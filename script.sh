#!/usr/bin/env bash
set -euo pipefail

MARZBAN_DIR="/opt/marzban"
PASARGUARD_DIR="/opt/pasarguard"
MARZBAN_DATA="/var/lib/marzban"
PASARGUARD_DATA="/var/lib/pasarguard"
MYSQL_MARZBAN_DIR="/var/lib/mysql/marzban"
MYSQL_PASARGUARD_DIR="/var/lib/mysql/pasarguard"
INSTALL_CLI="yes"
CHANGE_SQL_DRIVERS="auto"

log()  { echo -e "\033[1;32m[+] $*\033[0m"; }
warn() { echo -e "\033[1;33m[!] $*\033[0m"; }
err()  { echo -e "\033[1;31m[✗] $*\033[0m" >&2; }

require_root() {
  if [[ $EUID -ne 0 ]]; then
    err "This script must be run as root (use sudo)."
    exit 1
  fi
}

have() { command -v "$1" >/dev/null 2>&1; }

dcmd() {
  if have docker; then
    docker compose "$@"
  elif have docker-compose; then
    docker-compose "$@"
  else
    err "Docker or Docker Compose not found."
    exit 1
  fi
}

ts() { date +%Y%m%d-%H%M%S; }

require_root
log "Starting migration from Marzban to PasarGuard"

if [[ -d "$MARZBAN_DIR" ]]; then
  log "Stopping containers in $MARZBAN_DIR"
  (cd "$MARZBAN_DIR" && dcmd down || true)
else
  warn "Directory $MARZBAN_DIR not found; skipping container stop."
fi

BACKUP_DIR="/root/marzban-migration-backup-$(ts)"
mkdir -p "$BACKUP_DIR"
[[ -f "$MARZBAN_DIR/.env" ]] && cp -a "$MARZBAN_DIR/.env" "$BACKUP_DIR/.env.bak"
[[ -f "$MARZBAN_DIR/docker-compose.yml" ]] && cp -a "$MARZBAN_DIR/docker-compose.yml" "$BACKUP_DIR/docker-compose.yml.bak"
log "Backup saved to $BACKUP_DIR"

if [[ -d "$MARZBAN_DIR" ]]; then
  log "Renaming $MARZBAN_DIR → $PASARGUARD_DIR"
  mv "$MARZBAN_DIR" "$PASARGUARD_DIR"
fi

if [[ -d "$MARZBAN_DATA" ]]; then
  log "Renaming $MARZBAN_DATA → $PASARGUARD_DATA"
  mv "$MARZBAN_DATA" "$PASARGUARD_DATA"
else
  warn "Data directory $MARZBAN_DATA not found; skipping."
fi

if [[ -d "$MYSQL_MARZBAN_DIR" ]]; then
  log "Renaming $MYSQL_MARZBAN_DIR → $MYSQL_PASARGUARD_DIR"
  mkdir -p "$(dirname "$MYSQL_PASARGUARD_DIR")"
  mv "$MYSQL_MARZBAN_DIR" "$MYSQL_PASARGUARD_DIR"
else
  warn "MySQL directory not found; probably using SQLite or different path."
fi

ENV_FILE="$PASARGUARD_DIR/.env"
if [[ -f "$ENV_FILE" ]]; then
  log "Updating paths inside $ENV_FILE"
  sed -i 's|/var/lib/marzban|/var/lib/pasarguard|g' "$ENV_FILE"
  if [[ "$CHANGE_SQL_DRIVERS" != "no" ]]; then
    if grep -q 'sqlite:///db.sqlite3' "$ENV_FILE"; then
      log "Switching SQLite driver to aiosqlite"
      sed -i 's|sqlite:///db.sqlite3|sqlite+aiosqlite:///db.sqlite3|' "$ENV_FILE"
    fi
    if grep -q 'mysql+pymysql://' "$ENV_FILE"; then
      log "Switching MySQL driver to asyncmy"
      sed -i 's|mysql+pymysql://|mysql+asyncmy://|g' "$ENV_FILE"
    fi
  fi
else
  warn "No .env file found at $ENV_FILE"
fi

DC_FILE="$PASARGUARD_DIR/docker-compose.yml"
if [[ -f "$DC_FILE" ]]; then
  log "Updating $DC_FILE for PasarGuard"
  cp -a "$DC_FILE" "$BACKUP_DIR/docker-compose.yml.before-edit"
  awk '
    BEGIN{done=0}
    /^[[:space:]]*marzban:[[:space:]]*$/ && !done { sub(/^([[:space:]]*)marzban:/, "\\1pasarguard:"); done=1 }
    { print }
  ' "$DC_FILE" > "$DC_FILE.tmp" && mv "$DC_FILE.tmp" "$DC_FILE"
  sed -i 's|gozargah/marzban:latest|pasarguard/panel:latest|g' "$DC_FILE"
  sed -i 's|/var/lib/marzban|/var/lib/pasarguard|g' "$DC_FILE"
  sed -i 's|/var/lib/mysql/marzban|/var/lib/mysql/pasarguard|g' "$DC_FILE"
else
  warn "docker-compose.yml not found at $DC_FILE"
fi

if [[ -d "$PASARGUARD_DIR" ]]; then
  log "Fixing permissions for $PASARGUARD_DIR"
  chown -R "$SUDO_USER":"$SUDO_USER" "$PASARGUARD_DIR" || chown -R root:root "$PASARGUARD_DIR"
  chmod -R 755 "$PASARGUARD_DIR"
fi

if [[ "$INSTALL_CLI" == "yes" ]]; then
  log "Installing PasarGuard CLI script"
  bash -c "$(curl -sL https://github.com/PasarGuard/scripts/raw/main/pasarguard.sh)" @ install-script
else
  warn "Skipping CLI install (INSTALL_CLI=no)"
fi

if have pasarguard; then
  log "Starting PasarGuard service"
  pasarguard up
  log "Checking service status"
  pasarguard status || true
else
  warn "pasarguard command not found. Start manually: (cd \"$PASARGUARD_DIR\" && docker compose up -d)"
fi

log "Migration completed successfully!"
echo
echo "Rollback instructions if needed:"
cat <<'ROLLBACK'
  cd /opt/pasarguard && docker compose down || true
  mv /opt/pasarguard /opt/marzban || true
  mv /var/lib/pasarguard /var/lib/marzban || true
  if [ -d /var/lib/mysql/pasarguard ]; then
    mv /var/lib/mysql/pasarguard /var/lib/mysql/marzban || true
  fi
  # Restore backed-up docker-compose.yml and .env if required, then run:
  # marzban up
ROLLBACK
#!/usr/bin/env bash
set -euo pipefail

MARZBAN_DIR="/opt/marzban"
PASARGUARD_DIR="/opt/pasarguard"
MARZBAN_DATA="/var/lib/marzban"
PASARGUARD_DATA="/var/lib/pasarguard"
MYSQL_MARZBAN_DIR="/var/lib/mysql/marzban"
MYSQL_PASARGUARD_DIR="/var/lib/mysql/pasarguard"
INSTALL_CLI="yes"
CHANGE_SQL_DRIVERS="auto"

log()  { echo -e "\033[1;32m[+] $*\033[0m"; }
warn() { echo -e "\033[1;33m[!] $*\033[0m"; }
err()  { echo -e "\033[1;31m[✗] $*\033[0m" >&2; }

require_root() {
  if [[ $EUID -ne 0 ]]; then
    err "This script must be run as root (use sudo)."
    exit 1
  fi
}

have() { command -v "$1" >/dev/null 2>&1; }

dcmd() {
  if have docker; then
    docker compose "$@"
  elif have docker-compose; then
    docker-compose "$@"
  else
    err "Docker or Docker Compose not found."
    exit 1
  fi
}

ts() { date +%Y%m%d-%H%M%S; }

require_root
log "Starting migration from Marzban to PasarGuard"

if [[ -d "$MARZBAN_DIR" ]]; then
  log "Stopping containers in $MARZBAN_DIR"
  (cd "$MARZBAN_DIR" && dcmd down || true)
else
  warn "Directory $MARZBAN_DIR not found; skipping container stop."
fi

BACKUP_DIR="/root/marzban-migration-backup-$(ts)"
mkdir -p "$BACKUP_DIR"
[[ -f "$MARZBAN_DIR/.env" ]] && cp -a "$MARZBAN_DIR/.env" "$BACKUP_DIR/.env.bak"
[[ -f "$MARZBAN_DIR/docker-compose.yml" ]] && cp -a "$MARZBAN_DIR/docker-compose.yml" "$BACKUP_DIR/docker-compose.yml.bak"
log "Backup saved to $BACKUP_DIR"

if [[ -d "$MARZBAN_DIR" ]]; then
  log "Renaming $MARZBAN_DIR → $PASARGUARD_DIR"
  mv "$MARZBAN_DIR" "$PASARGUARD_DIR"
fi

if [[ -d "$MARZBAN_DATA" ]]; then
  log "Renaming $MARZBAN_DATA → $PASARGUARD_DATA"
  mv "$MARZBAN_DATA" "$PASARGUARD_DATA"
else
  warn "Data directory $MARZBAN_DATA not found; skipping."
fi

if [[ -d "$MYSQL_MARZBAN_DIR" ]]; then
  log "Renaming $MYSQL_MARZBAN_DIR → $MYSQL_PASARGUARD_DIR"
  mkdir -p "$(dirname "$MYSQL_PASARGUARD_DIR")"
  mv "$MYSQL_MARZBAN_DIR" "$MYSQL_PASARGUARD_DIR"
else
  warn "MySQL directory not found; probably using SQLite or different path."
fi

ENV_FILE="$PASARGUARD_DIR/.env"
if [[ -f "$ENV_FILE" ]]; then
  log "Updating paths inside $ENV_FILE"
  sed -i 's|/var/lib/marzban|/var/lib/pasarguard|g' "$ENV_FILE"
  if [[ "$CHANGE_SQL_DRIVERS" != "no" ]]; then
    if grep -q 'sqlite:///db.sqlite3' "$ENV_FILE"; then
      log "Switching SQLite driver to aiosqlite"
      sed -i 's|sqlite:///db.sqlite3|sqlite+aiosqlite:///db.sqlite3|' "$ENV_FILE"
    fi
    if grep -q 'mysql+pymysql://' "$ENV_FILE"; then
      log "Switching MySQL driver to asyncmy"
      sed -i 's|mysql+pymysql://|mysql+asyncmy://|g' "$ENV_FILE"
    fi
  fi
else
  warn "No .env file found at $ENV_FILE"
fi

DC_FILE="$PASARGUARD_DIR/docker-compose.yml"
if [[ -f "$DC_FILE" ]]; then
  log "Updating $DC_FILE for PasarGuard"
  cp -a "$DC_FILE" "$BACKUP_DIR/docker-compose.yml.before-edit"
  awk '
    BEGIN{done=0}
    /^[[:space:]]*marzban:[[:space:]]*$/ && !done { sub(/^([[:space:]]*)marzban:/, "\\1pasarguard:"); done=1 }
    { print }
  ' "$DC_FILE" > "$DC_FILE.tmp" && mv "$DC_FILE.tmp" "$DC_FILE"
  sed -i 's|gozargah/marzban:latest|pasarguard/panel:latest|g' "$DC_FILE"
  sed -i 's|/var/lib/marzban|/var/lib/pasarguard|g' "$DC_FILE"
  sed -i 's|/var/lib/mysql/marzban|/var/lib/mysql/pasarguard|g' "$DC_FILE"
else
  warn "docker-compose.yml not found at $DC_FILE"
fi

if [[ -d "$PASARGUARD_DIR" ]]; then
  log "Fixing permissions for $PASARGUARD_DIR"
  chown -R "$SUDO_USER":"$SUDO_USER" "$PASARGUARD_DIR" || chown -R root:root "$PASARGUARD_DIR"
  chmod -R 755 "$PASARGUARD_DIR"
fi

if [[ "$INSTALL_CLI" == "yes" ]]; then
  log "Installing PasarGuard CLI script"
  bash -c "$(curl -sL https://github.com/PasarGuard/scripts/raw/main/pasarguard.sh)" @ install-script
else
  warn "Skipping CLI install (INSTALL_CLI=no)"
fi

if have pasarguard; then
  log "Starting PasarGuard service"
  pasarguard up
  log "Checking service status"
  pasarguard status || true
else
  warn "pasarguard command not found. Start manually: (cd \"$PASARGUARD_DIR\" && docker compose up -d)"
fi

log "Migration completed successfully!"
echo
echo "Rollback instructions if needed:"
cat <<'ROLLBACK'
  cd /opt/pasarguard && docker compose down || true
  mv /opt/pasarguard /opt/marzban || true
  mv /var/lib/pasarguard /var/lib/marzban || true
  if [ -d /var/lib/mysql/pasarguard ]; then
    mv /var/lib/mysql/pasarguard /var/lib/mysql/marzban || true
  fi
  # Restore backed-up docker-compose.yml and .env if required, then run:
  # marzban up
ROLLBACK
