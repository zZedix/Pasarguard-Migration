#!/bin/bash
set -e

mkdir -p /opt/pasarguard
mkdir -p /var/lib/pasarguard/certs
mkdir -p /var/lib/pasarguard/mysql

[ -f /opt/marzban/docker-compose.yml ] && cp -f /opt/marzban/docker-compose.yml /opt/pasarguard/docker-compose.yml
[ -f /opt/marzban/.env ] && cp -f /opt/marzban/.env /opt/pasarguard/.env
[ -d /var/lib/marzban/certs ] && cp -a /var/lib/marzban/certs/. /var/lib/pasarguard/certs/
[ -d /var/lib/marzban/mysql ] && cp -a /var/lib/marzban/mysql/. /var/lib/pasarguard/mysql/
[ -d /var/lib/marzban/mysql-config ] && cp -a /var/lib/marzban/mysql-config /var/lib/pasarguard/
[ -f /var/lib/marzban/xray-config.json ] && cp -a /var/lib/marzban/xray-config.json /var/lib/pasarguard/

[ -f /opt/pasarguard/docker-compose.yml ] && sed -i 's|image: *gozargah/marzban:latest|image: pasarguard/panel:latest|' /opt/pasarguard/docker-compose.yml
[ -f /opt/pasarguard/docker-compose.yml ] && sed -i 's|- /var/lib/marzban:/var/lib/marzban|- /var/lib/pasarguard:/var/lib/pasarguard|' /opt/pasarguard/docker-compose.yml

# If the Marzban binary exists, rename it to pasarguard
[ -f /usr/local/bin/marzban ] && mv /usr/local/bin/marzban /usr/local/bin/pasarguard

pasarguard update
pasarguard restart

echo "✅ Migration completed successfully!"
