# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'
#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test;

BEGIN { plan tests => 1 };

use Data::Verify qw(:all);

use Error qw(:try);

use strict;

use warnings;

ok(1); # If we made it this far, we're ok.

#########################
# Insert your test code below, the Test module is use()ed here so read
# its man page ( perldoc Test ) for help writing this test script.

	$Data::Verify::DEBUG = 1;

	print toc();

	Data::Verify::println VARCHAR( 20 )->to_text;

	try
	{
		verify( 'one two three', Type::Proxy::VARCHAR( 20 ), Function::Proxy::match( qw/one/ ) );
	}
	catch Type::Exception with
	{
		my $e = shift;

		print "-" x 100, "\n";

		Data::Verify::printfln "Exception '%s' caught", ref $e;

		Data::Verify::printfln "Expected '%s' %s at %s line %s", $e->value, $e->type->info, $e->was_file, $e->was_line;
	};

	$Data::Verify::DEBUG = 0;

	Data::Verify::println "=" x 100;

	foreach my $type ( URI, EMAIL, IP( 'V4' ), VARCHAR(80) )
	{
		Data::Verify::println "\n" x 2, "Describing ", $type->info;

		foreach my $entry ( Data::Verify::testplan( $type ) )
		{
			Data::Verify::printfln "\texpecting it %s %s ", $entry->[1] ? 'is' : 'is NOT', Data::Verify::strlimit( $entry->[0]->info() );
		}
	}

	print "\n", CREDITCARD()->usage, "\n";
