# Author: Murat Uenalan (muenalan@cpan.org)
#
# Copyright (c) 2002 Murat Uenalan. All rights reserved.
#
# Note: This program is free software; you can redistribute
#
# it and/or modify it under the same terms as Perl itself.

require 5.005_62; use strict; use warnings;

use Class::Maker;

use IO::Extended qw(:all);

use Error qw(:try);

package Type::Exception;

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

		return $class->SUPER::new( %super_args );
	}

package Failure::Type;

	Class::Maker::class
	{
		isa => [qw(Type::Exception)],

		public =>
	    {
	    	bool => [qw( expected returned )],

			string => [qw( was_file )],

	    	int => [qw( was_line )],

	    	ref => [qw( type value )],
	    },
	};

package Failure::Function;

	Class::Maker::class
	{
		isa => [qw(Type::Exception)],

		public =>
	    {
	    	bool => [qw( expected returned )],

	    	ref => [qw( type )],
	    },
	};

package Data::Verify;

	our @types = type_list();

		# generate Type subs

	codegen();

	use Exporter;

	our @ISA = qw( Exporter );

	our %EXPORT_TAGS = ( 'all' => [ qw(typ untyp verify catalog testplan), map { uc } @types ] );

	our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

	our @EXPORT = ();

	our $VERSION = '0.01_08';

	our $DEBUG = 0;

	our @_history;

	no strict 'refs';

	sub strlimit
	{
		my $limit = $_[1] || 60;

		return length( $_[0] ) > $limit ? join('', (split(//, $_[0]))[0..$limit-1]).'..' : $_[0];
	}

	sub info
	{
		my $that = shift;

		my $value = shift;

		$value = '' unless defined( $value );

		::printfln "\n\nVerify '%s' against '%s' (%s)", $value, ref $that, strlimit( $that->info ) if $DEBUG;
	}

	sub expect
	{
		my $expected = shift;

		foreach my $that ( @_ )
		{
			::try
			{
				$that->test( $Type::value );

				#info( $that ) if $DEBUG;
			}
			catch Failure::Function ::with
			{
				my @back = caller(7);

				throw Failure::Type( value => $Type::value, type => $that, was_file => $back[1], was_line => $back[2] ) if $expected;
			};
		}
	}

	sub recording_expect
	{
		my $expected = shift;

		foreach my $that ( @_ )
		{
			push @Data::Verify::_history, [ $that, $expected ];
		}
	}

	our $current_expect = 'expect';

	sub pass
	{
		$current_expect->( 1, @_ );
	}

	sub fail
	{
		$current_expect->( 0, @_ );
	}

	sub assert
	{
		::println $_[0] ? '..ok' : '..failed';
	}

		# Tests Types

	sub verify
	{
		my $value = shift;

		foreach my $that ( @_ )
		{
			$Type::value = undef;

			info( $that, $value ) if $DEBUG;

			$that->test( $value );
		}
	}

	sub testplan
	{
		@Data::Verify::_history = ();

		$Data::Verify::current_expect = 'recording_expect';

		foreach my $that ( @_ )
		{
			$Type::value = undef;

			$that->test( '' );
		}

		$Data::Verify::current_expect = 'expect';

		return @Data::Verify::_history;
	}

	sub type_list
	{
		my @types = Data::Verify::_search_pkg( 'Type::' );

		my @result;

		foreach my $key ( @types )
		{
			( my $name ) = ( $key =~ /::(.+)::$/ );

			push @result, $name if $name =~ /^[a-z]/;
		}

		return @result;
	}

	sub catalog
	{
		my @types = type_list();

		::printfln "\n".__PACKAGE__." currently supports %d types:\n", scalar @types;

		foreach my $name ( @types )
		{
			::printfln "  %-18s - %s", uc $name, strlimit( ( bless [], "Type::${name}" )->info(  ) );
		}
	}

	sub typ
	{
		my $type = shift;

		foreach my $xref ( @_ )
		{
			ref($xref) or die sprintf "typ: %s reference detected, instead of a reference.", lc ref($xref) || 'no';

			$type->isa( 'Type::UNIVERSAL' ) or die sprintf "typed( ref, TYPE ) expects a TYPE as second arguemnt. You supplied '%s' which is not.", $type;

			tie $$xref, 'Data::Verify::Typed', $type;
		}
	}

	sub untyp
	{
		untie $$_ for @_;
	}

	use subs qw(typ untyp);

	sub _search_pkg
	{
		my $path = '';

		#s::println "_search_pkg scan $path";

		my @found;

		no strict 'refs';

		foreach my $pkg ( @_ )
		{
			#::println "_search_pkg ARG $pkg";

			next unless $pkg =~ /::$/;

			$path .= $pkg;

			#::println "PGK scan $path";

			if( $path =~ /(.*)::$/ )
			{
				foreach my $symbol ( sort keys %{$path} )
				{
					if( $symbol =~ /::$/ && $symbol ne 'main::' )
					{
						#::println "PGK $path";

						push @found, "${path}${symbol}";
					}
				}
			}
		}

	return @found;
	}

			# Generate Type alias subs
			#
			# - Generate subs like 'VARCHAR' into this package
			# - These are then Exported
			#
			# Note that codegen is called above

	sub codegen
	{
		foreach my $type ( Data::Verify::type_list() )
		{
			#::println $type;

			::println sprintf "sub %s { Type::Proxy::%s( \@_ ); };", uc $type, uc $type if $DEBUG;

			eval sprintf "sub %s { Type::Proxy::%s( \@_ ); };", uc $type, uc $type;

			warn $@ if $@;
		}

		::println sprintf "use subs qw(%s);", uc( join ' ', Data::Verify::type_list() ) if $DEBUG;

		eval sprintf "use subs qw(%s);", uc( join ' ', Data::Verify::type_list() );

		warn $@ if $@;
	}

package Type::Proxy;

	use vars qw($AUTOLOAD);

	sub AUTOLOAD
	{
		( my $func = $AUTOLOAD ) =~ s/.*:://;

	return bless [ @_ ], sprintf "Type::%s", lc $func;
	}

package Regex;

		use Regexp::Common;

	sub exact
	{
		return '^'.$_[0].'$';
	}

package Type;

		# This value is important. It gets reset to undef in verify() before the test starts. During test
		# it hold the $value of the data to tested against.

	our $value;

package Type::UNIVERSAL;

	sub to_text
	{
		my $this = shift;

		return "to_text() on $this called.";
	}

package Type::varchar;

	our @ISA = qw(Type::UNIVERSAL);

	sub info
	{
		my $this = shift;

		return sprintf 'a string with limited length of %s', $this->[0] || 'choice (default 60)';
	}

	sub test
	{
		my $this = shift;

		$Type::value = length( shift );

			Data::Verify::pass( Function::Proxy::range( 0, $this->[0] || 60 ) );
	}

package Type::word;

	our @ISA = qw(Type::UNIVERSAL);

	sub info
	{
		my $this = shift;

		return 'a word (without spaces)';
	}

	sub test
	{
		my $this = shift;

		$Type::value = shift;

			Data::Verify::pass( Function::Proxy::match( qr/[^\s]+/ ) );
	}

package Type::bool;

	our @ISA = qw(Type::UNIVERSAL);

	sub info
	{
		my $this = shift;

		return sprintf 'a %s boolean value', $this->[0] || 'true or false';
	}

	sub test
	{
		my $this = shift;

		$Type::value = shift;

			if( $this->[0] eq 'true' )
			{
				Data::Verify::pass( Function::Proxy::bool( $this->[0] ) );
			}
			else
			{
				Data::Verify::fail( Function::Proxy::bool( $this->[0] ) );
			}
	}

package Type::int;

	our @ISA = qw(Type::UNIVERSAL);

	sub info
	{
		my $this = shift;

		return 'an integer';
	}

	sub test
	{
		my $this = shift;

		$Type::value = shift;

			Data::Verify::pass( Function::Proxy::match( Regex::exact( $Regex::RE{num}{int} ) ) );
	}

package Type::num;

	our @ISA = qw(Type::UNIVERSAL);

	sub info
	{
		my $this = shift;

		return 'a number';
	}

	sub test
	{
		my $this = shift;

		$Type::value = shift;

				# Here we test the hierarchy feature -> nested types !

			Type::int->test( $value );
	}

package Type::real;

	our @ISA = qw(Type::UNIVERSAL);

	sub info
	{
		my $this = shift;

		return 'a real';
	}

	sub test
	{
		my $this = shift;

		$Type::value = shift;

			Data::Verify::pass( Function::Proxy::match( Regex::exact( $Regex::RE{num}{real} ) ) );
	}

package Type::email;

	our @ISA = qw(Type::UNIVERSAL);

	sub info
	{
		my $this = shift;

		return 'an email address';
	}

	sub test
	{
		my $this = shift;

		$Type::value = shift;

			Data::Verify::pass( Function::Proxy::email( $this->[0] ) );

			#Data::Verify::pass( Function::Proxy::match( qr/(?:[^\@]*)\@(?:\w+)(?:\.\w+)+/ ) );
	}

package Type::uri;

	our @ISA = qw(Type::UNIVERSAL);

	sub info
	{
		my $this = shift;

		my $scheme = $this->[0] || 'http';

		return sprintf 'an %s uri', $scheme;
	}

	sub test
	{
		my $this = shift;

		$Type::value = shift;

			my $scheme = $this->[0] || 'http';

			Data::Verify::pass( Function::Proxy::match( Regex::exact( $Regex::RE{URI}{HTTP}{'-scheme='.$scheme} ) ) );
	}

package Type::ipv4;

	our @ISA = qw(Type::UNIVERSAL);

	sub info
	{
		my $this = shift;

		return 'an IPv4 network address';
	}

	sub test
	{
		my $this = shift;

		$Type::value = shift;

			Data::Verify::pass( Function::Proxy::match( Regex::exact( $Regex::RE{net}{IPv4} ) ) );
	}

package Type::quoted;

	our @ISA = qw(Type::UNIVERSAL);

	sub info
	{
		my $this = shift;

		return 'a quoted string';
	}

	sub test
	{
		my $this = shift;

		$Type::value = shift;

			Data::Verify::pass( Function::Proxy::match( Regex::exact( $Regex::RE{quoted} ) ) );
	}

package Type::gender;

	our @ISA = qw(Type::UNIVERSAL);

	sub info
	{
		my $this = shift;

		return 'a gender (male|female)';
	}

	sub test
	{
		my $this = shift;

		$Type::value = shift;

			Data::Verify::pass( Function::Proxy::exists( [qw(male female)] ) );
	}

package Type::mysql_date;

	our @ISA = qw(Type::UNIVERSAL);

	sub info
	{
		my $this = shift;

			#The supported range is '1000-01-01' to '9999-12-31' (mysql)

		return "a date";
	}

	sub test
	{
		my $this = shift;

		$Type::value = shift;

			Data::Verify::pass( Function::Proxy::match( Regex::exact( qr/\d{4}-[01]\d-[0-3]\d/ ) ) );
	}

package Type::mysql_datetime;

	our @ISA = qw(Type::UNIVERSAL);

	sub info
	{
		my $this = shift;

			 #The supported range is '1000-01-01 00:00:00' to '9999-12-31 23:59:59' (mysql)

		return "a date and time combination";
	}

	sub test
	{
		my $this = shift;

		$Type::value = shift;

			Data::Verify::pass( Function::Proxy::match( Regex::exact( qr/\d{4}-[01]\d-[0-3]\d [0-2]\d:[0-6]\d:[0-6]\d/ ) ) );
	}

package Type::mysql_timestamp;

	our @ISA = qw(Type::UNIVERSAL);

	sub info
	{
		my $this = shift;

			#The range is '1970-01-01 00:00:00' to sometime in the year 2037 (mysql)

		return "a timestamp";
	}

	sub test
	{
		my $this = shift;

		$Type::value = shift;

			Data::Verify::pass( Function::Proxy::match( Regex::exact( qr/[1-2][9|0][7-9,0-3][0-7]-[01]\d-[0-3]\d [0-2]\d:[0-6]\d:[0-6]\d/ ) ) );
	}

package Type::mysql_time;

	our @ISA = qw(Type::UNIVERSAL);

	sub info
	{
		my $this = shift;

			#The range is '-838:59:59' to '838:59:59' (mysql)

		return "a time";
	}

	sub test
	{
		my $this = shift;

		$Type::value = shift;

			Data::Verify::pass( Function::Proxy::match( Regex::exact( qr/-?\d{3,3}:[0-6]\d:[0-6]\d/ ) ) );
	}

package Type::mysql_year;

	our @ISA = qw(Type::UNIVERSAL);

	sub info
	{
		my $this = shift;

			#The allowable values are 1901 to 2155, 0000 in the 4-digit year format, and 1970-2069 if you use the 2-digit format (70-69) (default is 4-digit)

		return "a year in 2- or 4-digit format";
	}

	sub test
	{
		my $this = shift;

		$Type::value = shift;

			my $yformat = $this->[0] || 4;

			if( $yformat == 2 )
			{
					#1970-2069 if you use the 2-digit format (70-69);

				Data::Verify::pass( Function::Proxy::match( Regex::exact( qr/\d{2,2}/ ) ) );
			}
			else
			{
					#The allowable values are 1901 to 2155, 0000 in the 4-digit

				Data::Verify::pass( Function::Proxy::match( Regex::exact( qr/[0-2][9,0,1]\d\d/ ) ) );
			}
	}

package Type::mysql_tinytext;

	our @ISA = qw(Type::UNIVERSAL);

	sub info
	{
		my $this = shift;

		return "a 'blob' or 'text' with a max length of 255 (2^8 - 1) characters (mysql)";
	}

	sub test
	{
		my $this = shift;

		$Type::value = length( shift );

			Data::Verify::pass( Function::Proxy::max( 255 ) );
	}

package Type::mysql_tinyblob;

	our @ISA = qw(Type::mysql_tinytext);


package Type::mysql_text;

	our @ISA = qw(Type::UNIVERSAL);

	sub info
	{
		my $this = shift;

		return "a 'blob' or 'text' with a max length of 65535 (2^16 - 1) characters (mysql)";
	}

	sub test
	{
		my $this = shift;

		$Type::value = length( shift );

			Data::Verify::pass( Function::Proxy::max( 65535 ) );
	}

package Type::mysql_blob;

	our @ISA = qw(Type::mysql_text);

package Type::mysql_mediumtext;

	our @ISA = qw(Type::UNIVERSAL);

	sub info
	{
		my $this = shift;

		return "a 'blob' or 'text' with a max length of 16777215 (2^24 - 1) characters (mysql)";
	}

	sub test
	{
		my $this = shift;

		$Type::value = length( shift );

			Data::Verify::pass( Function::Proxy::max( 16777215 ) );
	}

package Type::mysql_mediumblob;

	our @ISA = qw(Type::mysql_mediumtext);

package Type::mysql_longtext;

	our @ISA = qw(Type::UNIVERSAL);

	sub info
	{
		my $this = shift;

		return "a 'blob' or 'text' with a max length of 4294967295 (2^32 - 1) characters (mysql)";
	}

	sub test
	{
		my $this = shift;

		$Type::value = length( shift );

			Data::Verify::pass( Function::Proxy::max( 4294967295 ) );
	}

package Type::mysql_longblob;

	our @ISA = qw(Type::mysql_longtext);

package Type::mysql_enum;

	our @ISA = qw(Type::UNIVERSAL);

	sub info
	{
		my $this = shift;

			#A string object that can have only one value, chosen from the list of values 'value1', 'value2', ..., NULL or the special "" error value. An ENUM can have a maximum of 65535 distinct values (mysql)

		return qq{a member of an enumeration};
	}

	sub test
	{
		my $this = shift;

		$Type::value = shift;

			throw Failure::Function() if @$this > 65535;

			Data::Verify::pass( Function::Proxy::exists( [ @$this ] ) );
	}

package Type::mysql_set;

	our @ISA = qw(Type::UNIVERSAL);

	sub info
	{
		my $this = shift;

			# A string object that can have zero or more values, each of which must be chosen from the list of values 'value1', 'value2', ... A SET can have a maximum of 64 members. (mysql)

		return qq{a set};
	}

	sub test
	{
		my $this = shift;

		$Type::value = shift;

			throw Failure::Function() if @$Type::value > 64;

			throw Failure::Function() if @$this > 65535;

			Data::Verify::pass( Function::Proxy::exists( [ @$this ] ) );
	}

	#
	# Functions here
	#

package Function::Proxy;

	use vars qw($AUTOLOAD);

	sub AUTOLOAD
	{
		( my $func = $AUTOLOAD ) =~ s/.*:://;

	return bless [ @_ ], sprintf 'Function::%s', $func;
	}

package Function::email;

	use Email::Valid;

	sub test : method
	{
		my $this = shift;

		my $val = shift;

		my $mxcheck = shift || 0;

		throw Failure::Function() unless Email::Valid->address( -address => $val, -mxcheck => $mxcheck );
	}

	sub info : method
	{
		my $this = shift;

		my $mxcheck = shift || 0;

		return sprintf "a valid email address (%s mxcheck)", $mxcheck ? 'with' : 'without';
	}

package Function::range;

	sub test : method
	{
		my $this = shift;

		my $val = shift;

		throw Failure::Function() unless defined( $val );

		throw Failure::Function() unless $val >= $this->[0] && $val <= $this->[1];
	}

	sub info : method
	{
		my $this = shift;

		return sprintf 'between %s - %s', $this->[0], $this->[1];
	}

package Function::lines;

	sub test : method
	{
		my $this = shift;

		my $val = shift;

		throw Failure::Function() unless defined($val);

		throw Failure::Function() unless ($val =~ s/(\n)//g) > $this->[0];
	}

	sub info : method
	{
		my $this = shift;

		return sprintf '%d lines', $this->[0];
	}

package Function::less;

	sub test : method
	{
		my $this = shift;

		my $val = shift;

		throw Failure::Function() unless defined($val);

		throw Failure::Function() unless length($val) < $this->[0];
	}

	sub info : method
	{
		my $this = shift;

		return sprintf 'less than %d chars long', $this->[0];
	}

package Function::max;

	sub test : method
	{
		my $this = shift;

		my $val = shift;

		throw Failure::Function() unless defined($val);

		throw Failure::Function() if $val > $this->[0];
	}

	sub info : method
	{
		my $this = shift;

		return sprintf 'maximum of %d', $this->[0];
	}

package Function::min;

	sub test : method
	{
		my $this = shift;

		my $val = shift;

		throw Failure::Function() unless defined($val);

		throw Failure::Function() if $val < $this->[0];
	}

	sub info : method
	{
		my $this = shift;

		return sprintf 'minimum of %d', $this->[0];
	}

package Function::match;

	sub test : method
	{
		my $this = shift;

		my $val = shift;

		throw Failure::Function() unless defined($val);

		throw Failure::Function() unless $val =~ $this->[0];
	}

	sub info : method
	{
		my $this = shift;

		return sprintf 'matching the regular expression /%s/', $this->[0];
	}

package Function::is;

	sub test : method
	{
		my $this = shift;

		throw Failure::Function() unless $this->[0];
	}

	sub info : method
	{
		my $this = shift;

		return sprintf 'exact %s', $this->[0];
	}

package Function::bool;

	sub test : method
	{
		my $this = shift;

		throw Failure::Function() unless $this->[0];
	}

	sub info : method
	{
		my $this = shift;

		return sprintf "boolean '%s' value", $this->[0] ? 'true' : 'false';
	}

package Function::null;

	sub test : method
	{
		my $this = shift;

		my $val = shift;

		throw Failure::Function() unless uc( $val ) eq 'NULL';
	}

	sub info : method
	{
		my $this = shift;

		return "exactly 'NULL'";
	}

package Function::exists;

	sub test : method
	{
		my $this = shift;

		my $val = shift;

			if( ref( $val ) eq 'ARRAY' )
			{
				$this->test( $_ ) for @$val;

				return;
			}

			if( ref( $this->[0] ) eq 'ARRAY' )
			{
				my %hash;

				@hash{ @{ $this->[0] } } = 1;

				$this->[0] = \%hash;
			}

		throw Failure::Function() unless exists $this->[0]->{$val};
	}

	sub info : method
	{
		my $this = shift;

		if( ref( $this->[0] ) eq 'HASH' )
		{
			return sprintf 'element of hash keys (%s)', join( ', ', keys %{ $this->[0] } );
		}

		return sprintf 'element of array (%s)', join(  ', ', @{$this->[0]} );
	}

package Data::Verify::Typed;

	use strict;

	require Tie::Scalar;

	our @ISA = qw(Tie::StdScalar);

	our $DEBUG = 0;

	sub TIESCALAR
	{
		ref( $_[1] ) || die;

		$_[1]->isa( 'Type::UNIVERSAL' ) || die;

		::printfln "TIESC '%s'", ref( $_[1] ) if $DEBUG;

	    return bless [ undef, $_[1] ], $_[0];
	}

	sub STORE
	{
		my $this = shift;

		my $value = shift || undef;

		::printfln "STORE '%s' into %s typed against '%s'", $value, $this, ref( $this->[1] ) if $DEBUG;

		::try
		{
			Data::Verify::verify( $value, $this->[1] );
		}
		catch Type::Exception ::with
		{
			my $e = shift;

			my @back = caller(4);

			warn sprintf "type conflict: '%s' is not %s at %s line %d\n", $value, $this->[1]->info, $back[1], $back[2];

			record $e;
		};

		$this->[0] = $value;
	}

	sub FETCH
	{
		my $this = shift;

		::printfln "FETCH $this '%s' ", $this->[0] if $DEBUG;

		return $this->[0];
	}

1;

__END__

=head1 NAME

Data::Verify - versatile data/type verification, validation and testing

=head1 SYNOPSIS

	use Data::Verify qw(:all);

	$Data::Verify::DEBUG = 1;

	catalog();

		# Procedural interface

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

	## Type Binding (Interface)

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

=head1 DESCRIPTION

=head1 KEYWORDS

=head1 TESTS

=head2 BASIC TESTS

=head2 CUSTOM TESTS

=head1 TYPES

=head2 NUMERIC TYPES

=head2 DATE AND TIME TYPES

=head2 STRING (CHARACTERS) TYPES

=head2 CUSTOM TYPES

=head1 INTERFACE

=head2 FUNCTIONS

	verify( $teststring, $type, [ .. ] ) - Verifies a 'value' against a 'type'.

=head2 TYPE BINDING

	typ/untyp

=head2 EXPORT

all = (typ untyp verify catalog testplan), map { uc } @types

None by default.

=head1 AUTHOR

Murat Uenalan, muenalan@cpan.org

=head1 SEE ALSO

Data::Types, String::Checker, Regexp::Common, Data::FormValidator, HTML::FormValidator, CGI::FormMagick::Validator, CGI::Validate,
Email::Valid, Email::Valid::Loose, Embperl::Form::Validate

