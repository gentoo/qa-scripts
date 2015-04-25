#!/bin/bash
# Copyright 2015 Gentoo Foundation
# Distributed under the terms of the GNU GPL version 2 or later
# Author: Markos Chandras <hwoarang@gentoo.org>

tmpfile="/tmp/mn-pkglist$$.tmp"

cleanup () {
	[[ -e ${tmpfile} ]] && rm ${tmpfile}
}

portageq --no-filters --maintainer-email=maintainer-needed@gentoo.org -n > ${tmpfile} || { cleanup; exit 1; }

echo """
<html>
	<head>
		<style type=\"text/css\"> li a { font-family: monospace; display: block; float: left; }</style>
		<title>Orphan packages</title>
	</head>
	<body>
		List generated on $(date)<br/>
		Total packages: <b>$(wc -l ${tmpfile} | cut -d ' '  -f1)</b><br/><br/>
		<table>
			<tr>
				<th>Package Name</th>
				<th>Description</th>
				<th>Open bugs</th>
			</tr>
"""

while read pkg; do
	echo """
			<tr>
				<td>${pkg}</td>
				<td>$(pquery --no-version --one-attr description ${pkg})</td>
				<td><a href=\"https://bugs.gentoo.org/buglist.cgi?quicksearch=${pkg}\">Open Bugs</a></td>
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
