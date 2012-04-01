#!/bin/sh
OUTPUTDIR=/var/www/qa-reports.gentoo.org/htdocs/output/genrdeps
[ -d "${OUTPUTDIR}" ] || mkdir -p ${OUTPUTDIR}
cd ${OUTPUTDIR}

mkdir .rindex_new
pushd .rindex_new > /dev/null
/var/www/qa-reports.gentoo.org/qa-scripts/genrdeps/genrdeps.py RDEPEND
find | cut -c 3- > .rindex
popd > /dev/null
mv rindex rindex_old
mv .rindex_new rindex
rm -rf rindex_old

mkdir .dindex_new
pushd .dindex_new > /dev/null
/var/www/qa-reports.gentoo.org/qa-scripts/genrdeps/genrdeps.py DEPEND
find | cut -c 3- > .dindex
popd > /dev/null
mv dindex dindex_old
mv .dindex_new dindex
rm -rf dindex_old

mkdir .pindex_new
pushd .pindex_new > /dev/null
/var/www/qa-reports.gentoo.org/qa-scripts/genrdeps/genrdeps.py PDEPEND
find | cut -c 3- > .pindex
popd > /dev/null
mv pindex pindex_old
mv .pindex_new pindex
rm -rf pindex_old
