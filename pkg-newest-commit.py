#!/usr/bin/env python

import argparse
import glob
import os
import os.path
import subprocess
import sys


def main(argv):
    argp = argparse.ArgumentParser(prog=argv[0])
    argp.add_argument('--git-dir', default='.',
                      help='Path to repo git clone (used for git log)')
    argp.add_argument('--work-dir', default='.',
                      help='Path to repo working directory (used to grab '
                           'package list when no packages specified)')
    argp.add_argument('package', nargs='*',
                      help='List of packages to find (defaults to all)')
    args = argp.parse_args(argv[1:])

    packages = set(args.package)
    if not packages:
        with open(os.path.join(args.work_dir, 'profiles/categories')) as f:
            for cat in f:
                packages.update('/'.join(x.rsplit('/', 3)[-3:-1])
                                for x in glob.glob(os.path.join(
                                    args.work_dir, cat.strip(), '*/')))
    if not packages:
        print('No packages specified or found', file=sys.stderr)
        return 1
    pkg_max_len = max(len(x) for x in packages)
    pkg_format = '{{:.<{}}} {{}} {{}}'.format(pkg_max_len+1)

    excludes = frozenset([
        # specify EAPI=0 explicitly
        '4a409a1ecd75d064e8b471f6131bb1feb83c37a8',
        # drop $id
        '61b861acd7b49083dab687e133f30f3331cb7480',
        # initial git commit
        '56bd759df1d0c750a065b8c845e93d5dfa6b549d',
    ])

    os.environ['TZ'] = 'UTC'
    s = subprocess.Popen(['git', 'log', '--date=iso-local', '--name-only',
                          '--diff-filter=AM', '--no-renames',
                          '--pretty=COMMIT|%H|%cd', '**.ebuild'],
                         cwd=args.git_dir,
                         stdout=subprocess.PIPE)
    for l in s.stdout:
        l = l.decode('utf8').strip()
        if l.startswith('COMMIT|'):
            commit_data = l[7:]
        elif l:
            pkg = '/'.join(l.split('/', 2)[:2])
            if pkg in packages:
                commit, date = commit_data.split('|')
                if commit in excludes:
                    continue
                print(pkg_format.format(pkg + ' ', date, commit))
                packages.remove(pkg)
                if not packages:
                    break


if __name__ == '__main__':
    sys.exit(main(sys.argv))
