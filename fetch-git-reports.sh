#!/usr/bin/env bash
# (c) 2015 Michał Górny
# 2-clause BSD licensed

set -e -x

outputdir=${1}

[[ ${outputdir} ]]
cd "${outputdir}"

for repo in gentoo-ci gpyutils repos; do
	[[ -d ${repo} ]] || git clone --depth=1 "git://anongit.gentoo.org/report/${repo}.git"

	cd "${repo}"
	git pull
	cd - >/dev/null
done
