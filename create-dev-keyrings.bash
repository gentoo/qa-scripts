#!/bin/bash

OUTPUT_DIR=${1:-.}

DEV_BASE='ou=devs,dc=gentoo,dc=org'
SYSTEM_BASE='ou=system,dc=gentoo,dc=org'

COMMIT_RULE='(&(gentooAccess=git.gentoo.org/repo/gentoo.git)(gentooStatus=active))'
NONCOMMIT_RULE='(&(!(gentooAccess=git.gentoo.org/repo/gentoo.git))(gentooStatus=active))'
RETIRED_RULE='(!(gentooStatus=active))'

GPG_TMPDIR=$(mktemp -d)
clean_tmp() {
	rm -rf "$GPG_TMPDIR"
}

# grab_ldap_fingerprints <ldap-rule>
grab_ldap_fingerprints() {
	ldapsearch "${@}" -Z gpgfingerprint -LLL |
		sed -n -e '/^gpgfingerprint: /{s/^.*://;s/ //g;p}' |
		sort -u |
		grep -v undefined
}

# grab_keys <fingerprint>...
grab_keys() {
	local retries=0
	local missing=()
	local remaining=( "${@}" )

	# this needs to move to HKPS as well, but that part is not yet deployed.
	KS1=hkp://keys.gentoo.org/
	KS2=hkps://hkps.pool.sks-keyservers.net/
	while :; do
		timeout 5m  gpg --keyserver $KS1 -q --recv-keys "${remaining[@]}" || :
		timeout 20m gpg --keyserver $KS2 -q --recv-keys "${remaining[@]}" || :
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

export_keys() {
	DST="$1"
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

set -e

COMMITTING_DEVS=( $(grab_ldap_fingerprints -b "${DEV_BASE}" "${COMMIT_RULE}") )
NONCOMMITTING_DEVS=( $(grab_ldap_fingerprints -b "${DEV_BASE}" "${NONCOMMIT_RULE}") )
RETIRED_DEVS=( $(grab_ldap_fingerprints -b "${DEV_BASE}" "${RETIRED_RULE}") )
SYSTEM_KEYS=( $(grab_ldap_fingerprints -b "${SYSTEM_BASE}" "${NONCOMMIT_RULE}") )

grab_keys "${SYSTEM_KEYS[@]}"
export_keys "${OUTPUT_DIR}"/service-keys.gpg \
	"${SYSTEM_KEYS[@]}"

grab_keys "${COMMITTING_DEVS[@]}"
export_keys "${OUTPUT_DIR}"/committing-devs.gpg \
	"${COMMITTING_DEVS[@]}"

grab_keys "${NONCOMMITTING_DEVS[@]}"
export_keys "${OUTPUT_DIR}"/active-devs.gpg \
	"${COMMITTING_DEVS[@]}" \
	"${NONCOMMITTING_DEVS[@]}"

# -- not all are on keyservers
# -- and are unlikely to turn up now
# -- this needs to fetch from some archive instead
#grab_keys "${RETIRED_DEVS[@]}"
export_keys "${OUTPUT_DIR}"/retired-devs.gpg \
	"${RETIRED_DEVS[@]}"

# Everybody together now
export_keys "${OUTPUT_DIR}"/all-devs.gpg \
	"${SYSTEM_KEYS[@]}" \
	"${COMMITTING_DEVS[@]}" \
	"${NONCOMMITTING_DEVS[@]}" \
	"${RETIRED_DEVS[@]}"
