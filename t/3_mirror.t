# -*- Mode: Perl; -*-

use strict;
use Test;

$^W = 1;

BEGIN { plan tests => 3 }

use Geo::Mirror;

my $gm = Geo::Mirror->new(mirror_file => 't/cpan_mirror.txt');

# pakistan closest to India
ok($gm->find_mirror_by_country('pk'), 'http://cpan.in.freeos.com');

# Iran closest to Saudi Arabia
ok($gm->find_mirror_by_addr('62.60.128.1'), 'ftp://ftp.isu.net.sa/pub/CPAN/');

# Philippines
ok($gm->find_mirror_by_addr('210.23.107.55'), 'http://www.adzu.edu.ph/CPAN');
