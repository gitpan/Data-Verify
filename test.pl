# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test;
BEGIN { plan tests => 1 };
use Data::Verify qw(verify assess);
ok(1); # If we made it this far, we're ok.

#########################

# Insert your test code below, the Test module is use()ed here so read
# its man page ( perldoc Test ) for help writing this test script.

use Data::Dumper;

my @pass =
(
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

	foreach ( @pass, @fail )
	{
		print $_->{label}, " ", assess( $result = verify( %$_ ) ), "\n";

		print Dumper $result;
	}
