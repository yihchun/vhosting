#!/usr/bin/perl
#
# genapache.pl -- generate apache sites-available and php5 fpm/pool.d files
# for multiple sites and multiple users. Uses mod_php for www-data's sites
# and fastcgi / php5-fpm for other sites.
#

open CONFIG, "config";

while (<CONFIG>) {
  chop;
  next if (/^#/);
  ($user,$rootdir,$hosts,$options,$names) = split /\t/;
  ($canonical,$others) = split / /, $hosts, 2;
  $hosts =~ s/\*/www/;
  @allhost = split / /, $hosts;
  if ($names) {
    @allhost = split / /, $names;
  }
  print "openssl genrsa 4096 > $canonical.key\n";
  print "openssl req -new -sha256 -key $canonical.key -subj \"/\" -reqexts SAN -config <(cat /etc/ssl/openssl.cnf <(printf \"[SAN]\\nsubjectAltName=DNS:" . join(",DNS:", @allhost) . "\")) > $canonical.csr\n";
  print "python sign_csr.py -e yihchun.com\@gmail.com -p user.pub -d /var/www/$rootdir $canonical.csr > $canonical.crt\n";
}
