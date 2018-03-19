#!/bin/bash

# Boring 'script' that just uses pkgcore's pinspect command. Someday it would be
# nice to graph this output, or maybe keep some running history?

#[[ $(type pinspect 2> /dev/null) ]] || exit 1
#
#pinspect eapi_usage /usr/portage

find /usr/portage/metadata/md5-cache -type f \
  ! -name '*.gz' ! -name 'Manifest*' -exec awk '
    BEGINFILE { found=0 }
    /^EAPI=/ { sub("EAPI=",""); eapi[$1]++; found=1; nextfile }
    END { for (i in eapi) print i,eapi[i] }
  ' '{}' '+' | awk '
    { eapi[$1]+=$2; total+=$2 }
    END {
      PROCINFO["sorted_in"]="@val_num_desc"
      for (i in eapi) {
        s=""; for (j=1; j<eapi[i]*50./total+0.5; j++) s=s"#"
        printf "EAPI %s: %7d ebuilds (%5.02f%%)  %s\n",
               i, eapi[i], eapi[i]*100.0/total, s
       }
       printf "total:  %7d ebuilds\n", total
    }'

echo
echo "Date generated: $(date)"
