#!/usr/bin/env python
# Rewrite of genrdeps-index to stop using horrible Portage API.
# (c) 2020 Michał Górny
# 2-clause BSD license

import argparse
import collections
import errno
import os
import os.path
import shutil
import subprocess
import sys
import tempfile

import pkgcore.config
from pkgcore.ebuild.atom import atom
from pkgcore.restrictions.boolean import AndRestriction, OrRestriction
from pkgcore.restrictions.packages import Conditional


DepTuple = collections.namedtuple('DepTuple', ('cpv', 'blocks', 'use'))


GROUPS = (
    ('bdepend', 'bindex'),
    ('depend', 'dindex'),
    ('idepend', 'iindex'),
    ('pdepend', 'pindex'),
    ('rdepend', 'rindex'),
)


def process_deps(deps, useflags=frozenset()):
    for d in deps:
        if isinstance(d, atom):
            yield DepTuple(d.key, d.blocks, useflags)
        elif isinstance(d, OrRestriction) or isinstance(d, AndRestriction):
            # || deps and nested () blocks
            for sd in process_deps(d, useflags):
                yield sd
        elif isinstance(d, Conditional):
            # foo? deps
            assert d.attr == 'use'
            assert len(d.restriction.vals) == 1
            r = next(iter(d.restriction.vals))
            if d.restriction.negate:
                r = '!' + r
            for sd in process_deps(d, useflags | frozenset((r,))):
                yield sd
        else:
            raise AssertionError("Unknown dep type: " + d.__class__)


def rmtree_ignore_enoent(func, path, exc_info):
    if not isinstance(exc_info[1], FileNotFoundError):
        raise


def main():
    argp = argparse.ArgumentParser()
    argp.add_argument('outputdir',
                      help='Directory to create rdep index in')
    args = argp.parse_args()

    c = pkgcore.config.load_config()
    repo = c.repo['gentoo']

    rindex = {}
    for g, gi in GROUPS:
        rindex[g] = collections.defaultdict(set)

    for p in repo:
        for g, gi in GROUPS:
            deps = frozenset(process_deps(getattr(p, g)))
            for dep, blocks, flags in deps:
                rindex[g][dep].add(DepTuple(p.cpvstr, blocks, flags))

    for g, gi in GROUPS:
        outdir = os.path.join(args.outputdir, '.' + gi + '.new')
        shutil.rmtree(outdir, onerror=rmtree_ignore_enoent)

        for p, revdeps in rindex[g].items():
            outpath = os.path.join(outdir, p)
            os.makedirs(os.path.dirname(outpath), exist_ok=True)
            with open(outpath, 'w') as f:
                for dep, blocks, flags in sorted(revdeps):
                    if blocks:
                        dep = '[B]' + dep
                    if flags:
                        dep += ':' + '+'.join(sorted(flags))
                    f.write(dep + '\n')

    for g, gi in GROUPS:
        outdir = os.path.join(args.outputdir, gi)
        olddir = os.path.join(args.outputdir, '.' + gi + '.old')
        newdir = os.path.join(args.outputdir, '.' + gi + '.new')

        shutil.rmtree(olddir, onerror=rmtree_ignore_enoent)
        try:
            os.rename(outdir, olddir)
        except FileNotFoundError as e:
            pass
        os.rename(newdir, outdir)
        shutil.rmtree(olddir, onerror=rmtree_ignore_enoent)

    with tempfile.NamedTemporaryFile(prefix='.tmp.rdeps-', suffix='.tar', dir=args.outputdir, delete=False) as tmpf:
        try:
            subprocess.check_call(
                ['tar', '-cf', tmpf.name] + [gi for g, gi in GROUPS],
                cwd=args.outputdir)
            subprocess.check_call(
                ['xz', '-9', tmpf.name],
                cwd=args.outputdir)
            os.rename(tmpf.name + '.xz', os.path.join(args.outputdir, 'rdeps.tar.xz'))
            os.chmod(os.path.join(args.outputdir, 'rdeps.tar.xz'), 0o644)
        except Exception as e:
            raise e
        finally:
            # Cleanup:
            for f in [tmpf.name, (tmpf.name + '.xz')]:
                try:
                    os.unlink(f)
                except FileNotFoundError as e:
                    pass

    return 0


if __name__ == '__main__':
    sys.exit(main())
