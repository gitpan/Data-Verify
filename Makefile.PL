use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'Data::Verify',
    'VERSION_FROM'	=> 'Verify.pm', # finds $VERSION
    'PREREQ_PM'		=>
    {
    	Class::Maker => 0,

    	Error		=> 0.15,

    }, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'Verify.pm', # retrieve abstract from module
       AUTHOR     => 'muenalan@cpan.org') : ()),
);
