	# (c) 2002 by Murat Ünalan. All rights reserved. Note: This program is
# free software; you can redistribute it and/or modify it under the same
# terms as perl itself


require 5.005_62; use strict; use warnings;

use Class::Maker;

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

	use IO::Extended qw(:all);
	
	use Iter qw(:all);

	our @types = type_list();

		# generate Type subs

	codegen();

	use Exporter;

	our @ISA = qw( Exporter );

	our %EXPORT_TAGS = ( 'all' => [ qw(typ untyp istyp verify overify catalog toc testplan), map { uc } @types ] );

	our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

	our @EXPORT = ();

	our $VERSION = '0.01.25';

	our $DEBUG = 0;

	our @_history;

	our $tie_registry = {};
	
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

		printfln "\n\nVerify '%s' against '%s' (%s)", $value, ref $that, strlimit( $that->info ) if $DEBUG;
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
		println $_[0] ? '..ok' : '..failed';
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

		# verify a collection of types against an object
		
	sub overify 
	{
		my $rules = shift;
	
		my @objects = @_;

		my $m;
				
		::try
		{
			foreach my $obj ( @objects )
			{
				foreach ( iter $rules )
				{ 
					my ( $m, $t ) = ( key(), value() );
									
					if( ref( $t ) eq 'ARRAY' ) 
					{
						verify( $obj->$m ,  @{ $t } );
					}
					elsif( ref( $t ) eq 'CODE' )
					{
						throw Type::Exception( text => 'overify failed with '.$m.' for object via CODEREF' ) unless $t->( $obj->$m );
					}
					else
					{
						verify( $obj->$m , $t );
					}
				}
			}
		}
		catch Type::Exception ::with
		{			
			my $e = shift;
			
			throw $e; 
		};
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

	sub _grasp_sym_list
	{
        my $pk = shift or die;
        
		my @types = Data::Verify::_search_pkg( $pk );

		my @result;

		foreach my $key ( @types )
		{
			( my $name ) = ( $key =~ /::(.+)::$/ );

			push @result, $name if $name =~ /^[a-z]/;
		}

		return @result;
	}
	
	sub type_list { _grasp_sym_list( 'Type::' ) };
	
	sub filter_list { _grasp_sym_list( 'Filter::' ) };

	sub catalog
	{
		my @types = type_list();

		my $result;
		
		$result .= sprintf __PACKAGE__." $VERSION supports %d types:\n\n", scalar @types;
				
		foreach my $name ( sort { $a cmp $b } @types )
		{
			$result .= sprintf "%s%-18s - %s\n", " " x 2, uc $name, strlimit( ( bless [], "Type::${name}" )->info(  ) );
		}

		@types = filter_list();

		$result .= sprintf "\nAnd %d filters:\n\n", scalar @types;

		foreach my $name ( @types )
		{
			$result .= sprintf "  %-18s - %s\n", $name, strlimit( ( bless [], "Filter::${name}" )->info(  ) );
		}
		
		return $result;
	}

	sub _show_list
	{
		my $hash = shift;
		
		my $ind = shift || 1;
		
		my $result;
		
		foreach my $key (keys %$hash)
		{
			my $val = $hash->{ $key };
			
				# headlines 
				
			unless( ref( $key ) )
			{
				$result .= sprintf "%s%s\n", " " x $ind, $key;
			}
			else
			{
				$result .= sprintf "%s%s\n", " " x $ind, $_ for @$key;
			}
						
				# contents
				
			if( ref( $val ) eq 'ARRAY' )
			{
				$result .= sprintf "%s%s\n\n", "  " x $ind, join( ', ', @$val ); 
			}
			elsif( ref( $val ) eq 'HASH' )
			{			
				$result .= _show_list( $val, $ind + 2 );
			}
		}
	
	return $result;
	}

	sub toc
	{
		my @types = type_list();

		my $result;
				
		use Tie::ListKeyedHash;
		
		tie my %tied_hash, 'Tie::ListKeyedHash';
		
		foreach my $name ( @types )
		{
			my @isa = @{ "Type::${name}::ISA" };
				
			my $special_key = [ map { $_->info } @isa ];
			
			$tied_hash{ $special_key } = [] unless exists $tied_hash{ $special_key };
			
			push @{ $tied_hash{ $special_key } }, sprintf "%s", uc $name;
		}
		
		$result .= _show_list \%tied_hash;
		
		return $result;
	}

	sub typ
	{
		my $type = shift;

		foreach my $xref ( @_ )
		{
			ref($xref) or die sprintf "typ: %s reference detected, instead of a reference.", lc ref($xref) || 'no';

			$type->isa( 'Type::UNIVERSAL' ) or die sprintf "typed( ref, TYPE ) expects a TYPE as second arguemnt. You supplied '%s' which is not.", $type;

			tie $$xref, 'Data::Verify::Typed', $type;
			
			$tie_registry->{$xref+0} = ref( $type );
		}
		
		return 1;
	}

	sub istyp
	{		
		no warnings;
		
		return $tie_registry->{ $_[0]+0 } if exists $tie_registry->{ $_[0]+0 };  
	}
	
	sub untyp
	{
		untie $$_ for @_;
		
		delete $tie_registry->{$_+0} for @_;
	}

	use subs qw(typ untyp);

	sub _search_pkg
	{
		my $path = '';

		my @found;

		no strict 'refs';

		foreach my $pkg ( @_ )
		{
			next unless $pkg =~ /::$/;

			$path .= $pkg;

			if( $path =~ /(.*)::$/ )
			{
				foreach my $symbol ( sort keys %{$path} )
				{
					if( $symbol =~ /::$/ && $symbol ne 'main::' )
					{
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
			println $type if $DEBUG;

			println sprintf "sub %s { Type::Proxy::%s( \@_ ); };", uc $type, uc $type if $DEBUG;

			eval sprintf "sub %s { Type::Proxy::%s( \@_ ); };", uc $type, uc $type;

			warn $@ if $@;
		}

		println sprintf "use subs qw(%s);", uc( join ' ', Data::Verify::type_list() ) if $DEBUG;

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

		return "Type::UNIVERSAL to_text() on $this called.";
	}

package IType::Numeric;

	our @ISA = qw(Type::UNIVERSAL);

	sub info { 'Numeric' }
	
package IType::Temporal;

	our @ISA = qw(Type::UNIVERSAL);

	sub info { 'Time or Date related' }

package IType::String;

	our @ISA = qw(Type::UNIVERSAL);

	sub info { 'String' }

package IType::Logic;

	our @ISA = qw(Type::UNIVERSAL);

	sub info { 'Logic' }

package IType::DB::Mysql;

	our @ISA = qw(Type::UNIVERSAL);

	sub info { 'Database' }

package Type::varchar;

	our @ISA = qw(IType::String);

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

	our @ISA = qw(IType::String);

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

	our @ISA = qw(IType::Numeric);

	sub info
	{
		my $this = shift;

		return sprintf 'a %s value', $this->[0] || 'true or false';
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

	our @ISA = qw(IType::Numeric);

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

	our @ISA = qw(IType::Numeric);

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

	our @ISA = qw(IType::Numeric);

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

	our @ISA = qw(IType::String);

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

	our @ISA = qw(IType::String);

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

package Type::ip;

	our @ISA = qw(IType::String);

	sub info
	{
		my $this = shift;

		return 'an IP (V4, MAC) network address';
	}

	sub test
	{
		my $this = shift;

		$Type::value = shift;

			my $format = lc( $this->[0] || 'v4' );

			$format = 'IP'.$format if $format =~ /^[vV][46]$/;

			Data::Verify::pass( Function::Proxy::match( Regex::exact( $Regex::RE{net}{$format} ) ) );
	}

package Type::quoted;

	our @ISA = qw(IType::String);

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

	our @ISA = qw(IType::String);

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

package Type::yesno;

	our @ISA = qw(IType::String);

	sub info
	{
		my $this = shift;

		return 'a simple answer (yes|no)';
	}

	sub test
	{
		my $this = shift;

		$Type::value = shift;
		
			Filter::chomp->filter( \$Type::value );
			
			Filter::lc->filter( \$Type::value );

			Data::Verify::pass( Function::Proxy::exists( [qw(yes no)] ) );
	}

	# HERE START THE MYSQL TYPES
	
package Type::date;

	our @ISA = qw(IType::DB::Mysql IType::Temporal);

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

package Type::datetime;

	our @ISA = qw(IType::DB::Mysql IType::Temporal);

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

package Type::timestamp;

	our @ISA = qw(IType::DB::Mysql IType::Temporal);

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

package Type::time;

	our @ISA = qw(IType::DB::Mysql IType::Temporal);

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

package Type::year;

	our @ISA = qw(IType::DB::Mysql IType::Temporal);

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

package Type::tinytext;

	our @ISA = qw(IType::DB::Mysql IType::String);

	sub info
	{
		my $this = shift;

		return "text with a max length of 255 (2^8 - 1) characters (alias mysql tinyblob)";
	}

	sub test
	{
		my $this = shift;

		$Type::value = length( shift );

			Data::Verify::pass( Function::Proxy::max( 255 ) );
	}

package Type::text;

	our @ISA = qw(IType::DB::Mysql IType::String);

	sub info
	{
		my $this = shift;

		return "blob with a max length of 65535 (2^16 - 1) characters (alias mysql text)";
	}

	sub test
	{
		my $this = shift;

		$Type::value = length( shift );

			Data::Verify::pass( Function::Proxy::max( 65535 ) );
	}

package Type::mediumtext;

	our @ISA = qw(IType::DB::Mysql IType::String);

	sub info
	{
		my $this = shift;

		return "text with a max length of 16777215 (2^24 - 1) characters (alias mysql mediumblob)";
	}

	sub test
	{
		my $this = shift;

		$Type::value = length( shift );

			Data::Verify::pass( Function::Proxy::max( 16777215 ) );
	}

package Type::longtext;

	our @ISA = qw(IType::DB::Mysql IType::String);

	sub info
	{
		my $this = shift;

		return "text with a max length of 4294967295 (2^32 - 1) characters (alias mysql longblob)";
	}

	sub test
	{
		my $this = shift;

		$Type::value = length( shift );

			Data::Verify::pass( Function::Proxy::max( 4294967295 ) );
	}

package Type::enum;

	our @ISA = qw(IType::DB::Mysql IType::Logic);

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

package Type::set;

	our @ISA = qw(IType::DB::Mysql IType::Logic);

	sub info
	{
		my $this = shift;

			# A string object that can have zero or more values, each of which must be chosen from the list of values 'value1', 'value2', ... A SET can have a maximum of 64 members. (mysql)

		return qq{a set (can have a maximum of 64 members (mysql))};
	}

	sub test
	{
		my $this = shift;

		$Type::value = shift;

			throw Failure::Function() if @$Type::value > 64;

			throw Failure::Function() if @$this > 65535;

			Data::Verify::pass( Function::Proxy::exists( [ @$this ] ) );
	}

package Type::ref;

	our @ISA = qw(IType::Logic);

	sub info
	{
		my $this = shift;

		return qq{a reference to a variable};
	}

	sub test
	{
		my $this = shift;

		$Type::value = shift;

			Data::Verify::pass( Function::Proxy::ref( $Type::value ) );
						
			if( @$this )
			{
				$Type::value = ref( $Type::value );
				
				$this = [ @$this ] unless ref( $this ) eq 'ARRAY';
				
				Data::Verify::pass( Function::Proxy::exists( [ @$this ] ) );
			}
	}

package Type::creditcard;

	our @ISA = qw(IType::Logic);

	our $cardformats = 
	{
		DINERS => 
		{
			name	=> 'Diners Club',
			
			prefix	=> { 3000 => 3059, 3600 => 3699, 3800 => 3889 },
			
			digits	=> [ 14 ],
		},
	
		AMEX => 
		{
			name	=> 'American Express',
			
			prefix	=> { 3400 => 3499, 3700 => 3799 },
			
			digits	=> [ 15 ],
		},
		
		JCB => 
		{
			name	=> 'JCB',
			
			prefix	=> { 3528 => 3589 },

			digits	=> [ 16 ],
		},
	
		BLACHE => 
		{
			name	=> 'Carte Blache',
			
			prefix	=> { 3890 => 3899 },

			digits	=> [ 14 ],
		},
	
		VISA => 
		{
			name	=> 'VISA',
			
			prefix=> [ 4 ],

			digits	=> [ 13, 16 ],
		},
	
		MASTERCARD => 
		{
			name	=> 'MasterCard',
			
			prefix	=> { 5100 => 5599 },

			digits	=> [ 16 ],
		},
	
		BANKCARD => 
		{
			name	=> 'Australian BankCard',
			
			prefix	=> [ 5610 ],

			digits	=> [ 16 ],
		},
	
		DISCOVER => 
		{
			name	=> 'Discover/Novus',
			
			prefix	=> [ 6011 ],

			digits	=> [ 16 ],
		}		
	};

	sub info
	{
		my $this = shift;

		return sprintf 'is one of a set of creditcard type (%s)', join( ', ', keys %$cardformats );
	}

	sub usage
	{
		my $this = shift;

		return sprintf "CREDITCARD( Set of [%s], .. )", join( '|', keys %$cardformats );
	}
	
	our $default_cc = 'VISA';
	
	sub test
	{
		my $this = shift;

		$Type::value = shift;

			Filter::strip->filter( \$Type::value, '\D' );

			printf "creditcard '%s' is about to be tested\n", $Type::value if $Data::Verify::DEBUG;
			
			Data::Verify::pass( Function::Proxy::mod10check( $Type::value ) );

			push @$this, $default_cc unless @$this;
			
			my $results = {};
			
			foreach ( @$this )
			{
				$results->{$_} = [];
				
				my $card = $cardformats->{$_};
				
				push @{ $results->{$_} }, 'digits' if map { length($Type::value) eq $_ ? () : 'invalid' } @{ $card->{digits} };
				
				if( ref $card->{prefix} eq 'HASH' )
				{					
					my $prefix;
					
					while( my( $min, $max ) = each %{ $card->{prefix} } )
					{
						$prefix = pack( 'a'.length($max), $Type::value );

						push @{ $results->{$_} }, 'prefix' if $prefix+0 > $max;

						$prefix = pack( 'a'.length($min), $Type::value );

						push @{ $results->{$_} }, 'prefix' if $prefix+0 < $min;
					}
				}
				elsif( ref $card->{prefix} eq 'ARRAY' )
				{
					for ( @{ $card->{prefix} } )
					{
						$_ .= '';
						
						push @{ $results->{$_} }, 'prefix' unless $Type::value =~ /$_/;
					}
				}
			}
			
		throw Failure::Function() unless map { @{ $results->{$_} } == 0 ? 1 : () } keys %$results;
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

package Function::ref;

	sub test : method
	{
		my $this = shift;

		my $val = shift;

		throw Failure::Function() unless ref( $val );
	}

	sub info : method
	{
		my $this = shift;

		return sprintf $this->[0] ? 'reference' : 'reference to %s', $this->[0];
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

package Function::mod10check;

	use Business::CreditCard;

	sub test : method
	{
		my $this = shift;

		my $val = shift;

		# throw Failure::Function() unless mod10check( $val );

			# We use Business::CreditCard's mod10 routine
			
		throw Failure::Function() unless validate( $val );
	}

	sub info : method
	{
		my $this = shift;

		return 'LUHN formula (mod 10) for validation of creditcards';
	}
	
	# The following steps are required to validate the primary
	# account number:
	#
	# Step 1:   Double the value of alternate digits of the primary
	#			account number beginning with the second digit from
	#			the right (the first right--hand digit is the
	#			checkdigit.)
	#
	# Step 2:   Add the individual digits comprising the products
	#			obtained in Step 1 to each of the unaffected digits
	#			in the original number.
	#
	# Step 3:   The total obtained in Step 2 must be a number ending
	#			in zero (30, 40, 50, etc.) for the account number
	#			to be validated.
				
	sub mod10check($)
	{
		my $Number = shift;
	
		$Number =~ tr/[!0-9]//cd;
	
		my ( $NumberLength, $Location, $Checksum, $Digit ) = ( length($Number), 0, 0, '' );
	
			# Add even digits in even length strings
			# or odd digits in odd length strings.
		
			# checke jede zweite zahl 
		
		for( $Location = 1 - ($NumberLength % 2); $Location < $NumberLength; $Location += 2 )
		{
			$Checksum += substr($Number, $Location, 1);
		}
	
			# Analyze odd digits in even length strings
			# or even digits in odd length strings.

		for( $Location = ($NumberLength % 2); $Location < $NumberLength; $Location += 2 )
		{
			$Digit = substr($Number, $Location, 1) * 2;
			
			if ($Digit < 10)
			{
				$Checksum += $Digit;
			}
			else
			{
				$Checksum += $Digit - 9;
			}
		}
	
		# Is the checksum divisible by 10?
		
	return ($Checksum % 10 == 0);
	}

package Filter;

	sub filter : method
	{
		die "abstract method called";
	}

	sub info : method
	{
		die "abstract method called";
	}

package Filter::chomp;

	our @ISA = ( 'Filter' );
	
	sub filter : method
	{
		my $this = shift;

		my $sref_val = shift;
		
	return chomp $$sref_val;
	}

	sub info : method
	{
		my $this = shift;

		return "chomps";
	}

package Filter::lc;

	our @ISA = ( 'Filter' );
	
	sub filter : method
	{
		my $this = shift;

		my $sref_val = shift;
		
	return lc $$sref_val;
	}

	sub info : method
	{
		my $this = shift;

		return "lower cases";
	}

package Filter::strip;

	our @ISA = ( 'Filter' );
	
	sub filter : method
	{
		my $this = shift;

		my $sref_val = shift;
		
		my $what = shift;
		
		$$sref_val =~ s/$what//go;
		
	return $$sref_val;
	}

	sub info : method
	{
		my $this = shift;

		return 'strip whitespaces';
	}

package Filter::uc;

	our @ISA = ( 'Filter' );
	
	sub filter : method
	{
		my $this = shift;

		my $sref_val = shift;
		
	return lc $$sref_val;
	}

	sub info : method
	{
		my $this = shift;

		return "upper cases";
	}

package Data::Verify::Typed;

	use strict;

	require Tie::Scalar;

	our @ISA = qw(Tie::StdScalar);

	our $DEBUG = 0;

	our $BEHAVIOUR = { exceptions => 1, warnings => 1 };
	
	sub TIESCALAR
	{
		ref( $_[1] ) || die;

		$_[1]->isa( 'Type::UNIVERSAL' ) || die;

		Data::Verify::printfln "TIESC '%s'", ref( $_[1] ) if $DEBUG;

	    return bless [ undef, $_[1] ], $_[0];
	}

	sub STORE
	{
		my $this = shift;

		my $value = shift || undef;

		Data::Verify::printfln "STORE '%s' into %s typed against '%s'", $value, $this, ref( $this->[1] ) if $DEBUG;

		::try
		{
			Data::Verify::verify( $value, $this->[1] );
		}
		catch Type::Exception ::with
		{
			my $e = shift;

			my @back = caller(4);

			warn sprintf "type conflict: '%s' is not %s at %s line %d\n", $value, $this->[1]->info, $back[1], $back[2] if $BEHAVIOUR->{warnings};

			$e->value = $value;
			$e->was_file = $back[1];
			$e->was_line = $back[2];
			
			throw $e if $BEHAVIOUR->{exceptions};
		};

		$this->[0] = $value;
	}

	sub FETCH
	{
		my $this = shift;

		Data::Verify::printfln "FETCH $this '%s' ", $this->[0] if $DEBUG;

		return $this->[0];
	}

package Data::Verify::Guard;

	use Carp;
	
	Class::Maker::class
	{
		public =>
		{
			array => [qw( types )],
			
			hash => [qw( tests )],
		},
	};
	
	sub inspect : method
	{
		my $this = shift;
	
		my $object = shift;

		my $decision;

		if( @{ $this->types } > 0 )
		{			
			my %t;
	
			@t{ $this->types } = 1;

			unless( exists $t{ ref( $object ) } )
			{
				carp "Guard is selective and only accepts ", join ', ', $this->types if $Data::Verify::DEBUG;
				
				return 0;
			}    			
		}
			
		::try
		{
			Data::Verify::overify( { $this->tests }, $object );
			
			$decision = 1;
		}
		catch Type::Exception ::with
		{
			$decision = 0;
		};
	
	return $decision; 
	}

1;

__END__

=head1 NAME

Data::Verify - deprecated and moved to Data::Type

=head1 SYNOPSIS

use Data::Verify qw(:all);
use Error qw(:try);

	# EMAIL, URI, IP('V4') are standard types
	
	try
	{
		verify( $cgi->param( 'email' ),    EMAIL  );
		verify( $cgi->param( 'homepage' ), URI('http') );
		verify( $cgi->param( 'serverip' ), IP('v4') );
		verify( $cgi->param( 'cc' ),       CREDITCARD( 'MASTERCARD', 'VISA' ) );
	}
	catch Type::Exception with
	{	
		printf "Expected '%s' %s at %s line %s\n", $_->value, $_->type->info, $_->was_file, $_->was_line foreach @_;
	};

	my $h = Human->new( email => 'j@d.de', firstname => 'john', lastname => 'doe', sex => 'male', countrycode => '123123', age => 12 );
	
	$h->contacts( { lucy => '110', john => '123' } );
	
	my $g = Data::Verify::Guard->new( 

		types => [ 'Human', 'Others' ],
		
		tests =>
		{
			email		=> EMAIL( 1 ),		# mxcheck ON ! see Email::Valid
			firstname	=> WORD,
			contacts	=> sub { my %args = @_; exists $args{lucy} },				
		}
	);
	
	$g->inspect( $h );
	
=head1 DESCRIPTION

This module supports types. Out of the ordinary it supports parameterised types (like
databases have i.e. VARCHAR(80) ). When you try to feed a typed variable against some
odd data, this module explains what he would have expected. It doesnt support casting (yet).

Functionality was utilised amongst others by Regexp::Common, Email::Valid and Business::CreditCard.


=head1 KEYWORDS

data types, data manipulation, data patterns, form data, user input, tie

=head1 TYPES and FILTERS

perl -e "use Data::Verify qw(:all); print catalog()" lists all supported types:

Data::Verify 0.01.24 supports 25 types:

  BOOL               - a true or false value
  CREDITCARD         - is one of a set of creditcard type (DINERS, BANKCARD, VISA, ..
  DATE               - a date
  DATETIME           - a date and time combination
  EMAIL              - an email address
  ENUM               - a member of an enumeration
  GENDER             - a gender (male|female)
  INT                - an integer
  IP                 - an IP (V4, MAC) network address
  LONGTEXT           - text with a max length of 4294967295 (2^32 - 1) characters (..
  MEDIUMTEXT         - text with a max length of 16777215 (2^24 - 1) characters (al..
  NUM                - a number
  QUOTED             - a quoted string
  REAL               - a real
  REF                - a reference to a variable
  SET                - a set (can have a maximum of 64 members (mysql))
  TEXT               - blob with a max length of 65535 (2^16 - 1) characters (alias..
  TIME               - a time
  TIMESTAMP          - a timestamp
  TINYTEXT           - text with a max length of 255 (2^8 - 1) characters (alias my..
  URI                - an http uri
  VARCHAR            - a string with limited length of choice (default 60)
  WORD               - a word (without spaces)
  YEAR               - a year in 2- or 4-digit format
  YESNO              - a simple answer (yes|no)

And 4 filters:

  chomp              - chomps
  lc                 - lower cases
  strip              - strip whitespaces
  uc                 - upper cases


=head1 GROUPED TYPES TOC

 Logic
  CREDITCARD, REF

 Database
   Logic
      ENUM, SET

   Time or Date related
      DATE, DATETIME, TIME, TIMESTAMP, YEAR

   String
      LONGTEXT, MEDIUMTEXT, TEXT, TINYTEXT

 Numeric
  BOOL, INT, NUM, REAL

 String
  EMAIL, GENDER, IP, QUOTED, URI, VARCHAR, WORD, YESNO


=head1 INTERFACE

=head2 FUNCTIONS

verify( $teststring, $type, [ .. ] ) - Verifies a 'value' against a 'type'.

overify( { member => TYPE, .. }, $object, [ .. ] ) - Verifies members of objects against multiple 'types' or CODEREFS.

=head2 Data::Verify::Guard class

This is something like a Bouncer. He inspect 'object' members for a specific type. The class has two attributes and one
member.
	
=head3 'types' attribute (Array)

If empty isn't selective for special references (  HASH, ARRAY, "CUSTOM", .. ). If is set then "inspect" will fail if the object
is not a reference of the listed type.

=head3 'tests' attribute (Hash)

Keys are the members names (anything that can be called via the $o->member syntax) and the type(s) as value. When a member should
match multple types, they should be contained in an array reference ( i.e. 'fon' => [ qw(NUM TELEPHONE) ] ).

=head3 'inspect' member

Accepts a blessed reference as a parameter. It returns 0 if a guard test or type constrain will fail, otherwise 1.  

=head2 TYPE BINDING

typ/untyp/istyp

=head3 Example	

try
{
	typ ENUM( qw(Murat mo muri) ), \( my $alias );

	$alias = 'Murat';

	$alias = 'mo';

	$alias = 'XXX';
}
catch Type::Exception ::with
{
	printf "Expected '%s' %s at %s line %s\n", $_->value, $_->type->info, $_->was_file, $_->was_line foreach @_;
};

=head1 Exceptions

Exceptions are implemented via the 'Error' module.

=head2 Type::Exception

This is a base class inheriting 'Error'. 

=head2 Failure::Type

Is a 'Type::Exception' and has following additional members:

	bool: 
		expected	- reserved for future use 
		returned	- reserved for future use
	string: 
		was_file	- the filename where the exception was thrown
	int: 
		was_line	- the line number
	ref: 
		type 		- the type 'object' used for verification
		value		- a reference to the data given for verification against the type

=head2 Failure::Function (Internal use only)

This exception is thrown in the verification process if a Function (which is a subelement
of the verification process) fails.

Is a 'Type::Exception' and has following additional members.

	bool: 
		expected 	- reserved for future use
		returned	- reserved for future use
	ref: 
		type		- the type 'object' used for verification

=head1 Retrieving Type Information

=head2 catalog()

returns a static string containing a listing of all know types (and a short information). This
may be used to get an overview via:

perl -e "use Data::Verify qw(:all); print catalog()"

=head2 toc()

returns a string containing a grouped listing of all know types.

=head2 testplan( $type )

Returns the entry-objects how the type is verified. This may be used to create a textual description how a type is verified.
 
		foreach my $entry ( testplan( $type ) )
		{
			printf "\texpecting it %s %s ", $entry->[1] ? 'is' : 'is NOT', strlimit( $entry->[0]->info() );
		}

=head2 EXPORT

all = (typ untyp istyp verify catalog testplan), map { uc } @types

None by default.

=head2 LAST CHANGES 0.01.24

  added Tie::ListKeyedHash (0.41) to the Makefile.PL prerequisites
  cleaned some of the pod documentation
  added new type CREDITCARD (uses Business::CreditCard for LUHN mod10)
  supported types are: DINERS, BANKCARD, VISA, DISCOVER, JCB, MASTERCARD, BLACHE, AMEX

=head1 AUTHOR

Murat Ünalan, <murat.uenalan@cpan.org>

=head1 SEE ALSO

Data::Types, String::Checker, Regexp::Common, Data::FormValidator, HTML::FormValidator, CGI::FormMagick::Validator, CGI::Validate,
Email::Valid::Loose, Embperl::Form::Validate, Attribute::Types

