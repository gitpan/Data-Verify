use Test;
BEGIN { plan tests => 1 }

use Data::Verify qw(:all);
use Error qw(:try);

	try
	{
			# NUM

		verify( '0' , NUM( 20 ) );

		verify( '234' , NUM( 20 ) );

			# BOOL

		verify( '1' , BOOL( 'true' ) );

			# INT

		verify( '100' , INT );

			# REAL

		verify( '1.1' , REAL );

			# GENDER

		verify( 'male' , GENDER );
		
		ok(1);
	}
	catch Type::Exception with
	{
		ok(0);
	};


