#!/bin/bash
# Export key updates to Keyservers: keys.gentoo.org

BASEDIR="$(dirname "$0")"
# shellcheck source=./keyrings.inc.bash
source "${BASEDIR}"/keyrings.inc.bash

set -e
export_ldap_data_to_env

export KEYSERVERS=( "${KS_GENTOO}" )
export KEYSERVER_TIMEOUT=5m

# Populate keys.gentoo.org with the keys we have, since they might have come from SKS
push_keys "${SYSTEM_KEYS[@]}"
push_keys "${COMMITTING_DEVS[@]}"
push_keys "${NONCOMMITTING_DEVS[@]}"
push_keys "${RETIRED_DEVS[@]}"
