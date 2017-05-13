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

	local topdir=$(dirname "${0}")/..

	if ! cd "${topdir}/htdocs/output/${repo}" 2>/dev/null; then
		echo "Status: 404 Not Found"
		echo
		echo "404 Not Found"
		exit 0
	fi

	# generate HTML from XML
	local lfile=${file}
	[[ ${file} == *.html ]] && lfile=${file%.html}.xml

	local tree=( $(git ls-tree "${commit}" "${lfile}" 2>/dev/null) )
	if [[ ! ${tree[*]} ]]; then
		# fallback for stuff without .xml
		lfile=${file}
		tree=( $(git ls-tree "${commit}" "${lfile}" 2>/dev/null) )
		if [[ ! ${tree[*]} ]]; then
			echo "Status: 404 Not Found"
			echo
			echo "404 Not Found (if the report was just published, you may need to wait a minute or two for sync)"
			exit 0
		fi
	fi

	local ct
	case "${file}" in
		*.css) ct=text/css;;
		*.html) ct=text/html;;
		*.xml) ct=application/xml;;
		*) ct=text/plain;;
	esac

	echo "Content-Type: ${ct}"
	echo
	if [[ ${file} == *.html && ${lfile} == *.xml ]]; then
		local ts=$(TZ=UTC git log --format='%cd' --date=iso-local -1 | cut -d' ' -f1-2)

		git cat-file -p "${tree[2]}" \
			| PYTHONIOENCODING=utf8 python "${topdir}"/pkgcheck2html/pkgcheck2html.py -t "${ts}" -
	else
		git cat-file -p "${tree[2]}"
	fi
}

main
