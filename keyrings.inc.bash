#!/bin/bash

DEV_BASE='ou=devs,dc=gentoo,dc=org'
SYSTEM_BASE='ou=system,dc=gentoo,dc=org'

COMMIT_RULE='(&(gentooAccess=git.gentoo.org/repo/gentoo.git)(gentooStatus=active))'
NONCOMMIT_RULE='(&(!(gentooAccess=git.gentoo.org/repo/gentoo.git))(gentooStatus=active))'
RETIRED_RULE='(!(gentooStatus=active))'
INFRA_RULE='(&(gentooAccess=infra.group)(gentooStatus=active))'
INFRA_SYSTEM_RULE='(&(gentooAccess=infra-system.group)(gentooStatus=active))'

export KS_GENTOO=hkps://keys.gentoo.org/
# Use local keyserver for speedup
# KS_GENTOO_LOCAL=${HOSTNAME%.gentoo.org}.keys.gentoo.org
# dig $KS_GENTOO_LOCAL +short |grep -sq . && export KS_GENTOO=hkps://${KS_GENTOO_LOCAL}

#export KS_SKS=hkps://hkps.pool.sks-keyservers.net/ # Disabled pending security announcement
export KS_OPENPGP=hkps://keys.openpgp.org/ # runs Hagrid
export KEYSERVERS=( ) # empty by default
export COMMITTING_DEVS=( )
export NONCOMMITTING_DEVS=( )
export RETIRED_DEVS=( )
export INFRA_DEVS=( )
export SYSTEM_KEYS=( )

# grab_ldap_fingerprints <ldap-rule>
grab_ldap_fingerprints() {
	ldapsearch "${@}" -x -Z gpgfingerprint -LLL |
		sed -n -e '/: undefined/d' -e '/^gpgfingerprint: /{s/^.*://;s/ //g;p}' |
		sort -u
}

# grab_keys <fingerprint>...
grab_keys() {
	local retries=0
	local missing=()
	local remaining=( "${@}" )

	KEYSERVER_TIMEOUT=${KEYSERVER_TIMEOUT:=2m}
	# quickly handle empty keyservers set
	[ "${#KEYSERVERS[@]}" -eq 0 ] && return
	while :; do
		for ks in "${KEYSERVERS[@]}" ; do
			timeout ${KEYSERVER_TIMEOUT} gpg \
				--keyserver-options no-import-clean,no-self-sigs-only \
				--keyserver "$ks" -q --recv-keys "${remaining[@]}" || :
		done
		missing=()
		for key in "${remaining[@]}"; do
			gpg --list-public "${key}" &>/dev/null || missing+=( "${key}" )
		done

		[[ ${#missing[@]} -ne 0 ]] || break

		# if we did not make progress, give it a few seconds and retry
		if [[ ${#missing[@]} -eq ${#remaining[@]} ]]; then
			if [[ $(( retries++ )) -gt 3 ]]; then
				echo "Unable to fetch the following keys:"
				printf '%s\n' "${missing[@]}"
				break # if we hard-exit, the entire export will fail
			fi
			sleep 5
		fi

		remaining=( "${missing[@]}" )
	done
}

# push_keys <fingerprint>...
push_keys() {
	# quickly handle empty keyservers set
	[ "${#KEYSERVERS[@]}" -eq 0 ] && return
	# Only send keys that we have
	local remaining=( $(gpg --with-colon --list-public "${@}" | sed -n '/^pub/{n; /fpr/p }' |cut -d: -f10) )
	KEYSERVER_TIMEOUT=${KEYSERVER_TIMEOUT:=1m}
	for ks in "${KEYSERVERS[@]}" ; do
		timeout ${KEYSERVER_TIMEOUT} gpg --keyserver "$ks" -q --send-keys "${remaining[@]}" || :
	done
}

export GPG_TMPDIR=''
clean_tmp() {
	# Ensure any agent is closed down
	gpgconf --kill all
	[ -n "$GPG_TMPDIR" ] && [ -d "$GPG_TMPDIR" ] && rm -rf "$GPG_TMPDIR"
}
setup_tmp() {
	if [ -z "${GPG_TMPDIR}" ]; then
		GPG_TMPDIR=$(mktemp -d)
		export GPG_TMPDIR
		trap clean_tmp EXIT
	fi
}

export_keys() {
	DST="$1"
	shift
	setup_tmp
	BASENAME=$(basename "${DST}")
	TMP="${GPG_TMPDIR}/${BASENAME}"
	# Must not exist, otherwise GPG will give error
	[[ -f "${TMP}" ]] && rm -f "${TMP}"
	# 'gpg --export' returns zero if there was no error with the command itself
	# If there are no keys in the export set, then it ALSO does not write the destination file
	# and prints 'gpg: WARNING: nothing exported' to stderr
	if ! gpg --output "$TMP" --export "${@}"; then
		echo "Unable to export keys to $DST: GPG returned non-zero"
		exit 1
	fi
	if ! test -s "${TMP}"; then
		echo "Unable to export keys to $DST: GPG returned zero but generated empty file"
		exit 1
	fi
	# We have a non-empty output now!
	# Capture it in a textual format that can be compared for changes, but make sure it exports correctly
	if ! gpg --list-packets "${TMP}" >"${TMP}.packets.txt"; then
		echo "Unable to export keys to $DST: GPG failed to list packets"
		exit 1
	fi

	# Ensure we have a checksum to verify the file.
	rhash --bsd --sha256 --sha512 --blake2b "${TMP}" |sed "s,${TMP},${BASENAME},g" >"${TMP}.DIGESTS"

	# Check if the textual format has changed at all, and emit the new version
	# if there are ANY changes at all.
	if ! cmp -s "${DST}.packets.txt" "${TMP}.packets.txt"; then
		chmod a+r "${TMP}"
		mv -f "${TMP}" "${DST}"
		mv -f "${TMP}.packets.txt" "${DST}.packets.txt"
		mv -f "${TMP}.DIGESTS" "${DST}.DIGESTS"
	fi
	# Cleanup anyway
	rm -f "${TMP}.packets.txt" "${TMP}"
}

# populate common variables
# TODO: for unclear reason this does not populate correctly inside a function
export_ldap_data_to_env() {
	export -a COMMITTING_DEVS=( $(grab_ldap_fingerprints -b "${DEV_BASE}" "${COMMIT_RULE}") )
	export -a NONCOMMITTING_DEVS=( $(grab_ldap_fingerprints -b "${DEV_BASE}" "${NONCOMMIT_RULE}") )
	export -a RETIRED_DEVS=( $(grab_ldap_fingerprints -b "${DEV_BASE}" "${RETIRED_RULE}") )
	export -a INFRA_DEVS=( $(grab_ldap_fingerprints -b "${DEV_BASE}" "${INFRA_RULE}") )
	export -a SYSTEM_KEYS=( $(grab_ldap_fingerprints -b "${SYSTEM_BASE}" "${NONCOMMIT_RULE}") )
	export -a INFRA_SYSTEM_KEYS=( $(grab_ldap_fingerprints -b "${SYSTEM_BASE}" "${INFRA_SYSTEM_RULE}") )
}
