# FN AutoSC

A menu-driven VPS automation suite for tunnelling protocols, proxy services, and
Xray account management.

One command installs SSH WebSocket, Xray (VMess / VLESS / Trojan over WebSocket,
HTTP Upgrade, XHTTP, and gRPC), OpenVPN, WireGuard, L2TP/IPsec, NoobzVPN,
SlowDNS, Cloudflare Argo, automated backups, and a Telegram control bot.

Supported operating systems: Debian 10–12 and Ubuntu 20.04–24.04.

---

## Table of Contents

1. [Installation](#installation)
2. [Variants — Full vs Lite](#variants--full-vs-lite)
3. [Menus](#menus)
4. [Protocols & Ports](#protocols--ports)
5. [Transport Paths](#transport-paths)
6. [Account Lifecycle](#account-lifecycle)
7. [Quota & IP Limiting](#quota--ip-limiting)
8. [Automated Maintenance (Cron)](#automated-maintenance-cron)
9. [Backup & Restore](#backup--restore)
10. [Web Restore Interface](#web-restore-interface)
11. [Domain & SSL Certificates](#domain--ssl-certificates)
12. [Special Features](#special-features)
13. [File Paths Reference](#file-paths-reference)
14. [Go Binaries](#go-binaries)
15. [Bugs Fixed](#bugs-fixed)
16. [Known Issues](#known-issues)
17. [Security Notes](#security-notes)
18. [Updating an Existing Install](#updating-an-existing-install)

---

## Installation

### Prerequisites

- A fresh VPS running Debian 10/11/12 or Ubuntu 20.04/22.04/24.04.
- Root access.
- A domain name pointed at your VPS public IP (an `A` record for IPv4, or
  `AAAA` for IPv6).
- Your VPS public IPv4 registered in the authorization repository (see below).

### Authorization

The installer will only run on a server whose public IPv4 appears in:

[`rohjagad/fn-autosc-auth/izin.txt`](https://github.com/rohjagad/fn-autosc-auth/blob/main/izin.txt)

Each line has the form:

```text
### <client-name> <ipv4-address> <expiry-date-YYYY-MM-DD>
```

For example:

```text
### client-01 203.0.113.195 2027-12-31
```

If the IP is not listed, or the expiry date has passed, every script exits
immediately. The check runs again on every menu command, so authorization is
continuously enforced — not just at install time.

### Install Command

Run as `root`. The install takes 15-30 minutes, so run it inside a terminal
multiplexer — a dropped SSH connection then cannot interrupt it:

```bash
# a stripped image may ship no downloader at all - install one first, since
# fetching the installer below is itself a download
command -v curl >/dev/null 2>&1 || { apt-get update -qq && apt-get install -y curl; }
command -v screen >/dev/null 2>&1 || { apt-get update -qq && apt-get install -y screen; }

# start a persistent session (screen is installed for you if it is missing)
screen -S fninstall

# run the installer inside it and answer the prompts
bash <(curl -fsSL https://raw.githubusercontent.com/rohjagad/fn-autosc/main/install.sh)
```

Detach at any time with **`Ctrl-A` then `D`** — the installation keeps running
on the server. Come back later and watch it:

```bash
screen -r fninstall     # reattach to the running install
screen -ls              # list sessions (if you forget the name)
```

`install.sh` now does this for you: started outside `screen`/`tmux`, it
re-launches itself in a session named `fninstall` (set `FN_NO_SESSION=1` to opt
out). `tmux` works just as well — detach with `Ctrl-B` then `D`, reattach with
`tmux attach -t fninstall`.

To keep a transcript you can follow without attaching, turn logging on when you
create the session:

```bash
screen -S fninstall -L -Logfile /root/fn-install.log
tail -f /root/fn-install.log      # follow it from a second SSH connection
```

The installer bootstraps `curl`/`wget` for its own payload, configures Debian
mirrors on stripped images, then verifies authorization before doing anything
else. Fetching the installer in the first place still needs a downloader, which
is why the block above installs `curl` first.

### Installation Prompts

You will be asked four things:

| Prompt | Meaning | Example |
| :--- | :--- | :--- |
| **Script type** | `full` or `lite` | `full` |
| **Domain** | Domain pointing at this VPS | `vpn.example.com` |
| **Email** | Contact email for ACME certificates | `admin@example.com` |
| **IP type** | `4`, `6`, or `dual` | `4` |

When installation finishes you will see `INSTALL SUCCESS`. A summary is also
sent to the configured Telegram chat.

### Installation Order

The full installer runs these stages, in order:

1. Save domain, email, and IP type.
2. Install base packages, directories, Node.js 16, and vnStat (`package.sh`).
3. Download and install the menu payload one file at a time into `/usr/bin`.
4. Install the terminal display formatter (`/etc/funny/format.sh`).
5. Install SSH, Dropbear (pinned to 2019.78 — see decision 25), and SSH WebSocket (`ssh.sh`).
6. Install Xray (`xray.sh`) — WebSocket, HTTP Upgrade, XHTTP, gRPC (all four transports).
7. Install the web restore interface (`website/install.sh`).
8. Install Nginx and obtain SSL certificates (`diamond.sh`).
9. Install OpenVPN, Squid, OHP (`vpn.sh`).
10. Install SlowDNS (`slowdns.sh`).
11. Install L2TP/IPsec (`l2tp.sh`).
12. Install WireGuard (`wg.sh`).
13. Install NoobzVPN (`noobz.sh`).
14. Install UDP Custom (`udp.sh`) and UDP Request (`request.sh`).
15. Apply system tuning and repairs (`fix/fix.sh`).

The Lite installer runs a smaller subset: packages, menu, SSH, Xray (all four transports),
website, and Nginx/SSL. It **skips** OpenVPN, SlowDNS, L2TP, WireGuard,
NoobzVPN, and UDP.

### Payload Layout (No Menu Zip)

The installer no longer downloads `menu/full.zip` or `menu/lite.zip`. It
downloads `menu/<edition>.manifest` and then each file individually:

- `script <name>` -> `<edition>/<name>.sh`
- `web <name>` -> `website/<name>.sh` (the web restore command)
- `bin <name>` -> `bin/<edition>/<name>`

`installer/payload.sh` stages and verifies every file (`bash -n` for scripts,
ELF magic for binaries) before replacing anything in `/usr/bin`, so a failed
or truncated download leaves the current install untouched.

Development workflow:

- Shell change: edit `<edition>/<name>.sh` and commit it. No repack.
- Go change: run `tools/build-binaries.sh`, commit the changed
  `bin/<edition>/<name>`, then run `tools/verify-payload.sh`.
- Add/remove a command: update `menu/<edition>.manifest` and the matching
  source or binary.

`tools/verify-payload.sh` checks manifest duplicates, missing sources,
orphan scripts/binaries, `bash -n` on every script, and the ELF/execute bits
on every binary.

---

## Variants — Full vs Lite

| Component | Full | Lite |
| :--- | :---: | :---: |
| Base packages + Node.js 16 + vnStat | ✅ | ✅ |
| SSH / Dropbear / SSH WebSocket | ✅ | ❌ |
| Xray (HTTP Upgrade, XHTTP, gRPC) | ✅ | ✅ |
| Xray (WebSocket) | ✅ | ✅ |
| Nginx + SSL certificates | ✅ | ✅ |
| Web restore interface | ✅ | ✅ |
| OpenVPN + Squid + OHP | ✅ | ❌ |
| SlowDNS (DNSTT) | ✅ | ❌ |
| L2TP / IPsec | ✅ | ❌ |
| WireGuard | ✅ | ❌ |
| NoobzVPN | ✅ | ❌ |
| UDP Custom / UDP Request | ✅ | ❌ |
| Argo, WARP, Telegram bot | ✅ | ✅ |

Both variants install the same apt package set — "Lite" controls which
*configuration stages* run, not the raw package footprint.

---

## Menus

Every menu is a command. Type it in the terminal to open it.

### Main Menu — `menu`

The dashboard. Shows the SSH version, domain, IP, uptime, ISP/region, account
counts per protocol, service status, recent traffic, and the installed /
updated panel commits (from `update.sh`).

| Option | Opens |
| :---: | :--- |
| 1 | SSH Menu (`menu-ssh`) |
| 2 | XTLS Menu (`menu-x`) |
| 3 | Domain Menu (`dm-menu`) |
| 4 | SlowDNS Menu (`menu-dnstt`) |
| 5 | Backup Menu (`bmenu`) |
| 6 | Telegram Bot (`menu-bot`) |
| 7 | L2TP Menu (`xl2tp`) |
| 8 | WireGuard Menu (`menu-wg`) |
| 9 | NoobzVPN Menu (`menu-noobz`) |
| 10 | System Menu (`menu-system`) |

### SSH Menu — `menu-ssh`

Create, trial, delete, extend, and list SSH accounts; check who is online;
view account logs; change passwords; change IP limits. The header lists the
version of the SSH front-ends a client connects through — OpenSSH, Dropbear,
the SSH WebSocket (`ws`), and Stunnel5 (decision 27).

### XTLS Menu — `menu-x`

Branches into the four protocol submenus:

- `x-ws` — WebSocket
- `x-http` — HTTP Upgrade
- `x-xhttp` — XHTTP
- `x-grpc` — gRPC

Each submenu offers the same 17 actions: create VMess / VLESS / Trojan,
create trials, check online users, delete, extend, view database logs, list
accounts, change UUID/password, unlock, routing config, change IP limit,
change quota, and lock.

### Other Menus

| Command | Purpose |
| :--- | :--- |
| `dm-menu` | Add/remove/list domains, renew certificates, self-signed cert |
| `bmenu` | Backup and restore |
| `menu-bot` | Telegram notifications and terminal bot |
| `menu-dnstt` | SlowDNS nameserver and keys |
| `menu-wg` | WireGuard accounts and configs |
| `xl2tp` | L2TP / IPsec accounts |
| `menu-noobz` | NoobzVPN accounts |
| `menu-system` | Timezone, service restart, WARP, OS reinstall, banner |
| `menu-argo` | Cloudflare Argo tunnel |

---

## Protocols & Ports

### Direct Services

| Service | Transport | Port(s) |
| :--- | :--- | :--- |
| OpenSSH | TCP | `22`, `3303` |
| Dropbear | TCP | `109`, `111` |
| Stunnel5 / HAProxy | TCP over TLS | `777` |
| Squid Proxy | HTTP CONNECT | `3128` |
| FN-OHP | HTTP proxy for OpenVPN | `9088` |
| OpenVPN TCP | TCP | `1194` |
| OpenVPN UDP | UDP | `2200` |
| OpenVPN WebSocket | HTTP WebSocket | `2086` |
| WireGuard | UDP | `51820` |
| L2TP / IPsec | UDP | `500`, `4500`, `1701` |
| NoobzVPN | TCP | `8080`, `8443` |
| SlowDNS (DNSTT) | UDP / DNS | `53` → `5300` |
| BadVPN / UDPGW | TCP | `7300` (localhost) |
| Web restore interface | HTTP (Apache) | `855` |

### HTTP / TLS Front-End Ports

Nginx terminates every Xray transport on the **same set of ports**.
Pick any port your network allows — they all serve the same service.

**TLS ports:**

```text
443   2053   2083   2087   2096
```

**NoneTLS (plain HTTP) ports:**

```text
80   8880   2052   2082   2095
```

The extra ports exist because Cloudflare's proxy only forwards a fixed set of
ports, and because some ISPs block 80/443. Using `2053`, `2083`, `2087`, or
`2096` lets clients connect through Cloudflare or past ISP filters while
receiving the same TLS service.

> Reachability note (measured live, Oct 2026): from two different client ISPs
> the ports `2082`/`2083`/`2087`/`2095`/`2096` timed out at TCP level
> (8s blackhole) while the server listened and served them locally
> (`curl` to `127.0.0.1` works), the host firewall was ACCEPT, closed ports
> elsewhere RST fast, and even hairpin via the public IP worked — while
> `443`/`2053`/`80`/`8880`/`2052` connected in ~30ms. The same five ports
> also failed through Cloudflare edge IPs (`104.17.x.x`/`104.18.x.x`,
> SNI+Host set correctly, valid edge cert): edge TCP+TLS fine, but no HTTP
> answer, while `443`/`2053`/`80`/`8880`/`2052` via the same edge returned
> `101` and carried full tunnels. That combination points at the VPS
> provider's edge firewall for the direct path (and edge/port enablement on
> the Cloudflare side for the CF path), not the panel. If clients report an
> alt port dead, open it in the provider's firewall panel (or ticket them)
> before assuming a panel fault.

---

## Transport Paths

Each protocol has its own URL path or gRPC service name. The **client link must
match the server path exactly** — these are what the account creation cards
show you.

Clients connect on any port listed above. Nginx inspects the path and forwards
internally to the correct Xray backend. Those internal ports are bound
to `127.0.0.1` only and are never reachable from outside.

| Protocol | Transport | TLS Path | NoneTLS Path | Internal Backend |
| :--- | :--- | :--- | :--- | :--- |
| VMess WS | WebSocket | `/vmws` | `/vmws` | `127.0.0.1:23456` |
| VLESS WS | WebSocket | `/vlws` | `/vlws` | `127.0.0.1:14016` |
| Trojan WS | WebSocket | `/trws` | `/trws` | `127.0.0.1:25432` |
| VMess HTTP Upgrade | HTTPUpgrade | `/vmhu` | `/vmhu` | `127.0.0.1:8001` |
| VLESS HTTP Upgrade | HTTPUpgrade | `/vlhu` | `/vlhu` | `127.0.0.1:8003` |
| Trojan HTTP Upgrade | HTTPUpgrade | `/trhu` | `/trhu` | `127.0.0.1:8002` |
| VMess XHTTP | XHTTP | `/vmxh` | `/vmxh` | `127.0.0.1:2019` |
| VLESS XHTTP | XHTTP | `/vlxh` | `/vlxh` | `127.0.0.1:2023` |
| Trojan XHTTP | XHTTP | `/trxh` | `/trxh` | `127.0.0.1:2020` |
| VMess gRPC | gRPC | `vmgr` | — | `127.0.0.1:31234` |
| VLESS gRPC | gRPC | `vlgr` | — | `127.0.0.1:24456` |
| Trojan gRPC | gRPC | `trgr` | — | `127.0.0.1:33456` |

### Alternative color paths

Every canonical path above has three color aliases (e.g. `/vmws` also
answers on `/red`, `/crimson`, `/scarlet`). Nginx rewrites them to the
canonical path upstream, so they behave identically. New account links
rotate across colors (round-robin via `/etc/xray/.colorseq`)
to spread usage. Paths do have a default: the canonical path always works
when typed manually and is what the card description shows (`Path`/`Service`
rows) — but copy-able links never use it, only colors.
to spread usage; the card description always shows the canonical path.

| Canonical | Colors |
| :--- | :--- |
| `/vmws` | `/red`, `/crimson`, `/scarlet` |
| `/vlws` | `/green`, `/lime`, `/emerald` |
| `/trws` | `/blue`, `/navy`, `/azure` |
| `/vmhu` | `/yellow`, `/gold`, `/khaki` |
| `/vlhu` | `/pink`, `/coral`, `/salmon` |
| `/trhu` | `/orange`, `/amber`, `/chocolate` |
| `/vmxh` | `/purple`, `/violet`, `/indigo` |
| `/vlxh` | `/cyan`, `/teal`, `/turquoise` |
| `/trxh` | `/brown`, `/tan`, `/beige` |
| `vmgr` | `black`, `gray`, `silver` |
| `vlgr` | `white`, `ivory`, `snow` |
| `trgr` | `magenta`, `plum`, `orchid` |

### Domain naming: installer domain and rotated domains

`/etc/xray/installer-domain` holds the single installer domain. It keeps Nginx
and the certificate anchored even when the rotation list is empty, so it cannot
be removed. `/etc/xray/rotated-domains` is the independent rotation list, one
domain per line. New account links rotate only over that list via
`/etc/xray/.rotated-domainseq`, exactly like colors; the installer domain is not
implicitly added.

On a fresh install the installer domain is written to both files, so the first
rotated entry is the installer domain. That entry is ordinary and removable
from the rotated list; the installer-domain file is unchanged. If every rotated
entry is removed, Xray, SSH, and WireGuard account creation stops with a notice
asking for a rotated domain instead of dividing by zero or silently using the
installer domain.

Every account card names the two values explicitly:

- `Installer Domain :` — the domain the panel was installed with.
- `Rotated Domain :` — the domain used by that account's links.

L2TP and NoobzVPN have no per-account links, so their cards list the rotation
list as `Rotated Domains :`. The Domain Menu list reports per-domain account
counts for each protocol, marks the installer entry when it is in the rotated
list, and shows the installer domain separately when it has been removed but
legacy accounts still point at it.

### Why arbitrary paths are unstable

You may have seen advice to use paths like `/anything` or `/custom`. Those are
**not** dedicated paths and will be unstable.

Any path that does not match a specific location block falls through to the
Nginx `location /` catch-all, which forwards to the SSH WebSocket backend:

```text
127.0.0.1:2080   SSH WebSocket (wsEpro)
```

Those connections land on the SSH WebSocket backend and fail.
Use `/vmws`, `/vlws`, `/trws`, and the other paths in the table above —
they route 100% of traffic to a dedicated backend and are fast and stable.

---

## Account Lifecycle

### Creating an Account

From any protocol submenu, choose *Create*. You will be asked for:

| Input | Notes |
| :--- | :--- |
| **Username** | Lowercase letters, digits, and underscore only. Must not already exist. |
| **Limit IP** | Maximum concurrent IPs (integer; `0` for unlimited). |
| **Limit Quota** | Data cap in GB (`0` for unlimited). |
| **Active Time** | Validity in days. |
| **UUID** | Optional — leave blank to generate one. |

The account is added to the protocol's config file, quota and IP-limit files are
written, the client links are generated, and the relevant service restarts.

The creation card is printed to the terminal with full styling (rainbow outer
borders, blue inner separators, green values, purple section titles, and
deep-purple connection links). The same card is saved to the account log
directory and sent to Telegram — those two copies are plain text.

### Trial Accounts

Trial accounts are pre-filled and temporary:

- Username: `trial` + three random digits
- Quota: 1 GB
- IP limit: 1
- Active time: 60 minutes

They are removed automatically by an `at` job when the timer expires.

### Deleting an Account

Removes the account from the config file and deletes its log, quota, and
IP-limit files, then restarts the service.

### Extending an Account

Prompts for the username and a number of days, then recomputes the expiry date
in the config file.

### Locking and Unlocking

Locking renames the account log from `{username}.log` to `{username}.locked`.
Unlocking reverses it. Both operations restart the service. Locked accounts are
skipped by auto-delete. Multilogin locks lift themselves (Xray at least
15 min, SSH ~15 min via due-epoch sweeper files); manual locks stay until
unlocked.

### Changing UUID / Password

Regenerates credentials for an existing account and updates the config.

### Routing Config

`routing-ws.sh` and friends rewrite the `outbounds` and `routing` section of the
config to add a chained trojan outbound — for connecting this server through
another server.

---

## Quota & IP Limiting

### Quota

Each account with a quota has two files:

```text
/etc/xray/quota/<protocol>/<username>          # limit, in bytes
/etc/xray/quota/<protocol>/<username>_usage    # current usage, in bytes
```

Usage is measured through the Xray stats API by the `quota-*` services
(`quota-ws`, `quota-http`, `quota-xhttp`, `quota-grpc`), which run continuously.

For xHTTP, the shared `/tmp/xray-json-xhttp.lock` covers only JSON/file
mutation. Stats collection, usage-file updates, Telegram notices, and the
service restart happen outside it, so a stalled stats call cannot make `xp`,
`kill-xhttp`, or `limit-ip-xhttp` report `busy`. An idle account with a quota
file gets a zero `_usage` file; the next real counters replace it.

When usage reaches the limit, `kill-*` removes the account and notifies
Telegram. If an account is killed for a missing quota file, the same path
applies.

### IP Limiting

Each account with an IP limit has one file:

```text
/etc/xray/limit/ip/xray/<protocol>/<username>   # max concurrent IPs
```

The `limit-ip-*` jobs run every 5 minutes. For each limited account they merge
the per-IP online map from `xray api statsonlineiplist` with the distinct
source IPs in the transport's access log over the last minute, and lock only
when the same over-limit IP set is seen on two consecutive runs (at least
4 minutes apart). The confirmation window keeps a single CGNAT device that
rotates addresses from looking like several devices; a real multi-device set
stays stable and locks on the second run. The lock notice lists the measured
IPs, or says `IP evidence unavailable` when both sources are empty instead of
showing `IPs (0)`. Per-user confirmation state lives in
`/var/lib/fn-autosc/limit-ip/<protocol>/<username>` and is removed when the
account is under the limit or gone. The access log is only a fallback:
`kill-ws` truncates `ws.log` every 5 minutes, so the limiter never relies on
it alone. Locked cards auto-unlock after at least 15 minutes (15–20 min
on the 5-minute cron), never earlier.

> CDN note (measured live, Oct 2026): behind Cloudflare the limiter counts
> real client IPs on all four transports (nginx forwards the address chain;
> gRPC carries it in `X-Real-IP`). gRPC additionally needs Cloudflare to
> speak HTTP/2 to the origin: on edges that downgrade to HTTP/1.1 the tunnel
> fails with `415` while WS/HU/XHTTP are unaffected. This varies per edge —
> prefer normal DNS (anycast picks healthy edges); if you dial edge IPs
> directly, don't stick to one — a sick edge fails while others work, so
> switch edges when a path misbehaves. If gRPC-over-CDN stays broken on your
> route, serve gRPC users a direct (grey-cloud) hostname.

### SSH IP Limiting

SSH accounts store their maximum concurrent client IPs in
`/etc/xray/limit/ip/ssh/<username>`. `limit-ip-ssh` runs every 5 minutes and
counts unique **active** client IPs per account. As with the Xray limiters, an
over-limit set must be seen on two consecutive runs (at least 4 minutes apart)
before the account is locked, so one CGNAT device that rotates addresses is
not mistaken for several devices. Direct Dropbear/OpenSSH connections expose
the client IP directly. SSH-over-WebSocket/CDN
connections reach Dropbear from `127.0.0.1`, so the `ssh-online` helper pairs
each Dropbear child connection with the matching `ws` log entry (`client:
<ip>` and `opened :2080 >>>> 127.0.0.1:109`) by timestamp; the two lines may
arrive in either order, so the resolver uses the nearest absolute match.
`cek-login-ssh`
uses the same helper, so the menu's `IP / limit` column cannot disagree with
the limiter. It counts unique active IPs, not historical login events; a
session that cannot be mapped is shown as `127.0.0.1` with a warning and
counts as one IP.

SSH-over-TLS on port `777` is the other proxied path: HAProxy forwards to
Dropbear from `127.0.0.1`. The installer and updater enable `option logasap`
with a local0 log target, so HAProxy records the client IP and accept
timestamp at the start of the session; `ssh-online` matches that timestamp to
the Dropbear child. Without the log patch the session stays `127.0.0.1` and
the menu warns rather than inventing an IP.

When the stable over-limit set locks an account, `limit-ip-ssh` runs
`passwd -l` and kills only that account's processes (`pkill -KILL -u`); it
does not restart `ssh`/`sshd`/`ws`, so other users' sessions survive. The
15-minute auto-unlock sweeper runs even when `ssh-online` is missing or
fails, and keeps its due file until `passwd -u` actually succeeds. A session
that waits at the password prompt is still counted for the first day of the
connection.

### The Four Maintenance Jobs

| Command | Protocol | What it does |
| :--- | :--- | :--- |
| `limit-ip-*` | ws/http/xhttp/grpc | Enforce IP limits |
| `auto-delete-*` | ws/http/xhttp/grpc | Remove orphans (log exists, account does not) |
| `kill-*` | ws/http/xhttp/grpc | Remove accounts over quota |
| `quota-*` | ws/http/xhttp/grpc | Service that measures and stores usage |
| `xp` | all + SSH | Remove accounts past their expiry date |

---

## Automated Maintenance (Cron)

These jobs are added to `/etc/crontab` during installation. Each runs under
`flock` so overlapping runs are prevented.

| Schedule | Command | Purpose |
| :--- | :--- | :--- |
| `0 0,6,12,18 * * *` (default; adjustable 1–24 h via bot menu option 3) | `backup` | Back up to Telegram |
| `0,15,30,45 * * * *` | `sleep 300 && xp` | Expiry sweep every 15 min (delayed 5 min) |
| `*/5 * * * *` | `limit-ip-ssh` | SSH IP limit |
| `*/5 * * * *` | `limit-ip-ws` | WebSocket IP limit |
| `*/5 * * * *` | `limit-ip-xhttp` | XHTTP IP limit |
| `*/5 * * * *` | `limit-ip-http` | HTTP Upgrade IP limit |
| `*/5 * * * *` | `limit-ip-grpc` | gRPC IP limit |
| `*/5 * * * *` | `auto-delete-ws` | Remove orphaned WS accounts |
| `*/5 * * * *` | `auto-delete-xhttp` | Remove orphaned XHTTP accounts |
| `*/5 * * * *` | `auto-delete-http` | Remove orphaned HTTP Upgrade accounts |
| `*/5 * * * *` | `auto-delete-grpc` | Remove orphaned gRPC accounts |
| `*/5 * * * *` | `kill-ws` | Remove WS accounts over quota |
| `*/5 * * * *` | `kill-http` | Remove HTTP Upgrade accounts over quota |
| `*/5 * * * *` | `kill-xhttp` | Remove XHTTP accounts over quota |
| `*/5 * * * *` | `kill-grpc` | Remove gRPC accounts over quota |

---

## Backup & Restore

### Backup Menu — `bmenu`

| Option | Action |
| :---: | :--- |
| 1 | Backup to Telegram (`backup`) |
| 2 | Restore from a URL |
| 3 | Restore from a local file |
| 4 | Restore a legacy backup (pre-1.23) |

### What Gets Backed Up

The backup command stages:

```text
/etc/passwd          /etc/xray/          /etc/crontab
/etc/group           /etc/funny/
/etc/shadow          /var/log/create/
/etc/gshadow
```

The staged tree is zipped to `/root/backup.zip`.

> Version markers (`.install-commit`, `.update-commit`, `version`) are
> deliberately left out of the archive. `format.sh` stays in the archive as a
> fallback, but restore keeps the running copy when present. This prevents a
> data restore from rolling the menu version or the account-card renderer back
> to an older panel.

### Where It Goes

- **`backup`** — sends the archive to **Telegram as a document attachment**,
  captioned with the auth username, server IP and date. Runs on the adjustable auto-backup interval (menu-bot option 3, 1-24h).
- **Telegram is the only delivery channel.** There is no file-host upload and
  therefore no expiring public link, no Google Drive variant, and no email
  notification. The Google Drive and email paths were removed, and the
  file-host upload was dropped in their favour (decisions document, sections
  11 and 12).

### Restore

All restore paths unzip the archive and copy `passwd`, `group`, `shadow`,
`gshadow`, `crontab`, `xray`, `funny`, and `create` back into place,
then restart SSH, the four Xray instances, Nginx, and cron.

The legacy restore additionally repairs an old WS backup's config by
re-appending the standard outbounds/routing/stats block to
`/etc/xray/json/ws.json`.

A standalone `restore-ftp` command performs the same restore, taking its zip
from `/var/www/uploads/` — this is what the web interface calls.

---

## Web Restore Interface

A small browser-based restore page is installed on **Apache, port 855**.

Visit:

```text
http://<your-vps-ip>:855/
```

Upload a file named exactly `backup.zip`. The page posts it to `upload.php`,
which moves it into place and runs `restore-ftp` as root, then reports success.

This is convenient for recovering a server whose SSH access is broken, but see
[Security Notes](#security-notes) — the endpoint has no authentication.

---

## Domain & SSL Certificates

### Certificate Flow

`diamond.sh` installs a self-signed EC certificate by default (atomic temp+move,
never truncating the live pair), so install never depends on the network.
Trusted issuance is manual via the Domain menu:

1. **Let's Encrypt** via acme.sh (standalone, EC-256, option 4).
2. **ZeroSSL** fallback if Let's Encrypt fails — typically a `429` rate limit.
3. **Certbot** standalone (option 5).

Certificates land in `/etc/xray/xray.crt` (`0644`) and `/etc/xray/xray.key`
(`0600`). Dual-stack uses a single certificate (one key, one chain).

Nginx reads the pair directly. HAProxy instead needs a single file containing
the chain followed by the key, so the pair is concatenated to
`/etc/haproxy/funny.pem` after every issuance; the bundle contains the private
key and is mode `0600`.

### Domain Menu — `dm-menu`

| Option | Action |
| :---: | :--- |
| 1 | Add rotated domain (auto self-signed multi-SAN) |
| 2 | Remove rotated domain (rebuilds SAN cert + `server_name`) |
| 3 | List domains with per-domain account counts |
| 4 | Renew via acme.sh for the chosen domain (IPv4 or IPv6) |
| 5 | Renew via Certbot for the chosen domain |
| 6 | Generate a self-signed certificate (all domains via SAN) |

The installer domain is written once by the installer to
`/etc/xray/installer-domain` and is never rewritten by the menu. On a fresh
install it is also seeded into `/etc/xray/rotated-domains`; option 2 can remove
it from that list. Adding or removing a rotated domain only updates
`/etc/xray/rotated-domains`, rebuilds the Nginx `server_name`, backs up the old
value, and reinstalls the certificate atomically in the same step. If the
rotated list becomes empty, account creation for Xray, SSH, and WireGuard stops
with a notice until option 1 adds a domain.

### Renewing After Certificate Expiry

Open `dm-menu`, pick the domain first, then choose option 4 (acme.sh) or 5
(certbot). The fallback chain handles rate limits automatically.

---

## Special Features

### SlowDNS (DNSTT)

Tunnels SSH over DNS. Clients connect to UDP `53`; an iptables rule
redirects it internally to the server on UDP `5300`.

**Requirement:** you must delegate a nameserver subdomain (NS record) to this
VPS, for example `slowdns.example.com`. Without it, `dnstt.service` runs but
serves nothing useful.

Key management and the nameserver are configured from `menu-dnstt`. The server
generates an X25519 keypair — the private key stays on the server, and the
public key (`/etc/slowdns/server.pub`) is embedded into client configurations.

### WireGuard — `menu-wg`

Interface `wg0`, UDP `51820`, subnet `10.66.66.0/24`, server address
`10.66.66.1`.

Create, delete, extend, list, and show client configs (with QR codes). Client
IPs are allocated from `10.66.66.2` to `10.66.66.254` — 253 clients maximum.
Configs are written to `/var/www/html/wireguard-<user>.conf` for download.
The client endpoint rotates over the rotated domain list (round-robin via
`/etc/xray/.rotated-domainseq`), same as Xray links; if the list is empty,
creation stops with the same notice. The card shows both `Installer Domain` and
the assigned `Rotated Domain`.

Also includes a Cloudflare WARP helper (peer persisted in `wg0.conf` with
keepalive, IPv4 endpoint resolved at setup).

### L2TP / IPsec — `xl2tp`

StrongSwan plus xl2tpd. IKE on UDP `500`, NAT-T on `4500`, L2TP on `1701`.
Client subnet `192.168.42.0/24`.

Accounts are stored in `/etc/funny/.l2tp`, with credentials mirrored into
`/etc/ppp/chap-secrets` and `/etc/ipsec.d/passwd`.

> The IPsec pre-shared key is generated randomly per install and stored mode
> `0600`; it is shown in the account card.

### OpenVPN

Two servers:

- TCP on `1194` — profile `/var/www/html/tcp.ovpn`
- UDP on `2200` — profile `/var/www/html/udp.ovpn`

Both are downloadable from `http://<domain>/web/`. Squid (`3128`) and FN-OHP
(`9088`) provide HTTP proxying for OpenVPN clients. There is also an OpenVPN
WebSocket service on `2086`.

### NoobzVPN — `menu-noobz`

Dual-mode TCP tunnel: plain on `8080`, TLS on `8443`. TLS uses the domain
ACME pair (symlinked, refreshed on renewal).

### UDP Custom & UDP Request

Both are UDP forwarding helpers for gaming and streaming. Each listens on
`36711` and is managed indirectly. UDP Request installs a watchdog timer that
keeps a protective `RETURN` rule in place so the VPS never locks itself out.

> Running UDP Custom and UDP Request together causes a port conflict — enable
> only one.

### Cloudflare Argo — `menu-argo`

Installs `cloudflared`, logs into Cloudflare, creates a tunnel, and routes DNS
to it. Ingress points at `localhost:80` and the WebSocket backend on `2080`.

### Telegram Bot — `menu-bot`

| Option | Action |
| :---: | :--- |
| 1 | Set up bot credentials — shows the registered chat ID and API key, then accepts new values (press ENTER on a field to keep it) → `/etc/funny/.keybot`, `/etc/funny/.chatid` |
| 2 | Set up bot notifications — reuses the saved credentials and sends one test message |
| 3 | Set up bot auto backup — reuses the saved credentials and guarantees the 4×/day scheduled backup |
| 4 | Terminal bot menu — install / uninstall / restart the Node.js bot |
| 5 | Report a script bug |

Credentials are entered **once**, in option 1; options 2 and 3 read them from
`/etc/funny/` and never ask again. Once set, account creation, deletion,
extension, quota kills, and backups all post notifications — and the backup
archive itself is delivered to Telegram (see the Backup Menu section).

### System Menu — `menu-system`

Timezone (9 regions), restart all services, Cloudflare WARP, OS reinstall
(17 distributions), service/port details, htop, Argo, and SSH banner editing.

### System Tuning — `fix/fix.sh`

Applies kernel tuning at install time:

```text
fs.file-max = 1000000
net.netfilter.nf_conntrack_max = 262144
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 30
```

---

## File Paths Reference

### Account Creation Logs

Plain text when written; the Go viewers format them with colour for the
terminal only.

| Protocol | Directory |
| :--- | :--- |
| VMess / VLESS / Trojan WebSocket | `/var/log/create/xray/ws/` |
| VMess / VLESS / Trojan HTTP Upgrade | `/var/log/create/xray/http/` |
| VMess / VLESS / Trojan XHTTP | `/var/log/create/xray/xhttp/` |
| VMess / VLESS / Trojan gRPC | `/var/log/create/xray/grpc/` |
| SSH | `/var/log/create/ssh/` |

Files are named `{username}.log`. Locking renames them to `{username}.locked`.

### Runtime Logs

| Service | Log |
| :--- | :--- |
| Xray WebSocket (WS) | `/var/log/xray/ws.log` |
| Xray HTTP Upgrade | `/var/log/xray/upgrade.log` |
| Xray XHTTP | `/var/log/xray/xhttp.log` |
| Xray gRPC | `/var/log/xray/grpc.log` |

### Config Files

| Service | Config |
| :--- | :--- |
| Xray WebSocket (WS) | `/etc/xray/json/ws.json` |
| Xray HTTP Upgrade | `/etc/xray/json/upgrade.json` |
| Xray XHTTP | `/etc/xray/json/xhttp.json` |
| Xray gRPC | `/etc/xray/json/grpc.json` |
| Nginx | `/etc/nginx/nginx.conf` |
| Installer domain | `/etc/xray/installer-domain` |
| Rotated domain list | `/etc/xray/rotated-domains` |
| Rotation counter | `/etc/xray/.rotated-domainseq` |
| Certificate | `/etc/xray/xray.crt`, `/etc/xray/xray.key` |
| HAProxy bundle | `/etc/haproxy/funny.pem` |
| Telegram | `/etc/funny/.keybot`, `/etc/funny/.chatid` |
| Version | `/etc/funny/version` |
| Install commit | `/etc/funny/.install-commit` (written by the installer) |
| Update commit | `/etc/funny/.update-commit` (written by `update.sh`) |

The three version markers above are not archived; restore keeps the running
copies so an old backup cannot make the menu display an older panel version.

The main menu shows the first seven characters of both markers. A fresh
install resolves the current `main` SHA from the GitHub API
(`/repos/rohjagad/fn-autosc/commits/main`), with `git ls-remote` as a fallback,
so `Installed version` is populated immediately. `Updated version` shows
`not updated` until `update.sh` records an update. Missing, empty, or invalid
markers display `not recorded` / `not updated`, never `Unknown`; when the
install marker is missing or invalid and an update actually changes the
version, `update.sh` records the detected live version as the baseline. A
same-target rerun leaves the marker alone.

### Quota & IP Limit Files

```text
/etc/xray/quota/<protocol>/<username>          # quota limit (bytes)
/etc/xray/quota/<protocol>/<username>_usage    # current usage (bytes)
/etc/xray/limit/ip/xray/<protocol>/<username>  # max IPs (integer)
```

Where `<protocol>` is `ws`, `http`, `xhttp`, or `grpc`.

---

## Go Binaries

Several commands are compiled Go programs. Their sources live alongside the
shell scripts.

| Binary | Source | Purpose |
| :--- | :--- | :--- |
| `log-database-xray-ws` | `log-database-xray-ws.go` | Styled WS account log viewer |
| `log-database-xray-http` | `log-database-xray-http.go` | Styled HTTP Upgrade log viewer |
| `log-database-xray-xhttp` | `log-database-xray-xhttp.go` | Styled XHTTP log viewer |
| `log-database-xray-grpc` | `log-database-xray-grpc.go` | Styled gRPC log viewer |
| `log-acc-ssh` | `log-acc-ssh.go` | Styled SSH log viewer |
| `cek-xray-ws` | `cek-xray-ws.sh` (shell, not Go) | WS account status |
| `cek-xray-http` | `cek-xray-http.go` | HTTP Upgrade account status |
| `cek-xray-xhttp` | `cek-xray-xhttp.go` | XHTTP account status |
| `cek-xray-grpc` | `cek-xray-grpc.go` | gRPC account status |
| `limit-ip` | `limit-ip.go` | SSH IP limiter |
| `delete-ssh` | `delete-ssh.go` | Delete SSH accounts |
| `extend-ssh` | `extend-ssh.go` | Extend SSH accounts |
| `list-ssh` | `list-ssh.go` | List SSH accounts |
| `pwd-ssh` | `pwd-ssh.go` | Show SSH passwords |
| `change-limit-ip-ws` | `change-limit-ip-ws.go` | Change WS IP limit |
| `change-limit-ip-http` | `change-limit-ip-http.go` | Change HTTP Upgrade IP limit |
| `change-limit-ip-xhttp` | `change-limit-ip-xhttp.go` | Change XHTTP IP limit |
| `change-limit-ip-grpc` | `change-limit-ip-grpc.go` | Change gRPC IP limit |

Binaries are built with `-ldflags='-s -w'` for a small footprint.

---

## Bugs Fixed

- **Typos that silently broke features** — `apt insfall` in the WebSocket installer (now `ws.sh`),
  `systemctl resrart` in the restore scripts, `cp -r creare` in the website
  restore, `Hostibg`, and `INSTALL SUCCES`.
- **Swapped IPv4/IPv6 variables** in `bmenu.sh` and the restore scripts, which
  had `ip4` fetching the IPv6 address and vice versa.
- **PHP `strpos()` called with one argument** in `upload.php`, breaking restore
  success detection.
- **Duplicate restore block** in `website/restore-ftp.sh` that ran the restore
  twice.
- **`ws.json` deleted before backup**, so backups silently omitted it.
- **Wrong OpenVPN UDP client port** — clients were told to connect to Squid's
  `3128` instead of the OpenVPN UDP port `2200`.
- **`kill-*.sh` missing the `.log` extension**, so quota kills never removed
  log files and killed accounts kept appearing in the database viewer.
- **`trial-ssh.sh` wrote no log**, so trial SSH accounts were invisible to the
  database viewer.
- **Missing `cek-xray-ws` binary** that the WS menu called.
- **Transport path bugs** — a VLESS WS path mismatch, a broken Trojan XHTTP
  URL, a wrong VMess WS display path, `security=none` on a TLS gRPC link, a
  literal `#user` fragment, and inconsistent `xhttp` type identifiers.
- **Duplicate website install** in `installer/lite.sh`.
- **Libreswan 3.32 crashes** on Debian 11/12 — replaced with distribution
  `strongswan` + `xl2tpd`.
- **SSL issuance failures on rate limits** — added the ZeroSSL and self-signed
  fallback chain, and synchronized `funny.pem` for HAProxy.
- **Slow downloads from raw GitHub** — payload files are fetched individually
  with 600 s timeouts; large binaries live in `bin/<edition>/`.
- **WireGuard interface collisions on reinstall** — config is now overwritten
  rather than appended.
- **Remaining Indonesian user-facing text** translated to English.
- **`time.Sleep(1)`** in `limit-ip.go`, which slept one nanosecond instead of
  one second.
- **Node.js 16 retained** — Node 20 was tried (Fix 271) but reverted (Fix 275): the terminal bot's pinned native addons (`node-pty ^0.9.0`, `node-termios 0.0.13`) do not build on Node 20.
- **Menu wording and styling** — grammar fixes across all Full and Lite menus,
  removed `<= ... =>` delimiters, standardized rainbow/blue/green styling, and
  applied matching styling to account creation output.
- **SSH IP display/limit counted history** — the menu and limiter now use
  active unique client IPs; WS/CDN and `777` sessions are mapped to the real
  client, and a slow password entry still counts.
- **Auto-unlock could freeze or lose its due state** — the sweeper is
  independent of `ssh-online`, the due file is kept until unlock succeeds,
  corrupt due files fall back to `mtime`/now, and the stable-set grace no
  longer resets on frequent manual runs.
- **SSH lock no longer restarts every session** — a lock terminates only
  the over-limit account's processes; other users keep their sessions.
- **Updater no longer replaces the web restore command** —
  `/usr/bin/restore-ftp` stays the website variant; interactive restore
  remains in `bmenu`. The installer manifest uses a `web` entry too, so a
  standalone payload run cannot reintroduce the TUI script.
- **Updater starts from the live version marker** — `.update-commit`, then
  `.install-commit`, with the documented `6b967af` live v1.23 fallback; the
  stale `5c48741` baseline is gone.
- **HAProxy 777 logging checks the `ssh-ssl` section** — a `log global` in
  another frontend no longer hides a missing directive, so 777 sessions map
  to their real client IPs.
- **IPv6 brackets counted twice** — normalized in the Xray limiters and the
  SSH helper.

---

## Known Issues

1. **SlowDNS needs manual setup** — `dnstt.service` is inactive until a
   nameserver domain is configured via `menu-dnstt`.
2. **XHTTP and HTTP/2** — some clients expecting plain HTTP/1.1 chunked
   transport may not work through HTTP/2 reverse proxies.
3. **UDP Request SNAT** — the broad `10.0.0.0/8` SNAT rule can overlap client
   private subnets and may need manual exclusion.

Formerly listed here and since fixed: the stale `raw.githubusercontent.com`
hosts entry; the hardcoded Telegram bot token (the install notification now
reads the operator's own `/etc/funny/.keybot` and `/etc/funny/.chatid` and
sends nothing when they are unset, so no credential is committed); the
hardcoded third-party contacts in the SSH banner (the order/trial line now
shows `wa.me/6289512992313`, and the previous author's group invite has been
replaced by `t.me/rohcuan`); the
Fail2ban/auth-log gap (now
configured against the systemd journal, which is where Debian 12 sshd and
dropbear actually log); the BadVPN/UDPGW `7300` port (the `other/badvpn` binary
the repository already shipped is now installed and run as
`badvpn-udpgw.service` on `127.0.0.1:7300`); the broken Argo/SlowDNS menu
entries; the hardcoded Certbot addresses in `dm-menu.sh` (now read from
`/etc/funny/.email`); and the `file.io` expiry mismatch (now moot - the
file-host upload has been removed entirely in favour of Telegram attachments).

---

## Security Notes

Read these before exposing a server to the internet.

- **The web restore endpoint requires the key in `/etc/funny/.restore.key`.**
  Uploads without (or with a wrong) token get `401`; only a matching token
  triggers extraction. Still, block port `855` at the firewall when not
  actively using it, or restrict it by source IP.
- **Backups contain password hashes.** The archive includes `/etc/shadow` and
  `/etc/gshadow`, and `backup` sends it as a Telegram document attachment only
  (no public link, no file host). Treat the delivered archive as a secret.
- **No secret is committed to the repository** — the L2TP pre-shared key is
  generated randomly at install time (`installer/l2tp.sh`). (The Telegram bot token and the Gmail app password
  that used to be listed here are both gone: install notifications use the
  operator's own `/etc/funny/` credentials, and the email and Google Drive
  backup paths have been removed.)
- **Authorization is remote and IP-based.** If GitHub is unreachable, or the
  IP is not listed, scripts fail closed and exit.

---

## Updating an Existing Install

A server installed from an older commit can be brought up to date
without reinstalling. Run as `root`:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/rohjagad/fn-autosc/main/update.sh)
```

What it does:

- Detects the installed edition (`full` vs `lite`) and the live starting
  version: `/etc/funny/.update-commit` (last applied update), then
  `/etc/funny/.install-commit` (fresh install); `Unknown`/empty markers are
  ignored, and only when both are missing does it use the documented
  `6b967af` live v1.23 fallback. If the install marker is missing or invalid
  and the update changes the version, that detected live version is also
  recorded in `.install-commit` as the install baseline. The target remains
  pinned in `update.sh`; currently
  `2833d8d03dc9f1cd22e0b2a130a417c18877be6a` (Fix 523 content; the updater
  script itself also carries Fix 520–523). It fetches 56 files on full,
  47 on lite. The four `change-limit-ip` tools and the full `limit-ip` tool ship as
  compiled binaries from `bin/<edition>/` and are checked against pinned md5
  fingerprints; shell files are syntax- and marker-checked. The account-card
  formatter `/etc/funny/format.sh` is fetched from `config/`, and the web
  restore command `/usr/bin/restore-ftp` from `website/`, then refreshed too.
  The payload manifest and `installer/payload.sh` are installer-only; the
  updater already installs the website restore variant through `WEB_FILES`.
- Downloads everything first, then verifies every file. If any check
  fails, **nothing is changed**.
- Backs up the replaced files to `/root/fn-update-backup-<date>/`,
  installs the new ones as `0755` into `/usr/bin` (the formatter into
  `/etc/funny`), wires the SSH banner
  (`Banner` in `sshd_config`, `-b` in Dropbear args — banner content
  itself is never touched), enables HAProxy start-of-session logging for the
  `777` front-end (full edition), and records the commit in
  `/etc/funny/.update-commit` (re-running is a no-op unless `--force`
  is passed).
- Cron/menu scripts need no restart. `ssh`/`dropbear` restart only when
  banner wiring was missing (SSH sessions survive; Dropbear clients
  reconnect); `haproxy` restarts only when the `777` logging patch was
  applied.

---

## Credits

FN AutoSC · branch `main`
