# qbittorrent-for-tos

> TerraMaster TOS 7 App Center — **Docker application** package for
> [qBittorrent](https://github.com/qbittorrent/qBittorrent) 5.3.0.

## What this is

A four-file TOS Docker application archive (`qbittorrentdocker.tar.gz`) that installs
qBittorrent on TOS 7 through the App Center, plus the repository material used to build,
verify and document it:

- `config.ini` — TOS application metadata (`application_type: docker`, id `qbittorrentdocker`)
- `qbittorrentdocker.lang` — 23-language superset (TOS requires 14)
- `qbittorrentdocker.svg` — application icon
- `docker-compose.yml` — one service, the pinned LinuxServer.io image and a small wrapper
  entrypoint (`src/entrypoint.sh`)

The upstream image is used unmodified. All user data stays on the NAS; there is no developer
account, telemetry or analytics.

## Repository layout

```text
.
├── config.ini / CHANGELOG.md / LICENSE / NOTICE.md / PRIVACY.md / README.md
├── src/
│   ├── config.ini                  # TOS metadata template (@@VERSION@@ / @@PLATFORM@@)
│   ├── docker-compose.yml          # one service, image pinned by digest
│   ├── entrypoint.sh               # inline wrapper, embedded into the compose file
│   ├── qbittorrentdocker.lang      # generated from tosapp.json
│   └── qbittorrentdocker.svg
├── scripts/build.sh                # stage -> verify -> tar.gz -> sha256
├── scripts/build-dual.sh           # x86_64 + aarch64 + official -c
├── test/install-and-verify.sh      # on-device E2E (root, official installer)
├── test/smoke.sh                   # login + add-task smoke test (base URL argument)
├── tools/verify.py                 # package conformance self-check
├── tosapp.json                     # the app spec / metadata source
└── TOSAppSelfTestingTool           # official TerraMaster checker (not packaged)
```

## How it works

| | |
|---|---|
| Container image | `linuxserver/qbittorrent:5.3.0`, pinned by the OCI index digest `sha256:a8083a33…b619` (build `5.3.0_v2.1.3-ls489`, 2026-11-23) |
| Web UI | `http://<NAS-IP>:8041/` → container port `8080` |
| Runs as | non-root `1000:1000`, `cap_drop: [ALL]`, `no-new-privileges`, `tmpfs /run` owned by uid 1000 |
| Persistent data | `/Volume1/DockerAppData/qbittorrentdocker/config` → `/config` and `/Volume1/DockerAppData/qbittorrentdocker/downloads` → `/downloads` |
| Logs | `docker logs qbittorrentdocker` (stdout/stderr) and `.../config/qBittorrent/logs/qbittorrent.log` |
| Health check | `curl -fsS http://127.0.0.1:8080/` — a 401/5xx is unhealthy |
| BT listen port | 6881 inside the container, **not published** (single-port store rule) |

The wrapper does three things before the upstream `/init`:

1. **Seeds the image defaults on first start.** It copies `/defaults/qBittorrent.conf` into
   the config volume, so `Downloads\SavePath=/downloads/`, `TempPath=/downloads/incomplete/`
   and `Connection\UPnP=false` are active. Writing a minimal hand-written config (as
   5.3.0-2 did) skipped those defaults: downloads silently went to `/config/Downloads` and
   UPnP fell back to on. Existing configs are migrated (save path, temp path, UPnP).
2. **Turns off the Host-header port check.** qBittorrent compares the browser's `Host` port
   with its own 8080; through 8041 or a TLS reverse proxy every request — HTML, CSS and JS —
   returns 401 and the page looks broken (the F7 finding). Authentication and CSRF protection
   stay enabled. Keep the UI on a trusted LAN or behind an authenticated TLS proxy.
3. **Generates a random WebUI password per installation.** qBittorrent normally prints a
   temporary password into the container log (the F10 finding). The wrapper instead stores
   the PBKDF2-HMAC-SHA512 hash in `qBittorrent.conf` and the plaintext only in
   `config/qBittorrent/webui-credentials.txt` (mode 0600); the log names the file, not the
   password.

## Install and first login

1. Install the package from App Center. On first start the wrapper creates
   `/Volume1/DockerAppData/qbittorrentdocker/config/qBittorrent/webui-credentials.txt`
   (mode 0600) containing `username=admin` and a random `password=…`.
2. Read the file (TOS File Manager, SMB, or SSH) and open `http://<NAS-IP>:8041/`.
3. Log in as `admin` with that password, change it in the WebUI (Settings → WebUI), then
   **delete `webui-credentials.txt`**. No default password exists, and the password is never
   printed in the container log.
4. Downloads are written below
   `/Volume1/DockerAppData/qbittorrentdocker/downloads/`. The downloads folder is not shown in
   TOS File Manager; use SMB/SSH or add the path to a backup task.

## Data, backup and uninstall

All state is below `/Volume1/DockerAppData/qbittorrentdocker/`:

| Path | What it is | Backup? |
|---|---|---|
| `config/qBittorrent/qBittorrent.conf` | settings and the PBKDF2 password hash | yes, contains the WebUI hash |
| `config/qBittorrent/webui-credentials.txt` | initial password, mode 0600 | not needed after the first login |
| `config/qBittorrent/BT_backup/` | `.torrent` metadata and resume data | yes, avoids re-checking |
| `config/qBittorrent/GeoDB/`, `logs/`, `rss/`, `categories.json`, `watched_folders.json` | optional caches/state | no |
| `downloads/` | the payload | your call; may be large |

**Uninstall and residual data (F11/F4).** The TOS App Center has no uninstall hook for Docker
applications, so removing the app stops and removes the container but deliberately keeps the
data folders. To remove everything, stop the app, then delete
`/Volume1/DockerAppData/qbittorrentdocker/` (or tick “delete data” during uninstall). Deleting
the app also removes its install directory below `/Volume1/@apps/DockerEngine/application/`;
the data folder is the only place this package writes.

Docker applications cannot be upgraded in place: updating means uninstall and reinstall,
which keeps the data folders unless you delete them. Move any files downloaded by 5.3.0-2
under `config/Downloads/` to `downloads/` if you used that version.

## Privacy

**The developer does not collect, receive or have access to any data processed by the app.**
There is no account, telemetry, analytics or crash reporting.

| Topic | Detail |
|---|---|
| Data processed | settings and the WebUI PBKDF2 hash, the initial password file, resume data and `.torrent` metadata, the GeoIP database and the local log (all under `/config`), plus the downloaded payload (`/downloads`). |
| Where | Only on your NAS. Nothing is uploaded to the developer. |
| Retention | Until **you** delete it. The log is rotated by qBittorrent; the GeoIP database is replaced monthly; the credentials file should be deleted after the first login. |
| Rights | **Access/export:** copy the data folder. **Correct:** edit in the WebUI. **Delete:** uninstall with “delete data”, or remove the folder. **Contact:** moechz@163.com (reply within 30 days). |
| Security | uid 1000, `cap_drop: ALL`, `no-new-privileges`, no host network/socket/`cap_add`, one published port, image pinned by digest, config and credentials 0600, random per-install password, no plaintext credential in logs. |

**Public IP and BitTorrent (C8).** The trackers, DHT nodes, peers and web seeds of the
torrents you add necessarily see your public IP and client port. This is how BitTorrent
works; no VPN is included. DHT, PeX and LSD are on by default; UPnP is off in this package.
Use Settings → Connection → Proxy Server, or a VPN, if the traffic must not be attributable
to your line. The full endpoint list, the data sent and the off switch for each item are in
[PRIVACY.md](PRIVACY.md) §7. Read it before using the app on a network where your IP matters.

**Full privacy policy:** [PRIVACY.md](PRIVACY.md) —
<https://github.com/Moechz/qbittorrent/blob/main/PRIVACY.md>.

## Third-party endpoints (summary)

| Endpoint | What it sends | How to turn it off |
|---|---|---|
| Trackers in your torrents | info-hash, peer ID, counters, **public IP:port** | not while the torrent runs; remove trackers, add paused, or use a proxy/VPN |
| Peers of your torrents | **public IP:port**, client version, piece bitmap, data | stop the torrent or use a VPN |
| Web seeds in a torrent | HTTP GET, IP, info-hash | remove the web-seed URLs / do not add such torrents |
| DHT (`dht.libtorrent.org:25401`, `dht.transmissionbt.com:6881`, `router.bt.ouinet.work:6881`) | info-hashes, **public IP:port** | Settings → BitTorrent → uncheck DHT |
| PeX | peer list, IP:port | uncheck PeX |
| LSD (LAN multicast) | info-hash, private LAN IP | uncheck local peer discovery |
| DB-IP (`download.db-ip.com`) | HTTP GET, IP, User-Agent | uncheck “Resolve peer countries” |
| GitHub search plugins + search sites | search terms, IP | do not use Search |
| RSS feeds you add | HTTP GET, IP | remove the subscription |
| Google STUN (`stun.l.google.com:19302`) | STUN binding, **public IP:port** | only used if WebTorrent peer support is enabled; block UDP 19302 |
| Docker Hub / your registry mirror | anonymous image pull, IP | install/update only |
| GitHub / moechz.com (help links) | normal browser request | do not open the link |

There is no telemetry, analytics or automatic update check to the developer. The developer
operates no server in this path.

## Security

- Non-root `1000:1000`; all Linux capabilities dropped; `no-new-privileges`; `/run` is a
  uid-1000 tmpfs so s6-overlay can start without `CAP_CHOWN`. Measured `CapEff=0`.
- Only the WebUI is published. The BitTorrent port stays inside the container.
- `umask 077`; `qBittorrent.conf` and `webui-credentials.txt` are 0600, the config directory
  0700 (best effort on platform-created mount roots).
- Random per-install WebUI password, no default, never in the log. Change it on first login.
- The WebUI is plain HTTP. Put it behind a TLS reverse proxy before exposing it, and remember
  that Host-header validation is off (see above) — do not publish 8041 directly.
- The image is pinned by digest; the package is rebuilt when LinuxServer.io ships a newer
  `5.3.0-ls*` build.

## Notices and licences

- qBittorrent source: **GPL-2.0-or-later**. Distributed binary: **GPL-3.0-or-later** with
  the OpenSSL linking exception (see upstream `COPYING`).
- Image: `linuxserver/qbittorrent:5.3.0`, index digest
  `sha256:a8083a33…b619`, amd64 `sha256:a2bf05fd…f994`, arm64
  `sha256:bf459ae1…56bd`, build `5.3.0_v2.1.3-ls489` (2026-11-23), LinuxServer.io.
- The image's build scripts are GPL-3.0-only per the image label; the image is pulled at
  install time and not redistributed here.
- Components inside the image (Qt 6.12.1, libtorrent 2.1.3.0, Boost 1.92.0, OpenSSL 4.1.0,
  zlib 1.3.2, s6-overlay 3.2.1.0, Alpine) are documented in [NOTICE.md](NOTICE.md) §3.
- This packaging is **MIT** (`LICENSE`); the icon is the qBittorrent Simple Icons mark (CC0
  artwork, trademark of the project). “qBittorrent”, “LinuxServer.io”, “TerraMaster” and “TOS”
  are trademarks of their owners; this package is not affiliated with them.

## Build

```bash
scripts/build.sh 5.3.0-3 x86_64     # one architecture -> out/qbittorrentdocker.tar.gz
scripts/build-dual.sh 5.3.0-3       # both architectures + official -c on each
```

`build.sh` stages the four files, substitutes `@@VERSION@@`/`@@PLATFORM@@`, embeds
`src/entrypoint.sh` into the compose block scalar (escaping `$` as `$$`), removes CRLF/BOM/
AppleDouble, packs GNU tar with zeroed timestamps and gzip without a timestamp, writes the
SHA-256, then runs `tools/verify.py`. The self-check covers archive layout, JSON validity,
required fields, 23 languages, version consistency, Docker-Hub-only images, a fixed tag, the
reserved/recommended host-port rules, non-root user, per-service healthcheck/TZ/restart, data
paths below the app data root, the `/Volume*` wildcard, comment-free sequence blocks,
`x-app-meta` position, no literal secrets, no ASCII semicolons in `.lang` values, the icon
size/element limits and the embedded entrypoint being byte-identical to `src/entrypoint.sh`.

## Verification (this release)

```text
scripts/build-dual.sh 5.3.0-3
  verify OK (x86_64 and aarch64)              # tools/verify.py
  TOSAppSelfTestingTool -c                    # "check passed" for both packages
python3 stage.py work/qbittorrent --timeout 300
  passed 3, failed 0                          # running/healthy, HTTP 200, user=1000
python3 smoke.py work/qbittorrent --timeout 300
  smoke passed                                # 1 container, 1 port, no fatal log
  test/smoke.sh http://127.0.0.1:<port>
    page 200 / login 204 / API v5.3.0 / add torrent 200 / listed / delete 200
```

Manual checks on the built package (isolated staging, x86_64): `CapEff=0`, config and
credentials 0600, no password in the container log, `save_path=/downloads`,
`temp_path=/downloads/incomplete`, `upnp=false`, torrent list survives a container restart,
`docker stop` exits 0 in ~7 s, and a 5.3.0-2 config with `/config/Downloads` is migrated.

The aarch64 package passes the official conformance check and is built from the same
multi-architecture image index; it is not executed on ARM hardware in this environment.

## Store submission checklist

1. Public GitHub repo (code + README only).
2. Release **tag `v5.3.0-3`**, assets `qbittorrentdocker_x86_64.tar.gz` +
   `qbittorrentdocker_aarch64.tar.gz` (+ `.sha256` each) — Docker asset naming:
   `<app_id>_<arch>.tar.gz`, one archive per architecture.
3. Developer platform → Add Application: ID `qbittorrentdocker`, package type Docker,
   repository URL, architecture `x86_64` (and a second record for `aarch64`).
4. Version Management → Add Version `5.3.0-3` → automated validation → review, with the
   remark “Rectified per review comments”.
5. Verify the platform `file_hash` equals the local `sha256sum` (V7).

## Review remediation (5.3.0-2 → 5.3.0-3)

| Finding | What was done |
|---|---|
| **F10** sensitive information in logs | Removed the upstream temporary WebUI password from the log path. Each installation now gets a random password, PBKDF2-HMAC-SHA512 in the config, plaintext only in `webui-credentials.txt` (0600); the log prints the file path, never the credential. |
| **F11 / F4** residual data after uninstall | README “Data, backup and uninstall” lists every path and the exact deletion step. The package cannot add a TOS uninstall hook; the platform keeps the data folder by design. |
| **F2** service fails to start | The wrapper now seeds `/defaults/qBittorrent.conf` instead of writing a minimal config, so the first start has valid save paths/UPnP. Health check start period 90 s; start/restart re-tested. |
| **F3** service fails to stop cleanly | `stop_grace_period: 30s`; `docker stop` exits 0 in ~7 s, qBittorrent logs a clean termination, no zombie processes. |
| **F7** Web UI does not work correctly | Host-header port validation is disabled before start, so `http://NAS:8041/`, the static assets and a reverse proxy all load (HTTP 200); login and CSRF remain enabled. |
| **F8** data not persisted across restarts | Volumes unchanged and re-verified: config, password hash, torrent list and payload survive a restart. The wrapper also migrates 5.3.0-2's `/config/Downloads`. |
| **F9** no recovery after a NAS restart | `restart: unless-stopped`, health check re-verified; container starts again and serves the WebUI after a restart. |
| **S11** file permissions not minimised | `umask 077`, config/credentials 0600, config dir 0700, non-root uid 1000, `cap_drop: [ALL]`, `no-new-privileges`, uid-1000 `/run` tmpfs. |
| **C2** licence | Corrected to `GPL-3.0-or-later` for the binary (source `GPL-2.0-or-later`, OpenSSL exception) after reading upstream `COPYING`; NOTICE rewritten with image digests. |
| **C8** third-party disclosure | New endpoint table in PRIVACY §7 with data sent, destination and how to disable each item, including tracker/DHT/peer public-IP exposure, the DB-IP download and optional STUN/search/RSS. |
| **C10** README | Added repository layout, install/first login, data and uninstall, privacy, notices, build, verification and limitations sections. |
| **T1** update | Image moved to the 2026-11-23 LinuxServer.io rebuild `5.3.0_v2.1.3-ls489` and pinned by index digest. Upstream qBittorrent is still 5.3.0. |
| **V7** checksum | Deterministic tar/gzip, local SHA-256 recorded, platform `file_hash` checked after submission. |

## Limitations

- The WebUI is plain HTTP; use a TLS reverse proxy before exposing it.
- The BitTorrent listen port (6881) is not published; incoming peers are limited and speeds
  may be lower than a desktop client. UPnP is off by default.
- Your public IP is visible to the trackers, DHT nodes and peers of every torrent you add.
  No VPN is included.
- Host-header validation is disabled so the WebUI works through 8041 and reverse proxies.
  Do not expose 8041 directly to the internet.
- The downloads folder is not visible in TOS File Manager; use SMB/SSH or a backup task.
- Docker applications cannot be upgraded in place; uninstall/reinstall keeps the data folders.
- The aarch64 package is conformance-checked and built from the same image index but is not
  run on ARM hardware in this environment.

## License

This packaging is MIT (see `LICENSE`). qBittorrent and the container image retain their own
licences; see `NOTICE.md`.

---

Packaged for TOS 7 by Moechz. Upstream image used unmodified from Docker Hub.
