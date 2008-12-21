# Red Hat Linux specific release extraction
%define DISTRO %([ -f /etc/redhat-release ] && sed -e "s/\\(.\\+\\)\\( Linux release \\)\\(.\\+\\)\\( .\\+\\)/\\1 \\3/" /etc/redhat-release)
%define DISTRO_REL %([ -f /etc/redhat-release ] && sed -e "s/\\(.\\+ release \\)\\(.\\+\\)\\( .\\+\\)/\\2/" /etc/redhat-release)
%define REQ_RPM_REL %(rpm -q --queryformat "%{VERSION}" rpm)
%define GLIBC_REL %(rpm -q --queryformat "%{VERSION}" glibc)

Summary: Geo::IP module for Perl
Name: perl-Geo-IP
Version: 1.36
Release: 1.%{DISTRO_REL}
License: GPL
Group: Applications/Internet
Source0: http://www.maxmind.com/download/geoip/api/perl/Geo-IP-%{version}.tar.gz
Url: http://www.maxmind.com/app/perl
BuildRoot: /var/tmp/%{name}/
BuildRequires: perl >= 5 GeoIP-devel >= 1.4.5
Requires: perl >= 5 GeoIP >= 1.4.5
BuildArch: noarch

%description
Geo-IP is a Perl interface to the GeoIP C library that enables the user to
find the country that any IP address or hostname originates from.

# Provide perl-specific find-{provides,requires}.
%define __find_provides /usr/lib/rpm/find-provides.perl
%define __find_requires /usr/lib/rpm/find-requires.perl

%prep
%setup -q -n Geo-IP-%{version} 

%build
CFLAGS="$RPM_OPT_FLAGS" perl Makefile.PL
make

%clean 
rm -rf $RPM_BUILD_ROOT

%install
rm -rf $RPM_BUILD_ROOT
eval `perl '-V:installarchlib'`
mkdir -p $RPM_BUILD_ROOT/$installarchlib
make PERL_INSTALL_ROOT=$RPM_BUILD_ROOT install

[ -x /usr/lib/rpm/brp-compress ] && /usr/lib/rpm/brp-compress

find $RPM_BUILD_ROOT -type f -name '.packlist' | xargs rm -r

find $RPM_BUILD_ROOT/usr -type f -print | 
	sed "s@^$RPM_BUILD_ROOT@@g"  > %{name}-%{version}-filelist
if [ "$(cat %{name}-%{version}-filelist)X" = "X" ] ; then
    echo "ERROR: EMPTY FILE LIST"
    exit -1
fi

%files -f %{name}-%{version}-filelist
%defattr(-,root,root)

%changelog
* Mon Sep  8 2003 Dr. Peter Bieringer <pbieringer@aerasec.de> 1.21-1.AERAsec.1
- Initial
