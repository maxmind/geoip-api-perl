package Geo::IP;

use strict;
use vars qw(@ISA $VERSION @EXPORT);

require DynaLoader;
require Exporter;
@ISA = qw(DynaLoader Exporter);

$VERSION = '0.26';

bootstrap Geo::IP $VERSION;

sub GEOIP_STANDARD(){0;}
sub GEOIP_MEMORY_CACHE(){1;}

@EXPORT = qw( GEOIP_STANDARD GEOIP_MEMORY_CACHE );

1;
__END__

=head1 NAME

Geo::IP - Look up country by IP Address

=head1 SYNOPSIS

  use Geo::IP;

  my $gi = Geo::IP->new(GEOIP_STANDARD);

  # look up IP address '65.15.30.247'
  # returns undef if country is unallocated, or not defined in our database
  my $country = $gi->country_code_by_addr('65.15.30.247');
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

To find a country for an IP address, this module a Network
that contains the IP address, then returns the country the Network is
assigned to.

=head1 CLASS METHODS

=over 4

=item $gi = Geo::IP->new( $flags );

Constructs a new Geo::IP object with the default database located inside your system's
I<datadir>, typically I</usr/local/share/GeoIP/GeoIP.dat>.

Flags can be set to either GEOIP_STANDARD, or for faster performance
(at a cost of using more memory), GEOIP_MEMORY_CACHE.

=item $gi = Geo::IP->open( $database_filename, $flags );

Constructs a new Geo::IP object with the database located at C<$database_filename>.

=back

=head1 OBJECT METHODS

=over 4

=item $code = $gi->country_code_by_addr( $ipaddr );

Returns the ISO 3166 country code for an IP address.

=item $code = $gi->country_code_by_name( $ipname );

Returns the ISO 3166 country code for a hostname.

=item $code = $gi->country_code3_by_addr( $ipaddr );

Returns the 3 letter country code for an IP address.

=item $code = $gi->country_code3_by_name( $ipname );

Returns the 3 letter country code for a hostname.

=item $name = $gi->country_name_by_addr( $ipaddr );

Returns the full country name for an IP address.

=item $name = $gi->country_name_by_name( $ipname );

Returns the full country name for a hostname.

=back

=head1 VERSION

0.26

=head1 AUTHOR

Copyright (c) 2002, MaxMind.com

All rights reserved.  This package is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=cut
