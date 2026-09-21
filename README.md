# FN AutoSC

Menu-driven VPS automation script for tunneling protocols, proxy services, and Xray/V2Ray account management. Supports Debian (10–12) and Ubuntu (20.04–24.04).

---

## User Guide (Installation)

### 1. Prerequisites
- Fresh VPS running Debian (10, 11, 12) or Ubuntu (20.04, 22.04, 24.04).
- Root user access.
- Domain name pointing to your VPS public IP address (A / AAAA record).
- VPS public IPv4 authorized in the rental authorization repository.

### 2. Rental Authorization
The installer requires the server's public IPv4 address to be registered in:
[`rohjagad/fn-autosc-auth/izin.txt`](https://github.com/rohjagad/fn-autosc-auth/blob/1.23/izin.txt)

Record syntax:
```text
### <client-name> <ipv4-address> <expiry-date-YYYY-MM-DD>
```
Example:
```text
### client-01 203.0.113.195 2027-12-31
```

### 3. Installation Command
Run the following command as `root`:
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/rohjagad/fn-autosc/1.23/install.sh)
```

### 4. Interactive Prompts
1. **Variant Selection**:
   - `full`: Complete suite (SSH, Xray/V2Ray, OpenVPN, WireGuard, L2TP, NoobzVPN, SlowDNS, Argo, backup tools).
   - `lite`: Lightweight installation focused on Xray, V2Ray, and web proxy services.
2. **Domain Configuration**: Enter your domain pointing to the VPS (e.g. `vpn.example.com`).
3. **Email Configuration**: Enter email for ACME SSL certificate issuance (e.g. `admin@example.com`).
4. **IP Type**: Select `4` (IPv4 only), `6` (IPv6 only), or `dual` (Dual stack).

### 5. Accessing Menus
After installation completes, manage services via terminal commands:
- `menu`: Primary management dashboard.
- `menu-ssh`: SSH and OpenVPN account management.
- `menu-x`: XTLS and Xray protocol submenus.
- `x-ws`, `x-http`, `x-split`, `x-grpc`: Protocol-specific management.
- `menu-wg`: WireGuard manager.
- `xl2tp`: L2TP / IPsec manager.
- `menu-noobz`: NoobzVPN manager.
- `menu-dnstt`: SlowDNS (DNSTT) manager.
- `menu-argo`: Cloudflare Argo tunnel manager.
- `menu-bot`: Telegram notification and terminal bot manager.
- `bmenu`: Backup and restore utility.
- `dm-menu`: Domain and SSL certificate renewal manager.
- `menu-system`: System settings, timezones, and OS reinstall tools.

---

## Protocols, Connections & Ports

| Service / Protocol | Transport / Mode | Port(s) | Notes |
| :--- | :--- | :--- | :--- |
| **OpenSSH** | Direct TCP | `22`, `3303` | Primary administrative and tunnel ports |
| **Dropbear** | Direct TCP | `109`, `111` | Lightweight SSH daemon |
| **Stunnel5** | SSL / TLS wrapper | `443` | Proxies TLS to Dropbear |
| **SSH WebSocket** | HTTP / NoneTLS | `80`, `8880`, `2052`, `2082`, `2086`, `2095` | Nginx reverse proxy to WebSocket ePro |
| **SSH WebSocket** | HTTPS / TLS | `443`, `2053`, `2083`, `2087`, `2096` | SSL frontend reverse proxy |
| **Enhanced WebSocket** | Direct TCP | `2080` | ws-epro backend service |
| **Squid Proxy** | HTTP CONNECT | `3128` | Local proxy limited to server IP |
| **FN-OHP** | OpenVPN HTTP Proxy | `9088` | OHP bridge to OpenVPN |
| **Xray VMess / VLESS / Trojan** | WebSocket (TLS) | `443`, `2053`, `2083`, `2087`, `2096` | Multiplexed over Nginx |
| **Xray VMess / VLESS / Trojan** | WebSocket (NoneTLS) | `80`, `8880`, `2052`, `2082`, `2095` | Multiplexed over Nginx |
| **Xray HTTP Upgrade** | HTTP Upgrade (TLS / NoneTLS) | `443` (TLS), `80` (NoneTLS) | Xray upgrade backend on port `2017` |
| **Xray gRPC** | Gun / Multi-mode | `443` (TLS) | Xray gRPC backend on port `2018` |
| **Xray SplitHTTP** | xhttp transport | `443` (TLS), `80` (NoneTLS) | Xray split backend on port `2019` |
| **OpenVPN TCP** | Direct TCP | `1194` | Profile: `/var/www/html/web/tcp.ovpn` |
| **OpenVPN UDP** | Direct UDP | `2200` | High-performance UDP tunnel |
| **OpenVPN WebSocket** | HTTP WebSocket | `2086` | OpenVPN payload over HTTP WS |
| **WireGuard** | Direct UDP | `51820` | Kernel / wg-quick interface `wg0` |
| **L2TP / IPsec** | UDP (StrongSwan / xl2tpd) | `500` (IKE), `4500` (NAT-T), `1701` (L2TP) | Distribution package stack |
| **NoobzVPN** | TCP (Non-SSL & SSL) | `8080` (TCP), `8443` (SSL) | Dual-mode TCP tunnel service |
| **SlowDNS (DNSTT)** | UDP / DNS tunnel | `53` (redirected to `5300` / `530`) | Requires NS domain record |
| **UDP Custom** | Custom UDP payload | `1-65535` | UDP custom tunnel binary |
| **UDP Request** | UDP request mode | `1-65535` | UDP request daemon |
| **BadVPN / UDPGW** | UDP forwarding | `7300` | VoIP and gaming UDP support for SSH |
| **Cloudflare Argo** | Tunnel daemon | Dynamic outbound | Ingress routes to `localhost:80` & `2080` |

---

## Bugs Fixed

- **Delimiters & Title Clean-up**: Eliminated awkward `<=[ ... ]=>`, `[ <= ... => ]`, and `<= ... =>` styling across all menus, submenus, account creation prompts, and result cards.
- **TUI & Database Log Styling**: Standardized menu layouts across both Full and Lite variants with rainbow outer borders (`====`), blue inner dividers (`----`), and green numbered options (`1.`).
- **Database Log Output**: Fixed account database viewers (`log-database-xray-*`, `log-acc-ssh`) to always display credentials in the terminal when Telegram bot is unconfigured. Formatted terminal output with styled color cards while delivering escape-code-free text to Telegram.
- **Libreswan Crash on Debian 11/12**: Replaced failing legacy Libreswan 3.32 compilation with native distribution packages (`strongswan` + `xl2tpd`), preventing runtime NSS assertion crashes.
- **Automated SSL Fallback & HAProxy Sync**: Implemented automated fallback to ZeroSSL and self-signed certificates when hitting Let's Encrypt 429 rate limits, synchronizing `/etc/haproxy/funny.pem` to prevent Nginx and HAProxy startup crashes.
- **Fastly CDN Dependency Mirroring**: Relocated large binary installer assets (Go toolchain, V2Ray, UDP Custom, UDP Request) from raw GitHub to Fastly CDN releases (`v1.23`), eliminating 40 KB/s transfer throttling.
- **Minimal OS Bootstrap**: Added `curl` and `wget` fallback logic in `install.sh` and automatic Debian mirror configuration on stripped OS images.
- **WireGuard Duplicate Interface Overwrites**: Changed `/etc/wireguard/wg0.conf` creation from appending (`>>`) to overwriting (`>`), eliminating interface collision errors (`RTNETLINK answers: File exists`) on reinstallation.
- **Menu English Phrasing**: Fixed awkward translations, broken grammar, and Indonesian loanwords across all 16 Full and Lite menu scripts.
- **Missing Commands & Script Errors**: Replaced invalid `cls` calls with `clear`, corrected `noobzvpns` CLI invocations, and guarded service kill routines.

---

## Known Bugs (Unfixed)

The following upstream quirks and limitations are documented and remain open:

1. **Stale GitHub Hosts Entry**: `installer/v2ray.sh` writes `199.232.68.133 raw.githubusercontent.com` to `/etc/hosts`. While operational in most regions, this hardcoded IP may fail if Fastly rotates edge IPs.
2. **SlowDNS Startup Status**: `dnstt.service` enters an inactive/failed state immediately after installation until the operator configures a nameserver domain and keypair via `menu-dnstt`.
3. **Fail2ban SSH Log Detection**: `fail2ban.service` may report a missing auth log on minimal Debian systems that do not create `/var/log/auth.log` prior to the first SSH authentication attempt.
4. **SplitHTTP Nginx Compatibility**: SplitHTTP over HTTP/2 reverse-proxy setups may produce protocol mismatches with certain client implementations that expect pure HTTP/1.1 chunked transport.
5. **UDP Request Broad SNAT Routing**: `udp-request -mode=system` inserts a top-priority `10.0.0.0/8` SNAT rule. A dedicated `RETURN` rule preserves host management, but client traffic routing through overlapping private subnets requires manual exclusion.
6. **Hardcoded Telegram Bot Token**: `installer/full.sh` and `installer/lite.sh` contain a default bot token. Operators should replace it via `menu-bot` after installation.
7. **Hardcoded WhatsApp Number**: `installer/ssh.sh` SSH issue banner contains a placeholder WhatsApp number.
8. **BadVPN/UDPGW Not Installed**: SSH account cards reference BadVPN/UDPGW port 7300, but the service binary is not installed by the current installer.

---

## Account & Log File Paths

### Account Creation Logs

Stored as plain text when an account is created (add or trial). The Go database log viewers read these files and format them with ANSI colors for terminal display.

| Protocol | Log Directory | File Pattern |
| :--- | :--- | :--- |
| VMess / VLESS / Trojan **WebSocket** | `/var/log/create/xray/ws/` | `{username}.log` |
| VMess / VLESS / Trojan **HTTP Upgrade** | `/var/log/create/xray/http/` | `{username}.log` |
| VMess / VLESS / Trojan **SplitHTTP** | `/var/log/create/xray/split/` | `{username}.log` |
| VMess / VLESS / Trojan **gRPC** | `/var/log/create/xray/grpc/` | `{username}.log` |
| **SSH** | `/var/log/create/ssh/` | `{username}.log` |

Locked accounts are renamed from `.log` to `.locked` in the same directory.

### Xray / V2Ray Runtime Logs

| Service | Log File | Used By |
| :--- | :--- | :--- |
| V2Ray (WS) | `/var/log/v2ray/access.log` | `cek-xray-ws` |
| Xray HTTP Upgrade | `/var/log/xray/upgrade.log` | `cek-xray-http` |
| Xray SplitHTTP | `/var/log/xray/split.log` | `cek-xray-split` |
| Xray gRPC | `/var/log/xray/grpc.log` | `cek-xray-grpc` |

### Xray / V2Ray Config Files

| Service | Config File |
| :--- | :--- |
| V2Ray (WS) | `/etc/v2ray/config.json` |
| Xray HTTP Upgrade | `/etc/xray/json/http.json` |
| Xray SplitHTTP | `/etc/xray/json/split.json` |
| Xray gRPC | `/etc/xray/json/grpc.json` |

### Quota & IP Limit Files

| Protocol | Quota Directory | IP Limit Directory |
| :--- | :--- | :--- |
| WebSocket | `/etc/xray/quota/ws/` | `/etc/xray/limit/ip/xray/ws/` |
| HTTP Upgrade | `/etc/xray/quota/http/` | `/etc/xray/limit/ip/xray/http/` |
| SplitHTTP | `/etc/xray/quota/split/` | `/etc/xray/limit/ip/xray/split/` |
| gRPC | `/etc/xray/quota/grpc/` | `/etc/xray/limit/ip/xray/grpc/` |

Quota files: `{username}` (limit in bytes), `{username}_usage` (current usage in bytes).
IP limit files: `{username}` (max concurrent IPs as integer).

### Go Binaries (Database Viewers & Checkers)

| Binary | Source | Function |
| :--- | :--- | :--- |
| `log-database-xray-ws` | `log-database-xray-ws.go` | View WS account logs with styled terminal output |
| `log-database-xray-http` | `log-database-xray-http.go` | View HTTP Upgrade account logs |
| `log-database-xray-split` | `log-database-xray-split.go` | View SplitHTTP account logs |
| `log-database-xray-grpc` | `log-database-xray-grpc.go` | View gRPC account logs |
| `log-acc-ssh` | `log-acc-ssh.go` | View SSH account logs |
| `cek-xray-ws` | `cek-xray-ws.go` | WS account status (quota, IP limit, protocol) |
| `cek-xray-http` | `cek-xray-http.go` | HTTP Upgrade account status (IP login, traffic, quota) |
| `cek-xray-split` | `cek-xray-split.go` | SplitHTTP account status (IP login, traffic, quota) |
| `cek-xray-grpc` | `cek-xray-grpc.go` | gRPC account status (IP login, traffic, quota) |
| `limit-ip` | `limit-ip.go` | SSH IP limiter daemon |
| `delete-ssh` | `delete-ssh.go` | Delete SSH accounts and their logs |
| `extend-ssh` | `extend-ssh.go` | Extend SSH account expiry |
| `list-ssh` | `list-ssh.go` | List SSH accounts from `/etc/passwd` |
| `pwd-ssh` | `pwd-ssh.go` | Show SSH account passwords |
| `change-limit-ip-ws` | `change-limit-ip-ws.go` | Change WS account IP limit |
| `change-limit-ip-http` | `change-limit-ip-http.go` | Change HTTP Upgrade account IP limit |
| `change-limit-ip-split` | `change-limit-ip-split.go` | Change SplitHTTP account IP limit |
| `change-limit-ip-grpc` | `change-limit-ip-grpc.go` | Change gRPC account IP limit |

### Transport Paths (Client ↔ Server)

Each protocol uses specific URL paths for WebSocket, HTTP Upgrade, SplitHTTP, or gRPC service names. Client links must match server config paths exactly.

Clients connect to **port 443** (TLS) or **port 80** (NoneTLS) — or [Cloudflare-compatible alternatives](#protocols-connections--ports). Nginx matches the path and forwards internally to the V2Ray/Xray backend.

| Protocol | Transport | TLS Path | NoneTLS Path | Internal Backend | Config File |
| :--- | :--- | :--- | :--- | :--- | :--- |
| VMess WS | WebSocket | `/vmess` | `/worryfree` | `127.0.0.1:23456` / `:95` | `/etc/v2ray/config.json` |
| VLESS WS | WebSocket | `/vless` | `/vless` | `127.0.0.1:14016` | `/etc/v2ray/config.json` |
| Trojan WS | WebSocket | `/trojanws` | `/trojanws` | `127.0.0.1:25432` | `/etc/v2ray/config.json` |
| VMess HTTP Upgrade | HTTPUpgrade | `/rere` | `/rere` | `127.0.0.1:8001` | `/etc/xray/json/upgrade.json` |
| VLESS HTTP Upgrade | HTTPUpgrade | `/imam` | `/imam` | `127.0.0.1:8003` | `/etc/xray/json/upgrade.json` |
| Trojan HTTP Upgrade | HTTPUpgrade | `/luqito` | `/luqito` | `127.0.0.1:8002` | `/etc/xray/json/upgrade.json` |
| VMess SplitHTTP | SplitHTTP | `/splitvm` | `/splitvm` | `127.0.0.1:2019` | `/etc/xray/json/split.json` |
| VLESS SplitHTTP | SplitHTTP | `/splitvl` | `/splitvl` | `127.0.0.1:2023` | `/etc/xray/json/split.json` |
| Trojan SplitHTTP | SplitHTTP | `/splittr` | `/splittr` | `127.0.0.1:2020` | `/etc/xray/json/split.json` |
| VMess gRPC | gRPC | `vmess-grpc` | — | `127.0.0.1:31234` | `/etc/xray/json/grpc.json` |
| VLESS gRPC | gRPC | `vless-grpc` | — | `127.0.0.1:24456` | `/etc/xray/json/grpc.json` |
| Trojan gRPC | gRPC | `trojan-grpc` | — | `127.0.0.1:33456` | `/etc/xray/json/grpc.json` |

Internal backends are localhost-only — never exposed to the internet. Nginx routes by path: `grpc_pass` for gRPC, `proxy_pass` for WebSocket/SplitHTTP, exact `location =` for HTTP Upgrade.

> **Note on arbitrary paths (`/anything`, `/whatever`, `/custom`):** Unmatched paths fall through to Nginx `location /`, which round-robins between **wsEpro (SSH WebSocket, port 2080)** and **VMess WS catch-all (port 977)**. This causes ~50% of VMess connections to hit the wrong backend and fail. Always use the dedicated paths listed above for stable connections.
