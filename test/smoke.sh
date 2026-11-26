#!/usr/bin/env bash
# Functional smoke test for the qBittorrent TOS package.
#
# Usage:  bash test/smoke.sh [http://127.0.0.1:8041]
#
# It proves the three things a BitTorrent client must do after installation:
#   1. the WebUI page loads through the published port (the F7 regression),
#   2. the admin login and the WebUI API answer,
#   3. a task can be added and is visible in the torrent list.
#
# Exit code 0 only when every check passes. The initial password is read from
# the per-install credentials file (0600) inside the container's /config mount,
# or from QBT_PASSWORD for a pre-seeded instance. It is never printed.
set -u

BASE="${1:-http://127.0.0.1:8041}"
BASE="${BASE%/}"
HASH="${QBT_SMOKE_HASH:-$(python3 -c 'import secrets; print(secrets.token_hex(20))')}"
DOCKER_BIN="${TOSDOCKER_DOCKER:-/Volume1/@apps/DockerEngine/dockerd/bin/docker}"
COOKIE="$(mktemp)"
BODY="$(mktemp)"
CID=""
FAIL=0

say() { printf '  [smoke] %s\n' "$*"; }
ok()  { printf '  [ OK ] %s\n' "$*"; }
bad() { printf '  [FAIL] %s\n' "$*"; FAIL=1; }

cleanup() {
  if [ -n "$CID" ] && [ -s "$COOKIE" ]; then
    curl -sS -m 10 -b "$COOKIE" -H "Origin: $BASE" -H "Referer: $BASE/" \
      --data-urlencode "hashes=$HASH" --data-urlencode "deleteFiles=true" \
      "$BASE/api/v2/torrents/delete" >/dev/null 2>&1 || true
  fi
  rm -f "$COOKIE" "$BODY"
}
trap cleanup EXIT

# --- locate the container (needed only to read the initial password) --------
SUDO=0
if [ -x "$DOCKER_BIN" ]; then
  if "$DOCKER_BIN" ps >/dev/null 2>&1; then
    :
  elif sudo -n "$DOCKER_BIN" ps >/dev/null 2>&1; then
    SUDO=1
  fi
fi
dk() {
  if [ "$SUDO" = 1 ]; then sudo -n "$DOCKER_BIN" "$@"; else "$DOCKER_BIN" "$@"; fi
}

PORT="$(printf '%s' "$BASE" | sed -n \
  's#^[a-zA-Z][a-zA-Z0-9+.-]*://[^/:]*:\([0-9][0-9]*\).*#\1#p')"
[ -n "$PORT" ] || PORT=80

if [ "$SUDO" = 1 ] || { [ "$SUDO" = 0 ] && [ -x "$DOCKER_BIN" ]; }; then
  CID="$(dk ps --format '{{.ID}} {{.Ports}}' 2>/dev/null |
    awk -v p=":$PORT->" 'index($0, p) {print $1; exit}')"
fi

PW="${QBT_PASSWORD:-}"
if [ -z "$PW" ] && [ -n "$CID" ]; then
  SRC="$(dk inspect "$CID" --format \
    '{{range .Mounts}}{{if eq .Destination "/config"}}{{.Source}}{{end}}{{end}}' 2>/dev/null)"
  if [ -n "$SRC" ] && [ -r "$SRC/qBittorrent/webui-credentials.txt" ]; then
    PW="$(sed -n 's/^password=//p' "$SRC/qBittorrent/webui-credentials.txt" | head -n 1)"
  fi
fi
if [ -z "$PW" ] && [ -n "$CID" ]; then
  PW="$(dk logs "$CID" 2>&1 |
    sed -n 's/.*temporary password is provided for this session: //p' | tail -n 1)"
fi
if [ -z "$PW" ]; then
  bad "cannot obtain the initial WebUI password (set QBT_PASSWORD or expose /config)"
  exit 1
fi

# --- 1. page + login ---------------------------------------------------------
CODE="$(curl -sS -m 15 -o "$BODY" -w '%{http_code}' "$BASE/" 2>/dev/null || printf '000')"
SIZE="$(wc -c < "$BODY" 2>/dev/null | tr -d ' ')"
if [ "$CODE" = "200" ] && [ "${SIZE:-0}" -gt 500 ] && grep -qi 'qBittorrent' "$BODY"; then
  ok "WebUI page loads through the published port (HTTP 200, ${SIZE} bytes)"
else
  bad "WebUI page missing (HTTP ${CODE}, ${SIZE:-0} bytes)"
fi

LOGIN_CODE="$(curl -sS -m 15 -o "$BODY" -w '%{http_code}' -c "$COOKIE" \
  --data-urlencode "username=admin" --data-urlencode "password=$PW" \
  "$BASE/api/v2/auth/login" 2>/dev/null || printf '000')"
LOGIN_BODY="$(cat "$BODY" 2>/dev/null)"
case "$LOGIN_CODE" in
  204) ok "admin login accepted (HTTP 204)" ;;
  200)
    if [ "$LOGIN_BODY" = "Ok." ]; then
      ok "admin login accepted (HTTP 200)"
    else
      bad "admin login rejected (HTTP 200: ${LOGIN_BODY:-empty})"
    fi
    ;;
  *) bad "admin login failed (HTTP ${LOGIN_CODE})" ;;
esac
[ "$FAIL" = 0 ] || { echo "SMOKE FAILED"; exit 1; }

# --- 2. API ------------------------------------------------------------------
VER="$(curl -sS -m 10 -b "$COOKIE" "$BASE/api/v2/app/version" 2>/dev/null)"
case "$VER" in
  v*) ok "API /app/version -> ${VER}" ;;
  *)  bad "API /app/version returned '${VER}'" ;;
esac

# --- 3. add a task and read it back -----------------------------------------
ADD_CODE="$(curl -sS -m 20 -o "$BODY" -w '%{http_code}' -b "$COOKIE" \
  -H "Origin: $BASE" -H "Referer: $BASE/" \
  --data-urlencode "urls=magnet:?xt=urn:btih:$HASH&dn=tos-smoke-test" \
  --data-urlencode "paused=true" \
  "$BASE/api/v2/torrents/add" 2>/dev/null || printf '000')"
case "$ADD_CODE" in
  200) ok "add torrent accepted (HTTP 200)" ;;
  *)   bad "add torrent failed (HTTP ${ADD_CODE})" ;;
esac

sleep 1
INFO="$(curl -sS -m 10 -b "$COOKIE" "$BASE/api/v2/torrents/info" 2>/dev/null)"
if printf '%s' "$INFO" | python3 -c '
import json, sys
want = sys.argv[1].lower()
try:
    items = json.load(sys.stdin)
except Exception:
    sys.exit(2)
sys.exit(0 if any(str(t.get("hash", "")).lower() == want for t in items) else 1)
' "$HASH"; then
  ok "the added task appears in the torrent list"
else
  bad "the added task is missing from the torrent list"
fi

DEL_CODE="$(curl -sS -m 10 -o "$BODY" -w '%{http_code}' -b "$COOKIE" \
  -H "Origin: $BASE" -H "Referer: $BASE/" \
  --data-urlencode "hashes=$HASH" --data-urlencode "deleteFiles=true" \
  "$BASE/api/v2/torrents/delete" 2>/dev/null || printf '000')"
case "$DEL_CODE" in
  200) ok "delete torrent accepted (HTTP 200)" ;;
  *)   bad "delete torrent failed (HTTP ${DEL_CODE})" ;;
esac

if [ "$FAIL" = 0 ]; then
  echo "SMOKE OK"
  exit 0
fi
echo "SMOKE FAILED"
exit 1
