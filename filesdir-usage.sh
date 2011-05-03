#!/bin/bash

# $1 is a number, N. The top N directories that are consuming space. Defaults to
# all.

cd /usr/portage/
if [[ -z $1 ]]; then
	du -h */*/files | sort -nr
else
	du -h */*/files | sort -nr | head -n $1
fi
echo
echo $(emerge --info | grep Timestamp)
