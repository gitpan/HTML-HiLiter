#!/usr/bin/perl -T
#
# usage: lighfile.cgi?f='somefile_or_url';q='some words to highlight'

use CGI qw(:standard);
use CGI::Carp qw(fatalsToBrowser);

print header();

my $f = param('f');
my (@q) = param('q');

use HTML::HiLiter;

my $hl = new HTML::HiLiter;

$hl->Queries([ @q ]);

$hl->CSS;

$hl->Run($f);

print "<p><pre>". $hl->Report . "</pre></p>";

1;

__END__

=pod

=head1 NAME

lightfile.cgi -- highlight a file with HTML::HiLiter via the HTTP method.

=head1 DESCRIPTION

Place in your cgi-bin and set permissions appropriately. Takes two parameters:
f (for file to fetch and highlight) and q (for query to highlight).

=head1 CAUTION

This script makes no attempt at untainting variables or similar security precautions.
It's simply an example.

USE AT YOUR OWN RISK!

=cut


 ###############################################################################
 #    CrayDoc 4
 #    Copyright (C) 2004 Cray Inc swpubs@cray.com
 #
 #    This program is free software; you can redistribute it and/or modify
 #    it under the terms of the GNU General Public License as published by
 #    the Free Software Foundation; either version 2 of the License, or
 #    (at your option) any later version.
 #
 #    This program is distributed in the hope that it will be useful,
 #    but WITHOUT ANY WARRANTY; without even the implied warranty of
 #    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 #    GNU General Public License for more details.
 #
 #    You should have received a copy of the GNU General Public License
 #    along with this program; if not, write to the Free Software
 #    Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 ###############################################################################
 