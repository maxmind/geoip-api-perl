package Geo::IP::Record;

use strict;

sub latitude {
  my $gir = shift;
  return sprintf("%.4f", $gir->_latitude);
}

sub longitude {
  my $gir = shift;
  return sprintf("%.4f", $gir->_longitude);
}

1;
