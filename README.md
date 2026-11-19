# qbittorrent-for-tos

> TerraMaster TOS 7 App Center — **Docker application** package for
> [qBittorrent](https://github.com/qbittorrent/qBittorrent).

## What this is

A four-file TOS Docker application archive (`qbittorrentdocker.tar.gz`) that installs
qBittorrent on TOS 7 through the App Center:

- `config.ini` — TOS application metadata (`application_type: docker`, id `qbittorrentdocker`)
- `qbittorrentdocker.lang` — 23-language superset (TOS requires 14)
- `qbittorrentdocker.svg` — application icon (1763 bytes, 3 SVG elements)
- `docker-compose.yml` — one service, image `linuxserver/qbittorrent:5.3.0`, with a small
  wrapper entrypoint (`src/entrypoint.sh`)

## How it works

| | |
|---|---|
| Container image | `linuxserver/qbittorrent:5.3.0` (Docker Hub, used unmodified) |
| Health check | `curl -f http://127.0.0.1:8080/` — a 401/5xx counts as unhealthy |
| Open | `http://<NAS-IP>:8041/` (container port 8080) |
| Runs as | non-root, `user: "1000:1000"` |
| Persistent data | `/config` → `/Volume1/DockerAppData/qbittorrentdocker/config`, `/downloads` → `/Volume1/DockerAppData/qbittorrentdocker/downloads` |
| Logs | `docker logs qbittorrentdocker` (stdout/stderr) |

`/config` (mounted from `DockerAppData/qbittorrentdocker/config`) keeps `qBittorrent/qBittorrent.conf` plus the resume data; `/downloads` (mounted from `.../downloads`) is where finished and in-progress torrents are written.

## Design highlights

- **Non-root.** `user: "1000:1000"`; verified on real hardware (the container reports uid 1000).
- **Fixed image tag, never `:latest`**, Docker Hub only, no `privileged`, no `network_mode: host`, and no Docker socket, no `cap_add`.
- **Health check** with `curl -f`: any 401/5xx (broken WebUI, dead database-less start) marks the
  container unhealthy instead of silently passing.
- **Deterministic build**: GNU tar with uid/gid 0 and zeroed timestamps, gzip without a timestamp, plus the review-standards self-check above.
- **Thin wrapper entrypoint.** `src/entrypoint.sh` sets `WebUI\HostHeaderValidation=false` in
  `/config/qBittorrent/qBittorrent.conf` and then `exec /init`s the upstream s6 entrypoint. Without
  that, qBittorrent compares the port in the browser's `Host` header with its own port 8080 and
  answers every request through the published port (8041) — or through a TLS reverse proxy — with
  HTTP 401, so the page never loads. Authentication and CSRF protection stay enabled.
- **First-run password in the log.** No password is baked into the package: qBittorrent generates a temporary one and the user changes it in the WebUI.
- **One published port.** Only the WebUI (8080) is exposed; the BT listen port stays inside the container, which is the trade-off for the store's single-port rule.

## Runtime file manifest

Everything the application writes on the NAS lives inside its own data
directory; the container-internal `/tmp` is discarded with the container. The
table lists what is created and how it behaves. Nothing else is written.

| Path | Purpose | Created when | Growth bound | Lifecycle |
|---|---|---|---|---|
| `/Volume1/DockerAppData/qbittorrentdocker/config` | `qBittorrent/qBittorrent.conf` (settings incl. the PBKDF2 password hash), `BT_backup/` (resume data + .torrent metadata), `GeoDB/` (GeoIP database), `logs/`, `rss/` | on first start / on demand | bounded by your own torrents | persistent; kept on uninstall unless you ask to delete it |
| `/Volume1/DockerAppData/qbittorrentdocker/downloads` | the torrent payload, plus `incomplete/` while downloading | on first download | bounded by what you download | persistent; kept on uninstall unless you ask to delete it |

## Build

```bash
scripts/build.sh                  # -> out/qbittorrentdocker.tar.gz + .sha256
scripts/build.sh 5.3.0-2            # packaging iteration bump
scripts/build.sh 5.3.0-2 aarch64    # explicit platform (both are published)
```

The build stages the four files, substitutes the version/platform placeholders,
removes CRLF/BOM/AppleDouble, then runs
`tools/verify.py`, a review-standards self-check (archive layout, JSON validity,
required fields, 14+ language coverage, version consistency, Docker-Hub-only
images, fixed tag, reserved/recommended host ports, non-root user, per-service
healthcheck/TZ/restart, data path below the application data root, never the
`/Volume*` wildcard, comment-free sequence blocks, `x-app-meta` position, no
literal secrets and the SVG size/element limits).

## Local verification

```bash
./TOSAppSelfTestingTool -c out/qbittorrentdocker.tar.gz   # official spec check
bash test/install-and-verify.sh                  # on-device E2E (needs root)
```

> Docker applications cannot be side-loaded through the App Center's manual
> install page (it accepts `.deb` only); the official self-testing tool's `-i`
> mode or `docker compose` are the only ways to install one for testing.

## Store submission checklist

1. Public GitHub repo (code + README only).
2. Release **tag `v5.3.0-2`**, assets `qbittorrentdocker_x86_64.tar.gz` +
   `qbittorrentdocker_aarch64.tar.gz` (+ `.sha256` each) — Docker asset naming:
   `<app_id>_<arch>.tar.gz`, one archive per architecture.
3. Developer platform → Add Application: ID `qbittorrentdocker`, package type Docker,
   repository URL, architecture `x86_64` (and a second record for `aarch64`).
4. Version Management → Add Version `5.3.0-2` → automated validation → review.

## Privacy

This application runs entirely on your NAS. **The developer does not collect, receive or have
access to any data processed by the application.** There is no telemetry, no analytics and no
account.

| Topic | Detail |
|---|---|
| Data processed | Settings and the WebUI password hash, resume data and .torrent metadata, the GeoIP database and the application log (all under `/config`), plus the downloaded payload (`/downloads`). |
| Where it is stored | The application data folder (`/Volume1/DockerAppData/qbittorrentdocker/`) on your NAS. Nothing is uploaded to the developer. |
| Retention period | Until **you** delete it; the application log is rotated by qBittorrent, the GeoIP database is replaced when refreshed. |
| Your rights | **Access / export**: copy the data folder. **Correct**: change it in the WebUI. **Delete**: uninstall with “delete data”, or remove the folder after stopping the container. |
| Deletion channel | Delete the folder yourself, or email **moechz@163.com** (answered within 30 days). |
| Security measures | uid 1000 (never root), no privileged/host network/cap_add/socket, one published port (WebUI only), pinned image tag, WebUI login + CSRF protection. |

**Full privacy policy:** [PRIVACY.md](PRIVACY.md) —
<https://github.com/Moechz/qbittorrent/blob/main/PRIVACY.md> — and the website version at
<https://www.moechz.com/privacy.html>.

## Third-party services (API disclosure)

The developer operates no server in this path. The client contacts the endpoints below; the
first four are part of the BitTorrent protocol and follow the torrents **you** add.

| Service | Endpoint | Data sent | Destination / region |
|---|---|---|---|
| Trackers of your torrents | announce URLs inside the torrent (HTTP/HTTPS/UDP) | info-hash, peer ID, counters, your public IP | the tracker operator (varies) |
| Peers / web seeds | the swarm of your torrents | your IP and port, piece availability, transferred data | other participants worldwide |
| DHT bootstrap | `dht.libtorrent.org:25401`, `router.bittorrent.com:6881`, `router.utorrent.com:6881`, `dht.transmissionbt.com:6881` | DHT queries + your IP | those operators |
| GeoIP database | `https://download.db-ip.com/free/dbip-country-lite-YYYY-MM.mmdb.gz` | a plain HTTP GET, no user data | DB-IP, EU |
| Search plugins (only when you use Search) | plugin sources on `github.com/qbittorrent/search-plugins`, then the search sites | your search terms | GitHub (US) + the search site |
| RSS feeds (only if you subscribe) | the feed URLs you add | a plain HTTP GET | the feed provider |

See `PRIVACY.md` §6 for the full table. There is no telemetry, no analytics SDK and no update
check.

## License / branding

qBittorrent is distributed by its upstream authors under **GPL-2.0**. The container image is the official image from Docker Hub (`linuxserver/qbittorrent:5.3.0`) and is used unmodified; no upstream source code is redistributed here. This packaging is an independent community submission by Moechz and is not affiliated with the upstream project or TerraMaster.

## Limitations

- The WebUI is plain HTTP; use a TLS reverse proxy before exposing it to the internet.
- The BitTorrent listen port (6881) is not published, so incoming peers cannot connect and speeds may be lower than a desktop client.
- The downloads folder is not visible in TOS File Manager; manage files over SMB/SSH or add the path to a backup task.

---

Packaged for TOS 7 by Moechz. Upstream image used unmodified from Docker Hub.
