#!/usr/bin/perl 
#
#
#	testing HTML::HiLiter
#

print "1..1\n";

use HTML::HiLiter;
$HTML::HiLiter::debug=1;

my $file = 't/test.html';

my @q = ('foo = "quick brown" and bar=(fox* or run)',
	 'runner',
	 '"Over the Too Lazy dog"',
	 '"c++ filter"',
	 '"-h option"',
	 'laz',
	 'fakefox'
	);

my $hiliter = new HTML::HiLiter(
				Links=>1,
				Print=>0,
				);

$hiliter->Queries(\@q, [ qw(foo bar) ]);
$hiliter->CSS;

my $highlighted = $hiliter->Run($file);

print STDOUT "ok\n" if $highlighted;

warn $highlighted;	# so user can see

warn $hiliter->Report;

