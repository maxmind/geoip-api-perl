package Geo::IP;

use strict;
use vars qw(@ISA $VERSION @EXPORT);

require Geo::IP::Record;
require DynaLoader;
require Exporter;
@ISA = qw(DynaLoader Exporter);

$VERSION = '1.26';

bootstrap Geo::IP $VERSION;

sub GEOIP_STANDARD(){0;}
sub GEOIP_MEMORY_CACHE(){1;}
sub GEOIP_CHECK_CACHE(){2;}
sub GEOIP_INDEX_CACHE(){4;}

sub GEOIP_UNKNOWN_SPEED(){0;}
sub GEOIP_DIALUP_SPEED(){1;}
sub GEOIP_CABLEDSL_SPEED(){2;}
sub GEOIP_CORPORATE_SPEED(){3;}

@EXPORT = qw( GEOIP_STANDARD GEOIP_MEMORY_CACHE GEOIP_CHECK_CACHE GEOIP_INDEX_CACHE
	GEOIP_UNKNOWN_SPEED GEOIP_DIALUP_SPEED GEOIP_CABLEDSL_SPEED GEOIP_CORPORATE_SPEED );

1;
__END__

=head1 NAME

Geo::IP - Look up country by IP Address

=head1 SYNOPSIS

  use Geo::IP;

  my $gi = Geo::IP->new(GEOIP_STANDARD);

  # look up IP address '24.24.24.24'
  # returns undef if country is unallocated, or not defined in our database
  my $country = $gi->country_code_by_addr('24.24.24.24');
  $country = $gi->country_code_by_name('yahoo.com');
  # $country is equal to "US"

=head1 DESCRIPTION

This module uses a file based database.  This database simply contains
IP blocks as keys, and countries as values. 
This database should be more
complete and accurate than reverse DNS lookups.

This module can be used to automatically select the geographically closest mirror,
to analyze your web server logs
to determine the countries of your visiters, for credit card fraud
detection, and for software export controls.

=head1 IP ADDRESS TO COUNTRY DATABASES

Free monthly updates to the database are available from 

  http://www.maxmind.com/download/geoip/database/

This free database is similar to the database contained in IP::Country, as 
well as many paid databases. It uses ARIN, RIPE, APNIC, and LACNIC whois to 
obtain the IP->Country mappings.

If you require greater accuracy, MaxMind offers a database on a paid 
subscription basis.  Also included with this is a service that updates your
database automatically each month, by running a program called geoipupdate
included with the C API from a cronjob.  For more details on the differences
between the free and paid databases, see:
http://www.maxmind.com/app/geoip_country

=head1 CLASS METHODS

=over 4

=item $gi = Geo::IP->new( $flags );

Constructs a new Geo::IP object with the default database located inside your system's
I<datadir>, typically I</usr/local/share/GeoIP/GeoIP.dat>.

Flags can be set to either GEOIP_STANDARD, or for faster performance
(at a cost of using more memory), GEOIP_MEMORY_CACHE.  When using memory
cache you can force a reload if the file is updated by setting GEOIP_CHECK_CACHE.

=item $gi = Geo::IP->open( $database_filename, $flags );

Constructs a new Geo::IP object with the database located at C<$database_filename>.

=back

=head1 OBJECT METHODS

=over 4

=item $code = $gi->country_code_by_addr( $ipaddr );

Returns the ISO 3166 country code for an IP address.

=item $code = $gi->country_code_by_name( $hostname );

Returns the ISO 3166 country code for a hostname.

=item $code = $gi->country_code3_by_addr( $ipaddr );

Returns the 3 letter country code for an IP address.

=item $code = $gi->country_code3_by_name( $hostname );

Returns the 3 letter country code for a hostname.

=item $name = $gi->country_name_by_addr( $ipaddr );

Returns the full country name for an IP address.

=item $name = $gi->country_name_by_name( $hostname );

Returns the full country name for a hostname.

=item $r = $gi->record_by_addr( $ipaddr );

Returns a Geo::IP::Record object containing city location for an IP address.

=item $r = $gi->record_by_name( $hostname );

Returns a Geo::IP::Record object containing city location for a hostname.

=item $org = $gi->org_by_addr( $ipaddr );

Returns the Organization or ISP name for an IP address.

=item $org = $gi->org_by_name( $hostname );

Returns the Organization or ISP name for a hostname.

=item $info = $gi->database_info;

Returns database string, includes version, date, build number and copyright notice.

=back

=head1 MAILING LISTS AND CVS

Are available from SourceForge, see
http://sourceforge.net/projects/geoip/

=head1 VERSION

1.25

=head1 SEE ALSO

Geo::IP::Record

=head1 AUTHOR

Copyright (c) 2004, MaxMind LLC

All rights reserved.  This package is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=cut
