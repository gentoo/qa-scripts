#!/bin/bash
# Export keys to keyrings
#
# TODO:
# - only run the export if there was really a change
# - requires keeping state to detect changes in keys, there is no usable mtime data in a key itself

OUTPUT_DIR=${1:-.}
BASEDIR="$(dirname "$0")"
# shellcheck source=./keyrings.inc.bash
source "${BASEDIR}"/keyrings.inc.bash

set -e
export_ldap_data_to_env
export -a COMMITTING_DEVS=( $(grab_ldap_fingerprints -b "${DEV_BASE}" "${COMMIT_RULE}") )
export -a NONCOMMITTING_DEVS=( $(grab_ldap_fingerprints -b "${DEV_BASE}" "${NONCOMMIT_RULE}") )
export -a RETIRED_DEVS=( $(grab_ldap_fingerprints -b "${DEV_BASE}" "${RETIRED_RULE}") )
export -a SYSTEM_KEYS=( $(grab_ldap_fingerprints -b "${SYSTEM_BASE}" "${NONCOMMIT_RULE}") )

export_keys "${OUTPUT_DIR}"/service-keys.gpg \
	"${SYSTEM_KEYS[@]}"

export_keys "${OUTPUT_DIR}"/committing-devs.gpg \
	"${COMMITTING_DEVS[@]}"

export_keys "${OUTPUT_DIR}"/active-devs.gpg \
	"${COMMITTING_DEVS[@]}" \
	"${NONCOMMITTING_DEVS[@]}"

export_keys "${OUTPUT_DIR}"/infra-devs.gpg \
	"${INFRA_DEVS[@]}"

export_keys "${OUTPUT_DIR}"/retired-devs.gpg \
	"${RETIRED_DEVS[@]}"

# Everybody together now
export_keys "${OUTPUT_DIR}"/all-devs.gpg \
	"${SYSTEM_KEYS[@]}" \
	"${COMMITTING_DEVS[@]}" \
	"${NONCOMMITTING_DEVS[@]}" \
	"${INFRA_DEVS[@]}" \
	"${RETIRED_DEVS[@]}"

for key in service-keys committing-devs active-devs infra-devs retired-devs all-devs ; do
	timestamp=$(date -u +%Y%m%d -d "next monday")

	# Don't clobber existing timestamped keys for this period (weekly)
	# if we're running several times a day.
	if [[ -f "${OUTPUT_DIR}"/${key}-${timestamp}.gpg ]] ; then
		continue
	fi

	cp "${OUTPUT_DIR}"/${key}.gpg "${OUTPUT_DIR}"/${key}-${timestamp}.gpg
done

clean_tmp
