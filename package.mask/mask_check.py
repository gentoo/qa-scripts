#!/usr/bin/env python
# Copyright 1999-2011 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2

# python mask_check.py $(find /usr/portage/profiles -type f -name '*.mask' -not -regex '.*/prefix/.*')

import re

from lxml import etree
from os.path import join, isfile, isdir, basename
from os import listdir
from sys import stderr, argv
from time import strftime, gmtime

from portage import settings
from portage.versions import pkgsplit, vercmp

OPERATORS = (">", "=", "<", "~")

def strip_atoms(pkg):
	while pkg.startswith( OPERATORS ) and len(pkg) > 1:
		pkg = pkg[1:]
	while pkg.endswith( ("*", ".") ):
		pkg = pkg[0:-1]

	# strip slots
	if pkg.find(":") != -1:
		pkg = pkg[0:pkg.find(":")]
	return pkg

# Deprecated
def strip_atoms2(pkg):
	while pkg.startswith( OPERATORS ) and len(pkg) > 1:
		pkg = pkg[1:]
	while pkg.endswith( "*" ):
		pkg = pkg[0:-1]

	return pkg

def pkgcmp_atom(pkgdir, pkg):
	ebuilds = []

	for ent in listdir(pkgdir):
		if ent.endswith(".ebuild"):
			ebuilds.append(ent)

	ppkg = basename(strip_atoms(pkg))

	# test
	ppkg2 = basename(strip_atoms2(pkg))
	if ppkg != ppkg2:
		print >> stderr, "PPKG: %s" % ppkg
		print >> stderr, "PPKG2: %s" % ppkg2

	revre = re.compile( ("^" + re.escape(ppkg) + "(-r\d+)?.ebuild$") )

#	print "DBG: checking for %s" % pkg
#	print "DBG: Got %i ebuilds:" % len(ebuilds)
#	print ebuilds

	for ebuild in ebuilds:
		# workaround? for - prefix
		if pkg.startswith( "-" ):
			pkg = pkg[1:]

		if pkg.startswith( ("=", "~") ):
			if pkg.startswith("~"):
				if revre.match(ebuild):
#					print "DBG: revmatch '%s' '%s'" % (pkg, ebuild)
					return 1
				else:
#					print "DBG: revmatch continue"
					continue
			if pkg.endswith("*"):
				if ebuild.startswith(ppkg):
#					print "DBG: startswith '%s' '%s'" % (pkg, ebuild)
					return 1
				else:
#					print "DBG: startswith continue"
					continue
			else:
				if ebuild == (ppkg + ".ebuild"):
#					print "DBG: '%s' == '%s'" % (ppkg, ppkg)
					return 1
				else:
#					print "DBG: == continue"
					continue

		if pkg.startswith( (">=", ">", "<=", "<") ):
			plain = strip_atoms(pkg)

			mypkg = pkgsplit(plain)
			ourpkg = pkgsplit(ebuild.rstrip(".ebuild"))

			mypkgv = mypkg[1]
			if mypkg[2] != "r0":
				mypkgv = mypkgv + "-" + mypkg[2]

			ourpkgv = ourpkg[1]
			if ourpkg[2] != "r0":
				ourpkgv = ourpkgv + "-" + ourpkg[2]

#			print "MYPKGV:", mypkgv, "OURPKGV:", ourpkgv, "RESULT 'vercmp('%s', '%s'): %i" % (mypkgv, ourpkgv, vercmp(mypkgv, ourpkgv))

			if pkg.startswith(">="):
				if vercmp(mypkgv, ourpkgv) <= 0:
#					print "HIT: '%s' >= '%s'" % (ourpkg, mypkg)
					return 1
				else:
#					print ">= continue"
					continue
			if pkg.startswith(">") and not pkg.startswith(">="):
				if vercmp(mypkgv, ourpkgv) < 0:
#					print "HIT: '%s' > '%s'" % (ourpkg, mypkg)
					return 1
				else:
#					print "> continue"
					continue
			if pkg.startswith("<="):
				if vercmp(mypkgv, ourpkgv) >= 0:
#					print "HIT: '%s' <= '%s'" % (ourpkg, mypkg)
					return 1
				else:
#					print "<= continue"
					continue
			if pkg.startswith("<") and not pkg.startswith("<="):
				if vercmp(mypkgv, ourpkgv) > 0:
#					print "HIT: '%s' < '%s'" % (ourpkg, mypkg)
					return 1
				else:
#					print "< continue"
					continue

#	print "Nothing found... '%s' is invalid" % pkg
	return 0

def check_locuse(portdir, pkg, invalid):
	locuse = []

	ppkg = pkgsplit(strip_atoms(pkg))

	if ppkg:
		ppkg = ppkg[0]
	else:
		ppkg = strip_atoms(pkg)

	metadata = join(portdir, ppkg, "metadata.xml")

	tree = etree.parse(metadata)
	root = tree.getroot()
	for elem in root:
		if elem.tag == "use":
			for use in elem:
				locuse.append(use.get("name"))

	# create a _NEW_ list
	oldinvalid = [foo for foo in invalid]
	for iuse in oldinvalid:
		if iuse in locuse:
			invalid.remove(iuse)

	return invalid

def check_use(portdir, line):
	# use.desc
	# <flag> - <description>
	usedescs = [join(portdir, "profiles/use.desc")]
	globuse = []
	invalid = []
	useflags = []

	for useflag in line.split(" ")[1:]:
		# get a rid of malformed stuff e.g.:
		# app-text/enchant        zemberek
		if len(useflag) > 0:
			if useflag.startswith("-"):
				useflag = useflag[1:]
			useflags.append(useflag)

	pkg = line.split(" ")[0]

	# Add other description file
	for entry in listdir(join(portdir, "profiles/desc")):
		entry = join(portdir, "profiles/desc", entry)
		if isfile(entry) and entry.endswith(".desc"):
			usedescs.append(entry)

	for usedesc_f in usedescs:
		usedesc_fd = open(usedesc_f, "r")

		for line in usedesc_fd:
			line = line.rstrip()
			line = line.replace("\t", " ")

			if len(line) == 0:
				continue

			while line[0].isspace():
				if len(line) > 1:
					line = line[1:]
				else:
					break

			if line.startswith("#"):
				continue
			_flag = line.split(" - ")[0]

			if usedesc_f == join(portdir, "profiles/use.desc"):
				globuse.append(line.split(" - ")[0])
			else:
				_flag = "%s_%s" % (basename(usedesc_f).replace(".desc", ""), _flag)
				globuse.append(_flag)
#				print "GLOB: ", _flag

		usedesc_fd.close()

#	print globuse
#	exit(1)

	for flag in useflags:
		if not flag in globuse:
			# nothing found
			invalid.append(flag)
#			print "Add useflag %s" %flag

	# check metadata.xml
	if invalid:
		invalid = check_locuse(portdir, pkg, invalid)


#	print portdir, pkg, useflags
#	print globuse

	if invalid:
		return (pkg, invalid)
	else:
		return None

# <cat>/<pkg> <use> ...
def check_pkg(portdir, line):
#	print "PKGM1:", line
	pkgm = line.split(" ")[0]
#	print "PKGM2:", pkgm
#	print "DBG:", line.split(" ")

	if pkgm.startswith("-"):
		pkgm = pkgm[1:]

	if pkgm.startswith(OPERATORS):
		pkg = []
#		print "DBG1: %s" % pkgm
		plain_pkg = strip_atoms(pkgm)
#		print "DBG2: %s" % plain_pkg

		pkg = pkgsplit(plain_pkg)
		if not pkg:
			print >> stderr, "Error encountered during pkgsplit(), please contact idl0r@gentoo.org including the whole output!"
			print >> stderr, "1: %s; 2: %s" % (pkgm, plain_pkg)
			return 0

		plain_pkg = strip_atoms(pkg[0])

		if not isdir(join(portdir, plain_pkg)):
			return 0

		if not pkgcmp_atom(join(portdir, plain_pkg), pkgm):
			return 0

		return 1
	else:
		if pkgm.find(":") != -1:
			pkgm = strip_atoms(pkgm)
		if isdir(join(portdir, pkgm)):
			return 1
		else:
			return 0

	return 0

def get_timestamp():
	timestamp_f = join(settings["PORTDIR"],	"metadata/timestamp.chk")
	timestamp = open(timestamp_f).readline().rstrip()
	if len(timestamp) < 1:
		return "Unknown"

	return timestamp

def obsolete_pmask(portdir = None, package_mask=None):
	invalid_entries = []

	if not portdir:
		portdir = settings["PORTDIR"]

	if not package_mask:
		package_mask = join(portdir, "profiles/package.mask")

	pmask = open(package_mask, "r")

	for line in pmask:
		line = line.rstrip()

		if len(line) == 0:
			continue

		while line[0].isspace():
			if len(line) > 1:
				line = line[1:]
			else:
				break

		if line.startswith("#"):
			continue

		# Skip sys-freebsd
		if line.find("sys-freebsd") != -1:
			continue

		line = line.replace("\t", " ")

		# don't check useflags with check_pkg
		if line.find("/") != -1 and not check_pkg(portdir, line):
#			print "Add whole entry: '%s'" % line
			invalid_entries.append(line)
		else:
			invalid_use = check_use(portdir, line)
			if invalid_use:
#				print "Add useflags: '%s %s'" % (invalid_use[0], invalid_use[1])
				invalid_entries.append(invalid_use)

	pmask.close()

	if invalid_entries:
		print "Found %i invalid/obsolete entries in %s:" % (len(invalid_entries), package_mask)
		for invalid in invalid_entries:
			if isinstance(invalid, tuple):
				print invalid[0], invalid[1]
			else:
				print invalid
		print ""

if __name__ == "__main__":
	print "A list of invalid/obsolete package.mask entries in gentoo-x86, see bug 105016"
	print "Generated on: %s" % strftime( "%a %b %d %H:%M:%S %Z %Y", gmtime() )
	print "Timestamp of tree: %s" % get_timestamp()
	print "NOTE: if a package is listed as <category>/<package> <flag> ..."
	print "	or <category>/<package> then the whole entry is invalid/obsolete."
	print "NOTE: if a package is listed as <category>/<package> [ <flag>, ... ] then the listed useflags are invalid."
	print ""

	if len(argv) > 1:
		for _pmask in argv[1:]:
			obsolete_pmask(package_mask=_pmask)
	else:
		obsolete_pmask()
