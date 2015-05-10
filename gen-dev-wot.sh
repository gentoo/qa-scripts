#!/bin/bash

# silence the script by '&> /dev/null'

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
	egrep -o '0x([A-Z0-9]{8}){1,2}' > keys.txt

# Looks like all the outgoing connections to port 11371 are blocked from scrubfowl
/usr/bin/gpg -q --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys \
	`cat keys.txt`

/usr/bin/gpg -q --no-default-keyring --list-sigs | \
	/usr/bin/sig2dot -q -t "Gentoo Dev WoT" -s wot-stats.html \
	> keys.dot

/usr/bin/dot -Gcharset=latin1 -Tpng keys.dot > "${1}/wot-graph.png"

mv wot-stats.html "${1}"
rm -rf $GNUPGHOME
