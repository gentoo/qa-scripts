#!/usr/bin/python

import datetime, os, os.path, sys
import pkgcore.config # tested with pkgcore-0.9.2

def main(argv):
	try:
		outputdir = argv[1]
	except IndexError:
		print('Usage: %s output-directory/' % argv[0])
		return 1

	c = pkgcore.config.load_config()
	portdir = c.repo['gentoo']

	output = {}
	# initiate with all eclasses
	# (this also ensures we know eclasses that have no packages)
	for k in portdir.eclass_cache.eclasses:
		output[k] = set()

	for p in portdir:
		for eclass in p.data.get('_eclasses_', ()):
			output[eclass].add('%s/%s\n' % (p.category, p.PN))

	try:
		os.mkdir(outputdir)
	except OSError:
		# remove stale output files
		for f in os.listdir(outputdir):
			if f.endswith('.txt') and f[:-4] not in output:
				os.remove(os.path.join(outputdir, f))

	os.chdir(outputdir)
	for eclass in output:
		f = open('%s.txt' % eclass, 'w')
		f.writelines(sorted(output[eclass]))
		f.close()

	f = open('index.html', 'w')
	f.write('''<!DOCTYPE html>
<html>
	<head>
		<style type="text/css">
			li a { font-family: monospace; display: block; float: left; min-width: %dem; }
		</style>
		<title>Packages inheriting eclasses</title>
	</head>
	<body>
		<h1>Packages inheriting eclasses</h1>

		<ul>
			%s
			<li><a href="/">/ (go back)</a></li>
		</ul>
	</body>
</html>''' % (max([len(e) for e in output]), '\n'.join(['<li><a href="%s.txt">%s.eclass</a> (%d packages),</li>' % (e, e, len(output[e])) for e in sorted(output)])))
	f.close()

	return 0

if __name__ == '__main__':
	sys.exit(main(sys.argv))
