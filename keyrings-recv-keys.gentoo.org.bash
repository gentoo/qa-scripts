#!/bin/bash
# Import key updates from Keyservers: keys.gentoo.org
#
# TODO:
# - Turn off export in this script

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

grab_keys "${SYSTEM_KEYS[@]}"
grab_keys "${COMMITTING_DEVS[@]}"
grab_keys "${NONCOMMITTING_DEVS[@]}"
# -- not all are on keyservers
# -- and are unlikely to turn up now
# -- this needs to fetch from some archive instead
#grab_keys "${RETIRED_DEVS[@]}"
