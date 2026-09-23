# Bugs Fixed

This file records fixes confirmed in source review or live testing.

## TUI Restyle Regressions and Menu Bugs (fixed after KVM end-to-end testing)

- `cls` -> `clear` in `bmenu`, `dm-menu`, `menu-argo`, `menu-bot`,
  `menu-dnstt`, `menu-noobz`, `menu-system`, `menu-wg`, `xl2tp`.
- `menu-noobz.sh` now wraps the user-management calls in helpers that detect the
  modern subcommand CLI (`add`/`remove`/`print-all`) and fall back to the legacy
  `--add-user`/`--remove-user`/`--info-all-user` flags.
- `menu-noobz.sh` delete path now uses the `$name` it read instead of `$user`.
- `addssh.sh` telegram helper defaults `TIME` (`local TIME="${TIME:-10}"`) so it
  no longer errors with `curl: option --max-time: expected a proper numerical
  parameter`.
- `installer/vpn.sh` now also publishes `/var/www/html/web/tcp.ovpn` to match
  the `Config OVPN` URL the menu prints.
- `installer/vpn.sh` now uses `unzip -o` to prevent interactive prompt hangs when
  extracting over existing easy-rsa server files.
- `installer/diamond.sh` fixes typo `syste   mctl` -> `systemctl` and guards `pkill ${portd}`.
- `installer/wg.sh` uses `mkdir -p /metavpn/wireguard` so creation succeeds when `/metavpn` is absent.
- `installer/slowdns.sh` exports `/usr/local/go/bin` in environment and shallow-clones GitHub mirror
  fallback for fast and reliable `dnstt-server` compilation.
- `config/{4,6,dual}.conf` add `proxy_read_timeout`/`proxy_send_timeout`/
  `client_body_timeout` to `location /splitvm` so SplitHTTP uploads no longer
  hit the 12s body timeout.

## `udp-request` SNAT Self-Lockout


- **Commit:** `9ee1bf8`
- Added a higher-priority `RETURN` rule for the VPS management address before
  the broad `10.0.0.0/8` SNAT rule.
- Added `udp-request-fixnet.timer` to reapply the protection periodically.
- Live verification confirmed:

  ```text
  1 RETURN 10.245.234.252 0.0.0.0/0
  2 SNAT   10.0.0.0/8     !10.0.0.0/8 -> <public-ip>
  ```

- VPS internet access remained available while `udp-request` was active.

## `noobzvpns` IPv6 Bind Failure

- **Commit:** `9ee1bf8`
- `installer/noobz.sh` now writes IPv4-only listeners:

  ```text
  local_host = ["0.0.0.0:8080"]
  local_host = ["0.0.0.0:8443"]
  ```

- Live verification showed `noobzvpns.service` active on the IPv4-only VPS.

## Duplicate `fix.sh` Authorization Gate

- **Commit:** `ffc3dd0`
- Decrypted the original shc-wrapped ELF.
- Replaced the runtime `fix/fix.sh` with readable shell source.
- Removed only the separate `rohmatsb-biz/cobaizin` IP check and reboot branch.
- The installer-level authorization check using
  `rohjagad/fn-autosc-auth/izin.txt` remains in place.
- The unmodified decrypted payload is retained at:

  ```text
  fix/fix-decrypted-original.sh
  ```

## Undefined `fix.sh` Sysctl Values

- **Commit:** `ffc3dd0`
- Assigned the values used by the integrated fix:

  ```bash
  NEW_FILE_MAX=1000000
  NF_CONNTRACK_MAX="net.netfilter.nf_conntrack_max = 262144"
  NF_CONNTRACK_TIMEOUT="net.netfilter.nf_conntrack_tcp_timeout_time_wait = 30"
  ```

- Live verification confirmed:

  ```text
  fs.file-max = 1000000
  net.netfilter.nf_conntrack_max = 262144
  net.netfilter.nf_conntrack_tcp_timeout_time_wait = 30
  ```

## NoobzVPN Hosting URL

- Updated the binary URL to the available `noobzvpns.x86-64` asset.
- The corrected binary installed successfully on the Debian 12 VPS.

## Xray Version Drift

- **Commit:** `18660ea`
- Pinned Xray to `25.3.6` instead of resolving a moving version dynamically.
- Live verification reported:

  ```text
  Xray 25.3.6
  ```

## Menu Archive Hosting

- Rebuilt `menu/full.zip` and `menu/lite.zip` with the expected extensionless
  runtime filenames.
- Both archives passed `unzip -t` validation.
- Live installation extracted the menu files into `/usr/bin` successfully.

## Repository-Owned Asset URLs

- Rewired project-owned URLs to the `rohjagad` repositories.
- `bot.zip` now resolves from:

  ```text
  https://raw.githubusercontent.com/rohjagad/FN-API/main/bot.zip
  ```

- Live HTTP checks returned `200` for the installer, fix script, reference fix
  script, and `bot.zip`.

## Live Installation Verification

- Fresh Debian 12 installation completed successfully with version `1.23`.
- Confirmed active services included Xray, V2Ray, Nginx, HAProxy, NoobzVPN,
  UDP Custom, UDP Request, Dropbear, L2TP, WireGuard, OpenVPN, and FN-OHP.
- Nginx configuration test passed.
- HAProxy configuration validation passed with warnings.

## Libreswan 3.32 NSS Assertion Crash on Debian 11/12

- **Commits:** `429cee1`
- Libreswan 3.32 compilation from source failed at runtime with an assertion failure: `NSS: AEAD decryption using AES_GCM_16_128 and PK11_Decrypt() failed (SECERR: 2 (0x2))` due to modern libnss3 changes.
- Switched Debian/Ubuntu to use distribution-packaged `strongswan` and `xl2tpd` instead of compiling legacy Libreswan 3.32.
- Verified `strongswan-starter` / `ipsec.service` is active and running cleanly with 0 failed units.

## Automated ACME Fallback (Let's Encrypt 429 Rate Limits) & HAProxy funny.pem Sync

- **Commits:** `55a5032`
- Reinstalls hitting Let's Encrypt weekly rate limits (HTTP 429 "too many certificates already issued") left `/etc/xray/xray.crt` empty, crashing Nginx and HAProxy.
- Updated `installer/diamond.sh`, `full/dm-menu.sh`, and `lite/dm-menu.sh` to automatically fall back to ZeroSSL (`--server zerossl`) and generate a temporary self-signed certificate if all ACME CAs fail.
- Automatically creates and synchronizes `/etc/haproxy/funny.pem` from `/etc/xray/xray.crt` and `/etc/xray/xray.key`.
- Verified Nginx and HAProxy boot cleanly with zero SSL errors.

## Fastly CDN Release URLs for Large Binary Dependencies

- **Commits:** `fa21a0e`
- Raw GitHub URLs (`raw.githubusercontent.com`) heavily throttle blobs larger than 50MB, causing Go (`go1.22.0.linux-amd64.tar.gz`, 66MB) to download at <35 KB/s (~15-20 min installer stalls).
- Hosted large assets in `rohjagad/fn-autosc-miscellaneous` GitHub Release `v1.23` backed by Fastly CDN, restoring download speeds to 12+ MB/s (~4 seconds).
- Extended Fastly CDN release hosting to `v2ray-linux-64.zip` (16MB), `udp-custom-linux-amd64` (4.6MB), and `udp-request-linux-amd64` (5.6MB) (`36c1588`, `d4ddb33`), eliminating raw GitHub 40 KB/s throttling stalls across all sub-installers.

## Minimal OS Bootstrap & `install.sh` Fetch Resiliency

- **Commits:** `b642e40`, `cb8ae69`
- On minimal Debian reinstalls lacking `wget`, running `bash <(curl ... install.sh)` failed immediately with `wget: command not found` when trying to fetch `full.sh`/`lite.sh`.
- Updated `install.sh` to use `curl -fsSL || wget -q` fallback and auto-populate standard `deb.debian.org` mirrors if only Freexian ELTS sources are present.

## WireGuard Overwrite Fix on Reinstall / Rerun

- **Commits:** `023efe1`
- `installer/wg.sh` appended configuration with `>> /etc/wireguard/wg0.conf` instead of overwriting, causing repeated runs to have duplicate `[Interface]` blocks. `wg-quick` failed with `RTNETLINK answers: File exists` when attempting to bind the same IP twice.
- Changed to overwrite `> /etc/wireguard/wg0.conf` and stop existing `wg-quick@wg0` beforehand. Verified WireGuard starts cleanly.

## Menu TUI English Phrasing and Grammar Fixes

- Corrected awkward Indonesian-English translations, grammatical errors, and misspellings across all 16 TUI menus in both `full/` and `lite/` while keeping wording concise and punchy.
- Replaced Indonesian loanwords and broken phrasing (e.g. `Cek User Login` -> `Check Online Users`, `Extend Expired SSH` -> `Extend SSH Account`, `Extending Account L2TP Active Life` -> `Extend L2TP Account`, `Locked Account WebSocket` -> `Lock WS Account`, `Your IP doesn’t have on database` -> `Your IP is not in the database`).
- Standardized menu headers, alignment, and options across SSH, XTLS (WS, HTTP, Split, gRPC), WireGuard, L2TP, NoobzVPN, SlowDNS, Argo Tunnel, Telegram Bot, Backup, Domain, and System menus.
- Rebuilt `menu/full.zip` and `menu/lite.zip` with updated menu executables.

## Account Database Log Display & Telegram Notification

- In `log-database-xray-*` and `log-acc-ssh`, checking an account log aborted immediately with `Error reading chat ID: open /etc/funny/.chatid: no such file or directory` if the Telegram bot had not been set up, preventing the account details from displaying in the terminal.
- Reordered logic to always display the log details in the terminal immediately.
- Added graceful check for `/etc/funny/.chatid` and `/etc/funny/.keybot`: if configured with non-empty credentials, the log is also posted to the Telegram bot via URL-encoded form POST with a 5-second timeout, avoiding blocking or terminal mangling.
- Recompiled Go binaries for `log-database-xray-ws`, `log-database-xray-http`, `log-database-xray-split`, `log-database-xray-grpc`, and `log-acc-ssh`, and updated `menu/full.zip` and `menu/lite.zip`.

## Menu Title and Banner Stylization Clean-up

- Removed awkward `<=[ ... ]=>`, `[ <= ... => ]`, and `<= ... =>` styling from all menu titles, submenus, account creation prompts, and account cards across both `full/` and `lite/`.
- Updated menus including `lite/menu.sh`, `lite/x-*.sh`, `menu-argo.sh`, `menu-bot.sh`, `locked-xray-*.sh`, `unlock-*.sh`, `menu-system.sh`, `addssh.sh`, `trial-ssh.sh`, `add-*.sh`, and `trial-*.sh`.
- Rebuilt `menu/full.zip` and `menu/lite.zip` with 0755 executable permissions and deployed to the test VPS.

## Menu & Database Log Output Styling Standardization

- Standardized all menus and submenus across `lite/` and `full/` to match the main menu style: outer line separators use rainbow `===================================`, inner section separators use blue `-----------------------------------`, and numbering uses green `${green}1${NC}.`.
- Updated database account log viewers (`log-database-xray-ws`, `log-database-xray-http`, `log-database-xray-split`, `log-database-xray-grpc`, and `log-acc-ssh`) in Go:
  - Account selection list renders with green numbering, blue inner dividers, and rainbow outer borders.
  - Dynamically formats rendered account logs with rainbow top/bottom outer lines, blue inner section dividers, purple section headers, and green values for terminal display, while preserving clean escape-code-free text when sent to Telegram.
- Synchronized unstyled `lite/` menus (`x-*.sh`, `bmenu.sh`, `dm-menu.sh`, `menu-bot.sh`, `menu-argo.sh`, `menu-system.sh`) with their styled versions.
- Recompiled all 5 Go binaries and rebuilt `menu/full.zip` and `menu/lite.zip`.

## Comprehensive Bug Sweep (14 bugs fixed)

Full codebase audit cross-referenced with original script archive, verified on
clean Debian 11 reinstall pulling only from GitHub `origin/main`.

### Critical / High

1. **`apt insfall` typo** → `apt install` in `installer/v2ray.sh:62`. Unzip may not install on minimal images.
2. **`systemctl resrart` typo** → `systemctl restart` in `full/restore-ftp.sh:89` and `lite/restore-ftp.sh:89`. xray@split never restarted after restore.
3. **IPv4/IPv6 variable swap** — `ip6` fetched `ipv4.icanhazip.com` and vice versa. Fixed in `full/bmenu.sh` (×3), `lite/bmenu.sh` (×3), `full/restore-ftp.sh`, `lite/restore-ftp.sh`, `website/restore-ftp.sh`.
4. **`strpos()` missing argument** — `website/upload.php:24` called `strpos("SUCCESSFULL...")` with one arg. Fixed to `strpos($output, "SUCCESSFULL...")`.
5. **`cp -r creare` typo** → `cp -r create` in `website/restore-ftp.sh`. Log database not restored.
6. **Duplicate restore block** — `website/restore-ftp.sh` ran the entire restore twice. Removed the dead second block.
7. **`rm ws.json` before backup** — `full/backup.sh:66` and `lite/backup.sh:66` deleted `ws.json` before copying. Removed the premature delete.
8. **OpenVPN UDP client port** — `installer/vpn.sh:130` used Squid port `3128` instead of OpenVPN UDP port `2200`.

### Medium

9. **Undefined `$ANU` variable** — `installer/vpn.sh:72` and `installer/wg.sh:135` used `$ANU` in command substitution before defining it. Removed the stale reference.
10. **Duplicate website install (Lite)** — `installer/lite.sh` downloaded and ran `website/install.sh` twice consecutively. Removed the second copy.
11. **Indonesian user-facing text** — Translated remaining strings (`Gagal mengunduh`, `Tanggal kadaluwarsa`, `Izin telah kadaluwarsa`, `Tengah Melakukan Backup Data`, `melanjutkan proses`, `Script Anda Berhasil Diperbaiki`) to English across all scripts.
12. **`time.Sleep(1)` nanosecond** — `full/limit-ip.go:41` slept 1ns instead of 1s. Fixed to `time.Sleep(1 * time.Second)`.
13. **Node.js 16 EOL** — `installer/package.sh` referenced `setup_16.x`. Updated to `setup_20.x` (Node 20 LTS).
14. **Typos in user-facing strings** — `INSTALL SUCCES` → `INSTALL SUCCESS`, `Hostibg` → `Hosting`.

### Verification

- Fresh Debian 11 installed via `rohjagad/reinstall`.
- Script installed from GitHub (`curl -fsSL .../install.sh`), not from local.
- **0 failed systemd units** after installation (SlowDNS configured with `slowdns.rohcuan.dpdns.org`).
- All 19 core services active: SSH, Nginx, V2Ray, Xray (×3), HAProxy, WireGuard, NoobzVPN, StrongSwan, xl2tpd, UDP Custom, UDP Request, SlowDNS, Cron, OpenVPN, WS, Squid, Apache2.
- SSL certificate valid for `fntest.rohcuan.dpdns.org`.

## Not Fixed Yet

The following findings remain open and are documented rather than silently
changed:

- Stale `199.232.68.133 raw.githubusercontent.com` entry in `installer/v2ray.sh`.
- Fail2ban failure caused by missing SSH log input on minimal Debian.
- Hardcoded Telegram bot token in `installer/full.sh` and `installer/lite.sh`.
- Hardcoded WhatsApp number in SSH issue banner (`installer/ssh.sh`).
- `chmod +x *` in `/usr/bin` during menu install sets execute on all files.
- BadVPN/UDPGW referenced in SSH account cards but never installed.

## VPS Live Audit & Bug Fix Cycle (September 2026)

### Verified & Resolved Issues

1. **Fatal Bash Syntax Error in `menu-system.sh`** (`full/menu-system.sh`, `lite/menu-system.sh`)
   - Removed stray standalone double-quote on line 609 inside `rocky()` function that swallowed commands into an unclosed string.

2. **Missing Functions & Invalid `chmod`**
   - Removed non-existent `typer` call and corresponding menu option in `full/menu-dnstt.sh:182`.
   - Removed non-existent `reres` calls and corresponding menu options in `full/menu-argo.sh:229` and `lite/menu-argo.sh:229`.
   - Added missing permission mode: `chmod /usr/bin/warp.sh` -> `chmod +x /usr/bin/warp.sh` in `full/menu-system.sh:185`.

3. **Obsolete Debian 12 Package Names** (`installer/package.sh`, `installer/slowdns.sh`)
   - Replaced obsolete `python` with `python3` in `package.sh:13` and `slowdns.sh:59`.
   - Replaced obsolete `squid3` with `squid` in `package.sh:78`.

4. **IPv6 Breaking License & IP Authorization** (Global across 195+ scripts)
   - Replaced all `curl -s ifconfig.me` and `curl ifconfig.me` calls with `curl -4 -s ifconfig.me` and `curl -4 ifconfig.me` to guarantee IPv4 address retrieval on dual-stack hosts.

5. **Stale Fastly IP `/etc/hosts` Override** (`installer/v2ray.sh`)
   - Removed obsolete block writing hardcoded `199.232.68.133 raw.githubusercontent.com` to `/etc/hosts`.

6. **SlowDNS Port Redirection Collision** (`installer/slowdns.sh`)
   - Fixed typo in duplicate iptables PREROUTING rule: redirected port `530` -> `5300`.

7. **HAProxy Never Started or Enabled** (`installer/stunnel5.sh`)
   - Added `systemctl enable haproxy` and `systemctl start haproxy` prior to installer script cleanup.

8. **Web Restore Apache VirtualHost Never Enabled** (`website/install.sh`)
   - Added `a2dissite 000-default` and `a2ensite upload` before restarting Apache2.

9. **Dangerous Wildcard Script Deletion** (`installer/noobz.sh`)
   - Removed destructive `rm -f /root/*.sh` line.

10. **NoobzVPN Database Deletion Sed Over-Match** (`full/menu-noobz.sh`)
    - Changed sed range deletion `/^### $name $exp/,/^},{/d` (which deleted to EOF) to single-line deletion `/^### $name $exp/d`.

11. **Account Lock Script Inversion & Variable Bug** (8 files across `full/` and `lite/`)
    - Removed duplicate re-add code from `locked-xray-{ws,grpc,http,split}.sh`.
    - Fixed undefined `$user` variable to `$name` in sed deletion command.

12. **`xp.sh` Expiration Multi-Failure** (`full/xp.sh`, `lite/xp.sh`)
    - Replaced undefined `$today` with `$now` in WireGuard expiration block.
    - Added file guard `if [[ -f /etc/funny/.wireguard ]]` to prevent stdin read errors.
    - Fixed L2TP date check from exact `[[ "$exp2" = "0" ]]` to `[[ "$exp2" -le "0" ]]`.
    - Fixed service name typo `xl2tp` -> `xl2tpd`.
    - Removed username space-padding loop and fixed Telegram notification variable `$username` -> `$user`.
    - Corrected Telegram bot token and chat ID paths from `/etc/noobzvpns/` to `/etc/funny/`.

13. **Extend Script Log Regex Mismatch** (8 files across `full/` and `lite/`)
    - Changed sed pattern from `Expired: $exp` to `Expired : $exp` in `extend-{ws,http,split,grpc}.sh` to match the spacing format generated by account creation scripts.

14. **Non-Existent Service Restarts** (Multiple files across `full/`, `lite/`, `website/`)
    - Replaced `systemctl restart xray@http` with `systemctl restart xray@upgrade`.
    - Replaced `systemctl restart xray@ws` with `systemctl restart v2ray`.

15. **Incomplete Backup Restore** (`full/restore-ftp.sh`, `lite/restore-ftp.sh`, `website/restore-ftp.sh`)
    - Added missing restorations: `cp -r v2ray /etc/` and `cp crontab /etc/`.

16. **Nginx Upstream Protocol Mismatch** (`config/4.conf`, `config/6.conf`, `config/dual.conf`)
    - Removed incompatible port 977 (Vmess) from `upstream default_backend`, retaining only port 2080 (SSH WebSocket).

17. **Deprecated Cloudflare Warp Registration Endpoint** (`full/menu-wg.sh`)
    - Updated Warp API endpoint from `v0a737` to `v0a2169`.

18. **Unnecessary Dependency on `strings` Binary** (16 files across `full/` and `lite/`)
    - Removed `| strings` pipe from awk commands in `change-id-*` and `list-xray-*` scripts.

19. **Auth Log Truncation** (`full/limit-ip-ssh.sh`)
    - Commented out destructive `echo "" > /var/log/auth.log` that erased audit trails and broke Fail2ban.

20. **Go UID Check Includes `nobody` User** (`full/delete-ssh.go`, `full/list-ssh.go`)
    - Added upper bound check `&& id < 65534` to prevent system user `nobody` from appearing in user lists or being deleted.

21. **Unattended Installer Debconf Blocking** (`installer/set-br.sh`, `installer/l2tp.sh`, `installer/vpn.sh`, `installer/full.sh`, `installer/lite.sh`)
    - Pre-seeded `msmtp-mta/apparmor boolean false` via `debconf-set-selections` to prevent AppArmor interactive prompt.
    - Pre-seeded `iptables-persistent` autosave selections for IPv4 and IPv6 rules.
    - Exported `DEBIAN_FRONTEND=noninteractive` across main installer flows.

22. **Path Inconsistency for IP File** (`installer/l2tp.sh:83`)
    - Changed `/etc/funny/.ip` to `/etc/.ip` to match canonical output path from `installer/full.sh`.

23. **Path Inconsistency for NoobzVPN Database** (`full/menu-noobz.sh`, `full/xp.sh`, `lite/xp.sh`)
    - Changed `/etc/noobzvpns/.noob` to `/etc/funny/.noob` (10 occurrences) to align with installer initialization path.

24. **Menu Archive Rebuilds with Compiled Go Binaries**
    - Recompiled all Go source files using Go 1.23 with stripped symbols (`-ldflags="-s -w"`).
    - Repacked `menu/full.zip` and `menu/lite.zip` with static ELF executables and shell scripts.

25. **Account Creation JSON Corruption** (All 24 `add-*.sh` scripts in `full/` and `lite/`)
    - Changed sed pattern from `/#marker$/a\...\n},{"key":"val"}` (append-after, producing extra `}`) to `/#marker$/{n;s/}/},\n### user exp\n{"key":"val"}/}` (next-line substitution, producing valid JSON array).
    - Verified: multiple sequential account additions across all protocols/transports produce valid JSON. `v2ray test` and `xray run -test` pass. Services remain active after each addition.

### Live VPS Testing Verification

- **Environment:** Clean Debian 12 Bookworm on KVM VPS (`202.155.17.126`).
- **OS Reinstall:** Performed via `bin456789/reinstall` script.
- **Installer Execution:** Dual-stack IPv4/IPv6, domain `autosc.rohcuan.dpdns.org`, SlowDNS `slowdns.rohcuan.dpdns.org`. Completed unattended with zero interactive prompt pauses.
- **Service Status:** All 18 services active and running:
  - `nginx`, `ssh`, `sshd`, `dropbear`, `ws`, `v2ray`, `xray`, `xray@grpc`, `xray@upgrade`, `xray@split`, `haproxy`, `openvpn`, `wg-quick@wg0`, `noobzvpns`, `dnstt`, `udp-custom`, `xl2tpd`, `ipsec`.
- **TUI Menu:** Verified operational, all protocols reporting status `ON`.
- **Account Creation:** Created VLESS WS, VMESS WS, Trojan WS, and VLESS gRPC accounts. All JSON configs pass `v2ray test` / `xray run -test` after each addition. V2Ray and all Xray instances remain active.
- **Client Connection Test:** Xray client connected via VLESS WS TLS (port 443) through SOCKS5 proxy. `curl http://ifconfig.me` returned VPS IP `202.155.17.126`, confirming end-to-end tunnel functionality.

