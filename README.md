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
4. **Duplicate Lite Installer Step**: `installer/lite.sh` invokes `website/install.sh` twice consecutively during the setup routine.
5. **SplitHTTP Nginx Compatibility**: SplitHTTP over HTTP/2 reverse-proxy setups may produce protocol mismatches with certain client implementations that expect pure HTTP/1.1 chunked transport.
6. **UDP Request Broad SNAT Routing**: `udp-request -mode=system` inserts a top-priority `10.0.0.0/8` SNAT rule. A dedicated `RETURN` rule preserves host management, but client traffic routing through overlapping private subnets requires manual exclusion.
