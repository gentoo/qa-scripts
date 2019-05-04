#!/bin/bash
# Export key updates to Keyservers: keys.gentoo.org

BASEDIR="$(dirname "$0")"
# shellcheck source=./keyrings.inc.bash
source "${BASEDIR}"/keyrings.inc.bash

set -e
export_ldap_data_to_env
export -a COMMITTING_DEVS=( $(grab_ldap_fingerprints -b "${DEV_BASE}" "${COMMIT_RULE}") )
export -a NONCOMMITTING_DEVS=( $(grab_ldap_fingerprints -b "${DEV_BASE}" "${NONCOMMIT_RULE}") )
export -a RETIRED_DEVS=( $(grab_ldap_fingerprints -b "${DEV_BASE}" "${RETIRED_RULE}") )
export -a SYSTEM_KEYS=( $(grab_ldap_fingerprints -b "${SYSTEM_BASE}" "${NONCOMMIT_RULE}") )

export KEYSERVERS=( "${KS_GENTOO}" )
export KEYSERVER_TIMEOUT=5m

# Populate keys.gentoo.org with the keys we have, since they might have come from SKS
push_keys "${SYSTEM_KEYS[@]}"
push_keys "${COMMITTING_DEVS[@]}"
push_keys "${NONCOMMITTING_DEVS[@]}"
push_keys "${RETIRED_DEVS[@]}"
