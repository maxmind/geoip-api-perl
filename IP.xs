#ifdef __cplusplus
extern "C" {
#endif

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "GeoIP.h"
#include "GeoIPCity.h"

#ifdef __cplusplus
}
#endif

MODULE = Geo::IP	PACKAGE = Geo::IP

PROTOTYPES: DISABLE

GeoIP *
new(CLASS,flags = 0)
	char * CLASS
	int flags
    CODE:
	RETVAL = GeoIP_new(flags);
    OUTPUT:
	RETVAL

GeoIP *
open_type(CLASS,type,flags = 0)
	char * CLASS
	int type
	int flags
    CODE:
	RETVAL = GeoIP_open_type(type,flags);
    OUTPUT:
	RETVAL

GeoIP *
open(CLASS,filename,flags = 0)
	char * CLASS
	char * filename
	int flags
    CODE:
	RETVAL = ( filename != NULL ) ? GeoIP_open(filename,flags) : NULL;
    OUTPUT:
	RETVAL

int
id_by_addr(gi, addr)
	GeoIP *gi
	char * addr
    CODE:
	RETVAL = GeoIP_id_by_addr(gi,addr);
    OUTPUT:
	RETVAL

int
id_by_name(gi, name)
	GeoIP *gi
	char * name
    CODE:
	RETVAL = GeoIP_id_by_name(gi,name);
    OUTPUT:
	RETVAL

char *
database_info (gi)
	GeoIP *gi
    CODE:
	RETVAL = GeoIP_database_info(gi);
    OUTPUT:
	RETVAL

const char *
country_code_by_addr(gi, addr)
	GeoIP *gi
	char * addr
    CODE:
	RETVAL = GeoIP_country_code_by_addr(gi,addr);
    OUTPUT:
	RETVAL

const char *
country_code_by_name(gi, name)
	GeoIP *gi
	char * name
    CODE:
	RETVAL = GeoIP_country_code_by_name(gi,name);
    OUTPUT:
	RETVAL

const char *
country_code3_by_addr(gi, addr)
	GeoIP *gi
	char * addr
    CODE:
	RETVAL = GeoIP_country_code3_by_addr(gi,addr);
    OUTPUT:
	RETVAL

const char *
country_code3_by_name(gi, name)
	GeoIP *gi
	char * name
    CODE:
	RETVAL = GeoIP_country_code3_by_name(gi,name);
    OUTPUT:
	RETVAL

const char *
country_name_by_addr(gi, addr)
	GeoIP *gi
	char * addr
    CODE:
	RETVAL = GeoIP_country_name_by_addr(gi,addr);
    OUTPUT:
	RETVAL

const char *
country_name_by_name(gi, name)
	GeoIP *gi
	char * name
    CODE:
	RETVAL = GeoIP_country_name_by_name(gi,name);
    OUTPUT:
	RETVAL

char *
org_by_addr(gi, addr)
	GeoIP *gi
	char * addr
    CODE:
	RETVAL = GeoIP_org_by_addr(gi,addr);
    OUTPUT:
	RETVAL

char *
org_by_name(gi, name)
	GeoIP *gi
	char * name
    CODE:
	RETVAL = GeoIP_org_by_name(gi,name);
    OUTPUT:
	RETVAL

void
range_by_ip(gi, addr)
	GeoIP *gi
	const char * addr
    PREINIT:
    char ** r;
    PPCODE:
	r = GeoIP_range_by_ip(gi,addr);
        if (r != NULL){
		EXTEND(SP,2);
		PUSHs( sv_2mortal( newSVpv(r[0], 0) ) );
		PUSHs( sv_2mortal( newSVpv(r[1], 0) ) );

		if ( r[0] )
			free(r[0]);
		if ( r[1] )
			free(r[1]);
		free(r);
        }

void
region_by_addr(gi, addr)
	GeoIP *gi
	char * addr
    PREINIT:
	GeoIPRegion * gir;
    PPCODE:
	gir = GeoIP_region_by_addr(gi,addr);
        if (gir){
	  EXTEND(SP,2);

          ( gir->country_code[0] == '\0' && gir->country_code[1] == '\0' )
            ? PUSHs ( sv_newmortal() )
 	    : PUSHs ( sv_2mortal( newSVpv(gir->country_code, 2) ) );

          ( gir->region[0] == '\0' && gir->region[1] == '\0' )
            ? PUSHs ( sv_newmortal() )
            : PUSHs( sv_2mortal( newSVpv(gir->region, 2) ) );

          GeoIPRegion_delete(gir);
        }

void
region_by_name(gi, name)
	GeoIP *gi
	char * name
    PREINIT:
	GeoIPRegion * gir;
    PPCODE:
	gir = GeoIP_region_by_name(gi,name);
        if (gir){
	  EXTEND(SP,2);

          ( gir->country_code[0] == '\0' && gir->country_code[1] == '\0' )
            ? PUSHs ( sv_newmortal() )
 	    : PUSHs ( sv_2mortal( newSVpv(gir->country_code, 2) ) );

          ( gir->region[0] == '\0' && gir->region[1] == '\0' )
            ? PUSHs ( sv_newmortal() )
            : PUSHs( sv_2mortal( newSVpv(gir->region, 2) ) );

	  GeoIPRegion_delete(gir);
        }

GeoIPRecord *
record_by_addr(gi, addr)
	GeoIP *gi
	char * addr
    PREINIT:
	char * CLASS = "Geo::IP::Record";
    CODE:
	RETVAL = GeoIP_record_by_addr(gi,addr);
    OUTPUT:
	RETVAL

GeoIPRecord *
record_by_name(gi, addr)
	GeoIP *gi
	char * addr
    PREINIT:
	char * CLASS = "Geo::IP::Record";
    CODE:
	RETVAL = GeoIP_record_by_name(gi,addr);
    OUTPUT:
	RETVAL

int
set_charset(gi, charset)
	GeoIP *gi
	int charset
    CODE:
	RETVAL = GeoIP_set_charset(gi, charset);
    OUTPUT:
	RETVAL

int
charset(gi)
	GeoIP *gi
    CODE:
	RETVAL = GeoIP_charset(gi);
    OUTPUT:
	RETVAL

int
last_netmask(gi)
	GeoIP *gi
    CODE:
	RETVAL = GeoIP_last_netmask(gi);
    OUTPUT:
	RETVAL

void
DESTROY(gi)
	GeoIP *gi
    CODE:
	GeoIP_delete(gi);

MODULE = Geo::IP        PACKAGE = Geo::IP::Record

const char *
country_code(gir)
	GeoIPRecord *gir
    CODE:
	RETVAL = (const char *)gir->country_code;
    OUTPUT:
	RETVAL

const char *
country_code3(gir)
	GeoIPRecord *gir
    CODE:
	RETVAL = (const char *)gir->country_code3;
    OUTPUT:
	RETVAL

const char *
country_name(gir)
	GeoIPRecord *gir
    CODE:
	RETVAL = (const char *)gir->country_name;
    OUTPUT:
	RETVAL

const char *
region(gir)
	GeoIPRecord *gir
    CODE:
	RETVAL = (const char *)gir->region;
    OUTPUT:
	RETVAL

const char *
region_name(gir)
	GeoIPRecord *gir
    CODE:
	RETVAL = (const char *) GeoIP_region_name_by_code(gir->country_code, gir->region);
    OUTPUT:
	RETVAL

const char *
time_zone(gir)
	GeoIPRecord *gir
    CODE:
	RETVAL = (const char *) GeoIP_time_zone_by_country_and_region(gir->country_code, gir->region);
    OUTPUT:
	RETVAL

void
city(gir)
	GeoIPRecord *gir
    PREINIT:
        SV * n;
    PPCODE:
        n = newSVpv( gir->city ? gir->city : "", 0);
#if defined(sv_utf8_decode)
        if ( gir->charset == GEOIP_CHARSET_UTF8 )
          SvUTF8_on(n);
#endif
        sv_2mortal(n);
        ST(0) = n;
        XSRETURN(1);

const char *
postal_code(gir)
	GeoIPRecord *gir
    CODE:
	RETVAL = (const char *)gir->postal_code;
    OUTPUT:
	RETVAL

float
_latitude(gir)
	GeoIPRecord *gir
    CODE:
	RETVAL = gir->latitude;
    OUTPUT:
	RETVAL

float
_longitude(gir)
	GeoIPRecord *gir
    CODE:
	RETVAL = gir->longitude;
    OUTPUT:
	RETVAL

int
dma_code(gir)
	GeoIPRecord *gir
    CODE:
	RETVAL = gir->dma_code;
	
    OUTPUT:
	RETVAL

int
metro_code(gir)
	GeoIPRecord *gir
    CODE:
       RETVAL = gir->dma_code; /* we can NOT use metro_code here. metro_code may be not present in older CAPI's */
    OUTPUT:
	RETVAL

int
area_code(gir)
	GeoIPRecord *gir
    CODE:
	RETVAL = gir->area_code;
    OUTPUT:
	RETVAL

const char *
continent_code(gir)
	GeoIPRecord *gir
    CODE:
	RETVAL = (const char *)gir->continent_code;
    OUTPUT:
	RETVAL

void
DESTROY(gir)
	GeoIPRecord *gir
    CODE:
	GeoIPRecord_delete(gir);

void
_XScompiled ()
    CODE:
	XSRETURN_YES;
