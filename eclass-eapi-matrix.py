#!/usr/bin/env python
# Eclass-EAPI matrix
# (c) 2018 Michał Górny
# Licensed under the terms of the 2-clause BSD license

import math
import os
import os.path
import re
import sys


STATS_LINE_RE = re.compile(r'EAPI=(?P<eapi>\w+) count: (?P<count>\d+)')
SUPP_LINE_RE = re.compile(r'EAPIs declared supported by eclass: (.*)')


def collect_data(work_dir):
    """
    Collect data about supported and used EAPIs from work_dir.

    work_dir: directory with eapi-per-eclass stats

    Returns dict of {eclass: (supported_eapis, {eapi: count, ...}), ...}
    """
    data = {}
    for eclass in os.listdir(work_dir):
        if not eclass.endswith('.eclass'):
            continue

        with open(os.path.join(work_dir, eclass, 'STATS.txt')) as f:
            eapis = {}
            supp_eapis = None
            for l in f:
                m = STATS_LINE_RE.match(l)
                if m is not None:
                    eapis[m.group('eapi')] = int(m.group('count'))
                    continue

                m = SUPP_LINE_RE.match(l)
                if m is not None:
                    supp_eapis = m.group(1).split()

            data[eclass[:-7]] = (supp_eapis, eapis)
    return data


def format_table(data):
    """
    Pretty-format table of eclass-EAPI data.
    """

    ret = ''

    max_eclass_length = max(len(k) for k in data)
    max_count = max(v for supp, eapis in data.values()
            for v in eapis.values())
    max_count_length = math.ceil(math.log10(max_count))

    all_eapis = sorted(frozenset(v for supp, eapis in data.values()
                                   for v in eapis))

    # format strings
    format_str = '{{eclass:>{}}}'.format(max_eclass_length)
    for eapi in all_eapis:
        format_str += '  {{eapi_{}:>{}}}'.format(eapi, max_count_length)
    format_str += '\n'

    # header
    hdr = {'eclass': 'eclass / EAPI'}
    for eapi in all_eapis:
        hdr['eapi_'+eapi] = eapi
    ret += format_str.format(**hdr)

    # ruler
    rule = {'eclass': max_eclass_length * '-'}
    for eapi in all_eapis:
        rule['eapi_'+eapi] = max_count_length * '-'
    ret += format_str.format(**rule)

    # data
    for eclass, ecl_data in sorted(data.items()):
        line = {'eclass': eclass}
        supp_eapis, eapis = ecl_data
        for eapi in all_eapis:
            if supp_eapis is not None and eapi not in supp_eapis:
                if eapis.get(eapi, 0) > 0:
                    line['eapi_'+eapi] = '%d?!' % eapis[eapi]
                else:
                    line['eapi_'+eapi] = 'xx'
            else:
                line['eapi_'+eapi] = eapis.get(eapi, 0)
        ret += format_str.format(**line)

    return ret


def main(work_dir):
    data = collect_data(work_dir)
    out = format_table(data)

    with open(os.path.join(work_dir, 'matrix.txt'), 'w') as f:
        f.write(out)


if __name__ == '__main__':
    main(*sys.argv[1:])
