#!/usr/bin/env bash

if [[ ! ${QUERY_STRING} ]]; then
	echo "Script must be run through CGI" >&2
	exit 1
fi

main() {
	local repo=${QUERY_STRING}
	if [[ ${repo} == */* ]]; then
		echo "DANGER! DANGER! DON'T TALK TO STRANGERS!" >&2
		exit 1
	fi

	local topdir=$(dirname "${0}")/..

	if ! cd "${topdir}/htdocs/output/${repo}" 2>/dev/null; then
		echo "Status: 404 Not Found"
		echo
		echo "404 Not Found"
		exit 0
	fi

	local output=$(git pull -q 2>&1)
	if [ $? -eq 0 ]; then
		echo "Status: 200 OK"
		echo
		echo "Done."
	else
		echo "Status: 500 Failed"
		echo
		echo "${output}"
	fi
}

main
