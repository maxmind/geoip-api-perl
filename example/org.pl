#!/usr/bin/perl

use Test;

use Geo::IP;

my $gi = Geo::IP->open("/usr/local/share/GeoIP/GeoIPOrg.dat", GEOIP_STANDARD);

while (<DATA>) {
  chomp;
  my ($org) = $gi->org_by_name($_);
  print join("\t",$_,$org) . "\n";
}

__DATA__
12.10.1.4
66.108.94.158
yahoo.com
amazon.com
4.2.144.64
