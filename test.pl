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

	catalog();

	#::println VARCHAR( 20 )->to_text;

	try
	{
			# VARCHAR

		verify( 'one two three', Type::Proxy::VARCHAR( 20 ), Function::Proxy::match( qw/one/ ) );

		verify( ' ' x 20 , VARCHAR( 20 ) );

			# NUM

		verify( '0' , NUM( 20 ) );

		verify( '234' , NUM( 20 ) );

			# BOOL

		verify( '1' , BOOL( 'true' ) );

			# INT

		verify( '100' , INT );

			# REAL

		verify( '1.1' , REAL );

			# QUOTED

		verify( '"me"' , QUOTED );

			# GENDER

		verify( 'male' , GENDER );

			# URI

		verify( 'http://www.perl.org' , URI );

		verify( 'http://www.cpan.org' , URI('http') );

		verify( 'https://www.cpan.org' , URI('https') );

		verify( 'ftp://www.cpan.org' , URI('ftp') );

		verify( 'axkit://www.axkit.org' , URI('axkit') );

		verify( '62.01.01.20' , IPV4 );

			# MYSQL types

		verify( '2001-01-01', MYSQL_DATE );

		verify( '9999-12-31 23:59:59', MYSQL_DATETIME );

		verify( '1970-01-01 00:00:00', MYSQL_TIMESTAMP );

		verify( '-838:59:59', MYSQL_TIME );

			# mysql_year: 1901 to 2155, 0000 in the 4-digit

		verify( '1901', MYSQL_YEAR );

		verify( '0000', MYSQL_YEAR );

		verify( '2155', MYSQL_YEAR );

			# mysql_year: 1970-2069 if you use the 2-digit format (70-69);

		verify( '70', MYSQL_YEAR(2) );

		verify( '69', MYSQL_YEAR(2) );

		verify( '0' x 20, MYSQL_TINYTEXT );

		verify( '0' x 20, MYSQL_TINYBLOB );

		verify( '0' x 20, MYSQL_TEXT );

		verify( '0' x 20, MYSQL_BLOB );

		verify( '0' x 20, MYSQL_MEDIUMTEXT );

		verify( '0' x 20, MYSQL_MEDIUMBLOB );

		verify( '0' x 20, MYSQL_LONGTEXT );

		verify( '0' x 20, MYSQL_LONGBLOB );

		verify( 'one', MYSQL_ENUM( qw(one two three) ) );

		verify( [qw(two six)], MYSQL_SET( qw(one two three four five six) ) );

			# EMAIL

		verify( 'muenalan@cpan.org' , EMAIL );

		verify( 'muenalan<at>cpan.org' , EMAIL );
	}
	catch Type::Exception with
	{
		my $e = shift;

		print "-" x 100, "\n";

		::printfln "Exception '%s' caught", ref $e;

		::printfln "Expected '%s' %s at %s line %s", $e->value, $e->type->info, $e->was_file, $e->was_line;
	};

	$Data::Verify::DEBUG = 0;

	::println "=" x 100;

	foreach my $type ( URI, EMAIL, IPV4, VARCHAR(80) )
	{
		::println "\n" x 2, "Describing ", $type->info;

		foreach my $entry ( Data::Verify::testplan( $type ) )
		{
			::printfln "\texpecting it %s %s ", $entry->[1] ? 'is' : 'is NOT', Data::Verify::strlimit( $entry->[0]->info() );
		}
	}

	##

	::println "-" x 100;

	::println "\nTesting Data::Verify::Typed\n";

	{
		typ EMAIL, \( my $email, my $email1 );

		my $cp = $email = 'murat.uenalan@gmx.de';

		$email = 'fakeemail%anywhere.de';	# Error

		$email = 'garbage anywhere.de';		# Error

		$email1 = 'test.de';		# Error

		untyp \$email;

		$cp = $email = 'garbage';
	}

	{
		typ URI, \( my $uri );

		$uri = 'http://test.de';

		$uri = 'xxx://test.de';	# Error
	}

	{
		typ VARCHAR(10), \( my $var );

		$var = join '', (0..9);

		$var = join '', (0..10); # Error
	}

	{
		typ IPV4, \( my $ip );

		$ip = '255.255.255.0';

		$ip = '127.0.0.1';

		$ip = '127.0.0.1.x'; # Error
	}

	{
		Class::Maker::class 'Watched',
		{
			public =>
			{
				ipaddr => [qw( addr )],
			}
		};

		my $watched = Watched->new();

		typ IPV4, \( $watched->addr );

		$watched->addr( 'XxXxX' ); # Error
	}

	sub MYSQL::SET  { MYSQL_SET( @_ ) }

	sub MYSQL::ENUM { MYSQL_ENUM( @_ ) }

	{
		typ MYSQL::ENUM( qw(Murat mo muri) ), \( my $alias );

		$alias = 'Murat';

		$alias = 'mo';

		$alias = 'muri';

		$alias = 'idiot'; # Error ;)
	}

	{
		typ MYSQL::SET( qw(Murat mo muri) ), \( my $alias );

		$alias = [ qw(Murat mo)];

		$alias = [ 'john' ]; # Error ;)
	}

