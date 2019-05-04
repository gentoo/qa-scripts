#!/bin/bash

DEV_BASE='ou=devs,dc=gentoo,dc=org'
SYSTEM_BASE='ou=system,dc=gentoo,dc=org'

COMMIT_RULE='(&(gentooAccess=git.gentoo.org/repo/gentoo.git)(gentooStatus=active))'
NONCOMMIT_RULE='(&(!(gentooAccess=git.gentoo.org/repo/gentoo.git))(gentooStatus=active))'
RETIRED_RULE='(!(gentooStatus=active))'

export KS_GENTOO=hkps://keys.gentoo.org/
export KS_SKS=hkps://hkps.pool.sks-keyservers.net/
export KEYSERVERS=( ) # empty by default
export COMMITTING_DEVS=( )
export NONCOMMITTING_DEVS=( )
export RETIRED_DEVS=( )
export SYSTEM_KEYS=( )

# grab_ldap_fingerprints <ldap-rule>
grab_ldap_fingerprints() {
	ldapsearch "${@}" -Z gpgfingerprint -LLL |
		sed -n -e '/: undefined/d' -e '/^gpgfingerprint: /{s/^.*://;s/ //g;p}' |
		sort -u
}

# grab_keys <fingerprint>...
grab_keys() {
	local retries=0
	local missing=()
	local remaining=( "${@}" )

	KEYSERVER_TIMEOUT=${KEYSERVER_TIMEOUT:=1m}
	while :; do
		for ks in "${KEYSERVERS[@]}" ; do
			timeout ${KEYSERVER_TIMEOUT} gpg --keyserver "$ks" -q --recv-keys "${remaining[@]}" || :
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
	# Only send keys that we have
	local remaining=( $(gpg --with-colon --list-public "${@}" | sed -n '/^pub/{n; /fpr/p }' |cut -d: -f10) )
	KEYSERVER_TIMEOUT=${KEYSERVER_TIMEOUT:=1m}
	for ks in "${KEYSERVERS[@]}" ; do
		timeout ${KEYSERVER_TIMEOUT} gpg --keyserver "$ks" -q --send-keys "${remaining[@]}" || :
	done
}

export GPG_TMPDIR=''
clean_tmp() {
	[ -n "$GPG_TMPDIR" ] && [ -d "$GPG_TMPDIR" ] && rm -rf "$GPG_TMPDIR"
}
setup_tmp() {
	GPG_TMPDIR=$(mktemp -d)
	trap clean_tmp EXIT
}

export_keys() {
	DST="$1"
	shift
	setup_tmp
	TMP="${GPG_TMPDIR}"/$(basename "${DST}")
	# Must not exist, otherwise GPG will give error
	[[ -f "${TMP}" ]] && rm -f "${TMP}"
	# 'gpg --export' returns zero if there was no error with the command itself
	# If there are no keys in the export set, then it ALSO does not write the destination file
	# and prints 'gpg: WARNING: nothing exported' to stderr
	if gpg --output "$TMP" --export "${@}" && test -s "${TMP}"; then
		chmod a+r "${TMP}"
		mv "${TMP}" "${DST}"
	else
		echo "Unable to export keys to $DST"
		exit 1
	fi
}

# populate common variables
# TODO: for unclear reason this does not populate correctly inside a function
export_ldap_data_to_env() {
	export -a COMMITTING_DEVS=( $(grab_ldap_fingerprints -b "${DEV_BASE}" "${COMMIT_RULE}") )
	export -a NONCOMMITTING_DEVS=( $(grab_ldap_fingerprints -b "${DEV_BASE}" "${NONCOMMIT_RULE}") )
	export -a RETIRED_DEVS=( $(grab_ldap_fingerprints -b "${DEV_BASE}" "${RETIRED_RULE}") )
	export -a SYSTEM_KEYS=( $(grab_ldap_fingerprints -b "${SYSTEM_BASE}" "${NONCOMMIT_RULE}") )
}
