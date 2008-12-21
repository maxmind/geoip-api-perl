package Geo::IP;

use strict;
use base qw(Exporter);
use vars qw($VERSION @EXPORT  $GEOIP_PP_ONLY @ISA $XS_VERSION);

BEGIN { $GEOIP_PP_ONLY = 0 unless defined( $GEOIP_PP_ONLY );}

BEGIN {       
	$VERSION = '1.36';
  eval {

    # PERL_DL_NONLAZY must be false, or any errors in loading will just
    # cause the perl code to be tested
    local $ENV{PERL_DL_NONLAZY} = 0 if $ENV{PERL_DL_NONLAZY};

    require DynaLoader;
    local @ISA = qw(DynaLoader);
    bootstrap Geo::IP $VERSION;
  } unless $GEOIP_PP_ONLY;
}

require Geo::IP::Record;

sub GEOIP_STANDARD()     { 0; } # PP
sub GEOIP_MEMORY_CACHE() { 1; } # PP
sub GEOIP_CHECK_CACHE()  { 2; }
sub GEOIP_INDEX_CACHE()  { 4; }
sub GEOIP_MMAP_CACHE()   { 8; } # PP

sub GEOIP_UNKNOWN_SPEED()   { 0; } #PP
sub GEOIP_DIALUP_SPEED()    { 1; } #PP
sub GEOIP_CABLEDSL_SPEED()  { 2; } #PP
sub GEOIP_CORPORATE_SPEED() { 3; } #PP


BEGIN {

#my $pp = !( defined &_XScompiled && &_XScompiled && !$TESTING_PERL_ONLY );
my $pp = !defined &open;

sub GEOIP_COUNTRY_EDITION()     { $pp ? 106 : 1; }
sub GEOIP_REGION_EDITION_REV0() { $pp ? 112 : 7; }
sub GEOIP_CITY_EDITION_REV0()   { $pp ? 111 : 6; }
sub GEOIP_ORG_EDITION()         { $pp ? 110 : 5; }
sub GEOIP_ISP_EDITION()         { $pp ? 109 : 4; }
sub GEOIP_CITY_EDITION_REV1()   { 2; }
sub GEOIP_REGION_EDITION_REV1() { 3; }
sub GEOIP_PROXY_EDITION()       { 8; }
sub GEOIP_ASNUM_EDITION()       { 9; }
sub GEOIP_NETSPEED_EDITION()    { 10; }
sub GEOIP_DOMAIN_EDITION()      { 11; }

sub GEOIP_CHARSET_ISO_8859_1(){0;}
sub GEOIP_CHARSET_UTF8(){1;}

# cheat --- try to load Sys::Mmap PurePerl only
if ($pp) {
  eval "require Sys::Mmap"
    ? Sys::Mmap->import
    : do {
    for (qw/ PROT_READ MAP_PRIVATE MAP_SHARED /) {
      no strict 'refs';
      my $unused_stub = $_; # we must use a copy
      *$unused_stub = sub { die 'Sys::Mmap required for mmap support' };
    }
  } # do
} # pp

}

eval << '__PP_CODE__' unless defined &open;

use strict;
use FileHandle;
use File::Spec;

BEGIN {
  if ( $] >= 5.008 ) {
    require Encode;
	Encode->import(qw/ decode /);
  }
  else {
    *decode = sub {
      local $_ = $_[1];
      use bytes;
       s/([\x80-\xff])/my $c = ord($1);
	       my $p = $c >= 192 ? 1 : 0; 
	       pack ( 'CC' => 0xc2 + $p , $c & ~0x40 ); /ge;
	   return $_;
    };
  }
};

use vars qw/$PP_OPEN_TYPE_PATH/;

use constant FULL_RECORD_LENGTH        => 50;
use constant GEOIP_COUNTRY_BEGIN       => 16776960;
use constant RECORD_LENGTH             => 3;
use constant GEOIP_STATE_BEGIN_REV0    => 16700000;
use constant GEOIP_STATE_BEGIN_REV1    => 16000000;
use constant STRUCTURE_INFO_MAX_SIZE   => 20;
use constant DATABASE_INFO_MAX_SIZE    => 100;

#use constant GEOIP_COUNTRY_EDITION     => 106;
#use constant GEOIP_REGION_EDITION_REV0 => 112;
#use constant GEOIP_REGION_EDITION_REV1 => 3;
#use constant GEOIP_CITY_EDITION_REV0   => 111;
#use constant GEOIP_CITY_EDITION_REV1   => 2;
#use constant GEOIP_ORG_EDITION         => 110;
#use constant GEOIP_ISP_EDITION         => 109;
#use constant GEOIP_NETSPEED_EDITION    => 10;

use constant SEGMENT_RECORD_LENGTH     => 3;
use constant STANDARD_RECORD_LENGTH    => 3;
use constant ORG_RECORD_LENGTH         => 4;
use constant MAX_RECORD_LENGTH         => 4;
use constant MAX_ORG_RECORD_LENGTH     => 300;
use constant US_OFFSET                 => 1;
use constant CANADA_OFFSET             => 677;
use constant WORLD_OFFSET              => 1353;
use constant FIPS_RANGE                => 360;

my @continents = qw/
--
AS EU EU AS AS SA SA EU AS SA
AF AN SA OC EU OC SA AS EU SA
AS EU AF EU AS AF AF SA AS SA
SA SA AS AF AF EU SA NA AS AF
AF AF EU AF OC SA AF AS SA SA
SA AF AS AS EU EU AF EU SA SA
AF SA EU AF AF AF EU AF EU OC
SA OC EU EU EU AF EU SA AS SA
AF EU SA AF AF SA AF EU SA SA
OC AF SA AS AF SA EU SA EU AS
EU AS AS AS AS AS EU EU SA AS
AS AF AS AS OC AF SA AS AS AS
SA AS AS AS SA EU AS AF AF EU
EU EU AF AF EU EU AF OC EU AF
AS AS AS OC SA AF SA EU AF AS
AF NA AS AF AF OC AF OC AF SA
EU EU AS OC OC OC AS SA SA OC
OC AS AS EU SA OC SA AS EU OC
SA AS AF EU AS AF AS OC AF AF
EU AS AF EU EU EU AF EU AF AF
SA AF SA AS AF SA AF AF AF AS
AS OC AS AF OC AS AS SA OC AS
AF EU AF OC NA SA AS EU SA SA
SA SA AS OC OC OC AS AF EU AF
AF EU AF -- -- -- EU EU EU EU
SA SA
/;

my @countries = (
  undef, qw/
 AP EU AD AE AF AG AI 
 AL AM AN AO AQ AR AS AT 
 AU AW AZ BA BB BD BE BF 
 BG BH BI BJ BM BN BO BR 
 BS BT BV BW BY BZ CA CC 
 CD CF CG CH CI CK CL CM 
 CN CO CR CU CV CX CY CZ 
 DE DJ DK DM DO DZ EC EE 
 EG EH ER ES ET FI FJ FK 
 FM FO FR FX GA GB GD GE 
 GF GH GI GL GM GN GP GQ 
 GR GS GT GU GW GY HK HM 
 HN HR HT HU ID IE IL IN 
 IO IQ IR IS IT JM JO JP 
 KE KG KH KI KM KN KP KR 
 KW KY KZ LA LB LC LI LK 
 LR LS LT LU LV LY MA MC 
 MD MG MH MK ML MM MN MO 
 MP MQ MR MS MT MU MV MW 
 MX MY MZ NA NC NE NF NG 
 NI NL NO NP NR NU NZ OM 
 PA PE PF PG PH PK PL PM 
 PN PR PS PT PW PY QA RE 
 RO RU RW SA SB SC SD SE 
 SG SH SI SJ SK SL SM SN 
 SO SR ST SV SY SZ TC TD 
 TF TG TH TJ TK TM TN TO 
 TL TR TT TV TW TZ UA UG 
 UM US UY UZ VA VC VE VG 
 VI VN VU WF WS YE YT RS 
 ZA ZM ME ZW A1 A2 O1 AX 
 GG IM JE BL MF/
);
my @code3s = ( undef, qw/
                   AP  EU  AND ARE AFG ATG AIA
               ALB ARM ANT AGO AQ  ARG ASM AUT
               AUS ABW AZE BIH BRB BGD BEL BFA
               BGR BHR BDI BEN BMU BRN BOL BRA
               BHS BTN BV  BWA BLR BLZ CAN CC
               COD CAF COG CHE CIV COK CHL CMR
               CHN COL CRI CUB CPV CX  CYP CZE
               DEU DJI DNK DMA DOM DZA ECU EST
               EGY ESH ERI ESP ETH FIN FJI FLK
               FSM FRO FRA FX  GAB GBR GRD GEO
               GUF GHA GIB GRL GMB GIN GLP GNQ
               GRC GS  GTM GUM GNB GUY HKG HM
               HND HRV HTI HUN IDN IRL ISR IND
               IO  IRQ IRN ISL ITA JAM JOR JPN
               KEN KGZ KHM KIR COM KNA PRK KOR
               KWT CYM KAZ LAO LBN LCA LIE LKA
               LBR LSO LTU LUX LVA LBY MAR MCO
               MDA MDG MHL MKD MLI MMR MNG MAC
               MNP MTQ MRT MSR MLT MUS MDV MWI
               MEX MYS MOZ NAM NCL NER NFK NGA
               NIC NLD NOR NPL NRU NIU NZL OMN
               PAN PER PYF PNG PHL PAK POL SPM
               PCN PRI PSE PRT PLW PRY QAT REU
               ROM RUS RWA SAU SLB SYC SDN SWE
               SGP SHN SVN SJM SVK SLE SMR SEN
               SOM SUR STP SLV SYR SWZ TCA TCD
               TF  TGO THA TJK TKL TKM TUN TON
               TLS TUR TTO TUV TWN TZA UKR UGA
               UM  USA URY UZB VAT VCT VEN VGB
               VIR VNM VUT WLF WSM YEM YT  SRB
               ZAF ZMB MNE ZWE A1  A2  O1  ALA
			   GGY IMN JEY BLM MAF         /
);
my @names = (
              undef,
              "Asia/Pacific Region",
              "Europe",
              "Andorra",
              "United Arab Emirates",
              "Afghanistan",
              "Antigua and Barbuda",
              "Anguilla",
              "Albania",
              "Armenia",
              "Netherlands Antilles",
              "Angola",
              "Antarctica",
              "Argentina",
              "American Samoa",
              "Austria",
              "Australia",
              "Aruba",
              "Azerbaijan",
              "Bosnia and Herzegovina",
              "Barbados",
              "Bangladesh",
              "Belgium",
              "Burkina Faso",
              "Bulgaria",
              "Bahrain",
              "Burundi",
              "Benin",
              "Bermuda",
              "Brunei Darussalam",
              "Bolivia",
              "Brazil",
              "Bahamas",
              "Bhutan",
              "Bouvet Island",
              "Botswana",
              "Belarus",
              "Belize",
              "Canada",
              "Cocos (Keeling) Islands",
              "Congo, The Democratic Republic of the",
              "Central African Republic",
              "Congo",
              "Switzerland",
              "Cote D'Ivoire",
              "Cook Islands",
              "Chile",
              "Cameroon",
              "China",
              "Colombia",
              "Costa Rica",
              "Cuba",
              "Cape Verde",
              "Christmas Island",
              "Cyprus",
              "Czech Republic",
              "Germany",
              "Djibouti",
              "Denmark",
              "Dominica",
              "Dominican Republic",
              "Algeria",
              "Ecuador",
              "Estonia",
              "Egypt",
              "Western Sahara",
              "Eritrea",
              "Spain",
              "Ethiopia",
              "Finland",
              "Fiji",
              "Falkland Islands (Malvinas)",
              "Micronesia, Federated States of",
              "Faroe Islands",
              "France",
              "France, Metropolitan",
              "Gabon",
              "United Kingdom",
              "Grenada",
              "Georgia",
              "French Guiana",
              "Ghana",
              "Gibraltar",
              "Greenland",
              "Gambia",
              "Guinea",
              "Guadeloupe",
              "Equatorial Guinea",
              "Greece",
              "South Georgia and the South Sandwich Islands",
              "Guatemala",
              "Guam",
              "Guinea-Bissau",
              "Guyana",
              "Hong Kong",
              "Heard Island and McDonald Islands",
              "Honduras",
              "Croatia",
              "Haiti",
              "Hungary",
              "Indonesia",
              "Ireland",
              "Israel",
              "India",
              "British Indian Ocean Territory",
              "Iraq",
              "Iran, Islamic Republic of",
              "Iceland",
              "Italy",
              "Jamaica",
              "Jordan",
              "Japan",
              "Kenya",
              "Kyrgyzstan",
              "Cambodia",
              "Kiribati",
              "Comoros",
              "Saint Kitts and Nevis",
              "Korea, Democratic People's Republic of",
              "Korea, Republic of",
              "Kuwait",
              "Cayman Islands",
              "Kazakhstan",
              "Lao People's Democratic Republic",
              "Lebanon",
              "Saint Lucia",
              "Liechtenstein",
              "Sri Lanka",
              "Liberia",
              "Lesotho",
              "Lithuania",
              "Luxembourg",
              "Latvia",
              "Libyan Arab Jamahiriya",
              "Morocco",
              "Monaco",
              "Moldova, Republic of",
              "Madagascar",
              "Marshall Islands",
              "Macedonia",
              "Mali",
              "Myanmar",
              "Mongolia",
              "Macau",
              "Northern Mariana Islands",
              "Martinique",
              "Mauritania",
              "Montserrat",
              "Malta",
              "Mauritius",
              "Maldives",
              "Malawi",
              "Mexico",
              "Malaysia",
              "Mozambique",
              "Namibia",
              "New Caledonia",
              "Niger",
              "Norfolk Island",
              "Nigeria",
              "Nicaragua",
              "Netherlands",
              "Norway",
              "Nepal",
              "Nauru",
              "Niue",
              "New Zealand",
              "Oman",
              "Panama",
              "Peru",
              "French Polynesia",
              "Papua New Guinea",
              "Philippines",
              "Pakistan",
              "Poland",
              "Saint Pierre and Miquelon",
              "Pitcairn Islands",
              "Puerto Rico",
              "Palestinian Territory",
              "Portugal",
              "Palau",
              "Paraguay",
              "Qatar",
              "Reunion",
              "Romania",
              "Russian Federation",
              "Rwanda",
              "Saudi Arabia",
              "Solomon Islands",
              "Seychelles",
              "Sudan",
              "Sweden",
              "Singapore",
              "Saint Helena",
              "Slovenia",
              "Svalbard and Jan Mayen",
              "Slovakia",
              "Sierra Leone",
              "San Marino",
              "Senegal",
              "Somalia",
              "Suriname",
              "Sao Tome and Principe",
              "El Salvador",
              "Syrian Arab Republic",
              "Swaziland",
              "Turks and Caicos Islands",
              "Chad",
              "French Southern Territories",
              "Togo",
              "Thailand",
              "Tajikistan",
              "Tokelau",
              "Turkmenistan",
              "Tunisia",
              "Tonga",
              "Timor-Leste",
              "Turkey",
              "Trinidad and Tobago",
              "Tuvalu",
              "Taiwan",
              "Tanzania, United Republic of",
              "Ukraine",
              "Uganda",
              "United States Minor Outlying Islands",
              "United States",
              "Uruguay",
              "Uzbekistan",
              "Holy See (Vatican City State)",
              "Saint Vincent and the Grenadines",
              "Venezuela",
              "Virgin Islands, British",
              "Virgin Islands, U.S.",
              "Vietnam",
              "Vanuatu",
              "Wallis and Futuna",
              "Samoa",
              "Yemen",
              "Mayotte",
              "Serbia",
              "South Africa",
              "Zambia",
              "Montenegro",
              "Zimbabwe",
              "Anonymous Proxy",
              "Satellite Provider",
              "Other",
			  "Aland Islands",
              "Guernsey",
              "Isle of Man",
              "Jersey",
			  "Saint Barthelemy",
			  "Saint Martin"
);

# --- unfortunately we do not know the path so we assume the 
# default path /usr/local/share/GeoIP
# if thats not true, you can set $Geo::IP::PP_OPEN_TYPE_PATH
#
sub open_type {
  my ( $class, $type, $flags ) = @_;
  my %type_dat_name_mapper = (
    GEOIP_COUNTRY_EDITION()     => 'GeoIP',
    GEOIP_REGION_EDITION_REV0() => 'GeoIPRegion',
    GEOIP_REGION_EDITION_REV1() => 'GeoIPRegion',
    GEOIP_CITY_EDITION_REV0()   => 'GeoIPCity',
    GEOIP_CITY_EDITION_REV1()   => 'GeoIPCity',
    GEOIP_ISP_EDITION()         => 'GeoIPISP',
    GEOIP_ORG_EDITION()         => 'GeoIPOrg',
    GEOIP_PROXY_EDITION()       => 'GeoIPProxy',
    GEOIP_ASNUM_EDITION()       => 'GeoIPASNum',
    GEOIP_NETSPEED_EDITION()    => 'GeoIPNetSpeed',
    GEOIP_DOMAIN_EDITION()      => 'GeoIPDomain',
  );

  my $name = $type_dat_name_mapper{$type};
  die("Invalid database type $type\n") unless $name;

  my $mkpath = sub { File::Spec->catfile( File::Spec->rootdir, @_ ) };

  my $path =
    defined $Geo::IP::PP_OPEN_TYPE_PATH
    ? $Geo::IP::PP_OPEN_TYPE_PATH
    : do {
    $^O eq 'NetWare'
      ? $mkpath->(qw/ etc GeoIP /)
      : do {
	    $^O eq 'MSWin32'
        ? $mkpath->(qw/ GeoIP /)
        : $mkpath->(qw/ usr local share GeoIP /);
      }
    };

  my $filename = File::Spec->catfile( $path, $name . '.dat' );
  return $class->open( $filename, $flags );
}

sub open {
  die "Geo::IP::open() requires a path name"
    unless ( @_ > 1 and $_[1] );
  my ( $class, $db_file, $flags ) = @_;
  my $fh = FileHandle->new;
  my $gi;
  CORE::open $fh, "$db_file" or die "Error opening $db_file";
  binmode($fh);
  if ( $flags && ( $flags & ( GEOIP_MEMORY_CACHE | GEOIP_MMAP_CACHE ) ) ) {
    my %self;
 		if ( $flags & GEOIP_MMAP_CACHE ) {
		  die "Sys::Mmap required for MMAP support"
		    unless defined $Sys::Mmap::VERSION;
		  mmap( $self{buf} = undef, 0, PROT_READ, MAP_PRIVATE, $fh )
		    or die "mmap: $!";
		}
    else {
		  local $/ = undef;
		  $self{buf} = <$fh>;
		}   
		$self{fh}  = $fh;
    $gi = bless \%self, $class;
  }
	else {
	  $gi = bless { fh => $fh }, $class;
	}
	$gi->_setup_segments();
	return $gi;
}

sub new {
  my ( $class, $db_file, $flags ) = @_;

  # this will be less messy once deprecated new( $path, [$flags] )
  # is no longer supported (that's what open() is for)
  my $def_db_file = '/usr/local/share/GeoIP/GeoIP.dat';
  if ($^O eq 'NetWare') {
    $def_db_file = 'sys:/etc/GeoIP/GeoIP.dat';
  } elsif ($^O eq 'MSWin32') {
    $def_db_file = 'c:/GeoIP/GeoIP.dat';
  }
  if ( !defined $db_file ) {

    # called as new()
    $db_file = $def_db_file;
  }
  elsif ( $db_file =~ /^\d+$/	) {
    # called as new( $flags )
    $flags   = $db_file;
    $db_file = $def_db_file;
  }    # else called as new( $database_filename, [$flags] );

  $class->open( $db_file, $flags );
}

#this function setups the database segments
sub _setup_segments {
  my ($gi) = @_;
  my $a    = 0;
  my $i    = 0;
  my $j    = 0;
  my $delim;
  my $buf;

  $gi->{_charset} = GEOIP_CHARSET_ISO_8859_1; 
  $gi->{"databaseType"}  = GEOIP_COUNTRY_EDITION;
  $gi->{"record_length"} = STANDARD_RECORD_LENGTH;

  my $filepos = tell( $gi->{fh} );
  seek( $gi->{fh}, -3, 2 );
  for ( $i = 0; $i < STRUCTURE_INFO_MAX_SIZE; $i++ ) {
    read( $gi->{fh}, $delim, 3 );

    #find the delim
    if ( $delim eq ( chr(255) . chr(255) . chr(255) ) ) {
      read( $gi->{fh}, $a, 1 );

      #read the databasetype
      $gi->{"databaseType"} = ord($a);

#chose the database segment for the database type
#if database Type is GEOIP_REGION_EDITION then use database segment GEOIP_STATE_BEGIN
      if ( $gi->{"databaseType"} == GEOIP_REGION_EDITION_REV0 ) {
        $gi->{"databaseSegments"} = GEOIP_STATE_BEGIN_REV0;
      }
      elsif ( $gi->{"databaseType"} == GEOIP_REGION_EDITION_REV1 ) {
        $gi->{"databaseSegments"} = GEOIP_STATE_BEGIN_REV1;
      }

#if database Type is GEOIP_CITY_EDITION, GEOIP_ISP_EDITION or GEOIP_ORG_EDITION then
#read in the database segment
      elsif (    ( $gi->{"databaseType"} == GEOIP_CITY_EDITION_REV0 )
              || ( $gi->{"databaseType"} == GEOIP_CITY_EDITION_REV1 )
              || ( $gi->{"databaseType"} == GEOIP_ORG_EDITION )
              || ( $gi->{"databaseType"} == GEOIP_ISP_EDITION ) ) {
        $gi->{"databaseSegments"} = 0;

        #read in the database segment for the database type
        read( $gi->{fh}, $buf, SEGMENT_RECORD_LENGTH );
        for ( $j = 0; $j < SEGMENT_RECORD_LENGTH; $j++ ) {
          $gi->{"databaseSegments"} +=
            ( ord( substr( $buf, $j, 1 ) ) << ( $j * 8 ) );
        }

#record length is four for ISP databases and ORG databases
#record length is three for country databases, region database and city databases
        if ( $gi->{"databaseType"} == GEOIP_ORG_EDITION ) {
          $gi->{"record_length"} = ORG_RECORD_LENGTH;
        }
      }
      last;
    }
    else {
      seek( $gi->{fh}, -4, 1 );
    }
  }

#if database Type is GEOIP_COUNTY_EDITION then use database segment GEOIP_COUNTRY_BEGIN
  if (    $gi->{"databaseType"} == GEOIP_COUNTRY_EDITION
       || $gi->{"databaseType"} == GEOIP_NETSPEED_EDITION ) {
    $gi->{"databaseSegments"} = GEOIP_COUNTRY_BEGIN;
  }
  seek( $gi->{fh}, $filepos, 0 );
  return $gi;
}

sub _seek_country {
  my ( $gi, $ipnum ) = @_;

  my $fh     = $gi->{fh};
  my $offset = 0;

  my ( $x0, $x1 );

  my $reclen = $gi->{record_length};

  for ( my $depth = 31; $depth >= 0; $depth-- ) {
    unless ( exists $gi->{buf} ) {
      seek $fh, $offset * 2 * $reclen, 0;
      read $fh, $x0, $reclen;
      read $fh, $x1, $reclen;
    }
    else {
      $x0 = substr( $gi->{buf}, $offset * 2 * $reclen, $reclen );
      $x1 = substr( $gi->{buf}, $offset * 2 * $reclen + $reclen, $reclen );
    }

    $x0 = unpack( "V1", $x0 . "\0" );
    $x1 = unpack( "V1", $x1 . "\0" );

    if ( $ipnum & ( 1 << $depth ) ) {
      if ( $x1 >= $gi->{"databaseSegments"} ) {
	    $gi->{last_netmask} = 32 - $depth;
        return $x1;
      }
      $offset = $x1;
    }
    else {
      if ( $x0 >= $gi->{"databaseSegments"} ) {
	    $gi->{last_netmask} = 32 - $depth;
        return $x0;
      }
      $offset = $x0;
    }
  }

  print STDERR
"Error Traversing Database for ipnum = $ipnum - Perhaps database is corrupt?";
}

sub charset {
  return $_[0]->{_charset};
}

sub set_charset{
  my ($gi, $charset) = @_;
  my $old_charset = $gi->{_charset};
  $gi->{_charset} = $charset;
  return $old_charset;
}

#this function returns the country code of ip address
sub country_code_by_addr {
  my ( $gi, $ip_address ) = @_;
  return unless $ip_address =~ m!^(?:\d{1,3}\.){3}\d{1,3}$!;
  return $countries[ $gi->id_by_addr($ip_address) ];
}

#this function returns the country code3 of ip address
sub country_code3_by_addr {
  my ( $gi, $ip_address ) = @_;
  return unless $ip_address =~ m!^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$!;
  return $code3s[ $gi->id_by_addr($ip_address) ];
}

#this function returns the name of ip address
sub country_name_by_addr {
  my ( $gi, $ip_address ) = @_;
  return unless $ip_address =~ m!^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$!;
  return $names[ $gi->id_by_addr($ip_address) ];
}

sub id_by_addr {
  my ( $gi, $ip_address ) = @_;
  return unless $ip_address =~ m!^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$!;
  return $gi->_seek_country( addr_to_num($ip_address) ) - GEOIP_COUNTRY_BEGIN;
}

#this function returns the country code of domain name
sub country_code_by_name {
  my ( $gi, $host ) = @_;
  my $country_id = $gi->id_by_name($host);
  return $countries[$country_id];
}

#this function returns the country code3 of domain name
sub country_code3_by_name {
  my ( $gi, $host ) = @_;
  my $country_id = $gi->id_by_name($host);
  return $code3s[$country_id];
}

#this function returns the country name of domain name
sub country_name_by_name {
  my ( $gi, $host ) = @_;
  my $country_id = $gi->id_by_name($host);
  return $names[$country_id];
}

sub id_by_name {
  my ( $gi, $host ) = @_;
  my $ip_address;
  if ( $host =~ m!^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$! ) {
    $ip_address = $host;
  }
  else {
    $ip_address = join( '.', unpack( 'C4', ( gethostbyname($host) )[4] ) );
  }
  return unless $ip_address;
  return $gi->_seek_country( addr_to_num($ip_address) ) - GEOIP_COUNTRY_BEGIN;
}

#this function returns the city record as a array
sub get_city_record {
  my ( $gi, $host ) = @_;
  my $ip_address = $gi->get_ip_address($host);
  return unless $ip_address;
  my $record_buf;
  my $record_buf_pos;
  my $char;
  my $metroarea_combo;
  my $record_country_code  = "";
  my $record_country_code3 = "";
  my $record_country_name  = "";
  my $record_region        = "";
  my $record_city          = "";
  my $record_postal_code   = "";
  my $record_latitude      = "";
  my $record_longitude     = "";
  my $record_metro_code    = "";
  my $record_area_code     = "";
  my $record_continent_code = '';
  my $record_region_name = '';
  my $str_length           = 0;
  my $i;
  my $j;

  #lookup the city
  my $seek_country = $gi->_seek_country( addr_to_num($ip_address) );
  if ( $seek_country == $gi->{"databaseSegments"} ) {
    return;
  }

  #set the record pointer to location of the city record
  my $record_pointer = $seek_country +
    ( 2 * $gi->{"record_length"} - 1 ) * $gi->{"databaseSegments"};

  unless ( exists $gi->{buf} ) {
    seek( $gi->{"fh"}, $record_pointer, 0 );
    read( $gi->{"fh"}, $record_buf, FULL_RECORD_LENGTH );
    $record_buf_pos = 0;
  }
	else {
	  $record_buf = substr($gi->{buf}, $record_pointer, FULL_RECORD_LENGTH);
    $record_buf_pos = 0;
  }

  #get the country
  $char = ord( substr( $record_buf, $record_buf_pos, 1 ) );
  $record_country_code = $countries[$char];    #get the country code
  $record_country_code3 = $code3s[$char];   #get the country code with 3 letters
  $record_country_name  = $names[$char];    #get the country name
  $record_buf_pos++;

  # get the continent code
  $record_continent_code = $continents[$char];

  #get the region
  $char = ord( substr( $record_buf, $record_buf_pos + $str_length, 1 ) );
  while ( $char != 0 ) {
    $str_length++;                          #get the length of string
    $char = ord( substr( $record_buf, $record_buf_pos + $str_length, 1 ) );
  }
  if ( $str_length > 0 ) {
    $record_region = substr( $record_buf, $record_buf_pos, $str_length );
  }
  $record_buf_pos += $str_length + 1;
  $str_length = 0;

  #get the city
  $char = ord( substr( $record_buf, $record_buf_pos + $str_length, 1 ) );
  while ( $char != 0 ) {
    $str_length++;                          #get the length of string
    $char = ord( substr( $record_buf, $record_buf_pos + $str_length, 1 ) );
  }
  if ( $str_length > 0 ) {
    $record_city = substr( $record_buf, $record_buf_pos, $str_length );
  }
  $record_buf_pos += $str_length + 1;
  $str_length = 0;

  #get the postal code
  $char = ord( substr( $record_buf, $record_buf_pos + $str_length, 1 ) );
  while ( $char != 0 ) {
    $str_length++;                          #get the length of string
    $char = ord( substr( $record_buf, $record_buf_pos + $str_length, 1 ) );
  }
  if ( $str_length > 0 ) {
    $record_postal_code = substr( $record_buf, $record_buf_pos, $str_length );
  }
  $record_buf_pos += $str_length + 1;
  $str_length = 0;
  my $latitude  = 0;
  my $longitude = 0;

  #get the latitude
  for ( $j = 0; $j < 3; ++$j ) {
    $char = ord( substr( $record_buf, $record_buf_pos++, 1 ) );
    $latitude += ( $char << ( $j * 8 ) );
  }
  $record_latitude = ( $latitude / 10000 ) - 180;

  #get the longitude
  for ( $j = 0; $j < 3; ++$j ) {
    $char = ord( substr( $record_buf, $record_buf_pos++, 1 ) );
    $longitude += ( $char << ( $j * 8 ) );
  }
  $record_longitude = ( $longitude / 10000 ) - 180;

  #get the metro code and the area code
  if ( GEOIP_CITY_EDITION_REV1 == $gi->{"databaseType"} ) {
    $metroarea_combo = 0;
    if ( $record_country_code eq "US" ) {

      #if the country is US then read the dma/metro area combo
      for ( $j = 0; $j < 3; ++$j ) {
        $char = ord( substr( $record_buf, $record_buf_pos++, 1 ) );
        $metroarea_combo += ( $char << ( $j * 8 ) );
      }

      #split the dma/metro area combo into the metro code and the area code
      $record_metro_code  = int( $metroarea_combo / 1000 );
      $record_area_code = $metroarea_combo % 1000;
    }
  }
  $record_region_name = _get_region_name($record_country_code, $record_region) || '';


 # the pureperl API must convert the string by themself to UTF8
 # using Encode for perl >= 5.008 otherwise use it's own iso-8859-1 to utf8 converter
 $record_city = decode( 'iso-8859-1' => $record_city ) 
   if $gi->charset == GEOIP_CHARSET_UTF8; 

  return (
           $record_country_code, $record_country_code3, $record_country_name,
           $record_region,       $record_city,          $record_postal_code,
           $record_latitude,     $record_longitude,     $record_metro_code,
           $record_area_code,    $record_continent_code, $record_region_name,
		   $record_metro_code );
}

#this function returns the city record as a hash ref
sub get_city_record_as_hash {
  my ( $gi, $host ) = @_;
  my %gir;

  @gir{qw/ country_code   country_code3   country_name   region     city 
           postal_code    latitude        longitude      dma_code   area_code 
		   continent_code region_name metro_code/ } =
    $gi->get_city_record($host);
  
  return bless \%gir, 'Geo::IP::Record';
}

*record_by_addr = \&get_city_record_as_hash;
*record_by_name = \&get_city_record_as_hash;

#this function returns isp or org of the domain name
sub org_by_name {
  my ( $gi, $host ) = @_;
  my $ip_address = $gi->get_ip_address($host);
  my $seek_org   = $gi->_seek_country( addr_to_num($ip_address) );
  my $char;
  my $org_buf;
  my $org_buf_length = 0;
  my $record_pointer;

  if ( $seek_org == $gi->{"databaseSegments"} ) {
    return undef;
  }

  $record_pointer =
    $seek_org + ( 2 * $gi->{"record_length"} - 1 ) * $gi->{"databaseSegments"};
  
  unless ( exists $gi->{buf} ) {
    seek( $gi->{"fh"}, $record_pointer, 0 );
    read( $gi->{"fh"}, $org_buf, MAX_ORG_RECORD_LENGTH );
  }
	else {
    $org_buf = substr($gi->{buf}, $record_pointer, MAX_ORG_RECORD_LENGTH );
	}
	
  $char = ord( substr( $org_buf, 0, 1 ) );
  while ( $char != 0 ) {
    $org_buf_length++;
    $char = ord( substr( $org_buf, $org_buf_length, 1 ) );
  }

  $org_buf = substr( $org_buf, 0, $org_buf_length );
  return $org_buf;
}

#this function returns isp or org of the domain name
*isp_by_name = \*org_by_name;
*isp_by_addr = \*org_by_name;
*org_by_addr = \*org_by_name;

#this function returns the region
sub region_by_name {
  my ( $gi, $host ) = @_;
  my $ip_address = $gi->get_ip_address($host);
  return unless $ip_address;
  if ( $gi->{"databaseType"} == GEOIP_REGION_EDITION_REV0 ) {
    my $seek_region =
      $gi->_seek_country( addr_to_num($ip_address) ) - GEOIP_STATE_BEGIN_REV0;
    if ( $seek_region < 1000 ) {
      return (
               "US",
               chr( ( $seek_region - 1000 ) / 26 + 65 )
                 . chr( ( $seek_region - 1000 ) % 26 + 65 )
      );
    }
    else {
      return ( $countries[$seek_region], "" );
    }
  }
  elsif ( $gi->{"databaseType"} == GEOIP_REGION_EDITION_REV1 ) {
    my $seek_region =
      $gi->_seek_country( addr_to_num($ip_address) ) - GEOIP_STATE_BEGIN_REV1;
    if ( $seek_region < US_OFFSET ) {
      return ( "", "" );
    }
    elsif ( $seek_region < CANADA_OFFSET ) {

      # return a us state
      return (
               "US",
               chr( ( $seek_region - US_OFFSET ) / 26 + 65 )
                 . chr( ( $seek_region - US_OFFSET ) % 26 + 65 )
      );
    }
    elsif ( $seek_region < WORLD_OFFSET ) {

      # return a canada province
      return (
               "CA",
               chr( ( $seek_region - CANADA_OFFSET ) / 26 + 65 )
                 . chr( ( $seek_region - CANADA_OFFSET ) % 26 + 65 )
      );
    }
    else {

      # return a country of the world
      my $c = $countries[ ( $seek_region - WORLD_OFFSET ) / FIPS_RANGE ];
      my $a2 = ( $seek_region - WORLD_OFFSET ) % FIPS_RANGE;
      my $r =
          chr( ( $a2 / 100 ) + 48 )
        . chr( ( ( $a2 / 10 ) % 10 ) + 48 )
        . chr( ( $a2 % 10 ) + 48 );
      return ( $c, $r );
    }
  }
}

sub get_ip_address {
  my ( $gi, $host ) = @_;
  my $ip_address;

  #check if host is ip address
  if ( $host =~ m!^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$! ) {

    #host is ip address
    $ip_address = $host;
  }
  else {

    #host is domain name do a dns lookup
    $ip_address = join( '.', unpack( 'C4', ( gethostbyname($host) )[4] ) );
  }
  return $ip_address;
}

sub addr_to_num { unpack( N => pack( C4 => split( /\./, $_[0] ) ) ) }
sub num_to_addr { join q{.}, unpack( C4 => pack( N => $_[0] ) ) }

#sub addr_to_num {
#  my @a = split( '\.', $_[0] );
#  return $a[0] * 16777216 + $a[1] * 65536 + $a[2] * 256 + $a[3];
#}

sub database_info {
  my $gi = shift;
  my $i  = 0;
  my $buf;
  my $retval;
  my $hasStructureInfo;
  seek( $gi->{fh}, -3, 2 );
  for ( my $i = 0; $i < STRUCTURE_INFO_MAX_SIZE; $i++ ) {
    read( $gi->{fh}, $buf, 3 );
    if ( $buf eq ( chr(255) . chr(255) . chr(255) ) ) {
      $hasStructureInfo = 1;
      last;
    }
    seek( $gi->{fh}, -4, 1 );
  }
  if ( $hasStructureInfo == 1 ) {
    seek( $gi->{fh}, -6, 1 );
  }
  else {

    # no structure info, must be pre Sep 2002 database, go back to
    seek( $gi->{fh}, -3, 2 );
  }
  for ( my $i = 0; $i < DATABASE_INFO_MAX_SIZE; $i++ ) {
    read( $gi->{fh}, $buf, 3 );
    if ( $buf eq ( chr(0) . chr(0) . chr(0) ) ) {
      read( $gi->{fh}, $retval, $i );
      return $retval;
    }
    seek( $gi->{fh}, -4, 1 );
  }
  return '';
}

sub range_by_ip {
  my $gi = shift;
  my $ipnum          = addr_to_num( shift );
  my $c              = $gi->_seek_country( $ipnum );
  my $nm             = $gi->last_netmask;
  my $m              = 0xffffffff << 32 - $nm;
  my $left_seek_num  = $ipnum & $m;
  my $right_seek_num = $left_seek_num + ( 0xffffffff & ~$m );

  while ( $left_seek_num != 0
          and $c == $gi->_seek_country(  $left_seek_num - 1) ) {
    my $lm = 0xffffffff << 32 - $gi->last_netmask;
    $left_seek_num = ( $left_seek_num - 1 ) & $lm;
  }
  while ( $right_seek_num != 0xffffffff
          and $c == $gi->_seek_country( $right_seek_num + 1 ) ) {
    my $rm = 0xffffffff << 32 - $gi->last_netmask;
    $right_seek_num = ( $right_seek_num + 1 ) & $rm;
    $right_seek_num += ( 0xffffffff & ~$rm );
  }
  return ( num_to_addr($left_seek_num), num_to_addr($right_seek_num) );
}


sub netmask { $_[0]->{last_netmask} = $_[1] }

sub last_netmask {
  return $_[0]->{last_netmask};
}

sub DESTROY {
  my $gi = shift;
 
  if ( exists $gi->{buf} && $gi->{flags} && ( $gi->{flags} & GEOIP_MMAP_CACHE ) ) {
    munmap( $gi->{buf} ) or die "munmap: $!";
	  delete $gi->{buf};
  }
}

#sub _XS
__PP_CODE__

print STDERR $@ if $@;


@EXPORT = qw( 
  GEOIP_STANDARD              GEOIP_MEMORY_CACHE
  GEOIP_CHECK_CACHE           GEOIP_INDEX_CACHE
  GEOIP_UNKNOWN_SPEED         GEOIP_DIALUP_SPEED
  GEOIP_CABLEDSL_SPEED        GEOIP_CORPORATE_SPEED
  GEOIP_COUNTRY_EDITION       GEOIP_REGION_EDITION_REV0
  GEOIP_CITY_EDITION_REV0     GEOIP_ORG_EDITION
  GEOIP_ISP_EDITION           GEOIP_CITY_EDITION_REV1
  GEOIP_REGION_EDITION_REV1   GEOIP_PROXY_EDITION
  GEOIP_ASNUM_EDITION         GEOIP_NETSPEED_EDITION
  GEOIP_CHARSET_ISO_8859_1    GEOIP_CHARSET_UTF8
  GEOIP_MMAP_CACHE
);

## created with:
# perl -Ilib -e 'use MM::GeoIP::Reloaded::Country_Region_Names q{%country_region_names}; use Data::Dumper; print Dumper(\%country_region_names)' >/tmp/crn.pl
#

my %country_region_names = (
                         'GL' => {
                                   '01' => 'Nordgronland',
                                   '03' => 'Vestgronland',
                                   '02' => 'Ostgronland'
                         },
                         'DJ' => {
                                   '07' => 'Djibouti',
                                   '01' => 'Ali Sabieh',
                                   '05' => 'Tadjoura',
                                   '08' => 'Arta',
                                   '06' => 'Dikhil',
                                   '04' => 'Obock'
                         },
                         'JM' => {
                                   '11' => 'Saint Elizabeth',
                                   '01' => 'Clarendon',
                                   '04' => 'Manchester',
                                   '12' => 'Saint James',
                                   '17' => 'Kingston',
                                   '02' => 'Hanover',
                                   '14' => 'Saint Thomas',
                                   '15' => 'Trelawny',
                                   '07' => 'Portland',
                                   '08' => 'Saint Andrew',
                                   '10' => 'Saint Catherine',
                                   '13' => 'Saint Mary',
                                   '16' => 'Westmoreland',
                                   '09' => 'Saint Ann'
                         },
                         'PG' => {
                                   '11' => 'East Sepik',
                                   '05' => 'Southern Highlands',
                                   '04' => 'Northern',
                                   '17' => 'West New Britain',
                                   '02' => 'Gulf',
                                   '18' => 'Sandaun',
                                   '03' => 'Milne Bay',
                                   '08' => 'Chimbu',
                                   '06' => 'Western',
                                   '13' => 'Manus',
                                   '16' => 'Western Highlands',
                                   '01' => 'Central',
                                   '12' => 'Madang',
                                   '20' => 'National Capital',
                                   '14' => 'Morobe',
                                   '15' => 'New Ireland',
                                   '07' => 'North Solomons',
                                   '10' => 'East New Britain',
                                   '19' => 'Enga',
                                   '09' => 'Eastern Highlands'
                         },
                         'AT' => {
                                   '01' => 'Burgenland',
                                   '05' => 'Salzburg',
                                   '04' => 'Oberosterreich',
                                   '02' => 'Karnten',
                                   '07' => 'Tirol',
                                   '03' => 'Niederosterreich',
                                   '08' => 'Vorarlberg',
                                   '06' => 'Steiermark',
                                   '09' => 'Wien'
                         },
                         'KI' => {
                                   '01' => 'Gilbert Islands',
                                   '03' => 'Phoenix Islands',
                                   '02' => 'Line Islands'
                         },
                         'SZ' => {
                                   '01' => 'Hhohho',
                                   '03' => 'Manzini',
                                   '05' => 'Praslin',
                                   '04' => 'Shiselweni',
                                   '02' => 'Lubombo'
                         },
                         'BN' => {
                                   '11' => 'Collines',
                                   '12' => 'Kouffo',
                                   '17' => 'Plateau',
                                   '14' => 'Littoral',
                                   '15' => 'Tutong',
                                   '07' => 'Alibori',
                                   '18' => 'Zou',
                                   '08' => 'Belait',
                                   '13' => 'Donga',
                                   '16' => 'Oueme',
                                   '10' => 'Temburong',
                                   '09' => 'Brunei and Muara'
                         },
                         'ZM' => {
                                   '01' => 'Western',
                                   '05' => 'Northern',
                                   '04' => 'Luapula',
                                   '02' => 'Central',
                                   '07' => 'Southern',
                                   '03' => 'Eastern',
                                   '08' => 'Copperbelt',
                                   '06' => 'North-Western',
                                   '09' => 'Lusaka'
                         },
                         'CD' => {
                                   '11' => 'Nord-Kivu',
                                   '01' => 'Bandundu',
                                   '05' => 'Katanga',
                                   '04' => 'Kasai-Oriental',
                                   '12' => 'Sud-Kivu',
                                   '02' => 'Equateur',
                                   '07' => 'Kivu',
                                   '08' => 'Bas-Congo',
                                   '06' => 'Kinshasa',
                                   '10' => 'Maniema',
                                   '13' => 'Cuvette',
                                   '09' => 'Orientale'
                         },
                         'BW' => {
                                   '11' => 'North-West',
                                   '01' => 'Central',
                                   '05' => 'Kgatleng',
                                   '04' => 'Kgalagadi',
                                   '03' => 'Ghanzi',
                                   '08' => 'North-East',
                                   '06' => 'Kweneng',
                                   '10' => 'Southern',
                                   '09' => 'South-East'
                         },
                         'AO' => {
                                   '05' => 'Cuanza Norte',
                                   '04' => 'Cuando Cubango',
                                   '17' => 'Lunda Norte',
                                   '02' => 'Bie',
                                   '18' => 'Lunda Sul',
                                   '03' => 'Cabinda',
                                   '08' => 'Huambo',
                                   '16' => 'Zaire',
                                   '06' => 'Cuanza Sul',
                                   '01' => 'Benguela',
                                   '12' => 'Malanje',
                                   '20' => 'Luanda',
                                   '14' => 'Moxico',
                                   '15' => 'Uige',
                                   '07' => 'Cunene',
                                   '19' => 'Bengo',
                                   '10' => 'Luanda',
                                   '09' => 'Huila'
                         },
                         'ZW' => {
                                   '01' => 'Manicaland',
                                   '05' => 'Mashonaland West',
                                   '04' => 'Mashonaland East',
                                   '02' => 'Midlands',
                                   '07' => 'Matabeleland South',
                                   '03' => 'Mashonaland Central',
                                   '08' => 'Masvingo',
                                   '10' => 'Harare',
                                   '06' => 'Matabeleland North',
                                   '09' => 'Bulawayo'
                         },
                         'VC' => {
                                   '01' => 'Charlotte',
                                   '03' => 'Saint David',
                                   '05' => 'Saint Patrick',
                                   '06' => 'Grenadines',
                                   '04' => 'Saint George',
                                   '02' => 'Saint Andrew'
                         },
                         'JP' => {
                                   '32' => 'Osaka',
                                   '33' => 'Saga',
                                   '21' => 'Kumamoto',
                                   '05' => 'Ehime',
                                   '26' => 'Nagano',
                                   '04' => 'Chiba',
                                   '17' => 'Kagawa',
                                   '02' => 'Akita',
                                   '18' => 'Kagoshima',
                                   '03' => 'Aomori',
                                   '30' => 'Oita',
                                   '06' => 'Fukui',
                                   '16' => 'Iwate',
                                   '44' => 'Yamagata',
                                   '27' => 'Nagasaki',
                                   '25' => 'Miyazaki',
                                   '01' => 'Aichi',
                                   '28' => 'Nara',
                                   '40' => 'Tokyo',
                                   '14' => 'Ibaraki',
                                   '20' => 'Kochi',
                                   '07' => 'Fukuoka',
                                   '24' => 'Miyagi',
                                   '10' => 'Gumma',
                                   '31' => 'Okayama',
                                   '35' => 'Shiga',
                                   '11' => 'Hiroshima',
                                   '42' => 'Toyama',
                                   '22' => 'Kyoto',
                                   '46' => 'Yamanashi',
                                   '08' => 'Fukushima',
                                   '23' => 'Mie',
                                   '13' => 'Hyogo',
                                   '29' => 'Niigata',
                                   '39' => 'Tokushima',
                                   '36' => 'Shimane',
                                   '12' => 'Hokkaido',
                                   '41' => 'Tottori',
                                   '15' => 'Ishikawa',
                                   '47' => 'Okinawa',
                                   '38' => 'Tochigi',
                                   '34' => 'Saitama',
                                   '37' => 'Shizuoka',
                                   '45' => 'Yamaguchi',
                                   '19' => 'Kanagawa',
                                   '43' => 'Wakayama',
                                   '09' => 'Gifu'
                         },
                         'NA' => {
                                   '32' => 'Kunene',
                                   '33' => 'Ohangwena',
                                   '21' => 'Windhoek',
                                   '05' => 'Grootfontein',
                                   '26' => 'Mariental',
                                   '04' => 'Gobabis',
                                   '17' => 'Swakopmund',
                                   '02' => 'Caprivi Oos',
                                   '18' => 'Tsumeb',
                                   '03' => 'Boesmanland',
                                   '30' => 'Hardap',
                                   '06' => 'Kaokoland',
                                   '16' => 'Rehoboth',
                                   '27' => 'Namaland',
                                   '25' => 'Kavango',
                                   '01' => 'Bethanien',
                                   '28' => 'Caprivi',
                                   '14' => 'Outjo',
                                   '20' => 'Karasburg',
                                   '07' => 'Karibib',
                                   '24' => 'Hereroland Wes',
                                   '10' => 'Maltahohe',
                                   '31' => 'Karas',
                                   '35' => 'Omaheke',
                                   '11' => 'Okahandja',
                                   '22' => 'Damaraland',
                                   '08' => 'Keetmanshoop',
                                   '13' => 'Otjiwarongo',
                                   '23' => 'Hereroland Oos',
                                   '29' => 'Erongo',
                                   '39' => 'Otjozondjupa',
                                   '36' => 'Omusati',
                                   '12' => 'Omaruru',
                                   '15' => 'Owambo',
                                   '38' => 'Oshikoto',
                                   '34' => 'Okavango',
                                   '37' => 'Oshana',
                                   '09' => 'Luderitz'
                         },
                         'SH' => {
                                   '01' => 'Ascension',
                                   '03' => 'Tristan da Cunha',
                                   '02' => 'Saint Helena'
                         },
                         'TJ' => {
                                   '01' => 'Kuhistoni Badakhshon',
                                   '03' => 'Sughd',
                                   '02' => 'Khatlon'
                         },
                         'LC' => {
                                   '11' => 'Praslin',
                                   '01' => 'Anse-la-Raye',
                                   '05' => 'Dennery',
                                   '04' => 'Choiseul',
                                   '02' => 'Dauphin',
                                   '07' => 'Laborie',
                                   '03' => 'Castries',
                                   '08' => 'Micoud',
                                   '06' => 'Gros-Islet',
                                   '10' => 'Vieux-Fort',
                                   '09' => 'Soufriere'
                         },
                         'MA' => {
                                   '32' => 'Tiznit',
                                   '33' => 'Guelmim',
                                   '21' => 'Nador',
                                   '05' => 'Beni Mellal',
                                   '26' => 'Settat',
                                   '04' => 'Ben Slimane',
                                   '17' => 'Khenifra',
                                   '02' => 'Al Hoceima',
                                   '18' => 'Khouribga',
                                   '03' => 'Azilal',
                                   '30' => 'Taza',
                                   '06' => 'Boulemane',
                                   '16' => 'Khemisset',
                                   '55' => 'Souss-Massa-Dr,a',
                                   '27' => 'Tanger',
                                   '25' => 'Safi',
                                   '01' => 'Agadir',
                                   '40' => 'Tetouan',
                                   '57' => 'Tanger-Tetouan',
                                   '14' => 'Figuig',
                                   '20' => 'Meknes',
                                   '07' => 'Casablanca',
                                   '59' => 'La,youne-Boujdour-Sakia El Hamra',
                                   '49' => 'Rabat-Sale-Zemmour-Zaer',
                                   '24' => 'Rabat-Sale',
                                   '10' => 'El Kelaa des Srarhna',
                                   '35' => 'Laayoune',
                                   '11' => 'Er Rachidia',
                                   '53' => 'Guelmim-Es Smara',
                                   '48' => 'Meknes-Tafilalet',
                                   '22' => 'Ouarzazate',
                                   '08' => 'Chaouen',
                                   '46' => 'Fes-Boulemane',
                                   '23' => 'Oujda',
                                   '13' => 'Fes',
                                   '29' => 'Tata',
                                   '50' => 'Chaouia-Ouardigha',
                                   '39' => 'Taroudannt',
                                   '36' => 'Tan-Tan',
                                   '51' => 'Doukkala-Abda',
                                   '12' => 'Essaouira',
                                   '41' => 'Larache',
                                   '58' => 'Taza-Al Hoceima-Taounate',
                                   '15' => 'Kenitra',
                                   '47' => 'Marrakech-Tensift-Al Haouz',
                                   '38' => 'Sidi Kacem',
                                   '52' => 'Gharb-Chrarda-Beni Hssen',
                                   '34' => 'Ifrane',
                                   '56' => 'Tadla-Azilal',
                                   '37' => 'Taounate',
                                   '45' => 'Grand Casablanca',
                                   '19' => 'Marrakech',
                                   '09' => 'El Jadida',
                                   '54' => 'Oriental'
                         },
                         'VU' => {
                                   '11' => 'Paama',
                                   '05' => 'Ambrym',
                                   '12' => 'Pentecote',
                                   '17' => 'Penama',
                                   '14' => 'Shepherd',
                                   '15' => 'Tafea',
                                   '07' => 'Torba',
                                   '18' => 'Shefa',
                                   '08' => 'Efate',
                                   '10' => 'Malakula',
                                   '06' => 'Aoba',
                                   '13' => 'Sanma',
                                   '16' => 'Malampa',
                                   '09' => 'Epi'
                         },
                         'SV' => {
                                   '11' => 'Santa Ana',
                                   '01' => 'Ahuachapan',
                                   '05' => 'La Libertad',
                                   '04' => 'Cuscatlan',
                                   '12' => 'San Vicente',
                                   '02' => 'Cabanas',
                                   '14' => 'Usulutan',
                                   '07' => 'La Union',
                                   '08' => 'Morazan',
                                   '03' => 'Chalatenango',
                                   '06' => 'La Paz',
                                   '10' => 'San Salvador',
                                   '13' => 'Sonsonate',
                                   '09' => 'San Miguel'
                         },
                         'MN' => {
                                   '11' => 'Hentiy',
                                   '21' => 'Bulgan',
                                   '05' => 'Darhan',
                                   '17' => 'Suhbaatar',
                                   '02' => 'Bayanhongor',
                                   '22' => 'Erdenet',
                                   '18' => 'Tov',
                                   '08' => 'Dundgovi',
                                   '03' => 'Bayan-Olgiy',
                                   '06' => 'Dornod',
                                   '13' => 'Hovsgol',
                                   '16' => 'Selenge',
                                   '23' => 'Darhan-Uul',
                                   '25' => 'Orhon',
                                   '01' => 'Arhangay',
                                   '12' => 'Hovd',
                                   '15' => 'Ovorhangay',
                                   '14' => 'Omnogovi',
                                   '20' => 'Ulaanbaatar',
                                   '07' => 'Dornogovi',
                                   '24' => 'Govisumber',
                                   '10' => 'Govi-Altay',
                                   '19' => 'Uvs',
                                   '09' => 'Dzavhan'
                         },
                         'IT' => {
                                   '11' => 'Molise',
                                   '05' => 'Emilia-Romagna',
                                   '04' => 'Campania',
                                   '17' => 'Trentino-Alto Adige',
                                   '02' => 'Basilicata',
                                   '18' => 'Umbria',
                                   '03' => 'Calabria',
                                   '08' => 'Liguria',
                                   '06' => 'Friuli-Venezia Giulia',
                                   '13' => 'Puglia',
                                   '16' => 'Toscana',
                                   '01' => 'Abruzzi',
                                   '12' => 'Piemonte',
                                   '20' => 'Veneto',
                                   '14' => 'Sardegna',
                                   '15' => 'Sicilia',
                                   '07' => 'Lazio',
                                   '10' => 'Marche',
                                   '19' => 'Valle d\'Aosta',
                                   '09' => 'Lombardia'
                         },
                         'WS' => {
                                   '11' => 'Vaisigano',
                                   '05' => 'Gaga',
                                   '04' => 'Fa',
                                   '02' => 'Aiga-i-le-Tai',
                                   '07' => 'Gagaifomauga',
                                   '03' => 'Atua',
                                   '08' => 'Palauli',
                                   '10' => 'Tuamasaga',
                                   '06' => 'Va',
                                   '09' => 'Satupa'
                         },
                         'FR' => {
                                   'A1' => 'Bourgogne',
                                   'B4' => 'Nord-Pas-de-Calais',
                                   'A2' => 'Bretagne',
                                   'B6' => 'Picardie',
                                   'C1' => 'Alsace',
                                   '99' => 'Basse-Normandie',
                                   'A8' => 'Ile-de-France',
                                   'B2' => 'Lorraine',
                                   'B8' => 'Provence-Alpes-Cote d\'Azur',
                                   'A7' => 'Haute-Normandie',
                                   'B5' => 'Pays de la Loire',
                                   'B1' => 'Limousin',
                                   'A6' => 'Franche-Comte',
                                   '97' => 'Aquitaine',
                                   'A5' => 'Corse',
                                   'A4' => 'Champagne-Ardenne',
                                   'B7' => 'Poitou-Charentes',
                                   '98' => 'Auvergne',
                                   'A3' => 'Centre',
                                   'B9' => 'Rhone-Alpes',
                                   'B3' => 'Midi-Pyrenees',
                                   'A9' => 'Languedoc-Roussillon'
                         },
                         'EG' => {
                                   '11' => 'Al Qahirah',
                                   '21' => 'Kafr ash Shaykh',
                                   '05' => 'Al Gharbiyah',
                                   '26' => 'Janub Sina\'',
                                   '04' => 'Al Fayyum',
                                   '17' => 'Asyut',
                                   '02' => 'Al Bahr al Ahmar',
                                   '22' => 'Matruh',
                                   '18' => 'Bani Suwayf',
                                   '08' => 'Al Jizah',
                                   '03' => 'Al Buhayrah',
                                   '06' => 'Al Iskandariyah',
                                   '13' => 'Al Wadi al Jadid',
                                   '16' => 'Aswan',
                                   '23' => 'Qina',
                                   '27' => 'Shamal Sina\'',
                                   '01' => 'Ad Daqahliyah',
                                   '12' => 'Al Qalyubiyah',
                                   '15' => 'As Suways',
                                   '14' => 'Ash Sharqiyah',
                                   '20' => 'Dumyat',
                                   '07' => 'Al Isma\'iliyah',
                                   '24' => 'Suhaj',
                                   '10' => 'Al Minya',
                                   '19' => 'Bur Sa\'id',
                                   '09' => 'Al Minufiyah'
                         },
                         'UZ' => {
                                   '11' => 'Sirdaryo',
                                   '01' => 'Andijon',
                                   '05' => 'Khorazm',
                                   '04' => 'Jizzakh',
                                   '12' => 'Surkhondaryo',
                                   '02' => 'Bukhoro',
                                   '14' => 'Toshkent',
                                   '07' => 'Nawoiy',
                                   '08' => 'Qashqadaryo',
                                   '03' => 'Farghona',
                                   '06' => 'Namangan',
                                   '10' => 'Samarqand',
                                   '13' => 'Toshkent',
                                   '09' => 'Qoraqalpoghiston'
                         },
                         'LR' => {
                                   '11' => 'Grand Bassa',
                                   '01' => 'Bong',
                                   '04' => 'Grand Cape Mount',
                                   '14' => 'Montserrado',
                                   '20' => 'Lofa',
                                   '07' => 'Monrovia',
                                   '19' => 'Grand Gedeh',
                                   '06' => 'Maryland',
                                   '10' => 'Sino',
                                   '09' => 'Nimba'
                         },
                         'RW' => {
                                   '11' => 'Est',
                                   '01' => 'Butare',
                                   '12' => 'Kigali',
                                   '14' => 'Ouest',
                                   '15' => 'Sud',
                                   '13' => 'Nord',
                                   '06' => 'Gitarama',
                                   '09' => 'Kigali'
                         },
                         'TN' => {
                                   '35' => 'Tawzar',
                                   '32' => 'Safaqis',
                                   '33' => 'Sidi Bu Zayd',
                                   '17' => 'Bajah',
                                   '02' => 'Al Qasrayn',
                                   '22' => 'Silyanah',
                                   '18' => 'Banzart',
                                   '03' => 'Al Qayrawan',
                                   '30' => 'Qafşah',
                                   '16' => 'Al Munastir',
                                   '23' => 'Susah',
                                   '06' => 'Jundubah',
                                   '29' => 'Qabis',
                                   '27' => 'Bin',
                                   '39' => 'Manouba',
                                   '28' => 'Madanin',
                                   '36' => 'Tunis',
                                   '15' => 'Al Mahdiyah',
                                   '14' => 'Kef',
                                   '38' => 'Ariana',
                                   '34' => 'Tatawin',
                                   '37' => 'Zaghwan',
                                   '10' => 'Qafsah',
                                   '19' => 'Nabul',
                                   '31' => 'Qibili'
                         },
                         'BE' => {
                                   '11' => 'Brussels Hoofdstedelijk Gewest',
                                   '01' => 'Antwerpen',
                                   '05' => 'Limburg',
                                   '04' => 'Liege',
                                   '12' => 'Vlaams-Brabant',
                                   '02' => 'Brabant',
                                   '07' => 'Namur',
                                   '08' => 'Oost-Vlaanderen',
                                   '03' => 'Hainaut',
                                   '06' => 'Luxembourg',
                                   '10' => 'Brabant Wallon',
                                   '09' => 'West-Vlaanderen'
                         },
                         'EE' => {
                                   '11' => 'Parnumaa',
                                   '21' => 'Vorumaa',
                                   '05' => 'Jogevamaa',
                                   '04' => 'Jarvamaa',
                                   '17' => 'Tartu',
                                   '02' => 'Hiiumaa',
                                   '18' => 'Tartumaa',
                                   '08' => 'Laane-Virumaa',
                                   '03' => 'Ida-Virumaa',
                                   '06' => 'Kohtla-Jarve',
                                   '13' => 'Raplamaa',
                                   '16' => 'Tallinn',
                                   '01' => 'Harjumaa',
                                   '12' => 'Polvamaa',
                                   '15' => 'Sillamae',
                                   '20' => 'Viljandimaa',
                                   '14' => 'Saaremaa',
                                   '07' => 'Laanemaa',
                                   '10' => 'Parnu',
                                   '19' => 'Valgamaa',
                                   '09' => 'Narva'
                         },
                         'BY' => {
                                   '07' => 'Vitsyebskaya Voblasts\'',
                                   '01' => 'Brestskaya Voblasts\'',
                                   '03' => 'Hrodzyenskaya Voblasts\'',
                                   '05' => 'Minskaya Voblasts\'',
                                   '06' => 'Mahilyowskaya Voblasts\'',
                                   '04' => 'Minsk',
                                   '02' => 'Homyel\'skaya Voblasts\''
                         },
                         'SA' => {
                                   '05' => 'Al Madinah',
                                   '17' => 'Jizan',
                                   '02' => 'Al Bahah',
                                   '14' => 'Makkah',
                                   '15' => 'Al Hudud ash Shamaliyah',
                                   '20' => 'Al Jawf',
                                   '03' => 'Al Jawf',
                                   '08' => 'Al Qasim',
                                   '13' => 'Ha\'il',
                                   '10' => 'Ar Riyad',
                                   '06' => 'Ash Sharqiyah',
                                   '16' => 'Najran',
                                   '19' => 'Tabuk',
                                   '09' => 'Al Qurayyat'
                         },
                         'NO' => {
                                   '11' => 'Oppland',
                                   '05' => 'Finnmark',
                                   '04' => 'Buskerud',
                                   '17' => 'Telemark',
                                   '02' => 'Aust-Agder',
                                   '18' => 'Troms',
                                   '08' => 'More og Romsdal',
                                   '06' => 'Hedmark',
                                   '16' => 'Sor-Trondelag',
                                   '13' => 'Ostfold',
                                   '01' => 'Akershus',
                                   '12' => 'Oslo',
                                   '20' => 'Vestfold',
                                   '14' => 'Rogaland',
                                   '15' => 'Sogn og Fjordane',
                                   '07' => 'Hordaland',
                                   '10' => 'Nord-Trondelag',
                                   '19' => 'Vest-Agder',
                                   '09' => 'Nordland'
                         },
                         'LS' => {
                                   '11' => 'Butha-Buthe',
                                   '12' => 'Leribe',
                                   '17' => 'Qachas Nek',
                                   '14' => 'Maseru',
                                   '15' => 'Mohales Hoek',
                                   '18' => 'Quthing',
                                   '16' => 'Mokhotlong',
                                   '13' => 'Mafeteng',
                                   '19' => 'Thaba-Tseka',
                                   '10' => 'Berea'
                         },
                         'KR' => {
                                   '11' => 'Seoul-t\'ukpyolsi',
                                   '21' => 'Ulsan-gwangyoksi',
                                   '05' => 'Ch\'ungch\'ong-bukto',
                                   '17' => 'Ch\'ungch\'ong-namdo',
                                   '18' => 'Kwangju-jikhalsi',
                                   '03' => 'Cholla-bukto',
                                   '13' => 'Kyonggi-do',
                                   '16' => 'Cholla-namdo',
                                   '06' => 'Kangwon-do',
                                   '01' => 'Cheju-do',
                                   '12' => 'Inch\'on-jikhalsi',
                                   '14' => 'Kyongsang-bukto',
                                   '15' => 'Taegu-jikhalsi',
                                   '20' => 'Kyongsang-namdo',
                                   '10' => 'Pusan-jikhalsi',
                                   '19' => 'Taejon-jikhalsi'
                         },
                         'ZA' => {
                                   '11' => 'Western Cape',
                                   '05' => 'Eastern Cape',
                                   '02' => 'KwaZulu-Natal',
                                   '07' => 'Mpumalanga',
                                   '03' => 'Free State',
                                   '08' => 'Northern Cape',
                                   '06' => 'Gauteng',
                                   '10' => 'North-West',
                                   '09' => 'Limpopo'
                         },
                         'PT' => {
                                   '11' => 'Guarda',
                                   '21' => 'Vila Real',
                                   '05' => 'Braganca',
                                   '04' => 'Braga',
                                   '17' => 'Porto',
                                   '02' => 'Aveiro',
                                   '22' => 'Viseu',
                                   '18' => 'Santarem',
                                   '08' => 'Evora',
                                   '03' => 'Beja',
                                   '06' => 'Castelo Branco',
                                   '13' => 'Leiria',
                                   '16' => 'Portalegre',
                                   '23' => 'Azores',
                                   '20' => 'Viana do Castelo',
                                   '14' => 'Lisboa',
                                   '07' => 'Coimbra',
                                   '19' => 'Setubal',
                                   '10' => 'Madeira',
                                   '09' => 'Faro'
                         },
                         'BF' => {
                                   '33' => 'Oudalan',
                                   '67' => 'Noumbiel',
                                   '21' => 'Gnagna',
                                   '63' => 'Mouhoun',
                                   '70' => 'Sanmatenga',
                                   '71' => 'Seno',
                                   '68' => 'Oubritenga',
                                   '72' => 'Sissili',
                                   '44' => 'Zoundweogo',
                                   '55' => 'Komoe',
                                   '74' => 'Tuy',
                                   '28' => 'Kouritenga',
                                   '75' => 'Yagha',
                                   '57' => 'Kompienga',
                                   '40' => 'Soum',
                                   '61' => 'Leraba',
                                   '20' => 'Ganzourgou',
                                   '69' => 'Poni',
                                   '59' => 'Koulpelogo',
                                   '49' => 'Boulgou',
                                   '53' => 'Kadiogo',
                                   '78' => 'Zondoma',
                                   '48' => 'Bougouriba',
                                   '42' => 'Tapoa',
                                   '77' => 'Ziro',
                                   '46' => 'Banwa',
                                   '65' => 'Naouri',
                                   '50' => 'Gourma',
                                   '36' => 'Sanguie',
                                   '64' => 'Namentenga',
                                   '51' => 'Houet',
                                   '58' => 'Kossi',
                                   '15' => 'Bam',
                                   '47' => 'Bazega',
                                   '52' => 'Ioba',
                                   '60' => 'Kourweogo',
                                   '34' => 'Passore',
                                   '56' => 'Komondjari',
                                   '45' => 'Bale',
                                   '66' => 'Nayala',
                                   '73' => 'Sourou',
                                   '19' => 'Boulkiemde',
                                   '76' => 'Yatenga',
                                   '62' => 'Loroum',
                                   '54' => 'Kenedougou'
                         },
                         'CA' => {
                                   'NT' => 'Northwest Territories',
                                   'BC' => 'British Columbia',
                                   'NL' => 'Newfoundland',
                                   'MB' => 'Manitoba',
                                   'NS' => 'Nova Scotia',
                                   'ON' => 'Ontario',
                                   'QC' => 'Quebec',
                                   'YT' => 'Yukon Territory',
                                   'NU' => 'Nunavut',
                                   'PE' => 'Prince Edward Island',
                                   'NB' => 'New Brunswick',
                                   'SK' => 'Saskatchewan',
                                   'AB' => 'Alberta'
                         },
                         'AM' => {
                                   '11' => 'Yerevan',
                                   '01' => 'Aragatsotn',
                                   '05' => 'Kotayk\'',
                                   '04' => 'Geghark\'unik\'',
                                   '02' => 'Ararat',
                                   '07' => 'Shirak',
                                   '03' => 'Armavir',
                                   '08' => 'Syunik\'',
                                   '06' => 'Lorri',
                                   '10' => 'Vayots\' Dzor',
                                   '09' => 'Tavush'
                         },
                         'CM' => {
                                   '11' => 'Centre',
                                   '05' => 'Littoral',
                                   '04' => 'Est',
                                   '12' => 'Extreme-Nord',
                                   '14' => 'Sud',
                                   '07' => 'Nord-Ouest',
                                   '08' => 'Ouest',
                                   '13' => 'Nord',
                                   '10' => 'Adamaoua',
                                   '09' => 'Sud-Ouest'
                         },
                         'SR' => {
                                   '11' => 'Commewijne',
                                   '12' => 'Coronie',
                                   '17' => 'Saramacca',
                                   '14' => 'Nickerie',
                                   '15' => 'Para',
                                   '18' => 'Sipaliwini',
                                   '16' => 'Paramaribo',
                                   '13' => 'Marowijne',
                                   '19' => 'Wanica',
                                   '10' => 'Brokopondo'
                         },
                         'MG' => {
                                   '01' => 'Antsiranana',
                                   '03' => 'Mahajanga',
                                   '05' => 'Antananarivo',
                                   '06' => 'Toliara',
                                   '04' => 'Toamasina',
                                   '02' => 'Fianarantsoa'
                         },
                         'NP' => {
                                   '11' => 'Narayani',
                                   '01' => 'Bagmati',
                                   '05' => 'Janakpur',
                                   '04' => 'Gandaki',
                                   '12' => 'Rapti',
                                   '02' => 'Bheri',
                                   '14' => 'Seti',
                                   '07' => 'Kosi',
                                   '08' => 'Lumbini',
                                   '03' => 'Dhawalagiri',
                                   '06' => 'Karnali',
                                   '10' => 'Mechi',
                                   '13' => 'Sagarmatha',
                                   '09' => 'Mahakali'
                         },
                         'BT' => {
                                   '11' => 'Lhuntshi',
                                   '21' => 'Tongsa',
                                   '05' => 'Bumthang',
                                   '17' => 'Samdrup',
                                   '22' => 'Wangdi Phodrang',
                                   '18' => 'Shemgang',
                                   '08' => 'Daga',
                                   '06' => 'Chhukha',
                                   '16' => 'Samchi',
                                   '13' => 'Paro',
                                   '12' => 'Mongar',
                                   '14' => 'Pemagatsel',
                                   '15' => 'Punakha',
                                   '20' => 'Thimphu',
                                   '07' => 'Chirang',
                                   '19' => 'Tashigang',
                                   '10' => 'Ha',
                                   '09' => 'Geylegphug'
                         },
                         'PL' => {
                                   '32' => 'Gorzow',
                                   '33' => 'Jelenia Gora',
                                   '63' => 'Tarnobrzeg',
                                   '71' => 'Zielona Gora',
                                   '26' => 'Bydgoszcz',
                                   '80' => 'Podkarpackie',
                                   '72' => 'Dolnoslaskie',
                                   '44' => 'Lomza',
                                   '55' => 'Radom',
                                   '84' => 'Swietokrzyskie',
                                   '74' => 'Lodzkie',
                                   '27' => 'Chelm',
                                   '57' => 'Siedlce',
                                   '61' => 'Suwalki',
                                   '31' => 'Gdansk',
                                   '35' => 'Katowice',
                                   '78' => 'Mazowieckie',
                                   '48' => 'Opole',
                                   '87' => 'Zachodniopomorskie',
                                   '77' => 'Malopolskie',
                                   '65' => 'Torun',
                                   '29' => 'Czestochowa',
                                   '50' => 'Pila',
                                   '39' => 'Krakow',
                                   '64' => 'Tarnow',
                                   '58' => 'Sieradz',
                                   '41' => 'Legnica',
                                   '81' => 'Podlaskie',
                                   '52' => 'Plock',
                                   '60' => 'Slupsk',
                                   '56' => 'Rzeszow',
                                   '45' => 'Lublin',
                                   '73' => 'Kujawsko-Pomorskie',
                                   '66' => 'Walbrzych',
                                   '76' => 'Lubuskie',
                                   '86' => 'Wielkopolskie',
                                   '62' => 'Szczecin',
                                   '54' => 'Przemysl',
                                   '67' => 'Warszawa',
                                   '70' => 'Zamosc',
                                   '68' => 'Wloclawek',
                                   '30' => 'Elblag',
                                   '82' => 'Pomorskie',
                                   '25' => 'Bielsko',
                                   '28' => 'Ciechanow',
                                   '40' => 'Krosno',
                                   '75' => 'Lubelskie',
                                   '83' => 'Slaskie',
                                   '59' => 'Skierniewice',
                                   '69' => 'Wroclaw',
                                   '49' => 'Ostroleka',
                                   '24' => 'Bialystok',
                                   '53' => 'Poznan',
                                   '79' => 'Opolskie',
                                   '42' => 'Leszno',
                                   '46' => 'Nowy Sacz',
                                   '23' => 'Biala Podlaska',
                                   '85' => 'Warminsko-Mazurskie',
                                   '36' => 'Kielce',
                                   '51' => 'Piotrkow',
                                   '47' => 'Olsztyn',
                                   '38' => 'Koszalin',
                                   '34' => 'Kalisz',
                                   '37' => 'Konin',
                                   '43' => 'Lodz'
                         },
                         'TM' => {
                                   '01' => 'Ahal',
                                   '03' => 'Dashoguz',
                                   '05' => 'Mary',
                                   '04' => 'Lebap',
                                   '02' => 'Balkan'
                         },
                         'GA' => {
                                   '01' => 'Estuaire',
                                   '05' => 'Nyanga',
                                   '04' => 'Ngounie',
                                   '02' => 'Haut-Ogooue',
                                   '07' => 'Ogooue-Lolo',
                                   '03' => 'Moyen-Ogooue',
                                   '08' => 'Ogooue-Maritime',
                                   '06' => 'Ogooue-Ivindo',
                                   '09' => 'Woleu-Ntem'
                         },
                         'CF' => {
                                   '11' => 'Ouaka',
                                   '01' => 'Bamingui-Bangoran',
                                   '05' => 'Haut-Mbomou',
                                   '12' => 'Ouham',
                                   '04' => 'Mambere-Kadei',
                                   '17' => 'Ombella-Mpoko',
                                   '15' => 'Nana-Grebizi',
                                   '14' => 'Cuvette-Ouest',
                                   '02' => 'Basse-Kotto',
                                   '07' => 'Lobaye',
                                   '18' => 'Bangui',
                                   '03' => 'Haute-Kotto',
                                   '08' => 'Mbomou',
                                   '06' => 'Kemo',
                                   '13' => 'Ouham-Pende',
                                   '16' => 'Sangha-Mbaere',
                                   '09' => 'Nana-Mambere'
                         },
                         'BA' => {
                                 '01' => 'Federation of Bosnia and Herzegovina',
                                 '02' => 'Republika Srpska'
                         },
                         'AE' => {
                                   '07' => 'Umm Al Quwain',
                                   '01' => 'Abu Dhabi',
                                   '03' => 'Dubai',
                                   '05' => 'Ras Al Khaimah',
                                   '06' => 'Sharjah',
                                   '04' => 'Fujairah',
                                   '02' => 'Ajman'
                         },
                         'TH' => {
                                   '32' => 'Chai Nat',
                                   '33' => 'Sing Buri',
                                   '21' => 'Nakhon Phanom',
                                   '63' => 'Krabi',
                                   '71' => 'Ubon Ratchathani',
                                   '26' => 'Chaiyaphum',
                                   '02' => 'Chiang Mai',
                                   '18' => 'Loei',
                                   '03' => 'Chiang Rai',
                                   '72' => 'Yasothon',
                                   '16' => 'Nakhon Sawan',
                                   '44' => 'Chachoengsao',
                                   '55' => 'Samut Sakhon',
                                   '27' => 'Nakhon Ratchasima',
                                   '01' => 'Mae Hong Son',
                                   '57' => 'Prachuap Khiri Khan',
                                   '61' => 'Phangnga',
                                   '20' => 'Sakon Nakhon',
                                   '10' => 'Uttaradit',
                                   '31' => 'Narathiwat',
                                   '35' => 'Ang Thong',
                                   '11' => 'Kamphaeng Phet',
                                   '78' => 'Mukdahan',
                                   '48' => 'Chanthaburi',
                                   '08' => 'Tak',
                                   '65' => 'Trang',
                                   '29' => 'Surin',
                                   '50' => 'Kanchanaburi',
                                   '39' => 'Pathum Thani',
                                   '64' => 'Nakhon Si Thammarat',
                                   '12' => 'Phitsanulok',
                                   '58' => 'Chumphon',
                                   '41' => 'Phayao',
                                   '15' => 'Uthai Thani',
                                   '52' => 'Ratchaburi',
                                   '60' => 'Surat Thani',
                                   '56' => 'Phetchaburi',
                                   '45' => 'Prachin Buri',
                                   '66' => 'Phatthalung',
                                   '76' => 'Udon Thani',
                                   '09' => 'Sukhothai',
                                   '62' => 'Phuket',
                                   '54' => 'Samut Songkhram',
                                   '67' => 'Satun',
                                   '70' => 'Yala',
                                   '05' => 'Lamphun',
                                   '68' => 'Songkhla',
                                   '04' => 'Nan',
                                   '17' => 'Nong Khai',
                                   '30' => 'Sisaket',
                                   '06' => 'Lampang',
                                   '25' => 'Roi Et',
                                   '28' => 'Buriram',
                                   '75' => 'Ubon Ratchathani',
                                   '40' => 'Krung Thep',
                                   '14' => 'Phetchabun',
                                   '69' => 'Pattani',
                                   '07' => 'Phrae',
                                   '59' => 'Ranong',
                                   '49' => 'Trat',
                                   '24' => 'Maha Sarakham',
                                   '53' => 'Nakhon Pathom',
                                   '22' => 'Khon Kaen',
                                   '42' => 'Samut Prakan',
                                   '46' => 'Chon Buri',
                                   '13' => 'Phichit',
                                   '23' => 'Kalasin',
                                   '36' => 'Phra Nakhon Si Ayutthaya',
                                   '51' => 'Suphan Buri',
                                   '47' => 'Rayong',
                                   '38' => 'Nonthaburi',
                                   '34' => 'Lop Buri',
                                   '37' => 'Saraburi',
                                   '43' => 'Nakhon Nayok'
                         },
                         'KY' => {
                                   '07' => 'West End',
                                   '01' => 'Creek',
                                   '08' => 'Western',
                                   '03' => 'Midland',
                                   '05' => 'Spot Bay',
                                   '06' => 'Stake Bay',
                                   '04' => 'South Town',
                                   '02' => 'Eastern'
                         },
                         'LA' => {
                                   '11' => 'Vientiane',
                                   '01' => 'Attapu',
                                   '05' => 'Louang Namtha',
                                   '04' => 'Khammouan',
                                   '17' => 'Louangphrabang',
                                   '02' => 'Champasak',
                                   '14' => 'Xiangkhoang',
                                   '07' => 'Oudomxai',
                                   '08' => 'Phongsali',
                                   '03' => 'Houaphan',
                                   '10' => 'Savannakhet',
                                   '13' => 'Xaignabouri',
                                   '09' => 'Saravan'
                         },
                         'PH' => {
                                   '32' => 'Kalinga-Apayao',
                                   '71' => 'Sultan Kudarat',
                                   'B6' => 'Cavite City',
                                   '02' => 'Agusan del Norte',
                                   'C1' => 'Danao',
                                   'E8' => 'Palayan',
                                   '18' => 'Capiz',
                                   '16' => 'Camarines Sur',
                                   '44' => 'Mountain',
                                   'C8' => 'Iligan',
                                   '55' => 'Samar',
                                   'H3' => 'Negros Occidental',
                                   '27' => 'Ifugao',
                                   'E7' => 'Pagadian',
                                   'B1' => 'Cadiz',
                                   '57' => 'North Cotabato',
                                   '20' => 'Cavite',
                                   'F3' => 'Roxas',
                                   '31' => 'Isabela',
                                   'G6' => 'Trece Martires',
                                   '35' => 'Lanao del Sur',
                                   '11' => 'Bohol',
                                   '65' => 'Zamboanga del Norte',
                                   '29' => 'Ilocos Sur',
                                   'E3' => 'Olongapo',
                                   '58' => 'Sorsogon',
                                   '15' => 'Camarines Norte',
                                   'F6' => 'San Jose',
                                   'D7' => 'Lucena',
                                   '60' => 'Sulu',
                                   'B3' => 'Calbayog',
                                   '09' => 'Batangas',
                                   '62' => 'Surigao del Sur',
                                   '67' => 'Northern Samar',
                                   'A1' => 'Angeles',
                                   '05' => 'Albay',
                                   '17' => 'Camiguin',
                                   'G2' => 'Tagaytay',
                                   'F7' => 'San Pablo',
                                   'E4' => 'Ormoc',
                                   'C5' => 'Dumaguete',
                                   'H2' => 'Quezon',
                                   '14' => 'Cagayan',
                                   '69' => 'Siquijor',
                                   '07' => 'Bataan',
                                   'F9' => 'Surigao',
                                   'A3' => 'Bago',
                                   '49' => 'Palawan',
                                   '24' => 'Davao',
                                   'G8' => 'Aurora',
                                   'D2' => 'La Carlota',
                                   'B8' => 'Cotabato',
                                   '23' => 'Eastern Samar',
                                   'B5' => 'Canlaon',
                                   'A6' => 'Basilan City',
                                   'C7' => 'Gingoog',
                                   'D4' => 'Lapu-Lapu',
                                   'D1' => 'Iriga',
                                   'A4' => 'Baguio',
                                   'G4' => 'Tangub',
                                   '47' => 'Nueva Ecija',
                                   'F5' => 'San Carlos',
                                   '37' => 'Leyte',
                                   '43' => 'Misamis Oriental',
                                   'A9' => 'Cabanatuan',
                                   '33' => 'Laguna',
                                   '21' => 'Cebu',
                                   '63' => 'Tarlac',
                                   '26' => 'Davao Oriental',
                                   '03' => 'Agusan del Sur',
                                   '72' => 'Tawitawi',
                                   'E9' => 'Pasay',
                                   'G7' => 'Zamboanga',
                                   'C2' => 'Dapitan',
                                   '01' => 'Abra',
                                   'F8' => 'Silay',
                                   '61' => 'Surigao del Norte',
                                   'E6' => 'Ozamis',
                                   'E2' => 'Naga',
                                   '10' => 'Benguet',
                                   'D6' => 'Lipa',
                                   '48' => 'Nueva Vizcaya',
                                   '08' => 'Batanes',
                                   'F2' => 'Quezon City',
                                   'D8' => 'Mandaue',
                                   '50' => 'Pampanga',
                                   '39' => 'Masbate',
                                   '64' => 'Zambales',
                                   '12' => 'Bukidnon',
                                   '41' => 'Mindoro Oriental',
                                   'B7' => 'Cebu City',
                                   '56' => 'Maguindanao',
                                   '66' => 'Zamboanga del Sur',
                                   '19' => 'Catanduanes',
                                   '54' => 'Romblon',
                                   'G1' => 'Tacloban',
                                   '70' => 'South Cotabato',
                                   'B4' => 'Caloocan',
                                   '68' => 'Quirino',
                                   'A2' => 'Bacolod',
                                   'G3' => 'Tagbilaran',
                                   '04' => 'Aklan',
                                   'D5' => 'Legaspi',
                                   'A8' => 'Butuan',
                                   '30' => 'Iloilo',
                                   '06' => 'Antique',
                                   '25' => 'Davao del Sur',
                                   'C6' => 'General Santos',
                                   '28' => 'Ilocos Norte',
                                   'D9' => 'Manila',
                                   '40' => 'Mindoro Occidental',
                                   'C4' => 'Dipolog',
                                   '59' => 'Southern Leyte',
                                   'F1' => 'Puerto Princesa',
                                   'C9' => 'Iloilo City',
                                   'F4' => 'San Carlos',
                                   '53' => 'Rizal',
                                   'D3' => 'Laoag',
                                   'E1' => 'Marawi',
                                   '42' => 'Misamis Occidental',
                                   '22' => 'Basilan',
                                   '46' => 'Negros Oriental',
                                   '13' => 'Bulacan',
                                   'B2' => 'Cagayan de Oro',
                                   'A7' => 'Batangas City',
                                   'G5' => 'Toledo',
                                   '36' => 'La Union',
                                   'A5' => 'Bais',
                                   '51' => 'Pangasinan',
                                   '38' => 'Marinduque',
                                   'B9' => 'Dagupan',
                                   'C3' => 'Davao City',
                                   '34' => 'Lanao del Norte',
                                   'E5' => 'Oroquieta'
                         },
                         'NI' => {
                                   '11' => 'Masaya',
                                   '01' => 'Boaco',
                                   '05' => 'Esteli',
                                   '12' => 'Matagalpa',
                                   '04' => 'Chontales',
                                   '15' => 'Rivas',
                                   '14' => 'Rio San Juan',
                                   '02' => 'Carazo',
                                   '07' => 'Jinotega',
                                   '03' => 'Chinandega',
                                   '08' => 'Leon',
                                   '10' => 'Managua',
                                   '06' => 'Granada',
                                   '16' => 'Zelaya',
                                   '13' => 'Nueva Segovia',
                                   '09' => 'Madriz'
                         },
                         'KZ' => {
                                   '11' => 'Pavlodar',
                                   '05' => 'Astana',
                                   '04' => 'Aqtobe',
                                   '17' => 'Zhambyl',
                                   '02' => 'Almaty City',
                                   '03' => 'Aqmola',
                                   '08' => 'Bayqonyr',
                                   '06' => 'Atyrau',
                                   '16' => 'North Kazakhstan',
                                   '13' => 'Qostanay',
                                   '01' => 'Almaty',
                                   '12' => 'Qaraghandy',
                                   '14' => 'Qyzylorda',
                                   '15' => 'East Kazakhstan',
                                   '07' => 'West Kazakhstan',
                                   '10' => 'South Kazakhstan',
                                   '09' => 'Mangghystau'
                         },
                         'MM' => {
                                   '11' => 'Shan State',
                                   '01' => 'Rakhine State',
                                   '05' => 'Karan State',
                                   '04' => 'Kachin State',
                                   '12' => 'Tenasserim',
                                   '17' => 'Yangon',
                                   '02' => 'Chin State',
                                   '14' => 'Rangoon',
                                   '07' => 'Magwe',
                                   '08' => 'Mandalay',
                                   '03' => 'Irrawaddy',
                                   '06' => 'Kayah State',
                                   '10' => 'Sagaing',
                                   '13' => 'Mon State',
                                   '09' => 'Pegu'
                         },
                         'NR' => {
                                   '11' => 'Meneng',
                                   '01' => 'Aiwo',
                                   '05' => 'Baiti',
                                   '04' => 'Anibare',
                                   '12' => 'Nibok',
                                   '02' => 'Anabar',
                                   '14' => 'Yaren',
                                   '07' => 'Buada',
                                   '08' => 'Denigomodu',
                                   '03' => 'Anetan',
                                   '06' => 'Boe',
                                   '10' => 'Ijuw',
                                   '13' => 'Uaboe',
                                   '09' => 'Ewa'
                         },
                         'NE' => {
                                   '07' => 'Zinder',
                                   '01' => 'Agadez',
                                   '08' => 'Niamey',
                                   '03' => 'Dosso',
                                   '05' => 'Niamey',
                                   '06' => 'Tahoua',
                                   '04' => 'Maradi',
                                   '02' => 'Diffa'
                         },
                         'DM' => {
                                   '11' => 'Saint Peter',
                                   '05' => 'Saint John',
                                   '04' => 'Saint George',
                                   '02' => 'Saint Andrew',
                                   '07' => 'Saint Luke',
                                   '03' => 'Saint David',
                                   '08' => 'Saint Mark',
                                   '10' => 'Saint Paul',
                                   '06' => 'Saint Joseph',
                                   '09' => 'Saint Patrick'
                         },
                         'TO' => {
                                   '01' => 'Ha',
                                   '03' => 'Vava',
                                   '02' => 'Tongatapu'
                         },
                         'MR' => {
                                   '11' => 'Tiris Zemmour',
                                   '01' => 'Hodh Ech Chargui',
                                   '05' => 'Brakna',
                                   '04' => 'Gorgol',
                                   '12' => 'Inchiri',
                                   '02' => 'Hodh El Gharbi',
                                   '07' => 'Adrar',
                                   '08' => 'Dakhlet Nouadhibou',
                                   '03' => 'Assaba',
                                   '06' => 'Trarza',
                                   '10' => 'Guidimaka',
                                   '09' => 'Tagant'
                         },
                         'AD' => {
                                   '07' => 'Andorra la Vella',
                                   '03' => 'Encamp',
                                   '05' => 'Ordino',
                                   '08' => 'Escaldes-Engordany',
                                   '06' => 'Sant Julia de Loria',
                                   '04' => 'La Massana',
                                   '02' => 'Canillo'
                         },
                         'SE' => {
                                   '11' => 'Kristianstads Lan',
                                   '21' => 'Uppsala Lan',
                                   '05' => 'Gotlands Lan',
                                   '26' => 'Stockholms Lan',
                                   '04' => 'Goteborgs och Bohus Lan',
                                   '17' => 'Skaraborgs Lan',
                                   '02' => 'Blekinge Lan',
                                   '22' => 'Varmlands Lan',
                                   '18' => 'Sodermanlands Lan',
                                   '08' => 'Jonkopings Lan',
                                   '03' => 'Gavleborgs Lan',
                                   '06' => 'Hallands Lan',
                                   '13' => 'Malmohus Lan',
                                   '16' => 'Ostergotlands Lan',
                                   '23' => 'Vasterbottens Lan',
                                   '27' => 'Skane Lan',
                                   '25' => 'Vastmanlands Lan',
                                   '01' => 'Alvsborgs Lan',
                                   '28' => 'Vastra Gotaland',
                                   '12' => 'Kronobergs Lan',
                                   '15' => 'Orebro Lan',
                                   '14' => 'Norrbottens Lan',
                                   '07' => 'Jamtlands Lan',
                                   '24' => 'Vasternorrlands Lan',
                                   '10' => 'Dalarnas Lan',
                                   '09' => 'Kalmar Lan'
                         },
                         'AZ' => {
                                   '32' => 'Masalli',
                                   '33' => 'Mingacevir',
                                   '21' => 'Goranboy',
                                   '63' => 'Xizi',
                                   '71' => 'Zardab',
                                   '26' => 'Kalbacar',
                                   '02' => 'Agcabadi',
                                   '18' => 'Fuzuli',
                                   '03' => 'Agdam',
                                   '16' => 'Daskasan',
                                   '44' => 'Qusar',
                                   '55' => 'Susa',
                                   '27' => 'Kurdamir',
                                   '01' => 'Abseron',
                                   '57' => 'Tartar',
                                   '61' => 'Xankandi',
                                   '20' => 'Ganca',
                                   '10' => 'Balakan',
                                   '31' => 'Lerik',
                                   '35' => 'Naxcivan',
                                   '11' => 'Barda',
                                   '48' => 'Saki',
                                   '08' => 'Astara',
                                   '65' => 'Xocavand',
                                   '29' => 'Lankaran',
                                   '50' => 'Samaxi',
                                   '39' => 'Qax',
                                   '64' => 'Xocali',
                                   '58' => 'Tovuz',
                                   '41' => 'Qobustan',
                                   '12' => 'Beylaqan',
                                   '15' => 'Calilabad',
                                   '52' => 'Samux',
                                   '60' => 'Xacmaz',
                                   '56' => 'Susa',
                                   '45' => 'Saatli',
                                   '66' => 'Yardimli',
                                   '19' => 'Gadabay',
                                   '09' => 'Baki',
                                   '62' => 'Xanlar',
                                   '54' => 'Sumqayit',
                                   '67' => 'Yevlax',
                                   '70' => 'Zaqatala',
                                   '05' => 'Agstafa',
                                   '68' => 'Yevlax',
                                   '04' => 'Agdas',
                                   '17' => 'Davaci',
                                   '30' => 'Lankaran',
                                   '06' => 'Agsu',
                                   '25' => 'Ismayilli',
                                   '28' => 'Lacin',
                                   '40' => 'Qazax',
                                   '14' => 'Cabrayil',
                                   '69' => 'Zangilan',
                                   '07' => 'Ali Bayramli',
                                   '59' => 'Ucar',
                                   '49' => 'Salyan',
                                   '24' => 'Imisli',
                                   '53' => 'Siyazan',
                                   '22' => 'Goycay',
                                   '42' => 'Quba',
                                   '46' => 'Sabirabad',
                                   '23' => 'Haciqabul',
                                   '13' => 'Bilasuvar',
                                   '36' => 'Neftcala',
                                   '51' => 'Samkir',
                                   '47' => 'Saki',
                                   '38' => 'Qabala',
                                   '34' => 'Naftalan',
                                   '37' => 'Oguz',
                                   '43' => 'Qubadli'
                         },
                         'AF' => {
                                   '32' => 'Samangan',
                                   '33' => 'Sar-e Pol',
                                   '21' => 'Paktia',
                                   '05' => 'Bamian',
                                   '26' => 'Takhar',
                                   '17' => 'Lowgar',
                                   '02' => 'Badghis',
                                   '18' => 'Nangarhar',
                                   '03' => 'Baghlan',
                                   '30' => 'Balkh',
                                   '06' => 'Farah',
                                   '16' => 'Laghman',
                                   '27' => 'Vardak',
                                   '28' => 'Zabol',
                                   '01' => 'Badakhshan',
                                   '40' => 'Parvan',
                                   '14' => 'Kapisa',
                                   '07' => 'Faryab',
                                   '24' => 'Kondoz',
                                   '10' => 'Helmand',
                                   '31' => 'Jowzjan',
                                   '35' => 'Laghman',
                                   '11' => 'Herat',
                                   '42' => 'Panjshir',
                                   '22' => 'Parvan',
                                   '08' => 'Ghazni',
                                   '13' => 'Kabol',
                                   '23' => 'Kandahar',
                                   '29' => 'Paktika',
                                   '39' => 'Oruzgan',
                                   '36' => 'Paktia',
                                   '41' => 'Daykondi',
                                   '15' => 'Konar',
                                   '38' => 'Nurestan',
                                   '34' => 'Konar',
                                   '37' => 'Khowst',
                                   '19' => 'Nimruz',
                                   '09' => 'Ghowr'
                         },
                         'NG' => {
                                   '32' => 'Oyo',
                                   '21' => 'Akwa Ibom',
                                   '05' => 'Lagos',
                                   '26' => 'Benue',
                                   '17' => 'Ondo',
                                   '30' => 'Kwara',
                                   '16' => 'Ogun',
                                   '44' => 'Yobe',
                                   '55' => 'Gombe',
                                   '25' => 'Anambra',
                                   '27' => 'Borno',
                                   '28' => 'Imo',
                                   '57' => 'Zamfara',
                                   '40' => 'Kebbi',
                                   '49' => 'Plateau',
                                   '24' => 'Katsina',
                                   '10' => 'Rivers',
                                   '31' => 'Niger',
                                   '35' => 'Adamawa',
                                   '11' => 'Federal Capital Territory',
                                   '53' => 'Ebonyi',
                                   '48' => 'Ondo',
                                   '22' => 'Cross River',
                                   '42' => 'Osun',
                                   '46' => 'Bauchi',
                                   '23' => 'Kaduna',
                                   '29' => 'Kano',
                                   '50' => 'Rivers',
                                   '39' => 'Jigawa',
                                   '36' => 'Delta',
                                   '51' => 'Sokoto',
                                   '41' => 'Kogi',
                                   '47' => 'Enugu',
                                   '52' => 'Bayelsa',
                                   '56' => 'Nassarawa',
                                   '45' => 'Abia',
                                   '37' => 'Edo',
                                   '43' => 'Taraba',
                                   '54' => 'Ekiti'
                         },
                         'KE' => {
                                   '07' => 'Nyanza',
                                   '01' => 'Central',
                                   '03' => 'Eastern',
                                   '05' => 'Nairobi Area',
                                   '08' => 'Rift Valley',
                                   '06' => 'North-Eastern',
                                   '09' => 'Western',
                                   '02' => 'Coast'
                         },
                         'BJ' => {
                                   '01' => 'Atakora',
                                   '03' => 'Borgou',
                                   '05' => 'Oueme',
                                   '06' => 'Zou',
                                   '04' => 'Mono',
                                   '02' => 'Atlantique',
                                   '14' => 'Littoral'
                         },
                         'OM' => {
                                   '07' => 'Musandam',
                                   '01' => 'Ad Dakhiliyah',
                                   '08' => 'Zufar',
                                   '03' => 'Al Wusta',
                                   '05' => 'Az Zahirah',
                                   '06' => 'Masqat',
                                   '04' => 'Ash Sharqiyah',
                                   '02' => 'Al Batinah'
                         },
                         'VN' => {
                                   '32' => 'Son La',
                                   '33' => 'Tay Ninh',
                                   '63' => 'Kon Tum',
                                   '90' => 'Lao Cai',
                                   '21' => 'Kien Giang',
                                   '71' => 'Quang Ngai',
                                   '26' => 'Nghe Tinh',
                                   '80' => 'Ha Nam',
                                   '02' => 'Bac Thai',
                                   '03' => 'Ben Tre',
                                   '72' => 'Quang Tri',
                                   '16' => 'Ha Son Binh',
                                   '44' => 'Dac Lac',
                                   '55' => 'Binh Thuan',
                                   '74' => 'Thua Thien',
                                   '84' => 'Quang Nam',
                                   '27' => 'Nghia Binh',
                                   '01' => 'An Giang',
                                   '57' => 'Gia Lai',
                                   '61' => 'Hoa Binh',
                                   '20' => 'Ho Chi Minh',
                                   '92' => 'Dien Bien',
                                   '89' => 'Lai Chau',
                                   '31' => 'Song Be',
                                   '35' => 'Thai Binh',
                                   '11' => 'Ha Bac',
                                   '91' => 'Dak Nong',
                                   '78' => 'Da Nang',
                                   '48' => 'Minh Hai',
                                   '87' => 'Can Tho',
                                   '93' => 'Hau Giang',
                                   '77' => 'Vinh Long',
                                   '29' => 'Quang Nam-Da Nang',
                                   '65' => 'Nam Ha',
                                   '50' => 'Vinh Phu',
                                   '39' => 'Lang Son',
                                   '64' => 'Quang Tri',
                                   '58' => 'Ha Giang',
                                   '12' => 'Hai Hung',
                                   '52' => 'Ho Chi Minh',
                                   '81' => 'Hung Yen',
                                   '60' => 'Ha Tinh',
                                   '56' => 'Can Tho',
                                   '45' => 'Dong Nai',
                                   '66' => 'Nghe An',
                                   '73' => 'Soc Trang',
                                   '76' => 'Tuyen Quang',
                                   '19' => 'Hoang Lien Son',
                                   '62' => 'Khanh Hoa',
                                   '09' => 'Dong Thap',
                                   '54' => 'Binh Dinh',
                                   '67' => 'Ninh Binh',
                                   '05' => 'Cao Bang',
                                   '70' => 'Quang Binh',
                                   '68' => 'Ninh Thuan',
                                   '04' => 'Binh Tri Thien',
                                   '17' => 'Ha Tuyen',
                                   '88' => 'Dak Lak',
                                   '30' => 'Quang Ninh',
                                   '82' => 'Nam Dinh',
                                   '25' => 'Minh Hai',
                                   '28' => 'Phu Khanh',
                                   '75' => 'Tra Vinh',
                                   '83' => 'Phu Tho',
                                   '40' => 'Dong Nai',
                                   '14' => 'Ha Nam Ninh',
                                   '07' => 'Dac Lac',
                                   '69' => 'Phu Yen',
                                   '59' => 'Ha Tay',
                                   '49' => 'Song Be',
                                   '24' => 'Long An',
                                   '53' => 'Ba Ria-Vung Tau',
                                   '79' => 'Hai Duong',
                                   '22' => 'Lai Chau',
                                   '46' => 'Dong Thap',
                                   '23' => 'Lam Dong',
                                   '13' => 'Hai Phong',
                                   '85' => 'Thai Nguyen',
                                   '36' => 'Thuan Hai',
                                   '51' => 'Ha Noi',
                                   '47' => 'Kien Giang',
                                   '38' => 'Vinh Phu',
                                   '34' => 'Thanh Hoa',
                                   '37' => 'Tien Giang',
                                   '43' => 'An Giang'
                         },
                         'YE' => {
                                   '11' => 'Dhamar',
                                   '21' => 'Al Jawf',
                                   '05' => 'Shabwah',
                                   '04' => 'Hadramawt',
                                   '02' => 'Adan',
                                   '22' => 'Hajjah',
                                   '03' => 'Al Mahrah',
                                   '08' => 'Al Hudaydah',
                                   '16' => 'San',
                                   '23' => 'Ibb',
                                   '25' => 'Ta',
                                   '01' => 'Abyan',
                                   '14' => 'Ma\'rib',
                                   '15' => 'Sa',
                                   '20' => 'Al Bayda\'',
                                   '24' => 'Lahij',
                                   '10' => 'Al Mahwit'
                         },
                         'CI' => {
                                   '90' => 'Vallee du Bandama',
                                   '80' => 'Haut-Sassandra',
                                   '91' => 'Worodougou',
                                   '78' => 'Dix-Huit Montagnes',
                                   '79' => 'Fromager',
                                   '87' => 'Savanes',
                                   '88' => 'Sud-Bandama',
                                   '77' => 'Denguele',
                                   '82' => 'Lagunes',
                                   '74' => 'Agneby',
                                   '84' => 'Moyen-Cavally',
                                   '85' => 'Moyen-Comoe',
                                   '75' => 'Bafing',
                                   '83' => 'Marahoue',
                                   '61' => 'Abidjan',
                                   '51' => 'Sassandra',
                                   '81' => 'Lacs',
                                   '92' => 'Zanzan',
                                   '89' => 'Sud-Comoe',
                                   '86' => 'N\'zi-Comoe',
                                   '76' => 'Bas-Sassandra'
                         },
                         'DZ' => {
                                   '33' => 'Tebessa',
                                   '21' => 'Bouira',
                                   '26' => 'Mascara',
                                   '04' => 'Constantine',
                                   '18' => 'Bejaia',
                                   '03' => 'Batna',
                                   '30' => 'Sidi Bel Abbes',
                                   '06' => 'Medea',
                                   '44' => 'El Tarf',
                                   '55' => 'Tipaza',
                                   '27' => 'M\'sila',
                                   '25' => 'Laghouat',
                                   '01' => 'Alger',
                                   '40' => 'Boumerdes',
                                   '14' => 'Tizi Ouzou',
                                   '20' => 'Blida',
                                   '07' => 'Mostaganem',
                                   '49' => 'Naama',
                                   '24' => 'Jijel',
                                   '10' => 'Saida',
                                   '31' => 'Skikda',
                                   '35' => 'Ain Defla',
                                   '53' => 'Tamanghasset',
                                   '48' => 'Mila',
                                   '42' => 'El Bayadh',
                                   '22' => 'Djelfa',
                                   '46' => 'Illizi',
                                   '13' => 'Tiaret',
                                   '23' => 'Guelma',
                                   '29' => 'Oum el Bouaghi',
                                   '50' => 'Ouargla',
                                   '39' => 'Bordj Bou Arreridj',
                                   '36' => 'Ain Temouchent',
                                   '51' => 'Relizane',
                                   '12' => 'Setif',
                                   '41' => 'Chlef',
                                   '15' => 'Tlemcen',
                                   '47' => 'Khenchela',
                                   '38' => 'Bechar',
                                   '52' => 'Souk Ahras',
                                   '34' => 'Adrar',
                                   '56' => 'Tissemsilt',
                                   '37' => 'Annaba',
                                   '45' => 'Ghardaia',
                                   '19' => 'Biskra',
                                   '43' => 'El Oued',
                                   '09' => 'Oran',
                                   '54' => 'Tindouf'
                         },
                         'LK' => {
                                   '32' => 'North Western',
                                   '33' => 'Sabaragamuwa',
                                   '21' => 'Trincomalee',
                                   '26' => 'Mannar',
                                   '04' => 'Batticaloa',
                                   '17' => 'Nuwara Eliya',
                                   '02' => 'Anuradhapura',
                                   '18' => 'Polonnaruwa',
                                   '03' => 'Badulla',
                                   '30' => 'North Central',
                                   '06' => 'Galle',
                                   '16' => 'Moneragala',
                                   '25' => 'Jaffna',
                                   '27' => 'Mullaittivu',
                                   '01' => 'Amparai',
                                   '28' => 'Vavuniya',
                                   '14' => 'Matale',
                                   '20' => 'Ratnapura',
                                   '07' => 'Hambantota',
                                   '24' => 'Gampaha',
                                   '10' => 'Kandy',
                                   '31' => 'Northern',
                                   '35' => 'Uva',
                                   '11' => 'Kegalla',
                                   '23' => 'Colombo',
                                   '29' => 'Central',
                                   '36' => 'Western',
                                   '12' => 'Kurunegala',
                                   '15' => 'Matara',
                                   '34' => 'Southern',
                                   '19' => 'Puttalam',
                                   '09' => 'Kalutara'
                         },
                         'ID' => {
                                   '32' => 'Sumatera Selatan',
                                   '33' => 'Banten',
                                   '21' => 'Sulawesi Tengah',
                                   '05' => 'Jambi',
                                   '26' => 'Sumatera Utara',
                                   '04' => 'Jakarta Raya',
                                   '17' => 'Nusa Tenggara Barat',
                                   '02' => 'Bali',
                                   '18' => 'Nusa Tenggara Timur',
                                   '03' => 'Bengkulu',
                                   '30' => 'Jawa Barat',
                                   '06' => 'Jawa Barat',
                                   '16' => 'Maluku',
                                   '25' => 'Sumatera Selatan',
                                   '28' => 'Maluku',
                                   '01' => 'Aceh',
                                   '40' => 'Kepulauan Riau',
                                   '14' => 'Kalimantan Timur',
                                   '20' => 'Sulawesi Selatan',
                                   '07' => 'Jawa Tengah',
                                   '24' => 'Sumatera Barat',
                                   '10' => 'Yogyakarta',
                                   '31' => 'Sulawesi Utara',
                                   '35' => 'Kepulauan Bangka Belitung',
                                   '11' => 'Kalimantan Barat',
                                   '22' => 'Sulawesi Tenggara',
                                   '08' => 'Jawa Timur',
                                   '23' => 'Sulawesi Utara',
                                   '13' => 'Kalimantan Tengah',
                                   '29' => 'Maluku Utara',
                                   '39' => 'Irian Jaya Barat',
                                   '36' => 'Papua',
                                   '12' => 'Kalimantan Selatan',
                                   '41' => 'Sulawesi Barat',
                                   '15' => 'Lampung',
                                   '38' => 'Sulawesi Selatan',
                                   '34' => 'Gorontalo',
                                   '37' => 'Riau',
                                   '19' => 'Riau',
                                   '09' => 'Papua'
                         },
                         'FM' => {
                                   '01' => 'Kosrae',
                                   '03' => 'Chuuk',
                                   '04' => 'Yap',
                                   '02' => 'Pohnpei'
                         },
                         'GE' => {
                                   '32' => 'Lagodekhis Raioni',
                                   '33' => 'Lanch\'khut\'is Raioni',
                                   '21' => 'Gori',
                                   '63' => 'Zugdidi',
                                   '26' => 'Kaspis Raioni',
                                   '02' => 'Abkhazia',
                                   '18' => 'Dmanisis Raioni',
                                   '03' => 'Adigenis Raioni',
                                   '16' => 'Ch\'okhatauris Raioni',
                                   '44' => 'Qvarlis Raioni',
                                   '55' => 'T\'ianet\'is Raioni',
                                   '27' => 'Kharagaulis Raioni',
                                   '01' => 'Abashis Raioni',
                                   '57' => 'Ts\'ageris Raioni',
                                   '61' => 'Vanis Raioni',
                                   '20' => 'Gardabanis Raioni',
                                   '10' => 'Aspindzis Raioni',
                                   '31' => 'K\'ut\'aisi',
                                   '35' => 'Marneulis Raioni',
                                   '11' => 'Baghdat\'is Raioni',
                                   '48' => 'Samtrediis Raioni',
                                   '08' => 'Akhmetis Raioni',
                                   '29' => 'Khobis Raioni',
                                   '50' => 'Sighnaghis Raioni',
                                   '39' => 'Ninotsmindis Raioni',
                                   '64' => 'Zugdidis Raioni',
                                   '58' => 'Tsalenjikhis Raioni',
                                   '41' => 'Ozurget\'is Raioni',
                                   '12' => 'Bolnisis Raioni',
                                   '15' => 'Ch\'khorotsqus Raioni',
                                   '52' => 'T\'elavis Raioni',
                                   '60' => 'Tsqaltubo',
                                   '56' => 'Tqibuli',
                                   '45' => 'Rust\'avi',
                                   '19' => 'Dushet\'is Raioni',
                                   '09' => 'Ambrolauris Raioni',
                                   '62' => 'Zestap\'onis Raioni',
                                   '54' => 'T\'et\'ritsqaros Raioni',
                                   '05' => 'Akhalgoris Raioni',
                                   '04' => 'Ajaria',
                                   '17' => 'Dedop\'listsqaros Raioni',
                                   '30' => 'Khonis Raioni',
                                   '06' => 'Akhalk\'alak\'is Raioni',
                                   '25' => 'K\'arelis Raioni',
                                   '28' => 'Khashuris Raioni',
                                   '40' => 'Onis Raioni',
                                   '14' => 'Chiat\'ura',
                                   '07' => 'Akhalts\'ikhis Raioni',
                                   '59' => 'Tsalkis Raioni',
                                   '49' => 'Senakis Raioni',
                                   '24' => 'Javis Raioni',
                                   '53' => 'T\'erjolis Raioni',
                                   '22' => 'Goris Raioni',
                                   '42' => 'P\'ot\'i',
                                   '46' => 'Sach\'kheris Raioni',
                                   '23' => 'Gurjaanis Raioni',
                                   '13' => 'Borjomis Raioni',
                                   '36' => 'Martvilis Raioni',
                                   '51' => 'T\'bilisi',
                                   '47' => 'Sagarejos Raioni',
                                   '38' => 'Mts\'khet\'is Raioni',
                                   '34' => 'Lentekhis Raioni',
                                   '37' => 'Mestiis Raioni',
                                   '43' => 'Qazbegis Raioni'
                         },
                         'GM' => {
                                   '07' => 'North Bank',
                                   '01' => 'Banjul',
                                   '03' => 'Central River',
                                   '05' => 'Western',
                                   '04' => 'Upper River',
                                   '02' => 'Lower River'
                         },
                         'LV' => {
                                   '32' => 'Ventspils',
                                   '33' => 'Ventspils',
                                   '21' => 'Ogres',
                                   '05' => 'Cesu',
                                   '26' => 'Rigas',
                                   '04' => 'Bauskas',
                                   '17' => 'Liepajas',
                                   '02' => 'Aluksnes',
                                   '18' => 'Limbazu',
                                   '03' => 'Balvu',
                                   '30' => 'Valkas',
                                   '06' => 'Daugavpils',
                                   '16' => 'Liepaja',
                                   '27' => 'Saldus',
                                   '25' => 'Riga',
                                   '01' => 'Aizkraukles',
                                   '28' => 'Talsu',
                                   '14' => 'Kraslavas',
                                   '20' => 'Madonas',
                                   '07' => 'Daugavpils',
                                   '24' => 'Rezeknes',
                                   '10' => 'Jekabpils',
                                   '31' => 'Valmieras',
                                   '11' => 'Jelgava',
                                   '22' => 'Preilu',
                                   '08' => 'Dobeles',
                                   '13' => 'Jurmala',
                                   '23' => 'Rezekne',
                                   '29' => 'Tukuma',
                                   '12' => 'Jelgavas',
                                   '15' => 'Kuldigas',
                                   '19' => 'Ludzas',
                                   '09' => 'Gulbenes'
                         },
                         'RU' => {
                                   '32' => 'Khanty-Mansiy',
                                   '33' => 'Kirov',
                                   '21' => 'Ivanovo',
                                   '63' => 'Sakha',
                                   '90' => 'Permskiy Kray',
                                   '71' => 'Sverdlovsk',
                                   '26' => 'Kamchatka',
                                   '80' => 'Udmurt',
                                   '02' => 'Aginsky Buryatsky AO',
                                   '18' => 'Evenk',
                                   '03' => 'Gorno-Altay',
                                   '72' => 'Tambovskaya oblast',
                                   '16' => 'Chuvashia',
                                   '44' => 'Magadan',
                                   '55' => 'Orenburg',
                                   '27' => 'Karachay-Cherkess',
                                   '84' => 'Volgograd',
                                   '74' => 'Taymyr',
                                   '01' => 'Adygeya, Republic of',
                                   '57' => 'Penza',
                                   '61' => 'Rostov',
                                   '20' => 'Irkutsk',
                                   '89' => 'Yevrey',
                                   '10' => 'Bryansk',
                                   '31' => 'Khakass',
                                   '35' => 'Komi-Permyak',
                                   '11' => 'Buryat',
                                   '91' => 'Krasnoyarskiy Kray',
                                   '78' => 'Tyumen\'',
                                   '48' => 'Moscow City',
                                   '87' => 'Yamal-Nenets',
                                   '77' => 'Tver\'',
                                   '08' => 'Bashkortostan',
                                   '29' => 'Kemerovo',
                                   '65' => 'Samara',
                                   '50' => 'Nenets',
                                   '39' => 'Krasnoyarsk',
                                   '64' => 'Sakhalin',
                                   '12' => 'Chechnya',
                                   '41' => 'Kursk',
                                   '58' => 'Perm\'',
                                   '15' => 'Chukot',
                                   '52' => 'Novgorod',
                                   '81' => 'Ul\'yanovsk',
                                   '60' => 'Pskov',
                                   '56' => 'Orel',
                                   '45' => 'Mariy-El',
                                   '66' => 'Saint Petersburg City',
                                   '73' => 'Tatarstan',
                                   '19' => 'Ingush',
                                   '76' => 'Tula',
                                   '86' => 'Voronezh',
                                   '09' => 'Belgorod',
                                   '62' => 'Ryazan\'',
                                   '54' => 'Omsk',
                                   '67' => 'Saratov',
                                   '70' => 'Stavropol\'',
                                   '05' => 'Amur',
                                   '68' => 'North Ossetia',
                                   '04' => 'Altaisky krai',
                                   '17' => 'Dagestan',
                                   '88' => 'Yaroslavl\'',
                                   '30' => 'Khabarovsk',
                                   '06' => 'Arkhangel\'sk',
                                   '82' => 'Ust-Orda Buryat',
                                   '25' => 'Kaluga',
                                   '28' => 'Karelia',
                                   '40' => 'Kurgan',
                                   '75' => 'Tomsk',
                                   '83' => 'Vladimir',
                                   '14' => 'Chita',
                                   '59' => 'Primor\'ye',
                                   '07' => 'Astrakhan\'',
                                   '69' => 'Smolensk',
                                   '49' => 'Murmansk',
                                   '24' => 'Kalmyk',
                                   '53' => 'Novosibirsk',
                                   '79' => 'Tuva',
                                   '42' => 'Leningrad',
                                   '22' => 'Kabardin-Balkar',
                                   '46' => 'Mordovia',
                                   '13' => 'Chelyabinsk',
                                   '23' => 'Kaliningrad',
                                   '85' => 'Vologda',
                                   '36' => 'Koryak',
                                   '51' => 'Nizhegorod',
                                   '47' => 'Moskva',
                                   '38' => 'Krasnodar',
                                   '34' => 'Komi',
                                   '37' => 'Kostroma',
                                   '43' => 'Lipetsk'
                         },
                         'LB' => {
                                   '11' => 'Baalbek-Hermel',
                                   '01' => 'Beqaa',
                                   '05' => 'Mont-Liban',
                                   '04' => 'Beyrouth',
                                   '07' => 'Nabatiye',
                                   '03' => 'Liban-Nord',
                                   '08' => 'Beqaa',
                                   '10' => 'Aakk,r',
                                   '06' => 'Liban-Sud',
                                   '09' => 'Liban-Nord'
                         },
                         'DE' => {
                                   '11' => 'Brandenburg',
                                   '01' => 'Baden-Wurttemberg',
                                   '05' => 'Hessen',
                                   '12' => 'Mecklenburg-Vorpommern',
                                   '04' => 'Hamburg',
                                   '15' => 'Thuringen',
                                   '14' => 'Sachsen-Anhalt',
                                   '02' => 'Bayern',
                                   '07' => 'Nordrhein-Westfalen',
                                   '03' => 'Bremen',
                                   '08' => 'Rheinland-Pfalz',
                                   '10' => 'Schleswig-Holstein',
                                   '06' => 'Niedersachsen',
                                   '16' => 'Berlin',
                                   '13' => 'Sachsen',
                                   '09' => 'Saarland'
                         },
                         'FI' => {
                                   '01' => 'Aland',
                                   '08' => 'Oulu',
                                   '06' => 'Lapland',
                                   '13' => 'Southern Finland',
                                   '14' => 'Eastern Finland',
                                   '15' => 'Western Finland'
                         },
                         'MV' => {
                                   '05' => 'Laamu',
                                   '26' => 'Kaafu',
                                   '04' => 'Waavu',
                                   '17' => 'Daalu',
                                   '02' => 'Aliff',
                                   '03' => 'Laviyani',
                                   '08' => 'Thaa',
                                   '13' => 'Raa',
                                   '23' => 'Haa Daalu',
                                   '29' => 'Naviyani',
                                   '25' => 'Noonu',
                                   '27' => 'Gaafu Aliff',
                                   '28' => 'Gaafu Daalu',
                                   '01' => 'Seenu',
                                   '40' => 'Male',
                                   '12' => 'Meemu',
                                   '20' => 'Baa',
                                   '14' => 'Faafu',
                                   '07' => 'Haa Aliff',
                                   '24' => 'Shaviyani'
                         },
                         'LU' => {
                                   '01' => 'Diekirch',
                                   '03' => 'Luxembourg',
                                   '02' => 'Grevenmacher'
                         },
                         'VE' => {
                                   '11' => 'Falcon',
                                   '21' => 'Trujillo',
                                   '05' => 'Barinas',
                                   '26' => 'Vargas',
                                   '04' => 'Aragua',
                                   '17' => 'Nueva Esparta',
                                   '02' => 'Anzoategui',
                                   '22' => 'Yaracuy',
                                   '18' => 'Portuguesa',
                                   '08' => 'Cojedes',
                                   '03' => 'Apure',
                                   '06' => 'Bolivar',
                                   '13' => 'Lara',
                                   '16' => 'Monagas',
                                   '23' => 'Zulia',
                                   '25' => 'Distrito Federal',
                                   '01' => 'Amazonas',
                                   '12' => 'Guarico',
                                   '15' => 'Miranda',
                                   '14' => 'Merida',
                                   '20' => 'Tachira',
                                   '07' => 'Carabobo',
                                   '24' => 'Dependencias Federales',
                                   '19' => 'Sucre',
                                   '09' => 'Delta Amacuro'
                         },
                         'BH' => {
                                   '11' => 'Al Mintaqah al Wusta',
                                   '05' => 'Jidd Hafs',
                                   '17' => 'Al Janubiyah',
                                   '02' => 'Al Manamah',
                                   '18' => 'Ash Shamaliyah',
                                   '03' => 'Al Muharraq',
                                   '08' => 'Al Mintaqah al Gharbiyah',
                                   '06' => 'Sitrah',
                                   '16' => 'Al Asimah',
                                   '13' => 'Ar Rifa',
                                   '01' => 'Al Hadd',
                                   '12' => 'Madinat',
                                   '14' => 'Madinat Hamad',
                                   '15' => 'Al Muharraq',
                                   '10' => 'Al Mintaqah ash Shamaliyah',
                                   '19' => 'Al Wusta',
                                   '09' => 'Mintaqat Juzur Hawar'
                         },
                         'RO' => {
                                   '32' => 'Satu Mare',
                                   '33' => 'Sibiu',
                                   '21' => 'Hunedoara',
                                   '05' => 'Bihor',
                                   '26' => 'Mehedinti',
                                   '04' => 'Bacau',
                                   '17' => 'Dolj',
                                   '02' => 'Arad',
                                   '18' => 'Galati',
                                   '03' => 'Arges',
                                   '30' => 'Prahova',
                                   '06' => 'Bistrita-Nasaud',
                                   '16' => 'Dambovita',
                                   '27' => 'Mures',
                                   '25' => 'Maramures',
                                   '01' => 'Alba',
                                   '28' => 'Neamt',
                                   '40' => 'Vrancea',
                                   '14' => 'Constanta',
                                   '20' => 'Harghita',
                                   '07' => 'Botosani',
                                   '10' => 'Bucuresti',
                                   '31' => 'Salaj',
                                   '35' => 'Teleorman',
                                   '11' => 'Buzau',
                                   '42' => 'Giurgiu',
                                   '22' => 'Ialomita',
                                   '08' => 'Braila',
                                   '13' => 'Cluj',
                                   '23' => 'Iasi',
                                   '29' => 'Olt',
                                   '39' => 'Valcea',
                                   '36' => 'Timis',
                                   '12' => 'Caras-Severin',
                                   '41' => 'Calarasi',
                                   '15' => 'Covasna',
                                   '38' => 'Vaslui',
                                   '34' => 'Suceava',
                                   '37' => 'Tulcea',
                                   '19' => 'Gorj',
                                   '43' => 'Ilfov',
                                   '09' => 'Brasov'
                         },
                         'IN' => {
                                   '32' => 'Daman and Diu',
                                   '33' => 'Goa',
                                   '21' => 'Orissa',
                                   '05' => 'Chandigarh',
                                   '26' => 'Tripura',
                                   '17' => 'Manipur',
                                   '02' => 'Andhra Pradesh',
                                   '18' => 'Meghalaya',
                                   '03' => 'Assam',
                                   '30' => 'Arunachal Pradesh',
                                   '06' => 'Dadra and Nagar Haveli',
                                   '16' => 'Maharashtra',
                                   '25' => 'Tamil Nadu',
                                   '28' => 'West Bengal',
                                   '01' => 'Andaman and Nicobar Islands',
                                   '14' => 'Lakshadweep',
                                   '20' => 'Nagaland',
                                   '07' => 'Delhi',
                                   '24' => 'Rajasthan',
                                   '10' => 'Haryana',
                                   '31' => 'Mizoram',
                                   '35' => 'Madhya Pradesh',
                                   '11' => 'Himachal Pradesh',
                                   '22' => 'Puducherry',
                                   '13' => 'Kerala',
                                   '23' => 'Punjab',
                                   '29' => 'Sikkim',
                                   '39' => 'Uttarakhand',
                                   '36' => 'Uttar Pradesh',
                                   '12' => 'Jammu and Kashmir',
                                   '38' => 'Jharkhand',
                                   '34' => 'Bihar',
                                   '37' => 'Chhattisgarh',
                                   '19' => 'Karnataka',
                                   '09' => 'Gujarat'
                         },
                         'AR' => {
                                   '11' => 'La Pampa',
                                   '21' => 'Santa Fe',
                                   '05' => 'Cordoba',
                                   '04' => 'Chubut',
                                   '17' => 'Salta',
                                   '02' => 'Catamarca',
                                   '22' => 'Santiago del Estero',
                                   '18' => 'San Juan',
                                   '08' => 'Entre Rios',
                                   '03' => 'Chaco',
                                   '06' => 'Corrientes',
                                   '13' => 'Mendoza',
                                   '16' => 'Rio Negro',
                                   '23' => 'Tierra del Fuego',
                                   '01' => 'Buenos Aires',
                                   '12' => 'La Rioja',
                                   '15' => 'Neuquen',
                                   '14' => 'Misiones',
                                   '20' => 'Santa Cruz',
                                   '07' => 'Distrito Federal',
                                   '24' => 'Tucuman',
                                   '10' => 'Jujuy',
                                   '19' => 'San Luis',
                                   '09' => 'Formosa'
                         },
                         'SN' => {
                                   '11' => 'Kolda',
                                   '01' => 'Dakar',
                                   '05' => 'Tambacounda',
                                   '04' => 'Saint-Louis',
                                   '12' => 'Ziguinchor',
                                   '14' => 'Saint-Louis',
                                   '15' => 'Matam',
                                   '07' => 'Thies',
                                   '03' => 'Diourbel',
                                   '10' => 'Kaolack',
                                   '13' => 'Louga',
                                   '09' => 'Fatick'
                         },
                         'MX' => {
                                   '32' => 'Zacatecas',
                                   '21' => 'Puebla',
                                   '05' => 'Chiapas',
                                   '26' => 'Sonora',
                                   '04' => 'Campeche',
                                   '17' => 'Morelos',
                                   '02' => 'Baja California',
                                   '18' => 'Nayarit',
                                   '03' => 'Baja California Sur',
                                   '30' => 'Veracruz-Llave',
                                   '06' => 'Chihuahua',
                                   '16' => 'Michoacan de Ocampo',
                                   '27' => 'Tabasco',
                                   '25' => 'Sinaloa',
                                   '28' => 'Tamaulipas',
                                   '01' => 'Aguascalientes',
                                   '14' => 'Jalisco',
                                   '20' => 'Oaxaca',
                                   '07' => 'Coahuila de Zaragoza',
                                   '24' => 'San Luis Potosi',
                                   '10' => 'Durango',
                                   '31' => 'Yucatan',
                                   '11' => 'Guanajuato',
                                   '22' => 'Queretaro de Arteaga',
                                   '08' => 'Colima',
                                   '13' => 'Hidalgo',
                                   '23' => 'Quintana Roo',
                                   '29' => 'Tlaxcala',
                                   '12' => 'Guerrero',
                                   '15' => 'Mexico',
                                   '19' => 'Nuevo Leon',
                                   '09' => 'Distrito Federal'
                         },
                         'MC' => {
                                   '01' => 'La Condamine',
                                   '03' => 'Monte-Carlo',
                                   '02' => 'Monaco'
                         },
                         'HN' => {
                                   '11' => 'Islas de la Bahia',
                                   '05' => 'Copan',
                                   '04' => 'Comayagua',
                                   '17' => 'Valle',
                                   '02' => 'Choluteca',
                                   '18' => 'Yoro',
                                   '03' => 'Colon',
                                   '08' => 'Francisco Morazan',
                                   '06' => 'Cortes',
                                   '13' => 'Lempira',
                                   '16' => 'Santa Barbara',
                                   '01' => 'Atlantida',
                                   '12' => 'La Paz',
                                   '14' => 'Ocotepeque',
                                   '15' => 'Olancho',
                                   '07' => 'El Paraiso',
                                   '10' => 'Intibuca',
                                   '09' => 'Gracias a Dios'
                         },
                         'BR' => {
                                   '11' => 'Mato Grosso do Sul',
                                   '21' => 'Rio de Janeiro',
                                   '05' => 'Bahia',
                                   '26' => 'Santa Catarina',
                                   '04' => 'Amazonas',
                                   '17' => 'Paraiba',
                                   '02' => 'Alagoas',
                                   '22' => 'Rio Grande do Norte',
                                   '18' => 'Parana',
                                   '08' => 'Espirito Santo',
                                   '03' => 'Amapa',
                                   '30' => 'Pernambuco',
                                   '06' => 'Ceara',
                                   '13' => 'Maranhao',
                                   '16' => 'Para',
                                   '23' => 'Rio Grande do Sul',
                                   '29' => 'Goias',
                                   '25' => 'Roraima',
                                   '27' => 'Sao Paulo',
                                   '01' => 'Acre',
                                   '28' => 'Sergipe',
                                   '20' => 'Piaui',
                                   '15' => 'Minas Gerais',
                                   '14' => 'Mato Grosso',
                                   '07' => 'Distrito Federal',
                                   '24' => 'Rondonia',
                                   '31' => 'Tocantins'
                         },
                         'IL' => {
                                   '01' => 'HaDarom',
                                   '03' => 'HaZafon',
                                   '05' => 'Tel Aviv',
                                   '06' => 'Yerushalayim',
                                   '04' => 'Hefa',
                                   '02' => 'HaMerkaz'
                         },
                         'SB' => {
                                   '11' => 'Western',
                                   '12' => 'Choiseul',
                                   '07' => 'Isabel',
                                   '03' => 'Malaita',
                                   '08' => 'Makira',
                                   '13' => 'Rennell and Bellona',
                                   '06' => 'Guadalcanal',
                                   '10' => 'Central',
                                   '09' => 'Temotu'
                         },
                         'PS' => {
                                   'GZ' => 'Gaza',
                                   'WE' => 'West Bank'
                         },
                         'NZ' => {
                                   'F4' => 'Marlborough',
                                   'G1' => 'Waikato',
                                   'E7' => 'Auckland',
                                   'F8' => 'Southland',
                                   'G3' => 'West Coast',
                                   'E8' => 'Bay of Plenty',
                                   'F6' => 'Northland',
                                   'G2' => 'Wellington',
                                   'F9' => 'Taranaki',
                                   'F5' => 'Nelson',
                                   'F3' => 'Manawatu-Wanganui',
                                   'F2' => 'Hawke\'s Bay',
                                   'E9' => 'Canterbury',
                                   'F1' => 'Gisborne',
                                   '10' => 'Chatham Islands',
                                   'F7' => 'Otago'
                         },
                         'HU' => {
                                   '32' => 'Nagykanizsa',
                                   '33' => 'Nyiregyhaza',
                                   '21' => 'Tolna',
                                   '05' => 'Budapest',
                                   '26' => 'Bekescsaba',
                                   '04' => 'Borsod-Abauj-Zemplen',
                                   '17' => 'Somogy',
                                   '02' => 'Baranya',
                                   '18' => 'Szabolcs-Szatmar-Bereg',
                                   '03' => 'Bekes',
                                   '30' => 'Kaposvar',
                                   '06' => 'Csongrad',
                                   '16' => 'Pest',
                                   '27' => 'Dunaujvaros',
                                   '25' => 'Gyor',
                                   '01' => 'Bacs-Kiskun',
                                   '28' => 'Eger',
                                   '40' => 'Zalaegerszeg',
                                   '14' => 'Nograd',
                                   '20' => 'Jasz-Nagykun-Szolnok',
                                   '07' => 'Debrecen',
                                   '24' => 'Zala',
                                   '10' => 'Hajdu-Bihar',
                                   '31' => 'Kecskemet',
                                   '35' => 'Szekesfehervar',
                                   '11' => 'Heves',
                                   '42' => 'Szekszard',
                                   '22' => 'Vas',
                                   '08' => 'Fejer',
                                   '13' => 'Miskolc',
                                   '23' => 'Veszprem',
                                   '29' => 'Hodmezovasarhely',
                                   '39' => 'Veszprem',
                                   '36' => 'Szolnok',
                                   '12' => 'Komarom-Esztergom',
                                   '41' => 'Salgotarjan',
                                   '15' => 'Pecs',
                                   '38' => 'Tatabanya',
                                   '34' => 'Sopron',
                                   '37' => 'Szombathely',
                                   '19' => 'Szeged',
                                   '09' => 'Gyor-Moson-Sopron'
                         },
                         'DO' => {
                                   '32' => 'Monte Plata',
                                   '33' => 'San Cristobal',
                                   '21' => 'Sanchez Ramirez',
                                   '05' => 'Distrito Nacional',
                                   '26' => 'Santiago Rodriguez',
                                   '04' => 'Dajabon',
                                   '17' => 'Peravia',
                                   '02' => 'Baoruco',
                                   '18' => 'Puerto Plata',
                                   '03' => 'Barahona',
                                   '30' => 'La Vega',
                                   '06' => 'Duarte',
                                   '16' => 'Pedernales',
                                   '27' => 'Valverde',
                                   '25' => 'Santiago',
                                   '01' => 'Azua',
                                   '28' => 'El Seibo',
                                   '14' => 'Maria Trinidad Sanchez',
                                   '20' => 'Samana',
                                   '24' => 'San Pedro De Macoris',
                                   '10' => 'La Altagracia',
                                   '31' => 'Monsenor Nouel',
                                   '35' => 'Peravia',
                                   '11' => 'Elias Pina',
                                   '08' => 'Espaillat',
                                   '23' => 'San Juan',
                                   '29' => 'Hato Mayor',
                                   '36' => 'San Jose de Ocoa',
                                   '12' => 'La Romana',
                                   '15' => 'Monte Cristi',
                                   '34' => 'Distrito Nacional',
                                   '37' => 'Santo Domingo',
                                   '19' => 'Salcedo',
                                   '09' => 'Independencia'
                         },
                         'UG' => {
                                   '67' => 'Busia',
                                   '21' => 'Nile',
                                   '90' => 'Mukono',
                                   '05' => 'Busoga',
                                   '80' => 'Kaberamaido',
                                   '88' => 'Moroto',
                                   '18' => 'Central',
                                   '82' => 'Kanungu',
                                   '84' => 'Kitgum',
                                   '74' => 'Sembabule',
                                   '25' => 'Western',
                                   '95' => 'Soroti',
                                   '83' => 'Kayunga',
                                   '20' => 'Eastern',
                                   '92' => 'Pader',
                                   '69' => 'Katakwi',
                                   '24' => 'Southern',
                                   '89' => 'Mpigi',
                                   '91' => 'Nakapiripirit',
                                   '78' => 'Iganga',
                                   '79' => 'Kabarole',
                                   '22' => 'North Buganda',
                                   '87' => 'Mbale',
                                   '93' => 'Rukungiri',
                                   '77' => 'Arua',
                                   '08' => 'Karamoja',
                                   '23' => 'Northern',
                                   '96' => 'Wakiso',
                                   '65' => 'Adjumani',
                                   '85' => 'Kyenjojo',
                                   '97' => 'Yumbe',
                                   '94' => 'Sironko',
                                   '12' => 'South Buganda',
                                   '81' => 'Kamwenge',
                                   '56' => 'Mubende',
                                   '37' => 'Kampala',
                                   '66' => 'Bugiri',
                                   '73' => 'Nakasongola',
                                   '86' => 'Mayuge'
                         },
                         'KH' => {
                                   '11' => 'Phnum Penh',
                                   '05' => 'Kampong Thum',
                                   '04' => 'Kampong Spoe',
                                   '17' => 'Stoeng Treng',
                                   '02' => 'Kampong Cham',
                                   '18' => 'Svay Rieng',
                                   '03' => 'Kampong Chhnang',
                                   '08' => 'Kaoh Kong',
                                   '30' => 'Pailin',
                                   '06' => 'Kampot',
                                   '13' => 'Preah Vihear',
                                   '16' => 'Siemreab-Otdar Meanchey',
                                   '29' => 'Batdambang',
                                   '12' => 'Pouthisat',
                                   '14' => 'Prey Veng',
                                   '15' => 'Rotanokiri',
                                   '07' => 'Kandal',
                                   '10' => 'Mondol Kiri',
                                   '19' => 'Takev',
                                   '09' => 'Kracheh'
                         },
                         'TG' => {
                                   '22' => 'Centrale',
                                   '25' => 'Plateaux',
                                   '18' => 'Tsevie',
                                   '24' => 'Maritime',
                                   '23' => 'Kara',
                                   '26' => 'Savanes',
                                   '09' => 'Lama-Kara'
                         },
                         'GB' => {
                                   'R1' => 'Ballymoney',
                                   'T9' => 'Scottish Borders, The',
                                   '90' => 'Clwyd',
                                   'X6' => 'Ceredigion',
                                   'N2' => 'Stockport',
                                   'Q3' => 'Wolverhampton',
                                   'B6' => 'Brighton and Hove',
                                   'C1' => 'Bury',
                                   'E8' => 'Hackney',
                                   'J2' => 'North East Lincolnshire',
                                   'L1' => 'Richmond upon Thames',
                                   'U3' => 'Dundee City',
                                   'W1' => 'Perth and Kinross',
                                   'O8' => 'Walsall',
                                   'I5' => 'Middlesbrough',
                                   'J9' => 'Nottinghamshire',
                                   '18' => 'Greater Manchester',
                                   'M8' => 'Southwark',
                                   'V5' => 'Midlothian',
                                   'P3' => 'Warwickshire',
                                   'U1' => 'Clackmannanshire',
                                   'Y6' => 'Newport',
                                   'C8' => 'Croydon',
                                   'H9' => 'London, City of',
                                   'V1' => 'Fife',
                                   'Z3' => 'Vale of Glamorgan, The',
                                   'H3' => 'Leeds',
                                   '84' => 'Lothian',
                                   'T1' => 'Newtownabbey',
                                   'E7' => 'Greenwich',
                                   'P5' => 'Westminster',
                                   'R3' => 'Belfast',
                                   'B1' => 'Bolton',
                                   'K3' => 'Peterborough',
                                   'Y1' => 'Flintshire',
                                   '20' => 'Hereford and Worcester',
                                   'T3' => 'Omagh',
                                   'X3' => 'Bridgend',
                                   'F3' => 'Haringey',
                                   'G6' => 'Kingston upon Hull, City of',
                                   'O4' => 'Torbay',
                                   'T2' => 'North Down',
                                   'S9' => 'Newry and Mourne',
                                   'P1' => 'Wandsworth',
                                   'X1' => 'Isle of Anglesey',
                                   'L2' => 'Rochdale',
                                   'M1' => 'Slough',
                                   'W2' => 'Renfrewshire',
                                   'E3' => 'Enfield',
                                   'M3' => 'Somerset',
                                   'V7' => 'North Ayrshire',
                                   'N6' => 'Sunderland',
                                   'L6' => 'Shropshire',
                                   'V9' => 'Orkney',
                                   'S4' => 'Limavady',
                                   'D7' => 'Dudley',
                                   'F6' => 'Havering',
                                   'B3' => 'Bracknell Forest',
                                   'U8' => 'Edinburgh, City of',
                                   'X9' => 'Denbighshire',
                                   'P8' => 'Wiltshire',
                                   'R8' => 'Craigavon',
                                   'S7' => 'Magherafelt',
                                   'T5' => 'Aberdeen City',
                                   'H6' => 'Lewisham',
                                   'I1' => 'Luton',
                                   'N4' => 'Stoke-on-Trent',
                                   'Q8' => 'Armagh',
                                   'W8' => 'Eilean Siar',
                                   'A1' => 'Barking and Dagenham',
                                   'M5' => 'Southend-on-Sea',
                                   'V3' => 'Highland',
                                   '17' => 'Greater London',
                                   'V8' => 'North Lanarkshire',
                                   'X8' => 'Conwy',
                                   'N8' => 'Sutton',
                                   'O1' => 'Tameside',
                                   'U6' => 'East Lothian',
                                   'G2' => 'Isle of Wight',
                                   'Q5' => 'York',
                                   'Y9' => 'Rhondda Cynon Taff',
                                   'E4' => 'Essex',
                                   'F7' => 'Herefordshire',
                                   'O3' => 'Thurrock',
                                   'V6' => 'Moray',
                                   '82' => 'Grampian',
                                   'K9' => 'Redcar and Cleveland',
                                   'C5' => 'Cheshire',
                                   'H1' => 'Lambeth',
                                   'U4' => 'East Ayrshire',
                                   'H2' => 'Lancashire',
                                   'I8' => 'Newham',
                                   '07' => 'Cleveland',
                                   'A3' => 'Barnsley',
                                   'F9' => 'Hillingdon',
                                   'J6' => 'Northumberland',
                                   'K6' => 'Portsmouth',
                                   'K1' => 'Oldham',
                                   'J5' => 'North Tyneside',
                                   'D2' => 'Derby',
                                   'G8' => 'Kirklees',
                                   'Z1' => 'Swansea',
                                   'I7' => 'Newcastle upon Tyne',
                                   '79' => 'Central',
                                   'L4' => 'Rutland',
                                   'W7' => 'West Dunbartonshire',
                                   'H7' => 'Lincolnshire',
                                   'B8' => 'Bromley',
                                   '96' => 'South Glamorgan',
                                   'B5' => 'Brent',
                                   'X7' => 'Carmarthenshire',
                                   'A6' => 'Bexley',
                                   'Q7' => 'Ards',
                                   'R6' => 'Coleraine',
                                   'I3' => 'Medway',
                                   'W5' => 'South Lanarkshire',
                                   'C7' => 'Coventry',
                                   'D4' => 'Devon',
                                   'D1' => 'Darlington',
                                   'A4' => 'Bath and North East Somerset',
                                   'X4' => 'Caerphilly',
                                   'G4' => 'Kensington and Chelsea',
                                   'L7' => 'Sandwell',
                                   'Q2' => 'Wokingham',
                                   'Y3' => 'Merthyr Tydfil',
                                   'F5' => 'Hartlepool',
                                   'M7' => 'South Tyneside',
                                   'T7' => 'Angus',
                                   '37' => 'South Yorkshire',
                                   '43' => 'West Midlands',
                                   'A9' => 'Blackpool',
                                   'M9' => 'Staffordshire',
                                   'S1' => 'Dungannon',
                                   'W3' => 'Shetland Islands',
                                   'N9' => 'Swindon',
                                   'O5' => 'Tower Hamlets',
                                   'N3' => 'Stockton-on-Tees',
                                   'P2' => 'Warrington',
                                   'T4' => 'Strabane',
                                   'P9' => 'Windsor and Maidenhead',
                                   'E9' => 'Halton',
                                   '03' => 'Berkshire',
                                   'G7' => 'Kingston upon Thames',
                                   'N5' => 'Suffolk',
                                   'I6' => 'Milton Keynes',
                                   'C2' => 'Calderdale',
                                   'P7' => 'Wigan',
                                   'V4' => 'Inverclyde',
                                   'F8' => 'Hertford',
                                   '01' => 'Avon',
                                   'W4' => 'South Ayrshire',
                                   'O9' => 'Waltham Forest',
                                   'E6' => 'Gloucestershire',
                                   'R4' => 'Carrickfergus',
                                   'R5' => 'Castlereagh',
                                   '92' => 'Gwent',
                                   'E2' => 'East Sussex',
                                   'J1' => 'Northamptonshire',
                                   'L9' => 'Sheffield',
                                   'O7' => 'Wakefield',
                                   'P4' => 'West Berkshire',
                                   'R2' => 'Banbridge',
                                   'K4' => 'Plymouth',
                                   'S3' => 'Larne',
                                   'Y2' => 'Gwynedd',
                                   'H8' => 'Liverpool',
                                   'J8' => 'Nottingham',
                                   'D6' => 'Dorset',
                                   'I4' => 'Merton',
                                   'Y5' => 'Neath Port Talbot',
                                   '91' => 'Dyfed',
                                   '87' => 'Strathclyde',
                                   'S8' => 'Moyle',
                                   'X2' => 'Blaenau Gwent',
                                   'P6' => 'West Sussex',
                                   'F2' => 'Hampshire',
                                   'S5' => 'Lisburn',
                                   'R9' => 'Down',
                                   'D8' => 'Durham',
                                   'Z2' => 'Torfaen',
                                   'Y7' => 'Pembrokeshire',
                                   'K2' => 'Oxfordshire',
                                   'S6' => 'Derry',
                                   '97' => 'West Glamorgan',
                                   'N7' => 'Surrey',
                                   'U2' => 'Dumfries and Galloway',
                                   '41' => 'Tyne and Wear',
                                   'U9' => 'Falkirk',
                                   'H4' => 'Leicester',
                                   'B7' => 'Bristol, City of',
                                   'J3' => 'North Lincolnshire',
                                   '45' => 'West Yorkshire',
                                   'M2' => 'Solihull',
                                   'G1' => 'Hounslow',
                                   'K7' => 'Reading',
                                   'H5' => 'Leicestershire',
                                   'B4' => 'Bradford',
                                   'G3' => 'Islington',
                                   'A2' => 'Barnet',
                                   'U5' => 'East Dunbartonshire',
                                   'D5' => 'Doncaster',
                                   '88' => 'Tayside',
                                   'A8' => 'Blackburn with Darwen',
                                   'U7' => 'East Renfrewshire',
                                   'Q6' => 'Antrim',
                                   'C6' => 'Cornwall',
                                   'X5' => 'Cardiff',
                                   '28' => 'Merseyside',
                                   'D9' => 'Ealing',
                                   'R7' => 'Cookstown',
                                   'C4' => 'Camden',
                                   'Q4' => 'Worcestershire',
                                   'I2' => 'Manchester',
                                   'F1' => 'Hammersmith and Fulham',
                                   'L5' => 'Salford',
                                   'F4' => 'Harrow',
                                   'C9' => 'Cumbria',
                                   'D3' => 'Derbyshire',
                                   'G9' => 'Knowsley',
                                   'T8' => 'Argyll and Bute',
                                   'Z4' => 'Wrexham',
                                   'E1' => 'East Riding of Yorkshire',
                                   'M4' => 'Southampton',
                                   '22' => 'Humberside',
                                   'T6' => 'Aberdeenshire',
                                   'S2' => 'Fermanagh',
                                   'L8' => 'Sefton',
                                   'B2' => 'Bournemouth',
                                   'Q9' => 'Ballymena',
                                   'W9' => 'West Lothian',
                                   'A7' => 'Birmingham',
                                   'M6' => 'South Gloucestershire',
                                   'N1' => 'St. Helens',
                                   'Y4' => 'Monmouthshire',
                                   'K5' => 'Poole',
                                   'I9' => 'Norfolk',
                                   'G5' => 'Kent',
                                   'O2' => 'Telford and Wrekin',
                                   'A5' => 'Bedfordshire',
                                   '94' => 'Mid Glamorgan',
                                   'K8' => 'Redbridge',
                                   'V2' => 'Glasgow City',
                                   'J7' => 'North Yorkshire',
                                   'Q1' => 'Wirral',
                                   'Y8' => 'Powys',
                                   'B9' => 'Buckinghamshire',
                                   'C3' => 'Cambridgeshire',
                                   'L3' => 'Rotherham',
                                   'J4' => 'North Somerset',
                                   'E5' => 'Gateshead',
                                   'W6' => 'Stirling',
                                   'O6' => 'Trafford'
                         },
                         'BB' => {
                                   '11' => 'Saint Thomas',
                                   '01' => 'Christ Church',
                                   '05' => 'Saint John',
                                   '04' => 'Saint James',
                                   '02' => 'Saint Andrew',
                                   '07' => 'Saint Lucy',
                                   '03' => 'Saint George',
                                   '08' => 'Saint Michael',
                                   '06' => 'Saint Joseph',
                                   '10' => 'Saint Philip',
                                   '09' => 'Saint Peter'
                         },
                         'HT' => {
                                   '11' => 'Ouest',
                                   '12' => 'Sud',
                                   '14' => 'Grand\' Anse',
                                   '15' => 'Nippes',
                                   '07' => 'Centre',
                                   '03' => 'Nord-Ouest',
                                   '13' => 'Sud-Est',
                                   '06' => 'Artibonite',
                                   '10' => 'Nord-Est',
                                   '09' => 'Nord'
                         },
                         'DK' => {
                                   '11' => 'Sonderjylland',
                                   '21' => 'Syddanmark',
                                   '05' => 'Kobenhavn',
                                   '04' => 'Fyn',
                                   '17' => 'Hovedstaden',
                                   '02' => 'Bornholm',
                                   '18' => 'Midtjyllen',
                                   '08' => 'Ribe',
                                   '03' => 'Frederiksborg',
                                   '06' => 'Staden Kobenhavn',
                                   '13' => 'Vejle',
                                   '01' => 'Arhus',
                                   '12' => 'Storstrom',
                                   '20' => 'Sjelland',
                                   '14' => 'Vestsjalland',
                                   '15' => 'Viborg',
                                   '07' => 'Nordjylland',
                                   '10' => 'Roskilde',
                                   '19' => 'Nordjylland',
                                   '09' => 'Ringkobing'
                         },
                         'PA' => {
                                   '01' => 'Bocas del Toro',
                                   '05' => 'Darien',
                                   '04' => 'Colon',
                                   '02' => 'Chiriqui',
                                   '07' => 'Los Santos',
                                   '03' => 'Cocle',
                                   '08' => 'Panama',
                                   '10' => 'Veraguas',
                                   '06' => 'Herrera',
                                   '09' => 'San Blas'
                         },
                         'QA' => {
                                   '11' => 'Jariyan al Batnah',
                                   '01' => 'Ad Dawhah',
                                   '05' => 'Al Wakrah Municipality',
                                   '04' => 'Al Khawr',
                                   '12' => 'Umm Sa\'id',
                                   '02' => 'Al Ghuwariyah',
                                   '03' => 'Al Jumaliyah',
                                   '08' => 'Madinat ach Shamal',
                                   '10' => 'Al Wakrah',
                                   '06' => 'Ar Rayyan',
                                   '09' => 'Umm Salal'
                         },
                         'CV' => {
                                   '11' => 'Sao Vicente',
                                   '05' => 'Paul',
                                   '04' => 'Maio',
                                   '17' => 'Sao Domingos',
                                   '02' => 'Brava',
                                   '18' => 'Sao Filipe',
                                   '08' => 'Sal',
                                   '16' => 'Santa Cruz',
                                   '13' => 'Mosteiros',
                                   '01' => 'Boa Vista',
                                   '14' => 'Praia',
                                   '15' => 'Santa Catarina',
                                   '20' => 'Tarrafal',
                                   '07' => 'Ribeira Grande',
                                   '10' => 'Sao Nicolau',
                                   '19' => 'Sao Miguel'
                         },
                         'GD' => {
                                   '01' => 'Saint Andrew',
                                   '03' => 'Saint George',
                                   '05' => 'Saint Mark',
                                   '06' => 'Saint Patrick',
                                   '04' => 'Saint John',
                                   '02' => 'Saint David'
                         },
                         'MO' => {
                                   '01' => 'Ilhas',
                                   '02' => 'Macau'
                         },
                         'KM' => {
                                   '01' => 'Anjouan',
                                   '03' => 'Moheli',
                                   '02' => 'Grande Comore'
                         },
                         'HR' => {
                                   '11' => 'Pozesko-Slavonska',
                                   '21' => 'Grad Zagreb',
                                   '05' => 'Karlovacka',
                                   '04' => 'Istarska',
                                   '17' => 'Viroviticko-Podravska',
                                   '02' => 'Brodsko-Posavska',
                                   '18' => 'Vukovarsko-Srijemska',
                                   '08' => 'Licko-Senjska',
                                   '03' => 'Dubrovacko-Neretvanska',
                                   '06' => 'Koprivnicko-Krizevacka',
                                   '13' => 'Sibensko-Kninska',
                                   '16' => 'Varazdinska',
                                   '01' => 'Bjelovarsko-Bilogorska',
                                   '12' => 'Primorsko-Goranska',
                                   '15' => 'Splitsko-Dalmatinska',
                                   '20' => 'Zagrebacka',
                                   '14' => 'Sisacko-Moslavacka',
                                   '07' => 'Krapinsko-Zagorska',
                                   '10' => 'Osjecko-Baranjska',
                                   '19' => 'Zadarska',
                                   '09' => 'Medimurska'
                         },
                         'KW' => {
                                   '07' => 'Al Farwaniyah',
                                   '01' => 'Al Ahmadi',
                                   '05' => 'Al Jahra',
                                   '08' => 'Hawalli',
                                   '09' => 'Mubarak al Kabir',
                                   '02' => 'Al Kuwayt'
                         },
                         'CZ' => {
                                   '33' => 'Liberec',
                                   '21' => 'Jablonec nad Nisou',
                                   '90' => 'Zlinsky kraj',
                                   '70' => 'Trutnov',
                                   '80' => 'Vysocina',
                                   '04' => 'Breclav',
                                   '78' => 'Jihomoravsky kraj',
                                   '79' => 'Jihocesky kraj',
                                   '87' => 'Plzensky kraj',
                                   '88' => 'Stredocesky kraj',
                                   '03' => 'Blansko',
                                   '30' => 'Kolin',
                                   '23' => 'Jicin',
                                   '82' => 'Kralovehradecky kraj',
                                   '84' => 'Olomoucky kraj',
                                   '39' => 'Nachod',
                                   '85' => 'Moravskoslezsky kraj',
                                   '36' => 'Melnik',
                                   '83' => 'Liberecky kraj',
                                   '61' => 'Semily',
                                   '41' => 'Nymburk',
                                   '20' => 'Hradec Kralove',
                                   '52' => 'Hlavni mesto Praha',
                                   '81' => 'Karlovarsky kraj',
                                   '45' => 'Pardubice',
                                   '37' => 'Mlada Boleslav',
                                   '24' => 'Jihlava',
                                   '89' => 'Ustecky kraj',
                                   '86' => 'Pardubicky kraj'
                         },
                         'ES' => {
                                   '32' => 'Navarra',
                                   '53' => 'Canarias',
                                   '29' => 'Madrid',
                                   '55' => 'Castilla y Leon',
                                   '27' => 'La Rioja',
                                   '39' => 'Cantabria',
                                   '57' => 'Extremadura',
                                   '51' => 'Andalucia',
                                   '58' => 'Galicia',
                                   '52' => 'Aragon',
                                   '07' => 'Islas Baleares',
                                   '59' => 'Pais Vasco',
                                   '60' => 'Comunidad Valenciana',
                                   '34' => 'Asturias',
                                   '56' => 'Catalonia',
                                   '31' => 'Murcia',
                                   '54' => 'Castilla-La Mancha'
                         },
                         'MZ' => {
                                   '11' => 'Maputo',
                                   '01' => 'Cabo Delgado',
                                   '05' => 'Sofala',
                                   '04' => 'Maputo',
                                   '02' => 'Gaza',
                                   '07' => 'Niassa',
                                   '03' => 'Inhambane',
                                   '08' => 'Tete',
                                   '06' => 'Nampula',
                                   '10' => 'Manica',
                                   '09' => 'Zambezia'
                         },
                         'BO' => {
                                   '01' => 'Chuquisaca',
                                   '05' => 'Oruro',
                                   '04' => 'La Paz',
                                   '02' => 'Cochabamba',
                                   '07' => 'Potosi',
                                   '03' => 'El Beni',
                                   '08' => 'Santa Cruz',
                                   '06' => 'Pando',
                                   '09' => 'Tarija'
                         },
                         'ST' => {
                                   '01' => 'Principe',
                                   '02' => 'Sao Tome'
                         },
                         'AU' => {
                                   '07' => 'Victoria',
                                   '01' => 'Australian Capital Territory',
                                   '08' => 'Western Australia',
                                   '03' => 'Northern Territory',
                                   '05' => 'South Australia',
                                   '06' => 'Tasmania',
                                   '04' => 'Queensland',
                                   '02' => 'New South Wales'
                         },
                         'AL' => {
                                   '50' => 'Tirane',
                                   '40' => 'Berat',
                                   '51' => 'Vlore',
                                   '41' => 'Diber',
                                   '47' => 'Kukes',
                                   '48' => 'Lezhe',
                                   '42' => 'Durres',
                                   '46' => 'Korce',
                                   '49' => 'Shkoder',
                                   '45' => 'Gjirokaster',
                                   '43' => 'Elbasan',
                                   '44' => 'Fier'
                         },
                         'IR' => {
                                   '32' => 'Ardabil',
                                   '33' => 'East Azarbaijan',
                                   '21' => 'Zanjan',
                                   '05' => 'Kohkiluyeh va Buyer Ahmadi',
                                   '26' => 'Tehran',
                                   '04' => 'Sistan va Baluchestan',
                                   '17' => 'Mazandaran',
                                   '02' => 'Azarbayjan-e Khavari',
                                   '18' => 'Semnān Province',
                                   '03' => 'Chahar Mahall va Bakhtiari',
                                   '30' => 'Khorasan',
                                   '16' => 'Kordestan',
                                   '27' => 'Zanjan',
                                   '25' => 'Semnan',
                                   '01' => 'Azarbayjan-e Bakhtari',
                                   '28' => 'Esfahan',
                                   '40' => 'Yazd',
                                   '07' => 'Fars',
                                   '24' => 'Markazi',
                                   '10' => 'Ilam',
                                   '31' => 'Yazd',
                                   '35' => 'Mazandaran',
                                   '11' => 'Hormozgan',
                                   '22' => 'Bushehr',
                                   '42' => 'Khorasan-e Razavi',
                                   '08' => 'Gilan',
                                   '13' => 'Bakhtaran',
                                   '23' => 'Lorestan',
                                   '29' => 'Kerman',
                                   '39' => 'Qom',
                                   '36' => 'Zanjan',
                                   '12' => 'Kerman',
                                   '41' => 'Khorasan-e Janubi',
                                   '15' => 'Khuzestan',
                                   '38' => 'Qazvin',
                                   '34' => 'Markazi',
                                   '37' => 'Golestan',
                                   '43' => 'Khorasan-e Shemali',
                                   '19' => 'Markazi',
                                   '09' => 'Hamadan'
                         },
                         'CG' => {
                                   '11' => 'Pool',
                                   '01' => 'Bouenza',
                                   '05' => 'Lekoumou',
                                   '04' => 'Kouilou',
                                   '12' => 'Brazzaville',
                                   '07' => 'Niari',
                                   '03' => 'Cuvette',
                                   '08' => 'Plateaux',
                                   '10' => 'Sangha',
                                   '06' => 'Likouala'
                         },
                         'TR' => {
                                   '32' => 'Icel',
                                   '33' => 'Isparta',
                                   '21' => 'Diyarbakir',
                                   '63' => 'Sanliurfa',
                                   '90' => 'Kilis',
                                   '71' => 'Konya',
                                   '26' => 'Eskisehir',
                                   '80' => 'Sirnak',
                                   '02' => 'Adiyaman',
                                   '03' => 'Afyonkarahisar',
                                   '72' => 'Mardin',
                                   '16' => 'Bursa',
                                   '44' => 'Malatya',
                                   '55' => 'Samsun',
                                   '84' => 'Kars',
                                   '74' => 'Siirt',
                                   '57' => 'Sinop',
                                   '61' => 'Trabzon',
                                   '20' => 'Denizli',
                                   '92' => 'Yalova',
                                   '89' => 'Karabuk',
                                   '10' => 'Balikesir',
                                   '31' => 'Hatay',
                                   '35' => 'Izmir',
                                   '11' => 'Bilecik',
                                   '91' => 'Osmaniye',
                                   '78' => 'Karaman',
                                   '48' => 'Mugla',
                                   '87' => 'Bartin',
                                   '93' => 'Duzce',
                                   '77' => 'Bayburt',
                                   '08' => 'Artvin',
                                   '65' => 'Van',
                                   '50' => 'Nevsehir',
                                   '39' => 'Kirklareli',
                                   '64' => 'Usak',
                                   '12' => 'Bingol',
                                   '41' => 'Kocaeli',
                                   '58' => 'Sivas',
                                   '15' => 'Burdur',
                                   '52' => 'Ordu',
                                   '81' => 'Adana',
                                   '60' => 'Tokat',
                                   '45' => 'Manisa',
                                   '66' => 'Yozgat',
                                   '73' => 'Nigde',
                                   '19' => 'Corum',
                                   '76' => 'Batman',
                                   '86' => 'Ardahan',
                                   '09' => 'Aydin',
                                   '62' => 'Tunceli',
                                   '54' => 'Sakarya',
                                   '05' => 'Amasya',
                                   '70' => 'Hakkari',
                                   '68' => 'Ankara',
                                   '04' => 'Agri',
                                   '17' => 'Canakkale',
                                   '88' => 'Igdir',
                                   '82' => 'Cankiri',
                                   '25' => 'Erzurum',
                                   '28' => 'Giresun',
                                   '83' => 'Gaziantep',
                                   '40' => 'Kirsehir',
                                   '75' => 'Aksaray',
                                   '14' => 'Bolu',
                                   '69' => 'Gumushane',
                                   '59' => 'Tekirdag',
                                   '07' => 'Antalya',
                                   '49' => 'Mus',
                                   '24' => 'Erzincan',
                                   '53' => 'Rize',
                                   '79' => 'Kirikkale',
                                   '22' => 'Edirne',
                                   '46' => 'Kahramanmaras',
                                   '13' => 'Bitlis',
                                   '23' => 'Elazig',
                                   '85' => 'Zonguldak',
                                   '38' => 'Kayseri',
                                   '34' => 'Istanbul',
                                   '37' => 'Kastamonu',
                                   '43' => 'Kutahya'
                         },
                         'MD' => {
                                   '67' => 'Causeni',
                                   '63' => 'Briceni',
                                   '90' => 'Taraclia',
                                   '70' => 'Donduseni',
                                   '71' => 'Drochia',
                                   '68' => 'Cimislia',
                                   '80' => 'Nisporeni',
                                   '88' => 'Stefan-Voda',
                                   '72' => 'Dubasari',
                                   '55' => 'Tighina',
                                   '84' => 'Riscani',
                                   '74' => 'Falesti',
                                   '83' => 'Rezina',
                                   '75' => 'Floresti',
                                   '61' => 'Basarabeasca',
                                   '59' => 'Anenii Noi',
                                   '92' => 'Ungheni',
                                   '69' => 'Criuleni',
                                   '49' => 'Stinga Nistrului',
                                   '89' => 'Straseni',
                                   '53' => 'Orhei',
                                   '91' => 'Telenesti',
                                   '78' => 'Ialoveni',
                                   '48' => 'Chisinau',
                                   '79' => 'Leova',
                                   '87' => 'Soroca',
                                   '77' => 'Hincesti',
                                   '46' => 'Balti',
                                   '65' => 'Cantemir',
                                   '50' => 'Edinet',
                                   '85' => 'Singerei',
                                   '64' => 'Cahul',
                                   '51' => 'Gagauzia',
                                   '58' => 'Stinga Nistrului',
                                   '47' => 'Cahul',
                                   '52' => 'Lapusna',
                                   '81' => 'Ocnita',
                                   '60' => 'Balti',
                                   '56' => 'Ungheni',
                                   '73' => 'Edinet',
                                   '66' => 'Calarasi',
                                   '76' => 'Glodeni',
                                   '86' => 'Soldanesti',
                                   '62' => 'Bender',
                                   '54' => 'Soroca'
                         },
                         'BI' => {
                                   '11' => 'Cankuzo',
                                   '21' => 'Ruyigi',
                                   '12' => 'Cibitoke',
                                   '17' => 'Makamba',
                                   '20' => 'Rutana',
                                   '15' => 'Kayanza',
                                   '14' => 'Karuzi',
                                   '02' => 'Bujumbura',
                                   '22' => 'Muramvya',
                                   '18' => 'Muyinga',
                                   '19' => 'Ngozi',
                                   '10' => 'Bururi',
                                   '13' => 'Gitega',
                                   '23' => 'Mwaro',
                                   '16' => 'Kirundo',
                                   '09' => 'Bubanza'
                         },
                         'GN' => {
                                   '32' => 'Kankan',
                                   '33' => 'Koubia',
                                   '21' => 'Macenta',
                                   '05' => 'Dabola',
                                   '04' => 'Conakry',
                                   '17' => 'Kissidougou',
                                   '02' => 'Boffa',
                                   '18' => 'Koundara',
                                   '03' => 'Boke',
                                   '30' => 'Coyah',
                                   '06' => 'Dalaba',
                                   '16' => 'Kindia',
                                   '27' => 'Telimele',
                                   '25' => 'Pita',
                                   '28' => 'Tougue',
                                   '01' => 'Beyla',
                                   '07' => 'Dinguiraye',
                                   '10' => 'Forecariah',
                                   '31' => 'Dubreka',
                                   '35' => 'Lelouma',
                                   '11' => 'Fria',
                                   '22' => 'Mali',
                                   '13' => 'Gueckedou',
                                   '23' => 'Mamou',
                                   '29' => 'Yomou',
                                   '39' => 'Siguiri',
                                   '36' => 'Lola',
                                   '12' => 'Gaoual',
                                   '15' => 'Kerouane',
                                   '38' => 'Nzerekore',
                                   '34' => 'Labe',
                                   '37' => 'Mandiana',
                                   '19' => 'Kouroussa',
                                   '09' => 'Faranah'
                         },
                         'GW' => {
                                   '11' => 'Bissau',
                                   '01' => 'Bafata',
                                   '05' => 'Bolama',
                                   '04' => 'Oio',
                                   '12' => 'Biombo',
                                   '02' => 'Quinara',
                                   '07' => 'Tombali',
                                   '06' => 'Cacheu',
                                   '10' => 'Gabu'
                         },
                         'MK' => {
                                   '32' => 'Gazi Baba',
                                   '33' => 'Gevgelija',
                                   '21' => 'Debar',
                                   '63' => 'Makedonski Brod',
                                   '90' => 'Saraj',
                                   '71' => 'Novaci',
                                   '26' => 'Dobrusevo',
                                   '80' => 'Plasnica',
                                   'B6' => 'Vranestica',
                                   '02' => 'Bac',
                                   'C1' => 'Zajas',
                                   '99' => 'Struga',
                                   '18' => 'Centar Zupa',
                                   '03' => 'Belcista',
                                   '72' => 'Novo Selo',
                                   '16' => 'Cegrane',
                                   '44' => 'Kisela Voda',
                                   '55' => 'Kuklis',
                                   'C2' => 'Zelenikovo',
                                   '27' => 'Dolna Banjica',
                                   '74' => 'Ohrid',
                                   '84' => 'Radovis',
                                   '01' => 'Aracinovo',
                                   'B1' => 'Veles',
                                   '57' => 'Kumanovo',
                                   '95' => 'Staravina',
                                   '61' => 'Lukovo',
                                   '20' => 'Cucer-Sandevo',
                                   '92' => 'Sopiste',
                                   '89' => 'Samokov',
                                   '10' => 'Bogovinje',
                                   '31' => 'Dzepciste',
                                   '35' => 'Gradsko',
                                   '11' => 'Bosilovo',
                                   '91' => 'Sipkovica',
                                   '78' => 'Pehcevo',
                                   '48' => 'Kondovo',
                                   '87' => 'Rosoman',
                                   '77' => 'Oslomej',
                                   '93' => 'Sopotnica',
                                   '08' => 'Bogdanci',
                                   '29' => 'Dorce Petrov',
                                   '65' => 'Meseista',
                                   '50' => 'Kosel',
                                   '39' => 'Kamenjane',
                                   '64' => 'Mavrovi Anovi',
                                   '97' => 'Staro Nagoricane',
                                   '12' => 'Brvenica',
                                   '41' => 'Karpos',
                                   '58' => 'Labunista',
                                   '15' => 'Caska',
                                   '52' => 'Kriva Palanka',
                                   '81' => 'Podares',
                                   'B7' => 'Vrapciste',
                                   '60' => 'Lozovo',
                                   'B3' => 'Vevcani',
                                   '56' => 'Kukurecani',
                                   '45' => 'Klecevce',
                                   '66' => 'Miravci',
                                   '73' => 'Oblesevo',
                                   '19' => 'Cesinovo',
                                   '76' => 'Orizari',
                                   '86' => 'Resen',
                                   '09' => 'Bogomila',
                                   '62' => 'Makedonska Kamenica',
                                   '54' => 'Krusevo',
                                   '67' => 'Mogila',
                                   'A1' => 'Strumica',
                                   '05' => 'Bistrica',
                                   '70' => 'Negotino-Polosko',
                                   'B4' => 'Vinica',
                                   '68' => 'Murtino',
                                   'A2' => 'Studenicani',
                                   '17' => 'Centar',
                                   '04' => 'Berovo',
                                   '88' => 'Rostusa',
                                   'A8' => 'Valandovo',
                                   '30' => 'Drugovo',
                                   '06' => 'Bitola',
                                   '82' => 'Prilep',
                                   '25' => 'Demir Kapija',
                                   'C6' => 'Zrnovci',
                                   '28' => 'Dolneni',
                                   'C5' => 'Zletovo',
                                   '40' => 'Karbinci',
                                   '75' => 'Orasac',
                                   '83' => 'Probistip',
                                   '14' => 'Capari',
                                   'C4' => 'Zitose',
                                   '59' => 'Lipkovo',
                                   '07' => 'Blatec',
                                   '69' => 'Negotino',
                                   'A3' => 'Suto Orizari',
                                   '49' => 'Konopiste',
                                   '24' => 'Demir Hisar',
                                   '53' => 'Krivogastani',
                                   '79' => 'Petrovec',
                                   '42' => 'Kavadarci',
                                   '22' => 'Delcevo',
                                   '46' => 'Kocani',
                                   '13' => 'Cair',
                                   '23' => 'Delogozdi',
                                   'B2' => 'Velesta',
                                   'B8' => 'Vratnica',
                                   '96' => 'Star Dojran',
                                   'A7' => 'Topolcani',
                                   'B5' => 'Vitoliste',
                                   '85' => 'Rankovce',
                                   '36' => 'Ilinden',
                                   'A6' => 'Tetovo',
                                   '94' => 'Srbinovo',
                                   'A5' => 'Tearce',
                                   '51' => 'Kratovo',
                                   'A4' => 'Sveti Nikole',
                                   '47' => 'Konce',
                                   '38' => 'Jegunovce',
                                   '98' => 'Stip',
                                   'B9' => 'Vrutok',
                                   '34' => 'Gostivar',
                                   'C3' => 'Zelino',
                                   '37' => 'Izvor',
                                   '43' => 'Kicevo',
                                   'A9' => 'Vasilevo'
                         },
                         'GR' => {
                                   '32' => 'Fokis',
                                   '33' => 'Voiotia',
                                   '21' => 'Larisa',
                                   '05' => 'Serrai',
                                   '26' => 'Levkas',
                                   '04' => 'Drama',
                                   '17' => 'Ioannina',
                                   '02' => 'Rodhopi',
                                   '18' => 'Thesprotia',
                                   '03' => 'Xanthi',
                                   '30' => 'Evritania',
                                   '06' => 'Kilkis',
                                   '16' => 'Pieria',
                                   '44' => 'Rethimni',
                                   '27' => 'Kefallinia',
                                   '25' => 'Kerkira',
                                   '01' => 'Evros',
                                   '28' => 'Zakinthos',
                                   '40' => 'Messinia',
                                   '14' => 'Kavala',
                                   '20' => 'Arta',
                                   '07' => 'Pella',
                                   '49' => 'Kikladhes',
                                   '24' => 'Magnisia',
                                   '10' => 'Grevena',
                                   '31' => 'Aitolia kai Akarnania',
                                   '35' => 'Attiki',
                                   '11' => 'Kozani',
                                   '48' => 'Samos',
                                   '42' => 'Lakonia',
                                   '22' => 'Trikala',
                                   '08' => 'Florina',
                                   '46' => 'Lasithi',
                                   '23' => 'Kardhitsa',
                                   '13' => 'Thessaloniki',
                                   '29' => 'Fthiotis',
                                   '50' => 'Khios',
                                   '39' => 'Ilia',
                                   '36' => 'Argolis',
                                   '51' => 'Lesvos',
                                   '12' => 'Imathia',
                                   '41' => 'Arkadhia',
                                   '15' => 'Khalkidhiki',
                                   '47' => 'Dhodhekanisos',
                                   '38' => 'Akhaia',
                                   '34' => 'Evvoia',
                                   '37' => 'Korinthia',
                                   '45' => 'Iraklion',
                                   '19' => 'Preveza',
                                   '43' => 'Khania',
                                   '09' => 'Kastoria'
                         },
                         'AG' => {
                                   '07' => 'Saint Peter',
                                   '01' => 'Barbuda',
                                   '03' => 'Saint George',
                                   '05' => 'Saint Mary',
                                   '08' => 'Saint Philip',
                                   '06' => 'Saint Paul',
                                   '04' => 'Saint John'
                         },
                         'SI' => {
                                   '32' => 'Grosuplje',
                                   '71' => 'Medvode',
                                   'N2' => 'Videm',
                                   'B6' => 'Sevnica',
                                   '02' => 'Beltinci',
                                   'C1' => 'Skofljica',
                                   'J2' => 'Maribor',
                                   'L1' => 'Ribnica',
                                   'I5' => 'Litija',
                                   'J9' => 'Piran',
                                   '16' => 'Crna na Koroskem',
                                   '44' => 'Kanal',
                                   'C8' => 'Starse',
                                   '55' => 'Kungota',
                                   '84' => 'Nova Gorica',
                                   '27' => 'Gorenja Vas-Poljane',
                                   'E7' => 'Zagorje ob Savi',
                                   'B1' => 'Semic',
                                   '57' => 'Lasko',
                                   '20' => 'Dobrepolje',
                                   'F3' => 'Zrece',
                                   '89' => 'Pesnica',
                                   '31' => 'Gornji Petrovci',
                                   '35' => 'Hrpelje-Kozina',
                                   '11' => 'Celje',
                                   '78' => 'Moravske Toplice',
                                   '29' => 'Gornja Radgona',
                                   'E3' => 'Vodice',
                                   '15' => 'Crensovci',
                                   '81' => 'Muta',
                                   'D7' => 'Velenje',
                                   'B3' => 'Sentilj',
                                   '73' => 'Metlika',
                                   '76' => 'Mislinja',
                                   '86' => 'Odranci',
                                   '09' => 'Brezovica',
                                   '62' => 'Ljubno',
                                   'H6' => 'Kamnik',
                                   'A1' => 'Radenci',
                                   '05' => 'Borovnica',
                                   '17' => 'Crnomelj',
                                   '82' => 'Naklo',
                                   'C5' => 'Smarje pri Jelsah',
                                   '14' => 'Cerkno',
                                   '07' => 'Brda',
                                   'A3' => 'Radovljica',
                                   '49' => 'Komen',
                                   '24' => 'Dornava',
                                   'J5' => 'Miren-Kostanjevica',
                                   'D2' => 'Tolmin',
                                   'I7' => 'Loska Dolina',
                                   '79' => 'Mozirje',
                                   'H7' => 'Kocevje',
                                   'B8' => 'Skocjan',
                                   'A6' => 'Rogasovci',
                                   'I3' => 'Lenart',
                                   'C7' => 'Sostanj',
                                   'D4' => 'Trebnje',
                                   'D1' => 'Sveti Jurij',
                                   'L7' => 'Sentjur pri Celju',
                                   'G4' => 'Dobrova-Horjul-Polhov Gradec',
                                   '47' => 'Kobilje',
                                   '98' => 'Racam',
                                   '37' => 'Ig',
                                   'N3' => 'Vojnik',
                                   '26' => 'Duplek',
                                   '80' => 'Murska Sobota',
                                   '99' => 'Radece',
                                   '03' => 'Bled',
                                   '72' => 'Menges',
                                   'E9' => 'Zavrc',
                                   'N5' => 'Zalec',
                                   'G7' => 'Domzale',
                                   'C2' => 'Slovenj Gradec',
                                   'I6' => 'Ljutomer',
                                   '74' => 'Mezica',
                                   '01' => 'Ajdovscina',
                                   '61' => 'Ljubljana',
                                   'E6' => 'Vuzenica',
                                   '92' => 'Podcetrtek',
                                   'E2' => 'Vitanje',
                                   'J1' => 'Majsperk',
                                   'D6' => 'Turnisce',
                                   '91' => 'Pivka',
                                   '87' => 'Ormoz',
                                   '77' => 'Moravce',
                                   '08' => 'Brezice',
                                   'F2' => 'Ziri',
                                   'D8' => 'Velike Lasce',
                                   '50' => 'Koper-Capodistria',
                                   '39' => 'Ivancna Gorica',
                                   '64' => 'Logatec',
                                   '97' => 'Puconci',
                                   '12' => 'Cerklje na Gorenjskem',
                                   '52' => 'Kranj',
                                   'B7' => 'Sezana',
                                   'H4' => 'Jesenice',
                                   '45' => 'Kidricevo',
                                   '66' => 'Loski Potok',
                                   '19' => 'Divaca',
                                   '54' => 'Krsko',
                                   'K7' => 'Ptuj',
                                   'B4' => 'Sentjernej',
                                   '68' => 'Lukovica',
                                   'A2' => 'Radlje ob Dravi',
                                   '04' => 'Bohinj',
                                   'D5' => 'Trzic',
                                   '88' => 'Osilnica',
                                   'A8' => 'Rogatec',
                                   '30' => 'Gornji Grad',
                                   '06' => 'Bovec',
                                   '25' => 'Dravograd',
                                   'C6' => 'Smartno ob Paki',
                                   '28' => 'Gorisnica',
                                   '40' => 'Izola-Isola',
                                   '83' => 'Nazarje',
                                   'C4' => 'Slovenske Konjice',
                                   'I2' => 'Kuzma',
                                   'F1' => 'Zelezniki',
                                   'C9' => 'Store',
                                   '53' => 'Kranjska Gora',
                                   'D3' => 'Trbovlje',
                                   'E1' => 'Vipava',
                                   '42' => 'Jursinci',
                                   '22' => 'Dol pri Ljubljani',
                                   'L8' => 'Slovenska Bistrica',
                                   '46' => 'Kobarid',
                                   'B2' => 'Sencur',
                                   '13' => 'Cerknica',
                                   'A7' => 'Rogaska Slatina',
                                   'K5' => 'Preddvor',
                                   'I9' => 'Luce',
                                   '36' => 'Idrija',
                                   '94' => 'Postojna',
                                   '51' => 'Kozje',
                                   'J7' => 'Novo Mesto',
                                   '38' => 'Ilirska Bistrica',
                                   'B9' => 'Skofja Loka',
                                   '34' => 'Hrastnik',
                                   'L3' => 'Ruse',
                                   'E5' => 'Vrhnika'
                         },
                         'CO' => {
                                   '32' => 'Casanare',
                                   '33' => 'Cundinamarca',
                                   '21' => 'Norte de Santander',
                                   '05' => 'Bolívar Department',
                                   '26' => 'Santander',
                                   '04' => 'Atlantico',
                                   '17' => 'La Guajira',
                                   '02' => 'Antioquia',
                                   '18' => 'Magdalena Department',
                                   '03' => 'Arauca',
                                   '30' => 'Vaupes',
                                   '16' => 'Huila',
                                   '06' => 'Boyacá Department',
                                   '27' => 'Sucre',
                                   '25' => 'San Andres y Providencia',
                                   '01' => 'Amazonas',
                                   '28' => 'Tolima',
                                   '20' => 'Narino',
                                   '14' => 'Guaviare',
                                   '07' => 'Caldas Department',
                                   '24' => 'Risaralda',
                                   '10' => 'Cesar',
                                   '31' => 'Vichada',
                                   '35' => 'Bolivar',
                                   '11' => 'Choco',
                                   '22' => 'Putumayo',
                                   '08' => 'Caqueta',
                                   '23' => 'Quindio',
                                   '29' => 'Valle del Cauca',
                                   '36' => 'Boyaca',
                                   '12' => 'Cordoba',
                                   '15' => 'Guainia',
                                   '38' => 'Magdalena',
                                   '34' => 'Distrito Especial',
                                   '37' => 'Caldas',
                                   '19' => 'Meta',
                                   '09' => 'Cauca'
                         },
                         'JO' => {
                                   '11' => 'Amman Governorate',
                                   '12' => 'At Tafilah',
                                   '02' => 'Al Balqa\'',
                                   '14' => 'Irbid',
                                   '07' => 'Ma',
                                   '10' => 'Al Mafraq',
                                   '13' => 'Az Zarqa',
                                   '16' => 'Amman',
                                   '09' => 'Al Karak'
                         },
                         'SM' => {
                                   '01' => 'Acquaviva',
                                   '05' => 'Fiorentino',
                                   '04' => 'Faetano',
                                   '02' => 'Chiesanuova',
                                   '07' => 'San Marino',
                                   '03' => 'Domagnano',
                                   '08' => 'Monte Giardino',
                                   '06' => 'Borgo Maggiore',
                                   '09' => 'Serravalle'
                         },
                         'UA' => {
                                   '11' => 'Krym',
                                   '21' => 'Sums\'ka Oblast\'',
                                   '05' => 'Donets\'ka Oblast\'',
                                   '26' => 'Zaporiz\'ka Oblast\'',
                                   '04' => 'Dnipropetrovs\'ka Oblast\'',
                                   '17' => 'Odes\'ka Oblast\'',
                                   '02' => 'Chernihivs\'ka Oblast\'',
                                   '22' => 'Ternopil\'s\'ka Oblast\'',
                                   '18' => 'Poltavs\'ka Oblast\'',
                                   '08' => 'Khersons\'ka Oblast\'',
                                   '03' => 'Chernivets\'ka Oblast\'',
                                   '06' => 'Ivano-Frankivs\'ka Oblast\'',
                                   '13' => 'Kyyivs\'ka Oblast\'',
                                   '16' => 'Mykolayivs\'ka Oblast\'',
                                   '23' => 'Vinnyts\'ka Oblast\'',
                                   '27' => 'Zhytomyrs\'ka Oblast\'',
                                   '25' => 'Zakarpats\'ka Oblast\'',
                                   '01' => 'Cherkas\'ka Oblast\'',
                                   '12' => 'Kyyiv',
                                   '15' => 'L\'vivs\'ka Oblast\'',
                                   '14' => 'Luhans\'ka Oblast\'',
                                   '20' => 'Sevastopol\'',
                                   '07' => 'Kharkivs\'ka Oblast\'',
                                   '24' => 'Volyns\'ka Oblast\'',
                                   '10' => 'Kirovohrads\'ka Oblast\'',
                                   '19' => 'Rivnens\'ka Oblast\'',
                                   '09' => 'Khmel\'nyts\'ka Oblast\''
                         },
                         'CL' => {
                            '11' => 'Maule',
                            '01' => 'Valparaiso',
                            '05' => 'Atacama',
                            '04' => 'Araucania',
                            '12' => 'Region Metropolitana',
                            '02' => 'Aisen del General Carlos Ibanez del Campo',
                            '07' => 'Coquimbo',
                            '08' => 'Libertador General Bernardo O\'Higgins',
                            '03' => 'Antofagasta',
                            '06' => 'Bio-Bio',
                            '10' => 'Magallanes y de la Antartica Chilena',
                            '13' => 'Tarapaca',
                            '09' => 'Los Lagos'
                         },
                         'CU' => {
                                   '11' => 'La Habana',
                                   '01' => 'Pinar del Rio',
                                   '05' => 'Camaguey',
                                   '04' => 'Isla de la Juventud',
                                   '12' => 'Holguin',
                                   '02' => 'Ciudad de la Habana',
                                   '14' => 'Sancti Spiritus',
                                   '15' => 'Santiago de Cuba',
                                   '07' => 'Ciego de Avila',
                                   '08' => 'Cienfuegos',
                                   '03' => 'Matanzas',
                                   '10' => 'Guantanamo',
                                   '13' => 'Las Tunas',
                                   '16' => 'Villa Clara',
                                   '09' => 'Granma'
                         },
                         'KN' => {
                                   '11' => 'Saint Peter Basseterre',
                                   '01' => 'Christ Church Nichola Town',
                                   '05' => 'Saint James Windward',
                                   '04' => 'Saint George Gingerland',
                                   '12' => 'Saint Thomas Lowland',
                                   '02' => 'Saint Anne Sandy Point',
                                   '15' => 'Trinity Palmetto Point',
                                   '07' => 'Saint John Figtree',
                                   '08' => 'Saint Mary Cayon',
                                   '03' => 'Saint George Basseterre',
                                   '06' => 'Saint John Capisterre',
                                   '10' => 'Saint Paul Charlestown',
                                   '13' => 'Saint Thomas Middle Island',
                                   '09' => 'Saint Paul Capisterre'
                         },
                         'ML' => {
                                   '01' => 'Bamako',
                                   '05' => 'Segou',
                                   '04' => 'Mopti',
                                   '07' => 'Koulikoro',
                                   '03' => 'Kayes',
                                   '08' => 'Tombouctou',
                                   '10' => 'Kidal',
                                   '06' => 'Sikasso',
                                   '09' => 'Gao'
                         },
                         'SC' => {
                                   '11' => 'Cascade',
                                   '21' => 'Port Glaud',
                                   '05' => 'Anse Royale',
                                   '04' => 'Anse Louis',
                                   '17' => 'Mont Buxton',
                                   '02' => 'Anse Boileau',
                                   '22' => 'Saint Louis',
                                   '18' => 'Mont Fleuri',
                                   '08' => 'Beau Vallon',
                                   '03' => 'Anse Etoile',
                                   '06' => 'Baie Lazare',
                                   '13' => 'Grand\' Anse',
                                   '16' => 'La Riviere Anglaise',
                                   '23' => 'Takamaka',
                                   '01' => 'Anse aux Pins',
                                   '12' => 'Glacis',
                                   '15' => 'La Digue',
                                   '14' => 'Grand\' Anse',
                                   '20' => 'Pointe La Rue',
                                   '07' => 'Baie Sainte Anne',
                                   '10' => 'Bel Ombre',
                                   '19' => 'Plaisance',
                                   '09' => 'Bel Air'
                         },
                         'ET' => {
                              '11' => 'Southern',
                              '53' => 'Tigray',
                              '02' => 'Amhara',
                              '48' => 'Dire Dawa',
                              '46' => 'Amara',
                              '08' => 'Gambella',
                              '13' => 'Benishangul',
                              '44' => 'Adis Abeba',
                              '50' => 'Hareri Hizb',
                              '51' => 'Oromiya',
                              '12' => 'Tigray',
                              '14' => 'Afar',
                              '47' => 'Binshangul Gumuz',
                              '07' => 'Somali',
                              '52' => 'Sumale',
                              '49' => 'Gambela Hizboch',
                              '45' => 'Afar',
                              '10' => 'Addis Abeba',
                              '54' => 'YeDebub Biheroch Bihereseboch na Hizboch'
                         },
                         'IS' => {
                                   '35' => 'Vestur-Hunavatnssysla',
                                   '32' => 'Sudur-Tingeyjarsysla',
                                   '21' => 'Nordur-Tingeyjarsysla',
                                   '05' => 'Austur-Hunavatnssysla',
                                   '17' => 'Myrasysla',
                                   '42' => 'Suourland',
                                   '03' => 'Arnessysla',
                                   '23' => 'Rangarvallasysla',
                                   '06' => 'Austur-Skaftafellssysla',
                                   '29' => 'Snafellsnes- og Hnappadalssysla',
                                   '44' => 'Vestfiroir',
                                   '28' => 'Skagafjardarsysla',
                                   '40' => 'Norourland Eystra',
                                   '36' => 'Vestur-Isafjardarsysla',
                                   '41' => 'Norourland Vestra',
                                   '20' => 'Nordur-Mulasysla',
                                   '15' => 'Kjosarsysla',
                                   '07' => 'Borgarfjardarsysla',
                                   '34' => 'Vestur-Bardastrandarsysla',
                                   '37' => 'Vestur-Skaftafellssysla',
                                   '45' => 'Vesturland',
                                   '10' => 'Gullbringusysla',
                                   '43' => 'Suournes',
                                   '31' => 'Sudur-Mulasysla',
                                   '09' => 'Eyjafjardarsysla'
                         },
                         'NL' => {
                                   '11' => 'Zuid-Holland',
                                   '01' => 'Drenthe',
                                   '05' => 'Limburg',
                                   '12' => 'Dronten',
                                   '04' => 'Groningen',
                                   '15' => 'Overijssel',
                                   '14' => 'Lelystad',
                                   '02' => 'Friesland',
                                   '07' => 'Noord-Holland',
                                   '03' => 'Gelderland',
                                   '08' => 'Overijssel',
                                   '10' => 'Zeeland',
                                   '06' => 'Noord-Brabant',
                                   '16' => 'Flevoland',
                                   '13' => 'Zuidelijke IJsselmeerpolders',
                                   '09' => 'Utrecht'
                         },
                         'MS' => {
                                   '01' => 'Saint Anthony',
                                   '03' => 'Saint Peter',
                                   '02' => 'Saint Georges'
                         },
                         'EC' => {
                                   '11' => 'Imbabura',
                                   '05' => 'Carchi',
                                   '04' => 'Canar',
                                   '17' => 'Pastaza',
                                   '02' => 'Azuay',
                                   '22' => 'Sucumbios',
                                   '18' => 'Pichincha',
                                   '08' => 'El Oro',
                                   '03' => 'Bolivar',
                                   '06' => 'Chimborazo',
                                   '13' => 'Los Rios',
                                   '23' => 'Napo',
                                   '01' => 'Galapagos',
                                   '12' => 'Loja',
                                   '15' => 'Morona-Santiago',
                                   '20' => 'Zamora-Chinchipe',
                                   '14' => 'Manabi',
                                   '07' => 'Cotopaxi',
                                   '24' => 'Orellana',
                                   '10' => 'Guayas',
                                   '19' => 'Tungurahua',
                                   '09' => 'Esmeraldas'
                         },
                         'MY' => {
                                   '11' => 'Sarawak',
                                   '01' => 'Johor',
                                   '05' => 'Negeri Sembilan',
                                   '12' => 'Selangor',
                                   '04' => 'Melaka',
                                   '17' => 'Putrajaya',
                                   '15' => 'Labuan',
                                   '14' => 'Kuala Lumpur',
                                   '02' => 'Kedah',
                                   '07' => 'Perak',
                                   '03' => 'Kelantan',
                                   '08' => 'Perlis',
                                   '06' => 'Pahang',
                                   '16' => 'Sabah',
                                   '13' => 'Terengganu',
                                   '09' => 'Pulau Pinang'
                         },
                         'CR' => {
                                   '07' => 'Puntarenas',
                                   '01' => 'Alajuela',
                                   '03' => 'Guanacaste',
                                   '08' => 'San Jose',
                                   '06' => 'Limon',
                                   '04' => 'Heredia',
                                   '02' => 'Cartago'
                         },
                         'SD' => {
                                   '27' => 'Al Wusta',
                                   '35' => 'Upper Nile',
                                   '32' => 'Bahr al Ghazal',
                                   '33' => 'Darfur',
                                   '28' => 'Al Istiwa\'iyah',
                                   '34' => 'Kurdufan',
                                   '30' => 'Ash Shamaliyah',
                                   '29' => 'Al Khartum',
                                   '31' => 'Ash Sharqiyah'
                         },
                         'RS' => {
                                   '01' => 'Kosovo',
                                   '00' => 'Serbia proper',
                                   '02' => 'Vojvodina'
                         },
                         'CN' => {
                                   '11' => 'Hunan',
                                   '32' => 'Sichuan',
                                   '33' => 'Chongqing',
                                   '21' => 'Ningxia',
                                   '05' => 'Jilin',
                                   '26' => 'Shaanxi',
                                   '04' => 'Jiangsu',
                                   '02' => 'Zhejiang',
                                   '22' => 'Beijing',
                                   '18' => 'Guizhou',
                                   '08' => 'Heilongjiang',
                                   '03' => 'Jiangxi',
                                   '30' => 'Guangdong',
                                   '06' => 'Qinghai',
                                   '13' => 'Xinjiang',
                                   '16' => 'Guangxi',
                                   '23' => 'Shanghai',
                                   '29' => 'Yunnan',
                                   '25' => 'Shandong',
                                   '01' => 'Anhui',
                                   '28' => 'Tianjin',
                                   '12' => 'Hubei',
                                   '15' => 'Gansu',
                                   '14' => 'Xizang',
                                   '20' => 'Nei Mongol',
                                   '07' => 'Fujian',
                                   '24' => 'Shanxi',
                                   '10' => 'Hebei',
                                   '19' => 'Liaoning',
                                   '09' => 'Henan',
                                   '31' => 'Hainan'
                         },
                         'BG' => {
                                   '33' => 'Mikhaylovgrad',
                                   '53' => 'Ruse',
                                   '63' => 'Vidin',
                                   '48' => 'Pazardzhik',
                                   '42' => 'Grad Sofiya',
                                   '46' => 'Lovech',
                                   '65' => 'Yambol',
                                   '44' => 'Kurdzhali',
                                   '55' => 'Silistra',
                                   '50' => 'Pleven',
                                   '39' => 'Burgas',
                                   '64' => 'Vratsa',
                                   '57' => 'Smolyan',
                                   '40' => 'Dobrich',
                                   '61' => 'Varna',
                                   '51' => 'Plovdiv',
                                   '58' => 'Sofiya',
                                   '41' => 'Gabrovo',
                                   '47' => 'Montana',
                                   '52' => 'Razgrad',
                                   '38' => 'Blagoevgrad',
                                   '59' => 'Stara Zagora',
                                   '60' => 'Turgovishte',
                                   '49' => 'Pernik',
                                   '56' => 'Sliven',
                                   '45' => 'Kyustendil',
                                   '43' => 'Khaskovo',
                                   '62' => 'Veliko Turnovo',
                                   '54' => 'Shumen'
                         },
                         'UY' => {
                                   '11' => 'Paysandu',
                                   '05' => 'Durazno',
                                   '04' => 'Colonia',
                                   '17' => 'Soriano',
                                   '02' => 'Canelones',
                                   '18' => 'Tacuarembo',
                                   '03' => 'Cerro Largo',
                                   '08' => 'Lavalleja',
                                   '06' => 'Flores',
                                   '13' => 'Rivera',
                                   '16' => 'San Jose',
                                   '01' => 'Artigas',
                                   '12' => 'Rio Negro',
                                   '14' => 'Rocha',
                                   '15' => 'Salto',
                                   '07' => 'Florida',
                                   '10' => 'Montevideo',
                                   '19' => 'Treinta y Tres',
                                   '09' => 'Maldonado'
                         },
                         'PY' => {
                                   '11' => 'Itapua',
                                   '21' => 'Nueva Asuncion',
                                   '05' => 'Caazapa',
                                   '04' => 'Caaguazu',
                                   '17' => 'San Pedro',
                                   '02' => 'Amambay',
                                   '03' => 'Boqueron',
                                   '08' => 'Cordillera',
                                   '06' => 'Central',
                                   '13' => 'Neembucu',
                                   '16' => 'Presidente Hayes',
                                   '23' => 'Alto Paraguay',
                                   '01' => 'Alto Parana',
                                   '12' => 'Misiones',
                                   '20' => 'Chaco',
                                   '15' => 'Paraguari',
                                   '07' => 'Concepcion',
                                   '19' => 'Canindeyu',
                                   '10' => 'Guaira'
                         },
                         'BS' => {
                                   '35' => 'San Salvador and Rum Cay',
                                   '32' => 'Nichollstown and Berry Islands',
                                   '33' => 'Rock Sound',
                                   '05' => 'Bimini',
                                   '26' => 'Fresh Creek',
                                   '22' => 'Harbour Island',
                                   '18' => 'Ragged Island',
                                   '30' => 'Kemps Bay',
                                   '23' => 'New Providence',
                                   '16' => 'Mayaguana',
                                   '13' => 'Inagua',
                                   '06' => 'Cat Island',
                                   '29' => 'High Rock',
                                   '25' => 'Freeport',
                                   '27' => 'Governor\'s Harbour',
                                   '28' => 'Green Turtle Cay',
                                   '15' => 'Long Island',
                                   '34' => 'Sandy Point',
                                   '24' => 'Acklins and Crooked Islands',
                                   '10' => 'Exuma',
                                   '31' => 'Marsh Harbour'
                         },
                         'MU' => {
                                   '21' => 'Agalega Islands',
                                   '12' => 'Black River',
                                   '17' => 'Plaines Wilhems',
                                   '14' => 'Grand Port',
                                   '15' => 'Moka',
                                   '20' => 'Savanne',
                                   '22' => 'Cargados Carajos',
                                   '18' => 'Port Louis',
                                   '19' => 'Riviere du Rempart',
                                   '16' => 'Pamplemousses',
                                   '13' => 'Flacq',
                                   '23' => 'Rodrigues'
                         },
                         'CH' => {
                                   '11' => 'Luzern',
                                   '21' => 'Uri',
                                   '05' => 'Bern',
                                   '26' => 'Jura',
                                   '04' => 'Basel-Stadt',
                                   '17' => 'Schwyz',
                                   '02' => 'Ausser-Rhoden',
                                   '22' => 'Valais',
                                   '18' => 'Solothurn',
                                   '08' => 'Glarus',
                                   '03' => 'Basel-Landschaft',
                                   '06' => 'Fribourg',
                                   '13' => 'Nidwalden',
                                   '16' => 'Schaffhausen',
                                   '23' => 'Vaud',
                                   '25' => 'Zurich',
                                   '01' => 'Aargau',
                                   '12' => 'Neuchatel',
                                   '15' => 'Sankt Gallen',
                                   '14' => 'Obwalden',
                                   '20' => 'Ticino',
                                   '07' => 'Geneve',
                                   '24' => 'Zug',
                                   '10' => 'Inner-Rhoden',
                                   '19' => 'Thurgau',
                                   '09' => 'Graubunden'
                         },
                         'LI' => {
                                   '11' => 'Vaduz',
                                   '01' => 'Balzers',
                                   '21' => 'Gbarpolu',
                                   '05' => 'Planken',
                                   '04' => 'Mauren',
                                   '02' => 'Eschen',
                                   '22' => 'River Gee',
                                   '07' => 'Schaan',
                                   '08' => 'Schellenberg',
                                   '03' => 'Gamprin',
                                   '06' => 'Ruggell',
                                   '10' => 'Triesenberg',
                                   '09' => 'Triesen'
                         },
                         'GH' => {
                                   '11' => 'Upper West',
                                   '01' => 'Greater Accra',
                                   '05' => 'Eastern',
                                   '04' => 'Central',
                                   '02' => 'Ashanti',
                                   '03' => 'Brong-Ahafo',
                                   '08' => 'Volta',
                                   '10' => 'Upper East',
                                   '06' => 'Northern',
                                   '09' => 'Western'
                         },
                         'KG' => {
                                   '01' => 'Bishkek',
                                   '05' => 'Osh',
                                   '04' => 'Naryn',
                                   '02' => 'Chuy',
                                   '07' => 'Ysyk-Kol',
                                   '03' => 'Jalal-Abad',
                                   '08' => 'Osh',
                                   '06' => 'Talas',
                                   '09' => 'Batken'
                         },
                         'US' => {
                           'LA' => 'Louisiana',
                           'SC' => 'South Carolina',
                           'GU' => 'Guam',
                           'MS' => 'Mississippi',
                           'NC' => 'North Carolina',
                           'OK' => 'Oklahoma',
                           'NY' => 'New York',
                           'VA' => 'Virginia',
                           'HI' => 'Hawaii',
                           'PA' => 'Pennsylvania',
                           'NE' => 'Nebraska',
                           'DC' => 'District of Columbia',
                           'PR' => 'Puerto Rico',
                           'SD' => 'South Dakota',
                           'OH' => 'Ohio',
                           'WV' => 'West Virginia',
                           'NM' => 'New Mexico',
                           'WI' => 'Wisconsin',
                           'MH' => 'Marshall Islands',
                           'MO' => 'Missouri',
                           'AZ' => 'Arizona',
                           'NH' => 'New Hampshire',
                           'MA' => 'Massachusetts',
                           'MT' => 'Montana',
                           'MN' => 'Minnesota',
                           'MP' => 'Northern Mariana Islands',
                           'TX' => 'Texas',
                           'ME' => 'Maine',
                           'NJ' => 'New Jersey',
                           'WY' => 'Wyoming',
                           'NV' => 'Nevada',
                           'OR' => 'Oregon',
                           'WA' => 'Washington',
                           'PW' => 'Palau',
                           'ID' => 'Idaho',
                           'FM' => 'Federated States of Micronesia',
                           'RI' => 'Rhode Island',
                           'AL' => 'Alabama',
                           'KS' => 'Kansas',
                           'TN' => 'Tennessee',
                           'UT' => 'Utah',
                           'ND' => 'North Dakota',
                           'AA' => 'Armed Forces Americas',
                           'FL' => 'Florida',
                           'CT' => 'Connecticut',
                           'AS' => 'American Samoa',
                           'MD' => 'Maryland',
                           'CA' => 'California',
                           'IA' => 'Iowa',
                           'DE' => 'Delaware',
                           'AP' => 'Armed Forces Pacific',
                           'CO' => 'Colorado',
                           'MI' => 'Michigan',
                           'IN' => 'Indiana',
                           'AR' => 'Arkansas',
                           'VI' => 'Virgin Islands',
                           'VT' => 'Vermont',
                           'GA' => 'Georgia',
                           'AE' => 'Armed Forces Europe, Middle East, & Canada',
                           'KY' => 'Kentucky',
                           'IL' => 'Illinois',
                           'AK' => 'Alaska'
                         },
                         'PE' => {
                                   '11' => 'Ica',
                                   '21' => 'Puno',
                                   '05' => 'Ayacucho',
                                   '04' => 'Arequipa',
                                   '17' => 'Madre de Dios',
                                   '02' => 'Ancash',
                                   '22' => 'San Martin',
                                   '18' => 'Moquegua',
                                   '08' => 'Cusco',
                                   '03' => 'Apurimac',
                                   '06' => 'Cajamarca',
                                   '13' => 'La Libertad',
                                   '16' => 'Loreto',
                                   '23' => 'Tacna',
                                   '25' => 'Ucayali',
                                   '01' => 'Amazonas',
                                   '12' => 'Junin',
                                   '15' => 'Lima',
                                   '14' => 'Lambayeque',
                                   '20' => 'Piura',
                                   '07' => 'Callao',
                                   '24' => 'Tumbes',
                                   '10' => 'Huanuco',
                                   '19' => 'Pasco',
                                   '09' => 'Huancavelica'
                         },
                         'SL' => {
                                   '01' => 'Eastern',
                                   '03' => 'Southern',
                                   '04' => 'Western Area',
                                   '02' => 'Northern'
                         },
                         'BZ' => {
                                   '01' => 'Belize',
                                   '03' => 'Corozal',
                                   '05' => 'Stann Creek',
                                   '06' => 'Toledo',
                                   '04' => 'Orange Walk',
                                   '02' => 'Cayo'
                         },
                         'CY' => {
                                   '01' => 'Famagusta',
                                   '03' => 'Larnaca',
                                   '05' => 'Limassol',
                                   '06' => 'Paphos',
                                   '04' => 'Nicosia',
                                   '02' => 'Kyrenia'
                         },
                         'FJ' => {
                                   '01' => 'Central',
                                   '03' => 'Northern',
                                   '05' => 'Western',
                                   '04' => 'Rotuma',
                                   '02' => 'Eastern'
                         },
                         'IE' => {
                                   '11' => 'Kerry',
                                   '21' => 'Meath',
                                   '26' => 'Tipperary',
                                   '04' => 'Cork',
                                   '02' => 'Cavan',
                                   '22' => 'Monaghan',
                                   '18' => 'Longford',
                                   '03' => 'Clare',
                                   '30' => 'Wexford',
                                   '06' => 'Donegal',
                                   '13' => 'Kilkenny',
                                   '16' => 'Limerick',
                                   '23' => 'Offaly',
                                   '29' => 'Westmeath',
                                   '27' => 'Waterford',
                                   '25' => 'Sligo',
                                   '01' => 'Carlow',
                                   '12' => 'Kildare',
                                   '20' => 'Mayo',
                                   '15' => 'Laois',
                                   '14' => 'Leitrim',
                                   '07' => 'Dublin',
                                   '24' => 'Roscommon',
                                   '19' => 'Louth',
                                   '10' => 'Galway',
                                   '31' => 'Wicklow'
                         },
                         'TW' => {
                                   '01' => 'Fu-chien',
                                   '03' => 'T\'ai-pei',
                                   '04' => 'T\'ai-wan',
                                   '02' => 'Kao-hsiung'
                         },
                         'KP' => {
                                   '11' => 'P\'yongan-bukto',
                                   '01' => 'Chagang-do',
                                   '12' => 'P\'yongyang-si',
                                   '17' => 'Hamgyong-bukto',
                                   '14' => 'Namp\'o-si',
                                   '15' => 'P\'yongan-namdo',
                                   '07' => 'Hwanghae-bukto',
                                   '18' => 'Najin Sonbong-si',
                                   '08' => 'Kaesong-si',
                                   '03' => 'Hamgyong-namdo',
                                   '06' => 'Hwanghae-namdo',
                                   '13' => 'Yanggang-do',
                                   '09' => 'Kangwon-do'
                         },
                         'ER' => {
                                   '01' => 'Anseba',
                                   '03' => 'Debubawi K\'eyih Bahri',
                                   '05' => 'Ma\'akel',
                                   '06' => 'Semenawi K\'eyih Bahri',
                                   '04' => 'Gash Barka',
                                   '02' => 'Debub'
                         },
                         'IQ' => {
                                   '11' => 'Arbil',
                                   '05' => 'As Sulaymaniyah',
                                   '04' => 'Al Qadisiyah',
                                   '17' => 'An Najaf',
                                   '02' => 'Al Basrah',
                                   '18' => 'Salah ad Din',
                                   '03' => 'Al Muthanna',
                                   '08' => 'Dahuk',
                                   '06' => 'Babil',
                                   '13' => 'At Ta\'mim',
                                   '16' => 'Wasit',
                                   '01' => 'Al Anbar',
                                   '12' => 'Karbala\'',
                                   '14' => 'Maysan',
                                   '15' => 'Ninawa',
                                   '07' => 'Baghdad',
                                   '10' => 'Diyala',
                                   '09' => 'Dhi Qar'
                         },
                         'TZ' => {
                                   '11' => 'Mtwara',
                                   '21' => 'Zanzibar Central',
                                   '05' => 'Kigoma',
                                   '26' => 'Arusha',
                                   '04' => 'Iringa',
                                   '17' => 'Tabora',
                                   '02' => 'Pwani',
                                   '22' => 'Zanzibar North',
                                   '18' => 'Tanga',
                                   '08' => 'Mara',
                                   '03' => 'Dodoma',
                                   '06' => 'Kilimanjaro',
                                   '13' => 'Pemba North',
                                   '16' => 'Singida',
                                   '23' => 'Dar es Salaam',
                                   '27' => 'Manyara',
                                   '25' => 'Zanzibar Urban',
                                   '12' => 'Mwanza',
                                   '15' => 'Shinyanga',
                                   '14' => 'Ruvuma',
                                   '20' => 'Pemba South',
                                   '07' => 'Lindi',
                                   '24' => 'Rukwa',
                                   '10' => 'Morogoro',
                                   '19' => 'Kagera',
                                   '09' => 'Mbeya'
                         },
                         'MW' => {
                                   '11' => 'Lilongwe',
                                   '21' => 'Rumphi',
                                   '05' => 'Thyolo',
                                   '26' => 'Balaka',
                                   '04' => 'Chitipa',
                                   '17' => 'Nkhata Bay',
                                   '02' => 'Chikwawa',
                                   '22' => 'Salima',
                                   '18' => 'Nkhotakota',
                                   '08' => 'Karonga',
                                   '03' => 'Chiradzulu',
                                   '30' => 'Phalombe',
                                   '06' => 'Dedza',
                                   '13' => 'Mchinji',
                                   '16' => 'Ntcheu',
                                   '23' => 'Zomba',
                                   '29' => 'Mulanje',
                                   '25' => 'Mwanza',
                                   '27' => 'Likoma',
                                   '28' => 'Machinga',
                                   '12' => 'Mangochi',
                                   '15' => 'Mzimba',
                                   '20' => 'Ntchisi',
                                   '07' => 'Dowa',
                                   '24' => 'Blantyre',
                                   '19' => 'Nsanje',
                                   '09' => 'Kasungu'
                         },
                         'LY' => {
                                   '53' => 'Az Zawiyah',
                                   '05' => 'Al Jufrah',
                                   '48' => 'Al Fatih',
                                   '42' => 'Tubruq',
                                   '03' => 'Al Aziziyah',
                                   '08' => 'Al Kufrah',
                                   '30' => 'Murzuq',
                                   '13' => 'Ash Shati\'',
                                   '55' => 'Darnah',
                                   '50' => 'Al Khums',
                                   '57' => 'Gharyan',
                                   '61' => 'Tarabulus',
                                   '51' => 'An Nuqat al Khams',
                                   '58' => 'Misratah',
                                   '41' => 'Tarhunah',
                                   '47' => 'Ajdabiya',
                                   '52' => 'Awbari',
                                   '59' => 'Sawfajjin',
                                   '60' => 'Surt',
                                   '34' => 'Sabha',
                                   '49' => 'Al Jabal al Akhdar',
                                   '56' => 'Ghadamis',
                                   '45' => 'Zlitan',
                                   '62' => 'Yafran',
                                   '54' => 'Banghazi'
                         },
                         'GT' => {
                                   '11' => 'Jutiapa',
                                   '21' => 'Totonicapan',
                                   '05' => 'El Progreso',
                                   '04' => 'Chiquimula',
                                   '17' => 'San Marcos',
                                   '02' => 'Baja Verapaz',
                                   '22' => 'Zacapa',
                                   '18' => 'Santa Rosa',
                                   '08' => 'Huehuetenango',
                                   '03' => 'Chimaltenango',
                                   '06' => 'Escuintla',
                                   '13' => 'Quetzaltenango',
                                   '16' => 'Sacatepequez',
                                   '01' => 'Alta Verapaz',
                                   '12' => 'Peten',
                                   '15' => 'Retalhuleu',
                                   '14' => 'Quiche',
                                   '20' => 'Suchitepequez',
                                   '07' => 'Guatemala',
                                   '10' => 'Jalapa',
                                   '19' => 'Solola',
                                   '09' => 'Izabal'
                         },
                         'GY' => {
                                   '11' => 'Cuyuni-Mazaruni',
                                   '12' => 'Demerara-Mahaica',
                                   '17' => 'Potaro-Siparuni',
                                   '14' => 'Essequibo Islands-West Demerara',
                                   '15' => 'Mahaica-Berbice',
                                   '18' => 'Upper Demerara-Berbice',
                                   '16' => 'Pomeroon-Supenaam',
                                   '13' => 'East Berbice-Corentyne',
                                   '19' => 'Upper Takutu-Upper Essequibo',
                                   '10' => 'Barima-Waini'
                         },
                         'BM' => {
                                   '11' => 'Warwick',
                                   '01' => 'Devonshire',
                                   '05' => 'Pembroke',
                                   '04' => 'Paget',
                                   '02' => 'Hamilton',
                                   '07' => 'Saint George\'s',
                                   '03' => 'Hamilton',
                                   '08' => 'Sandys',
                                   '06' => 'Saint George',
                                   '10' => 'Southampton',
                                   '09' => 'Smiths'
                         },
                         'PK' => {
                                  '07' => 'Northern Areas',
                                  '01' => 'Federally Administered Tribal Areas',
                                  '08' => 'Islamabad',
                                  '03' => 'North-West Frontier',
                                  '05' => 'Sindh',
                                  '06' => 'Azad Kashmir',
                                  '04' => 'Punjab',
                                  '02' => 'Balochistan'
                         },
                         'GQ' => {
                                   '07' => 'Kie-Ntem',
                                   '03' => 'Annobon',
                                   '05' => 'Bioko Sur',
                                   '08' => 'Litoral',
                                   '06' => 'Centro Sur',
                                   '04' => 'Bioko Norte',
                                   '09' => 'Wele-Nzas'
                         },
                         'LT' => {
                                   '63' => 'Telsiu Apskritis',
                                   '57' => 'Kauno Apskritis',
                                   '64' => 'Utenos Apskritis',
                                   '61' => 'Siauliu Apskritis',
                                   '58' => 'Klaipedos Apskritis',
                                   '59' => 'Marijampoles Apskritis',
                                   '60' => 'Panevezio Apskritis',
                                   '56' => 'Alytaus Apskritis',
                                   '62' => 'Taurages Apskritis',
                                   '65' => 'Vilniaus Apskritis'
                         },
                         'TT' => {
                                   '11' => 'Tobago',
                                   '01' => 'Arima',
                                   '05' => 'Port-of-Spain',
                                   '04' => 'Nariva',
                                   '12' => 'Victoria',
                                   '02' => 'Caroni',
                                   '07' => 'Saint David',
                                   '08' => 'Saint George',
                                   '03' => 'Mayaro',
                                   '06' => 'Saint Andrew',
                                   '10' => 'San Fernando',
                                   '09' => 'Saint Patrick'
                         },
                         'TD' => {
                                   '11' => 'Moyen-Chari',
                                   '01' => 'Batha',
                                   '05' => 'Guera',
                                   '04' => 'Chari-Baguirmi',
                                   '12' => 'Ouaddai',
                                   '02' => 'Biltine',
                                   '14' => 'Tandjile',
                                   '07' => 'Lac',
                                   '08' => 'Logone Occidental',
                                   '03' => 'Borkou-Ennedi-Tibesti',
                                   '06' => 'Kanem',
                                   '10' => 'Mayo-Kebbi',
                                   '13' => 'Salamat',
                                   '09' => 'Logone Oriental'
                         },
                         'SO' => {
                                   '11' => 'Nugaal',
                                   '21' => 'Awdal',
                                   '05' => 'Galguduud',
                                   '04' => 'Bay',
                                   '02' => 'Banaadir',
                                   '22' => 'Sool',
                                   '18' => 'Nugaal',
                                   '08' => 'Jubbada Dhexe',
                                   '03' => 'Bari',
                                   '06' => 'Gedo',
                                   '13' => 'Shabeellaha Dhexe',
                                   '16' => 'Woqooyi Galbeed',
                                   '01' => 'Bakool',
                                   '12' => 'Sanaag',
                                   '20' => 'Woqooyi Galbeed',
                                   '14' => 'Shabeellaha Hoose',
                                   '07' => 'Hiiraan',
                                   '19' => 'Togdheer',
                                   '10' => 'Mudug',
                                   '09' => 'Jubbada Hoose'
                         },
                         'SY' => {
                                   '11' => 'Hims',
                                   '01' => 'Al Hasakah',
                                   '05' => 'As Suwayda\'',
                                   '04' => 'Ar Raqqah',
                                   '12' => 'Idlib',
                                   '02' => 'Al Ladhiqiyah',
                                   '14' => 'Tartus',
                                   '07' => 'Dayr az Zawr',
                                   '08' => 'Rif Dimashq',
                                   '03' => 'Al Qunaytirah',
                                   '06' => 'Dar',
                                   '10' => 'Hamah',
                                   '13' => 'Dimashq',
                                   '09' => 'Halab'
                         },
                         'SK' => {
                                   '07' => 'Trnava',
                                   '01' => 'Banska Bystrica',
                                   '08' => 'Zilina',
                                   '03' => 'Kosice',
                                   '05' => 'Presov',
                                   '06' => 'Trencin',
                                   '04' => 'Nitra',
                                   '02' => 'Bratislava'
                         },
                         'BD' => {
                                   '32' => 'Dhaka',
                                   '33' => 'Dinajpur',
                                   '63' => 'Netrakona',
                                   '71' => 'Rangpur',
                                   '26' => 'Brahmanbaria',
                                   '72' => 'Satkhira',
                                   '44' => 'Jhenaidah',
                                   '55' => 'Meherpur',
                                   '84' => 'Chittagong',
                                   '74' => 'Sherpur',
                                   '27' => 'Chandpur',
                                   '01' => 'Barisal',
                                   '57' => 'Munshiganj',
                                   '61' => 'Narsingdi',
                                   '31' => 'Cox\'s Bazar',
                                   '35' => 'Feni',
                                   '78' => 'Tangail',
                                   '48' => 'Kurigram',
                                   '77' => 'Sylhet',
                                   '65' => 'Pabna',
                                   '29' => 'Chattagram',
                                   '50' => 'Laksmipur',
                                   '39' => 'Habiganj',
                                   '64' => 'Nilphamari',
                                   '58' => 'Naogaon',
                                   '12' => 'Mymensingh',
                                   '41' => 'Jamalpur',
                                   '15' => 'Patuakhali',
                                   '81' => 'Dhaka',
                                   '52' => 'Madaripur',
                                   '60' => 'Narayanganj',
                                   '56' => 'Moulavibazar',
                                   '45' => 'Khagrachari',
                                   '73' => 'Shariyatpur',
                                   '66' => 'Panchagar',
                                   '76' => 'Sunamganj',
                                   '86' => 'Sylhet',
                                   '62' => 'Nator',
                                   '54' => 'Manikganj',
                                   '67' => 'Parbattya Chattagram',
                                   '05' => 'Comilla',
                                   '70' => 'Rajshahi',
                                   '68' => 'Pirojpur',
                                   '04' => 'Bandarban',
                                   '30' => 'Chuadanga',
                                   '82' => 'Khulna',
                                   '25' => 'Barguna',
                                   '28' => 'Chapai Nawabganj',
                                   '83' => 'Rajshahi',
                                   '40' => 'Jaipurhat',
                                   '75' => 'Sirajganj',
                                   '59' => 'Narail',
                                   '69' => 'Rajbari',
                                   '49' => 'Kushtia',
                                   '24' => 'Bogra',
                                   '53' => 'Magura',
                                   '79' => 'Thakurgaon',
                                   '42' => 'Jessore',
                                   '22' => 'Bagerhat',
                                   '46' => 'Khulna',
                                   '13' => 'Noakhali',
                                   '23' => 'Bhola',
                                   '85' => 'Barisal',
                                   '36' => 'Gaibandha',
                                   '51' => 'Lalmonirhat',
                                   '47' => 'Kishorganj',
                                   '38' => 'Gopalganj',
                                   '34' => 'Faridpur',
                                   '37' => 'Gazipur',
                                   '43' => 'Jhalakati'
                         }
);

sub _get_region_name {
  my ( $ccode, $region ) = @_;
  return unless $region;
  return if $region eq '00';

  return $country_region_names{$ccode}->{$region}
    if exists $country_region_names{$ccode};

}

1;
__END__

=head1 NAME

Geo::IP - Look up location and network information by IP Address

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
to determine the countries of your visitors, for credit card fraud
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
GEOIP_INDEX_CACHE caches
the most frequently accessed index portion of the database, resulting
in faster lookups than GEOIP_STANDARD, but less memory usage than
GEOIP_MEMORY_CACHE - useful for larger databases such as
GeoIP Organization and GeoIP City.  Note, for GeoIP Country, Region
and Netspeed databases, GEOIP_INDEX_CACHE is equivalent to GEOIP_MEMORY_CACHE

To combine flags, use the bitwise OR operator, |.  For example, to cache the database
in memory, but check for an updated GeoIP.dat file, use:
Geo::IP->new( GEOIP_MEMORY_CACHE | GEOIP_CHECK_CACHE. );

=item $gi = Geo::IP->open( $database_filename, $flags );

Constructs a new Geo::IP object with the database located at C<$database_filename>.

=item $gi = Geo::IP->open_type( $database_type, $flags );

Constructs a new Geo::IP object with the $database_type database located in the standard
location.  For example

  $gi = Geo::IP->open_type( GEOIP_CITY_EDITION_REV1 , GEOIP_STANDARD );

opens the database file in the standard location for GeoIP City, typically
I</usr/local/share/GeoIP/GeoIPCity.dat>.

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

Returns the Organization, ISP name or Domain Name for an IP address.

=item $org = $gi->org_by_name( $hostname );

Returns the Organization, ISP name or Domain Name for a hostname.

=item $info = $gi->database_info;

Returns database string, includes version, date, build number and copyright notice.

=item $old_charset = $gi->set_charset( $charset );

Set the charset for the city name - defaults to GEOIP_CHARSET_ISO_8859_1.  To
set UTF8, pass GEOIP_CHARSET_UTF8 to set_charset.
For perl >= 5.008 the utf8 flag is honored.

=item $charset = $gi->charset;

Gets the currently used charset.

=item $netmask = $gi->last_netmask;

Gets netmask of network block from last lookup.

=item $gi->netmask(12);

Sets netmask for the last lookup

=item my ( $from, $to ) = $gi->range_by_ip('24.24.24.24');

Returns the start and end of the current network block. The method tries to join several continous netblocks.

=back

=head1 MAILING LISTS AND CVS

Are available from SourceForge, see
http://sourceforge.net/projects/geoip/

The direct link to the mailing list is
http://lists.sourceforge.net/lists/listinfo/geoip-perl

=head1 VERSION

1.36

=head1 SEE ALSO

Geo::IP::Record

=head1 AUTHOR

Copyright (c) 2008, MaxMind, Inc

All rights reserved.  This package is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=cut


