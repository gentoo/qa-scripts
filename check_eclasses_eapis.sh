#!/bin/bash
# Created by Tomáš Chvátal <scarabeus@gentoo.org>
# License WTFPL-2.0

KNOWN_EAPIS="0 1 2 3 4"
TMPEAPIS="/tmp/$(basename $0).global.$$.tmp"
TMPECLASS="/tmp/$(basename $0).eclass.$$.tmp"
pushd "$(portageq portdir)/eclass" > /dev/null
ECLASSES=$(echo *.eclass)
popd > /dev/null
pquery --attr eapi --attr inherited --raw --all --repo portdir > "${TMPEAPIS}"

rm -rf *.eclass
for x in ${ECLASSES}; do
	echo "Processing eclass \"${x}\""
	rm -rf "${x}"
	mkdir "${x}"
	awk -F'=' '$3 ~ /'"${x%.eclass}"'[ "]/ {print $1" "$2}' "${TMPEAPIS}" > "${TMPECLASS}"
	pushd "${x}" > /dev/null
	echo "Overall statistic for eclass \"${x}\":" > "STATS.txt"
	for y in ${KNOWN_EAPIS}; do
		awk -F ' ' '$3 ~ /'"${y}"'/ {print $1}' "${TMPECLASS}" > "${y}.txt"
		tmpval=$(wc -l "${y}.txt" |cut -d' ' -f1)
		echo "EAPI=${y} count: ${tmpval}" >> "STATS.txt"
	done
	popd > /dev/null
done

rm ${TMPEAPIS}
rm ${TMPECLASS}
