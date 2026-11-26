# NOTICE — third-party components and attributions

This package (`qbittorrentdocker`, TOS 7 Docker application) is an independent packaging by
Moechz. It installs the **unmodified** LinuxServer.io container image from Docker Hub and adds
only the four-file TOS wrapper described in `README.md`.

## 1. Upstream application — qBittorrent 5.3.0

- Project: <https://github.com/qbittorrent/qBittorrent>
- Copyright: the qBittorrent authors (see the `AUTHORS` file upstream).
- Licence, verified against the upstream `COPYING` file:
  - **source code: GNU GPL v2 or later** (`GPL-2.0-or-later`);
  - **binary distribution: GNU GPL v3 or later** (`GPL-3.0-or-later`), because the binary
    bundles GPLv3+ assets such as images;
  - both with the **OpenSSL linking exception** reproduced in `COPYING`.
- The previous package metadata said `GPL-2.0`. That was the source-code licence only and is
  corrected here to `GPL-3.0-or-later` for the distributed binary. This package does not
  redistribute qBittorrent source code; the program is used unmodified inside the image.

## 2. Container image — `linuxserver/qbittorrent:5.3.0`

- Registry: Docker Hub, repository `linuxserver/qbittorrent`.
- Maintainer: LinuxServer.io (<https://github.com/linuxserver/docker-qbittorrent>).
- Build installed by this package (2026-11-23): LinuxServer.io version
  `5.3.0_v2.1.3-ls489`, image creation time `2026-11-23T20:31:36Z`.
- Multi-architecture OCI index, pinned in `docker-compose.yml`:
  - index: `sha256:a8083a3337a175e84374e3c8cf34ab76566c54502a2e8580e53b6deaa5b2f619`
  - `linux/amd64`: `sha256:a2bf05fd92e30a35095c9fd3701228a794c83f78dee9bc832ca2568b2af2f994`
  - `linux/arm64`: `sha256:bf459ae16e7d2fb6dfd088ee48cf2acd58951b8c05200072f78613faaa4e56bd`
- The image's own label declares the LinuxServer.io build scripts under **GPL-3.0-only**.
  That label describes the image, not the qBittorrent source (see §1).
- The image is pulled at install time and is **not redistributed** by this package. Its full
  licence texts and SBOM are available in the image and in the LinuxServer.io repository.

## 3. Components inside the image

Versions reported by qBittorrent's `buildInfo` API and the image labels:

| Component | Version | Licence (upstream) |
|---|---|---|
| qBittorrent | 5.3.0 | GPL-3.0-or-later (binary), GPL-2.0-or-later (source), OpenSSL exception |
| libtorrent-rasterbar | 2.1.3.0 | BSD-3-Clause |
| Qt | 6.12.1 | LGPL-3.0 / GPL-3.0 (open-source builds) |
| Boost | 1.92.0 | Boost Software License 1.0 |
| OpenSSL | 4.1.0 | Apache-2.0 |
| zlib | 1.3.2 | zlib licence |
| s6-overlay | 3.2.1.0 | ISC |
| Alpine Linux base (musl, BusyBox, …) | image build | MIT / GPL-2.0 / others, see the image package database |

These components are shipped inside the container image only. They are not redistributed as
separate files by this package; the authoritative licence texts are part of the image.

## 4. This packaging

The files authored for this package — `docker-compose.yml`, `config.ini`,
`qbittorrentdocker.lang`, `qbittorrentdocker.svg`, `src/entrypoint.sh`, the build scripts,
`test/smoke.sh` and this documentation — are released under the **MIT licence** in
`LICENSE`, which is compatible with the upstream GPL terms for this kind of independent
wrapper.

## 5. Trademarks

“qBittorrent”, “LinuxServer.io”, “TerraMaster” and “TOS” are trademarks or registered
trademarks of their respective owners. Their use here is descriptive only. This package is
**not affiliated with, sponsored or endorsed by** the qBittorrent project, LinuxServer.io or
TerraMaster.

## 6. Icon

The application icon in `src/qbittorrentdocker.svg` is the qBittorrent project mark from the
Simple Icons set (icon artwork CC0 1.0; the mark itself remains a trademark of the qBittorrent
project) and is used only to identify the packaged application.

## 7. Security updates (T1)

The image is pinned to the current LinuxServer.io rebuild `5.3.0_v2.1.3-ls489`
(2026-11-23). Upstream qBittorrent is still 5.3.0, so no newer application version exists.
The image is rebuilt when LinuxServer.io publishes a newer `5.3.0-ls*` build; the digest in
`docker-compose.yml` is then updated and the package re-submitted.

## 8. Contact

Moechz — moechz@163.com — <https://www.moechz.com/>
