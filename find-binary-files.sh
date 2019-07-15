#!/bin/bash
# Copyright 2014-2019 Ulrich Müller
# Distributed under the terms of the GNU GPL version 2 or later
# Author: Ulrich Müller <ulm@gentoo.org>

shopt -s extglob

portdir=$(portageq get_repo_path / gentoo)
cd "${portdir}" || exit 1

find . \( -path ./distfiles -o -path ./local -o -path ./metadata \
    -o -path ./packages \) -prune \
    -o ! -type d ! \( -type f -name 'Manifest*.gz' \) -exec file -ih '{}' + \
| while read line; do
    path=${line%:*}
    type=${line##*:*( )}
    case ${type} in
        "application/octet-stream; charset=binary" \
        | "application/octet-stream; charset=unknown" \
        | "binary; charset=binary")
            # GNU Info files (or patches to them) can contain the following
            # control characters that produce false positives:
            # - 0x1f, followed by LF or FF
            # - 0x7f (DEL), preceded by "Node:" or "Ref:" in the same line
            # Filter such characters and reiterate
            line=$(sed -e 's/\x1f\f\?$//;/\(Node\|Ref\):/s/\x7f//' "${path}" \
                | file -i -)
            type=${line##*:*( )}
            ;;
    esac
    case ${type} in
        text/*) ;;                            # text file
        application/*"; charset=us-ascii") ;;
        application/*"; charset=utf-8") ;;
        "image/svg; charset=us-ascii") ;;     # SVG image
        "image/svg+xml; charset=us-ascii") ;; # SVG image
        "image/x-xpmi; charset=us-ascii") ;;  # XPM image
        "message/rfc822; charset=us-ascii") ;;
        *)
            size=$(stat -c "%s" "${path}")
            echo "${path#./}: ${type} (size=${size})"
            ;;
    esac
done \
| sort 
