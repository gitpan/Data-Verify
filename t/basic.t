use Test;
BEGIN { plan tests => 3 }

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

			# REF
			
		verify( bless( \${ 'bla' }, 'SomeThing' ) , REF );

		verify( bless( \${ 'bla' }, 'SomeThing' ) , REF( qw(SomeThing) ) );

		verify( bless( \${ 'bla' }, 'SomeThing' ) , REF( qw(SomeThing Else) ) );
		
		ok(1);
	}
	catch Type::Exception with
	{
		ok(0);
		
		use Data::Dumper;
		
		print Dumper shift;
	};

	try
	{			
		verify( bless( \${ 'bla' }, 'SomeThing' ) , REF( 'Never' ) );
		
		ok(0);
	}
	catch Type::Exception with
	{
		ok(1);
	};

	try
	{
		verify( 'bla' , REF );
		
		ok(0);
	}
	catch Type::Exception with
	{
		ok(1);
	};


