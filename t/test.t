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
	 '"over the too lazy dog"',
	 '"c++ filter"',
	 '"-h option"',
	 'laz',
	 'fakefox'
	);

select(STDERR);
my $hiliter = new HTML::HiLiter(
				Links=>1
				);

$hiliter->Queries(\@q, [ qw(foo bar) ]);
$hiliter->CSS;

print STDOUT "ok\n" if $hiliter->Run($file);
select(STDOUT);

warn $hiliter->Report;

