# Privacy Policy — qBittorrent for TerraMaster TOS (`qbittorrentdocker`)

**Last updated:** 19 November 2026
**Data controller / contact:** Moechz — moechz@163.com

This policy covers the TOS application `qbittorrentdocker` (the “app”) and its packaging.
The App Center “Help” link of the application points at this policy
(<https://github.com/Moechz/qbittorrent/blob/main/PRIVACY.md>), and the same text is
published on the website version linked at the end.

## 1. Summary

- The app runs **entirely on your NAS**. The developer does not receive, collect or have
  access to any data the app processes: no account, no telemetry, no analytics, no crash
  reporting.
- BitTorrent is a peer-to-peer protocol: the peers, trackers, DHT nodes and web seeds of the
  torrents **you** add necessarily see your IP address and the torrent metadata. That traffic
  goes to the operators of those services, never to the developer (details in §6).
- Beyond that, the app contacts only what it needs to run: a public GeoIP database, and —
  only if you use the feature — search plugins and the RSS feeds you subscribe to.

## 2. What data is processed

| Container path | Stored on the NAS at | Contents |
|---|---|---|
| `/config` | `/Volume1/DockerAppData/qbittorrentdocker/config` | `qBittorrent/qBittorrent.conf` (settings, including the PBKDF2 hash of the WebUI password), `qBittorrent/BT_backup/` (resume data and the .torrent metadata of your torrents), `qBittorrent/GeoDB/` (the downloaded GeoIP database), `qBittorrent/logs/` (application log), `qBittorrent/rss/` (feed definitions) |
| `/downloads` | `/Volume1/DockerAppData/qbittorrentdocker/downloads` | the torrent payload you download, plus `incomplete/` while a download is running |

Nothing is uploaded to the developer. The WebUI password is stored only as a PBKDF2 hash and
never leaves the NAS.

## 3. Retention period

- **Application data and downloads:** kept until **you** delete them. There is no automatic
  expiry and no upload. Uninstalling the app keeps the data unless you tick “delete data”.
- **Logs:** the application log is rotated/size-limited by qBittorrent itself (default
  behaviour); container stdout/stderr follows the DockerEngine log rotation.
- **Cache / GeoIP database:** replaced when a newer copy is downloaded; safe to delete at any
  time, it is fetched again when needed.
- **Website/server logs (moechz.com):** short-lived operational logs, not used for profiling.

## 4. Your rights and the deletion channel

| Right | How |
|---|---|
| Access / export | Copy the folder `/Volume1/DockerAppData/qbittorrentdocker/` — it is the complete state. |
| Correct | Change the values in the app's own WebUI or edit `qBittorrent.conf` while the app is stopped. |
| Delete | Uninstall the app with “delete data”, or stop the container and remove `/Volume1/DockerAppData/qbittorrentdocker/`. |
| Assistance | Email **moechz@163.com** with the subject “qBittorrent data request”; a reply follows within 30 days. |

The developer holds no copy of your data, so deletion is normally completed by removing the
folder on your own NAS; the email channel exists for questions and for requests about the
website or the publishing records.

## 5. Security measures

- The container runs as **uid 1000**, never root; no `privileged`, no `cap_add`, no host
  network, no Docker socket.
- Only the WebUI port is published. The BitTorrent listen port (6881) is **not** published,
  which also means the app cannot be reached as a peer from outside your LAN.
- The image tag is **pinned**; the package is rebuilt when upstream ships security fixes.
- Data stays inside the application data folder, owned by the app user.
- The WebUI requires a login. The first start prints a temporary admin password in the
  container log; change it immediately. CSRF protection stays enabled.
- This package sets qBittorrent's `WebUI\HostHeaderValidation` to `false` before start-up.
  Reason: that check compares the port in the browser's `Host` header with the port the
  WebUI listens on inside the container, so every request through the published port
  (8041 → 8080) or through a TLS reverse proxy is rejected with HTTP 401 and the page cannot
  load. Only that host/port comparison is disabled — authentication and CSRF protection are
  unchanged. Keep the WebUI on your LAN or behind a reverse proxy with TLS; do not expose it
  to the internet unprotected.

## 6. Third-party sharing and API disclosure

The developer shares nothing. The app contacts the endpoints below; the first four are part
of the BitTorrent protocol and are driven by the torrents you add.

| Service | Endpoint | Data sent | Destination / region |
|---|---|---|---|
| Trackers of your torrents | the announce URLs contained in the torrent (HTTP/HTTPS/UDP) | info-hash, peer ID, uploaded/downloaded counters, event, your public IP and port | the tracker operator (chosen by the torrent, region varies) |
| Peers of your torrents | the peer addresses of the swarm (BitTorrent protocol, TCP/UDP) | your IP address and port, piece availability, the transferred data | other participants worldwide |
| Web seeds | URLs contained in the torrent (BEP 17/19) | HTTP request for the file pieces | the web seed host |
| DHT bootstrap nodes (DHT is on by default) | `dht.libtorrent.org:25401`, `router.bittorrent.com:6881`, `router.utorrent.com:6881`, `dht.transmissionbt.com:6881` | DHT queries (info-hashes) and your IP address | the operators of those domains |
| GeoIP database download (automatic, monthly) | `https://download.db-ip.com/free/dbip-country-lite-YYYY-MM.mmdb.gz` | a plain HTTP GET — no user data | DB-IP, EU |
| Search plugins (only when you open **Search**) | plugin sources from `https://github.com/qbittorrent/search-plugins`, then the search sites the plugins query | your search terms | GitHub (US) + the search site you pick |
| RSS feeds (only if you subscribe) | the feed URLs you add | a plain HTTP GET | the feed provider |

The app has **no telemetry, no analytics, no update check and no advertising**. Your public
IP address becomes visible to peers and trackers because that is how BitTorrent works — use a
VPN or a proxy in the app's connection settings if you do not want that.

## 7. Children

The app is a self-hosted utility and is not directed at children.

## 8. Changes

Material changes are published in this file and reflected in the “Last updated” date.

## 9. Contact

Moechz — **moechz@163.com** — <https://www.moechz.com/privacy.html>
