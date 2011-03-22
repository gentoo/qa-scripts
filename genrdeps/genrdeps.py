#!/usr/bin/python
# Pepper and solar..

import os, sys, types

os.environ["PORTDIR_OVERLAY"]=""
import portage, portage.dep

def processDeps(deps,use=""):
	returnMe=[]
	for (index,x) in enumerate(deps):
		if type(x)==types.ListType:
			continue
		elif x=="||":
			returnMe.extend(processDeps(deps[index+1],use))
		elif x[-1]=="?":
			returnMe.extend(processDeps(deps[index+1],"+".join(x for x in (use,x[:-1]) if x)))
		elif x[0]=="!":
			returnMe.append((portage.dep_getkey(x),"[B]",use))
		else:
			returnMe.append((portage.dep_getkey(x),"",use))
	return returnMe

revdeps = {}
for cpv in portage.portdb.cpv_all():
	try:
		deps = processDeps(portage.dep.paren_reduce(portage.portdb.aux_get(cpv, [sys.argv[1]])[0]))
	except:
		continue

	for dep in deps:
		if dep[0] not in revdeps:
			revdeps[dep[0]] = []
		revdeps[dep[0]].append((cpv, dep[1], dep[2] and ":"+dep[2]))

dirs = []
for cp in revdeps:
    c = cp.split("/")[0]
    if c not in dirs:
        os.makedirs(c)
        dirs.append(c)

    revdeps[cp].sort()
    f = open(cp, "w")
    f.write("\n".join([ b+cpv+use for (cpv,b,use) in revdeps[cp] ])+"\n")
    f.close()
