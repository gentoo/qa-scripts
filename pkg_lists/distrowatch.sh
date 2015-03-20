#!/bin/sh
# $Id: distrowatch.sh,v 1.2 2008/07/12 02:02:47 robbat2 Exp $
# this file creates a list of packages from the Portage tree for distrowatch
#
# $1 = web script directory
# $2 = web site htdocs directory

if ! [ -d "$1" -a -d "$2" ]; then
	echo "You must specify the path to the web scripts and the path to the output directory"
	exit 1
fi

#Note: distrowatch lists non-x86 packages like yaboot, so I'm now including all arches (drobbins, 04/04/2003)

STABLE_ARCHES=" x86 amd64 ppc alpha arm hppa ia64 m68k mips ppc64 s390 sh sparc sparc-fbsd x86-fbsd"
UNSTABLE_ARCHES=" ~x86 ~amd64 ~ppc ~alpha ~arm ~hppa ~ia64 ~m68k ~mips ~ppc64 ~s390 ~sh ~sparc ~sparc-fbsd ~x86-fbsd"

tmp=$(mktemp)

# gentoo_pkglist_x86.txt contains the stable branch packages
ACCEPT_KEYWORDS="$STABLE_ARCHES" $1/pkglist.py 1> $tmp 2> /dev/null
cat $tmp > $2/gentoo_pkglist_stable.txt

# gentoo_pkglist_X86.txt contains the unstable branch packages
ACCEPT_KEYWORDS="$STABLE_ARCHES $UNSTABLE_ARCHES" $1/pkglist.py 1> $tmp 2> /dev/null
cat $tmp > $2/gentoo_pkglist_unstable.txt

rm -f $tmp
