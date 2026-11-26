# Changelog

All notable user-visible changes to the qBittorrent TOS application package.

## 5.3.0-3 — 2026-11-26

Remediation of the `5.3.0-2 (x86_64)` review. All nine recorded findings are addressed:

### Fixed

- **F10 — no plaintext credential in the log.** qBittorrent used to print a temporary WebUI
  password into the container log when no password was configured. The wrapper now generates
  a random password per installation, stores a PBKDF2-HMAC-SHA512 hash (100 000 iterations,
  16-byte salt, 64-byte key) in `qBittorrent.conf` and keeps the plaintext only in
  `config/qBittorrent/webui-credentials.txt` (mode 0600). The log prints the file path, never
  the password. Verified with `docker logs | grep -F <password>` — no match.
- **F2 / F8 — first start and data path.** 5.3.0-2 wrote a minimal `qBittorrent.conf`, which
  skipped the image's `/defaults` and made qBittorrent fall back to `$HOME/Downloads` =
  `/config/Downloads` while UPnP stayed on. The wrapper now copies `/defaults/qBittorrent.conf`
  on first start (`Downloads\SavePath=/downloads/`, `TempPath=/downloads/incomplete/`,
  `Connection\UPnP=false`) and migrates an existing 5.3.0-2 config (`/config/Downloads` →
  `/downloads/`, `/config/Downloads/{incomplete,temp}` → `/downloads/incomplete/`, UPnP off
  when it was never explicitly set). Health-check start period is 90 s.
- **F3 — clean stop.** Added `stop_grace_period: 30s`. `docker stop` exits 0 in about 7 s,
  qBittorrent logs "termination initiated / ready to exit", no zombie processes.
- **F7 — WebUI loads through the published port.** `WebUI\HostHeaderValidation=false` is
  seeded before `/init`; requests with `Host: <nas>:8041`, `<nas>:443` or a bare hostname
  return 200. Login and CSRF protection stay enabled.
- **F11 / F4 — uninstall leaves no undocumented data.** README "Data, backup and uninstall"
  lists every path (`config/`, `downloads/`, the install directory) and the exact deletion
  step. The TOS App Center has no uninstall hook for Docker apps, so the data folder is kept
  by design until the user deletes it or ticks "delete data".
- **F9 — recovery after a NAS restart.** `restart: unless-stopped` and the health check were
  re-verified: the container starts again, serves the WebUI and restores the torrent list.
- **S11 — permissions.** `umask 077`; `qBittorrent.conf` and `webui-credentials.txt` are 0600;
  the config directory is 0700. Non-root uid 1000, `cap_drop: [ALL]`,
  `no-new-privileges: true` and a uid-1000 `tmpfs /run` (s6-overlay needs `/run` before the
  app starts, and the preinit cannot chown it without `CAP_CHOWN`). Measured `CapEff=0`.
- **C2 — licence.** Upstream `COPYING` says source `GPL-2.0-or-later`, binary
  `GPL-3.0-or-later` because of GPLv3+ assets, with the OpenSSL linking exception. The
  metadata is corrected from `GPL-2.0` to `GPL-3.0-or-later`; NOTICE now carries the image
  index/amd64/arm64 digests and the component licences.
- **C8 — third-party disclosure.** PRIVACY §7 is a per-endpoint table (what is sent, where,
  when, and how to disable it): trackers, peers, web seeds, DHT (with the active bootstrap
  list), PeX, LSD, external-IP detection, UPnP (off by default), the DB-IP country database,
  search plugins, RSS, the conditional Google STUN server, Docker Hub and the help links.
  The public-IP exposure of tracker/DHT/peer traffic is stated explicitly.
- **C10 — documentation.** README now has repository layout, install/first login, data and
  uninstall, privacy, notices, build, verification and limitations sections.
- **T1 — image update.** Moved to the 2026-11-23 LinuxServer.io rebuild
  `5.3.0_v2.1.3-ls489` and pinned it by OCI index digest
  `sha256:a8083a33…b619` (upstream qBittorrent is still 5.3.0).
- **V7 — checksums.** Deterministic tar/gzip; local SHA-256 recorded and compared with the
  platform `file_hash` after submission.

### Added

- `test/smoke.sh` — functional test with the base URL as argument: WebUI page, admin login,
  `/api/v2/app/version`, add a paused magnet, verify it in `/api/v2/torrents/info`, delete it.
  Exits non-zero when any step fails, so `smoke.py` can gate the release.
- `tools/verify.py` now rejects ASCII `;` inside `.lang` values (the store parser treats it as
  an INI comment and truncates the description).

## 5.3.0-2 — 2026-11-19

### Fixed

- **The WebUI could not be opened** (the F7 finding). qBittorrent's Host-header validation
  compares the port in the browser's `Host` header with the port the WebUI listens on inside
  the container (8080), so every request through the published port 8041 — and every request
  through a TLS reverse proxy — was answered with `401 Unauthorized`, including the HTML page
  and the static assets. The package seeds `WebUI\HostHeaderValidation=false` before
  qBittorrent starts (`src/entrypoint.sh` wraps the upstream `/init`); login and CSRF
  protection are unchanged.
- Health check uses `curl -f`, so a 401/5xx (the exact symptom above) is reported as
  unhealthy instead of passing. Start period raised to 60 s.

### Added

- `PRIVACY.md` and `NOTICE.md`, full third-party disclosure for a BitTorrent client, and a
  `config.ini` Help link to the privacy policy.

### Known issues in 5.3.0-2 (fixed in 5.3.0-3)

- The wrapper created a minimal config, so downloads went to `/config/Downloads` and UPnP was
  enabled. qBittorrent's temporary WebUI password appeared in the container log. The data
  volume and the image digest in `tosapp.json` were stale.

## 5.3.0-1 — 2026-11-10

### Added

- First release. qBittorrent (`linuxserver/qbittorrent:5.3.0`, Docker Hub, unmodified)
  packaged as a TOS 7 Docker application on port 8041, non-root user (1000:1000), data under
  `/Volume1/DockerAppData/qbittorrentdocker/`.
