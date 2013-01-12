#!/bin/bash
# Created by Tomáš Chvátal <scarabeus@gentoo.org>
# License WTFPL-2.0

if [[ -n ${1} ]]; then
	DIR="${1}"
	[[ -d ${DIR} ]] || mkdir -p ${DIR}
else
	DIR=$(pwd)
fi

[[ $(type pquery 2> /dev/null) ]] || exit 1

KNOWN_EAPIS="unsupported 0 1 2 3 4 5"
TMPEAPIS="/tmp/$(basename $0).global.$$.tmp"
TMPECLASS="/tmp/$(basename $0).eclass.$$.tmp"
pushd "$(portageq portdir)/eclass" > /dev/null
ECLASSES=$(echo *.eclass)
popd > /dev/null
pquery --attr eapi --attr inherited --raw --all --repo portdir > "${TMPEAPIS}"

pushd ${DIR} > /dev/null
rm -rf *.eclass
for x in ${ECLASSES}; do
	echo "Processing eclass \"${x}\""
	rm -rf "${x}"
	mkdir "${x}"
	awk -F'=' '$3 ~ /[ "]'"${x%.eclass}"'[ "]/ {print $1" "$2}' "${TMPEAPIS}" > "${TMPECLASS}"
	pushd "${x}" > /dev/null
	echo "Overall statistic for eclass \"${x}\":" > "STATS.txt"
	for y in ${KNOWN_EAPIS}; do
		awk -F ' ' '$3 ~ /"'"${y}"'"/ {print $1}' "${TMPECLASS}" > "${y}.txt"
		tmpval=$(wc -l "${y}.txt" |cut -d' ' -f1)
		echo "EAPI=${y} count: ${tmpval}" >> "STATS.txt"
	done
	sed -e 's/$/<br>/' STATS.txt > README.html
	popd > /dev/null
done
popd > /dev/null

rm ${TMPEAPIS}
rm ${TMPECLASS}
