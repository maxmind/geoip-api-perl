#!/usr/bin/perl

use Test;

use Geo::IP;

my $gi = Geo::IP->open("/usr/local/share/GeoIP/GeoIPCity.dat", GEOIP_STANDARD);

while (<DATA>) {
  chomp;
  my $r = $gi->record_by_name($_);
  if ($r) {
    print join("\t",$r->country_code,$r->country_name,$r->city,$r->region,$r->latitude,$r->longitude) . "\n";
  } else {
    print "UNDEF\n";
  }
}

__DATA__
12.10.1.4
0.0.0.0
66.108.94.158
yahoo.com
amazon.com
