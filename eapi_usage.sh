#!/bin/bash

# Boring 'script' that just uses pkgcore's pinspect command. Someday it would be
# nice to graph this output, or maybe keep some running history?

[[ $(type pinspect 2> /dev/null) ]] || exit 1

time pinspect eapi_usage /usr/portage
echo
echo "Date generated: $(date)"
