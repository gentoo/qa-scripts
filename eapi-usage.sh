#!/bin/bash
# This script respects EINFO_QUIET=1 etc to silence stdout
# Always puts a summary in $1/README.html.
# Arguments:
# $1: output directory. Defaults to eapi-usage.
# $2: file to place stats in within $1.
. /lib/gentoo/functions.sh

dir=${1}

if [[ -n ${1} && -e ${dir} && ! -d ${dir} ]] ; then
	eerror "Output directory given (${dir}) is not a directory! Exiting."
	exit 1
elif [[ -z ${dir} ]] ; then
	ewarn "No output directory argument given! Defaulting to 'eapi-usage'."
	dir=eapi-usage
fi

stats=${2:-$dir/STATS.txt}

mkdir -p ${dir} || exit 1

REPO_PATH=$(portageq get_repo_path ${EROOT:-/} gentoo || exit 1)
TMPDIR="$(mktemp -d || exit 1)"

shopt -s nullglob

einfo "Working in TMPDIR=${TMPDIR}"
pushd "${TMPDIR}" &>/dev/null || exit 1
mkdir -p eapi-usage || exit 1
cd eapi-usage || exit 1

ebegin "Finding ebuilds"
(
	for ebuild in $(find "${REPO_PATH}/metadata/md5-cache" -mindepth 2 -maxdepth 2 -type f -name '*-[0-9]*') ; do
		cpf=$(echo ${ebuild} | rev | cut -d/ -f1-2 | rev)
		eapi=$(grep -oi "eapi=.*" ${ebuild} | sed -e 's:EAPI=::')

		echo "${cpf}" >> ${eapi}.txt
	done
) || { eend $? || exit 1; }
eend ${?}

ebegin "Sorting EAPI files"
for eapi in *.txt ; do
	sort -u ${eapi} > ${eapi}.sorted
	mv ${eapi}.sorted ${eapi}
done || { eend $? || exit 1; }
eend $?

popd &>/dev/null || exit 1
# No exit here because it's fine if we removed nothing
rm ${dir}/*.txt
mv ${TMPDIR}/eapi-usage/*.txt ${dir}/ || exit 1

rm -r "${TMPDIR}" || exit 1

# Now generate the numbers/summary (copied in from previous eapi_usage.sh script)
# Boring 'script' that just uses pkgcore's pinspect command. Someday it would be
# nice to graph this output, or maybe keep some running history?

#[[ $(type pinspect 2> /dev/null) ]] || exit 1
#
#pinspect eapi_usage /usr/portage
find "${REPO_PATH}"/metadata/md5-cache -type f ! -name '*.gz' \
  -exec grep -h '^EAPI=' '{}' + \
  | awk '
    { sub("EAPI=",""); eapi[$1]++ }
    END {
      PROCINFO["sorted_in"]="@val_num_desc"
      for (i in eapi) {
        s=""; for (j=1; j<eapi[i]*50./NR+0.5; j++) s=s"#"
        printf "EAPI %s: %7d ebuilds (%5.02f%%)  %s\n",
               i, eapi[i], eapi[i]*100.0/NR, s
       }
       printf "total:  %7d ebuilds\n", NR
    }' > ${stats}

echo >> ${stats}
echo "Date generated: $(date -u '+%Y-%m-%d %H:%M:%S %Z')" >> ${stats}
echo "</pre>" >> ${stats}

echo "<pre>" > ${dir}/README.html
cat ${stats} >> ${dir}/README.html
echo "</pre>" >> ${dir}/README.html
