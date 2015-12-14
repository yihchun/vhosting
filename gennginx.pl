#!/usr/bin/perl
#
# genfiles.pl -- generate nginx sites-available and php5 fpm/pool.d files
# for multiple sites and multiple users. 
#
system "rm nginx-sites/*";
system "rm fpm-pools/*";

open CONFIG, "config";
$fpmport = 9000;

while (<CONFIG>) {
  chop;
  next if (/^#/);
  ($user,$rootdir,$hosts) = split /\t/;
  ($canonical,$others) = split / /, $hosts;
  $dofpm = ($canonical eq "DEFAULT") || !system("/usr/bin/find /var/www/$rootdir -name \\*.php -print | /bin/grep php > /dev/null");
  if ($dofpm && !exists($fpm{$user})) {
    $fpm{$user} = $fpmport++;
  }
  print STDERR "Generating $user $canonical $dofpm $fpm{$user}\n";
  die if ($canonical =~ m|/|);
  if (-d "/var/www/$rootdir") {
    open OUTPUT, ">nginx-sites/$canonical";
    print OUTPUT "server {\n";
    if ($canonical ne "DEFAULT") {
      print OUTPUT "server_name $hosts;\n";
    } else {
      print OUTPUT "listen 80 default_server;\nserver_name www.yihchun.com;\n";
    }

    $gencfg = <<EOF;
root /var/www/$rootdir;
index index.html index.htm index.php;
autoindex on;
EOF
    if ($dofpm) {
      $gencfg .= <<EOF;
location ~ \\.php\$ {
fastcgi_split_path_info ^(.+\.php)(/.+)\$;
#fastcgi_pass 127.0.0.1:$fpm{$user};
fastcgi_pass unix:/var/run/php5-fpm/$fpm{$user}.sock;
fastcgi_index index.php;
include fastcgi_params;
fastcgi_param   SCRIPT_FILENAME    \$document_root\$fastcgi_script_name;
fastcgi_param   SCRIPT_NAME        \$fastcgi_script_name;
}
EOF
    }

    $gencfg .= <<EOF;
location ~ /\\. {
access_log off;
log_not_found off; 
deny all;
}
#location / {
#include /etc/nginx/naxsi.rules
#}
#location /RequestDenied {
#return 418;
#}
EOF

    $gencfg .= "error_page 404 /404.html;\n" 
      if (-e "/var/www/$rootdir/404.html");
    $gencfg .= "error_page 500 502 503 504 /50x.html;\n" 
      if (-e "/var/www/$rootdir/50x.html");
    print OUTPUT "$gencfg}\n";

    next unless (-e "/etc/apache2/ssl/$canonical.crt");

    print OUTPUT "server {\n";

    if ($canonical ne "DEFAULT") {
      print OUTPUT "server_name $hosts;\nlisten 443 ssl;";
    } else {
      print OUTPUT "listen 443 ssl default_server;\nserver_name www.yihchun.com\n";
    }
    print OUTPUT <<EOF;
	ssl on;
	ssl_certificate /etc/apache2/ssl/$canonical.crt;
	ssl_certificate_key /etc/apache2/ssl/$canonical.key;
	ssl_session_timeout 5m;
	ssl_protocols SSLv3 TLSv1;
	ssl_ciphers ALL:!ADH:!EXPORT56:RC4+RSA:+HIGH:+MEDIUM:+LOW:+SSLv3:+EXP;
	ssl_prefer_server_ciphers on;
$gencfg
}
EOF
    close OUTPUT;
  } else {
    print "Could not find directory /var/www/$rootdir for $canonical\n";
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
EOF
  close OUTPUT;
}

$x = <<EOF;

	location / {
		try_files \$uri \$uri/ /index.html;
	}
}
EOF

print "cp nginx-sites/* /etc/nginx/sites-available\n";
print "cp fpm-pools/* /etc/php5/fpm/pool.d\n";
print "service nginx restart\n";
print "service php5-fpm restart\n";
