#!/usr/bin/env python

import os
import sys
import portage

if len(sys.argv) != 2 or not portage.isvalidatom(sys.argv[1]):
	sys.stderr.write("usage: %s <atom>\n" % os.path.basename(sys.argv[0]))
	sys.exit(1)

input_atom = portage.dep.Atom(sys.argv[1])
settings = portage.config(config_profile_path="",
	local_config=False)
settings["ACCEPT_KEYWORDS"] = "**"
settings.backup_changes("ACCEPT_KEYWORDS")
settings.lock()
porttree = portage.portagetree(settings=settings)
portdb = porttree.dbapi
trees = {"/" : {"porttree":porttree}}
dep_keys = ("DEPEND", "RDEPEND", "PDEPEND")

for cp in portdb.cp_all():
	for cpv in portdb.cp_list(cp):
		metadata = dict(zip(dep_keys,
			portdb.aux_get(cpv, dep_keys)))
		dep_str = " ".join(metadata[k] for k in dep_keys)
		success, atoms = portage.dep_check(dep_str,
			None, settings, use="all",
			trees=trees, myroot=settings["ROOT"])

		if not success:
			sys.stderr.write("%s %s\n" % (cpv, atoms))
		else:
			bad_atoms = []
			for atom in atoms:
				if not atom.blocker and atom.cp == input_atom.cp:
					matches = portdb.xmatch("match-all", atom)
					if not portage.dep.match_from_list(input_atom, matches):
						bad_atoms.append(atom)
			if bad_atoms:
				sys.stdout.write("%s\t%s\n" % (cpv, " ".join(bad_atoms)))
