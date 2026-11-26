# Privacy Policy — qBittorrent for TerraMaster TOS (`qbittorrentdocker`)

**Last updated:** 26 November 2026
**Data controller / contact:** Moechz — moechz@163.com

This policy covers the TOS application `qbittorrentdocker` (the “app”) and its packaging.
The App Center “Help” link points at this file
(<https://github.com/Moechz/qbittorrent/blob/main/PRIVACY.md>).

## 1. Summary

- The app runs **entirely on your NAS**. The developer does not receive, collect or have
  access to any data the app processes: no account, no telemetry, no analytics and no crash
  reporting. There is no update check to the developer.
- BitTorrent is a peer-to-peer protocol. The trackers, DHT nodes, peers and web seeds of the
  torrents **you** add necessarily see your public IP address, your client port and the
  torrent metadata. That traffic goes to those third parties, never to the developer. No VPN
  or anonymity layer is included.
- Beyond the BitTorrent swarm, the app contacts only what its features need: the DB-IP
  country database (when “Resolve peer countries” is on), the search-plugin list on GitHub
  (only when you open Search), the RSS feeds you subscribe to, and the Google STUN server
  (only if WebTorrent peer support is enabled — it is not used by this package's defaults).
  Each endpoint and its off switch is listed in §7.
- The WebUI password is generated randomly **per installation** on first start and is stored
  only on your NAS: a PBKDF2-HMAC-SHA512 hash in `qBittorrent.conf`, the initial plaintext in
  `webui-credentials.txt` (mode 0600). It is never written to the container log, which is the
  fix for the F10 review finding.

## 2. What data is processed and where it is stored

Everything the app writes lives under
`/Volume1/DockerAppData/qbittorrentdocker/` on your NAS.

| Host path | Contents | Notes |
|---|---|---|
| `config/qBittorrent/qBittorrent.conf` | every setting: save paths, listen ports, bandwidth limits, DHT/PeX/LSD/UPnP switches, proxy settings, **PBKDF2 hash of the WebUI password** (mode 0600) | never leaves the NAS |
| `config/qBittorrent/webui-credentials.txt` | initial random WebUI password, `username=admin`, plaintext, mode 0600 | created on first start; delete it after changing the password |
| `config/qBittorrent/BT_backup/` | `.torrent` metadata and resume data of the torrents you add | rebuilding it re-checks the payload |
| `config/qBittorrent/GeoDB/` | DB-IP Country Lite database (only when peer-country resolution is on) | replaced monthly; safe to delete |
| `config/qBittorrent/logs/qbittorrent.log` | local application log: listen addresses, local IPs, the detected public IP, tracker/peer events, WebAPI logins | local file only; contains no password |
| `config/qBittorrent/rss/` | RSS feed definitions you add | only if you use RSS |
| `config/qBittorrent/categories.json`, `watched_folders.json` | small state files for categories and watched folders | only created by the features you use |
| `downloads/` | the torrent payload and, while a download runs, `incomplete/` | your data; may be very large |

The WebUI password hash is PBKDF2-HMAC-SHA512 with 100 000 iterations, a per-install
16-byte salt and a 64-byte derived key. The plaintext initial password exists only in the
0600 credentials file described above.

## 3. Retention period

- **Settings, resume data, downloads and the initial password file:** kept until **you**
  delete them. There is no automatic expiry and no upload. Uninstalling the app keeps the
  data folder unless you tick “delete data” or remove it yourself.
- **Application log:** kept locally and rotated/limited by qBittorrent itself. Delete it at
  any time while the app is stopped; it is recreated on the next start.
- **GeoIP database:** replaced when a newer copy is downloaded; safe to delete, it is fetched
  again when peer-country resolution is on.
- **Container stdout/stderr:** handled by DockerEngine's log rotation. It contains startup
  messages but no credentials.
- **Website/server logs (moechz.com):** short-lived operational logs, not used for profiling.

## 4. Your rights and the deletion channel

| Right | How |
|---|---|
| Access / export | Copy the folder `/Volume1/DockerAppData/qbittorrentdocker/`. It is the complete state of the app. |
| Correct | Change the values in the app's WebUI, or edit `qBittorrent.conf` while the app is stopped. |
| Delete | Uninstall the app with “delete data”, or stop the container and remove `/Volume1/DockerAppData/qbittorrentdocker/`. |
| Restrict / object | Do not add torrents, leave DHT/PeX/LSD off, do not use Search/RSS, and keep the WebUI on your LAN. |
| Assistance | Email **moechz@163.com** with the subject “qBittorrent data request”; a reply follows within 30 days. |

The developer holds no copy of your data, so deletion is normally completed by removing the
folder on your own NAS. The email channel exists for questions and for requests about the
website or the publishing records.

## 5. Security measures

- The container runs as **uid/gid 1000**, never root, with `cap_drop: [ALL]`,
  `no-new-privileges`, no `privileged`, no `cap_add`, no host network and no Docker socket.
  `/run` is a uid-1000 tmpfs because s6-overlay needs it before the app starts. Measured
  effective capabilities: `CapEff=0000000000000000`.
- Only the WebUI port is published (host 8041 → container 8080). The BitTorrent listen port
  (6881) is **not** published, so the app cannot accept incoming peers from outside your LAN
  unless you add a router forward yourself.
- `umask 077` and explicit modes: `qBittorrent.conf` and `webui-credentials.txt` are 0600,
  the `qBittorrent` config directory is 0700.
- No default password. A random password is generated per installation; it is not printed to
  the container log. Change it after the first login and delete `webui-credentials.txt`.
- The WebUI requires a login and keeps CSRF protection and the failed-login rate limit on.
  It is plain HTTP on the LAN; use a TLS reverse proxy before exposing it.
- The image is pinned by OCI digest, and the package is rebuilt when upstream ships security
  fixes.
- **Host-header validation is disabled on purpose.** qBittorrent compares the port in the
  browser's `Host` header with the port it listens on inside the container (8080), so every
  request through the published port 8041 or through a TLS reverse proxy is rejected with
  HTTP 401 and the page cannot load (the F7 finding). The package turns only that host/port
  comparison off before start-up. Authentication, CSRF protection and the requirement to log
  in remain enabled. Residual risk: the DNS-rebinding protection of that check is lost, so
  keep the UI on a trusted LAN or behind an authenticated TLS proxy and never expose port
  8041 directly to the internet.

## 6. Logs and diagnostics

The container's stdout/stderr contains the s6/LinuxServer.io startup banner, the qBittorrent
startup line and the text `qBittorrent WebUI credentials: …/webui-credentials.txt (mode 0600)`
— a path, never the password. The local application log contains local interface addresses,
the public IP that DHT/UPnP detection observed, tracker and peer events and WebAPI login
records; it contains no password or API token. Both are local to the NAS. The application log
is safe to delete while the app is stopped.

## 7. Third-party sharing and API disclosure

The developer shares nothing and operates no server in this path. The app contacts the
endpoints below. The first group is part of the BitTorrent protocol and is driven by the
torrents you add; the second group is optional or only used by a feature you invoke.

**What is sent to the swarm, and how to reduce it**

| Service / endpoint | When | Data sent | Destination / region | How to disable |
|---|---|---|---|---|
| Trackers announced in your torrents (HTTP/HTTPS/UDP announce URLs) | when a torrent is added, started or re-announced | info-hash, peer ID, uploaded/downloaded counters, event, **public IP and client port** | the tracker operator named in the torrent (region varies) | not disableable while the torrent runs. Add it paused, remove its tracker URLs before starting, or route tracker traffic through a proxy/VPN. |
| Peers of your torrents (TCP/UDP, the BitTorrent protocol) | while downloading or seeding | **public IP and port**, client version, piece availability, the transferred data | other swarm participants worldwide | not disableable while the torrent runs. Stop the torrent or use a VPN. |
| Web seeds embedded in a torrent (BEP 17/19 URLs) | when the torrent contains them | HTTP request, your IP, info-hash, file range | the web-seed host named in the torrent | remove the web-seed URLs from the torrent or do not add such torrents; there is no global switch. |
| DHT (on by default) — bootstrap nodes `dht.libtorrent.org:25401`, `dht.transmissionbt.com:6881`, `router.bt.ouinet.work:6881` (the active list is in `dht_bootstrap_nodes`) | while any torrent is active | info-hashes, **public IP:port**, DHT queries | the global DHT swarm (worldwide) | Settings → BitTorrent → uncheck “Enable DHT”, or set `Session\DHTEnabled=false`. |
| Peer Exchange / PeX (on by default) | while a torrent is active | peer list, **IP:port** | other peers in the swarm | Settings → BitTorrent → uncheck “Enable PeX”. |
| Local Peer Discovery / LSD (on by default), multicast `239.192.x.x:6771` | while a torrent is active | info-hash, **private LAN IP** | your own LAN only | Settings → BitTorrent → uncheck “Enable local peer discovery”. |
| External-IP detection (logged as `Detected external IP`) | at startup while DHT or UPnP is on | **public IP** | learned through DHT/UPnP, no developer server | turn off DHT and UPnP. |
| UPnP / NAT-PMP (**off by default in this package**) | only if you enable it | port-mapping request, local IP, requested port | your own router/gateway | keep “Use UPnP / NAT-PMP port forwarding” unchecked; the image defaults and this package set `Connection\UPnP=false`. |

**Optional or feature-triggered endpoints**

| Service / endpoint | When | Data sent | Destination / region | How to disable |
|---|---|---|---|---|
| DB-IP Country Lite — `https://download.db-ip.com/free/dbip-country-lite-YYYY-MM.mmdb.gz` | first start and monthly refresh when “Resolve peer countries” is on | plain HTTP GET, your IP and User-Agent — no torrent data | DB-IP, EU | Settings → BitTorrent → uncheck “Resolve peer countries”, or block the host. |
| qBittorrent search plugins — plugin list on `https://github.com/qbittorrent/search-plugins`, then the search sites a plugin queries | only when you open **Search** and run a query | search terms, your IP | GitHub (US) and the selected search site | do not use Search, or remove the plugins in Search → plugins. |
| RSS feeds — the feed URLs you add | only for subscriptions you create | HTTP GET, your IP, User-Agent | the feed provider you chose | delete the subscription. |
| Google STUN — `stun.l.google.com:19302` | only if WebTorrent peer support is enabled; **not used by the default configuration** | STUN binding request, **public IP:port** | Google, US | do not enable WebTorrent; block UDP 19302. |
| Docker Hub — `registry-1.docker.io` (or the NAS registry mirror) | install and image update | anonymous image pull, your IP | Docker Hub, US | only happens on install/update; the app does not pull at runtime. |
| GitHub — the Help link and this policy | when you click the link | normal browser request, your IP | GitHub, US | do not click; the app does not fetch it. |
| `www.moechz.com` — the website copy of this policy | when you open the link | normal browser request, your IP | the developer's website | do not open it. |

There is **no telemetry, no analytics, no advertising and no automatic update check** to the
developer. Your public IP becomes visible to trackers, DHT nodes and peers because that is
how BitTorrent works. If that matters, use a VPN, or configure qBittorrent's proxy settings
(Settings → Connection → Proxy Server) so that peer, tracker and RSS traffic goes through
your proxy. “Anonymous mode” only hides the client fingerprint; it does not hide your IP.

## 8. Children

The app is a self-hosted utility and is not directed at children.

## 9. Changes

Material changes are published in this file and reflected in the “Last updated” date.

## 10. Contact

Moechz — **moechz@163.com** — <https://www.moechz.com/>
