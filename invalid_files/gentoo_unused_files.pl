#!/usr/bin/perl -wT
# Copyright 1999-2011 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# Author: Christian (idl0r) Ruppert <idl0r@gentoo.org>

use strict;

# The path where the GDatabase.pm is (Can be outside of the wwwroot)
use lib qw( /home/idl0r );

use Time::HiRes qw(gettimeofday tv_interval);
my $t0 = [gettimeofday];

use CGI;
use CGI::Carp qw(fatalsToBrowser warningsToBrowser);

my %DB = ();

use GDatabase;

%DB = %GDatabase::DB ? %GDatabase::DB : undef;

my $query = new CGI;
my $search = $query->param('search');

my $author = 'Christian Ruppert (idl0r) &lt;idl0r &lt;AT&gt; gentoo &lt;DOT&gt; org&gt;';
my $dbdate = $GDatabase::DBDATE ? $GDatabase::DBDATE : 'Timestamp of DB: not available.';


sub is_undef($)
{
	my $var = shift;

	if(defined($var) && (length($var) > 0))
	{
		return 0;
	}

	return 1;
}

sub error_search
{
	print "<br /><b>Oops, something went wrong! Sorry :(</b><br />\n";
}

sub table_start($)
{
	my $caption = shift;

	# <category> <package> <herd> <maintainer> <files>

	print <<_TABLE_START_;
			<br />
			<table border="1">
				<caption><b>Query: ${caption}</b></caption>
				<tr>
					<th>Category</th>
					<th>Package</th>
					<th>Herd</th>
					<th>Maintainer</th>
					<th>File</th>
					<th>Size</th>
				</tr>
_TABLE_START_
}

sub table_end()
{
	print "\t\t\t</table>\n\t\t\t<br />\n";
}

sub print_data(\%$$)
{
	my $hashref = shift;
	my $cat = shift;
	my $pkg = shift;

	my $i = 0;

	my %hash = %{$hashref};

	print "\t\t\t\t<tr>\n";
	print "\t\t\t\t\t<td>${cat}</td>\n";
	print "\t\t\t\t\t<td>${pkg}</td>\n";

	if( @{$hash{$cat}{$pkg}{'herd'}} eq 0 )
	{
		print "\t\t\t\t\t<td>no-herd</td>\n";
	}
	else
	{
		print "\t\t\t\t\t<td>".join("<br />", sort(@{$hash{$cat}{$pkg}{'herd'}}))."</td>\n";
	}

	if( @{$hash{$cat}{$pkg}{'maintainer'}} eq 0 )
	{
		if( @{$hash{$cat}{$pkg}{'herd'}} eq 0 )
		{
			print "\t\t\t\t\t<td>maintainer-needed</td>\n";
		}
		else
		{
			print "\t\t\t\t\t<td>-</td>\n";
		}
	}
	else
	{
		print "\t\t\t\t\t<td>".join("<br />", sort(@{$hash{$cat}{$pkg}{'maintainer'}}))."</td>\n";
	}

	print "\t\t\t\t\t<td>";
	$i = 0;
	foreach my $f (sort(@{$hash{$cat}{$pkg}{'files'}}))
	{
		$i++;
		my ($fname, $size) = split(":", $f, 2);

		print "${fname}";
		if($i < @{$hash{$cat}{$pkg}{'files'}})
		{
			print "<br />";
		}
	}
	print "</td>\n";

	print "\t\t\t\t\t<td>";
	$i = 0;
	foreach my $f (sort(@{$hash{$cat}{$pkg}{'files'}}))
	{
		$i++;
		my ($fname, $size) = split(":", $f, 2);

		print "${size}";
		if($i < @{$hash{$cat}{$pkg}{'files'}})
		{
			print "<br />";
		}
	}
	print "</td>\n";

	print "\t\t\t\t</tr>\n";
}

sub parse_data
{
	my ($maintainer, $herd) = @_;

	my $all = 0;
	my $noherd = 0;
	my $needed = 0;

	if( is_undef($maintainer) && is_undef($herd) ) {
		$all = 1;
		table_start("All");
	}
	elsif(!is_undef($maintainer) && ($maintainer =~ m/^\Qmaintainer-needed\E$/))
	{
		$needed = 1;
		$maintainer = 'maintainer-needed';
	}
	elsif(!is_undef($herd) && ($herd =~ m/^\Qno-herd\E$/))
	{
		$noherd = 1;
		$herd = "no-herd"
	}

	if(!is_undef($herd))
	{
		table_start("herd => ${herd}");
	}
	elsif(!is_undef($maintainer))
	{
		table_start("maintainer => ${maintainer}");
	}

	# <category> <package> <herd> <maintainer> <files>
	foreach my $cat (sort(keys(%DB)))
	{
		foreach my $pkg (sort(keys(%{$DB{$cat}})))
		{
			if($all eq 1)
			{
				# print all
				print_data(%DB, $cat, $pkg);
				next;
			}
			elsif(!is_undef($herd))
			{
				# print by herd

				# no-herd
				if($noherd eq 1)
				{
					if( @{$DB{$cat}{$pkg}{'herd'}} eq 0 || grep(/^\Q${herd}\E$/, @{$DB{$cat}{$pkg}{'herd'}}) )
					{
						print_data(%DB, $cat, $pkg);
					}
					next;
				}
				else
				{
					if( @{$DB{$cat}{$pkg}{'herd'}} > 0 && grep(/^\Q${herd}\E$/, @{$DB{$cat}{$pkg}{'herd'}}) )
					{
						print_data(%DB, $cat, $pkg);
					}
					next;
				}
			}
			elsif(!is_undef($maintainer))
			{
				# print by maintainer

				# no maintainer != maintainer-needed except there is also no-herd
				if($needed eq 1)
				{
					if ( (@{$DB{$cat}{$pkg}{'herd'}} eq 0 || grep(/^\Qno-herd\E$/, @{$DB{$cat}{$pkg}{'herd'}})) && (@{$DB{$cat}{$pkg}{'maintainer'}} eq 0 || grep(/^\Qmaintainer-needed\E$/, @{$DB{$cat}{$pkg}{'maintainer'}})) )
					{
						print_data(%DB, $cat, $pkg);
					}
					next;
				}
				elsif( @{$DB{$cat}{$pkg}{'maintainer'}} > 0 && grep(/^\Q${maintainer}\E$/,	@{$DB{$cat}{$pkg}{'maintainer'}}) )
				{
					print_data(%DB, $cat, $pkg);
				}
				next;
			}

			table_end();
			error_search();
			return;
		}
	}

	table_end();
}

sub get_data
{
	my $qry = shift;

	my $m = undef;
	my $h = undef;

	if(defined($qry) && length($qry) == 0)
	{
		parse_data(undef, undef);
		return;
	}
	elsif(defined($qry) && length($qry) >= 2)
	{
		if(length($qry) == 2 && $qry =~ m/^(mn|nh)$/)
		{
			if($qry =~ m/^mn$/)
			{
				parse_data("maintainer-needed", undef);
				return;
			}
			elsif($qry =~ m/^nh$/)
			{
				parse_data(undef, "no-herd");
				return;
			}
		}
		elsif($qry =~ m/^[mh]\:\w+(\-\w*)?$/)
		{
			($m, $h) = split(":", $qry, 2);

			if( (defined($m) && length($m) == 1) && (defined($h) && length($h) >= 1) )
			{
				if($m =~ m/^m$/)
				{
					parse_data($h, undef);
					return;
				}
				elsif($m =~ m/^h$/)
				{
					parse_data(undef, $h);
					return;
				}
			}
		}
	}

	error_search();
}

print "Content-Type: application/xhtml+xml\n\n";

print <<_HEADER_;
<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
	"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">

<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
	<head>
		<!--[if IE]>
			<meta http-equiv="refresh" content="0; URL=http://www.mozilla.com/firefox/" />
		<![endif]-->

		<meta name="author" content="Christian Ruppert (idl0r)" />
		<meta name="description" content="list _possible_ unused files from package files dirs" />
		<meta name="date" content="2009-08-16T00:00:00+02:00" />
		<meta name="robots" content="noindex" />
		<meta http-equiv="Content-Language" content="de" />
		<meta http-equiv="Content-Type" content="application/xhtml+xml; charset=utf-8" />
		<meta http-equiv="Content-Script-Type" content="application/x-www-form-urlencoded" />
		<!-- <meta http-equiv="Content-Style-Type" content="text/css" /> -->
		<meta http-equiv="expires" content="0" />

		<!--
		<style type="text/css">
			body { background-color:#000000; color:#008000; }
			a:link { color:#008000; }
			a:visited { color:#008000; }
			a:active { color:#008000; }
		</style>
		-->

		<title>list of _possible_ unused files from package files dirs</title>
	</head>
	<body>
		<h3>*** NOTE: THERE MIGHT BE FALSE-POSITIVES ***</h3>
_HEADER_

print <<_SEARCH_;
		<div>
			${dbdate}<br /><br />
			Search through the DB by: <b>herd</b>, <b>maintainer</b> or leave <b>empty</b> to view <b>all</b>.<br />
			Examples:<br />
			maintainer = m:idl0r<br />
			herd = h:perl<br />
			maintainer-needed: mn<br />
			no-herd: nh<br />

			<form action="gentoo_unused_files-beta.pl" method="get">
			<p>
				<input name="search" type="text" size="20" maxlength="30" />
				<input type="submit" value="Gimme!" />
			</p>
			</form>
_SEARCH_

if(defined($search))
{
	get_data($search);
}
else
{
	print"\t\t\t<br />\n";
}

my $elapsed = tv_interval($t0, [gettimeofday]);
print <<_BOTTOM_;
			<p>
				<a  href="http://validator.w3.org/check?uri=referer">
					<img style="border:0;width:88px;height:31px"
						src="http://www.w3.org/Icons/valid-xhtml10-blue"
						alt="Valid XHTML 1.0 Strict!" />
				</a>
				<!-- <a href="http://jigsaw.w3.org/css-validator/check/referer">
					<img style="border:0;width:88px;height:31px"
						src="http://jigsaw.w3.org/css-validator/images/vcss-blue"
						alt="CSS ist valide!" />
				</a> -->
			</p>

			<div style="text-align:right;">
				${author}
				<br />
				Page generated in ${elapsed} seconds.
			</div>

			<p>
				<a href="http://english-134423350361.spampoison.com">
					<img style="border:0;width:80px:height:15px"
						src="http://pics4.inxhost.com/images/sticker.gif"
						alt="Fight Spam! Click Here!"/>
				</a>
			</p>
		</div>
	</body>
</html>
_BOTTOM_
