use Test;
BEGIN { plan tests => 1 }

use Data::Verify qw(:all);
use Error qw(:try);

	try
	{
			# VARCHAR

		verify( 'one two three', Type::Proxy::VARCHAR( 20 ), Function::Proxy::match( qw/one/ ) );

		verify( ' ' x 20 , VARCHAR( 20 ) );

			# BOOL

		verify( '1' , BOOL( 'true' ) );

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
		
		ok(1);
	}
	catch Type::Exception with
	{
		ok(0);
	};

