use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'Data::Verify',
    'VERSION_FROM'	=> 'Verify.pm', # finds $VERSION
    'PREREQ_PM'		=>
    {


	Class::Maker => '0.05.10',

	Error => '0.15',

	IO::Extended => '0.05',

	Regexp::Common => '1.20',

	Email::Valid => '0.14',

	Tie::ListKeyedHash => '0.41',

	Business::CreditCard => '0.27',

	Iter => '0',


    },
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'Verify.pm', # retrieve abstract from module
       AUTHOR     => 'murat.uenalan@cpan.org') : ()),
);
