#!/bin/bash
# Import key updates from Keyservers: keys.gentoo.org

BASEDIR="$(dirname "$0")"
DEBUG=${DEBUG:=0}
# shellcheck source=./keyrings.inc.bash
source "${BASEDIR}"/keyrings.inc.bash

set -e

# export_ldap_data_to_env
# TODO: for unclear reason this does not populate correctly inside a function
export -a COMMITTING_DEVS=( $(grab_ldap_fingerprints -b "${DEV_BASE}" "${COMMIT_RULE}") )
export -a INFRA_DEVS=( $(grab_ldap_fingerprints -b "${DEV_BASE}" "${INFRA_RULE}") )
export -a NONCOMMITTING_DEVS=( $(grab_ldap_fingerprints -b "${DEV_BASE}" "${NONCOMMIT_RULE}") )
export -a RETIRED_DEVS=( $(grab_ldap_fingerprints -b "${DEV_BASE}" "${RETIRED_RULE}") )
export -a SYSTEM_KEYS=( $(grab_ldap_fingerprints -b "${SYSTEM_BASE}" "${NONCOMMIT_RULE}") )

export KEYSERVERS=( "${KS_GENTOO}" )
export KEYSERVER_TIMEOUT=5m

[[ $DEBUG -ne 0 ]] && echo SYSTEM_KEYS
grab_keys "${SYSTEM_KEYS[@]}"
[[ $DEBUG -ne 0 ]] && echo COMITTING_DEVS
grab_keys "${COMMITTING_DEVS[@]}"
[[ $DEBUG -ne 0 ]] && echo NONCOMITTING_DEVS
grab_keys "${NONCOMMITTING_DEVS[@]}"
[[ $DEBUG -ne 0 ]] && echo INFRA_DEVS
grab_keys "${INFRA_DEVS[@]}"
# -- not all are on keyservers
# -- and are unlikely to turn up now
# -- this needs to fetch from some archive instead
#grab_keys "${RETIRED_DEVS[@]}"

clean_tmp
