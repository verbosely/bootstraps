#! /usr/bin/env bash

# Run this script to download and install/upgrade nginx from sources.
# The version to download is specified in a positional parameter.

# Print a usage message to stderr.
usage() {
  cat <<- USAGE >&2
Usage: $(basename "${0}") [-h] version

positional arguments:
    version     the version number (x[x].x[x].x[x]) of nginx 
                to download and install

options:
    -h, --help  print this message, and exit

USAGE
  exit 1
}

# Parse positional parameters.
[ ! $# -ne 1 ] && [ ! $1 = "-h" ] && [ ! $1 = "--help" ] || usage;

# Fetch the nginx archive.
curl --output-dir ~/Downloads "https://nginx.org/download/nginx-$1.tar.gz" \
    -o "nginx-latest.tar.gz";

tar -zxf ~/Downloads/nginx-latest.tar.gz -C ~/Downloads;
rm ~/Downloads/nginx-latest.tar.gz;
sudo apt-get update;
sudo apt-get upgrade;

# Install dependencies if missing.
dpkg --get-selections | grep "[[:blank:]]install" \
    | grep "libpcre2-dev[:[:blank:]]" > /dev/null \
    || sudo apt-get install libpcre2-dev;
dpkg --get-selections | grep "[[:blank:]]install" \
    | grep "libpcre2-posix3[:[:blank:]]" > /dev/null \
    || sudo apt-get install libpcre2-posix3;
dpkg --get-selections | grep "[[:blank:]]install" \
    | grep "zlib1g-dev[:[:blank:]]" > /dev/null \
    || sudo apt-get install zlib1g-dev;
dpkg --get-selections | grep "[[:blank:]]install" \
    | grep "zlib1g[:[:blank:]]" > /dev/null \
    || sudo apt-get install zlib1g;
dpkg --get-selections | grep "[[:blank:]]install" \
    | grep "openssl[:[:blank:]]" > /dev/null \
    || sudo apt-get install openssl;
dpkg --get-selections | grep "[[:blank:]]install" \
    | grep "libssl-dev[:[:blank:]]" > /dev/null \
    || sudo apt-get install libssl-dev;
dpkg --get-selections | grep "[[:blank:]]install" \
    | grep "gcc[:[:blank:]]" > /dev/null \
    || sudo apt-get install gcc;

sudo apt-get autoremove;
sudo apt-get clean;
cd ~/Downloads/nginx-*;

./configure \
    --prefix=/usr/local/nginx \
    --with-http_ssl_module \
    --with-http_gunzip_module \
    --with-http_gzip_static_module \
    --with-http_v2_module \
    --with-http_v3_module \
    --with-stream;

make;
sudo make install;
cd ..;
rm -r nginx-*;

# Create symbolic link to nginx binary if missing.
[ -L /usr/local/bin/nginx ] \
    || sudo ln -s /usr/local/nginx/sbin/nginx /usr/local/bin/nginx;

# Create nginx user if missing.
awk -F : '{print $1}' /etc/passwd | grep "nginx" > /dev/null \
    || sudo useradd -r nginx;

sudo chown -R nginx /usr/local/nginx/logs;
sudo chmod -R 0744 /usr/local/nginx/logs;
