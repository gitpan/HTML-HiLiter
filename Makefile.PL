use 5.006001;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'HTML::HiLiter',
    VERSION_FROM      => 'HiLiter.pm', # finds $VERSION
    PREREQ_PM         => { Test::Simple => 0.47, Text::ParseWords => 3.2 }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (
       AUTHOR         => 'Peter Karman <karman@cray.com>') : ()
	),
);
