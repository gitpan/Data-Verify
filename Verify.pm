# Author: Murat Uenalan (muenalan@cpan.org)
#
# Copyright (c) 2001 Murat Uenalan. All rights reserved.
#
# Note: This program is free software; you can redistribute
#
# it and/or modify it under the same terms as Perl itself.

require 5.005_62; use strict; use warnings;

use Class::Maker;

use Error qw(:try);

package Data::Verify::Exception;

our @ISA = qw(Error);

sub new
{
	my $class = shift;

	$class = ref( $class ) || $class;

    local $Error::Depth = $Error::Depth + 1;

	my %args = @_;

	my %super_args;

	foreach my $key ( qw(text package file line object) )
	{
		if( exists $args{$key} )
		{
			$super_args{'-'.$key} = $args{$key};

			delete $args{$key};
		}
	}

	my $this = $class->SUPER::new( %super_args );

	return $this;
}

package Data::Verify;

our $VERSION = '0.01_04';

Class::Maker::class
{
	public =>
	{
		bool 	=> [qw( debug )],

		hash	=> [qw( tests types )],

		array	=>  [qw( results )],

		string 	=> [qw( type label ) ],

		scalar => [qw(  value )],
	},
};

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [ qw(verify assess describe) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = ();

our @err;

sub verify
{
	my $this = new Data::Verify( @_ );

		die unless $this->type;

			# reset error stack

		@err = ();

		my $result = {};

		my $type = load_type( $this->type ) || die sprintf 'Unknown Data::Verify::Type::%s - Perhaps a typo ?', $this->type;

		if( $type->pass )
		{
			foreach ( keys %{ $type->pass } )
			{
				$result->{$this->type.'.'.$_} = ( load_test($_)->( $this->value, $type->pass->{$_} ) )+0;
			}
		}

		if( $type->fail )
		{
			foreach ( keys %{ $type->fail } )
			{
				$result->{$this->type.'.'.$_} = ( not load_test($_)->( $this->value, $type->fail->{$_} ) )+0;
			}
		}

		if( $type->extends )
		{
			foreach my $subtype ( @{ $type->extends } )
			{
				$this->type( $subtype->id );

				#print "Verify test ", $subtype->id, "\n";

				$result = { %$result, %{ verify( %{ $this } ) } };
			}
		}

return $result;
}

sub assess
{
return { reverse %{ $_[0] } }->{0} ? 0 : 1;
}

sub load_type
{
	no strict qw(refs);

return ${ 'Data::Verify::Type::'.$_[0] };
}

sub load_test
{
	no strict qw(refs);

return *{ 'Data::Verify::Test::'.$_[0] };
}

sub describe
{
	my $type = shift;

		my $obj = Data::Verify::load_type( $type->type );

		printf "'%s' (%s) must be '%s' ( has to be of type '%s' ), and is ok when it\n",$type->value, $type->label, $obj->desc, $type->type ;

		my $tests = $obj->all_tests;

		no strict 'refs';

		foreach my $pass_or_fail ( qw(pass fail) )
		{
			foreach my $subtype ( keys %{ $tests->{$pass_or_fail} } )
			{
				foreach my $test ( keys %{ $tests->{$pass_or_fail}->{$subtype} } )
				{
					my $english;

					$english = "Data::Verify::Test::Warnings::${test}"->( $tests->{$pass_or_fail}->{$subtype}->{$test} );

					printf " - %s %s (%s)\n", ($pass_or_fail) eq 'pass' ? 'is' : "isn't" , $english, $subtype;
				}
			}
		}
}

	##
	##
	##

package Data::Verify::Type;

Class::Maker::class
{
	public =>
	{
		string	=> [qw( id desc )],

		array	=> [qw( extends )],

		hash	=> [qw( pass fail )],
	},
};

sub all_tests
{
	my $this = shift;

		my $all;

		foreach my $subtype ( @{ $this->extends }, $this )
		{
			$all->{pass}->{$subtype->id} = $subtype->pass if keys %{ $subtype->pass };

			$all->{fail}->{$subtype->id} = $subtype->fail if keys %{ $subtype->fail };
		}

return $all;
}

our $true = 	new Data::Verify::Type( id => 'true', desc => 'a true value', pass => { bool => 1 } );

our $false = 	new Data::Verify::Type( id => 'false', desc => 'a false value', fail => { bool => 1 } );

our $not_null = new Data::Verify::Type( id => 'not_null', desc => 'not the string "NULL"', fail => { NULL => 1 } );

our $null = 	new Data::Verify::Type( id => 'null', desc => 'must be the string "NULL"', pass => { NULL => 1 } );

our $limited = 	new Data::Verify::Type( id => 'limited', desc => 'a standard length word', fail => { less => 1 } );

our $text = 	new Data::Verify::Type( id => 'text', desc => 'a standard length word', pass => { range => [1,800] } );

our $word = 	new Data::Verify::Type( id => 'word', desc => 'a word', extends => [ $limited ], pass => { match => qr/[a-zA-Z\-]+[0-9]*/ } );

our $name = 	new Data::Verify::Type( id => 'name', desc => 'a first- or lastnames', extends => [ $limited ], pass => { match => qr/[^\s]+/ } );

our $login = 	new Data::Verify::Type( id => 'login', desc => 'a login- or nickname', extends => [ $limited ], pass => { match => qr/[a-zA-Z\-]+[0-9]*/ } );

our $email = 	new Data::Verify::Type( id => 'email', desc => 'an email address', pass => { less => 45, match => qr/([^\@]*)\@(\w+)(\.\w+)+/ }, fail => { less => 5 } ); # qr/^([\w.-]+)\@([\w.-]\.)+\w+$/ }

our $number = 	new Data::Verify::Type( id => 'number', desc => 'a number or digit', extends => [ $limited ], pass => { match => qr/[\d]+/ } );

our $number_notnull = new Data::Verify::Type( id => 'number_notnull', desc => 'a number or digit, but not 0', extends => [ $number ], fail => { match => qr/^0+$/ } );

our $zip_ger = 	new Data::Verify::Type( id => 'zip_ger', desc => 'a german zip code', extends => [ $number ], pass => { less => 7 }, fail => { less => 4 } );

our $phone_ger = new Data::Verify::Type( id => 'phone_ger', desc => 'a german phone number', pass => { less => 20, match => qr/[\d\-\+\)\(]+/ }, fail => { less => 3 } );

our $creditcard = new Data::Verify::Type( id => 'creditcard', desc => 'a credit-card number', extends => [ $limited ], pass => { creditcard => [ 'amex', 'mastercard', 'vextends' ] } );

our $dummy = 	new Data::Verify::Type( id => 'dummy', desc => 'a dummy comlex', extends => [ $text, $word, $email ] );

	##
	##
	##

package Data::Verify::Test;

sub range	{ return 0 unless defined($_[0]); return ( length($_[0]) >= $_[1]->[0] && length($_[0]) <= $_[1]->[1]) ? 1 : 0 ; }

sub lines	{ return 0 unless defined($_[0]); return ($_[0] =~ s/(\n)//g) > $_[1]; }

sub less	{ return 0 unless defined($_[0]); return length($_[0]) < $_[1]; }

sub match	{ return 0 unless defined($_[0]); return ($_[0] =~ $_[1]) ? 1 : 0; }

sub is		{ return $_[0] }

sub bool    { return $_[0] ? 1 : 0 }

sub NULL    { return uc( $_[0] ) eq 'NULL' ? 1 : 0 }

sub exists_in
{
	if( ref( $_[1] ) eq 'ARRAY' )
	{
		my %hash;

		@hash{ @{ $_[1] } } = 1;

		$_[1] = \%hash;
	}

return ( exists $_[1]->{$_[0]} ) ? 1 : 0;
}

package Data::Verify::Test::Warnings;

sub range	{ return sprintf 'between %s - %s', $_[0]->[0], $_[0]->[1] }

sub lines	{ return sprintf '%d lines', $_[0] }

sub less 	{ return sprintf 'less than %d chars long', $_[0] }

sub match	{ return sprintf 'matching the regular expression /%s/', $_[0] }

sub is		{ return sprintf 'exact %s', $_[0] }

sub bool	{ return sprintf 'boolean %s', $_[0] ? 'true' : 'false' }

sub NULL	{ return 'exactly NULL' }

sub exists_in { return sprintf 'expected in a %s', ref( $_[0] ) }

	##
	##	Object Bouncer
	##

package Bouncer::Test;

	Class::Maker::class
	{
		public =>
		{
			string => [qw( field type )],
		},
	};

package Bouncer;

	Class::Maker::class
	{
		public =>
		{
			array => { tests => 'Bouncer::Test' },
		},
	};

sub inspect : method
{
	my $this = shift;

	my $client = shift or return undef;

		no strict 'refs';

		foreach my $test ( $this->tests )
		{
			my $met = $test->field;

			die "'$met' is not a known field of ".ref($client) unless $client->can( $met );

			unless( Data::Verify::assess( Data::Verify::verify( label => $met, value => $client->$met(), type => $test->type ) ) )
			{
				$@ .= " $met";

				return 0;
			}
		}

return 1;
}

1;

__END__

=head1 NAME

Data::Verify - versatile data/type verification, validation and testing

=head1 SYNOPSIS

	use Data::Verify qw(assess verify);

	{
		package Data::Verify::Type;

		our $digit_not_0 = Data::Verify::Type->new(

			desc => 'a number or digit, but not 0',

			extends => [qw(limited)],

			pass => { match => qr/[\d]+/ },

			fail => { match => qr/^0+$/ }

		);

		our $german_zip = Data::Verify::Type->new(

			desc => 'a german zip code',

			extends => [qw(number)],

			pass => { less => 7 },

			fail => { less => 4 }
		);
	}

	verify( label => 'my personal digit', value => '12', type => 'digit_not_0' );

	verify( label => 'an foreign zip', value => '999-233', type => 'german_zip' );

	$bouncer->inspect( $user );

=head1 DESCRIPTION

A sceptic programmer never trusts anybodys input (web forms, config files, etc.). He verifys if the data
is in the right format. With this module he can do it in a very elegant and efficient way. Using object oriented
techniques, you can create a hierarchy of tests for verifying almost everything.

The verification procedure is like a simple program. The building blocks are called tests (While this has little
to do with modules like Test::Simple, the term 'test' is used because it behaves like it ).
Multiple tests result into a 'test program'. While some tests may be expected to fail, and some to pass
to result into a valid verification.
I call every data which passes the complete program as expected belonging to a 'data type' (So i use
this term instead of 'test program').

Here an example in pseudo-code for two data-types:

	DATA_TYPE_B
	{
		PASS
		{
			TEST_1
			TEST_2
		}
	}

	DATA_TYPE_A (extends DATA_TYPE_B)
	{
		PASS
		{
			TEST_5
			TEST_6
		}

		FAIL
		{
			TEST_1
			TEST_2
			TEST_3
			TEST_4
		}
	}

This means: Data is (belonging to) 'DATA_TYPE_A' when it is passing test 5 and 6 with success, and is
failing tests 1,2,3 and 4. It also EXTENDS 'DATA_TYPE_B', that means that "DATA_TYPE_A" inherits all
"DATA_TYPE A" PASS+FAIL tests.

=head1 TESTS

Tests are simply subroutines in the Data::Verify::Test package. Per definition a test receives: 1) the test
value 2) the test arguments. Then it simply returns true or false.

Here a very simple example:

	sub my_test { $_[0] > $_[1] }	# my_test( 12300, 100 ) would test if 12300 is bigger than 100

=head1 PREDEFINED TESTS

Following tests are always instantly available.

	range 	- takes two arguments where the value has to be inbetween (ie. range => [1,800] )

	lines 	- counts the lines (\n) (ie. lines => 5 )

	less 	- lesser than the length in characters (ie. less => 3)

	match 	- takes a regex to match (ie. match => qr/^0+$/ )

	is 		- exact string comparision (ie. is => 'follow' )

	bool 	- transformation of the value into bool (ie. bool => undef)

	NULL 	- exact string match 'NULL' (ie. NULL => 1)

	exists_in - checks whether the <var> is in a list. if list is an

		Array:	look if exact string is a member

		Hash:	look if the <var> key exists

		Example:

			pass => { exists_in => { firstname => 1, lastname => 1, email => 1 } },

			fail => { exists_in => [qw(blabla)] }
=cut

=head1 DATA TYPES

A data can be simply instanciated by creation of a new Data::Verify::Type object.

Example (how to create a new data type):

	package Data::Verify::Type;

		our $number_notnull = new Data::Verify::Type(

			desc => 'a number or digit, but not 0',

			extends => [qw(number)],

			fail => { match => qr/^0+$/ }
		);

	Normally we should have added 'pass => { match => qr/\d+/ },', but we dont explicitly need to add it
	because we inherit that from 'number'. Note: A regex-guru would have written simply a better regex which
	would had done it with just one match, but this example is for education purposes.

=head1 PREDEFINED DATA TYPES

Following types are always instantly available.

      true 		- a boolean true value

      false		- a boolean false value

      not_null	- not the string "NULL"

      null		- must be the string "NULL"

      limited	- a word longer than 1 character

      text		- a standard length text ( 1-800 characters )

      word		- a word ( match => qr/[a-zA-Z\-]+[0-9]*/ } )

      name		- a first- or lastnames

      login     - a login- or nickname

      email		- an email address

      number	- a number or digit

      number_notnull 	- a number or digit, but not 0

      zip_ger	- a german zip code

      phone_ger - a german phone number

      creditcard	- a credit-card number (not implemented yet)

=head1 FUNCTIONS

=head2 verify( $teststring, $data_type )

Verifies a 'value' against a 'type'.

Example:

	my $verify_result = verify( label => 'Config.Author.Level', value => 'NULL', type => 'not_null' );

	assess( $verify_result ) # this would fail

Because verify returns a hashref containing information about the test result, you must use 'assess' (below) to
transform it to a simple boolean value.

=head2 assess( $verify_result )

Use 'assess' to process the result of 'verify' to a simple boolean value.

Example:

	assess( verify( value => 0, type => 'false' );	# would return true

=head2 describe( Data::Verify )

Prints out an english text, describing how the format has to be and how it is tested.

=head1 Bouncer Interface

Observes/Inspects other objects if they fullfil a list of tests.

A bouncer in front of a disco makes decisions. He inspects other persons if they meet
the criteria/expectations to be accepted to enter the party or not. The criteria are instructed by
the boss. This is also how "Bouncer" works: it inspects other objects and rejects/accepts them.

Shortly i call it 'object bouncing'.

=head2 EXAMPLE

use Data::Verify;

	my $user = new User( email => 'hiho@test.de', registered => 1 );

	my $user_bouncer = Bouncer->new(

		tests =>
		[
			Bouncer::Test->new( field => 'email', type => 'email' ),

			Bouncer::Test->new( field => 'registered', type => 'not_null' ),

			Bouncer::Test->new( field => 'firstname', type => 'word' ),

			Bouncer::Test->new( field => 'lastname', type => 'word' )
		]
	);

	if( $user_bouncer->inspect( $user ) )
	{
		print "User is ok";
	}
	else
	{
		print "rejects User because of unsufficient field:", $@;
	}

=head2 EXPORT

:all = assess, verify, describe

None by default.

=head1 AUTHOR

Murat Uenalan, muenalan@cpan.org

=head1 SEE ALSO

Regexp::Common, Data::FormValidator, HTML::FormValidator, CGI::FormMagick::Validator, CGI::Validate,
Email::Valid, Email::Valid::Loose, Embperl::Form::Validate

=cut
