use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'Data::Verify',
    'VERSION_FROM'	=> 'Verify.pm', # finds $VERSION
    'PREREQ_PM'		=>
    {
    	Class::Maker 		=> 0.05_10,

    	Error				=> 0.15,

    	IO::Extended		=> 0.05,

    	Regexp::Common		=> 0.09,
    },
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'Verify.pm', # retrieve abstract from module
       AUTHOR     => 'muenalan@cpan.org') : ()),
);
