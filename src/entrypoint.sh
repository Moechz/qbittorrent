#!/bin/sh
# TOS wrapper for qBittorrent (linuxserver.io image).
#
# The WebUI is reached through a host port (8041 -> container 8080) and, if the
# user follows the package advice, through a TLS reverse proxy. The browser then
# sends a Host header whose port is not 8080, and qBittorrent's Host-header
# validation compares that port with its own listening port before anything
# else: every request - the HTML page, the CSS and the JS - is answered with
# 401 "Unauthorized", so the WebUI looks broken. Seed the preference before the
# app starts. CSRF protection stays enabled and the WebUI still requires the
# admin login; only the port/host comparison is turned off.
set -e
set -u

CONF=/config/qBittorrent/qBittorrent.conf
mkdir -p /config/qBittorrent

if [ ! -s "$CONF" ]; then
  printf '[WebUI]\nHostHeaderValidation=false\n' > "$CONF"
else
  # Current layout: a [WebUI] section with plain keys.
  if grep -q '^HostHeaderValidation=' "$CONF"; then
    sed -i 's/^HostHeaderValidation=.*/HostHeaderValidation=false/' "$CONF"
  elif grep -q '^\[WebUI\]' "$CONF"; then
    sed -i '/^\[WebUI\]/a HostHeaderValidation=false' "$CONF"
  else
    printf '\n[WebUI]\nHostHeaderValidation=false\n' >> "$CONF"
  fi
  # Older layouts keep the key under [Preferences] with the group prefix.
  if grep -q '^WebUI\\HostHeaderValidation=' "$CONF"; then
    sed -i 's/^WebUI\\HostHeaderValidation=.*/WebUI\\HostHeaderValidation=false/' "$CONF"
  fi
fi

exec /init
