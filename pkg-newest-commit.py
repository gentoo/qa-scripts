#!/usr/bin/env python

import argparse
import glob
import os
import subprocess
import sys


def main(argv):
    argp = argparse.ArgumentParser(prog=argv[0])
    argp.add_argument('package', nargs='*',
                      help='List of packages to find (defaults to all)')
    args = argp.parse_args(argv[1:])

    packages = set(args.package)
    if not packages:
        with open('profiles/categories') as f:
            for cat in f:
                packages.update(x.rstrip('/')
                        for x in glob.glob('{}/*/'.format(cat.strip())))

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
                print('{:.<65} {} {}'.format(pkg + ' ', date, commit))
                packages.remove(pkg)
                if not packages:
                    break


if __name__ == '__main__':
    sys.exit(main(sys.argv))
