# From Leo3418's GSoC 2021 work
# https://leo3418.github.io/2021/07/18/find-leaf-packages.html

import concurrent.futures
import os
import re
import subprocess
import sys

method="pkgcore"

def main() -> None:
    if len(sys.argv) > 1:
        repo = sys.argv[1]
    else:
        repo = 'gentoo'
    zero_in_degree = create_ebuild_dict(repo)
    with concurrent.futures.ThreadPoolExecutor(max_workers=os.cpu_count()) \
            as executor:
        for ebuild in zero_in_degree:
            # Let the executor run function call
            # update_for_deps_of(ebuild, zero_in_degree)
            if method == "pkgcore":
                executor.submit(update_for, ebuild, zero_in_degree, repo)
            else:
                executor.submit(update_for_deps_of, ebuild, zero_in_degree)

    # Print leaf ebuilds to standard output
    for ebuild in zero_in_degree:
        if zero_in_degree[ebuild]:
            print(ebuild)


def update_for(ebuild: str, zero_in_degree: dict, repo: str) -> None:
    """
    Update the boolean value for the specified ebuild in the given dictionary.
    Reverse dependencies of the ebuild will be searched in the specified
    repository only.
    """
    print(f"Processing {ebuild} ...", file=sys.stderr)
    proc = subprocess.run(f'pquery --first --restrict-revdep ={ebuild} '
                          f'--repo {repo} --raw --unfiltered',
                          capture_output=True, text=True, shell=True)
    zero_in_degree[ebuild] = len(proc.stdout) == 0

def create_ebuild_dict(repo: str) -> dict:
    """
    Create a dictionary with all ebuilds in the specified repository as keys
    that maps each key to a boolean value indicating whether it is a leaf
    ebuild with zero in-degree.
    """
    zero_in_degree = {}
    proc = subprocess.run(f'pquery --repo {repo} --raw --unfiltered',
                          capture_output=True, text=True,
                          shell=True, check=True)
    ebuilds = proc.stdout.splitlines()
    for ebuild in ebuilds:
        zero_in_degree[ebuild] = True
    return zero_in_degree


def update_for_deps_of(ebuild: str, zero_in_degree: dict) -> None:
    """
    For ebuilds that can be pulled as the specified ebuild's dependencies,
    update the boolean value for them in the given dictionary accordingly.
    """

    def get_dep_atoms() -> list:
        """
        Return a list of all dependency specification atoms.
        """
        dep_atoms = []
        equery_dep_atom_pattern = re.compile(r'\(.+/.+\)')
        proc = subprocess.run(f'equery -CN depgraph -MUl {ebuild}',
                              capture_output=True, text=True, shell=True)
        out_lines = proc.stdout.splitlines()
        for line in out_lines:
            dep_atom_match = equery_dep_atom_pattern.findall(line)
            dep_atom = [dep.strip('()') for dep in dep_atom_match]
            dep_atoms.extend(dep_atom)
        return dep_atoms

    def find_matching_ebuilds(atom: str) -> list:
        """
        Return a list of ebuilds that satisfy an atom.
        """
        proc = subprocess.run(f"equery list -op -F '$cpv' '{atom}'",
                              capture_output=True, text=True, shell=True)
        return proc.stdout.splitlines()

    #print(f"Processing {ebuild} ...", file=sys.stderr)

    # Get dependency specifications in the ebuild;
    # equivalent to dep_graph[ebuild] in the examples above
    dep_atoms = get_dep_atoms()

    # Convert list of atoms to list of ebuilds that satisfy them
    dep_ebuilds = []
    for dep_atom in dep_atoms:
        dep_ebuilds.extend(find_matching_ebuilds(dep_atom))

    # Register dependency ebuilds as non-leaves
    for dep_ebuild in dep_ebuilds:
        # An ebuild in an overlay might depend on ebuilds from ::gentoo and/or
        # other repositories, but we only care about ebuilds in the dictionary
        # passed to this function
        if dep_ebuild in zero_in_degree:
            zero_in_degree[dep_ebuild] = False


if __name__ == '__main__':
    main()

