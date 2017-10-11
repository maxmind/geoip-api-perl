#!/usr/local/bin/perl

use strict;
use warnings;

use Geo::IP;

my $gi = Geo::IP->open(
    "/usr/local/share/GeoIP/GeoIPNetSpeed.dat",
    GEOIP_STANDARD
);

my $netspeed = $gi->id_by_name("24.24.24.24");

if ( $netspeed == GEOIP_UNKNOWN_SPEED ) {
    print "Unknown\n";
}
elsif ( $netspeed == GEOIP_DIALUP_SPEED ) {
    print "Dialup\n";
}
elsif ( $netspeed == GEOIP_CABLEDSL_SPEED ) {
    print "Cable/DSL\n";
}
elsif ( $netspeed == GEOIP_CORPORATE_SPEED ) {
    print "Corporate\n";
}
