# NOTICE — third-party components and attributions

This package (`qbittorrentdocker`, TOS 7 Docker application) is an independent packaging by
Moechz of the upstream **qBittorrent** project.

## 1. Upstream application — qBittorrent

- Project: https://github.com/qbittorrent/qBittorrent
- Licence: **GPL-2.0-or-later** (the project as a whole is GPL-2.0 with parts under
  GPL-3.0-or-later; the binary is distributed under the GPL)
- Relationship: the upstream application is used **unmodified**, inside the container image.
  No upstream source code is redistributed in this package.

## 2. Container image — linuxserver/qbittorrent:5.3.0

- Registry: Docker Hub (`linuxserver/qbittorrent:5.3.0`)
- Maintainer: LinuxServer.io
- The image is pulled from Docker Hub at install time and is not redistributed here. Its own
  licences and notices are documented in the image metadata.

## 3. Components inside the image

The image bundles qBittorrent, libtorrent-rasterbar and the LinuxServer.io s6-overlay base
system. Their licences are documented in the image's package metadata; they are shipped
inside the image only and are not redistributed as separate files by this package.

## 4. This packaging

The files authored for this package — `docker-compose.yml`, `config.ini`,
`qbittorrentdocker.lang`, `qbittorrentdocker.svg`, `entrypoint.sh`, build scripts and this
documentation — are released under **GPL-3.0** (see `LICENSE`), which is compatible with the
upstream GPL-2.0-or-later terms.

## 5. Trademarks

“qBittorrent”, “TerraMaster” and “TOS” are trademarks or registered trademarks of their
respective owners. Their use here is descriptive only. This package is **not affiliated
with, sponsored or endorsed by** the qBittorrent project, LinuxServer.io or TerraMaster.

## 6. Icon

The application icon in `src/qbittorrentdocker.svg` is the qBittorrent project mark (Simple
Icons artwork, CC0 for the icon set, used to identify the packaged application). It is not
used as a trademark of this packaging.

## 7. Contact

Moechz — moechz@163.com — <https://www.moechz.com/>
