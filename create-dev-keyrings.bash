#!/bin/bash

OUTPUT_DIR=${1:-.}

COMMIT_RULE='(&(gentooAccess=git.gentoo.org/repo/gentoo.git)(gentooStatus=active))'
NONCOMMIT_RULE='(&(!(gentooAccess=git.gentoo.org/repo/gentoo.git))(gentooStatus=active))'
RETIRED_RULE='(!(gentooStatus=active))'

# grab_ldap_fingerprints <ldap-rule>
grab_ldap_fingerprints() {
	ldapsearch "${1}" -Z gpgfingerprint -LLL |
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
		gpg -q --recv-keys "${remaining[@]}" || :
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

COMMITTING_DEVS=( $(grab_ldap_fingerprints "${COMMIT_RULE}") )
NONCOMMITTING_DEVS=( $(grab_ldap_fingerprints "${NONCOMMIT_RULE}") )
#RETIRED_DEVS=( $(grab_ldap_fingerprints "${RETIRED_RULE}") )

export GNUPGHOME=$(mktemp -d)
trap 'rm -rf "${GNUPGHOME}"' EXIT

grab_keys "${COMMITTING_DEVS[@]}"
gpg --export > "${OUTPUT_DIR}"/committing-devs.gpg
grab_keys "${NONCOMMITTING_DEVS[@]}"
gpg --export > "${OUTPUT_DIR}"/active-devs.gpg
# -- not all are on keyservers
#grab_keys "${RETIRED_DEVS[@]}"
#gpg --export > "${OUTPUT_DIR}"/all-devs.gpg
