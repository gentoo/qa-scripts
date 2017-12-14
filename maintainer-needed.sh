#!/bin/bash
# Copyright 2015 Gentoo Foundation
# Distributed under the terms of the GNU GPL version 2 or later
# Author: Markos Chandras <hwoarang@gentoo.org>

tmpfile="/tmp/mn-pkglist$$.tmp"
rdepdir=$1

cleanup () {
	[[ -e ${tmpfile} ]] && rm ${tmpfile}
}

portageq --no-filters --orphaned -n > ${tmpfile} || { cleanup; exit 1; }

echo """
<html>
	<head>
		<style type=\"text/css\"> li a { font-family: monospace; display: block; float: left; }</style>
		<title>Orphan packages</title>
	</head>
	<body>
		List generated on $(date)<br/>
		Total packages: <b>$(wc -l ${tmpfile} | cut -d ' '  -f1)</b><br/><br/>
		<table frame="box" rules="all">
			<tr>
				<th>Package Name</th>
				<th>Description</th>
				<th>Open bugs</th>
				<th>R-revdeps</th>
				<th>D-revdeps</th>
				<th>P-revdeps</th>
			</tr>
"""

while read pkg; do
	echo """
			<tr>
				<td>${pkg}</td>
				<td>$(pquery --no-version --one-attr description ${pkg})</td>
				<td><a href=\"https://bugs.gentoo.org/buglist.cgi?quicksearch=${pkg}\">Open Bugs</a></td>
				<td><a href=\"genrdeps/rindex/${pkg}\">$(cat ${rdepdir}/rindex/${pkg} 2>/dev/null | wc -l)</a></td>
				<td><a href=\"genrdeps/dindex/${pkg}\">$(cat ${rdepdir}/dindex/${pkg} 2>/dev/null | wc -l)</a></td>
				<td><a href=\"genrdeps/pindex/${pkg}\">$(cat ${rdepdir}/pindex/${pkg} 2>/dev/null | wc -l)</a></td>
			</tr>
	"""
done < ${tmpfile}

echo """
		</table>
	</body>
</html>
"""

cleanup

exit 0
