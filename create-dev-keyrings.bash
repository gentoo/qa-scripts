#!/bin/bash

OUTPUT_DIR=${1:-.}

DEV_BASE='ou=devs,dc=gentoo,dc=org'
SYSTEM_BASE='ou=system,dc=gentoo,dc=org'

COMMIT_RULE='(&(gentooAccess=git.gentoo.org/repo/gentoo.git)(gentooStatus=active))'
NONCOMMIT_RULE='(&(!(gentooAccess=git.gentoo.org/repo/gentoo.git))(gentooStatus=active))'
RETIRED_RULE='(!(gentooStatus=active))'

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

	while :; do
		timeout 5m gpg -q --recv-keys "${remaining[@]}" || :
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
				exit 1
			fi
			sleep 5
		fi

		remaining=( "${missing[@]}" )
	done
}

set -e

COMMITTING_DEVS=( $(grab_ldap_fingerprints -b "${DEV_BASE}" "${COMMIT_RULE}") )
NONCOMMITTING_DEVS=( $(grab_ldap_fingerprints -b "${DEV_BASE}" "${NONCOMMIT_RULE}") )
#RETIRED_DEVS=( $(grab_ldap_fingerprints -b "${DEV_BASE}" "${RETIRED_RULE}") )
SYSTEM_KEYS=( $(grab_ldap_fingerprints -b "${SYSTEM_BASE}" "${NONCOMMIT_RULE}") )

grab_keys "${COMMITTING_DEVS[@]}" "${NONCOMMITTING_DEVS[@]}" "${SYSTEM_KEYS[@]}"
gpg --export "${COMMITTING_DEVS[@]}" > "${OUTPUT_DIR}"/committing-devs.gpg
gpg --export "${COMMITTING_DEVS[@]}" "${NONCOMMITTING_DEVS[@]}" > "${OUTPUT_DIR}"/active-devs.gpg
gpg --export "${SYSTEM_KEYS[@]}" > "${OUTPUT_DIR}"/release-keys.gpg
# -- not all are on keyservers
#grab_keys "${RETIRED_DEVS[@]}"
#gpg --export > "${OUTPUT_DIR}"/all-devs.gpg
