#!/usr/bin/env python3

import sys
from pathlib import Path

import pkgcore.config


def main(argv: list[str]) -> int:
    try:
        outputdir = Path(argv[1])
    except IndexError:
        print(f"Usage: {argv[0]} output-directory/")
        return 1

    config = pkgcore.config.load_config()
    repo = config.objects.repo["gentoo"]

    # initiate with all eclasses
    # (this also ensures we know eclasses that have no packages)
    output: dict[str, set[str]] = {
        eclass: set() for eclass in repo.eclass_cache.eclasses
    }
    for pkg in repo:
        for eclass in pkg.inherited:
            output[eclass].add(pkg.key)

    existed = outputdir.exists()
    outputdir.mkdir(exist_ok=True)
    if existed:
        # remove stale output files
        for f in outputdir.glob("*.txt"):
            if f.stem not in output:
                f.unlink()

    for eclass, packages in output.items():
        text = "".join(f"{pkg}\n" for pkg in sorted(packages))
        (outputdir / f"{eclass}.txt").write_text(text)

    width = max(len(eclass) for eclass in output)
    entries = "\n\t\t\t".join(
        f'<li><a href="{eclass}.txt">{eclass}.eclass</a> ({len(output[eclass])} packages),</li>'
        for eclass in sorted(output)
    )
    (outputdir / "index.html").write_text(f"""<!DOCTYPE html>
<html>
\t<head>
\t\t<style type="text/css">
\t\t\tli a {{ font-family: monospace; display: block; float: left; min-width: {width}em; }}
\t\t</style>
\t\t<title>Packages inheriting eclasses</title>
\t</head>
\t<body>
\t\t<h1>Packages inheriting eclasses</h1>

\t\t<ul>
\t\t\t{entries}
\t\t\t<li><a href="/">/ (go back)</a></li>
\t\t</ul>
\t</body>
</html>""")

    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
