
This is a collection of scripts that I use for virtual hosting from a low-end
Virtual Private Server. It creates scripts that (potentially) isolate different
domains with different userids through fpm. (To be fair, this part of the
functionality is not thoroughly tested). It also uses Let's Encrypt to generate
certs, through some changes to https://github.com/diafygi/letsencrypt-nosudo

I'm regularly using the Apache generator, but the nginx generator was in use
for quite some time. Either of these scripts probably require quite a bit of
customization for your environment.

For the READMEs on the two .py files, see this project:
   https://github.com/diafygi/letsencrypt-nosudo
The main change I've made is to use a directory to serve the file for 
sign\_cert.py; you need to use -d webroot\_dir to write the correct file.

The config file is a tab-delimited file that has the following fields:
- user (who should run fpm; if www-data, then it uses Apache's PHP plugin)
- relative directory of the webroot, relative to /var/www/
- space-delimited hostname list, wildcards OK. Canonical hostname goes first in this list, wildcards must be preceded by any more-specifics. DEFAULT as a canonical hostname serves for when the VirtualHost is not matched, and should go first.
- options. Currently supports only redirssl, which redirects all requests to SSL.
- space-delimited certificate name list. If you want certificate alternate names that are not in the hostname list, put it here. If you don't have a certificate name list, it uses the hostname list, replacing wildcards with www.
