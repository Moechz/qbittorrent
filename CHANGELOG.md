# Changelog

All notable user-visible changes to the qBittorrent TOS application package.

## 5.3.0-2 — 2026-11-19

### Fixed
- **The WebUI could not be opened** (the F7 finding). qBittorrent's Host-header validation
  compares the port in the browser's `Host` header with the port the WebUI listens on inside
  the container (8080), so every request through the published port 8041 — and every request
  through a TLS reverse proxy — was answered with `401 Unauthorized`, including the HTML page
  and the static assets. The package now seeds `WebUI\HostHeaderValidation=false` into
  `qBittorrent.conf` before qBittorrent starts (`src/entrypoint.sh` wraps the upstream
  `/init`); login and CSRF protection are unchanged.
- Health check uses `curl -f`, so a 401/5xx (the exact symptom above) is reported as
  unhealthy instead of passing. Start period raised to 60 s.

### Added
- `PRIVACY.md` (retention, user rights, security measures, third-party sharing, deletion
  channel) and `NOTICE.md` (upstream GPL-2.0, LinuxServer.io image, icon and trademark
  notices).
- Full third-party disclosure for a BitTorrent client: the trackers, peers and web seeds of
  the torrents the user adds, the DHT bootstrap nodes, the DB-IP GeoIP database download, the
  search plugins (only when used) and the RSS feeds (only if added).
- `config.ini` `help` now points at the privacy policy; the website copy is linked from the
  app description and the README.

### Changed
- `README.md`: wrapper explanation, privacy and third-party sections, factual runtime file
  manifest, release/tag naming.

## 5.3.0-1 — 2026-11-10

### Added
- First release. qBittorrent (`linuxserver/qbittorrent:5.3.0`, Docker Hub official image, unmodified)
  packaged as a TOS 7 Docker application, published on port 8041 and running
  as a non-root user (1000:1000).
- Persistent data is kept under `/Volume1/DockerAppData/qbittorrentdocker/`.
