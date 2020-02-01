# zoneedit_letsencrypt

Scripts to enable automated ssl certificate update dns-01 challenge with Linux, Zoneedit and Letsencrypt

This is a very basic script for my needs.  Borrowed heavily from https://github.com/jeansergegagnon/zoneedit_letsencrypt/ but simplified to be an auth hook from certbot and fixed issues handling spaces in TXT entries.

There are 2 scripts:
1. certbot-authenticator.sh
2. certbot-wrapper.sh


To use this, you need the following:

1. A ZoneEdit hosted Domain
2. The certbot binary in the path 
3. Your ZoneEdit user and password (you will need to save them in /etc/sysconfig/zoneedit.cfg file)
4. These scripts

You just install this in a directory, as simple as this:

```
cd /path/to/dir/to/save/files
git clone git@github.com:galapogos01/zoneedit_letsencrypt.git
cd zoneedit_letsencrypt
certbot certonly --manual --preferred-challenges=dns --manual-public-ip-logging-ok --manual-auth-hook /path/to/certbot-wrapper.sh --manual-cleanup-hook /path/to/certbot-wrapper.sh -d *.domain.com.au

```

On first execution, this will fail and you will need to edit the /etc/sysconfig/zoneedit.cfg file
and you can re-run the command which will complete

```
certbot certonly --manual --preferred-challenges=dns --manual-public-ip-logging-ok --manual-auth-hook /path/to/certbot-wrapper.sh --manual-cleanup-hook /path/to/certbot-wrapper.sh -d *.domain.com.au
```


Obviously, change the *domain.com.au* to your domain in above exmaple command.

Feel free to email me or the original author at jeanserge.gagnon@gmail.com for any questions or comments and fork this project to submit any pull requests. I will be happy to review and approve any changes that make this code even more useful to others.


