#!/usr/bin/env bash

if [[ ! ${QUERY_STRING} ]]; then
	echo "Script must be run through CGI" >&2
	exit 1
fi

main() {
	local qs=${QUERY_STRING}
	local repo=${qs%%;*}
	qs=${qs#*;}
	local commit=${qs%%;*}
	qs=${qs#*;}
	local file=${qs%%;*}

	if [[ ${repo} == */* ]]; then
		echo "DANGER! SOMEONE TRIES TO ABUSE ME!" >&2
		exit 1
	fi

	if ! cd "$(dirname "${0}")/../htdocs/output/${repo}" 2>/dev/null; then
		echo "Status: 404 Not Found"
		echo
		echo "404 Not Found"
		exit 0
	fi

	local tree=( $(git ls-tree "${commit}" "${file}" 2>/dev/null) )
	if [[ ! ${tree[*]} ]]; then
		echo "Status: 404 Not Found"
		echo
		echo "404 Not Found"
		exit 0
	fi

	local ct
	case "${file}" in
		*.css) ct=text/css;;
		*.html) ct=text/html;;
		*) ct=text/plain;;
	esac

	echo "Content-Type: ${ct}"
	echo
	git cat-file -p "${tree[2]}"
}

main
