#!/usr/bin/perl 
#
#
#	testing HTML::HiLiter
#

print "1..1\n";

use HTML::HiLiter;
$HTML::HiLiter::debug=1;

my $file = 't/test.html';

my @q = ('"quick brown"', 'fox*');


my $hiliter = new HTML::HiLiter(
				Links=>1,
				);

$hiliter->Queries(\@q);
$hiliter->CSS;

select(STDERR);
print STDOUT "ok\n" if $hiliter->Run($file);
select(STDOUT);

warn $hiliter->Report;

