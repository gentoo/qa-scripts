#!/usr/bin/perl -w
# Copyright 1999-2011 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# Author: Christian (idl0r) Ruppert <idl0r@gentoo.org>

# perl ~/main.pl > ~/toparse; perl ~/make_hash.pl > ~/GDatabase.pm

use strict;
use XML::Parser;
use POSIX qw(strftime);

my $xml = new XML::Parser();

my %pkg = ();
my %foo = ();

my @fnames = undef;
my $pkg = undef;
my $cat = undef;
my $metadata = undef;
my $oldcat = '#';
my $size = undef;

my @mtainer = ();
my @herd = ();

my $inherd = 0;
my $inmtainer = 0;
my $inemail = 0;

sub start
{
	my $value = shift;
	my $tag = shift;

	if($tag =~ m/^herd$/)
	{
		$inherd = 1;
	}
	elsif($tag =~ m/^maintainer$/)
	{
		$inmtainer = 1;
	}
	elsif($tag =~ m/^email$/)
	{
		$inemail = 1;
	}
#	print "START: ${tag}\n";
}
sub end
{
	my $value = shift;
	my $tag = shift;

	if($tag =~ m/^herd$/)
	{
		$inherd = 0;
	}
	elsif($tag =~ m/^maintainer$/)
	{
		$inmtainer = 0;
	}
	elsif($tag =~ m/^email$/)
	{
		$inemail = 0;
	}
#	print "END: ${tag}\n";
}
sub content
{
	my $value = shift;
	my $content = shift;

	if($inmtainer eq 1 && $inemail eq 1)
	{
#		print "CONTENT: ${content}\n";
#		print "VALUE: ${value}\n";
		if($content =~ m/^(.+)\@gentoo\.org$/)
		{
			push(@mtainer, $1);
		}
		else
		{
			push(@mtainer, $content);
#			system("echo '${content}'>>~/FOOOOOOOOO");
		}
	}
	elsif($inherd eq 1)
	{
#		print "CONTENT: ${content}\n";
		push(@herd, $content);
	}
}

sub get_date()
{
	open(FH, "<", "/usr/portage/metadata/timestamp.chk");
	chomp(my $ts = <FH>);
	close(FH);

	return $ts;
}

$xml->setHandlers (Start => \&start, End => \&end, Char=>\&content );

open(TOPARSE, "<", ($ARGV[0] || "toparse") );
print "# Copyright 1999-".strftime("%Y", localtime)." Gentoo Foundation\n# Distributed under the terms of the GNU General Public License v2\n\n";
print "package GDatabase;\n\nuse strict;\nuse warnings;\n\nour \$VERSION = '1.00';\n\nuse base 'Exporter';\n\nour \@EXPORT = qw( %DB \$DBDATE );\n\n";
print "our \$DBDATE = 'Timestamp of DB: ".get_date()."';\n\n";
print "our %DB = (\n";

while(defined(my $line = <TOPARSE>))
{
	chomp($line);
	if($line =~ m/^\* (.+)\: (.*)$/)
	{
		$foo{$1} = $line;
	}
	else
	{
		printf STDERR "ERRORRRRR\n";
	}
}

foreach my $key (sort(keys(%foo)))
{
	my $line = $foo{$key};

	if($line =~ m/^\* (.+)\: (.*)$/)
	{
		($cat, $pkg) = split("/", $1, 2);
		@fnames = split(" ", $2);
		$metadata = "/usr/portage/${cat}/${pkg}/metadata.xml";

		if($cat ne $oldcat)
		{
			if($oldcat ne "#") { print "\t},\n"; }
			print "\t'${cat}' => {\n";
			$oldcat = $cat;
		}

		$xml->parsefile ($metadata);

		print "\t\t'${pkg}' => {\n";

		print "\t\t\t'herd' => [\n";
		foreach my $h (@herd)
		{
			print "\t\t\t\t'${h}',\n";
		}
		print "\t\t\t\],\n";

		print "\t\t\t'maintainer' => [\n";
		foreach my $m (@mtainer)
		{
			print "\t\t\t\t'${m}',\n";
		}
		print "\t\t\t\],\n";

		print "\t\t\t'files' => [\n";
		foreach my $fname (@fnames)
		{
			$size = int(-s "/usr/portage/${cat}/${pkg}/files/${fname}");

			if($size >= 1000000)
			{
				$size = (($size / 1024) / 1024);
				$size = sprintf("%0.2f MB", ${size});
				print "\t\t\t\t'${fname}:${size}',\n";
				next;
			}
			elsif($size >= 1000)
			{
				$size = ($size / 1024);
				$size = sprintf("%0.2f kB", ${size});
				print "\t\t\t\t'${fname}:${size}',\n";
				next;
			}
			else
			{
				$size = sprintf("%0.2f B", ${size});
				print "\t\t\t\t'${fname}:${size}',\n";
				next;
			}

#			print STDERR "ERRERRR\n";
		}
		print "\t\t\t\],\n";

		print "\t\t},\n";

		@mtainer = ();
		@herd = ();
	}
	else
	{
#		print STDERR "ERROR\n";
		exit(1);
	}
}
close(TOPARSE);
print "\t},\n);\n\n1;\n";
