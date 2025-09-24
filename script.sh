#!/bin/bash
set -e

mkdir -p /opt/pasarguard
mkdir -p /var/lib/pasarguard/certs
mkdir -p /var/lib/pasarguard/mysql

cp -f /opt/marzban/docker-compose.yml /opt/pasarguard/docker-compose.yml
cp -f /opt/marzban/.env /opt/pasarguard/.env

cp -a /var/lib/marzban/certs/. /var/lib/pasarguard/certs/
cp -a /var/lib/marzban/mysql/. /var/lib/pasarguard/mysql/
cp -a /var/lib/marzban/mysql-config /var/lib/pasarguard/
cp -a /var/lib/marzban/xray-config.json /var/lib/pasarguard/

yes | marzban uninstall
