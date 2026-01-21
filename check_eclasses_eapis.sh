#!/bin/bash
# Created by Tomáš Chvátal <scarabeus@gentoo.org>
# License WTFPL-2.0

if [[ -n ${1} ]]; then
	DIR="${1}"
	[[ -d ${DIR} ]] || mkdir -p ${DIR}
else
	DIR=$(pwd)
fi

#[[ $(type pquery 2> /dev/null) ]] || exit 1
[[ $(type gawk 2> /dev/null) ]] || exit 1

TMPEAPIS="$(mktemp -t $(basename $0).global.tmp.XXXXXX)"
TMPECLASS="$(mktemp -t $(basename $0).eclass.tmp.XXXXXX)"
REPO_PATH=$(portageq get_repo_path ${EROOT:-/} gentoo)
pushd "${REPO_PATH}/eclass" > /dev/null
ECLASSES=$(echo *.eclass)
popd > /dev/null

#pquery --attr eapi --attr inherited --raw --all --repo portdir > "${TMPEAPIS}"
find "${REPO_PATH}/metadata/md5-cache" -type f -name '*-[0-9]*' -exec gawk -F= '
	BEGINFILE {
		n = split(FILENAME, f, "/")
		file = f[n-1] "/" f[n]
		eapi = "0"
		n_eclasses = 0
	}
	$1 == "EAPI" { eapi = $2 }
	$1 == "_eclasses_" { n_eclasses = split($2, eclasses, "\t") }
	ENDFILE {
		printf "%s eapi=\"%s\" inherited=\"", file, eapi
		for (i = 1; i <= n_eclasses; i += 2) {
			if (i != 1) printf " "
			printf "%s", eclasses[i]
		}
		printf "\"\n"
	}
	' '{}' \+ > "${TMPEAPIS}"

KNOWN_EAPIS=$(gawk '
	{ e = gensub(/eapi="(.*)"/, "\\1", "", $2); eapi[e] = e }
	END { PROCINFO["sorted_in"]="@ind_num_asc"; for (e in eapi) print e }
	' "${TMPEAPIS}")

pushd ${DIR} > /dev/null
rm -rf *.eclass
rm -f *.txt README.html
for x in ${ECLASSES}; do
	echo "Processing eclass \"${x}\""
	rm -rf "${x}"
	mkdir "${x}"
	gawk -F'=' '$3 ~ /[ "]'"${x%.eclass}"'[ "]/ {print $1" "$2}' "${TMPEAPIS}" > "${TMPECLASS}"
	pushd "${x}" > /dev/null
	echo "Overall statistics for eclass \"${x}\":" > "STATS.txt"
	for y in ${KNOWN_EAPIS}; do
		gawk -F ' ' '$3 ~ /"'"${y}"'"/ {print $1}' "${TMPECLASS}" > "${y}.txt"
		tmpval=$(wc -l "${y}.txt" |cut -d' ' -f1)
		echo "EAPI=${y} count: ${tmpval}" >> "STATS.txt"
	done
	SUPP_EAPIS=$(sed -n -e 's/^# @SUPPORTED_EAPIS: //p' "${REPO_PATH}/eclass/${x}")
	if [[ -n ${SUPP_EAPIS} ]]; then
		echo "EAPIs declared supported by eclass: ${SUPP_EAPIS}" >> STATS.txt
	fi
	sed -e 's/$/<br>/' STATS.txt > README.html
	popd > /dev/null
done
popd > /dev/null

"${0%/*}"/eclass-eapi-matrix.py "${DIR}"

rm ${TMPEAPIS}
rm ${TMPECLASS}
