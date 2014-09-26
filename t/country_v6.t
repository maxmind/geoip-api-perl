use strict;
use warnings;

use Geo::IP;

use Test::More;

if ( Geo::IP->api eq 'PurePerl' ) {
    plan skip_all => 'Pure Perl code does not have v6 methods';
}

my $gi = Geo::IP->open( 't/data/GeoIPv6.dat', GEOIP_STANDARD );

is(
    $gi->country_code_by_addr_v6('2001:200::'), 'JP',
    'expected country code'
);

done_testing();
