package HTML::HiLiter;

use 5.006001;
use strict;
use sigtrap qw(die normal-signals error-signals);
require Exporter;

# debug_time() is part of the Pubs::Times module
# and can be used for benchmarking

use vars qw(@ISA @EXPORT $VERSION);

@ISA = qw(Exporter);

@EXPORT = qw( );

$VERSION = '0.10';

=pod

=head1 NAME

HTML::HiLiter - highlight words in an HTML document just like a felt-tip HiLiter


=head1 DESCRIPTION

HTML::HiLiter is designed to make highlighting search queries
in HTML easy and accurate. HTML::HiLiter was designed for CrayDoc 4, the
Cray documentation server. It has been written with SWISH::API users in mind, 
but can be used within any Perl program.

=head2 Should you use this module?

I would suggest 
B<not> using HTML::HiLiter if your HTML is fairly simple, since in 
HTML::HiLiter, speed has been sacrificed for accuracy. Check out HTML::Highlighter
instead.

Unlike other highlighting code I've found, this one supports nested tags and
character entities, such as might be found in technical documentation or HTML
generated from some other source (like DocBook SGML or XML). 

You might try using the Parser=>0 feature, which should speed up the 
run time but doesn't support
all the features (like Links, TagFilter, TextFilter, smart context, etc.). Parser=>0
has the advantage of not requiring the HTML::Parser (and associated modules), but
it makes the highlighting rather 'blind'.

The goal is server-side highlighting that looks as if you used a felt-tip marker
on the HTML page. You shouldn't need to know what the underlying tags and entities and
encodings are: you just want to easily highlight some text B<as your browser presents it>.

=head1 SYNOPSIS

	use HTML::HiLiter;

	my $hiliter = new HTML::HiLiter;

	$hiliter->Queries([
			'foo',
			'bar',
			'"some phrase"'
			]
			);

	$hiliter->CSS;

	$hiliter->Run('some_file_or_URL');



=head1 REQUIREMENTS

Perl version 5.6.1 or later.

Requires the following modules:

=over

=item
HTML::Parser (but optional with Parser=>0 -- see new() )

=item
HTML::Entities (but optional with Parser=>0 -- see new() )

=item
HTML::Tagset (but optional with Parser=>0 -- see new() )

=item
Text::ParseWords

=item
HTTP::Request (only if fetching HTML via http)

=item
LWP::UserAgent (only if fetching HTML via http)
 

=back

=head1 FEATURES

=over

=item *

With HTML::Parser enabled (default), HTML::HiLiter evals highlighted HTML 
chunk by chunk, buffering all text
within an HTML block element before evaluating the buffer for highlighting.
If no matches to the queries are found, the HTML is immediately printed (default)
or cached and returned at the end of all evaluation.
Otherwise, the HTML is highlighted and then printed (or cached). The buffer is flushed
after each print/cache.

You can direct the print() to a FILEHANDLE with the standard select() function
in your script. Or use Print=>0 to return the highlighted HTML as a scalar string.

=item *

Ample debugging. Set the $HTML::HiLiter::debug variable to 1,
and lots of debugging info will be printed within HTML comments <!-- -->.

=item *

Will highlight link text (the stuff within an <a href> tagset) if the HREF 
value is a valid match. See the Links option.

=item *

Smart context. Won't highlight across an HTML block element like a <p></p> 
tagset or a <div></div> tagset. (Your indexing software shouldn't consider 
matches for phrases that span across those tags either. But of course, 
that's probably just my opinion...)

=item *

Rotating colors. Each query gets a unique color. The default is four different 
colors, which will repeat if you have more than four queries in a single 
document. You can define more colors in the new() object call.

=item *

Cascading Style Sheets. Will add a <style> tagset in CSS to the <head> of an 
HTML document if you use the CSS() method. If you use the Inline() method, 
the I<style> attribute will be used instead. The added <style> set will be placed
immediately after the opening <head> tag, so that any subsequent CSS defined
in the document will override the added <style>. This allows you to re-define
the highlighting appearance in one of your own CSS files.

=back

=cut


# ----------------------------------------------------------------------------
# PACKAGE globals

use vars qw( $BegChar $EndChar $WordChar $White_Space $HiTag 
		$CSS_Class $hrefs $buffer $debug $Delim $color $nocolor
		$OC $CC %entity2char %codeunis %unicodes %char2entity $ISO_ext
		@whitesp
		);

$OC = "\n<!--\n";
$CC = "\n-->\n";


# ISO 8859 Latin1 encodings

# remove dependency on HTML::Entities by copying them all here
# we don't use the functions in HTML::Entities and it does a require HTML::Parser anyway
%entity2char = (
 # Some normal chars that have special meaning in SGML context
 amp    => '&',  # ampersand 
'gt'    => '>',  # greater than
'lt'    => '<',  # less than
 quot   => '"',  # double quote
 apos   => "'",  # single quote

 # PUBLIC ISO 8879-1986//ENTITIES Added Latin 1//EN//HTML
 AElig	=> 'Æ',  # capital AE diphthong (ligature)
 Aacute	=> 'Á',  # capital A, acute accent
 Acirc	=> 'Â',  # capital A, circumflex accent
 Agrave	=> 'À',  # capital A, grave accent
 Aring	=> 'Å',  # capital A, ring
 Atilde	=> 'Ã',  # capital A, tilde
 Auml	=> 'Ä',  # capital A, dieresis or umlaut mark
 Ccedil	=> 'Ç',  # capital C, cedilla
 ETH	=> 'Ð',  # capital Eth, Icelandic
 Eacute	=> 'É',  # capital E, acute accent
 Ecirc	=> 'Ê',  # capital E, circumflex accent
 Egrave	=> 'È',  # capital E, grave accent
 Euml	=> 'Ë',  # capital E, dieresis or umlaut mark
 Iacute	=> 'Í',  # capital I, acute accent
 Icirc	=> 'Î',  # capital I, circumflex accent
 Igrave	=> 'Ì',  # capital I, grave accent
 Iuml	=> 'Ï',  # capital I, dieresis or umlaut mark
 Ntilde	=> 'Ñ',  # capital N, tilde
 Oacute	=> 'Ó',  # capital O, acute accent
 Ocirc	=> 'Ô',  # capital O, circumflex accent
 Ograve	=> 'Ò',  # capital O, grave accent
 Oslash	=> 'Ø',  # capital O, slash
 Otilde	=> 'Õ',  # capital O, tilde
 Ouml	=> 'Ö',  # capital O, dieresis or umlaut mark
 THORN	=> 'Þ',  # capital THORN, Icelandic
 Uacute	=> 'Ú',  # capital U, acute accent
 Ucirc	=> 'Û',  # capital U, circumflex accent
 Ugrave	=> 'Ù',  # capital U, grave accent
 Uuml	=> 'Ü',  # capital U, dieresis or umlaut mark
 Yacute	=> 'Ý',  # capital Y, acute accent
 aacute	=> 'á',  # small a, acute accent
 acirc	=> 'â',  # small a, circumflex accent
 aelig	=> 'æ',  # small ae diphthong (ligature)
 agrave	=> 'à',  # small a, grave accent
 aring	=> 'å',  # small a, ring
 atilde	=> 'ã',  # small a, tilde
 auml	=> 'ä',  # small a, dieresis or umlaut mark
 ccedil	=> 'ç',  # small c, cedilla
 eacute	=> 'é',  # small e, acute accent
 ecirc	=> 'ê',  # small e, circumflex accent
 egrave	=> 'è',  # small e, grave accent
 eth	=> 'ð',  # small eth, Icelandic
 euml	=> 'ë',  # small e, dieresis or umlaut mark
 iacute	=> 'í',  # small i, acute accent
 icirc	=> 'î',  # small i, circumflex accent
 igrave	=> 'ì',  # small i, grave accent
 iuml	=> 'ï',  # small i, dieresis or umlaut mark
 ntilde	=> 'ñ',  # small n, tilde
 oacute	=> 'ó',  # small o, acute accent
 ocirc	=> 'ô',  # small o, circumflex accent
 ograve	=> 'ò',  # small o, grave accent
 oslash	=> 'ø',  # small o, slash
 otilde	=> 'õ',  # small o, tilde
 ouml	=> 'ö',  # small o, dieresis or umlaut mark
 szlig	=> 'ß',  # small sharp s, German (sz ligature)
 thorn	=> 'þ',  # small thorn, Icelandic
 uacute	=> 'ú',  # small u, acute accent
 ucirc	=> 'û',  # small u, circumflex accent
 ugrave	=> 'ù',  # small u, grave accent
 uuml	=> 'ü',  # small u, dieresis or umlaut mark
 yacute	=> 'ý',  # small y, acute accent
 yuml	=> 'ÿ',  # small y, dieresis or umlaut mark

 # Some extra Latin 1 chars that are listed in the HTML3.2 draft (21-May-96)
 copy   => '©',  # copyright sign
 reg    => '®',  # registered sign
 nbsp   => "\240", # non breaking space

 # Additional ISO-8859/1 entities listed in rfc1866 (section 14)
 iexcl  => '¡',
 cent   => '¢',
 pound  => '£',
 curren => '¤',
 yen    => '¥',
 brvbar => '¦',
 sect   => '§',
 uml    => '¨',
 ordf   => 'ª',
 laquo  => '«',
'not'   => '¬',    # not is a keyword in perl
 shy    => '­',
 macr   => '¯',
 deg    => '°',
 plusmn => '±',
 sup1   => '¹',
 sup2   => '²',
 sup3   => '³',
 acute  => '´',
 micro  => 'µ',
 para   => '¶',
 middot => '·',
 cedil  => '¸',
 ordm   => 'º',
 raquo  => '»',
 frac14 => '¼',
 frac12 => '½',
 frac34 => '¾',
 iquest => '¿',
'times' => '×',    # times is a keyword in perl
 divide => '÷'

);

while (my($entity, $char) = each(%entity2char)) {
    $char2entity{$char} = "&$entity;";
}
delete $char2entity{"'"};  # only one-way decoding

# Fill in missing entities
for (0 .. 255) {
    next if exists $char2entity{chr($_)};
    $char2entity{chr($_)} = "&#$_;";
}

########## end copy from HTML::Entities

# a subset of chars per SWISHE
$ISO_ext = 'ªµºÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝÞßàáâãäåæçèéêëìíîïðñòóôõöøùúûüýþÿ';

######################################################################################
# http://www.pemberley.com/janeinfo/latin1.html
# The CP1252 characters that are not part of ANSI/ISO 8859-1, and that should therefore
# always be encoded as Unicode characters greater than 255, are the following:

# Windows   Unicode    Char.
#  char.   HTML code   test         Description of Character
#  -----     -----     ---          ------------------------
#ALT-0130   &#8218;   â    Single Low-9 Quotation Mark
#ALT-0131   &#402;    Ä    Latin Small Letter F With Hook
#ALT-0132   &#8222;   ã    Double Low-9 Quotation Mark
#ALT-0133   &#8230;   É    Horizontal Ellipsis
#ALT-0134   &#8224;        Dagger
#ALT-0135   &#8225;   à    Double Dagger
#ALT-0136   &#710;    ö    Modifier Letter Circumflex Accent
#ALT-0137   &#8240;   ä    Per Mille Sign
#ALT-0138   &#352;    ?    Latin Capital Letter S With Caron
#ALT-0139   &#8249;   Ü    Single Left-Pointing Angle Quotation Mark
#ALT-0140   &#338;    Î    Latin Capital Ligature OE
#ALT-0145   &#8216;   Ô    Left Single Quotation Mark
#ALT-0146   &#8217;   Õ    Right Single Quotation Mark
#ALT-0147   &#8220;   Ò    Left Double Quotation Mark
#ALT-0148   &#8221;   Ó    Right Double Quotation Mark
#ALT-0149   &#8226;   ¥    Bullet
#ALT-0150   &#8211;   Ð    En Dash
#ALT-0151   &#8212;   Ñ    Em Dash
#ALT-0152   &#732;    ÷    Small Tilde
#ALT-0153   &#8482;   ª    Trade Mark Sign
#ALT-0154   &#353;    ?    Latin Small Letter S With Caron
#ALT-0155   &#8250;   Ý    Single Right-Pointing Angle Quotation Mark
#ALT-0156   &#339;    Ï    Latin Small Ligature OE
#ALT-0159   &#376;    Ù    Latin Capital Letter Y With Diaeresis
#
#######################################################################################

# NOTE that all the Char tests will likely fail above unless your terminal/editor
# supports Unicode

# browsers should support these numbers, and in order for perl < 5.8 to work correctly,
# we add the most common if missing

%unicodes = (
		8218	=> "'",
		402	=> 'f',
		8222	=> '"',
		8230	=> '...',
		8224	=> 't',
		8225	=> 't',
		8216	=> "'",
		8217	=> "'",
		8220	=> '"',
		8221	=> '"',
		8226	=> '*',
		8211	=> '-',
		8212	=> '-',
		732	=> '~',
		8482	=> '(TM)',
		376	=> 'Y',
		352	=> 'S',
		353	=> 's',
		8250	=> '>',
		8249	=> '<',
		710	=> '^',
		338	=> 'OE',
		339	=> 'oe',
);

for (keys %unicodes) {
	# quotemeta required since build_regexp will look for the \
	my $ascii = quotemeta($unicodes{$_});
	next if length $ascii > 2;
	#warn "pushing $_ into $ascii\n";
	push(@{ $codeunis{$ascii} }, $_);
}
	
################################################################################

# SWISH-E users:
# WordChars should be WordCharacters class
# but should probably never include <> just to be safe.

# the default SWISH definition??
$WordChar = '\w' . $ISO_ext . './-';

$BegChar = '\w' . $ISO_ext . './-';

$EndChar = '\w' . $ISO_ext;

# regexp for what constitutes whitespace in an HTML doc
# it's not as simple as \s|&nbsp; so we define it separately
@whitesp = (
		'&#x0020;',
		'&#x0009;',
		'&#x000C;',
		'&#x200B;',
		'&#x2028;',
		'&#x2029;',
		'&nbsp;',
		'&#x32;',
		'&#x160;',
		'\\s',
		'\xa0',
		'\x20',
		);

$White_Space = join('|', @whitesp);

$HiTag = 'span';	# what tag to use to hilite

$CSS_Class = 'hilite';

$buffer = '';		# init the buffer

$hrefs = [];		# init the href buffer (for Links option)

$debug = 0;		# set to 0 to avoid all the output

# if we're running via terminal (usually for testing)
# and the Term::ANSIColor module is installed
# use that for debugging -- easier on the eyes...

$color = '';
$nocolor = '';


if (-t STDOUT) {
	eval { require Term::ANSIColor };
	unless ($@) {
		
		$color = Term::ANSIColor::color('bold blue');
		$nocolor = Term::ANSIColor::color('reset');
		
	}
}


my $HiLiting = 0;	# flag initially OFF, then turned ON
			# whenever we pass out of <head>

my $tag_regexp = '(?s-mx:<[^>]+>)';

$Delim = '"';

my %common_char = (
		'>' 	=> '&gt;',
		'<' 	=> '&lt;',
		'&' 	=> '&amp;',
		'\xa0' 	=> '&nbsp;',
		'"'	=> '&quot;'
		);

sub new
{
	my $package = shift;
	my $self = {};
	bless($self, $package);
	$self->_init(@_);
	return $self;
}

sub swish_new
{
# takes a SWISH::API object and
# uses the SWISH methods to set WordChar, etc.

	my $self = shift;
	my $swish_obj = $self->{SWISHE};
	my @head_names = $swish_obj->HeaderNames;
	my @indexes = $swish_obj->IndexNames;
	# just use the first index, assuming user
	# won't pass more than one with different Header values
	my $index = shift @indexes;
	for my $h (@head_names) {
		$self->{$h} = $swish_obj->HeaderValue( $index, $h );
	}

}

sub _init
{
    my $self = shift;
    $self->{'start'} = time;
    my %extra = @_;   
    @$self{keys %extra} = values %extra;
	
	# special handling for swish flag
	
	$self->swish_new if $self->{SWISHE};
	
	# default values for object
	
	$self->{WordCharacters} 	||= $WordChar;
	$self->{EndCharacters} 		||= $EndChar;
	$self->{BeginCharacters} 	||= $BegChar;
	
	# a search for a '<' or '>' should still highlight,
	# since &lt; or &gt; can be indexed as literal < and >, at least by SWISH-E
	for (qw(WordCharacters EndCharacters BeginCharacters))  {
		$self->{$_} =~ s,[<>&],,g;
		# escape the - since it is special in a [] class
		$self->{$_} =~ s/\-/\\-/g;
	}
	
	
	# what's the boundary between a word and a not-word?
	# by default:
	#	the beginning of a string
	#	the end of a string
	#	whatever we've defined as White_Space
	#	any character that is not a WordChar
	#
	# the \A and \Z (beginning and end) should help if the word butts up
	# against the beginning or end of a tagset
	# like <p>Word or Word</p>

	$self->{StartBound} 	||= join('|', '\A?', '\s', '[^>;' . $self->{BeginCharacters} . ']' ) ;
	#$self->{EndBound} 	||= join('|', '\Z?', '[\s]', '[^<&]', "[^$self->{EndCharacters}]" ) ;
	#$self->{StartBound} 	||= join('|', '\A?', "[^\\S>;$self->{BeginCharacters}]" ) ;
	$self->{EndBound} 	||= '\Z|[\s<]|[^' . $self->{EndCharacters} . ']';
	$self->{HiTag} 		||= $HiTag;
	$self->{Colors} 	||= [ '#FFFF33', '#99FFFF', '#66FFFF', '#99FF99' ];					
	$self->{Links}		||= 0;		# off by default
	
	$self->{BufferLim}	||= 100000;	# eval'ing enormous buffers can cause
						# huge bottlenecks. if buffer length
						# exceeds BufferLim, it will not be highlighted
						
	$self->{Force}	||= undef;	# wrap Inline HTML with <p> tagset
					# to force HTML interpolation
						
	# load the parser unless explicitly asked not to
	unless ( defined($self->{Parser}) && $self->{Parser} == 0) {
		$self->{Parser}++;
		require HTML::Parser;
		require HTML::Tagset;
		# HTML::Tagset::isHeadElement doesn't define these,
		# so we add them here
		$HTML::Tagset::isHeadElement{'head'}++;
		$HTML::Tagset::isHeadElement{'html'}++;
	}
	
	unless ( defined($self->{Print}) && $self->{Print} == 0) {
		$self->{Print} = 1;
	}
	
						
=pod

=head1 Object Oriented Interface

The following parameters take values that can be made into a regexp class.
If you are using SWISH-E, for example, you will want to set these parameters
equal to the equivalent SWISH-E configuration values. Otherwise, the defaults
should work for most cases.

Example:

	my $hiliter = new HTML::HiLiter(
	
				WordCharacters 	=>	'\w\-\.',
				BeginCharacters =>	'\w',
				EndCharacters	=>	'\w',
				HiTag =>	'span',
				Colors =>	[ qw(#FFFF33 yellow pink) ],
				Links =>	1
				TagFilter =>	\&yourcode(),
				TextFilter =>	\&yourcode(),
				Force	=>	1,
				SWISHE	=>	$swish_api_object
					);
	


=over

=item WordCharacters

Characters that constitute a word.

=item BeginCharacters

Characters that may begin a word.

=item EndCharacters

Characters that may end a word.

=item StartBound

Characters that may not begin a word. If not specified, will be automatically 
based on [^BeginCharacters] plus some regexp niceties.

=item EndBound

Characters that may not end a word. If not specified, will be automatically 
based on [^EndCharacters] plus some regexp niceties.

=item HiTag

The HTML tag to use to wrap highlighted words. Default: span

=item Colors

A reference to an array of HTML colors. Default is:
'#FFFF33', '#99FFFF', '#66FFFF', '#99FF99'

=item Links

A boolean (1 or 0). If set to '1', consider <a href="foo">my link</a> a valid match for 
'foo' and highlight the visible text within the <a> tagset ('my link').
Default Links flag is '0'.

=item TagFilter

Not yet implemented.

=item TextFilter

Not yet implemented.

=item BufferLim

When the number of characters in the HTML buffer exceeds the value of BufferLim,
the buffer is printed without highlighting being attempted. The default is 100000
characters. Make this higher at your peril. Most HTML will not exceed more than
100,000 characters in a <p> tagset, for example. (At least, most legible HTML will
not...)

=item Print

Print highlighted HTML as the HTML::Parser encounters it.
If TRUE (the default), use a select() in your script to print somewhere besides the
perl default of STDOUT. 

NOTE: set this to 0 (FALSE) only if you are highlighting small chunks of HTML
(i.e., smaller than BufferLim). See Run().

=item Force

Automatically wrap <p> tagset around HTML passed in Run(). This will
force the highlighting of plain text. Use this only with Inline().

=item SWISHE

For SWISH::API compatibility. See the SWISH::API documentation and the
EXAMPLES section later in this document.

=item Parser

If set to 0 (FALSE), then the HTML::Parser module will not be loaded. This allows
you to use the regexp methods without the overhead of loading the parser. The default
is to load the parser.

=back

=head1 Variables

The following variables may be redefined by your script.

=over

=item
$HTML::HiLiter::Delim

The phrase delimiter. Default is double quotation marks (").

=item 
$HTML::HiLiter::debug

Debugging info prints on STDOUT inside <!-- --> comments. Default is 0. Set it to 1
to enable debugging.

=item
$HTML::HiLiter::White_Space

Regular expression of what constitutes HTML white space.
Redefine at your own risk.

=item
$HTML::HiLiter::CSS_Class

The I<class> attribute value used by the CSS() method. Default is 'hilite'.

=back

=head1 Methods

=cut
						
    
}

sub mytag
{
	my ($self,$tag,$tagname,$offset,$length,$offset_end,$attr,$text) = @_;
	
	# $tag has ! for declarations and / for endtags
	# $tagname is just bare tagname
	
	if ($debug == 3) {
		print $OC;
		print "\n". '=' x 20 . "\n";
		print "Tag is :$tag:\n";
		print "TagName is :$tagname:\n";
		print "Offset is $offset\n";
		print "Length is $length\n";
		print "Offset_end is $offset_end\n";
		print "Text is $text\n";
		print "Attr is $_ = $attr->{$_}\n" for keys %$attr;
		print $CC;
	}
	
	# if we encounter an inline tag, add it to the buffer
	# for later evaluation
	
	# PhraseMarkup is closest to libxml2 'inline' definition
	if ( $HTML::Tagset::isPhraseMarkup{$tagname} )
	{
	
		print "${OC} adding :$text: to buffer ${CC}" if $debug == 3;
		
		$buffer .= $text;	# add to the buffer for later evaluation
					# as a potential match
				
		# for Links option	
		if ($self->{HiLiter}->{Links} and exists($attr->{'href'})) {
			push(@$hrefs, $attr->{'href'});
		}
					
		#warn "INLINEBUFFER:$buffer:INLINEBUFFER";
		
		return;
		
	}
	
	# otherwise, evaluate $buffer and then print and flush it
	# if this is an opentag, then $buffer is likely NULL which is fine
	
	
	else
	{
		
		if ($debug == 2) {
			print 	"${OC} ~~~~~~~~~~~~~~~~~~~~\n".
				"start buffer eval: ". debug_time(). " secs\n".
				"\n~~~~~~~~~~~~~~~~~~~~ $CC";
		}
		
		if ($self->{HiLiter}->{BufferLim} and
			length($buffer) > $self->{HiLiter}->{BufferLim})
			{
			
			if ($self->{HiLiter}->{Print}) {
				print $buffer;
			} else {
				$self->{HiLiter}->{Buffer} .= $buffer;
			}
			
		} else {
		
			my $hilited = $self->{HiLiter}->hilite( $buffer, $hrefs );
			
			if ($self->{HiLiter}->{Print}) {
				print $hilited;
			} else {
				$self->{HiLiter}->{Buffer} .= $hilited;
			}
			
			
		}
		
		
		if ($debug == 2) {
			print 	"${OC} ~~~~~~~~~~~~~~~~~~~~\n".
				"end buffer eval: ". debug_time(). " secs\n".
				"\n~~~~~~~~~~~~~~~~~~~~ $CC";
		}

		
		$buffer = '';
		$hrefs = [];
		
	}

	
	# turn HiLiting ON if we are not inside the <head> tagset
	# this prevents us from hiliting a <title> for example
	if (! $HTML::Tagset::isHeadElement{$tagname} )
	{
		$HiLiting++;
	}
	
	# use reassemble to futz with attribute values or tagnames
	# before printing them.
	# otherwise, default to what we have in original HTML
	#
	# NOTE: this is where we could change HREF values, for example
	my $reassemble;
	
		# do something here to create $reassemble
		
	$reassemble ||= $text;
	if ($self->{HiLiter}->{Print}) {
		print $reassemble;
	} else {
		$self->{HiLiter}->{Buffer} .= $reassemble;
	}
	
	# if this is the opening <head> tag,
	# add the <style> declarations for the hiliting
	# this lets later <link css> tags in a doc
	# override our local <style>
	
	if ( $tag eq 'head' )
	{
	  if ($self->{HiLiter}->{Print}) {
		print $self->{HiLiter}->{StyleHead}
			if $self->{HiLiter}->{StyleHead};
	  } else {
	  	$self->{HiLiter}->{Buffer} .= $self->{HiLiter}->{StyleHead}
			if $self->{HiLiter}->{StyleHead};
	  }
	}
	
}

sub mytext
{
# self is HTML::Parser object
	my ($self, $dtext, $text, $offset, $length) = @_;
	
	unless ($HiLiting) {
	
		if ($self->{HiLiter}->{Print}) {
		
			print $text;
			
		} else {
		
			$self->{HiLiter}->{Buffer} .= $text;
			
		}
		
	} else {
	
		$buffer .= $text;
		
	}
	
	
	if ($debug == 3) {
		print 	$OC.
			"TEXT :$text:\n";
		
		print	"Added TEXT to buffer\n" if $HiLiting;
		
		print	"DECODED :$dtext:\n".
			"Offset is $offset\n".
			"Length is $length\n".
			$CC;
		
	}


}

sub read_file
{ # some error checking first
	local $/;
	open (FILE, shift ) || die "can't open file: $!\n";
	my $buf = <FILE>;
	close(FILE);
	return $buf;
}

sub check_count
{
# return total count for all keys
	my $done;
	for (sort keys %{ $_[0] })
	{
		$done += $_[0]->{$_};
		if ($debug == 1 and $_[0]->{$_} > 0) {
			print "$OC $_[0]->{$_} remaining to hilite for: $_ $CC";
		}
	}
	return $done;
}

sub tidy_tags
{

# not used
	$_[0] =~ s,<\s*,<,g;
	$_[0] =~ s,\s*>,>,g;

}

sub Queries
{

=pod

=head2 Queries( \@queries, [ \@metanames ] )

Parse the queries you want to highlight, and create
the corresponding regular expressions in the object.
This method must be called prior to Run(), but need
only be done once for a set of queries. You may Run()
multiple times with only one Queries() setup.

Queries() requires a single parameter: a reference to an array
of words or phrases. Phrases should be delimited with
a double quotation mark (or as redefined in $HTML::HiLiter::Delim ).

If using SWISH-E, Queries() takes a second parameter: a reference
to an array of a metanames. If the metanames are used as part of the query,
they will be removed from the regexp used for highlighting.

NOTE to SWISH::API users: be wary of using the SWISH::API ParsedWords() method with
Queries() as SWISH::API will lowercase all your queries. This will result
in the highlighted words being lowercased as well, which may not be what you want.

Returns a hash ref of the queries, with key = query and value = regexp.

=cut

	my $self = shift;
	my $queries = shift || die "Need some queries to Prepare...\n";
	
	my $q_array = $self->prep_queries($queries, @_);
	
	# build regexp for each uniq and save in hash
	# this lets us build regexp just once for each time we use Queries method
	# which is likely just once per use of this module
	my $q2regexp = {};
	
	for my $q (@$q_array) {
		$q2regexp->{$q} = $self->build_regexp($q);
		print "$OC REGEXP: $q\n$q2regexp->{$q} $CC" if $debug == 1;
	}

	$self->{Queries} = $q2regexp;
	
	return $self->{Queries};
	
}

sub Inline
{

=pod

=head2 Inline

Create the inline style attributes for highlighting without CSS.
Use this method when you want to Run() a piece of HTML text.

=cut

	my $self = shift;
	# don't hilite an entire file, just a chunk of HTML passed by calling script
	# this requires we specify colors inline in HiTag style attribute
	# as opposed to CSS in head.
	$self->make_styles_inline;

}

sub CSS
{

=pod

=head2 CSS

Create a CSS <style> tagset for the <head> of your output. Use this
if you intend to pass Run() a file name, filehandle or a URL.

=cut

	# set up object
	my $self = shift;
	$self->make_styles_css;
	
}



sub Run
{

=pod

=head2 Run( file_or_url )

Run() takes either a file name, a URL (indicated by a leading 'http://'),
or a scalar reference to a string of HTML text.

The HTML::Parser must be used with this method.

=cut

	my $self = shift;
	my $file_or_html = shift || die "no File or HTML in HiLiter object!\n";
	
	$self->{Buffer} = '';	# reset
	
	my $default_h = sub { print @_ };
	
	if (! $self->{Print}) {
		$default_h = sub { $self->{Buffer} .= $_ for @_ };
	}
	
	if ( -e $file_or_html )	# should handle files or filehandles
	{
	
	   $self->{File} = $file_or_html;
		
	   
	} elsif ($file_or_html =~ m/^http:\/\//i) {
	   
	   ($self->{HTML}) = $self->get_url($file_or_html);
		
	   
	} elsif (ref $file_or_html eq 'SCALAR') {

	  $self->{HTML} = $$file_or_html;
	  
	  $self->{HTML} = '<p>' . $$file_or_html . '</p>' if $self->{Force};
	  	   
	} else {
	
		die "$file_or_html is neither a file nor a filehandle nor a scalar ref!\n";
	   
	}
	
	my $parser = new HTML::Parser(
	  unbroken_text => 1,
	  api_version => 3,
	  text_h => [ \&mytext, 'self,dtext,text,offset,length' ],
	  start_h => [ \&mytag, 'self,tag,tagname,offset,length,offset_end,attr,text' ],
	  end_h => [\&mytag, 'self,tag,tagname,offset,length,offset_end,undef,text' ],
	  default_h => [ $default_h, 'text' ]
	);

	# shove $self into the $parser object, so that the my...() subroutines
	# can access the data.
	# this feels ugly, but works. perhaps a re-think of the whole structure
	# would be better, but this way other OO methods are available
	# for finer tuning/control by user, without making it overly complicated to use
	# at a 'novice' level.
	
	# NOTE if HTML::Parser API ever changes, this might break.
	
	$parser->{HiLiter} = $self;

	# two kinds to run: File or Chunk
	if ($self->{File})
	{
		return $! if ! $parser->parse_file($self->{File});
	
	}
	
	elsif ($self->{HTML})
	
	{
		return $! if ! $parser->parse($self->{HTML});
	}
	
	unless ($self->{Print}) {
	
		$self->{Buffer} .= "\n";
		
	} else {

		print "\n";	# does parser intentionlly chomp last line?
	}

	# reset in case caller is mixing HTML and File in a single object
	delete $self->{HTML};
	delete $self->{File};
	$parser->eof;

	return $self->{Buffer} || 1;
}


sub hilite
{
	
=pod

=head2 hilite( html, links )

Usually accessed via Run() but documented here in case you want to run without
the HTML::Parser. Returns the text, highlighted. Note that CSS() will probably
not work for you here; use Inline() prior to calling this method, 
so that the object has the styles defined.

See SWISH::API in EXAMPLES.

NOTE: that the second param 'links' is an array ref and only works if using the 
HTML::Parser and you have set the Links param in the new() method -- 
in which case, use Run() instead.

Example:

	my $hilited_text = $hiliter->hilite('some text');
	
=cut

	my $self = shift;
	my $html = shift || return '';	# no html to highlight
	my $links = shift || [];	# href values for Links option
	
	delete $self->{Report} if ! $self->{Parser}; #reset
	
	if ($debug == 1) {
		print	$OC.
			"\n", '~' x 60, "\n".
			"HTML to eval is S:$html:E\n".
			"HREF to eval is S:$_:E\n".
			$CC
			for @$links;
	}
	
	###################################################################
	# 1.
	#	count instances of each query in $html
	#	and in $links ( this lets us compare the accuracy of our regexp )
	# 2.
	#	create hash of query -> [ array of real HTML to hilite ]
	# 	using the prebuilt regexp
	# 3.
	#	hilite the real HTML
	#
	###################################################################
	
	# 1. count instances
	# this will let us get an accurate count of instances
	# since entities will be decoded and tags stripped,
	# and let's us return if this chunk doesn't contain any queries

	my $tagless = '';
	
	# wrap in an eval{} in case HTML::Parser isn't loaded

	eval {
		my $plainascii = new HTML::Parser(
			unbroken_text => 1,
			api_version => 3,
		  	text_h => [ sub { $tagless .= shift }, "dtext" ],
		  	#marked_sections => 1,
		)->parse( $html );
		
		$plainascii->eof;	# resets parser
		
	};

	$tagless ||= $html;	# sometimes it's just a single &nbsp; or something
				# and we end up with ' '.
	
	for my $num (keys %unicodes) {
		$tagless =~ s,&#$num;,$unicodes{$num},g;
		# some special Unicode entities
		# that get special ascii equivs for DocBook source
	}	
	
	print $OC . "TAGLESS: $tagless :TAGLESS" , $CC if $debug == 1;
		
	my $count = {};
	
	my @all_queries = sort keys %{ $self->{Queries} };
	
	Q: for my $q (@all_queries) {
		#print "counting $q...\n";
		$count->{$q} = $self->count_instances($q, $tagless, $links) || 0;
		print $OC . "COUNT for '$q' is $count->{$q}" , $CC if $debug == 1;
	}

	
	#print "COUNT: $_ -> $count->{$_}\n" for keys %$count;

    if (! $count or ! check_count($count)) {
	
		# do nothing

    } else {

	# 2. start looking for real HTML to hilite
	
	my $q2real = {};
	# this is going to be query => [ real_html ]
	
	# if the query text matched in the text, then we need to
	# use our prebuilt regexp
	
	# if the query text matches in a link, then we simply need
	# to look for (<a.*?href=['"]$link['"].*?>.*?</a>)
	# and let the add_hilite_tags decide where to put the hiliting tags

	my @instances = sort keys %$count; # sort is just to make debugging easier

	Q: for my $q (@instances) {
	
		next Q if ! $count->{$q};
		
		print $OC . "FOUND $q" . $CC if $debug == 1;
		
		my $reg_exp = $self->{Queries}->{$q};
		
		my $real = get_real_html( $html, $reg_exp );
		
		R: for my $r (keys %$real) {
		
			print $OC . "REAL appears to be $r ($real->{$r} instances)" , $CC if $debug == 1;
			
			push(@{ $q2real->{$q} }, $r ) while $real->{$r}--;
			
		}
		
		if ($self->{Links}) {
		   LINK: for my $link (@$links) {
		   
		   	print $OC . "found LINK: $link" , $CC if $debug == 1;
			
			my $s = quotemeta($link);
	
	# thanks to Mike Schilli m@perlmeister.com for this regexp fix
			my $re = qq!(.?)(<a.*?href=['"]${s}! . qq!"["'].*?>.*?</a>)(.?)!;
			#my $re = qq!(.?)(<a.*?href=['"]${s}["'].*?>.*?</a>)(.?)!;
			
			my $link_plus_txt = get_real_html( $html, $re );
			
			R: for my $r (keys %$link_plus_txt) {
			
			# if the href and the link text both match, don't count each
			# one; omit the href, since the link text should be caught
			# by the standard @instances
			
				my ($href,$ltext) = ($r =~ m,<a.*?href=['"](.*?)["'].*?>(.*?)</a>,is );
				
				print 	$OC .
				 	"LINK:\nhref is $href\n".
					"ltext is $ltext".
					$CC if $debug ==1;
				
				if ( $ltext =~ m/$reg_exp/isx ) {
					print $OC . "SKIPPING LINK as duplicate" . $CC if $debug ==1;
					$count->{$q}--;
					next R;
				}
			
				print $OC . "REAL LINK appears to be $r" , $CC if $debug == 1;
				
				push( @{ $q2real->{$q} }, $r) while $link_plus_txt->{$r}--;
				
			}
		   }
		}
		
		$self->{Report}->{$q}->{Instances} += scalar(@{ $q2real->{$q} || [] });
		
		print $OC . "before any hiliting, count for '$q' is $self->{Report}->{$q}->{Instances} " . $CC
			if $debug == 1;
		
	}
	
	# 3. add the hiliting tags
		
	HILITE: for my $q (@instances) {

	   my %uniq_reals = ();
	   $uniq_reals{$_}++ for @{ $q2real->{$q} };
	
	   REAL: for my $real (keys %uniq_reals) {
	   
	   	print $OC . "'$q' matched real:\n$real\n" . $CC if $debug == 1;
		
		$html = $self->add_hilite_tags($html,$q,$real,$count);
		
	   }
	   
	}	
	
	
    }
	# no matter what, if we get here, return whatever we have
	report($self,$count);
	return $html;

}

sub report
{
# keep tally of how many matches vs how many successful hilites
	my $self = shift;
	my $count = shift;
	return if ! scalar(keys %$count);
	
	my $file = $self->{File} || $self->{HTML} || '[unknown file]';
	for (keys %$count) {
		next if $count->{$_} <= 0;
		$self->{Report}->{$_}->{Misses}->{$file} += $count->{$_};
	}

}


sub make_styles_css
{
	# create <style> tagset for header
	# and for subsequent substitutions
	
	# each query gets assigned a letter
	# and in the header, each letter is assigned a color
	
	my $self = shift;
	my $queries = [ keys %{ $self->{Queries} } ];
	my $styles;
	my $tagset = qq( <STYLE TYPE="text/css"> $OC );
	my $num = 0; 
	my @colors = @{ $self->{Colors} };
	for (@$queries) {
		
		$tagset .= qq( \n
			$self->{HiTag}.$CSS_Class$num
			{
			   background : $colors[$num];
			}
			) unless $tagset =~ m/$CSS_Class$num/;
			# only define it once
			# but assign a definition to each query
		$styles->{$_} = $CSS_Class.$num++;
		$num = 0 if $num > $#colors;	# start over if we exceed
						# total number of colors
	}
	
	$tagset .= " $CC </STYLE>\n";
	$self->{Styles} = $styles;
	$self->{StyleHead} = $tagset;

}

sub make_styles_inline
{
	# create hash for adding style attribute inline
	# each query gets assigned a color
	
	my $self = shift;
	my $queries = [ keys %{ $self->{Queries} } ];
	my $styles;
	my $num = 0; 
	my @colors = @{ $self->{Colors} };
	for (@$queries) {
		$styles->{$_} = $colors[$num++];
		$num = 0 if $num > $#colors;	# start over if we exceed
						# total number of colors
	}
	
	$self->{Styles} = $styles;

}

sub setup_style
{
	my $self = shift;
	my $match = shift;
	my $style = $self->{Styles}->{$match} || warn "no style for '$match'!\n";
	$style ||= 'yellow';	# just in case
	
	# what kind of style are we doing: inline or css?
	if ($style =~ /$CSS_Class/i) {
		$style = "class='$style'";
	} else {
		$style = "style='background:$style'";
	}
	return $style;
}


sub get_real_html
{

# this could be a bottleneck if buffer is really large
# so use $self->{BufferLim} to avoid that.
# or can the s//eval{}/ approach be improved upon??

	if ($debug == 2) {
	
		print 	$OC .
			"\n~~~~~~~~~~~~~~~~~~~~\n".
			"starting get_real_html: " . debug_time() . " secs\n" .
			$CC;
		
	}
	
	my ($html,$re) = @_;
	my $uniq;
	#warn "UNIQ looked for \n$re\n";
	#warn "UNIQ: $_\n" for keys %$uniq;

	# $1 should be st_bound, $2 should be query, $3 should be end_bound
	$html =~ s$reeval { $uniq->{$2}++ }gisex;
	
	
	if ($debug == 2) {
	
		print	$OC .
			"\n~~~~~~~~~~~~~~~~~~~~\n".
			"end get_real_html: " . debug_time() . " secs\n" .
			$CC;
		
	}

	
	
	return $uniq;

}


sub count_instances
{
	my ($self,$query,$tagless,$links) = @_;
	my $wild = $self->{EndCharacters};
	my $st_bound = $self->{StartBound};
	my $end_bound = $self->{EndBound};
	my $count = 0;
	
	# first count in tagless HTML
	my $safe = quotemeta($query);
	
	# set up whitespace
	$safe =~ s,\\ ,(?:$White_Space)+,g;
	
	$safe =~ s,\\\*,[$wild]*,g;
	
	my $pattern = "(${st_bound})(${safe})(${end_bound})";
	
	#warn "counting instances of : $pattern :\nin HTML: $html\n" if $debug;
	
	$count = ($tagless =~ s/$pattern/ 1 /gsi );
	
	# second, count instances in $links (an array ref)
	# just one hit per link, even if the pattern appears multiple times
	
	for my $i (@$links) {
		print $OC . "looking for LINK '$i' against $pattern" , $CC if $debug == 1;
		my $copy = $i;	# so we don't alter source in s//
		
		$count += ( $copy =~ s/$pattern/ 1 /gsi );
	}
	
	
	return $count;

}

sub build_regexp
{

=pod

=head2 build_regexp( words_to_highlight )

Returns the regular expression for a string of word(s). Usually called by Queries()
but you might use directly if you are running
without the HTML::Parser.

	my $pattern = $hiliter->build_regexp( 'foo or bar' );
	
This is the heart of the HiLiter. We leverage the speed of Perl's regexp engine 
against the complication of a regexp that matches inline tags, entities, and combinations of both.

=cut

	my ($self,$match) = @_;
	my $wild = $self->{EndCharacters};
	my $st_bound = $self->{StartBound};
	my $end_bound = $self->{EndBound};

	my (@char) = split(//,$match);
	
	my $counter = -1;
	
	CHAR: foreach my $c (@char)
	{
		$counter++;
		
		my $ent = $char2entity{$c} || warn "no entity defined for >$c< !\n";
		my $num = ord($c);		
		# if this is a special regexp char, protect it
		$c = quotemeta($c);
		
		# if it's a *, replace it with the Wild class
		$c = "[$wild]*" if $c eq '\*';
		
		# if $c is whitespace, replace it with White_Space def
		# since we might have a space before or after a newline, make it a + (one or more)
		if ($c eq '\ ') {
			$c = "(?-xsm:$White_Space)+" . $tag_regexp . '*';
			next CHAR;
		} elsif (exists $codeunis{$c} ) {
			#warn "matched $c in codeunis\n";
			my @e = @{ $codeunis{$c} };
			$c = join('|', $c, grep { $_ = "&#$_;" } @e );
		}
		
		my $aka = $ent eq "&#$num;" ? $ent : "$ent|&#$num;";
		
		# make $c into a regexp
		$c = "(?-xsm:$c|$aka)" unless $c eq "[$wild]*";
		#$c = "(?:$c|$aka)";
		
		# any char might be followed by zero or more tags, unless it's the last char
		$c .= $tag_regexp . '*' unless $counter == $#char;

		
 	}
	 
	# re-join the chars into a single string
 	my $safe = join("\n",@char);	# use \n to make it legible in debugging
	
	# for debugging legibility
	my $pattern =<<EOF;
	(
	${st_bound}
	)
	(
${safe}
	)
	(
	${end_bound}
	)

EOF
	
	return $pattern;
}

sub add_hilite_tags
{
	my ($self,$html,$q,$to_hilite,$count) = @_;
	
	my $style = setup_style($self,$q);
	
	my $tag = $self->{HiTag};
	my $open = "<${tag} ${style}>";
	my $close = '</'. $tag .'>';

	ascii_chars($html);

	my $safe = quotemeta($to_hilite);
		
	# pre-fix nested tags in match
	(my $prefixed = $to_hilite) =~ s,($tag_regexp+),${nocolor}$close$1$open${color},g;
		
	my $c = 0;
	$c = ($html =~ s/($safe)/${open}${color}${prefixed}${nocolor}${close}/g );
							# no -s, -i or -x flags wanted or needed
							# since we watch exact (case sensitive) matches
							# on real, previously identified HTML
	
	if ($debug == 1) {
		print	$OC .
			"SAFE was $safe\n".
			"PREFIXED was $prefixed\n".
			"HILITED $c times\n".
			"AFTER is $html\n".
			$CC;
	}
		
	$count->{$q} -= $c;
		
	$self->{Report}->{$q}->{HiLites} += $c;
	
	$html = $self->clean_up_hilites($html,$q,$open,$close,$safe,$count);
	
	print $OC . "AFTER hilite clean:$html:" . $CC if $debug == 3;
	
	return $html;

}

sub count_tags
{

# not used
	my $html = shift;
	my $cnt = ($html =~ s/$tag_regexp/ 1 /sg);
	return $cnt;

}

sub ascii_chars
{
	my $s = shift;
	for (split(//,$s)) {
		print $OC . "$_ = ". ord($_) . $CC if $debug == 3;
	}

}



sub clean_up_hilites
{

# try and keep Report honest
# if it was a mistake, don't count it as an Instance
# so that it also doesn't show up as a Miss

	my ($self,$html,$q,$open,$close,$safe,$count) = @_;
	
	print $OC . "BEFORE cleanup, HiLite Count for '$q' is $self->{Report}->{$q}->{HiLites}" . $CC if $debug == 1;
	
	# empty hilites are useless
	my $empty = ( $html =~ s,$open(?:\Q$color\E)(?:\Q$nocolor\E)$close,,sgi ) || 0;
	
	# to be safe: in some cases we might match against entities or within tag content.
  	my $ent_split = ( $html =~ s/(&[\w#]*)$open(?:\Q$color\E)(${safe})(?:\Q$nocolor\E)$close([\w#]*;)/$1$2$3/igs ) || 0;
	
	my $tag_split = 0;
	while ( $html =~ m/(<[^<>]*)\Q$open\E(?:\Q$color\E)($safe)(?:\Q$nocolor\E)\Q$close\E([^>]*>)/gxsi ) {	

		print "$OC appears to split tag: $1$2$3 $CC" if $debug == 1;

		$tag_split += ( $html =~ s/(<[^<>]*)\Q$open\E(?:\Q$color\E)($safe)(?:\Q$nocolor\E)\Q$close\E([^>]*>)/$1$2$3/gxsi );

		#$count->{$q} += $c;
	}
	
	$self->{Report}->{$q}->{HiLites} -= ($tag_split + $ent_split);
	$self->{Report}->{$q}->{Instances} -= ($ent_split + $tag_split);
	
	if ($debug == 1) {
		print 	$OC.
			"\tfound $empty empty hilite tags\n".
			"\tfound $tag_split split tags\n".
			"\tfound $ent_split split entities\n".
			$CC;
	}
	
	print "$OC AFTER cleanup, HiLite Count for '$q' is $self->{Report}->{$q}->{HiLites} $CC" if $debug == 1;

	
	return $html;

}

sub urlify_ascii
{
	my $str = shift;
	$str =~ s/([\W])/"%" . uc(sprintf("%2.2x",ord($1)))/eg;
	return($str);
}

sub prep_queries
{

=pod

=head2 prep_queries( \@queries [, \@metanames, \@stopwords ] )

Parse a list of query strings and return them as individual word/phrase tokens.
Removes stopwords and metanames from queries.

	my @q = $hiliter->prep_queries( ['foo', 'bar', 'baz'] );
		
The reason we support multiple @query instead of $query is to allow for compounded searches.

Don't worry about 'not's since those aren't going to be in the
results anyway. Just let the highlight fail.

NOTE that you do not need to pass @stopwords when you used the SWISHE option in the new()
call, since the HiLiter object will contain a StopWords parameter.

=cut

	require Text::ParseWords;

	my $self = shift;
	my @query = @{ shift(@_) };
	my $metanames = shift || [];
	my $stopwords = shift || $self->{StopWords} || [];
	$stopwords = [ split(/\s+/, $stopwords) ] if ! ref $stopwords;

	
	my (%words,%uniq);
	
	my $quot = ord($Delim);
	my $lparen = ord('(');
	my $rparen = ord(')');
	my $paren_regexp = '\(|\)' . '|\x'. $rparen . '|\x' . $lparen;
	
	my $Q = join('|', $Delim, $quot );
	
	Q: for my $q (@query) {
		chomp $q;
		
		print $OC . "raw:$q:" . $CC if $debug == 1;
		
		# remove any swish metanames from each query
		$q =~ s,\b$_\s*=\s*,,gi for @$metanames;
				
		# no () groupers
		# replace with space, in case we have something like
		# (foo)(this or that)
		$q =~ s,$paren_regexp, ,g;
		
		print $OC . "ready:$q:" . $CC if $debug == 1;

		#$q =~ s/($Q)(.*?)($Q)/ eval { $phrases{$2}++ } /xesgi;
		# substitution removes phrases and remembers them in hash
		
		#$q =~ s/(\S+)/ eval { $words{$1}++ } /xesgi;
		# same for singleton words
		
		my @words = Text::ParseWords::shellwords($q);
		
		$uniq{$_}++ for @words;
	}

	# clean up:

	# strip singleton \ slashes, since highlite will quotemeta 
	#s/\\([^\\])/$1/g, s/\\\\/\\/g, s/^\s+|\s+$//g
	#	for (keys %phrases, keys %words);

	# no extra whitespace, and everything unique
	#s/\s+/\ /g, s/^\s+|\s+$//g, $uniq{$_}++
	#	for (keys %words);

	#delete $uniq{''};
	#delete $uniq{0};	# parsing errors generate this value
	# remove keywords from words but not phrases
        # because we can search for a literal 'and' or 'or' inside a phrase
	delete $uniq{'and'};
        delete $uniq{'or'};
        delete $uniq{'not'};
	
	# no individual stopwords should get highlighted
	# but stopwords in phrases should.
	delete $uniq{$_} for @$stopwords;
	
	#print "\n". '=' x 20 . "\n" if $debug;
	for (keys %uniq) {
		print $OC .  ':'. $_ . ":" . $CC if $debug == 1;
		
		# double-check that we don't have something like foo and foo*
		
		if ($_ =~ m/\*/) {
			(my $b = $_) =~ s,\*,,g;
			if (exists($uniq{$b})) {
				delete($uniq{$b});	# ax the more exact of the two
							# since the stemmed * will match both
			}
		}
		
		
	}
	print $OC . '~' x 40 . $CC if $debug == 1;	
	
	return ( [ sort keys %uniq ] );	# sort just makes repeated debuggings easier
}

sub Report
{

=pod

=head2 Report

Return a summary of how many instances of each query were
found, how many highlighted, and how many missed.

=cut

	my $self = shift;
	my $report;
	if ($self->{Report}) {
		$report .= "HTML::HiLiter report:\n";
		my $r = $self->{Report};
		for my $query (sort keys %$r) {
			$report .= "$query\n";
			for my $cat (sort keys %{ $r->{$query} }) {
				my $val = '';
				if (ref $r->{$query}->{$cat} eq 'HASH') {
					$val = "\n";
					$val .= "\t  $_ ( $r->{$query}->{$cat}->{$_} )\n"
					 for keys %{ $r->{$query}->{$cat} };
				} else {
					$val = $r->{$query}->{$cat};
				}
				$report .= "\t$cat -> $val\n";
			}
		}
	}

	# reset report, so it can be used multiply with single object
	delete $self->{Report};

	return $report;
}
		

sub get_url
{

	require HTTP::Request;
	require LWP::UserAgent;
 
 	my $self = shift;
	my $url = shift || return;

	my ($http_ua,$request,$response,$content_type,$buf,$size);

	$http_ua = LWP::UserAgent->new;
	$request = HTTP::Request->new(GET => $url);
	$response = $http_ua->request($request);
	$content_type ||= '';
	if( $response->is_error ) {
	  warn "Error: Couldn't get '$url': response code " . $response->code. "\n";
	  return;
	}

	if( $response->headers_as_string =~ m/^Content-Type:\s*(.+)$/im ) {
	  $content_type = $1;
	  $content_type =~ s/^(.*?);.*$/$1/;		# ignore possible charset value???
	}

	$buf = $response->content;
	$size = length($buf);
	
	$url = $response->base;
	return ($buf, $url, $response->last_modified, $size, $content_type);
	
}

	
1;

__END__

=pod

=head1 EXAMPLES

=head2 Filesystem

A very simple example for highlighting a document from the filesystem.
	
	use HTML::HiLiter;
	
	my $hiliter = new HTML::HiLiter;
	
	#$HTML::HiLiter::debug=1;	# uncomment for oodles of debugging info
	
	my $file = shift || die "$0 file.html expr\n";
	
	# you should do some error checks on $file for security and sanity
	# same with ARGV
	my @q = @ARGV;
	
	$hiliter->Queries(\@q);
	
	select(STDOUT);
	
	$hiliter->CSS;
	
	$hiliter->Run($file);
	
	# if you wanted to know how accurate you were.
	warn $hiliter->Report;	


=head2 SWISH::API

An example for SWISH::API users (SWISH-E 2.4 and later).

	#!/usr/bin/perl

	# highlight swishdescription text in search results.
	# use as CGI script.
	# NOTE this is not a pretty output -- dress it up as you will
	
	use CGI;
	my $cgi = new CGI;
	$| = 1;
	
	print $cgi->header;
	
	print "<pre>";
	
	use SWISH::API;
	
	my $index = 'index.swish-e';
	
	my @metanames = qw/ swishtitle swishdefault swishdocpath /;
	
	my $swish = SWISH::API->new( $index );
	
	use HTML::HiLiter;
	
	#$HTML::HiLiter::debug = 1;
	my $hiliter = new HTML::HiLiter(
				#Force => 1,  # because swishdescription
					     # is not stored as HTML
				SWISHE => $swish,
				Parser=> 0,  # don't load HTML::Parser
				);
	


        $swish->AbortLastError
               if $swish->Error;

        my $search = $swish->New_Search_Object;

	my @query = $cgi->param('q');
	
	@query || die "$0 'words to query'\n";

        my $results = $search->Execute( join(' ', @query) );

        $swish->AbortLastError
               if $swish->Error;
	       
        my $hits = $results->Hits;
        if ( !$hits ) {
               print "No Results\n";
               exit;
        }

        print "Found ", $results->Hits, " hits\n";

	my $query_str = join(' ', @query );
	my @parsed_query = keys %{ $hiliter->Queries(
					[ $query_str ],
					[ @metanames ]
					)
				};
	$hiliter->Inline;

        # highlight the queries in each file description
	
	# NOTE that this will print ALL results
	# so in a real SWISH application, you'd likely
	# quit after N number of results.
	
	# NOTE too that swishdescription does NOT store
	# HTML text per se, just tagless characters as parsed
	# by the indexer. But since SWISH-E is often used
	# via CGI, this lets the output from your CGI
	# script show higlighted.
	
	# and finally, NOTE that swishdescription is,
	# by default, pretty long (> 100 chars), so
	# we do a test and a little substr magic to avoid
	# printing everything.	
	
	while ( my $result = $results->NextResult ) {
          
	  print "Rank: ", $result->Property( 'swishrank' ), "\n";
	  print "Title: ", $result->Property( 'swishtitle' ), "\n";
	  print "Path: ", $result->Property( 'swishdocpath' ), "\n";

	  my $snippet = get_snippet ( $result->Property( "swishdescription" ) );
	
	  print $hiliter->hilite( $snippet );
	  
	  # warn $hiliter->Report if $hiliter->Report;
	  # comment in for some debugging.
	  
	  print "\n<hr/ >\n";
	
	}
	
	print "\n";
	
	print "</pre>";
	
	sub get_snippet
	{
		my $context_chars = 100;
	
		my %char = (
		'>' 	=> '&gt;',
		'<' 	=> '&lt;',
		'&' 	=> '&amp;',
		'\xa0' 	=> '&nbsp;',
		'"'	=> '&quot;'
		);

		my $desc = shift || return '';
		# test if $desc contains any of our query words
	  	my @snips;
	  	Q: for my $q (@parsed_query) {
	  	  if ($desc =~ m/(.*?)(\Q$q\E)(.*)/si) {
			my $bef = $1;
			my $qm = $2;
			my $af = $3;
			$bef = substr $bef, -$context_chars;
			$af = substr $af, 0, $context_chars;
			
			# no partial words...
			$af =~ s,^\S+\s+|\s+\S+$,,gs;
			$bef =~ s,^\S+\s+|\s+\S+$,,gs;

			push(@snips, "$bef $qm $af");
		  }
	  	}
	  	my $ellip = ' ... ';
	  	my $snippet = $ellip. join($ellip, @snips) . $ellip;
	  
	  	# convert special HTML characters
 	  	$snippet =~ s/([<>&"\xa0])/$char{$1}/g;
		
		return $snippet;
		
	}



=head2 A simple CGI script.

	#!/usr/bin/perl -T
	#
	# usage: hilight.cgi?f='somefile_or_url';q='some words to highlight'

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
	
	

=head1 BACKGROUND

Why one more highlighting module?
My goal was complete, exhaustive, tear-your-hair-out efforts to highlight HTML.
No other modules I found on the web supported nested tags within words and phrases,
or character entities.

I assume ISO-8859-1 Latin1 encoding. Unicode is beyond me at this point,
though I suspect you could make it work fairly easily with 
newer Perl versions (>= 5.8) and the 'use locale' and 'use encoding' pragmas.
Thus regex matching would work with things like \w and [^\w] since perl
interprets the \w for you.

I think I follow the W3C HTML 4.01 specification. Please prove me wrong.

B<Prime Example> of where this module overcomes other attempts by other modules.

The query 'bold in the middle' should match this HTML:

	<p>some phrase <b>with <i>b</i>old</b> in&nbsp;the middle</p>

GOOD highlighting:

	<p>some phrase <b>with <i><span>b</span></i><span>old</span></b><span>
	in&nbsp;the middle</span></p>

BAD highlighting:
	
	<p>some phrase <b>with <span><i>b</i>bold</b> in&nbsp;the middle</span></p>
	

No module I tried in my tests could even find that as a match (let alone perform
bad highlighting on it), even though indexing programs like SWISH-E would consider
a document with that HTML a valid match.

=head1 LOCALE

NOTE: locale settings will affect what [\w] will match in regular expressions.
Here's a little test program to determine how \w will work on your system.
By default, no locale is set in HTML::HiLiter, so \w should default to the
locale with which your perl was compiled.

This test program was copied verbatim from http://rf.net/~james/perli18n.html#Q3

I find it very helpful.

=head2 Testing locale

  #!/usr/bin/perl -w
  use strict;
  use diagnostics;

  use locale;
  use POSIX qw (locale_h);

  my @lang = ('default','en_US', 'es_ES', 'fr_CA', 'C', 'en_us', 'POSIX');

  foreach my $lang (@lang) {
   if ($lang eq 'default') {
      $lang = setlocale(LC_CTYPE);
   }
   else {
      setlocale(LC_CTYPE, $lang)
   }
   print "$lang:\n";
   print +(sort grep /\w/, map { chr() } 0..255), "\n";
   print "\n";
  }


=head1 TODO

=over

=item *

Better approach to stopwords in prep_queries().

=item *

Highlight IMG tags where ALT attribute matches query??

=item *

Support the TagFilter and TextFilter parameters. This will
extend the use of HiLiter as an HTML filter. For example,
you might want every link in your highlit HTML to point
back at your CGI script, so that every link target gets highlighted
as well.
	

=back

=head1 HISTORY

 * 0.05
	first CPAN release

 * 0.06
	use Text::ParseWords instead of original clumsy regexps in prep_queries()
	add support for 8211 (ndash) and 8212 (mdash) entities
	tweeked StartBound and EndBound to not match within a word
	fixed doc to reflect that debugging prints on STDOUT, not STDERR

 * 0.07
	made HTML::Parser optional to allow for more flexibility with using methods
	added perldoc for previously undocumented methods
	corrected perldoc for Queries() to refer to metanames as second param
	updated SWISH::API example to avoid using HTML::Parser
	added unicode entity -> ascii equivs for better DocBook support
	  (NOTE: this expands the ndash/mdash feature from 0.06)
	misc cleanup
	
 * 0.08
 	fixed bug in SWISH::API example with ParsedWords and updated Queries()
	  perldoc to reflect the change.
	removed dependency on HTML::Entities by hardcoding all relevant entities.
	  (HTML::Entities does a 'require HTML::Parser' which made the parser=>0
	  feature break.)
	  
 * 0.09
 	added Print feature to new() to allow Run() to return highlighted text instead
	  of automatically printing in a streaming fashion. Set Print=>0 to turn off print().
	Run() now returns highlighted text if Print=>0.
	changed parser=>0 to Parser=>0.
	the ParsedWords bug reported in 0.08 was really with my example in get_snippet().
	  so rather than blame someone else's code, I fixed mine... :)
	fixed bug with count of real HTML matches that was most evident with running hilite()
	added test2.t test to test the Parser=>0 feature
	
 * 0.10
 	fixed prep_queries() perldoc head
	Queries() now returns hash ref of q => regexp
	fixed SWISH::API example to use new Queries()
	fixed Queries() perldoc
	added StopWords note to prep_queries()
	fixed regexp that caused make test to fail in perl < 5.8.1 (thanks to m@perlmeister.com)
	added note to hilite() perldoc to always use Inline()
	
	
=head1 KNOWN BUGS

Report() may be inaccurate when Links flag is on. Report() may be inaccurate
if the moon is full. Report() may just be inaccurate, plain and simple. Improvements
welcome.

HiLiter will not highlight literal parentheses ().

Phrases that contain stopwords may not highlight correctly. It's more a problem of *which*
stopword the original doc used and is not an intrinsic problem with the HiLiter, but
noted here for completeness' sake.


=head1 AUTHOR

Peter Karman, karman@cray.com

Thanks to the SWISH-E developers, in particular Bill Moseley for graciously
sharing time, advice and code examples.

Comments and suggestions are welcome.

=cut

=pod

=head1 COPYRIGHT

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


=head1 SUPPORT

Send email to swpubs@cray.com.

=cut
