#!/usr/bin/perl -w
# Copyright 1999-2011 Gentoo Foundation
# Distributed under the terms of the GNU General Public License v2
# Author: Christian (idl0r) Ruppert <idl0r@gentoo.org>

# perl ~/main.pl > ~/toparse; perl ~/make_hash.pl > ~/GDatabase.pm

use Time::HiRes qw(gettimeofday tv_interval);
#my $t0 = [gettimeofday];

use threads;
use strict;
use File::Util;
use File::Basename;

our $PORTDIR = "/usr/portage";
our $CATEGORIES = "${PORTDIR}/profiles/categories";

my($f) = File::Util->new();

our $t0;
sub profile {
	my $state = shift;
	my $msg = shift;

	if($state eq "set") {
		$t0 = [gettimeofday];
	}
	elsif($state eq "show") {
		printf STDERR "DEBUG: Profile: %s took %f seconds\n", $msg ? $msg : "", tv_interval($t0, [gettimeofday]);
	}
}

sub ververify($) {
	my $version = shift;

	if($version =~ m/^(cvs\.)?(\d+)((\.\d+)*)([a-z]?)((_(pre|p|beta|alpha|rc)\d*)*)(-r(\d+))?$/) {
		return 1;
	}

	return 0;
}

sub pkgsplit($) {
	my $cpvr = shift;

	my $revok = 0;
	my $verPos = 0;

	my $revision = undef;

	my @pkg = ();
	my @myparts = ();

	@myparts = split("-", $cpvr);

	if($#myparts < 1) {
		print STDERR "!!! Name error in ${cpvr}: missing a version or name part.\n";
		return undef;
	}

	$revok = 0;
	$revision = $myparts[-1];

	if(length($revision) and substr($revision, 0, 1) eq "r") {
		if($revision =~ m/\d+/) {
			$revok = 1;
		}
	}

	if($revok eq 1) {
		$verPos = -2;
		$revision = $myparts[-1];
	}
	else {
		$verPos = -1;
		$revision = "r0";
	}

	if(ververify($myparts[$verPos]) eq 1) {
		if($revok eq 1) {
			$pkg[2] = pop(@myparts);
		}
		else {
			$pkg[2] = $revision;
		}
		$pkg[1] = pop(@myparts);
		$pkg[0] = join("-", @myparts);

		return @pkg;
	}

	return undef;
}

sub get_categories($) {
	my $categories_f = shift;
	my @categories = ();

	open(CATEGORIES, "<", $categories_f);
	while(defined(my $line = <CATEGORIES>)) {
		chomp($line);
		$line =~ s/^\s*//g;
		$line =~ s/\s*$//g;

		next if $line =~ m/^#/;

		push(@categories, $line);
	}
	close(CATEGORIES);

	return @categories;
}

sub check_category($) {
	my $category = shift;

	$SIG{'KILL'} = sub { threads->exit(); };

#	print "Thread started for category $category\n";
#	threads->exit();
#	return;

#	return if $category ne "dev-db"; # FIXME

	foreach my $candidate ($f->list_dir( "${PORTDIR}/${category}", "--dirs-only", "--no-fsdots", "--with-paths" )) {
		next if ! -d "${candidate}/files";

#		next if $candidate !~ m/postgresql-server/;

		my @myfiles = ();
		my $mypkgdir = $candidate;
		my @myebuilds = ();
		my @notfound = ();
		my @found = ();

		foreach my $file ($f->list_dir("${candidate}/files", "--files-only", "--recurse", "--no-fsdots")) {
			$file =~ s/\Q${candidate}\/files\/\E//;
			push(@myfiles, $file);
			push(@notfound, $file);
		}

		foreach my $file ($f->list_dir($candidate, "--files-only", "--no-fsdots", '--pattern=\.ebuild$')) {
			$file =~ s/\Q${candidate}\/\E//;
			push(@myebuilds, $file);
		}

		if($#myfiles eq -1) {
			print STDERR "empty files dir found: ${candidate}/files\n";
			next;
		}
		if($#myebuilds eq -1) {
			print STDERR "empty package dir found: ${candidate}\n";
			next;
		}

		foreach my $ebuild (@myebuilds) {
			last if $#notfound eq $#found;

			my $cpvr = $ebuild;
			$cpvr =~ s/\.ebuild$//;

			my @PKG = pkgsplit($cpvr);
			my %possible = ();

			my $P = "${PKG[0]}-${PKG[1]}";
			my $PN = $PKG[0];
			my $PV = $PKG[1];
			my $PR = $PKG[2];
			my $PVR = "";

			if( $PR =~ m/^r0$/) {
				$PVR = $PV;
			}
			else {
				$PVR = "${PV}-${PR}";
			}

			my $PF = "${PN}-${PVR}";
			my $FILESDIR = "${candidate}/files";
			my %INHERIT;

			# Export ebuild variables for source.sh
			my $exports = sprintf('export P=%s; export PN=%s; export PV=%s; export PR=%s; export PVR=%s; export PF=%s;', $P, $PN, $PV, $PR, $PVR, $PF);
#			$ENV{P} = $P;
#			$ENV{PN} = $PN;
#			$ENV{PV} = $PV;
#			$ENV{PR} = $PR;
#			$ENV{PVR} = $PVR;
#			$ENV{PF} = $PF;

			open(my $ebuild_fh, '-|', "${exports} bash ./source.sh ${candidate}/${ebuild}");
			chomp(my $MY_P = <$ebuild_fh>);
			chomp(my $MY_PV = <$ebuild_fh>);
			chomp(my $MY_PN = <$ebuild_fh>);
			chomp(my $SLOT = <$ebuild_fh>);
			chomp(my $inherit = <$ebuild_fh>);
			close($ebuild_fh);

			foreach my $inh (split(/\s+/, $inherit)) {
				$INHERIT{$inh} = 1;
			}

			foreach my $file (@myfiles) {
				last if $#notfound eq $#found;

				# possible
				$possible{$file} = [];
				my $newfile = $file;
				push(@{$possible{$file}}, $file);

				if(dirname($newfile) =~ m/^\.$/) {
					while(! dirname($newfile) =~ m/^\.$/) {
						$newfile = basename($newfile);
					}
					push(@{$possible{$file}}, $newfile);
				}

				my $tmp = $newfile;

				# Skip vdr stuff
				if(($newfile eq "rc-addon.sh" or $newfile eq "confd") and defined($INHERIT{"vdr-plugin"})) {
					push(@found, $file);
					next;
				}

				# cannadict
				if(defined($INHERIT{"cannadic"}) and $newfile =~ m/.*.dics.dir$/) {
					push(@found, $file);
					next;
				}

				# java...
				if(defined($INHERIT{"java-vm-2"}) && $newfile =~ m/${PN}-${SLOT}\.env$/ || $newfile =~ m/${PN}.env$/) {
					push(@found, $file);
					next;
				}

				if($newfile =~ m/\Q${MY_P}\E/) {
					$tmp = $newfile;
					$tmp =~ s/\Q${MY_P}\E/\${MY_P}/;
					push(@{$possible{$file}}, $tmp);
				}
				if($newfile =~ m/\Q${MY_PV}\E/) {
					$tmp = $newfile;
					$tmp =~ s/\Q${MY_PV}\E/\${MY_PV}/;
					push(@{$possible{$file}}, $tmp);
				}
				if($newfile =~ m/\Q${MY_PN}\E/) {
					$tmp = $newfile;
					$tmp =~ s/\Q${MY_PN}\E/\${MY_PN}/;
					push(@{$possible{$file}}, $tmp);
				}
				if($newfile =~ m/\Q${P}\E/) {
					$tmp = $newfile;
					$tmp =~ s/\Q${P}\E/\${P}/;
					push(@{$possible{$file}}, $tmp);
				}
				if($newfile =~ m/\Q${PN}\E/) {
					$tmp = $newfile;
					$tmp =~ s/\Q${PN}\E/\${PN}/;
					push(@{$possible{$file}}, $tmp);
				}
				if($newfile =~ m/\Q${PV}\E/) {
					$tmp = $newfile;
					$tmp =~ s/\Q${PV}\E/\${PV}/;
					push(@{$possible{$file}}, $tmp);
				}
				if($newfile =~ m/\Q${PR}\E/) {
					$tmp = $newfile;
					$tmp =~ s/\Q${PR}\E/\${PR}/;
					push(@{$possible{$file}}, $tmp);
				}
				if($newfile =~ m/\Q${PVR}\E/) {
					$tmp = $newfile;
					$tmp =~ s/\Q${PVR}\E/\${PVR}/;
					push(@{$possible{$file}}, $tmp);
				}
				if($newfile =~ m/\Q${PF}\E/) {
					$tmp = $newfile;
					$tmp =~ s/\Q${PF}\E/\${PF}/;
					push(@{$possible{$file}}, $tmp);
				}
				if($newfile =~ m/\Q${PN}-${PV}\E/) {
					$tmp = $newfile;
					$tmp =~ s/\Q${PN}-${PV}\E/\${PN}-\${PV}/;
					push(@{$possible{$file}}, $tmp);
				}
				if($newfile =~ m/\Q${P}-${PR}\E/) {
					$tmp = $newfile;
					$tmp =~ s/\Q${P}-${PR}\E/\${P}-\${PR}/;
					push(@{$possible{$file}}, $tmp);
				}
				if($newfile =~ m/\Q${SLOT}\E/) {
					$tmp = $newfile;
					$tmp =~ s/\Q${SLOT}\E/\${SLOT}/;
					push(@{$possible{$file}}, $tmp);
				}
				#

				# eselect stuff
				if($category =~ m/^app-admin$/ && $PN =~ m/^eselect-/) {
					my $MODULE = $PN;
					$MODULE =~ s/eselect-//;

					if($newfile =~ m/\Q${MODULE}.eselect-\E(${PVR}|${PV})/) {
						$tmp = $newfile;
						$tmp =~ s/\Q${MODULE}.eselect-${PVR}\E/\${MODULE}\.eselect-\${PVR}/;
						push(@{$possible{$file}}, $tmp);

						$tmp = $newfile;
						$tmp =~ s/\Q${MODULE}.eselect-${PV}\E/\${MODULE}\.eselect-\${PV}/;
						push(@{$possible{$file}}, $tmp);
					}
				}
				elsif($category =~ m/^www-apache$/) {
					my $tmp = $newfile;

					if($tmp =~ m/_\Q${PN}\E(-.*)?\.conf/) {
						$tmp =~ s/\Q_${PN}.conf/_\${PN}/;

						push(@{$possible{$file}}, "APACHE2_MOD_CONF=\"${tmp}\"");
						push(@{$possible{$file}}, "APACHE2_MOD_CONF=${tmp}");

						$tmp = $newfile;
						$tmp =~ s/\Q_${PN}.conf/_${PN}/;

						push(@{$possible{$file}}, "APACHE2_MOD_CONF=\"${tmp}\"");
						push(@{$possible{$file}}, "APACHE2_MOD_CONF=${tmp}");

						$tmp = $newfile;
						$tmp =~ s/\Q_${P}.conf/_${P}/;

						push(@{$possible{$file}}, "APACHE2_MOD_CONF=\"${tmp}\"");
						push(@{$possible{$file}}, "APACHE2_MOD_CONF=${tmp}");
					}
				}
				elsif($category =~ m/^x11-drivers$/ && $PN =~ m/^xf86-video-.*/) {
					my $tmp = $newfile;
					if($tmp =~ m/\.xinf$/) {
						push(@{$possible{$file}}, "x-modular");
					}
				}

				open($ebuild_fh, '<', "${candidate}/${ebuild}");
				while(defined(my $line = <$ebuild_fh>)) {
					last if $#notfound eq $#found;

					chomp($line);
					$line =~ s/^\s*//g;
					$line =~ s/\s*$//g;
					next if length($line) == 0 or $line =~ m/^#/;

					$line =~ s/\"//g;

#					my $foo = $line;
#					if($line =~ m/\$\{?P\}?/) {
#						print "JAJAJA: $line\n";
#						return;
#					}
#					if($foo =~ s/\$\{?P\}?/$P/;

					foreach my $mypossible (@{$possible{$file}}) {
						if($line =~ m/\Q${mypossible}\E/) {
							push(@found, $file) if(!grep(/^\Q${file}\E$/, @found));
							last;
						}
						if($line =~ m/[^\$]\{(,?[^\}]+,?){1,}\}/) {
							my $bashism = $1;
							foreach my $foo (split(",", $bashism)) {
								my $foo2 = $line;
								$foo2 =~ s/([^\$])\{(,?[^\}]+,?){1,}\}/$1$foo/;
								if($foo2 =~ m/\Q${mypossible}\E/) {
									push(@found, $file) if(!grep(/^\Q${file}\E$/, @found));
									last;
								}
							}
						}
					}
				}
				close($ebuild_fh);

				%possible = ();
			}
		}

		if($#notfound ne $#found) {
			my @newnotfound = ();
			foreach my $not (@notfound) {
				if(! grep(/^\Q${not}\E$/, @found)) {
					push(@newnotfound, $not);
				}
			}
			print "* ${category}/".basename(${candidate}).": @newnotfound\n";
		}
	}

	threads->exit();
}

# FIXME
sub num_cpus() {
	open(my $fh, '<', '/sys/devices/system/cpu/possible') or do { warn "Failed to open '/sys/devices/system/cpu/possible': $!"; return 1 };
	chomp(my $num_cpu = <$fh>);
	close($fh);

	$num_cpu =~ s/\d+-//;
	$num_cpu++;

	return $num_cpu ? $num_cpu : 1;
}

sub main() {
	my @categories = ();

	@categories = get_categories($CATEGORIES);
#	my $num_cpu = 4;
	my $num_cpu = num_cpus();

	foreach my $category (@categories) {
		my $thread_count = threads->list(threads::running);

		while($thread_count >= $num_cpu) {
			my @rthreads = threads->list(threads::joinable);
			if($#rthreads >= 0) {
				foreach my $thr (@rthreads) {
					$thr->join();
				}
			}
			else {
				sleep(1);
			}
			$thread_count = threads->list(threads::running);
		}

		threads->create(\&check_category, $category);
	}

	my $threads_running = threads->list(threads::running);
	while($threads_running > 0) {
#		printf STDERR "Waiting until all threads has been finished, %d running threads\n", $threads_running;
		sleep(1);
		$threads_running = threads->list(threads::running);
	}

	foreach my $thr (threads->list(threads::joinable)) {
		$thr->join();
	}

	threads->exit();
}

main();
#my $elapsed = tv_interval($t0, [gettimeofday]);
#print STDERR "took ${elapsed} seconds\n";
