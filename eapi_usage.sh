#!/bin/bash

# Boring 'script' that just uses pkgcore's pinspect command. Someday it would be
# nice to graph this output, or maybe keep some running history?

#[[ $(type pinspect 2> /dev/null) ]] || exit 1
#
#pinspect eapi_usage /usr/portage

echo "<pre>"
find /usr/portage/metadata/md5-cache -type f ! -name '*.gz' \
  -exec grep -h '^EAPI=' '{}' + \
  | awk '
    { sub("EAPI=",""); eapi[$1]++ }
    END {
      PROCINFO["sorted_in"]="@val_num_desc"
      for (i in eapi) {
        s=""; for (j=1; j<eapi[i]*50./NR+0.5; j++) s=s"#"
        printf "EAPI %s: %7d ebuilds (%5.02f%%)  %s\n",
               i, eapi[i], eapi[i]*100.0/NR, s
       }
       printf "total:  %7d ebuilds\n", NR
    }'

echo
echo "Date generated: $(date -u '+%Y-%m-%d %H:%M:%S %Z')"
echo "</pre>"
