#!/bin/bash

# $1 is a number, N. The top N directories that are consuming space. Defaults to
# all.

pushd $(portageq portdir) >/dev/null
if [[ -z $1 ]]; then
	du -h */*/files | sort -nr
else
	du -h */*/files | sort -nr | head -n $1
fi
popd >/dev/null
echo
echo $(emerge --info | grep Timestamp)
