# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test;
BEGIN { plan tests => 1 };

use Data::Verify qw(:all);
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test module is use()ed here so read
# its man page ( perldoc Test ) for help writing this test script.

use IO::Extended qw(:all);

use Data::Dumper;

my @pass =
(
	{ label => 'dummylabel', value => 'test@test.de', type => 'dummy' },

	{ label => 'not null', value => 'NOTNULL', type => 'not_null' },

	{ label => 'true expr', value => '1', type => 'true' },

	{ label => 'false expr', value => '', type => 'false' },

	{ label => 'fragivar', value => 'superkalifragilistic', type => 'word' },

	{ label => 'mylogin', value => 'muenalan', type => 'login' },

	{ label => 'myemail', value => 'murat@test.de', type => 'email' },

	{ label => 'mynumber', value => '1234', type => 'number' },

	{ label => 'myphone', value => '030-4152232', type => 'phone_ger' },
);

my @fail =
(
	{ label => 'is null', value => 'NULL', type => 'not_null' },

	{ label => 'true expr', value => '0', type => 'true' },

	{ label => 'false expr', value => '1', type => 'false' },

	{ label => 'emptyvar', value => '', type => 'name' },

	{ label => 'fakeemail', value => 'murat@testde', type => 'email' },
);

	my $result;

	foreach my $href_args ( @pass, @fail )
	{
		#print Dumper [ Data::Verify->new( %$href_args ) ], [ Data::Verify->new( label => 1, value => 'one', type => 'true' ) ];

		describe( Data::Verify->new( %$href_args ) );

		print "\n", $href_args->{label}, "...", assess( $result = verify( %$href_args ) ) ? 'ok' : 'not ok', "\n" x 4;

		#print Dumper $result;
	}
