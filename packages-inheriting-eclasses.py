#!/usr/bin/python

import collections, datetime, os, os.path, sys
import pkgcore.config # tested with pkgcore-0.7.7.8

def main(argv):
	try:
		outputdir = argv[1]
	except IndexError:
		print('Usage: %s output-directory/' % argv[0])
		return 1

	c = pkgcore.config.load_config()
	portdir = c.repo['portdir']

	output = collections.defaultdict(set)

	for p in portdir:
		for eclass in p.data['_eclasses_']:
			output[eclass].add('%s/%s\n' % (p.category, p.PN))

	try:
		os.mkdir(outputdir)
	except OSError:
		pass # XXX: removing old eclasses?

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

		<p>(tree synced at %s UTC)</p>

		<ul>
			%s
			<li><a href="/">/ (go back)</a></li>
		</ul>
	</body>
</html>''' % (max([len(e) for e in output]), datetime.datetime.fromtimestamp(c.syncer['sync:%s' % portdir.location].current_timestamp()), '\n'.join(['<li><a href="%s.txt">%s.eclass</a> (%d packages),</li>' % (e, e, len(output[e])) for e in sorted(output)])))
	f.close()

	return 0

if __name__ == '__main__':
	sys.exit(main(sys.argv))
