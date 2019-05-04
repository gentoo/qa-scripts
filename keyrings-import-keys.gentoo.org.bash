#!/bin/bash
# Import key updates from Keyservers: keys.gentoo.org
#
# TODO:
# - Turn off export in this script

OUTPUT_DIR=${1:-.}
BASEDIR="$(dirname "$0")"
source "${BASEDIR}"/keyrings.inc.bash

set -e
export_ldap_data_to_env

export KEYSERVERS=( "${KS_GENTOO}" )
export KEYSERVER_TIMEOUT=5m

grab_keys "${SYSTEM_KEYS[@]}"
grab_keys "${COMMITTING_DEVS[@]}"
grab_keys "${NONCOMMITTING_DEVS[@]}"
# -- not all are on keyservers
# -- and are unlikely to turn up now
# -- this needs to fetch from some archive instead
grab_keys "${RETIRED_DEVS[@]}"
