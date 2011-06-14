#!/usr/bin/perl

# Matt Turner <mattst88@gentoo.org/gmail.com>
# June 2010. For qa-reports.gentoo.org.

use strict;
use warnings;

use File::Find;

sub wanted {
	!-d && ((-z && print "empty  file: $File::Find::name\n")
		 || (-B && print "binary file: $File::Find::name\n"));
}

finddepth(\&wanted,  @ARGV);
