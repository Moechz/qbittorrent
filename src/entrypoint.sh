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
#
# Two more things happen here, both measured against the 5.3.0 image:
#
# 1. On a first start the image itself copies /defaults/qBittorrent.conf into
#    the config volume. Writing a minimal config instead (as 5.3.0-2 did) skips
#    its Downloads\SavePath=/downloads/ default, so downloads silently landed
#    in /config/Downloads and UPnP stayed enabled. Seed the image defaults and
#    migrate the wrong path from 5.3.0-2.
#
# 2. qBittorrent prints a *temporary WebUI password* into the container log
#    when no password is configured (the F10 finding). Instead, generate a
#    random password for this installation, store its PBKDF2 hash in the config
#    and keep the plaintext only in a 0600 file; the log names the path, never
#    the credential.
set -e
set -u
umask 077

CONF_DIR=/config/qBittorrent
CONF="$CONF_DIR/qBittorrent.conf"
CRED="$CONF_DIR/webui-credentials.txt"

mkdir -p "$CONF_DIR"

# First start: use the image's own defaults. They carry the correct save paths,
# the accepted legal notice and UPnP=off. Never replace them with a bare config.
if [ ! -s "$CONF" ]; then
  if [ -s /defaults/qBittorrent.conf ]; then
    cp /defaults/qBittorrent.conf "$CONF"
  else
    printf '%s\n' \
      '[LegalNotice]' 'Accepted=true' '' \
      '[Preferences]' \
      'Downloads\SavePath=/downloads/' \
      'Downloads\TempPath=/downloads/incomplete/' \
      'WebUI\Address=*' > "$CONF"
  fi
fi

python3 - "$CONF" "$CRED" <<'PY'
import base64
import hashlib
import os
import re
import secrets
import sys

conf, cred = sys.argv[1], sys.argv[2]
text = open(conf, encoding="utf-8").read() if os.path.exists(conf) else ""
if not text.strip():
    text = ("[LegalNotice]\nAccepted=true\n\n[Preferences]\n"
            "Downloads\\SavePath=/downloads/\n"
            "Downloads\\TempPath=/downloads/incomplete/\n"
            "WebUI\\Address=*\n")

# 5.3.0-2 wrote a minimal config, so qBittorrent fell back to
# $HOME/Downloads = /config/Downloads. Move that setting to the mounted volume.
text = re.sub(r"(?m)^(Session\\DefaultSavePath|Downloads\\SavePath)=/config/Downloads(?:/)?$",
              lambda m: m.group(1) + "=/downloads/", text)
text = re.sub(r"(?m)^(Session\\TempPath|Downloads\\TempPath)=/config/Downloads(?:/(?:incomplete|temp))?/?$",
              lambda m: m.group(1) + "=/downloads/incomplete/", text)

# qBittorrent 5.3 migrates the old [Preferences] WebUI\... layout to a [WebUI]
# section. Patch whichever layout the file already uses.
new_layout = ("[Meta]" in text) or ("[WebUI]" in text)


def set_key(text, section, key, value, alt=None):
    """Replace an existing key, otherwise insert it into (or create) section."""
    for candidate in (key, alt):
        if not candidate:
            continue
        pat = re.compile(r"(?m)^" + re.escape(candidate) + r"=.*$")
        if pat.search(text):
            return pat.sub(lambda m: candidate + "=" + value, text, count=1)
    header = "[" + section + "]"
    hdr = re.compile(r"(?m)^" + re.escape(header) + r"\s*$")
    if hdr.search(text):
        return hdr.sub(lambda m: m.group(0) + "\n" + key + "=" + value,
                       text, count=1)
    return text.rstrip("\n") + "\n\n" + header + "\n" + key + "=" + value + "\n"


if new_layout:
    text = set_key(text, "WebUI", "HostHeaderValidation", "false",
                   "WebUI\\HostHeaderValidation")
else:
    text = set_key(text, "Preferences", "WebUI\\HostHeaderValidation", "false",
                   "HostHeaderValidation")

# 5.3.0-2 skipped the image defaults, so UPnP fell back to its default ON.
# Keep the package's documented default (off) on upgrade. Do not override an
# explicit user choice.
if new_layout:
    if not re.search(r"(?m)^(?:PortForwardingEnabled|Connection\\UPnP)=", text):
        text = set_key(text, "Network", "PortForwardingEnabled", "false",
                       "Connection\\UPnP")
else:
    if not re.search(r"(?m)^(?:Connection\\UPnP|PortForwardingEnabled)=", text):
        text = set_key(text, "Preferences", "Connection\\UPnP", "false",
                       "PortForwardingEnabled")

# No plaintext password in the log (F10). Reuse an existing credentials file,
# otherwise generate one per installation. A password already present in the
# config (the user changed it) is never touched.
if not re.search(r"(?m)^(?:WebUI\\)?Password_PBKDF2=", text):
    pwd = ""
    if os.path.exists(cred):
        for line in open(cred, encoding="utf-8"):
            if line.startswith("password="):
                pwd = line.split("=", 1)[1].rstrip("\r\n")
                break
    if not pwd:
        pwd = secrets.token_urlsafe(18)
        with open(cred, "w", encoding="utf-8") as fh:
            fh.write("username=admin\npassword=" + pwd + "\n")
        os.chmod(cred, 0o600)
    salt = secrets.token_bytes(16)
    digest = hashlib.pbkdf2_hmac("sha512", pwd.encode("utf-8"), salt,
                                 100000, 64)
    blob = (base64.b64encode(salt).decode("ascii") + ":" +
            base64.b64encode(digest).decode("ascii"))
    value = '"@ByteArray(' + blob + ')"'
    if new_layout:
        text = set_key(text, "WebUI", "Password_PBKDF2", value,
                       "WebUI\\Password_PBKDF2")
    else:
        text = set_key(text, "Preferences", "WebUI\\Password_PBKDF2", value,
                       "Password_PBKDF2")

open(conf, "w", encoding="utf-8", newline="\n").write(text)
try:
    os.chmod(conf, 0o600)
except OSError:
    pass
print("qBittorrent WebUI credentials: " + cred +
      " (user admin, mode 0600). Change the password after the first login and delete the file.")
PY

# Key files stay private to the app user (S11). The directory mode is best
# effort: a platform-created mount root may be owned by root.
chmod 700 "$CONF_DIR" 2>/dev/null || true
chmod 600 "$CONF" 2>/dev/null || true
chmod 600 "$CRED" 2>/dev/null || true

exec /init
