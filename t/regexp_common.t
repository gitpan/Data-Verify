use Test;
BEGIN { plan tests => 1 }

use Data::Verify qw(:all);
use Error qw(:try);

	try
	{
			# QUOTED

		verify( '"me"' , QUOTED );

			# URI

		verify( 'http://www.perl.org' , URI );

		verify( 'http://www.cpan.org' , URI('http') );

		verify( 'https://www.cpan.org' , URI('https') );

		verify( 'ftp://www.cpan.org' , URI('ftp') );

		verify( 'axkit://www.axkit.org' , URI('axkit') );

		verify( '62.01.01.20' , IPV4 );

		ok(1);
	}
	catch Type::Exception with
	{
		ok(0);
	};


