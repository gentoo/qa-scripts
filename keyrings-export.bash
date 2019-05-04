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

export_keys "${OUTPUT_DIR}"/service-keys.gpg \
	"${SYSTEM_KEYS[@]}"

export_keys "${OUTPUT_DIR}"/committing-devs.gpg \
	"${COMMITTING_DEVS[@]}"

export_keys "${OUTPUT_DIR}"/active-devs.gpg \
	"${COMMITTING_DEVS[@]}" \
	"${NONCOMMITTING_DEVS[@]}"

export_keys "${OUTPUT_DIR}"/retired-devs.gpg \
	"${RETIRED_DEVS[@]}"

# Everybody together now
export_keys "${OUTPUT_DIR}"/all-devs.gpg \
	"${SYSTEM_KEYS[@]}" \
	"${COMMITTING_DEVS[@]}" \
	"${NONCOMMITTING_DEVS[@]}" \
	"${RETIRED_DEVS[@]}"
