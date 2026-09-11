#!/usr/bin/env python3
# Copyright 1999-2026 Gentoo Authors
# Distributed under the terms of the GNU General Public License v2

# python mask_check.py $(find /usr/portage/profiles -type f -name '*.mask' -not -regex '.*/prefix/.*')

import re
from pathlib import Path
from sys import argv, stderr
from time import gmtime, strftime

from lxml.etree import parse
from portage import settings
from portage.versions import pkgsplit, vercmp

OPERATORS = (">", "=", "<", "~")


def strip_atoms(pkg: str) -> str:
    # strip slots
    if ":" in pkg:
        pkg = pkg[: pkg.find(":")]

    while pkg.startswith(OPERATORS) and len(pkg) > 1:
        pkg = pkg[1:]
    while pkg.endswith(("*", ".")):
        pkg = pkg[:-1]

    return pkg


def pkgcmp_atom(pkgdir: Path, pkg: str) -> bool:
    ebuilds = [ent.name for ent in pkgdir.iterdir() if ent.name.endswith(".ebuild")]

    ppkg = Path(strip_atoms(pkg)).name

    revre = re.compile(f"^{re.escape(ppkg)}(-r\\d+)?.ebuild$")

    for ebuild in ebuilds:
        # workaround? for - prefix
        pkg = pkg.removeprefix("-")

        if pkg.startswith(("=", "~")):
            if pkg.startswith("~"):
                if revre.match(ebuild):
                    return True
                continue
            if pkg.endswith("*"):
                if ebuild.startswith(ppkg):
                    return True
                continue
            if ebuild == (ppkg + ".ebuild"):
                return True
            continue

        if pkg.startswith((">=", ">", "<=", "<")):
            plain = strip_atoms(pkg)

            mypkg = pkgsplit(plain)
            ourpkg = pkgsplit(ebuild.removesuffix(".ebuild"))

            mypkgv = mypkg[1]
            if mypkg[2] != "r0":
                mypkgv = f"{mypkgv}-{mypkg[2]}"

            ourpkgv = ourpkg[1]
            if ourpkg[2] != "r0":
                ourpkgv = f"{ourpkgv}-{ourpkg[2]}"

            if pkg.startswith(">="):
                if vercmp(mypkgv, ourpkgv) <= 0:
                    return True
            elif pkg.startswith(">"):
                if vercmp(mypkgv, ourpkgv) < 0:
                    return True
            elif pkg.startswith("<="):
                if vercmp(mypkgv, ourpkgv) >= 0:
                    return True
            elif pkg.startswith("<"):
                if vercmp(mypkgv, ourpkgv) > 0:
                    return True
                continue

    return False


def check_locuse(portdir: Path, pkg: str, invalid: list[str]) -> list[str]:
    ppkg = pkgsplit(strip_atoms(pkg))
    ppkg = ppkg[0] if ppkg else strip_atoms(pkg)

    tree = parse(portdir / ppkg / "metadata.xml")
    root = tree.getroot()
    locuse = [use.get("name") for elem in root if elem.tag == "use" for use in elem]

    return [iuse for iuse in invalid if iuse not in locuse]


def check_use(portdir: Path, line: str):
    # use.desc
    # <flag> - <description>
    useflags = [
        useflag.removeprefix("-")
        for useflag in line.split(" ")[1:]
        # get a rid of malformed stuff e.g.:
        # app-text/enchant        zemberek
        if useflag
    ]

    pkg = line.split(" ")[0]

    usedescs = [portdir / "profiles/use.desc"]
    usedescs.extend(
        entry
        for entry in (portdir / "profiles/desc").iterdir()
        if entry.is_file() and entry.suffix == ".desc"
    )

    globuse = set()
    for usedesc_f in usedescs:
        with usedesc_f.open() as usedesc_fd:
            for desc_line in usedesc_fd:
                desc_line = desc_line.rstrip().replace("\t", " ").lstrip()

                if not desc_line or desc_line.startswith("#"):
                    continue

                flag = desc_line.split(" - ")[0]
                if usedesc_f.name != "use.desc":
                    flag = f"{usedesc_f.stem}_{flag}"
                globuse.add(flag)

    invalid = [flag for flag in useflags if flag not in globuse]

    # check metadata.xml
    if invalid:
        invalid = check_locuse(portdir, pkg, invalid)

    return (pkg, invalid) if invalid else None


# <cat>/<pkg> <use> ...
def check_pkg(portdir: Path, line: str) -> bool:
    pkgm = line.split(" ")[0].removeprefix("-")

    if pkgm.startswith(OPERATORS):
        plain_pkg = strip_atoms(pkgm)

        pkg = pkgsplit(plain_pkg)
        if not pkg:
            print(
                "Error encountered during pkgsplit(), please contact idl0r@gentoo.org including the whole output!",
                file=stderr,
            )
            print(f"1: {pkgm}; 2: {plain_pkg}", file=stderr)
            return False

        plain_pkg = strip_atoms(pkg[0])
        pkgdir = portdir / plain_pkg

        if not pkgdir.is_dir():
            return False

        return pkgcmp_atom(pkgdir, pkgm)

    if ":" in pkgm:
        pkgm = strip_atoms(pkgm)
    return (portdir / pkgm).is_dir()


def get_timestamp() -> str:
    timestamp_f = Path(settings["PORTDIR"]) / "metadata/timestamp.chk"
    try:
        timestamp = timestamp_f.read_text().splitlines()[0].rstrip()
    except (OSError, IndexError):
        return "Unknown"

    return timestamp or "Unknown"


def obsolete_pmask(
    portdir: Path | str | None = None, package_mask: Path | str | None = None
) -> None:
    invalid_entries = []

    portdir = Path(portdir or settings["PORTDIR"])
    package_mask = (
        Path(package_mask) if package_mask else portdir / "profiles/package.mask"
    )

    with package_mask.open() as pmask:
        for line in pmask:
            line = line.strip()

            if not line or line.startswith("#"):
                continue

            # Skip sys-freebsd
            if "sys-freebsd" in line:
                continue

            line = line.replace("\t", " ")

            # don't check useflags with check_pkg
            if "/" in line and not check_pkg(portdir, line):
                invalid_entries.append(line)
            else:
                invalid_use = check_use(portdir, line)
                if invalid_use:
                    invalid_entries.append(invalid_use)

    if invalid_entries:
        print(
            f"Found {len(invalid_entries)} invalid/obsolete entries in {package_mask}:"
        )
        for invalid in invalid_entries:
            if isinstance(invalid, tuple):
                print(invalid[0], invalid[1])
            else:
                print(invalid)
        print()


if __name__ == "__main__":
    print(
        "A list of invalid/obsolete package.mask entries in gentoo repository, see bug 105016"
    )
    print(f"Generated on: {strftime('%a %b %d %H:%M:%S %Z %Y', gmtime())}")
    print(f"Timestamp of tree: {get_timestamp()}")
    print("NOTE: if a package is listed as <category>/<package> <flag> ...")
    print("\tor <category>/<package> then the whole entry is invalid/obsolete.")
    print(
        "NOTE: if a package is listed as <category>/<package> [ <flag>, ... ] then the listed useflags are invalid."
    )
    print()

    if len(argv) > 1:
        for _pmask in argv[1:]:
            obsolete_pmask(package_mask=_pmask)
    else:
        obsolete_pmask()
