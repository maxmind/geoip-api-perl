use ExtUtils::MakeMaker;
use Config;
use Cwd;

$geoip_libpath = '';
$geoip_incpath = '';

my @replacement_args;

my %config;

while($_ = shift) {
    my ($key, $val) = split(/=/, $_, 2);
    $config{$key} = $val;
}

unless ($config{LIBS}) {
  # Test for existence of libGeoIP
  my $found = 0;
  foreach (split(/\s+/, $Config{libpth})) {
    if (-f "$_/libGeoIP." . $Config{so}) {
      $found = 1;
      last;
    }
  }

  unless ($found) {
    die <<'GeoIP_Not_Installed;';

GeoIP must be installed prior to building Geo::IP and I can't find
it in the standard library directories. You can download GeoIP from:

http://maxmind.com/geoip/api/c.shtml

If GeoIP is installed, but in a non-standard directory, then use the
following options to Makefile.PL:

    perl Makefile.PL LIBS='-L/home/me/lib' INC='-I/home/me/include'

Note that if you build against a shareable library in a non-standard location
you may (on some platforms) also have to set your LD_LIBRARY_PATH environment
variable at run time for perl to find the library.

GeoIP_Not_Installed;
  }
}

if ($config{LIBS} !~ /\-lGeoIP\b/) {
    $config{LIBS} .= ' -lGeoIP';
}

@extras = ();

push(@extras,
     CAPI => 'TRUE')
    if ($PERL_VERSION >= 5.005 and $OSNAME eq 'MSWin32'
	and $Config{archname} =~ /-object\b/i);

push(@extras,
     ABSTRACT_FROM => 'lib/Geo/IP.pm',
     AUTHOR        => 'T.J. Mather (tjmather@tjmather.com)')
    if ($ExtUtils::MakeMaker::Version >= 5.4301);
     
WriteMakefile(
              NAME	=> 'Geo::IP',
              dist      => {COMPRESS => 'gzip', SUFFIX => '.gz'},
              VERSION_FROM => 'lib/Geo/IP.pm',
              LIBS      => ['-lGeoIP'],
              @extras,
	      %config
             );
