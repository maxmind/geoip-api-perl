#!/usr/local/bin/perl

use Geo::IP;

my $gi = Geo::IP->open("/home/geoip/geoipapi/c/data/GeoIPNetSpeed.dat", GEOIP_STANDARD);

my $netspeed = $gi->id_by_name("217.137.88.6");

print "netspeed = $netspeed\n";
