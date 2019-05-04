#!/bin/bash
# Import key updates from Keyservers
#
# TODO:
# - Turn off export in this script

OUTPUT_DIR=${1:-.}
BASEDIR="$(dirname "$0")"
source "${BASEDIR}"/keyrings.inc.bash

set -e
export_ldap_data_to_env

export KEYSERVERS=( "${KS_SKS}" "${KS_GENTOO}" )
export KEYSERVER_TIMEOUT=20m

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

# Populate keys.gentoo.org with the keys we have, since they might have come from SKS
export KEYSERVERS=( "${KS_GENTOO}" )
export KEYSERVER_TIMEOUT=20m
push_keys "${SYSTEM_KEYS[@]}"
push_keys "${COMMITTING_DEVS[@]}"
push_keys "${NONCOMMITTING_DEVS[@]}"
push_keys "${RETIRED_DEVS[@]}"
