
# Author: Murat Uenalan (muenalan@cpan.org)
#
# Copyright (c) 2001 Murat Uenalan. All rights reserved.
#
# Note: This program is free software; you can redistribute
#
# it and/or modify it under the same terms as Perl itself.

require 5.005_62; use strict; use warnings;

our $VERSION = '0.01_01';

use Class::Maker;

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

package Data::Verify::Type;

Class::Maker::class
{
	attribute =>
	{
		string	=> [qw( id desc )],

		array	=> [qw( extends )],

		hash	=> [qw( pass fail )],
	},
};

our $true = new Data::Verify::Type( desc => 'a true value', pass => { bool => 1 } );

our $false = new Data::Verify::Type( desc => 'a false value', fail => { bool => 1 } );

our $not_null = new Data::Verify::Type( desc => 'not the string "NULL"', fail => { NULL => 1 } );

our $null = new Data::Verify::Type( desc => 'must be the string "NULL"', pass => { NULL => 1 } );

our $limited = new Data::Verify::Type( desc => 'a standard length word', fail => { less => 1 } );

our $text = new Data::Verify::Type( desc => 'a standard length word', pass => { range => [1,800] } );

our $word = new Data::Verify::Type( desc => 'a word', extends => [qw(limited)], pass => { match => qr/[a-zA-Z\-]+[0-9]*/ } );

our $name = new Data::Verify::Type( desc => 'a first- or lastnames', extends => [qw(limited)], pass => { match => qr/[^\s]+/ } );

our $login = new Data::Verify::Type( desc => 'a login- or nickname', extends => [qw(limited)], pass => { match => qr/[a-zA-Z\-]+[0-9]*/ } );

our $email = new Data::Verify::Type( desc => 'an email address', pass => { less => 45, match => qr/([^\@]*)\@(\w+)(\.\w+)+/ }, fail => { less => 5 } ); # qr/^([\w.-]+)\@([\w.-]\.)+\w+$/ }

our $number = new Data::Verify::Type( desc => 'a number or digit', extends => [qw(limited)], pass => { match => qr/[\d]+/ } );

our $number_notnull = new Data::Verify::Type( desc => 'a number or digit, but not 0', extends => [qw(number)], fail => { match => qr/^0+$/ } );

our $zip_ger = new Data::Verify::Type( desc => 'a german zip code', extends => [qw(number)], pass => { less => 7 }, fail => { less => 4 } );

our $phone_ger = new Data::Verify::Type( desc => 'a german phone number', pass => { less => 20, match => qr/[\d\-\+\)\(]+/ }, fail => { less => 3 } );

our $creditcard = new Data::Verify::Type( desc => 'a credit-card number', extends => [qw(limited)], pass => { creditcard => [ 'amex', 'mastercard', 'vextends' ]} );

package Data::Verify;

Class::Maker::class
{
	attribute =>
	{
		bool 	=> [qw( debug )],

		hash	=> [qw( tests types )],

		array	=>  [qw( results )],

		scalar => [qw( type value label )],
	},
};

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = ( 'all' => [ qw(verify assess) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = ();

my @err;

sub verify
{
	my $this = new Data::Verify( @_ );

		die unless $this->type;

			# reset error stack

		@err = ();

		my $result;

		my $type = load_type( $this->type ) || die sprintf 'Unknown Data::Verify::Type::%s - Perhaps a typo ?', $this->type;

		foreach ( keys %{ $type->pass } )
		{
			$result->{$this->type.'.'.$_} = ( load_test($_)->( $this->value, $type->pass->{$_} ) )+0;
		}

		foreach ( keys %{ $type->fail } )
		{
			$result->{$this->type.'.'.$_} = ( not load_test($_)->( $this->value, $type->fail->{$_} ) )+0;
		}

		foreach( @{ $type->extends } )
		{
			$this->type( $_ );

			$result = { %$result, %{ verify( %{ $this } ) } };
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

1;

__END__

=head1 NAME

Data::Verify - object oriented data verification, validation and testing

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

=head1 DESCRIPTION

A sceptic programmer never trusts somebody else his input (web forms, config files, etc.). He verifys if the data
is in the right format. With this module he can do it in a very elegant and efficient way. Using object oriented
techniques, you can create a hierarchy of tests for verifying almost everything.

The verification procedure is like a simple program. The building blocks are called tests.
Multiple tests result into a 'test program'. While some tests may be expected to fail, and some to pass
to result into a valid verification.
I call every data which passes the complete program as expected belonging to a 'data type' (So i use
this term instead of 'test program').

Here an example in pseudo-code:

	DATA_TYPE A (extends DATA_TYPE B)
	{
		PASS
		{
			TEST 5
			TEST 6
		}

		FAIL
		{
			TEST 1
			TEST 2
			TEST 3
			TEST 4
		}
	}

This means: Data is (belonging to) 'DATA TYPE' when it is passing test 5 and 6 with success, and is
failing tests 1,2,3 and 4. It also EXTENDS 'DATA_TYPE B', that means that "DATA_TYPE A" inherits all
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

=cut

=head2 assess( $verify_result )

Use 'assess' to process the result of 'verify' to a simple boolean value.

Example:

	assess( verify( value => 0, type => 'false' );	# would return true

=cut

=head2 EXPORT

:all = assess, verify

None by default.

=head1 AUTHOR

Murat Uenalan, muenalan@cpan.org

=head1 SEE ALSO

Regexp::Common, Data::FormValidator, HTML::FormValidator, CGI::FormMagick::Validator, CGI::Validate,
Email::Valid, Email::Valid::Loose, Embperl::Form::Validate, Email::Valid

=cut
