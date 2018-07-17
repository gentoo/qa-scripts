#!/usr/bin/python

import portage

allpkgs=portage.db["/"]["porttree"].dbapi.cp_all()
bestpkgs={}
mycount=0

for x in allpkgs:
	if x not in list(bestpkgs.keys()):
		y=portage.db["/"]["porttree"].dbapi.xmatch("bestmatch-visible", x)
		bestpkgs[x]=y
		if y=="":
			continue
		xs=portage.pkgsplit(bestpkgs[x])
		print('%s %s %s' % (xs[0].split("/")[1], xs[1], bestpkgs[x]))
		mycount+=1
