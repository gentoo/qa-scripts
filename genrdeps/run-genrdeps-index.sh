#!/bin/sh
OUTPUTDIR=/var/www/qa-reports.gentoo.org/htdocs/output/genrdeps
[[ -d ${OUTPUTDIR} ]] || mkdir -p ${OUTPUTDIR}

rm -rf ${OUTPUTDIR}/rindex
mkdir ${OUTPUTDIR}/rindex
cd ${OUTPUTDIR}/rindex
/var/www/qa-reports.gentoo.org/qa-scripts/genrdeps/genrdeps.py RDEPEND
find | cut -c 3- > .rindex

rm -rf ${OUTPUTDIR}/dindex
mkdir ${OUTPUTDIR}/dindex
cd ${OUTPUTDIR}/dindex
/var/www/qa-reports.gentoo.org/qa-scripts/genrdeps/genrdeps.py DEPEND
find | cut -c 3- > .dindex

rm -rf ${OUTPUTDIR}/pindex
mkdir ${OUTPUTDIR}/pindex
cd ${OUTPUTDIR}/pindex
/var/www/qa-reports.gentoo.org/qa-scripts/genrdeps/genrdeps.py PDEPEND
find | cut -c 3- > .pindex
