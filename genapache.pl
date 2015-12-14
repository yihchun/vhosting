#!/usr/bin/perl
#
# genapache.pl -- generate apache sites-available and php5 fpm/pool.d files
# for multiple sites and multiple users. Uses mod_php for www-data's sites
# and fastcgi / php5-fpm for other sites.
#

system "rm apache-sites/*";
system "rm fpm-pools/*";

open CONFIG, "config";

$port = 80;
$sslport = 443;
$host = "youlost.mooo.com";
$fpmport = 9000;

#open OUTPUT, ">>apache-sites/default";
#print OUTPUT "SSLStaplingCache shmcb:/var/run/www/stapling_cache(128000)\n";
#close OUTPUT;

while (<CONFIG>) {
  chop;
  next if (/^#/);
  ($user,$rootdir,$hosts, $options) = split /\t/;
  ($canonical,$others) = split / /, $hosts, 2;

  $dofpm = ($user ne "www-data") && !system("/usr/bin/find /var/www/$rootdir -name \\*.php -print | /bin/grep php > /dev/null");
  $domodphp = ($user eq "www-data");

  if ($dofpm && !exists($fpm{$user})) {
    $fpm{$user} = $fpmport++;
  }
  print STDERR "Generating $user $canonical $dofpm $fpm{$user}\n";
  die if ($canonical =~ m|/|);
  if (-d "/var/www/$rootdir") {
    open OUTPUT, ">>apache-sites/default";
    print OUTPUT "<VirtualHost *:$port>\n";
    if ($canonical ne "DEFAULT") {
      $gencfg = "ServerName $canonical\n";
    } else {
      $gencfg = "ServerName $host\n";
    }

    if ($others) {
      $gencfg .= "ServerAlias " . join("\nServerAlias ", split(" ", $others));
      $gencfg .= "\n";
    }

    $gencfg .= "DocumentRoot /var/www/$rootdir\n";

    if (!$domodphp) {
      #$gencfg .= "RemoveHandler .php .phtml .php3 .php5\nphp_flag engine off\n";
      $gencfg .= "RemoveHandler .php .phtml .php3 .php5\n";
    }

    if ($dofpm) {
#      $gencfg .= <<EOF;
#<IfModule mod_fastcgi.c>
#AddHandler php-fastcgi .php .phpe
#Action php-fastcgi /php5.fastcgi virtual
#Alias /php5.fastcgi /var/www/fcgi
#FastCGIExternalServer /var/www/fcgi -socket /var/run/php5-fpm/$fpm{$user}.sock
#</IfModule>
#EOF
#AddHandler php-fastcgi .php .phpe
#Action php-fastcgi /php5.fastcgi virtual
#Alias /php5.fastcgi /var/www/fcgi
#FastCGIExternalServer /var/www/fcgi -socket /var/run/php5-fpm/$fpm{$user}.sock
    }

#    $gencfg .= "ScriptAlias /local-bin /usr/bin\nAddHandler application/x-httpd-php5 php\nAction application/x-httpd-php5 /local-bin/php-cgi\n";
#    if ($user != "www-data") {
#      $gencfg .= "<IfModule mpm_itk_module>\n AssignUserId $user $user\n</IfModule>\n";
#    }
    $gencfg .= "ErrorDocument 404 /404.html;\n" 
      if (-e "/var/www/$rootdir/404.html");
    $gencfg .= "ErrorDocument 500 502 503 504 /50x.html;\n" 
      if (-e "/var/www/$rootdir/50x.html");

    if (-e "bonus/apache-$canonical") {
      open my $fh, "<bonus/apache-$canonical";
      $gencfg .= do { local $/; <$fh> };
    }

    if ($options =~ /redirssl/) {
      $tmpcfg = $gencfg;
      $tmpcfg =~ s/DocumentRoot.*/Redirect permanent \/ https:\/\/$canonical\//;
      print OUTPUT "$tmpcfg</VirtualHost>\n";
    } else {
      print OUTPUT "$gencfg</VirtualHost>\n";
    }

    next unless (-e "/etc/apache2/ssl/$canonical.crt");
    $ca = "$canonical.crt";
    open SSLCOMPANY, "/usr/bin/openssl x509 -text -in /etc/apache2/ssl/$canonical.crt |";
    while (<SSLCOMPANY>) {
      $ca = "wosign.pem" if (/Issuer:/ && /WoSign/);
      $ca = "startcom.pem" if (/Issuer:/ && /StartCom/);
      $ca = "letsencrypt.pem" if (/Issuer:/ && /Let's Encrypt/);
    }
    close SSLCOMPANY;

    print OUTPUT "<IfModule mod_ssl.c>\n<VirtualHost *:$sslport>\n$gencfg";
    print OUTPUT <<EOF;
SSLEngine on
SSLCertificateFile /etc/apache2/ssl/$canonical.crt
SSLCertificateKeyFile /etc/apache2/ssl/$canonical.key
SSLCACertificateFile /etc/apache2/ssl/$ca
<FilesMatch "\\.(cgi|shtml|phtml|php)\$">
        SSLOptions +StdEnvVars
</FilesMatch>
BrowserMatch "MSIE [2-6]" nokeepalive ssl-unclean-shutdown downgrade-1.0 force-response-1.0
BrowserMatch "MSIE [17-9]" ssl-unclean-shutdown
</VirtualHost>
</IfModule>
EOF
    close OUTPUT;
  } else {
    print STDERR "Could not find directory /var/www/$rootdir for $canonical\n";
  }
}

foreach $key (keys %fpm) {
  open OUTPUT, ">fpm-pools/$key.conf";
  print OUTPUT <<EOF;
[$key]
user = $key
;listen = 127.0.0.1:$fpm{$key}
listen = /var/run/php5-fpm/$fpm{$key}.sock
listen.owner = www-data
listen.mode = 0600
; process management
pm = dynamic
pm.max_children = 10
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 4
pm.max_requests = 50
;chroot = 
chdir = /
security.limit_extensions = .php .phpe
EOF
  close OUTPUT;
}

$x = <<EOF;

	location / {
		try_files \$uri \$uri/ /index.html;
	}
}
EOF

print "cp apache-sites/* /etc/apache2/sites-available\n";
print "cp fpm-pools/* /etc/php5/fpm/pool.d\n" if ($fpmport != 9000);
print "apachectl configtest\n";
#print "service apache2 restart\n";
#print "service php5-fpm restart\n";
