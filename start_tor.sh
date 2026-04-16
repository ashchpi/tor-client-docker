#!/bin/sh

TOR_CONFIG_DIR="${TOR_CONFIG_DIR:-/etc/tor}"

fix_tor_permissions() {
  local DATA_DIR="${TOR_DATA_DIR:-/var/lib/tor}"
  if [ ! -d "$DATA_DIR" ]; then
    mkdir -p "$DATA_DIR"
  fi
  uown tor "$DATA_DIR"
  chmod 700 "$DATA_DIR"
}

fix_tor_permissions
/usr/bin/tor