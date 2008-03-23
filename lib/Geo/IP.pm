package Geo::IP;

use strict;
use base qw(Exporter);
use vars qw($VERSION @EXPORT  $TESTING_PERL_ONLY @ISA $XS_VERSION);

BEGIN { $TESTING_PERL_ONLY = 0;}

BEGIN {       
	$VERSION = '1.31';
  eval {

    # PERL_DL_NONLAZY must be false, or any errors in loading will just
    # cause the perl code to be tested
    local $ENV{PERL_DL_NONLAZY} = 0 if $ENV{PERL_DL_NONLAZY};

    require DynaLoader;
    local @ISA = qw(DynaLoader);
    bootstrap Geo::IP $VERSION;
  } unless $TESTING_PERL_ONLY;
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

#eval << '__PP_CODE__' if ( !defined &_XScompiled || !&_XScompiled || $TESTING_PERL_ONLY );
eval << '__PP_CODE__' unless defined &open;

use strict;
use FileHandle;

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
 ZA ZM ME ZW A1 A2 AX GG 
 IM JE BL MF/
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
               ZAF ZMB MNE ZWE A1  A2  ALA GGY
               IMN JEY BLM MAF                 /
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
              "Aland Islands",
              "Guernsey",
              "Isle of Man",
              "Jersey",
	      "Saint Barthelemy",
	      "Saint Martin"
);

sub open {
  die "Geo::IP::PurePerl::open() requires a path name"
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
        return $x1;
      }
      $offset = $x1;
    }
    else {
      if ( $x0 >= $gi->{"databaseSegments"} ) {
        return $x0;
      }
      $offset = $x0;
    }
  }

  print STDERR
"Error Traversing Database for ipnum = $ipnum - Perhaps database is corrupt?";
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
  my $dmaarea_combo;
  my $record_country_code  = "";
  my $record_country_code3 = "";
  my $record_country_name  = "";
  my $record_region        = "";
  my $record_city          = "";
  my $record_postal_code   = "";
  my $record_latitude      = "";
  my $record_longitude     = "";
  my $record_dma_code      = "";
  my $record_area_code     = "";
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

  #get the dma code and the area code
  if ( GEOIP_CITY_EDITION_REV1 == $gi->{"databaseType"} ) {
    $dmaarea_combo = 0;
    if ( $record_country_code eq "US" ) {

      #if the country is US then read the dma area combo
      for ( $j = 0; $j < 3; ++$j ) {
        $char = ord( substr( $record_buf, $record_buf_pos++, 1 ) );
        $dmaarea_combo += ( $char << ( $j * 8 ) );
      }

      #split the dma area combo into the dma code and the area code
      $record_dma_code  = int( $dmaarea_combo / 1000 );
      $record_area_code = $dmaarea_combo % 1000;
    }
  }
  return (
           $record_country_code, $record_country_code3, $record_country_name,
           $record_region,       $record_city,          $record_postal_code,
           $record_latitude,     $record_longitude,     $record_dma_code,
           $record_area_code
  );
}

#this function returns the city record as a hash ref
sub get_city_record_as_hash {
  my ( $gi, $host ) = @_;
  my %gir;

  @gir{qw/ country_code   country_code3   country_name   region     city 
           postal_code    latitude        longitude      dma_code   area_code / } =
    $gi->get_city_record($host);
  
  return bless \%gir, 'Geo::IP::Record';
}

*record_by_addr = \&get_city_record_as_hash;

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
sub isp_by_name {
  my ( $gi, $host ) = @_;
  $gi->org_by_name($host);
}

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

sub addr_to_num {
  my @a = split( '\.', $_[0] );
  return $a[0] * 16777216 + $a[1] * 65536 + $a[2] * 256 + $a[3];
}

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

sub last_netmask {
  die "not yet implemented";
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

=item $charset = $gi->charset;

Gets the currently used charset.

=item $netmask = $gi->last_netmask;

Gets netmask of network block from last lookup.

=back

=head1 MAILING LISTS AND CVS

Are available from SourceForge, see
http://sourceforge.net/projects/geoip/

The direct link to the mailing list is
http://lists.sourceforge.net/lists/listinfo/geoip-perl

=head1 VERSION

1.31

=head1 SEE ALSO

Geo::IP::Record

=head1 AUTHOR

Copyright (c) 2008, MaxMind, Inc

All rights reserved.  This package is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.

=cut
