package Geo::IP::Record;

use Geo::IP;    #

use vars qw/$pp/;


  use strict;

# here are the missing functions if the C API is used
  sub latitude {
    my $gir = shift;
    return sprintf( "%.4f", $gir->_latitude );
  }

  sub longitude {
    my $gir = shift;
    return sprintf( "%.4f", $gir->_longitude );
  }



BEGIN {
 $pp = !defined(&Geo::IP::_XScompiled)
  || !Geo::IP::_XScompiled()
  || $Geo::IP::TESTING_PERL_ONLY;
}

eval <<'__PP__' if $pp;

for ( qw: country_code country_code3 country_name
          region       region_name   city
          postal_code  dma_code      area_code 
          latitude     longitude                : ) {
  no strict qw/ refs redefine /;
  my $m = $_; # looks bogus, but it is not! it is a copy not a alias
  *$_ = sub { $_[0]->{$m} };
}

__PP__
1;
