=pod

=head1 NAME

HTML::HiLiter - highlight words in an HTML document just like a felt-tip HiLiter

=head1 VERSION

0.13

=cut

# TODO: would HTML::Tree be faster?
# or even XML::LibXML since we assume libxml2 for swish-e?
# perhaps experiment with both and toggle on the fly?


package HTML::HiLiter;

use 5.006001;
use strict;
use sigtrap qw(die normal-signals error-signals);

use vars qw( 
		$VERSION $BegChar $EndChar $WordChar $White_Space $HiTag $HiClass
		$CSS_Class $hrefs $buffer $Debug $Delim $color $nocolor
		$OC $CC %entity2char %codeunis %unicodes %char2entity $ISO_ext
		@whitesp $SkipTag
		);
		

my $ticker;

eval { require Pubs::Times; };

unless ($@) {

	$ticker = 1;
	Pubs::Times::tick('start ok');
}

#$ticker = 0;


$VERSION = '0.13';


$OC = "\n<!--\n";
$CC = "\n-->\n";

$SkipTag = '';


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

# a subset of chars per SWISH
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

$WordChar = '\w' . $ISO_ext . './-';

$BegChar = '\w' . $ISO_ext . './-';

$EndChar = '\w' . $ISO_ext;

# regexp for what constitutes whitespace in an HTML doc
# it's not as simple as \s|&nbsp; so we define it separately

# NOTE that the pound sign # seems to need escaping, though that seems like a perl bug to me.
# Mon Sep 20 11:34:04 CDT 2004

@whitesp = (
		'&\#0020;',
		'&\#0009;',
		'&\#000C;',
		'&\#200B;',
		'&\#2028;',
		'&\#2029;',
		'&nbsp;',
		'&\#32;',
		'&\#160;',
		'\s',
		'\xa0',
		'\x20',
		);

$White_Space 	= join('|', @whitesp);

$HiTag 		= 'span';	# what tag to use to hilite

$HiClass        = undef;        # what class to use (none by default)

$CSS_Class 	= 'hilite';

$buffer 	= '';		# init the buffer

$hrefs 		= [];		# init the href buffer (for Links option)

$Delim 		= '"';		# phrase delimiter

$Debug 		= 0;		# set to 0 to turn off debugging comments

# if we're running via terminal (usually for testing)
# and the Term::ANSIColor module is installed
# use that for debugging -- easier on the eyes...

# if we were really clever, we might rotate colors ala span class

$color = '';
$nocolor = '';


if ( $ENV{HTML_HILITER_TERMINAL} ) {
	eval { require Term::ANSIColor };
	unless ($@) {
		
		$color = Term::ANSIColor::color('bold blue');
		$nocolor = Term::ANSIColor::color('reset');
		
	}
}


my $HiLiting = 0;	# flag initially OFF, then turned ON
			# whenever we pass out of <head>

my $tag_regexp = '(?s-mx:<[^>]+>)';	# this might miss comments inside tags
					# or CDATA attributes
					# unless HTML::Parser is used

my %common_char = (
		'>' 	=> '&gt;',
		'<' 	=> '&lt;',
		'&' 	=> '&amp;',
		#'\xa0' 	=> '&nbsp;',	# this is ok asis
		'"'	=> '&quot;',
		#"\xa0"	=> ' '
		);

sub new
{
	my $package = shift;
	my $self = {};
	bless($self, $package);
	$self->_init(@_);
	return $self;
}

sub _swish_new
{
# takes a SWISH::API object and
# uses the SWISH methods to set WordChar, etc.

	my $self = shift;
	my $swish_obj = $self->{SWISHE} || $self->{SWISH};
	
	# use standard name internally, for calling SWISH:: methods like Stemming
	$self->{swishobj} = $swish_obj;
	my @head_names = $swish_obj->HeaderNames;
	my @indexes = $swish_obj->IndexNames;
	# just use the first index, assuming user
	# won't pass more than one with different Header values
	my $index = shift @indexes;
	$self->{swishindex} = $index;
	for my $h (@head_names) {
	
		my @v = $swish_obj->HeaderValue( $index, $h );
	
		$self->{$h} = scalar @v > 1
		? [ @v ]
		: $v[0];
		
		$self->{$h} = quotemeta( $v[0] || '' ) if $h =~/char/i;
		
	}
	
	# set stemmer flag if it was used in the index
	
	$self->{stemmer} = $self->{'Stemming Applied'};

}

sub _init
{
    my $self = shift;
    $self->{'start'} = time;
    my %extra = @_;   
    @$self{keys %extra} = values %extra;
	
	$Debug = $self->{debug} if $self->{debug};
	
	# special handling for swish flag
	# allow common naming mistake :)
	_swish_new( $self ) if $self->{SWISHE} or $self->{SWISH};
	
	# default values for object
	
	$self->{WordCharacters} 	||= $WordChar;
	$self->{EndCharacters} 		||= $EndChar;
	$self->{BeginCharacters} 	||= $BegChar;
	
	# a search for a '<' or '>' should still highlight,
	# since &lt; or &gt; can be indexed as literal < and >, at least by SWISH-E
	for (qw(WordCharacters EndCharacters BeginCharacters))  {
		$self->{$_} =~ s,[<>&],,g;
		# escape some special chars in a class []
		#$self->{$_} =~ s/([.-])/\\$1/g;
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

	$self->{StartBound} ||= join('|',
				'\A',
				'[>]',
				'(?:&[\w\#]+;)',	# because a ; might be a legitimate wordchar
							# and we treat a char entity like a single char.
							# if &char; resolves to a legit wordchar
							# this might give unexpected results.
							# NOTE that &nbsp; etc is in $White_Space
				$White_Space,
				'[^' . $self->{BeginCharacters} . ']'
				);
				
	$self->{EndBound} ||= 	join('|',
				'\Z',
				'[<&]',
				$White_Space,
				'[^' . $self->{EndCharacters} . ']'
				);
				
	# the whitespace in a query phrase might be:
	#	any ignorelastchar, followed by
	#	one or more nonwordchar or whitespace, followed by
	#	any ignorefirstchar
	# define for both text and html
	
	my $igf = $self->{IgnoreFirstChar} ? qr/[$self->{IgnoreFirstChar}]*/i : '';
	my $igl = $self->{IgnoreLastChar} ? qr/[$self->{IgnoreLastChar}]*/i : '';
	
	$self->{textPhraseBound} = join '',
				$igl,
				qr/[\s\x20]|[^$self->{WordCharacters}]/is,
				'+',
				$igf;
	$self->{HTMLPhraseBound} = join '',
				$igl,
				qr/$White_Space|[^$self->{WordCharacters}]/is,
				'+',
				$igf;
				
	
	$self->{HiTag} 		||= $HiTag;
	$self->{HiClass}	= $HiClass unless( defined $self->{HiClass} );
	$self->{Colors} 	||= [ '#FFFF99', '#99FFFF', '#ffccff', '#ccccff' ];					
	$self->{Links}		||= 0;		# off by default
	
	$self->{BufferLim}	||= 100000;	# eval'ing enormous buffers can cause
						# huge bottlenecks. if buffer length
						# exceeds BufferLim, it will not be highlighted
						
	$self->{Force}		||= undef;	# wrap Inline HTML with <p> tagset
						# to force HTML interpolation by HTML::Parser
						
	# load the parser unless explicitly asked not to
	unless ( defined($self->{Parser}) && $self->{Parser} == 0)
	{
		$self->{Parser}++;
		require HTML::Parser;
		require HTML::Tagset;
		# HTML::Tagset::isHeadElement doesn't define these,
		# so we add them here
		$HTML::Tagset::isHeadElement{'head'}++;
		$HTML::Tagset::isHeadElement{'html'}++;
	}
	
	unless ( defined($self->{Print}) && $self->{Print} == 0)
	{
		$self->{Print} = 1;
	}
	
	
	$self->{TagFilter}	||= sub {};
	$self->{TextFilter}	||= sub {};
						
    	$self->{noplain}	||= 0;	# allow for plaintext() as optimization
}

sub _escape
{
	my $C = join '', keys %common_char;
	$_[0] =~ s/([$C])/$common_char{$1}/og;
	1;
}


sub _mytag
{
	my ($parser,$tag,$tagname,$offset,$length,$offset_end,$attr,$text) = @_;
	
	my $hiliter = $parser->{HiLiter};
	
	# $tag has ! for declarations and / for endtags
	# $tagname is just bare tagname
	
	if ($Debug >= 3) {
		print $OC;
		print "\n". '=' x 20 . "\n";
		print "Tag is :$tag:\n";
		print "TagName is :$tagname:\n";
		print "Offset is $offset\n";
		print "Length is $length\n";
		print "Offset_end is $offset_end\n";
		print "Text is $text\n";
		print "Attr is $_ = $attr->{$_}\n" for keys %$attr;
		print "SkipTag is :$SkipTag:\n";
		print $CC;
	}
	
	if ( $attr->{nohiliter} and $tag !~ m!^/! ) {
	# we want to not highlight this tag's contents
	
		$SkipTag = $tagname;
		#warn "skipping <$tag> with nohiliter\n";
	
	} elsif ( $SkipTag eq $tagname and $tag =~ m!^/! ) {
	# should be endtag
	
		$SkipTag = '';
	
	}
	
	
	# if we encounter an inline tag, add it to the buffer
	# for later evaluation
	
	# PhraseMarkup is closest to libxml2 'inline' definition
	if ( $HTML::Tagset::isPhraseMarkup{$tagname} )
	{
	
		my $tagfilter = $hiliter->{TagFilter};
		my $reassemble = &$tagfilter( @_ ) || $text;

		print "${OC} adding :$reassemble: to buffer ${CC}" if $Debug >= 3;
		
		$buffer .= $reassemble;	# add to the buffer for later evaluation
					# as a potential match
				
		# for Links option	
		if ($hiliter->{Links} and exists($attr->{'href'})) {
			push(@$hrefs, $attr->{'href'});
		}
					
		#warn "INLINEBUFFER:$buffer:INLINEBUFFER";
		
		return;
		
	}
	
	else
	{
		
	    if ($Debug >= 3) {
	    	Pubs::Times::tick('start buffer eval') if $ticker;
	    }
	    
	   # if we have a BufferLim defined and the current $buffer
	   # length exceeds that limit, deal with it immediately
	   # and don't highlight
	    if ($hiliter->{BufferLim} and
	    	length($buffer) > $hiliter->{BufferLim})
	    	{
	    	
	    	if ($hiliter->{Print}) {
	    		print $buffer;
	    	} else {
	    		$hiliter->{Buffer} .= $buffer;
	    	}
	    	
	    } else {
	    
# otherwise, call the hiliter on $buffer
# this is the main event
	    
	    	my $hilited = $hiliter->hilite( $buffer, $hrefs );
	    	
		# remove any NULL markers we inserted to skip hiliting
		$hilited =~ s/\000//g;
		
	    	if ($hiliter->{Print}) {
	    		print $hilited;
	    	} else {
	    		$hiliter->{Buffer} .= $hilited;
	    	}
	    	
	    	
	    }
	    
	    
	    if ($Debug >= 3) {
	    	Pubs::Times::tick('end buffer eval') if $ticker;
	    }

	    
	    $buffer = '';
	    $hiliter->{dtext} = '';
	    $hrefs = [];
		
	}

	
	# turn HiLiting ON if we are not inside the <head> tagset.
	# this prevents us from hiliting a <title> for example.
		
	unless ( $HTML::Tagset::isHeadElement{$tagname} )
	{
	
		$HiLiting = 1;
		
	}
	
	# use reassemble to futz with attribute values or tagnames
	# before printing them.
	# otherwise, default to what we have in original HTML
	#
	# NOTE: this is where we could change HREF values, for example
	
	my $tagfilter = $hiliter->{TagFilter};
	my $reassemble = &$tagfilter( @_ ) || $text;
		
	if ($hiliter->{Print}) {
		print $reassemble;
	} else {
		$hiliter->{Buffer} .= $reassemble;
	}
	
	# if this is the opening <head> tag,
	# add the <style> declarations for the hiliting
	# this lets later <link css> tags in a doc
	# override our local <style>
	
	if ( $tag eq 'head' )
	{
	  if ($hiliter->{Print}) {
		print $hiliter->{StyleHead}
			if $hiliter->{StyleHead};
	  } else {
	  	$hiliter->{Buffer} .= $hiliter->{StyleHead} if $hiliter->{StyleHead};
	  }
	}
	
}

sub _mytext
{

	my ($parser, $dtext, $text, $offset, $length) = @_;
	
	my $hiliter = $parser->{HiLiter};
	my $textfilter = $hiliter->{TextFilter};
	my $filtered = &$textfilter( @_ ) || $text;
	$hiliter->{dtext} .= $dtext;	# remember decoded to eval before calling hilite()
					# this replaces the addtional 'tagless' algorithm
					# that hilite() was doing
	unless ( $HiLiting ) {
	
		if ($hiliter->{Print}) {
		
			print $filtered;
			
		} else {
		
			$hiliter->{Buffer} .= $filtered;
			
		}
		
		
	} elsif ( $SkipTag ) {
	
	# we don't want to highlight this text but we do want to output it later
	# so delimit the text with the NULL character and skip that fragment
	# in hilite()
	
		$buffer .= "\000" . $filtered . "\000";
		
		
	} else {
	
		$buffer .= $filtered;
		
	}
	
	
	if ($Debug >= 3) {
		print 	$OC.
			"TEXT :$text:\n".
			"FILTERED: $filtered\n";
			
		print	"Added TEXT to buffer\n" if $HiLiting;
		
		print	"DECODED :$dtext:\n".
			"Offset is $offset\n".
			"Length is $length\n".
			$CC;
		
	}


}


sub _check_count
{
# return total count for all keys
	my $done;
	for (sort keys %{ $_[0] })
	{
		$done += $_[0]->{$_};
		if ($Debug >= 1 and $_[0]->{$_} > 0) {
			print "$OC $_[0]->{$_} remaining to hilite for: $_ $CC";
		}
	}
	return $done;
}


sub Queries
{
	my $self = shift;
	my $queries = shift || return $self->{Queries};
	my @Q;
	if ( ref $queries eq 'ARRAY' ) {
	
		@Q = @$queries;
		
	} else {
	
		$Q[0] = $queries;
		
	}
	
	Pubs::Times::tick('run Queries()') if $ticker;
	
	my $q_array = $self->prep_queries( \@Q, @_ );
	$self->{query_array} = $q_array;
	
	# build regexp for each uniq and save in hash
	# this lets us build regexp just once for each time we use Queries method
	# which is likely just once per use of this module
	my $q2regexp = {};
	
	for my $q (@$q_array)
	{
		$q2regexp->{$q} = $self->build_regexp( $q );
		#print "$OC REGEXP: $q\n$q2regexp->{$q} $CC" if $Debug >= 1;
	}

	$self->{Queries} = $q2regexp;
	
	return $self->{Queries} unless wantarray;
	return @$q_array;
	
}

sub Inline
{
	_make_styles_inline( @_ );
}

sub CSS
{
	_make_styles_css( @_ );
}



sub Run
{
	my $self = shift;
	my $file_or_html = shift || die "no File or HTML in HiLiter object!\n";
	
	Pubs::Times::tick('run Run()') if $ticker;
	
	$self->{Buffer} = '';	# reset
	
	my $default_h =
	sub {
	  my $s = shift;
	  my $t = shift;
	  
	  #print "TEXT NOT PARSED: $t\n";
	  
	  if ($s->{HiLiter}->{Print}) {
		
		print $t;
			
	  } else {
		
		$s->{HiLiter}->{Buffer} .= $t;
			
	  }
	
	};
	
	if (! $self->{Print}) {
		$default_h = sub { for (@_) { $self->{Buffer} .= $_ unless ref $_ } };
	}
	
	if ( -e $file_or_html )	# should handle files or filehandles
	{
	
	   $self->{File} = $file_or_html;
		
	   
	} elsif ($file_or_html =~ m/^http:\/\//i) {
	   
	   ($self->{HTML}) = _get_url($self, $file_or_html);
		
	   
	} elsif (ref $file_or_html eq 'SCALAR') {

	  $self->{HTML} = $$file_or_html;
	  
	  $self->{HTML} = '<p>' . $$file_or_html . '</p>' if $self->{Force};
	  	   
	} else {
	
		die "$file_or_html is neither a file nor a filehandle nor a scalar ref!\n";
	   
	}
	
	my $parser = new HTML::Parser(
	  unbroken_text => 1,
	  api_version => 3,
	  text_h => [ \&_mytext, 'self,dtext,text,offset,length' ],
	  start_h => [ \&_mytag, 'self,tag,tagname,offset,length,offset_end,attr,text' ],
	  end_h => [\&_mytag, 'self,tag,tagname,offset,length,offset_end,undef,text' ],
	  default_h => [ $default_h, 'self,text' ]
	);

	# subclass $self into the $parser object, so that the my...() subroutines
	# can access the data.
	# this feels ugly.
	
	# NOTE if HTML::Parser API ever changes, this might break.
	
	$parser->{HiLiter} = $self;

	# two kinds to run: File or Chunk
	if ($self->{File})
	{
		return $! unless $parser->parse_file($self->{File});
	
	}
	
	elsif ($self->{HTML})
	
	{
		return $! unless $parser->parse($self->{HTML});
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

sub plaintext
{

# faster, less accurate alternative
# use this for plain text (not HTML) as with SWISH::HiLiter

	my $self = shift;
	my $text = shift;
	# $text should have no entities or tags, because our simple regular
	# expression may not account for those.
	_escape( $text );
	
	Pubs::Times::tick('start plaintext()') if $ticker;
	Pubs::Times::tick( join("\n", caller ) ) if $ticker;

	my @q = $self->{sortedq} ? @{ $self->{sortedq} } : sort keys %{ $self->{Queries} };
	$self->{sortedq} ||= [ @q ];	# cache it
	
	Q: for my $q (@q)
	{
	
	    my $re = $self->{Queries}->{$q}->[1] || warn "no re for $q\n", next Q;
	    my $o = $self->{OTags}->{$q} || '';
	    my $c = $self->{CTags}->{$q} || '';
		
		
		#print $OC . "looking for $re in $text" . $CC;
		#print $OC . "to replace with ${o}${color}${q}${nocolor}${c} " . $CC;
		
		#warn "looking for '$re' in '$text'\n";
		#warn "to replace with '${o}${color}${q}${nocolor}${c}'\n";
		
		# do it
	    my $cnt = 0;
		
		# because s// fails to find duplicate instances like 'foo foo'
		# we use a while loop and increment pos()
		
		#select(STDERR);
		
	# this can suck into an infinite loop because increm pos()-- results
	# in repeated match on nonwordchar: > (since we just added a tag)
	
	    while ( $text =~ m/$re/g ) {
		$cnt++;
		#warn "cnt is $cnt\n";
		
		# these should obviously be all defined, but...
		my $s = $1 || '';
		my $m = $2 || $q;
		my $e = $3 || '';
		if ( $Debug >= 2 )
		{
			#print "$OC add_hilite_tags:\n$st_bound\n$safe\n$end_bound\n $CC";
			print "$OC matched:\n'$s'\n'$m'\n'$e'\n $CC";
			print "$OC \$1 is " . ord( $s ) . $CC;
			print "$OC \$3 is " . ord( $e ) . $CC;
		}
		
		# use substr to do what s// would normally do if pos() wasn't an issue
		# -- is this a big speed diff?
		my $len = length($s.$m.$e);
		my $pos = pos($text);
		my $newstring = $s.$o.$color.$2.$nocolor.$c.$e;
		substr( $text, $pos - $len, $len, $newstring );
		
		#warn "new text: '$text'\n";
		
		last if $pos == length $text;
		
		#warn "pos is $pos\n";
		# need to account for all the new chars we just added with length(...)
		pos($text) = $pos + length( $o.$color.$nocolor.$c ) - 1;
		# move past close tag, but back 1 to reconsider $3 as next $1
		#warn "pos now ", pos($text), "\n";
		#warn "new start chars are '", substr( $text, pos($text), 10 ), "'\n";
		
	    }
		#select(STDOUT);
		
		#$cnt = ($text =~ s/$re/${1}${o}${color}${2}${nocolor}${c}${3}/g);
		
	    $self->{Report}->{$q}->{HiLites} += $cnt;
	    $self->_report( { $q => $cnt } );
		
	}
	
	Pubs::Times::tick('end plaintext()') if $ticker;
	
	return $text;

}

sub htmltext
{
# just a placeholder really

	return hilite( @_ );
}


sub hilite
{

# TODO: how to speed this part up.
# 1. should we do a simple pass first to see if we match?
# 2. should we do away with the HTML::Parser version to get tagless here
# and instead do it ourselves?


	my $self = shift;
	my $html = shift || return '';	# no html to highlight
	my $links = shift || [];	# href values for Links option
	
# don't bother if we've got nothing to look at
	return $html unless $html =~ m/\S/;
	
	
		
	$self->{hilitecalled}++;
	
	Pubs::Times::tick('start hilite()') if $ticker;
	
	delete $self->{Report} unless $self->{Parser}; #reset if called directly
	
	if ($Debug >= 1) {
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

	my $tagless = $self->{dtext} || $html;	# if we didn't have dtext, we weren't using HTML::Parser
	
# if the html has no tags or entities, call plaintext() instead
	if ( 
        $tagless eq $html and
		$tagless !~ m/[<>&]/ and
		! $self->{noplain}
		) {
		return $self->plaintext( $html );
	}
	
	
	
	$tagless =~ s/\000.*?\000//sgi;	# don't consider anything we've marked
					# with a 'nohiliter' attribute
				
	
	for my $num (keys %unicodes)
	{
		$tagless =~ s/&#$num;/$unicodes{$num}/g;
		# some special Unicode entities
		# that get special ascii equivs for DocBook source
	}
	
	# replace all nonWordChars with a space, so that we can get accurate
	# representation of how SWISH indexes
	my $wc = $self->{WordCharacters};
	$tagless =~ s/[^$wc]/ /ogi;	# does -o really make a diff?
	
	# should replace all StopWords with a space, for same reason
	# but that would result in a truly unwieldy regexp when trying to match
	# real HTML. We just have to suffer this as a limitation.
	
	
	print $OC . "TAGLESS: $tagless :TAGLESS" , $CC if $Debug >= 1;
		
	my $count = {};
	
	my @all_queries = sort keys %{ $self->{Queries} };
	
	Q: for my $q (@all_queries)
	{
		#print "counting $q...\n";
		my $re = $self->{Queries}->{$q}->[1];
		$count->{$q} = _count_instances($self, $q, $tagless, $links, $re) || 0;
		print $OC . "COUNT for '$q' is $count->{$q}" . $CC if $Debug >= 1;
	}

	
	#print "COUNT: $_ -> $count->{$_}\n" for keys %$count;

    unless ( $count or _check_count($count) ) {
	
		# do nothing

    } else {

	# 2. start looking for real HTML to hilite
	
	my $q2real = {};
	# this is going to be query => [ real_html ]
	
	# if the query text matched in the text, then we need to
	# use our prebuilt regexp
	
	# if the query text matches in a link, then we simply? need
	# to look for (<a.*?href=(['"])$link\2.*?>.*?</a>)
	# and let the add_hilite_tags decide where to put the hiliting tags

	my @instances = sort keys %$count; # sort is just to make debugging easier

	Q: for my $q (@instances) {
	
		next Q if ! $count->{$q};
		
		print $OC . "FOUND '$q' $count->{$q} times" . $CC if $Debug >= 1;
		
		my $reg_exp = $self->{Queries}->{$q}->[0];
		
		my $real = _get_real_html( $html, $reg_exp );
		
		R: for my $r (keys %$real) {
		
			print $OC . "REAL appears to be $r ($real->{$r} instances)" , $CC if $Debug >= 1;
			
			push(@{ $q2real->{$q} }, $r ) while $real->{$r}--;
			
		}
		
		if ($self->{Links}) {
		   LINK: for my $link (@$links) {
		   
		   	print $OC . "found LINK: $link" , $CC if $Debug >= 1;
			
			my $s = quotemeta($link);
	
	# thanks to Mike Schilli m@perlmeister.com for this regexp fix
			#my $re = qq!(.?)(<a.*?href=['"]${s}! . qq!"["'].*?>.*?</a>)(.?)!;
		
		# changed to more accurate submatch with \\3 - Sat Oct 23 22:51:59 CDT 2004

			my $re = qq/(.?)(<a.*?href=(['"])${s}/ . qq!\\3.*?>.*?</a>)(.?)!;
			
			my $link_plus_txt = _get_real_html( $html, $re );
			
			R: for my $r (keys %$link_plus_txt) {
			
			# if the href and the link text both match, don't count each
			# one; omit the href, since the link text should be caught
			# by the standard @instances
			
				my ($href,$ltext) = ($r =~ m,<a.*?href=['"](.*?)["'].*?>(.*?)</a>,is );
				
				print 	$OC .
				 	"LINK:\nhref is $href\n".
					"ltext is $ltext".
					$CC if $Debug >=1;
				
				if ( $ltext =~ m/$re/isx ) {
					print $OC . "SKIPPING LINK as duplicate" . $CC if $Debug >=1;
					$count->{$q}--;
					next R;
				}
			
				print $OC . "REAL LINK appears to be $r" , $CC if $Debug >= 1;
				
				push( @{ $q2real->{$q} }, $r) while $link_plus_txt->{$r}--;
				
			}
		   }
		}
		
		$self->{Report}->{$q}->{Instances} += scalar(@{ $q2real->{$q} || [] });
		
		print $OC . "before any hiliting, count for '$q' is $self->{Report}->{$q}->{Instances} " . $CC
			if $Debug >= 1;
		
	}
	
	# 3. add the hiliting tags
		
	HILITE: for my $q (@instances) {

	   my %uniq_reals = ();
	   $uniq_reals{$_}++ for @{ $q2real->{$q} };
	
	   REAL: for my $real (keys %uniq_reals) {
	   
	   	print $OC . "'$q' matched real:\n$real\n" . $CC if $Debug >= 1;
		
		$html = _add_hilite_tags($self, $html, $q, $real, $count);
		
	   }
	   
	}	
	
	
    }
	# no matter what, if we get here, return whatever we have
	$self->_report( $count );
	
	$self->{hilitetime} += Pubs::Times::tick('end hilite()') if $ticker;
	
	return $html;

}

sub _report
{
# keep tally of how many matches vs how many successful hilites
	my $self = shift;
	my $count = shift;
	return if ! scalar(keys %$count);
	
	my $file = $self->{File} || '[unknown file]';	# if we eval \$file, we don't care.
	for (keys %$count) {
		next if $count->{$_} <= 0;
		$self->{Report}->{$_}->{Misses}->{$file} += $count->{$_};
	}

}


sub _make_styles_css
{
	# create <style> tagset for header
	# and for subsequent substitutions
	
	# each query gets assigned a letter
	# and in the header, each letter is assigned a color
	
	my $self = shift;
	my $queries = $self->{query_array};
	my $tagset = qq( <STYLE TYPE="text/css"> $OC );
	my $num = 0; 
	my @colors = @{ $self->{Colors} };
	my $tag = $self->{HiTag};
	for (@$queries) {
		
		$tagset .= qq( \n
			$tag.$CSS_Class$num
			{
			   background : $colors[$num];
			}
			) unless $tagset =~ m/$CSS_Class$num/;
			# only define it once
			# but assign a definition to each query
                my $s = '';
                # use HiClass if we have it
                if( defined $self->{HiClass} ) {
                    # this allows for having an empty, but defined HiClass
                    $s = "class='$self->{HiClass}'" if $self->{HiClass};
                } else {
		    $s = "class='" . $CSS_Class.$num++ . "'";
                }

		$self->{OTags}->{$_} = $s ? "<$tag $s>" : "<$tag>";
		$self->{CTags}->{$_} = "</$tag>";	# this is always the same; should we bother?
		$num = 0 if $num > $#colors;	# start over if we exceed
						# total number of colors
	}
	
	$tagset .= " $CC </STYLE>\n";
	$self->{StyleHead} = $tagset;

	1;
}

sub _make_styles_inline
{
	# create hash for adding style attribute inline
	# each query gets assigned a color
	
	my $self = shift;
	my $queries = $self->{query_array};
	my $num = 0; 
	my @colors = @{ $self->{Colors} };
	my $tag = $self->{HiTag};
	for (@$queries) {
		
                my $s = '';
                # if we are using HiClass
                if( defined $self->{HiClass} ) {
                    # this allows for having an empty, but defined HiClass
		    $s = "class='$self->{HiClass}'" if( $self->{HiClass} );
                # else, use the color
                } else {
		    $s = "style='background:" . $colors[$num++] . "'";
                }
		$self->{OTags}->{$_} = $s ? "<$tag $s>" : "<$tag>";
		$self->{CTags}->{$_} = "</$tag>";	# this is always the same; should we bother?
		$num = 0 if $num > $#colors;	# start over if we exceed
						# total number of colors
	}
	
	1;

}


sub _get_real_html
{

# this could be a bottleneck if buffer is really large
# so use $self->{BufferLim} to avoid that.
# or can the s//eval{}/ approach be improved upon??

	if ($Debug >= 3) {
	
		Pubs::Times::tick('start get real html') if $ticker;
		
	}
	
	my ($html,$re) = @_;
	my $uniq = {};

	# $1 should be st_bound, $2 should be query, $3 should be end_bound
	
	#warn "looking for '$re' in '$html'\n";
	while( $html =~ m/$re/g ) {
	
#		print $OC,
#		 "\$1 is '$1'\n",
#		 "\$2 is '$2'\n",
#		 "\$3 is '$3'\n",
#		 $CC;
		
		$uniq->{$2}++;
		pos($html) = pos($html) - 1;
		# move back and consider $3 again as possible $1 for next match
		
	}
	#$html =~ s$reeval { $uniq->{$2}++ }gisex;
	
	#print $OC . "UNIQ looked for \n$re\n" . $CC;
	#print $OC . "UNIQ: $_\n" . $CC for keys %$uniq;

	
	if ($Debug >= 3) {
	
		Pubs::Times::tick('end get real html') if $ticker;
		
	}

	
	
	return $uniq;

}


sub _count_instances
{
	my ($self,$query,$tagless,$links,$re) = @_;
		
	print $OC, "counting instances of : $re :\nin text: $tagless\n", $CC if $Debug > 1;
	
	my $count = 0;
	
	$count++ while ( $tagless =~ m/$re/g );
	
	# second, count instances in $links (an array ref)
	# just one hit per link, even if the pattern appears multiple times
	
	for my $i (@$links)
	{
		print $OC . "looking for LINK '$i' against $re" , $CC if $Debug >= 1;
				
		$count++ while ( $tagless =~ m/$re/g );
	}
	
	
	return $count;

}

sub build_regexp
{
	my ($self,$q) = @_;
	my $wild = $self->{EndCharacters};
	my $begchars = $self->{BeginCharacters};
	my $st_bound = $self->{StartBound};
	my $end_bound = $self->{EndBound};
	my $wordchars = $self->{WordCharacters};
	my $text_phr_bound = $self->{textPhraseBound};
	my $html_phr_bound = $self->{HTMLPhraseBound};
	
# define simple pattern for plain text
# and complex pattern for HTML markup
	my ($simple,$complex);

	my $escaped = quotemeta( $q );
	$escaped =~ s/\\[\*]/[$wordchars]*/g;	# wildcard
	$escaped =~ s/\\[\s]/$text_phr_bound/g;	# whitespace
	
$simple = qr/
(
\A|[^$begchars]
)
(
${escaped}
)
(
[^$wild]|\Z
)
/xis;	# no -o because we might have multiple $q's



	my (@char) = split(//,$q);
	
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
		
		#warn "char: $c\n";
		
		
		if ($c eq '\ ') {
			$c = $html_phr_bound . $tag_regexp . '*';
			
			#warn "whitespace: $c\n";
			
			next CHAR;
		} elsif (exists $codeunis{$c} ) {
			#warn "matched $c in codeunis\n";
			my @e = @{ $codeunis{$c} };
			$c = join('|', $c, grep { $_ = "&#$_;" } @e );
		}
		
		#warn "c after: $c\n";
		
		my $aka = $ent eq "&#$num;" ? $ent : "$ent|&#$num;";
		
		# make $c into a regexp
		#$c = "(?i-xsm:$c|$aka)" unless $c eq "[$wild]*";
		$c = qr/$c|$aka/i unless $c eq "[$wild]*";
		#$c = "(?:$c|$aka)";
		
		# any char might be followed by zero or more tags, unless it's the last char
		$c .= $tag_regexp . '*' unless $counter == $#char;

		
 	}
	 
	# re-join the chars into a single string
 	my $safe = join("\n",@char);	# use \n to make it legible in debugging
	
# for debugging legibility we include newlines, so make sure we s//x in matches
$complex =qr/
(
${st_bound}
)
(
${safe}
)
(
${end_bound}
)
/xis;	# no -o because we have multiple $safe's
	
	
	#warn "complex: '$complex'\n";
	#warn "simple:  '$simple'\n";
	
	
	return [ $complex, $simple ];
}

sub _add_hilite_tags
{
	my ($self,$html,$q,$to_hilite,$count) = @_;
	
	# $to_hilite is the real html that matched our regexp in _get_real...
	
	# we still check boundaries just to be safe...
	my $st_bound = $self->{StartBound};
	my $end_bound = $self->{EndBound};
	
	my $open = $self->{OTags}->{$q};
	my $close = $self->{CTags}->{$q};

	_ascii_chars($html) if $Debug >= 3;

	my $safe = quotemeta($to_hilite);
		
	# pre-fix nested tags in match
	my $prefixed = $to_hilite;
	my $pre_added = $prefixed =~ s($tag_regexp+)${nocolor}$close$1$open${color}g;
	my $len_added = length( $nocolor.$close.$open.$color) * $pre_added;
	# should be same as length( $to_hilite) - length( $prefixed );
	my $len_diff = ( length( $to_hilite ) - length( $prefixed ) );
	$len_diff *= -1 if $len_diff < 0;	# pre_added might be -1 if no subs were made
	if ( $len_diff != $len_added ) {
		warn "length math failed!\n";
		warn "len_diff = $len_diff\nlen_added = $len_added\n";
	}
	
		
	my $c = 0;
	
	while ( $html =~ m/($st_bound)($safe)($end_bound)/g ) {
		$c++;
		my $s = $1;
		my $m = $2;
		my $e = $3;
		if ( $Debug >= 2 )
		{
			#print "$OC add_hilite_tags:\n$st_bound\n$safe\n$end_bound\n $CC";
			print "$OC matched:\n'$s'\n'$m'\n'$e'\n $CC";
			print "$OC \$1 is " . ord( $s ) . $CC;
			print "$OC \$3 is " . ord( $e ) . $CC;
		}
		
		# use substr to do what s// would normally do if pos() wasn't an issue
		# -- is this a big speed hit?
		my $len = length($s.$m.$e);
		my $pos = pos($html);
		my $newstring = $s.$open.$color.$prefixed.$nocolor.$close.$e;
		substr( $html, $pos - $len, $len, $newstring );
		
		pos($html) = $pos + length( $open.$color.$nocolor.$close ) + $len_added - 1;
		# adjust for new text added
		# $prefixed is the hard bit, since we must take $len_added into account
		# move back 1 to reconsider $3 as next $1
		
#		warn "pos was $pos\nnow ", pos( $html ), "\n";
#		warn "new: '$html'\n";
#		warn "new text: '$newstring'\n";
#		warn "first chars of new pos are '", substr( $html, pos($html), 10 ), "'\n";
		
		
	}
	
	# put this in while() loop above so we can futz with pos()
	#$c = ($html =~ s/($st_bound)($safe)($end_bound)/$1${open}${color}${prefixed}${nocolor}${close}$3/g );
							# no -s, -i or -x flags wanted or needed
							# since we watch exact (case sensitive) matches
							# on real, previously identified HTML
							# but -g to get all instances
							
	
	
	if ($Debug >= 1) {
		print	$OC .
			"SAFE was $safe\n".
			"PREFIXED was $prefixed\n".
			"HILITED $c times\n".
			"AFTER is $html\n".
			$CC;
	}
		
	$count->{$q} -= $c;
		
	$self->{Report}->{$q}->{HiLites} += $c;
	
	$html = _clean_up_hilites($self, $html, $q, $open, $close, $safe, $count);
	
	print $OC . "AFTER hilite clean:$html:" . $CC if $Debug >= 3;
	
	return $html;

}


sub _ascii_chars
{
	my $s = shift;
	for (split(//,$s)) {
		print $OC . "$_ = ". ord($_) . $CC;
	}

}



sub _clean_up_hilites
{

# try and keep Report honest
# if it was a mistake, don't count it as an Instance
# so that it also doesn't show up as a Miss

	my ($self,$html,$q,$open,$close,$safe,$count) = @_;
	
	print $OC . "BEFORE cleanup, HiLite Count for '$q' is $self->{Report}->{$q}->{HiLites}" . $CC if $Debug >= 1;
	
	# empty hilites are useless
	my $empty = ( $html =~ s,$open(?:\Q$color\E)(?:\Q$nocolor\E)$close,,sgi ) || 0;
	
	# to be safe: in some cases we might match against entities or within tag content.
  	my $ent_split = ( $html =~ s/(&[\w#]*)$open(?:\Q$color\E)(${safe})(?:\Q$nocolor\E)$close([\w#]*;)/$1$2$3/igs ) || 0;
	
	my $tag_split = 0;
	while ( $html =~ m/(<[^<>]*)\Q$open\E(?:\Q$color\E)($safe)(?:\Q$nocolor\E)\Q$close\E([^>]*>)/gxsi ) {	

		print "$OC appears to split tag: $1$2$3 $CC" if $Debug >= 1;

		$tag_split += ( $html =~ s/(<[^<>]*)\Q$open\E(?:\Q$color\E)($safe)(?:\Q$nocolor\E)\Q$close\E([^>]*>)/$1$2$3/gxsi );

		#$count->{$q} += $c;
	}
	
	$self->{Report}->{$q}->{HiLites} -= ($tag_split + $ent_split);
	$self->{Report}->{$q}->{Instances} -= ($ent_split + $tag_split);
	
	if ($Debug >= 1) {
		print 	$OC.
			"\tfound $empty empty hilite tags\n".
			"\tfound $tag_split split tags\n".
			"\tfound $ent_split split entities\n".
			$CC;
	}
	
	print "$OC AFTER cleanup, HiLite Count for '$q' is $self->{Report}->{$q}->{HiLites} $CC" if $Debug >= 1;

	
	return $html;

}

sub _metanames
{

	my $self = shift;
	my $swish = $self->{swishobj};
	my $index = ( $swish->IndexNames )[0];
	my @metaobjs = $swish->MetaList( $index );
	my @metanames;
	for (@metaobjs) {
	
		push(@metanames, $_->Name);
		
	}
	
	return @metanames;

}

sub prep_queries
{
	require Text::ParseWords;

	my $self = shift;
	my @query = @{ shift(@_) };
	my $metanames = shift || undef;
	my $stopwords = shift || $self->{StopWords} || [];
	$stopwords = [ split(/\s+/, $stopwords) ] unless ref $stopwords;

	if ( $self->{swishobj} and ! defined $metanames ) {
	# get metanames automatically
	
		$metanames = [ $self->_metanames ];
		
	}


	my (%words,%uniq);
	
	my $quot = ord($Delim);
	my $lparen = ord('(');
	my $rparen = ord(')');
	my $paren_regexp = '\(|\)' . '|\x'. $rparen . '|\x' . $lparen;
	
	my $Q = join('|', $Delim, $quot );
	
	# only SWISH would define these
	my $igf = $self->{IgnoreFirstChar} || '';
	my $igl = $self->{IgnoreLastChar} || '';
	
	Q: for my $q (@query) {
		chomp $q;
		
		#print $OC . "raw:$q:" . $CC if $Debug >= 1;
		
		# remove any swish metanames from each query
		$q =~ s,\b$_\s*=\s*,,gi for @$metanames;
				
		# no () groupers
		# replace with space, in case we have something like
		# (foo)(this or that)
		$q =~ s,$paren_regexp, ,g;
		
		my @words = Text::ParseWords::shellwords($q);
		
		# try preserving order of query for better intuitive highlighting color order
		my $c = 0;
		WORD: for my $w (@words) {
			next WORD if exists $uniq{$w};
			
			
		# remove any Ignore chars, since search will ignore them too
		#warn "s/(\A|\s+)[$igf]*/$1/gi\n";
		#warn "s/[$igl]*(\Z|\s+)/$1/gi\n";
			$w =~ s/(\A|\s+)[$igf]*/$1/gi if $igf;
			$w =~ s/[$igl]*(\Z|\s+)/$1/gi if $igl;
			
			
			$uniq{$w} = $c++;
		}
		
	}

	# clean up:

	delete $uniq{''};
	delete $uniq{0};	# parsing errors generate this value
	# remove keywords from words but not phrases
        # because we can search for a literal 'and' or 'or' inside a phrase
	delete $uniq{'and'};
        delete $uniq{'or'};
        delete $uniq{'not'};
	
	# no individual stopwords should get highlighted
	# but stopwords in phrases should.
	delete $uniq{$_} for @$stopwords;
	
	#print "\n". '=' x 20 . "\n" if $Debug;
	for (keys %uniq) {
	#	print $OC .  ':'. $_ . ":" . $CC if $Debug >= 1;
		
		# double-check that we don't have something like foo and foo*
		
		if ($_ =~ m/\*/) {
			(my $b = $_) =~ s,\*,,g;
			if (exists($uniq{$b})) {
				delete($uniq{$b});	# ax the more exact of the two
							# since the * will match both
			}
		}
		
		
	}
	#print $OC . '~' x 40 . $CC if $Debug >= 1;
	
# if stemmer flag is turned on, that means we're dealing with a swish::api instance
# and we need to stem each query word after we're through.
# in order to build a sane regexp, we take the first N common chars from the original
# word and the stemmed word.

	if ( $self->{stemmer} )
	{
	# split each $uniq into words
	# stem each word
	# if stem ne word, break into chars and find first N common
	# rejoin $uniq
	
		#warn "stemming ON\n";
	
		K: for ( keys %uniq ) {
			my (@w) = split /\ /;
			W: for my $w (@w) {
				my $f = $self->_stem( $w );
				#warn "w: $w\nf: $f\n";
				
				if ( $f ne $w ) {
				
					my @stemmed = split //, $f;
					my @char = split //, $w;
					$f = '';	#reset
					while ( @char && @stemmed && $stemmed[0] eq $char[0] ) {
						$f .= shift @stemmed;
						shift @char;
					}
				
				}
				$w = $f . '*'; # add wildcard so that regexp gets built correctly
			}
			my $new = join ' ',@w;
			if ($new ne $_) {
			
				$uniq{$new} = $uniq{$_};
				delete $uniq{$_};
				
			}
		}
		
	}
	
	
	return ( [ sort { $uniq{$a} <=> $uniq{$b} } keys %uniq ] );
	# sort keeps query in same order as we entered
}

sub _stem
{
# this is a copy of SWISH::HiLiter::stem()

    my $self = shift;
    my $w = shift;
	my $i = $self->{swishindex};
	
    my $fw = $self->{swishobj}->Fuzzify( $i, $w );
    my @fuzz = $fw->WordList;
    if ( my $e = $fw->WordError ) {
    
    	warn "Error in Fuzzy WordList ($e): $!\n";
		return undef;
	
    }
    return $fuzz[0];	# we ignore possible doublemetaphone
}

sub Report
{
	my $self = shift;
	my $report;
	if ($self->{Report}) {
	    $report = "HTML::HiLiter report:\n";
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
	    
	} else {
	
	    $report = "nothing hilited\n";

	}
	
	$report .= "hilite() called " . $self->{hilitecalled} . " times\n";
	$report .= "hilite() took " . $self->{hilitetime} . " total secs\n" if $ticker;
	
# add settings summary
	if ( $Debug )
	{
		require Data::Dumper;
		$Data::Dumper::Indent = 1;
		$Data::Dumper::Deepcopy = 1;
		$report .= Data::Dumper::Dumper( $self );
		$report .= "Debug = $Debug\n";
	}
	
	$report .= '-' x 40 . "\n";	# trailing line for readability
	
	# reset report, so it can be used multiply with single object
	delete $self->{Report};

	return $report;
}
		

sub _get_url
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


=head1 DESCRIPTION

HTML::HiLiter is designed to make highlighting search queries
in HTML easy and accurate. HTML::HiLiter was designed for CrayDoc 4, the
Cray documentation server. It has been written with SWISH::API users in mind, 
but can be used within any Perl program.


=head1 SYNOPSIS

	use HTML::HiLiter;
	
	my $hiliter = new HTML::HiLiter(
	
		WordCharacters 	=>	'\w\-\.',
		BeginCharacters =>	'\w',
		EndCharacters	=>	'\w',
		HiTag =>	'span',
		Colors =>	[ qw(#FFFF33 yellow pink) ],
		Links =>	1
		TagFilter =>	\&yourtagcode(),
		TextFilter =>	\&yourtextcode(),
		Force	=>	1,
		SWISH	=>	$swish_api_object
	);
	
	$hiliter->Queries( 'foo bar or "some phrase"' );
	
	$hiliter->CSS;
	
	$hiliter->Run('some_file_or_URL');



=head1 REQUIREMENTS

The following are absolutely required:

=over

=item

Perl version 5.6.1 or later.

=item

Text::ParseWords

=back


Required if using with SWISH::HiLiter or the SWISH param in new():

=over

=item

SWISH::API version 0.03 or later

=back


Required if running with Parser=>1 (default):

=over

=item

HTML::Parser

=item

HTML::Entities

=item

HTML::Tagset

=back


Required to use the HTTP option in the Run() method:


=over

=item

HTTP::Request 

=item

LWP::UserAgent

=back


The Debug feature requires L<Data::Dumper> when you run Report().


=head1 FEATURES

A cornucopia of features.

=over

=item *

With HTML::Parser enabled (default), HTML::HiLiter evals highlighted HTML 
chunk by chunk, buffering all text
within an HTML block element before evaluating the buffer for highlighting.
If no matches to the queries are found, the HTML is immediately printed (default)
or cached and returned at the end of all evaluation (Print=>0).

You can direct the print() to a filehandle with the standard select() function
in your script. Or use Print=>0 to return the highlighted HTML as a scalar string.


=item *

Turn highlighting off on a per-tagset basis with the custom HTML "nohiliter" attribute. 
Set the attribute to a TRUE value (like 1) to turn off
highlighting for the duration of that tag.

=item *

Ample debugging. Set the $HTML::HiLiter::Debug variable to a level between 1 and 3,
and lots of debugging info will be printed within HTML comments <!-- -->.

=item *

Will highlight link text (the stuff within an <a href> tagset) if the HREF 
value is a valid match. See the Links option.

=item *

Smart context. Won't highlight across an HTML block element like a <p></p> 
tagset or a <div></div> tagset. (IMHO, your indexing software shouldn't consider 
matches for phrases that span across those tags either.)

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


=head1 VARIABLES

The following variables may be redefined by your script.

=over

=item

$HTML::HiLiter::Delim

The phrase delimiter. Default is double quotation marks (").

=item 

$HTML::HiLiter::Debug

Debugging info prints on STDOUT inside <!-- --> comments. Default is 0. Set it to 1 - 3
to enable debugging. Use the 'debug' param in new() to set this as well.

=item

$HTML::HiLiter::White_Space

Regular expression of what constitutes HTML white space.
Redefine at your own risk.

=item

$HTML::HiLiter::CSS_Class

The I<class> attribute value used by the CSS() method. Default is 'hilite'.

=back

=head1 METHODS

=head2 new()

Create a HiLiter object handle.

Many of following parameters take values that can be made into a regexp class.
If you are using SWISH-E, for example, you will want to set these parameters
equal to the equivalent SWISH-E configuration values. Otherwise, the defaults
should work for most cases.


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

=item HiClass

The HTML class attribute used within the HiTag. If not specified, the class name
will be auto generated by the Colors array.

=item Colors

A reference to an array of HTML colors.

=item Links

A boolean (1 or 0). If set to '1', consider <a href="foo">my link</a> a valid match for 
'foo' and highlight the visible text within the <a> tagset ('my link').
Default Links flag is '0'.

=item TagFilter

A CODE reference of your choosing for filtering HTML tags as they pass through the
HTML::Parser. See L<FILTERS>.

=item TextFilter

A CODE reference of your choosing for filtering HTML tags as they pass through the
HTML::Parser. See L<FILTERS>.

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

Will force Run() to wrap <p> tagset around the text you pass. This will
force the highlighting of plain text if using HTML::Parser (which depends on at least one tag
to activate highlighting). Use this only with Inline().

=item noplain

Starting with version 0.11, a plaintext() method helps optimize performance by using a
simpler algorithm for highlighting plain (nonHTML) text. If noplain=>1, the optimization
will not be used and htmltext() will be called every time.

=item SWISH

For SWISH::API compatibility. See the SWISH::API documentation and the
EXAMPLES section later in this document.

=item Parser

If set to 0 (FALSE), then the HTML::Parser module will not be loaded. This allows
you to use the regexp methods without the overhead of loading the parser. The default
is to load the parser.


=back

=head2 Queries( )

=head2 Queries( I<query> )

=head2 Queries( \@I<queries> )

=head2 Queries( \@I<queries>, \@I<metanames>, \@I<stopwords> )

=head2 Queries( \@I<queries>, \@I<metanames>, I<stopwords> )

Parse the queries you want to highlight, and create
the corresponding regular expressions in the object.
This method must be called prior to Run(), but need
only be done once for a query or queries. You may Run()
multiple times with only one Queries() setup.

Queries() requires a single parameter: either a query text string, or
a reference to an array
of words or phrases. Phrases should be delimited with
a double quotation mark (or as redefined in $HTML::HiLiter::Delim ).

If using SWISH-E, Queries() takes several factors into account.

=over

=item MetaNames

A reference to an array of a MetaNames may be passed to Queries().
If the MetaNames appear in the query,
they will be removed from the regexp used for highlighting. MetaNames used in queries
are expected to be of the form:

	meta=value

in which case the 'meta=' would be removed. There may be space before or after the '='.

B<NOTE:> If using SWISH feature, MetaNames are automatically retrieved, as are StopWords.

=item Ignore*Char

Any characters defined in IgnoreFirstChar or IgnoreLastChar will be stripped from the query.
This assumes that your search would ignore these characters anyway.

=item StopWords

Either a scalar string or an array ref of StopWords. If using SWISH feature, StopWords are
retrieved automatically.

=item FuzzyMode

a.k.a. stemming. New in version 0.11 is support for the SWISH FuzzyMode option. If FuzzyMode was used
in the SWISH::API object passed in new(), then Queries() will take the stemmed version of the word
into account.

=back


In scalar context, Queries() returns a hash ref of the queries, with key = query and value = regexp.
In array context, returns an array of queries (keys of the hash ref).

With no arguments, returns the regular expression hash ref currently in use.


=head2 Inline

Create the inline style attributes for highlighting without CSS.
Use this method when you want to Run() a piece of HTML text.



=head2 CSS

Create a CSS <style> tagset for the <head> of your output. Use this
if you intend to pass Run() a file name, filehandle or a URL.



=head2 Run( file_or_url )

Run() takes either a file name, a URL (indicated by a leading 'http://'),
or a scalar reference to a string of HTML text.

The HTML::Parser must be used with this method.

=head2 htmltext( I<html> )

Same as calling hilite().

=head2 plaintext( I<text> )

If you want to highlight plain, nonHTML text, you can use plaintext(). It uses
a simpler regexp to match your query and should be slightly faster than htmltext().
plaintext() is called automatically by hilite() if the text you pass does not
contain any <> characters.

=head2 hilite( I<html> )

Usually accessed via Run() but documented here in case you want to run without
the HTML::Parser. Returns the text, highlighted. Note that CSS() will probably
not work for you here; use Inline() prior to calling this method, 
so that the object has the styles defined.

See also L<SWISH::HiLiter> which uses this method.

Example:

	my $hilited_text = $hiliter->hilite('some text');


=head2 build_regexp( I<words_to_highlight> )

Returns the regular expression for a string of word(s). Usually called by Queries()
but you might use directly if you are running
without the HTML::Parser.

	my $pattern = $hiliter->build_regexp( 'foo or bar' );

This is the heart of the HiLiter. We leverage the speed of Perl's regexp engine 
against the complication of a regexp that matches inline tags, entities, and combinations of both.

B<NOTE:> $pattern is an array ref of two regexps: the first is a complex one for HTML, the second
is a simpler one for plain text. Access them like:

	my $complex = $pattern->[0];
	my $simple = $pattern->[1];



=head2 prep_queries

prep_queries() takes same arguments as Queries() (which actually uses prep_queries() internally).

Parse a list of query strings and return them as individual word/phrase tokens.
Removes stopwords and metanames from queries. Stemming is also supported, though it may
behave unpredictably in the resulting regexps from Queries().

	my @q = $hiliter->prep_queries( ['foo', 'bar', 'baz'] );

The reason we support multiple @query instead of $query is to allow for compounded searches.

Don't worry about I<not>s since those aren't going to be in the
results anyway. Just let the highlight fail.


=head2 Report

Return a summary of how many instances of each query were
found, how many highlighted, and how many missed.


=head1 FILTERS

TextFilter and TagFilter are two optional parameters that allow you to filter
the contents of your HTML beyond normal highlighting. Each parameter takes a CODE
reference.

TextFilter should expect these parameters in this order:

I<parserobj>, I<dtext>, I<text>, I<offset>, I<length>

TagFilter should expect these parameters in this order:

I<parserobj>, I<tag>, I<tagname>, I<offset>, I<length>, I<offset_end>, I<attr>, I<text>

Both should return a scalar string of text. TagFilter should return a set of attributes. TextFilter
may return whatever you want. See L<EXAMPLES> and the L<HTML::Parser> documentation 
for what these parameters mean and for more about writing filters.


=head1 EXAMPLES

See F<examples/> directory in source distribution.


=head1 HISTORY

Yet another highlighting module?

My goal was complete, exhaustive, tear-your-hair-out efforts to highlight HTML.
No other modules I found on the web supported nested tags within words and phrases,
or character entities. Cray uses the standard DocBook stylesheets from Norm Walsh et al,
to generate HTML. These stylesheets produce valid HTML but often fool the other
highlighters I found.

The problem became most evident when we started using SWISH-E. SWISH-E does such
a good job at converting entities and doing phrase matching that we found ourselves
in a dilemma: SWISH-E often gave valid search results that mere mortal highlighters
could not match in the source HTML -- not even the SWISH::*Highlight modules.

I assume ISO-8859-1 Latin1 encoding. Unicode is beyond me at this point,
though I suspect you could make it work fairly easily with 
newer Perl versions (>= 5.8) and the 'use locale' and 'use encoding' pragmas.
Thus regex matching would work with things like \w and [^\w] since perl
interprets the \w for you.

With the exception of the 'nohiliter' attribute,
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

=head2 Should you use this module?

I would suggest 
B<not> using HTML::HiLiter if your HTML is fairly simple, since in 
HTML::HiLiter, speed has been sacrificed for accuracy and rich features.
Check out L<HTML::Highlight> instead.

Unlike other highlighting code I've found, HTML::HiLiter supports nested tags and
character entities, such as might be found in technical documentation or HTML
generated from some other source (like DocBook SGML or XML). 

To speed up runtime, try using the Parser=>0 feature (though that doesn't support
all the features, like Links, TagFilter, TextFilter, smart context, etc.). Parser=>0
has the advantage of not requiring the HTML::Parser (and associated modules), but
it makes the highlighting rather 'blind'.

The goal is server-side highlighting that looks as if you used a felt-tip marker
on the HTML page. You shouldn't need to know what the underlying tags and entities and
encodings are: you just want to easily highlight some text B<as your browser presents it>.


=head1 TODO

=over

=item *

Better approach to stopwords in prep_queries().

=item *

Highlight IMG tags where ALT attribute matches query??

=back

=head1 KNOWN BUGS AND LIMITATIONS

Report() may be inaccurate when Links flag is on. Report() may be inaccurate
if the moon is full. Report() may just be inaccurate, plain and simple. Improvements
welcome.

Will not highlight literal parentheses ().

Phrases that contain stopwords may not highlight correctly. It's more a problem of *which*
stopword the original doc used and is not an intrinsic problem with the HiLiter, but
noted here for completeness' sake.

If using the SWISH param in new(), only the first index's Char* settings are considered.

Stemming support "works" but feels to the author like a crude hack. YMMV.

=head2 Locale

NOTE: locale settings will affect what [\w] will match in regular expressions.
Here's a little test program to determine how \w will work on your system.
By default, no locale is set in HTML::HiLiter, so \w should default to the
locale with which your perl was compiled.

This test program was copied verbatim from L<http://rf.net/~james/perli18n.html#Q3>

I find it very helpful.

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
  


=head1 AUTHOR

Peter Karman, karpet@peknet.com

Thanks to the Swish-edevelopers, in particular Bill Moseley for graciously
sharing time, advice and code examples.

Thanks to Cray for allowing this module to be publically released as part of
CrayDoc and allowing me to continue supporting it.

Comments and suggestions are welcome.


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


=head1 SEE ALSO

L<SWISH::HiLiter>, L<SWISH::API>, L<HTML::Parser>, L<HTML::Tagset>, L<HTML::Entities>,
L<Text::ParseWords>, L<LWP::UserAgent>, L<HTTP::Request>, L<Data::Dumper>


=cut
