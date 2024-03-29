#!/bin/bash

# silence the script by '&> /dev/null'

if [[ -z "$1" ]]; then
	echo "Usage: $0 </path/to/output/>"
	exit 1
fi
if ! type -P sig2dot &>/dev/null; then
	echo "install signing-party"; exit 1
fi
if ! type -P dot &>/dev/null; then
	echo "install graphviz"; exit 1
fi

gpg -q --keyid-format=long --keyring "${1}/active-devs.gpg" --list-sigs | \
	/usr/bin/sig2dot -q -t "Gentoo Dev WoT" -s wot-stats.html \
	> keys.dot

dot -Gcharset=UTF-8 -Tsvg keys.dot > "${1}/wot-graph.svg"

mv wot-stats.html "${1}"
