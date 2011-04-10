#!/bin/bash

[ -z $1 ] && exit 1

source /usr/lib/portage/bin/isolated-functions.sh 2>/dev/null

inherit() {
	for include in $*; do
		INHERIT="${INHERIT:+${INHERIT} }${include}"
		case $include in
			# That'll fix some variables when sourcing the ebuild itself :)
			(versionator|eutils)
				source /usr/portage/eclass/${include}.eclass
				continue
			;;
		esac
	done
}

source $1 2>/dev/null

[ -z "${MY_P}" ] && MY_P="####"
[ -z "${MY_PV}" ] && MY_PV="####"
[ -z "${MY_PN}" ] && MY_PN="####"
[ -z "${SLOT}" ] && SLOT="0"
[ -z "${INHERIT}" ] && INHERIT=""

echo $MY_P
echo $MY_PV
echo $MY_PN
echo $SLOT
echo $INHERIT

#echo $MY_P 1>&2
#echo $MY_PV 1>&2
#echo $MY_PN 1>&2
#echo $SLOT 1>&2
#echo $INHERIT 1>&2
