use Test;
BEGIN { plan tests => 5; $| = 0 }

use strict; use warnings;

use Data::Verify qw(:all);
use Error qw(:try);
use IO::Extended qw(:all);

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

		my $bla = 'blalbl';
			
		verify( bless( \$bla, 'SomeThing' ) , REF );

		verify( bless( \$bla, 'SomeThing' ) , REF( qw(SomeThing) ) );

		verify( bless( \$bla, 'SomeThing' ) , REF( qw(SomeThing Else) ) );

		verify( [ 'bla' ] , REF( 'ARRAY' ) );

		verify( 'yes' , YESNO );

		verify( 'no' , YESNO );

		verify( "yes\n" , YESNO );

		verify( "no\n" , YESNO );

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
		my $bla = 'blalbl';

		verify( bless( \$bla, 'SomeThing' ) , REF( 'Never' ) );

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

Class::Maker::class 'Human',
{
	public =>
	{
		int => [qw(age)],

		string =>
		[
			qw(email countrycode postalcode firstname lastname sex eye_color),

			qw(hair_color occupation city region street fax)
		],

		time => [qw(birth dead)],

		array => [qw(nicknames friends)],

		hash => [qw(contacts telefon)],

		whatsit => { tricky => 'An::Object' },
	},
};
	
	my $guard_rules =
	{
		email		=> EMAIL, 
		firstname	=> WORD,
		lastname	=> WORD,
		sex			=> GENDER,
		countrycode => NUM,
		age			=> NUM,
		contacts	=> sub { my %args = @_; exists $args{lucy} },				
	};

	my $h = Human->new( email => 'j@d.de', firstname => 'john', lastname => 'doe', sex => 'male', countrycode => '123123', age => 12 );
	
	$h->contacts( { lucy => '110', john => '123' } );
	
	try
	{
		overify( $guard_rules, $h );
		
		ok(1);
	}
	catch Type::Exception with
	{
		ok(0);
	};

	try
	{	
		$h->firstname = undef;
			
		overify( $guard_rules, $h );

		ok(0);
	}
	catch Type::Exception with
	{
		ok(1);
	};

