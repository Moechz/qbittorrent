# qbittorrent-for-tos

> TerraMaster TOS 7 App Center — **Docker application** package for
> [qBittorrent](https://github.com/qbittorrent/qBittorrent).

## What this is

A four-file TOS Docker application archive (`qbittorrentdocker.tar.gz`) that installs
qBittorrent on TOS 7 through the App Center:

- `config.ini` — TOS application metadata (`application_type: docker`, id `qbittorrentdocker`)
- `qbittorrentdocker.lang` — 23-language superset (TOS requires 14)
- `qbittorrentdocker.svg` — application icon (1763 bytes, 3 SVG elements)
- `docker-compose.yml` — one service, image `linuxserver/qbittorrent:5.3.0`

## How it works

| | |
|---|---|
| Container image | `linuxserver/qbittorrent:5.3.0` (Docker Hub, used unmodified) |
| Open | `http://<NAS-IP>:8041/` (container port 8080) |
| Runs as | non-root, `user: "1000:1000"` |
| Persistent data | `/config` → `/Volume1/DockerAppData/qbittorrentdocker/config`, `/downloads` → `/Volume1/DockerAppData/qbittorrentdocker/downloads` |
| Logs | `docker logs qbittorrentdocker` (stdout/stderr) |

`/config` (mounted from `DockerAppData/qbittorrentdocker/config`) keeps `qBittorrent/qBittorrent.conf` plus the resume data; `/downloads` (mounted from `.../downloads`) is where finished and in-progress torrents are written.

## Design highlights

- **Non-root.** `user: "1000:1000"`; verified on real hardware (the container reports uid 1000).
- **Fixed image tag, never `:latest`**, Docker Hub only, no `privileged`, no `network_mode: host`, and no Docker socket, no `cap_add`.
- **Health check** probing the service on container port 8080.
- **Deterministic build**: GNU tar with uid/gid 0 and zeroed timestamps, gzip without a timestamp, plus the review-standards self-check above.
- **Runs unprivileged with the upstream entrypoint.** The LinuxServer.io image in this tag can run as uid 1000, so no wrapper is needed; the volumes are chowned by the installer.
- **First-run password in the log.** No password is baked into the package: qBittorrent generates a temporary one and the user changes it in the WebUI.
- **One published port.** Only the WebUI (8080) is exposed; the BT listen port stays inside the container, which is the trade-off for the store's single-port rule.

## Runtime file manifest

Everything the application writes on the NAS lives inside its own data
directory; the container-internal `/tmp` is discarded with the container. The
table lists what is created and how it behaves. Nothing else is written.

| Path | Purpose | Created when | Growth bound | Lifecycle |
|---|---|---|---|---|
| `/Volume1/DockerAppData/qbittorrentdocker/config` | qBittorrent application data (everything the container writes outside /tmp) | on first start / on demand | bounded by your own data | persistent; kept on uninstall unless you ask to delete it |
| `/Volume1/DockerAppData/qbittorrentdocker/downloads` | qBittorrent application data (everything the container writes outside /tmp) | on first start / on demand | bounded by your own data | persistent; kept on uninstall unless you ask to delete it |

## Build

```bash
scripts/build.sh                  # -> out/qbittorrentdocker.tar.gz + .sha256
scripts/build.sh 5.3.0-2   # packaging iteration bump
scripts/build.sh 5.3.0-1 aarch64
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
2. Release **tag `v5.3.0-1`**, assets `qbittorrentdocker.tar.gz` +
   `qbittorrentdocker.tar.gz.sha256` (Docker asset naming: `<app_id>.tar.gz`, **no
   platform suffix**).
3. Developer platform → Add Application: ID `qbittorrentdocker`, package type Docker,
   repository URL, architecture `x86_64`.
4. Version Management → Add Version `5.3.0-1` → automated validation → review.

## License / branding

qBittorrent is distributed by its upstream authors under **GPL-2.0**. The container image is the official image from Docker Hub (`linuxserver/qbittorrent:5.3.0`) and is used unmodified; no upstream source code is redistributed here. This packaging is an independent community submission by Moechz and is not affiliated with the upstream project or TerraMaster.

## Limitations

- The WebUI is plain HTTP; use a TLS reverse proxy before exposing it to the internet.
- The BitTorrent listen port (6881) is not published, so incoming peers cannot connect and speeds may be lower than a desktop client.
- The downloads folder is not visible in TOS File Manager; manage files over SMB/SSH or add the path to a backup task.

---

Packaged for TOS 7 by Moechz. Upstream image used unmodified from Docker Hub.
