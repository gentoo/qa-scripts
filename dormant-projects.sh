#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Copyright 2026 Gentoo Authors
# Author: Brett A C Sheffield <bacs@librecast.net>
#
# Print a list of projects with no members, linking to their semi-orphaned
# packages.
#
# Requires:
# - dev-libs/libxslt (for xsltproc)
# - net-misc/curl (for wcurl)

tmpfile=`mktemp`

cleanup () {
        [[ -e ${tmpfile} ]] && rm ${tmpfile}
}

wcurl --curl-options="--silent --clobber" -O ${tmpfile} https://api.gentoo.org/metastructure/projects.xml || { cleanup; exit 1; }

xsltproc --novalid --stringparam now "$(date)" -o - dormant-projects.xsl ${tmpfile}

cleanup

exit 0
