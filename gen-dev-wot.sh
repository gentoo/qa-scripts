#!/bin/bash

# intentionally quiet script

if [[ -z "$1" ]]; then
	echo "Usage: $0 </path/to/output/>"
	exit 1
fi
if [[ ! -e /usr/bin/sig2dot ]]; then
	echo "install signing-party"; exit 1
fi
if [[ ! -e /usr/bin/neato ]]; then
	echo "install graphviz"; exit 1
fi

export GNUPGHOME=$(mktemp -d --suffix=$(basename $0))
cd $GNUPGHOME || exit 1

wget -q -O -  http://www.gentoo.org/proj/en/devrel/roll-call/userinfo.xml | \
	egrep -o 0x[A-Z0-9]\{8\} | egrep [A-Z0-9]\{8\} > keys.txt

/usr/bin/gpg -q --keyserver hkp://pool.sks-keyservers.net --recv-keys \
	`cat keys.txt` &> /dev/null

/usr/bin/gpg -q --export `cat keys.txt` > keys.gpg

/usr/bin/gpg -q --no-default-keyring  --keyring ./keys.gpg --list-sigs | \
	/usr/bin/sig2dot -q -a -t "Gentoo Dev WoT" -s stats.html 2> /dev/null | \
	/usr/bin/neato -Gcharset=latin1 -Tpng > "${1}/graph.png"

mv stats.html "${1}"
rm -rf $GNUPGHOME
