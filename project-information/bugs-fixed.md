# Bugs Fixed

> **⚠ APPEND-ONLY:** Do not delete or overwrite existing entries. Always add new content at the very bottom of this file.

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

26. **SlowDNS Nameserver Prompt Delayed** (`installer/full.sh`, `installer/slowdns.sh`)
    - Moved `Your SlowDNS Nameserver` prompt from `slowdns.sh` (runs ~15 min into install) into `full.sh` alongside Domain, Email, and IP Type prompts. Nameserver is saved to `/etc/slowdns/nsdomain` upfront. `slowdns.sh` reads from that file if present, falling back to interactive prompt only when file is missing.

27. **Menu ZIP Files Missing Execute Permissions** (`menu/full.zip`, `menu/lite.zip`)
    - Set `chmod +x` on all files in build directories before running `zip`, so the zips now store files as `755` (`-rwxr-xr-x`). `unzip -o` extracts with correct execute permissions. No more `permission denied` on `menu` or any menu command after installation.

---

## Bugs 28–40: Deep Component Verification Fixes (September 2026)

All fixes live-verified on Debian 12 VPS (`202.155.17.126`) after fresh OS reinstall and full script installation.

28. **Account Deletion Leaves Trailing Commas in JSON** (`full/delete-*.sh`, `lite/delete-*.sh`, `full/kill-*.sh`, `lite/kill-*.sh`, `full/xp.sh`, `lite/xp.sh`, all `trial-*.sh`)
    - After every `sed -i "/### $user $exp/ {N;d}" <config>`, added `sed -i -z 's/},\n *\]/}\n        ]/' <config>` to strip trailing commas before `]`. For trial `at` commands, the cleanup is embedded inside the scheduled echo string.
    - **Verified:** Added 3 users, deleted each one sequentially (middle → first → last). JSON stayed valid at every step. `v2ray test -c /etc/v2ray/config.json` returned `Configuration OK.` after each deletion.

29. **Trial Account Self-Deletion Broken by Unescaped Quotes** (24 `trial-*.sh` in `full/` and `lite/`)
    - Changed outer quoting from `echo "..."` (double quotes with nested unescaped double quotes) to `echo '...'` with proper `'"$var"'` variable splicing.
    - **Verified:** `trial-vless-ws` created trial080 successfully. `atq` shows scheduled job. `at -c <job>` shows correctly formed `sed -i "/### trial080 26-09-24/ {N;d}" ... && sed -i -z 's/...' ...` command.

30. **Trial and Unlock Scripts Use Broken Append Pattern** (24 `trial-*.sh`, 8 `unlock-*.sh` in `full/` and `lite/`)
    - Replaced old `sed -i '/#marker$/a\...'` two-line append with correct `sed -i '/#marker$/{n;s/}/},\n### user exp\n{...}/}'` single-line substitution matching the working `add-*.sh` pattern.
    - **Verified:** After creating trial account, `add-vless-ws` for `postuser` succeeded. Both entries present in config. JSON valid.

31. **`kill-ws.sh` Deletes Unlimited Quota Accounts** (`full/kill-ws.sh`, `lite/kill-ws.sh`)
    - Added guard: `if [[ -f "$log_file" ]]; then return; fi` before the deletion block. Accounts with a creation log but no quota file (unlimited quota) are now skipped.
    - **Verified:** Created account with quota=0, no `/etc/xray/quota/ws/postuser` file existed. Ran `kill-ws`. Account remained in config.

32. **SlowDNS Installer Wipes `/etc/slowdns/nsdomain`** (`installer/slowdns.sh`)
    - Added `local saved_nsdomain` variable that reads `/etc/slowdns/nsdomain` before `rm -rf`, then restores it after `mkdir -p /etc/slowdns/`.
    - **Verified:** After full installation, `cat /etc/slowdns/nsdomain` returns `slowdns.rohcuan.dpdns.org`. `dnstt` service active. No interactive prompt during install.

33. **NoobzVPN Auto-Expiration Deletes Adjacent Accounts** (`full/xp.sh`, `lite/xp.sh`)
    - Changed `sed -i "/### $user $exp/ {N;d}"` (deletes 2 lines) to `sed -i "/^### $user $exp/d"` (single-line records in `.noob`). Changed `noobzvpns --remove-user "$user"` to `noobzvpns remove "$user"`.
    - Also removed duplicate `{N;d}` lines in the V2Ray/Xray sections of `xp.sh` (redundant second pass).
    - **Verified:** `grep "noobzvpns" /usr/bin/xp` shows `noobzvpns remove "$user"`. sed uses single-line `d`.

34. **Crontab `flock` Syntax Runs `xp` Unprotected** (`installer/xray.sh`)
    - Changed `flock -n /tmp/xp.lock sleep 300 && /usr/bin/xp` to `flock -n /tmp/xp.lock /usr/bin/xp`. Removed the pointless 5-minute sleep.
    - **Verified:** `grep xp /etc/crontab` shows `flock -n /tmp/xp.lock /usr/bin/xp`.

35. **Undefined `$TEKS` in Backup Notification** (`full/backup-gd.sh`, `lite/backup-gd.sh`)
    - Moved `opwares` message definition before the Telegram `curl` call and replaced `$TEKS` with `$opwares`.
    - **Verified:** `grep -n "TEKS" /usr/bin/backup-gd` returns nothing. `opwares` is defined at line 108 and used at line 117.

36. **Web-Based Restore Path Mismatch** (`website/install.sh`)
    - Added `wget ... restore-ftp.sh -O /usr/bin/restore-ftp` and `chmod +x /usr/bin/restore-ftp` to `website/install.sh` so the restore script is actually deployed.
    - `website/restore-ftp.sh` already uses the correct `/var/www/uploads/*.zip` path.

37. **`delete-split.sh` Deletes Quota from Wrong Directory** (`full/delete-split.sh`, `lite/delete-split.sh`)
    - Changed `rm -f /etc/xray/quota/ws/$user` to `rm -f /etc/xray/quota/split/$user`.
    - **Verified:** `grep quota /usr/bin/delete-split` shows `/etc/xray/quota/split/$user`.

38. **Missing `qrencode` Package** (`installer/wg.sh`)
    - Added `apt install qrencode -y` to WireGuard installer.
    - **Verified:** `which qrencode` returns `/usr/bin/qrencode` on fresh install.

39. **WireGuard WARP Variables in Single Quotes** (`full/menu-wg.sh`)
    - Changed `'$CLOUDFLAREKEY'` to `"$CLOUDFLAREKEY"` and replaced undefined `'$IPV4':51820` with `engage.cloudflareclient.com:51820`.

40. **`iptables-restore -t` Runs in Test Mode** (`installer/l2tp.sh`, `installer/vpn.sh`)
    - Removed `-t` flag from `iptables-restore` in both files.
    - **Verified:** `iptables -L -n` shows loaded rules (UDP ports 36711, 5300 accepted).

---

## Regression Fixes (September 2026)

All fixes live-verified on Debian 12 VPS (`202.155.17.126`) after deployment of updated `menu/full.zip`.

41. **(Regression Fix) Account Locking Omits Trailing-Comma JSON Cleanup** (`full/locked-xray-*.sh`, `lite/locked-xray-*.sh` — 8 files)
    - Added `sed -i -z 's/},\n *\]/}\n        ]/' <config>` after every `{N;d}` deletion in all 8 `locked-xray-*.sh` scripts. Previously omitted when Bug 28 trailing-comma cleanup was applied to `delete-*.sh`, `kill-*.sh`, `xp.sh`, and `trial-*.sh`.
    - **Verified:** Created `locktest1`, locked via `locked-xray-ws`. `v2ray test -c /etc/v2ray/config.json` returned `Configuration OK.` after lock. Unlocked, re-verified — JSON valid at every step.

42. **(Regression Fix) Duplicate Legacy Output in Lock/Unlock Scripts** (`full/locked-xray-*.sh`, `lite/locked-xray-*.sh`, `full/unlock-*.sh`, `lite/unlock-*.sh` — 16 files)
    - Removed duplicate unstyled `Detail Locked/Unlock X-Ray ...` output blocks and trailing `clear` calls left behind after TUI restyle. Only the styled rainbow-bordered card remains.
    - **Verified:** Lock/unlock terminal output shows single styled card, no stutter or duplication.

43. **(Regression Fix) `extend-ws.sh` Reads Obsolete `/etc/xray/json/ws.json`** (`full/extend-ws.sh`, `lite/extend-ws.sh`)
    - Replaced all 4 occurrences of `/etc/xray/json/ws.json` with `/etc/v2ray/config.json` to match Bug 14's V2Ray migration.
    - **Verified:** `extend-ws` found `locktest1` in `/etc/v2ray/config.json` and extended expiration from `26-09-23` to `26-09-28`.

44. **(Regression Fix) `lite/list-xray-ws.sh` Reads Dead Config Path** (`lite/list-xray-ws.sh`)
    - Changed `/etc/xray/json/ws.json` to `/etc/v2ray/config.json` at line 110 to match `full/list-xray-ws.sh`.

45. **(Regression Fix) `quota-*.sh` Daemons Omit Trailing-Comma Cleanup** (`full/quota-*.sh`, `lite/quota-*.sh` — 8 files)
    - Added `sed -i -z 's/},\n *\]/}\n        ]/' <config>` after every `{N;d}` deletion in all 8 quota daemon scripts. Previously omitted when Bug 28 was applied.

46. **(Regression Fix) `quota-*.sh` Daemons Crash on Unlimited-Quota Accounts** (`full/quota-*.sh`, `lite/quota-*.sh` — 8 files)
    - Wrapped `quota_limit=$(cat "$quota_file")` and its comparison block inside `if [[ -f "$quota_file" ]]; then ... fi` guard. Unlimited accounts (Quota = 0) never create quota files, causing `cat` errors and `bc` arithmetic failures every 30 seconds.

47. **(Regression Fix) `limit-ip-ssh.sh` Still Truncates `/var/log/auth.log`** (`full/limit-ip-ssh.sh`)
    - Commented out line 216 `echo "" > ${LOG}` which was missed when Bug 19 commented out line 214. The `${LOG}` variable points to `/var/log/auth.log`.
    - **Verified:** Ran `limit-ip-ssh` on VPS with 43 lines in auth.log; line count unchanged afterward (was truncated to 1 before fix).

48. **(Regression Fix) HAProxy Started With Default Config, Never Reloads** (`installer/stunnel5.sh`)
    - Changed `systemctl start haproxy` to `systemctl restart haproxy`. On Debian 12, `apt install haproxy` auto-starts the service with default config; subsequent `start` is a no-op and port 777 never binds.
    - **Verified:** After restart, `ss -tlpn | grep 777` shows `0.0.0.0:777` bound by haproxy.

49. **(Regression Fix) Installer Telegram Notification Drops on Dual-Stack** (`installer/full.sh`, `installer/lite.sh`)
    - Added `-4` flag to `curl` Telegram notification calls. On dual-stack hosts, `api.telegram.org` resolves IPv6 first; with `--max-time 10`, IPv6 timeout silently drops the notification before IPv4 fallback.

50. **(Regression Fix) `vpn.sh` Destructive Wildcard Deletion Mid-Install** (`installer/vpn.sh`)
    - Commented out `history -c`, `rm -f /root/*.sh`, `rm -f /root/install`, `rm -f /root/*install*` at end of `vpn.sh`. These ran at step 6 of the 14-step installer, destroying subsequent installer scripts and logs.

51. **(Regression Fix) `restore-ftp.sh` Path Conflict Between Web and CLI** (`full/restore-ftp.sh`, `lite/restore-ftp.sh`, `website/restore-ftp.sh`)
    - Replaced single-source `mv` with dual-source check: tries `/var/www/uploads/*.zip` first, then falls back to `/root/*backup*.zip`. Both web upload and CLI backup restore paths now work regardless of which `restore-ftp` was installed last.

---

## Bugs 52–61: Post-Fresh-Install System Audit Fixes (September 2026)

All fixes live-verified on Debian 12 VPS (`202.155.17.126`) after fresh OS reinstall and full script installation.

52. **`xp.sh` SSH Expiration Leaves Ghost Logs and Uses Undefined Variables** (`full/xp.sh`, `lite/xp.sh`)
    - Added `rm -f /var/log/create/ssh/${username}.log` upon SSH account expiration so deleted accounts no longer haunt `log-acc-ssh` and `pwd-ssh`.
    - Defined `exp="$tgl $bulantahun"` in the SSH loop so Telegram expiration notifications display the valid date.
    - Corrected cleanup from `rm -rf /etc/funny/limit/ssh/ip/$user` (undefined variable and wrong directory) to `rm -f /etc/xray/limit/ip/ssh/$username`.
    - **Verified:** Created expired SSH user `testexp52`, verified user was deleted, log file removed, and limit file deleted on VPS.

53. **`trial-ssh.sh` Scheduled Expiration Leaves Orphaned Database Logs** (`full/trial-ssh.sh`)
    - Updated `schedule_user_expiration()` to execute `pkill -u $username; userdel -f $username; rm -f /var/log/create/ssh/${username}.log /etc/xray/limit/ip/ssh/${username}` via `at`.
    - **Verified:** Created trial SSH user `trial194`. Confirmed scheduled `at` job contains the complete log and limit cleanup command.

54. **Domain Update in `dm-menu.sh` Uses Single Quotes, Corrupts cert2 Keys, and Misses gRPC** (`full/dm-menu.sh`, `lite/dm-menu.sh`)
    - Changed single quotes to double quotes: `sed -i "s|${old_domain}|${host}|g"` so bash properly interpolates domain variables into user logs.
    - Added `/var/log/create/xray/grpc/*` and removed duplicated `split` line.
    - In `cert2()`, changed `cat ... >> /etc/xray/xray.key` to overwrite `>` and added `/etc/haproxy/funny.pem` renewal.

55. **"Restart All Services" in `menu-system.sh` Misses 12 Core Services** (`full/menu-system.sh`, `lite/menu-system.sh`)
    - Updated `resall()` to restart all 20 running services: added `dropbear`, `haproxy`, `openvpn`, `wg-quick@wg0`, `noobzvpns`, `dnstt`, `udp-custom`, `udp-request`, `xl2tpd`, `ipsec`, `fn-ohp`, `opn`.
    - **Verified:** Ran option 2 in `menu-system`; verified all 20 services restarted cleanly and remained active.

56. **OS Reinstall Menu Prompt Variable Mismatch** (`full/menu-system.sh`)
    - Changed `elif [[ $ip_version == "n" ]]; then` to `elif [[ $osw == "n" ]]; then` so entering `n` exits immediately.

57. **`udp.sh` Installer Deletes Itself Mid-Execution** (`installer/udp.sh`)
    - Changed `rm -fr /root/udp*` to `rm -fr /root/udp-custom` to prevent unlinking the executing script `/root/udp.sh`.

58. **Backup and Restore Omit Non-Xray VPN Services** (`full/backup.sh`, `lite/backup.sh`, `full/bmenu.sh`, `lite/bmenu.sh`, `full/backup-gd.sh`, `full/restore-ftp.sh`, `lite/restore-ftp.sh`, `website/restore-ftp.sh`)
    - Added `/etc/wireguard`, `/etc/slowdns`, `/etc/noobzvpns`, `/etc/ppp`, `/etc/ipsec.d`, and `/etc/ipsec.secrets` to all backup generation and restore functions.

59. **`auto-delete-*.sh` Daemons Omit Deleting Quota Usage Files** (`full/auto-delete-*.sh`, `lite/auto-delete-*.sh` — 8 files)
    - Changed `rm -f /etc/xray/quota/<proto>/$user` to wildcard `$user*` to remove both quota limit and `_usage` files.

60. **SlowDNS Menu Missing Public Key and Connection Details** (`full/menu-dnstt.sh`)
    - Added option 4 "View SlowDNS Information & Keys" to display the configured nameserver, server public key (`/etc/slowdns/server.pub`), target port (5300), and running status.

61. **OpenVPN Generic `dev tun` Collides with `udp-request` TUN Requirement** (`installer/vpn.sh`)
    - Explicitly set `dev tun2` for TCP 1194 and `dev tun3` for UDP 2200 in OpenVPN server configurations, leaving `tun0` available for `udp-request`.
    - **Verified:** Confirmed `tun0` (udp-request), `tun2` (openvpn TCP), and `tun3` (openvpn UDP) all active and operating simultaneously without collisions.


## Live Audit Cycle 4: Focus-Area Fixes (Bugs 62–71)

62. **Change-Limit-IP Tools Never Update the On-Disk Limit File** (`full/change-limit-ip-{ws,grpc,http,split}.go`, `lite/change-limit-ip-{ws,grpc,http,split}.go`, `full/limit-ip.go`)
    - Added `updateLimitFile()` (`path/filepath`, `mkdir -p`) to all 8 Go tools so every limit change also writes `/etc/xray/limit/ip/xray/<proto>/<user>`, and added `isNumeric` validation so non-numeric input is rejected; `full/limit-ip.go` now rejects non-numeric limits as well.
    - **Verified:** Live on Debian 12 VPS — change limit 2 → 5 updated both the log (`Limit IP: 5`) and `/etc/xray/limit/ip/xray/ws/testvm2` (`5`).

63. **Deleting a VMess Account Leaves Trailing Commas and Crash-Loops V2Ray** (~34 scripts in `full/` and `lite/`)
    - Added the `g` flag to every `sed -i -z 's/},\n *\]/}\n        ]/'` fix-up (64 sites), so all four VMess inbounds are repaired in one pass.
    - **Verified:** Live on Debian 12 VPS — vmess delete with 4 markers left `JSON_OK` and `v2ray active`; lock → unlock cycle kept `JSON_OK` and `active` both directions.

64. **SSH IP-Limit Enrollment Uses GID Instead of UID** (`full/limit-ip-ssh.sh`)
    - Changed the enrollment parse to `read -r username _ uid _ _ _ _` with `uid >= 1000 && uid < 65534` (plus `nobody`/`root` exclusions), added cleanup of stale limit files for no-longer-enrolled accounts, switched login matching to field-exact `grep -F " - $user - "`, and made non-numeric limit files fall back to `2`.
    - **Verified:** Live on Debian 12 VPS — limit files for `sync`/`_apt`/`sshd`/`strongswan` removed; only real accounts (`banyan`, `kvs1`, `kvs2`) remain.

65. **Lite OS-Reinstall Menu Prompt Tests the Wrong Variable** (`lite/menu-system.sh`)
    - Changed `elif [[ $ip_version == "n" ]]` to `elif [[ $osw == "n" ]]` so `n` exits immediately.
    - **Verified:** `bash -n` clean; variable now matches the read prompt.

66. **`xp.sh` Wildcard Deletion Cross-Destroys Longer Usernames** (`full/xp.sh`, `lite/xp.sh`)
    - Replaced all 8 `$user*` prefix globs with exact `$user` + `${user}_usage` path pairs.
    - **Verified:** Live on Debian 12 VPS — expiring `xpw1` removed its log/quota/config marker while `xpw10`'s quota, log, and config marker survived.

67. **Menu Delete Scripts Leave `${user}_usage` Orphaned** (`full/delete-*.sh`, `lite/delete-*.sh` — 8 files)
    - Added `rm -f .../${user}_usage` alongside the existing quota-limit removal.
    - **Verified:** Live on Debian 12 VPS — deleting `testvm2` removed both `testvm2` and `testvm2_usage`.

68. **IP-Limit Enforcer Deletes the Config From the Marker to End-of-File** (`full/limit-ip-*.sh`, `lite/limit-ip-*.sh` — 8 files)
    - Replaced the broken `/^### $user $exp/,/^},{/d` range (undefined `$exp`, never-matching end pattern) with: `exp` read from the config marker (empty → skip), `sed "/^### $user $exp/ {N;d}"` (removes exactly the marker + client line), and the `/g` trailing-comma fix-up. Added numeric guards: limit must match `^[1-9][0-9]*$` (0/missing = unlimited → skip) and the online count must be numeric.
    - **Verified:** Live on Debian 12 VPS with a stats shim — triggered gRPC limit removed only `tstgrpc`, `grpc.json` stayed `JSON_OK`, `xray@grpc` stayed active.

69. **WS IP-Limit Probe Calls the XRay Stats API on a V2Ray Port** (same 8 `limit-ip-*.sh`)
    - Added a one-time pre-loop `xray api statsonline` probe: if the endpoint answers `Unimplemented`/no stats service (v2ray-served WS on :10080), print one `IP limit check skipped: online statistics unavailable ...` line and exit 0 instead of raising integer-expression errors every cron run; xray-backed transports (gRPC/split/HTTP on :10083/:10082) continue to enforce for real behind the same guard.
    - **Verified:** Live on Debian 12 VPS — WS run exits cleanly with the skip message; gRPC run with valid stats performed a real, safe lock.

70. **Dropbear Login Events Are Invisible to the SSH IP Limit and Login Checker** (`full/limit-ip-ssh.sh`, `full/cek-login-ssh.sh`)
    - `limit-ip-ssh.sh` now reads dropbear successes from the systemd journal (`journalctl -u dropbear --since "-10 minutes"`) with an auth-log fallback when journalctl/the unit is absent. `cek-login-ssh.sh` uses the same journal source (bounded with `-n 10000`), and its total now counts both daemons.
    - **Verified:** Live on Debian 12 VPS — 3 real dropbear logins as `kvs1` were counted and locked the account; `cek-login-ssh` dropbear table now lists `kvs1`/`root` rows with correct user, `ip:port`, PID, and limit.

71. **Fixed Field Offsets Cannot Parse RFC3339 Auth-Log Timestamps** (`full/limit-ip-ssh.sh`, `full/cek-login-ssh.sh`)
    - Both scripts now parse the message body (`Password auth succeeded for 'user' from ip:port` / `Accepted password for user from ip port n`) with the PID taken from the `tag[PID]` prefix, which is identical under classic and RFC3339 formats. The 10-minute window awk accepts both timestamp styles (`Mon DD HH:MM:SS` and `YYYY-MM-DDTHH:MM:SS...`).
    - **Verified:** Format fixtures — old lines in both formats dropped, fresh lines in both kept; live VPS counted classic fakes (sshd) and journal lines (dropbear); `cek-login-ssh` Username column now shows usernames instead of IP addresses.

## Live Audit Cycle 4 Addendum: Expiry Enforcement Fix and Regression Fixes (Bugs 72–74)

72. **Expired SSH Accounts Are Not Refused at Login Until xp Cleanup** (`full/expire-ssh.sh`, `full/extend-ssh.go`, `installer/xray.sh`)
    - Added `full/expire-ssh.sh`: walks `/etc/passwd` with the same enrollment filter as Bug 64 (uid >= 1000 and < 65534, excluding `root`/`nobody`), reads the shadow account-expiry date (field 8 - field 7 is inactivity, verified against `xp`'s `cut -f1,8` convention), and locks expired accounts with `passwd -l` - the same mechanism the multi-login limiter uses - while skipping accounts that are already locked. Never-expiring/numeric-invalid fields are ignored. Registered a `*/5` cron line in `installer/xray.sh` next to `limit-ip-ssh`.
    - `full/extend-ssh.go`: after a successful `usermod -e` renewal, runs `passwd -u` when the new expiry is in the future so renewed customers can log in again instead of staying behind the expiry lock.
    - **Verified:** Live on Debian 12 VPS - expired `kvsx3` locked (`P` -> `L`) while control accounts `banyan`/`kvs1`/`kvs2` (never expiring) stayed `P`. Client-verified from the KVM VM: locked expired account refused with `Permission denied` (exit 5) while it still existed; `xp`-deleted account (`kvsx2`) also refused (exit 5); renewal (+30 days) restored `P`, `expire-ssh` did not re-lock, and a subsequent VM login succeeded (session ran).

73. **SSH Multi-Login Lock Re-applies Forever After Automatic Unlock (Regression Fix)** (`full/limit-ip-ssh.sh`)
    - See regression `## 12.`: added a 10-minute time window (accepting classic and RFC3339 timestamps) before counting login events, so aged logins stop counting the moment the unlock delay passes.
    - **Verified:** Live on Debian 12 VPS - logins older than the window alone did not lock (`kvs2` stayed `P`); 3 fresh logins locked; after unlocking past the window, a re-run kept the account `P` (no immediate re-lock); 3 real KVM/dropbear logins were counted and locked, and the locked account was refused client-side (`Permission denied`, exit 5).

74. **`auto-delete-*.sh` Wildcard Quota Deletion Cross-Destroys Longer Usernames (Regression Fix)** (`full/auto-delete-{ws,grpc,http,split}.sh`, `lite/auto-delete-{ws,grpc,http,split}.sh`)
    - See regression `## 13.`: reverted the Bug 59 fix's `$user*` prefix glob back to the exact `$user` + `${user}_usage` path pair in all 8 daemons.
    - **Verified:** Live on Debian 12 VPS - ghost user `tst` cleaned while `tsta`'s quota file and config marker survived; `JSON_OK`.

## Fresh-Reinstall Audit Cycle (Bug 75)

75. **Reinstall Stacks Duplicate Cron Entries for Every Daemon** (`installer/xray.sh`)
    - Added a strip-before-append guard: a `sed -i .../d` pass removes all previously installed panel `flock` lines (backup, xp, expire-ssh, limit-ip-*, auto-delete-*, kill-*) from `/etc/crontab` before the canonical 16-line block is appended, making repeat installs idempotent.
    - **Verified:** Live on the reinstalled Debian 12 VPS - the same `sed` reduced 32 duplicated `flock` lines to 0, re-appending left exactly 16 unique lines with 0 duplicates.

## Fresh-Reinstall Audit Cycle (Bug 76)

76. **Backup Upload Produces an Empty Link** (`full/backup.sh`, `lite/backup.sh`)
    - Added `-L --max-time 60` to the file.io upload, quoted the `jq` response parsing, and added a two-stage fallback: tmpfiles.org API (parsed `.data.url`, `id_link="tmpfiles.org"`) then litterbox/catbox 72h (`id_link="litterbox-72h"`). Both fallbacks were probed live from the VPS before wiring.
    - **Verified:** Live on the fresh Debian 12 VPS - backup recorded `Link Backup: https://tmpfiles.org/.../backup.zip` with `Your ID: tmpfiles.org`. Full loop tested: deleted xray user `fr1` (4 config lines) and SSH user `fssh2`, downloaded the archive (7.7 MB, 121 files), ran `restore-ftp` (`SUCCESSFULL RESTORE YOUR VPS`) - both accounts returned with quota/log files intact, `JSON_OK`, all services active, crontab still duplicate-free.

## Fresh-Reinstall Audit Cycle (Bug 77)

77. **Lock Message Lists Timestamp Fragments Instead of IP Addresses** (`full/limit-ip-ssh.sh`)
    - Changed the `ip_list` builder from `awk '{print $NF}'` to `awk '{print $5}'`, matching the `PID - USER - IP - TIME` line format for both classic and RFC3339 timestamps.
    - **Verified:** Functional test on `PID - USER - IP - TIME` lines in both timestamp formats returned `10.9.9.1,10.9.9.2`; live on the Debian 12 VPS the fixed line is deployed (`print $5` present) and the lock path triggers normally.

## Fresh-Reinstall Audit Cycle (Bug 78)

78. **Input Prompts and Create-Account Headers Render Plain White** (138 `.sh` + 21 `.go` files in `full/`, `lite/`, `install.sh`, `installer/`)
    - Colored all **520** shell prompts (`read -p`/`read -rp`/`read -n 1 -s -r -p`) cyan via `$'\033[96;1m...\033[0m'` ANSI-C quoting so no expansion changes; the two `xl2tp` prompts containing `${NUMBER_OF_CLIENTS}` keep a split-quoted `"..."` segment so the variable still expands.
    - Create-account screens (`add-*`, `trial-*`, `addssh`): header rules cyan, titles yellow, validation errors ("cannot"/"already exists") red. `echo -n` prompts switched to `echo -ne` with color; 6 `echo "===="` headers switched to `echo -e`.
    - Colored all **31** Go input prompts (`fmt.Print("Input username: ")` etc.) cyan.
    - **Verified:** `bash -n` passes on all 138 shell files; all 21 Go binaries compile; a line-by-line semantic diff against git HEAD accounts for all 1223 changed lines (695 pure-color, 518 prompt-quoting, 2 echo-flag, 6 echo→echo-e, 2 split-quote) with zero unresolved; every prompt's text (520 shell + 31 Go) compared byte-identical after color-stripping; `menu/full.zip` (115) and `menu/lite.zip` (98) rebuilt with entry lists diff-identical to the originals and contents syntax-gated.

## Fresh-Reinstall Audit Cycle (Bug 79)

79. **Telegram Notification Bodies Sent Raw ANSI Escape Codes** (48 `add-*` / `trial-*` in `full/`, `lite/`) — (Regression Fix)
    - Stripped the escapes **only** from the Telegram payload by piping it inside the `curl` argument: `--data-urlencode "text=$(printf '%s' "$TEKS" | sed -e 's/\\033\[[0-9;]*m//g' -e 's/\x1b\[[0-9;]*m//g')"`. The terminal path (`format_display "$TEKS"`) and the log path (`echo -e "$TEKS" > logfile`) keep their colors, so only the consumer that cannot render ANSI is sanitized.
    - Rule-line restyle reviewed at the same time: all **384** cyan `════`/`====` separators in the create-account screens are now equal-length runs of `-` carrying the codebase's canonical 7-stop `rainbow_sep()` truecolor gradient, so the rules match the menu separators instead of the flat cyan.
    - **Verified:** the Python gradient was proven byte-identical to the real bash `rainbow_sep()` for every rule length present (19/20/22/23/24/25/28/29/30/31); `bash -n` passes on all 50 changed files; a line-by-line semantic diff against git HEAD classifies **all 432** changed lines with zero unresolved (384 rule transforms - each proven to preserve run width and to leave the other 567 cyan usages untouched - plus 48 byte-identical Telegram rewrites); running the real payload expression against a real `TEKS` returns **0** remaining escape sequences while keeping the dash separators and every `Remarks`/`Domain`/`UUID`/`Expired` field intact.
    - **Live on the Debian 12 VPS:** `full.zip` (md5 `56acdf2b`) redeployed to `/usr/bin` - `add-vmess-ws` went from 10 cyan rules / 0 rainbow to 0 cyan / 10 rainbow with the Telegram strip present, `DEPLOY_SYNTAX_OK` across every deployed `add-*`/`trial-*`. A captured `Create VMess WS` screen showed 4 rule lines with **28 dashes = 28 truecolor stops each** and a reset at end (0 mismatches), gradient running red `(255,0,0)` through green/blue and wrapping back to red exactly like `rainbow_sep()`; the only remaining `96;1m` cyan in the capture was the two `Username:` prompts, titles stayed yellow and the empty-username error stayed red. Re-simulating the send path on the deployed file left **0** escapes with `Remarks` and `UUID` intact, and the screen left the VPS clean (0 accounts, 0 at-jobs).

## Fresh-Reinstall Audit Cycle (Bug 80)

80. **Input Prompts Colored Cyan by the TUI Restyle** (138 `.sh` + 21 `.go` files in `full/`, `lite/`, `install.sh`, `installer/`) - revision of fix 78's scope
    - Reverted **559** input prompts to plain white by restoring each line byte-for-byte from `fad2fb4^`, the commit immediately before the colorization, so the quoting and variable expansion are the original ones rather than a re-derived approximation: **520** `read -p` / `read -rp` / `read -n 1 -s -r -p` prompts, **8** `echo` prompts (the 2 `echo -ne` back to `echo -n`, the 6 `echo -e "...\\c"` back to plain with `\c` and any trailing space intact), and **31** Go `fmt.Print` input prompts.
    - Everything reviewed and confirmed correct was left untouched: the **384** rainbow `------` separator rules from fix 79, the yellow header titles, the red validation errors (not input fields, so out of scope), the **48** Telegram escape-strips, and the **8** pre-existing `Cyan="\033[96;1m"` palette definitions in the `change-quota-*` scripts, which are V23 originals.
    - **Verified:** `bash -n` passes on all 114 changed shell files and all 21 changed Go binaries compile; a line-by-line diff against git HEAD classifies **all 559** changed line pairs as prompt reverts with **0** problems, every one passing a round-trip proof (`colorize(plain) == colored`) that reproduces the pre-change line exactly; HEAD-relative invariants prove nothing else moved - yellow `171 -> 171`, red `181 -> 181`, rainbow-rule lines `435 -> 435`, Telegram strip `48 -> 48`; cyan prompts went `520 -> 0` (read), `2 -> 0` (`echo -ne`) and `31 -> 0` (Go), leaving the only `96;1m` in the shell tree as the 8 pre-existing `Cyan=` palette definitions (**0** non-palette cyan).

## Fresh-Reinstall Audit Cycle (Bug 81)

81. **Quantity Fields Reject 0 and State Their Unit** (96 shell prompts + 10 Go prompts across `full/` and `lite/`)
    - Every quantity prompt now names its measurement and states that `0` is refused: `Limit Ip (0 not allowed): `, `Limit Quota (GBs, 0 not allowed): `, `Active Time (days, 0 not allowed): `, `Expired (days, 0 not allowed): `, `Expired (minutes, 0 not allowed): `, `Duration (Days, 0 not allowed): `, `Duration (Days, 0 not allowed) : `, `Limit IP (0 not allowed): `, ` Input New Quota (GBs, 0 not allowed) : `, plus the **10** Go prompts (`Input New IP Limit (0 not allowed): `, `Input New IP (0 not allowed): `, `Day Extend (days, 0 not allowed): `). **106** prompt lines rewritten; **0** prompts anywhere claim `0` means unlimited or no limit.
    - Added a re-prompt loop behind all **96** shell quantity reads: `while ! [[ "$var" =~ ^[1-9][0-9]*$ ]]; do`, the existing red error style `\033[0;31mValue must be a whole number greater than 0.\033[0m`, then the same prompt again. The re-read carries `|| exit 1` so end-of-input exits instead of spinning the loop forever - without it a `read` that returns non-zero at EOF leaves the variable unchanged and the loop never terminates.
    - Tightened **8** `change-quota-*.sh` guards from `^[0-9]+$` to `^[1-9][0-9]*$`, on both the new loop and the pre-existing late check at line 207.
    - Rewrote the **9** Go `isNumeric` definitions into `isPositiveInt` (rejects empty, a leading `0`, and any non-digit) and updated their 9 call sites; renamed rather than patched so a missed call site fails `go build` instead of silently keeping the old behaviour.
    - `full/extend-ssh.go`: `if err != nil` became `if err != nil || days < 1`, and the message now reads `Days must be a whole number greater than 0`.
    - Enforcement readers were deliberately left alone: `limit-ip-*.sh:97` tests `cek`, the **online count**, and `expire-ssh.sh:67` tests a **uid** - both legitimately allow `0`; the Bug-68 `^[1-9][0-9]*$` skip guard is unchanged.
    - **Verified:** `bash -n` on all 45 changed shell files and `go build` on all 10 changed Go programs; a line-by-line diff classifies **all 583 added and 143 removed lines** with **0** unclassified and every count exact (96 each of loop `while`/error/`done`/re-read, 98 + 10 hinted prompts, 96 + 10 prompt rewrites, 8 quota regex, 9 each of Go doc/func/zero-check/call, 1 + 1 extend guard/message). HEAD-relative invariants prove nothing else moved: rainbow rules, yellow titles, red errors, Telegram strips and the `Cyan=` palette all untouched. **40/40** functional assertions pass against code lifted out of the repo - the real `addssh.sh` loop refuses `0`, `00` and `abc` and recovers to the next valid value, exits with rc 1 on EOF instead of hanging, and hands `3` - never `0` - to the writer; the real `isPositiveInt` compiled from `change-limit-ip-ws.go` passes a 14-case truth table; and a full `addssh.sh` run on a real pty shows each `0` raising exactly one red error before re-asking, with the rainbow rules and yellow title intact.

## Fresh-Reinstall Audit Cycle (Bug 82)

82. **The 0 Rule Stated Once Per Screen Instead of on Every Field** (192 shell prompt lines + 10 Go prompts across `full/` and `lite/`)
    - Dropped the repeated `(0 not allowed)` suffix from all **202** quantity prompt lines while keeping every measurement on the field that carries it: `Limit Quota (GBs): `, `Active Time (days): `, `Expired (days): `, `Expired (minutes): `, `Duration (Days): `, `Duration (Days) : `, `Expired (Days) : `, ` Input New Quota (GBs) : `, `Day Extend (days): `. The two count fields have no unit and return to V23's exact wording - `Limit Ip: `, `Limit IP: `, `Input New IP Limit: `, and `full/limit-ip.go`'s `Input New IP   : ` (3-space alignment) restored byte-for-byte rather than re-derived.
    - Added **57** notices - `echo "0 not allowed"` in shell, `fmt.Println("0 not allowed")` in Go - placed immediately before the first numeric prompt of each screen: **47** shell (24 `add-*`, 8 `change-quota-*`, 8 `extend-*`, `full/addssh.sh` landing after the Password field, `full/trial-ssh.sh` at the very top because it has no Username prompt, `full/menu-noobz.sh`, plus 2 each for `full/xl2tp.sh` and `full/menu-wg.sh` since both contain two separate screens) and **10** Go. Each notice sits directly above the number block it governs and prints once, so it follows Username where a screen has one, Password where that intervenes, and nothing where there is no preceding prompt.
    - **Untouched:** every `^[1-9][0-9]*$` re-prompt loop, its red `Value must be a whole number greater than 0.` error, the `|| exit 1` EOF guards, the `isPositiveInt` validators, the rainbow rules, the yellow titles and the plain-white prompt colour.
    - No `(Regression Fix)` marker: fix 81's acceptance criteria - `0` refused everywhere, unit named on every field - never regressed; this is a presentation revision of how the rule is displayed.

## Fresh-Reinstall Audit Cycle (Bug 83)

83. **The 0 Notice Sits Flush Against the Form in Plain White** (47 shell + 10 Go notices across `full/` and `lite/`)
    - Each notice now renders in the panel's established orange, `\033[38;5;208m0 not allowed\033[0m` - the same value as the shell's `orange='\033[38;5;208m'` (defined in 8 menu scripts) and Go's `colorOrange = "\033[38;5;208m"`, so it matches the notices the menus already print rather than introducing a second orange. The escape is written inline in both languages so no file depends on a colour variable it may not define (`extend-ssh.go` has no constant block at all).
    - A blank line goes above every notice - `echo ""` in shell, `fmt.Println()` in Go - so the rule separates itself from `Username:`/`Password:` above and from the first field below: `Password:` / *(blank)* / `0 not allowed` / `Limit IP:`. The `^` indent of each notice is preserved exactly (4-space, 8-space, tab, 2-tab and column-0 all occur), and the notice still sits directly above the first numeric prompt.
    - **Untouched:** the prompt text and its units, the `^[1-9][0-9]*$` loops, the red error, the EOF guards, `isPositiveInt`, the rainbow rules, the yellow titles and the plain-white **prompts** (the notice is a rule, not an input field, so it is the one coloured thing added to the input layer).
    - **Verified:** `bash -n` on all 45 changed shell files and `go build` + `go vet` on all 10 changed Go programs; a line-by-line diff classifies **all 114 added and 57 removed lines** with **0** unclassified as exactly 57 blank+orange pairs (47 shell, 10 Go); a census confirms 47 + 10 orange notices, 47 + 10 blank lines immediately above them, **0** plain notices left and **0** notices missing their blank. **64/64** functional assertions pass, including a live `addssh.sh` run on a real pty that renders precisely `Username: u82` / `Password: p82` / *(blank)* / `0 not allowed` in orange / `Limit IP:` with the notice drawn **once**, both `0` keystrokes still rejected, and units intact - the capture input is deliberately paced rather than dumped, because a whole file fed at once echoes every keystroke at the top of the screen and hides the blank line being proven. All **10** Go binaries rebuilt and re-embedded (each carries the orange notice, zero stale suffix): `menu/full.zip` md5 `0b2c9345` (115 entries, 31 replaced) and `menu/lite.zip` md5 `beb3f455` (98 entries, 24 replaced) pass the audit with entry lists identical, `bash -n` 98/98 and 87/87, **27 + 20 = 47** orange shell notices each preceded by a blank line, **6 + 4 = 10** Go binary notices and **0** stale suffixes.
    - **Verified:** `bash -n` on all 45 changed shell files and `go build` + `go vet` on all 10 changed Go programs; a line-by-line diff classifies **all 259 added and 202 removed lines** with **0** unclassified (202 prompt rewordings paired one-for-one against their previous text, 57 notices); a census confirms exactly **1** notice per screen - 47 shell + 10 Go - each sitting directly above a numeric prompt, and **0** `(0 not allowed)` suffixes anywhere in `full/`, `lite/` or the compiled binaries. **55/55** functional assertions pass against code lifted out of the repo, including a live `addssh.sh` run on a real pty where the notice draws **exactly once**, precedes `Limit IP: `, no repeated suffix appears, both `0` keystrokes still raise a red error and recover, units render, and the rainbow rules and yellow title stay intact. All **10** Go binaries were rebuilt and re-embedded (each carries `0 not allowed` and zero stale suffix): `menu/full.zip` md5 `6f81b7c5` (115 entries, 31 replaced - 25 shell + 6 Go) and `menu/lite.zip` md5 `064f7c6b` (98 entries, 24 replaced - 20 shell + 4 Go) pass the audit with entry lists identical, `bash -n` 98/98 and 87/87, **27 + 20 = 47** shell notices, **6 + 4 = 10** Go binary notices and **0** stale suffixes.

## Fresh-Reinstall Audit Cycle (Bug 84)

84. **Account Cards Render Their Separators and Title Instead of Printing Escape Text** (`config/format.sh`, sourced by all 50 account-card callers)
    - `format_display`'s fallback branch now reads `echo -e "$line"`, so a line without a `:` - the 8 rainbow separators, the `Xray VMess WS` title, and every other colon-less row - expands its own `\033[…` sequences instead of printing them verbatim. The colon-bearing key/value and `Link` rows already took an `echo -e` branch and are untouched, as is the entire palette (`green`, `blue`, `purple`, `dpurple`) and every `^[=]{3,}$` test.
    - The `last_sep` subscript is guarded: `local last_sep=999` followed by `if (( nseps > 0 )); then last_sep=${sep_lines[$((nseps-1))]:-999}; fi`, so a card with no bare `===` line no longer evaluates `sep_lines[-1]`. The guard is an `if` rather than `(( … )) && …` deliberately, so a caller running under `set -e` cannot abort on the short-circuit's failure status; `first_sep=${sep_lines[0]:-999}` was already safe (subscript 0 on an empty array is unset, which `:-` handles) and is unchanged.
    - Deliberately **not** done: teaching `^[=]{3,}$` to match escape-prefixed separators. That would let `format_display` repaint the card's own rainbow dashes in its blue/`=` palette, undoing the rainbow-separator restyle - the card text already carries the intended colours, so the renderer's only job is to expand them.
    - **`(Regression Fix)`** - `012774e` (ours, 2026-09-21) swapped the working `echo -e "$TEKS"` for `format_display`, regressing all 50 account cards; the much larger escape runs introduced by `79eddef` are what made it visible, not what caused it.
    - **Verified:** `bash -n` passes on `config/format.sh`; a **26/26** assertion gate replays the real `add-vmess-ws` card (the literal-`\033` `TEKS` of an actually created account, recovered from its `.log` by reversing `echo -e`) through both renderers and requires the pre-fix file still to fail - **72** bytes of stderr, `sep_lines: bad array subscript`, **9** junk lines, **16** rendered - against the fixed file's **0** bytes of stderr, **0** junk lines and **25** rendered (16 + 9), with `Remarks : v84test`, `Expired : 26-10-04`, `Quota   : 10 GB`, the `vmess://` links and the separators-as-dashes all intact, line 2's leading byte a real `0x1b`, the `nseps>0` path still clean on bare `===` input, and empty/plain input round-tripping unchanged.
    - **Verified live:** deployed to `/etc/funny/format.sh`, md5 `bd438f23…` -> `d7715e9e…`, `-rwxr-xr-x` preserved; rendering that card through the *deployed* file gives **0** stderr, **0** junk, **25** rendered. A full paced `add-vmess-ws` run on a real pty then created `v85test` end-to-end: markers 4 -> 8, **0** `bad array subscript`, **0** literal-backslash lines in the raw capture, 33 lines carrying real escape bytes, and the card head rendering `-----------------------` / `Xray VMess WS` / `-----------------------` with every value and link correct. The only two errors in that capture were the pre-existing benign `cat: /etc/funny/.keybot` / `.chatid` notices. Cleanup restored the VPS exactly: markers back to 4 x `rentang`, **4749 - 404 = 4345 bytes** (4 blocks x 101 B, byte-exact), strict JSON `PARSE_OK`, quota/IP-limit/log files holding only `rentang`, 0 at-jobs, 0 test users, 0 test-account files, `v2ray` active.
    - **No zip or Go change:** `config/format.sh` ships through the installer's GitHub-raw fetch, not through the menu archives - `menu/full.zip` and `menu/lite.zip` each contain **0** `format.sh` entries - so neither zip nor any compiled binary was rebuilt and both zip md5s are unchanged.

## Fresh-Reinstall Audit Cycle (Bug 85)

85. **Account Cards and Logs Restyled Again by Returning the Card Rules, Title and Link Lines to Plain** (50 card blocks across `full/` and `lite/`)
    - Reverted the card blocks' structural lines to their pre-`fad2fb4` plain form: every rainbow-dash rule run back to a plain `=` run (at the original per-rule width), and every `\033[1;33m…\033[0m`-wrapped line back to plain text (`     Xray VMess WS`, `Link TLS : $vmesslink1`, `Link None: $vmesslink2`). 50 files, **466 lines**, a 1:1 swap.
    - This is what re-enables restyling: `config/format.sh` matches `^[=]{3,}$` again and the rule branch runs → rainbow `=` outer, blue `-` inner, and with two rules detected the title between them becomes purple and the `Link` rows match `^Link\ ` → deep purple; the Go viewers match `HasPrefix(trimmed,"==")` again and apply the identical standard.
    - **Deliberately untouched:** the create-account FORM rules (**52** lines still rainbow dashes) and FORM titles (**36** lines still yellow), the plain-white prompts, the red validation errors, the orange `0 not allowed` notices and the Telegram escape-strip. The card content is now escape-free, so the Telegram payload no longer needs stripping on that path.
    - **`(Regression Fix)`** - fix 78 wrapped the card title and `Link` lines in yellow escapes and fix 79 turned the card rules into rainbow dash runs; both made the structural lines undetectable to the renderers.
    - **Verified:** `bash -n` passes on all 50 changed files; the transform is a pure 1:1 line swap (**466 insertions / 466 deletions**) and the form styling is provably intact (rainbow rules **384 -> 52**, i.e. form only; `1;33m` **170 -> 36**, form only). Rendering the reverted card through `format_display` gives **0** stderr, **2** rainbow `=` outer, **6** blue `-` inner, **1** purple header, **2** deep-purple links, **14** green values and **0** escapes left; a faithful port of the Go `formatLogForTerminal` over the same content now detects **8** separators (was **0**) and yields **3** rainbow `=` / **5** blue `-` / **1** purple / **2** deep purple / **14** green.
    - **Zips:** `menu/full.zip` md5 `0b2c9345` -> `d3b685d3` (115 entries, **26** replaced) and `menu/lite.zip` `beb3f455` -> `a2e4aea7` (98 entries, **24** replaced), rebuilt in place with **identical entry lists** and **0** non-0755 entries; extracted entries are byte-identical to their sources, `unzip -tq` is clean, and **no Go binary was rebuilt** because no Go source changed (the viewers read the plain content correctly as-is).
    - **Deploy pending:** the test VPS went unreachable (provider-side outage) during this cycle, so this fix is committed and pushed for fresh installs but not yet deployed or live-verified on the VPS.

## Fresh-Reinstall Audit Cycle (Bugs 86-93)

86. **`change-id-grpc` Now Actually Changes the ID** (`full/change-id-grpc.sh`, `lite/change-id-grpc.sh`)
    - The two config substitutions were rewritten with escaped inner quotes - `sed -i "s|\"id\": \"${old}\"|\"id\": \"${new}\"|" /etc/xray/json/*.json` and the same for `"password"` - so the pattern that reaches `sed` is now `"id": "OLD"` instead of the quote-stripped `id: OLD`. The log rewrite at line 134 was moved from single quotes (where `'s/${old}/${new}/g'` matched the literal text `${old}`) to double quotes so the variables expand.
    - **Live on the fresh Debian 12 install:** created `bug84test` with `add-vmess-grpc`, then ran `change-id-grpc`; the UUID read back from `/etc/xray/json/grpc.json` was `cfbbaafc-8d52-450c-9fb0-145bc8221e6d` both **before and after** the change - the operation silently did nothing. Locally, the fixed pattern rewrites a real config line and the log line. Test account and its quota/limit/log files removed afterwards.
    - No `(Regression Fix)` marker: V23 carries the identical broken pattern.

87. **The Locked-HTTP Notification Names the Account** (`full/locked-xray-http.sh`, `lite/locked-xray-http.sh`)
    - `<code>$user</code>` -> `<code>$name</code>` on the notification line, matching what the script actually assigns (`read -p "Input Username to Lock: " name`) and what its three siblings already used.
    - **Live:** `bash -uc 'echo "$user"'` reports `user: unbound variable`, and the installed script's own assignment is `name` - so every HTTP lock notification was sent with an empty username.
    - No marker: V23 line 68 already reads `<code>$user</code>`.

88. **The lite Menu Renders Its Colours** (`lite/menu.sh`)
    - Added the three missing definitions the file was already using - `export blue='\033[1;34m'`, `export purple='\033[1;35m'`, `export orange='\033[38;5;208m'` - immediately after `NC`, matching `full/menu.sh:181-183`. `blue` is used for `blue_sep` and was masked from shellcheck by a function-local array of the same name, so it is fixed here too.
    - **Live:** the `menu` extracted from the shipped `menu/lite.zip` used `${purple}` twice, `${orange}` once and `${blue}` six times while defining **none** of them, so the "TOTAL ACCOUNTS" heading, the inner dividers and the "Press [Ctrl + C] to exit" footer rendered in the default foreground.
    - **`(Regression Fix)`** - the menu standardization introduced the usages (and the full menu's definitions) but synced the lite file without the definitions; V23's `lite/menu.sh` used neither colour.

89. **The UDP-Request Fallback Points at the File That Exists** (`installer/request.sh`)
    - `${hosting}/udp-request-linux-amd64` -> `${hosting}/udp/udp-request-linux-amd64`. The GitHub release URL remains the primary source and is unchanged.
    - **Verified against the network:** the old path returns **404** while the new one returns 200 (the binary is committed at `udp/udp-request-linux-amd64`), so the second source is now a real fallback instead of a guaranteed 404.

90. **`limit-ip-ssh` Iterates Its Array Safely** (`full/limit-ip-ssh.sh`)
    - `for user in ${username[@]}` -> `for user in "${username[@]}"`, clearing the ShellCheck SC2068 error and stopping word-splitting from inventing usernames.
    - **Verified:** `username=("a b")` iterated unquoted yields `[a]` and `[b]` (each of which would get its own `/etc/xray/limit/ip/ssh/<fragment>` default file), while the quoted form yields `[a b]`.
    - No marker: V23 has the same unquoted line.

91. **The OS-Reinstall Menu Points at a Maintained Reinstaller** (`full/menu-system.sh`, `lite/menu-system.sh`)
    - All **31** reinstall URLs in each file repointed from `raw.githubusercontent.com/rohjagad/reinstall/main/reinstall.sh` to `raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh`, the maintained upstream the fork mirrors.
    - **Live on this VPS:** running the fork reached `***** MOD DEBIAN INITRD *****`, downloaded upstream `trans.sh`, then aborted with `***** ERROR ***** / This script is outdated, please download reinstall.sh again`; the fork carries `SCRIPT_VERSION=4BACD833-A585-23BA-6CBB-9AA4E08E0004` while upstream is at `...0005`, and only the latter's GUID appears in `trans.sh`. The identical command with the upstream script completed, isolating the fault to the stale fork. The aborted run left the machine neither modified nor boot-primed.
    - No marker: the reinstall menu is a repo-added feature that never worked, not a regression of something that did.

92. **`xl2tp` Prints Its Warning in Red** (`full/xl2tp.sh`)
    - `Username ${RED}${VPN_USER}${NC} already exists` -> `Username ${red}${VPN_USER}${NC} already exists`, using the lower-case `red` the file actually defines.
    - **Live:** the installed script defines `red`, `green`, `blue`, `purple`, `orange`, `NC` and no `RED`; evaluating the line as written emitted no colour code at all, while the `${red}` form emitted `\033[0;31m`.
    - No marker: V23 has the same line.

93. **The Installer Bootstraps Its Own Downloader** (`install.sh`)
    - `install.sh` now installs `curl`/`wget`/`ca-certificates` when **both** are absent, before the authorization step rather than after it, so the README's claim that "the installer bootstraps `curl`/`wget`" is now true. `LOCAL_IP` gained a `wget` fallback and an explicit `Could not determine your public IPv4 - check that curl/wget is installed and the network is up.` error, replacing the misleading `Your IP doesn't have on database` that an empty IP previously produced.
    - **Live on the fresh Debian 12 install:** `command -v curl` and `command -v wget` both returned nothing; `printf 'full\n' | bash install.sh` printed `/root/install.sh: line 24: curl: command not found` and the same at line 39, then `Your IP doesn't have on database`, and exited. Installing `curl`/`wget` by hand and re-running the identical command passed the licence gate and started `full.sh` normally.
    - No marker: the bootstrap never existed, so nothing regressed.

- **Cycle artefacts:** `menu/full.zip` md5 `0b2c9345` -> **`5354da08`** (115 entries, 5 replaced: `change-id-grpc`, `limit-ip-ssh`, `locked-xray-http`, `menu-system`, `xl2tp`) and `menu/lite.zip` `beb3f455` -> **`cf5e937c`** (98 entries, 4 replaced: `change-id-grpc`, `locked-xray-http`, `menu`, `menu-system`), rebuilt in place with identical entry lists and 0 non-0755 entries; `unzip -tq` clean on both. `install.sh` and `installer/request.sh` are fetched from GitHub raw and are not zip entries. No Go source changed, so no binary was rebuilt.
- **Fresh-install verification:** the eight bugs were reproduced on a **freshly reinstalled Debian 12** (`PRETTY_NAME="Debian GNU/Linux 12 (bookworm)"`, kernel `6.1.0-50-cloud-amd64`) with the autoscript installed from GitHub `main` (`INSTALL SUCCESS`, `funny` 1.23, xray/v2ray/nginx/wg-quick@wg0/quota-ws/dnstt/dropbear all active) - i.e. on the buggy code, before any fix - so each reproduction is against what a real fresh install ships.

## Installer Resilience and Operations Notes (post-audit)

- **The installer now runs inside a persistent session** (`install.sh`, commit `743377a`). Started outside `screen`/`tmux` on a tty, it re-fetches itself to `/root/fn-install.sh` and re-launches with `exec screen -S fninstall bash /root/fn-install.sh`, falling back to `tmux new-session -A -s fninstall`, and installs `screen` first when neither tool is present. `FN_NO_SESSION=1` opts out, and non-interactive runs (no tty) skip the wrapper entirely so automation is unaffected.
  - **Reason:** a full install takes 15-30 minutes; a dropped SSH connection previously killed it mid-flight and left a half-installed machine.
  - **Verified live on the VPS:** an attached session was started, the SSH connection was killed after 9 s, and on reconnect the session was still `(Detached)` with its output advanced from `tick 2` to `tick 5` - i.e. the work survived the disconnect.
  - **Reattach / progress commands** are documented in `README.md` under "Install Command": `screen -r fninstall` to reattach, `screen -ls` to list sessions, `Ctrl-A` then `D` to detach (`Ctrl-B` then `D` for tmux), and `screen -S fninstall -L -Logfile /root/fn-install.log` with `tail -f /root/fn-install.log` for a transcript readable from a second SSH connection without attaching.
- **Operations note - the installer moves SSH to port 3303.** `installer/ssh.sh:58` appends `Port 3303` to `/etc/ssh/sshd_config`; because Debian ships `#Port 22` commented out, sshd then listens on 3303 only and port 22 closes. A freshly installed machine must be reached at `<host>:3303`.
- **Deployment status:** fixes 86-93 are committed and pushed (`f0e4c10`) and served from GitHub `main`. The fresh test VPS was deliberately installed from that ref **before** those fixes landed, so the bugs could be reproduced live against what a real fresh install ships; it has **not** been re-deployed with the fixed `menus/full.zip` since and still runs the buggy build.
- **Ops caveat seen during this cycle - a fresh netboot install can crawl, for environment reasons.** On the test VPS the Debian installer's resolver listed IPv6 nameservers first and the host's IPv6 default route was not actually routable, so every fetch stalled before falling back to IPv4; the CDN edge for `deb.debian.org` also served pool files at ~2 KB/s while GitHub fetched in 0 s. Pointing `/etc/resolv.conf` at `1.1.1.1`/`8.8.8.8` and pinning `deb.debian.org` to a mirror verified byte-exact against it (`ftp.kaist.ac.kr`, 5/5 files matched) took component retrieval from ~2 minutes each to 5-10 seconds. This is a hosting-environment problem rather than a defect in `fn-autosc`, but it is why a clean reinstall can take hours instead of minutes on this provider, and it is the same class of stall that made the installer look hung when it was merely starved.

## Regression Sweep After the Fresh-Reinstall Cycle (Bugs 94-95)

94. **The Reinstall Menu Now Matches the Script It Calls** (`full/menu-system.sh`, `lite/menu-system.sh`) - **`(Regression Fix)`**
    - All 13 unreachable entries corrected to the values upstream actually accepts: `openeuler 24.04`->`24.03`, `opensuse 15.5`->`16.0` and `15.6`->`tumbleweed`, `ubuntu 16.04`->`26.04`, `alpine 3.17/3.18/3.19/3.20`->`3.21/3.22/3.23/3.24`, `alma 9`->`almalinux 9`, `nixos 24.05`->`26.05`, `fedora 40`->`43`, `gento`->`gentoo`, `kali`->`kali rolling`; the display labels were updated in step (`Alpine 3.21-3.24`, `OpenSuse 16.0`/`Tumbleweed`, `Ubuntu 26.04`) including the pre-existing `OpenSuse 16.6` label typo.
    - **Verified:** both files still carry exactly **31** reinstall URLs and pass `bash -n`; every remaining argument pair was re-checked against upstream's usage text and all 31 are now valid (`almalinux 9`, `alpine 3.21-3.24`, `anolis 8`, `arch`, `centos 9`, `debian 9-12`, `fedora 43`, `gentoo`, `kali rolling`, `nixos 26.05`, `opencloudos 8`, `openeuler 20.03/22.03/24.03`, `opensuse 16.0|tumbleweed`, `oracle 8`, `rocky 8|9`, `ubuntu 18.04-26.04`), and the live probe confirms upstream accepts the corrected values (`alpine 3.23` proceeds) while the old ones were rejected (`alpine 3.17` -> usage + exit).
    - **Why it regressed:** the repoint in fix 91 moved the menu to the maintained upstream script to make the feature work at all; the carried-over commands were never reconciled with upstream's version list. See bug 92.

95. **The Installer No Longer Dies When `screen` Cannot Start** (`install.sh`)
    - The session hand-off dropped `exec` and now branches on the result: `screen -d -R fninstall bash "$SELF" && exit 0`, with a `tmux new-session -A -s fninstall ... && exit 0` equivalent and an explicit `screen/tmux could not start - continuing in this session.` fallback, so a failed hand-off installs normally in the current shell instead of replacing it. `-d -R` also makes a re-run reattach to an existing `fninstall` session rather than erroring.
    - **Verified:** with a `screen` stub that exits 1 the fixed block prints `REACHED: continues in this session`; with a stub that exits 0 it hands off and the parent exits 0 without falling through; `bash -n install.sh` clean. `shopt -s execfail` was tested and rejected as a fix - it does not cover a screen that executes successfully and then exits non-zero.
    - Self-introduced with the feature it hardens (not a regression of previously-working behaviour). See bug 93.

## Install Entry-Point Prerequisite (found while verifying the regression sweep)

- **`README.md` now installs a downloader before fetching the installer.** The bug-91 fix taught `install.sh` to bootstrap `curl`/`wget` for its own payload, but fetching `install.sh` in the first place is itself a download - so on a stripped image (exactly what the panel's own reinstall feature produces) the documented `bash <(curl ...)` command could not even be typed. The install block now opens with `command -v curl >/dev/null 2>&1 || { apt-get update -qq && apt-get install -y curl; }`, and the closing note states plainly that the payload bootstrap is separate from the entry-point requirement.
- **Verified live on the freshly reinstalled Debian 12:** `command -v curl` and `command -v wget` both returned nothing on the clean box - the installer had to be transferred out of band to start it - while the fixed `install.sh` then printed `No downloader found - installing curl and wget...` and went on to `INSTALL SUCCESS`. That is exactly the split the new README text describes.
- **Step-7 verdict on the freshly reinstalled box:** no regression remained. R-1 validated (0 invalid reinstall args, 0 stale typos in the installed `menu-system`), R-2 validated (no `exec screen` in the published installer, both fallbacks present, the hand-off failure falls through), and every previous-cycle fix re-checked present (`change-id-grpc` sed, `locked-xray-http` naming the account, `xl2tp` `${red}`, the quoted `limit-ip-ssh` array, plain card rules, and `/etc/funny/format.sh` byte-identical to the fixed `d7715e9e`). Menu smoke test clean, all services active.

## Cycle Epilogue - Current Deployment State, Corrections, and Verification Practice

- **Correction to the "Deployment status" bullet in the installer-resilience section above.** That note was accurate when written but is now superseded, and the docs are append-only so it is corrected here rather than edited. The test VPS was reinstalled again (Debian 12) and the autoscript reinstalled from GitHub `main` **after** fixes 86-95 had landed, so the live machine now runs the **fixed** build, not the buggy one it briefly carried. Confirmed on the running box: `/etc/funny/format.sh` md5 `d7715e9e5f73297442e8beabfb04b08b` (the fixed renderer), `menu-system` contains **0** invalid reinstall arguments, and `/usr/bin/change-id-grpc` carries the corrected `sed` pattern.
- **State of the test VPS at the end of this cycle:** Debian GNU/Linux 12 (bookworm), kernel `6.1.0-50-cloud-amd64`, `funny` 1.23, with `xray`, `v2ray`, `nginx`, `dnstt`, `dropbear`, `quota-ws` and `wg-quick@wg0` all active; SSH on port **3303** with 22 closed by design (see the ops note); **0** v2ray, gRPC and SSH test accounts; **0** at-jobs; no leftover operator files in `/root` or `/tmp`; and `/home` holding only the panel's own `limit` directory.
- **Artifacts as deployed:** `menu/full.zip` md5 **`dfff5179`** (115 entries) and `menu/lite.zip` md5 **`e59a78cd`** (98 entries), both last changed by `dcb3acd`. Earlier-cycle hashes (`6f81b7c5`/`064f7c6b`, `0b2c9345`/`beb3f455`, `5354da08`/`cf5e937c`) are historical and no longer current.
- **Verification practice - two false positives to avoid repeating.** (1) Rule-line counts differ per card: `add-vmess-grpc` legitimately carries **6** plain `=` rules while `add-vmess-ws` carries **8**, so a hard-coded expected count is the wrong assertion - compare against the same file's source or its hash instead. (2) Grepping for `echo -e "$line"` from inside a double-quoted `$( )` mangles the escaping and reports a false zero; use `grep -F` with the literal in single quotes, or simply compare md5s as above. The md5 is the dependable check for `/etc/funny/format.sh`.
- **Test-driver improvements for future reinstall cycles.** The progress poller should key on the *installed* kernel marker (`-cloud-amd64`) together with `PRETTY_NAME`, and should accept a lingering `pgrep` self-match as completion rather than waiting for zero matching processes - this cycle both conditions failed to fire even though the install had finished, costing two false waits. It should also try both port 22 (installer) and port 3303 (post-install) since the panel moves sshd during installation.

## Status of the "Not Fixed Yet" List and README Known Issues (re-verified against the code)

Every open finding was re-checked against the current tree rather than trusted from the docs. **Four are no longer true** and are stale documentation; the rest are genuinely still open.

**Resolved since being listed as open:**
- **Stale `199.232.68.133 raw.githubusercontent.com` hosts entry** (`installer/v2ray.sh`) - the block was removed (see the "Removed obsolete block writing hardcoded `199.232.68.133`..." entry earlier in this document). The address now appears only inside these docs.
- **Hardcoded Telegram bot token** in `installer/full.sh` / `installer/lite.sh` - `grep -rE 'bot[0-9]{6,}:[A-Za-z0-9_-]{20,}'` returns **0** across `installer/`, `full/`, `lite/` and `install.sh`.
- **`file.io` expiry mismatch** - `full/backup.sh` and `lite/backup.sh` now fall back to `tmpfiles.org` and then `litterbox.catbox.moe` (72h) when file.io fails, so the caption's expiry claim is no longer the operative one.
- **Broken menu entries "Argo option 2 (`reres`)" and "SlowDNS option 4 (`typer`)"** - neither symbol exists anywhere in `full/`, `lite/` or `installer/`; `menu-argo.sh` has no option 2 at all, and `menu-dnstt.sh` option 4 renders a SlowDNS information panel.

**Still open (verified present in the code today):**
- **BadVPN/UDPGW port 7300 is advertised but unsupported.** `full/addssh.sh:158` and `full/trial-ssh.sh:133` print `BadVpn/Udpgw : 7300` on every SSH account card, while no `badvpn`/`udpgw` binary exists anywhere in the tree - the service is never installed, so every SSH account promises a port that does not answer.
- **`chmod +x *` executes inside `/usr/bin`.** `installer/full.sh:123` and `installer/lite.sh:117` make every file in the current directory executable during the menu install; that directory is `/usr/bin`, so the mode change lands on the whole system binary directory instead of just the unpacked menu entries.
- **Hardcoded WhatsApp contact in the SSH banner.** `installer/ssh.sh:71-72` embeds a personal `wa.me` number and a WhatsApp group invite that operators cannot change without editing the file.
- **Hardcoded ACME addresses in `dm-menu.sh`.** `full/dm-menu.sh` carries three personal addresses (`faraskun02@gmail.com:163`, `melon334456@gmail.com:328`, `rerechan0202@gmail.com:365`) and `lite/dm-menu.sh` one; all four are handed to Let's Encrypt on the operator's behalf.
- **Fail2ban is installed but never configured.** `installer/package.sh:13,77` install the package, but no `jail.local` or `jail.d` is created anywhere in the tree, so it runs on upstream defaults and the "missing auth log" warning on minimal Debian stands.
- **Restore path conflict (regression 11).** Unchanged: `website/restore-ftp.sh` reads only `/var/www/uploads/*.zip` while `full/restore-ftp.sh` reads only `/root/*backup*.zip`; whichever is installed last wins.
- **SlowDNS still needs a manual DNS record** (README Known Issues 2) - `dnstt.service` stays inactive until the nameserver domain resolves to the host.
- **Design caveats rather than defects:** the broad `10.0.0.0/8` SNAT rule for the UDP request can overlap client private subnets, and HTTP/2-fronted SplitHTTP may not suit clients that expect plain HTTP/1.1 chunked transport.

## Correction - `chmod +x *` Is a Reliability Guard, Not a Defect

The `chmod +x *` in `installer/full.sh:123` (and `installer/lite.sh:117`) was listed earlier in this document as an open finding and described as a "blunt workaround". That classification is wrong and is corrected here.

- **What it does and where.** The sequence is `cd /usr/bin` -> `wget full.zip` -> `chmod +x full.zip` -> `unzip -o full.zip` -> **`chmod +x *`** -> `rm -f full.zip`. It runs immediately after the menu archive is unpacked, and its purpose is to guarantee that every extracted menu command is executable regardless of how the archive's stored permissions survived the download.
- **It closes a real, previously-observed outage.** The documented failure was that `zip` had been run over `644` source files, so `unzip -o` recreated them non-executable and *running `menu`, or any menu command, returned `permission denied`* - the entire panel became unrunnable. `chmod +x *` defeats that in one line, independently of the archive. The zips now also carry `0755` (see the "rebuild menu zips with execute permissions" fix), so the guard is a redundant second layer - which is precisely what a reliability guard should be.
- **The "blunt" concern is theoretical, not practical.** `/usr/bin` is a binary directory: on the live VPS all **442** files under it are already executable and **0** are not, so the command has nothing to change on a healthy system. It grants no read or write access and changes no ownership - only the execute bit, on entries that are by definition meant to be executed, and it is run by the installer as root on a directory of root-owned binaries.
- **Verdict: a deliberate reliability measure, not a bug.** It is left exactly as it is. Narrowing it to the archive's own entry list would be tidier but would make the guard depend on the archive's contents - the very thing it exists to be independent of.

## Follow-up - The Test VPS Was Reset (correcting the epilogue's state claim)

The "Cycle Epilogue" above records that the test VPS ended the cycle running the fixed build. That is no longer true, because the machine has since been reset to a bare Debian 12. Checked on 2026-09-25: uptime ~4h52m; `/etc/funny` absent entirely (0 entries); `/usr/bin/menu` missing; `/usr/bin` holding the base-system **490** entries where a full install carries ~1700; `/root/install.log` gone; **every** panel service inactive (`xray`, `v2ray`, `nginx`, `dnstt`, `dropbear`, `quota-ws`, `wg-quick@wg0`, `fail2ban`); and `sshd_config` back to its distributor state, dated 2026-05-05 with only the commented `#Port 22` and no `Port 3303` append.

The epilogue's verification claims are unaffected in substance - they were recorded from the machine while it *was* in that state, and the repository, zips and GitHub-served artifacts are unchanged by the reset. Only the description of the live box is stale: it currently carries no panel, so any further live verification needs a fresh install first.

For the same reason, the `/usr/bin` evidence quoted in the `chmod +x *` correction (`442` files, all executable) was gathered while the panel was installed. The argument it supports does not depend on that: `/usr/bin` exists to hold executables, so in practice there is nothing there for the guard to change - that is a property of the directory, not of that particular host.

## Remaining Open Items Closed (September 2026)

The `## Not Fixed Yet` list has been reduced to nothing actionable. Two of its entries were already fixed in code, four were fixed now, and two are deferred by their owner (the hardcoded WhatsApp banner and the SlowDNS DNS record, both listed in the README's Known Issues).

**BadVPN/UDPGW port 7300 is now real, because the repository already shipped the binary** (`installer/ssh.sh`)
- The repo carries `other/badvpn` - verified to be **BadVPN udpgw 1.999.130**, an x86-64 ELF - and serves it from GitHub raw (200), yet nothing ever installed it, while `full/addssh.sh:158` and `full/trial-ssh.sh:133` advertise `BadVpn/Udpgw : 7300` on every SSH account card. Note the card line is **not** inherited: V23's own `addssh.sh` has no `7300` line, so the advertisement was added here while its companion install step was not. The correct fix was therefore to instal it, not to delete the claim.
- `installer/ssh.sh` now fetches `other/badvpn` to `/usr/bin/badvpn-udpgw`, marks it executable, and runs it under `badvpn-udpgw.service` with `--listen-addr 127.0.0.1:7300 --max-clients 1000 --max-connections-for-client 10 --client-socket-sndbuf 100000`, following the same unit pattern as the existing `ws.service`.
- **Verified live** on a bare Debian 12: the binary reports `BadVPN udpgw 1.999.130`, runs, and `ss -ltn` shows `LISTEN 127.0.0.1:7300`. It listens on **TCP** - `/proc/net/tcp` matches port 7300 (hex `1C84`) while `/proc/net/udp` does not - which is correct for udpgw (it tunnels UDP inside a TCP connection), so the README's port table was corrected from `UDP` to `TCP (localhost)`.

**Fail2ban is now actually configured** (`installer/package.sh`)
- Fail2ban was installed but never configured, so it ran on defaults, which on Debian expect `/var/log/auth.log` - a file a minimal install does not create until the first login. That is exactly the "missing auth log" symptom: the first start after `apt install` fails with `Failed during configuration: Have not found any log file for sshd jail`.
- `installer/package.sh` now installs `python3-systemd`, stops the auto-started daemon, writes `/etc/fail2ban/jail.local` with `backend = systemd` for `[DEFAULT]`, `[sshd]` and `[dropbear]` (Debian 12 sshd and dropbear both log to the journal), then enables and restarts it.
- **Verified live** on a bare Debian 12: the service is `active`, `fail2ban-client status` reports `dropbear,sshd`, and the sshd jail was already showing **4 currently banned** addresses from real internet brute-forcing - i.e. it is reading the journal and banning, not merely loaded. The pre-fix `Have not found any log file` error no longer appears once the jail is in place.

**The Certbot addresses in `dm-menu.sh` now come from the operator** (`full/dm-menu.sh`, `lite/dm-menu.sh`)
- Three personal Gmail addresses were hardcoded for ACME: `faraskun02@gmail.com` (the `cert2()` helper), `melon334456@gmail.com` (inline in the `fn()` certbot call) and `rerechan0202@gmail.com` (the CSR subject fields) - three per tree, six in total. Every certificate the panel issued was therefore registered to someone else's address.
- All six now read the address the installer already stores: `email=$(cat /etc/funny/.email 2>/dev/null || echo "admin@example.com")`, with the inline certbot call reading the same file directly since `$email` is not set in that function's scope. `grep -c '@gmail.com'` is now **0** in both files.

**Two entries were already fixed and are simply stale documentation**
- **Restore path conflict (regression 11):** all three scripts now check both locations - `full/restore-ftp.sh`, `lite/restore-ftp.sh` and `website/restore-ftp.sh` each reference `/var/www/uploads/*.zip` **and** `/root/*backup*.zip`, so the web-vs-CLI conflict is gone.
- **UDP Request SNAT `10.0.0.0/8`:** not fixed because it is not this repository's rule to narrow. `installer/request.sh` already installs a host-exclusion guard (`ExecStartPost` plus a 15-second `udp-request-fixnet.timer` that re-asserts `iptables -t nat -I POSTROUTING -s $ip_nat -j RETURN`); the broad client-subnet SNAT is performed by the `udp-request` binary itself, so it stays a documented caveat in the README rather than a code change here.

**Deferred by the owner:** the hardcoded WhatsApp banner (`installer/ssh.sh`) and the SlowDNS nameserver record, both left in the README's Known Issues by request.

- **Process note - the archives must be rebuilt whenever a zipped source changes.** The commit that closed the open items above initially went out with the corrected `dm-menu.sh` in `full/` and `lite/` but **not** inside `menu/full.zip` / `menu/lite.zip`, because the zip-rebuild helper was missing from `/tmp` and the command did not abort on its failure. A fresh install unpacks the archives, not the source tree, so it would still have received the hardcoded addresses. Corrected in the following commit: `menu/full.zip` and `menu/lite.zip` were rebuilt in place (1 entry each, `dm-menu`), with entry lists identical and 0 non-0755 entries, and the packed entries verified byte-identical to their sources. The durable lesson is to assert the packed copy after any change to a zipped file - compare the extracted entry's md5 against the source's, as done here - rather than trusting that the rebuild ran.

## ADDENDUM: the Telegram-token false positive (found during this audit)

`bugs-fixed.md` (in the "Status of the Not Fixed Yet List" section) claimed:

> **Hardcoded Telegram bot token** in `installer/full.sh` / `installer/lite.sh` - `grep -rE 'bot[0-9]{6,}:[A-Za-z0-9_-]{20,}'` returns **0** ...

That verification is invalid. The stored value was `KEY="8610037724:AAGS..."` - a bare `<id>:<secret>` with **no `bot` prefix**, which the pattern `bot[0-9]{6,}:...` can never match. The grep therefore reported 0 for a file that still contained the token, and the entry was recorded as fixed when nothing had changed. V23 confirms the feature is inherited rather than newly added, but with a **different** token (`6981433170:AAH8q0tC...`), i.e. the fork only swapped the credential.

- The token was live in two files: `installer/full.sh:236` and `installer/lite.sh:172`, used by the install-complete notification that posts the new host's IP, domain, email and edition to a fixed chat.
- It is a real credential, committed to a public repository, and the README's own Security Notes already told operators to rotate it - so it was fixed rather than merely re-documented: both installers now read the operator's own `/etc/funny/.keybot` and `/etc/funny/.chatid` (the files `menu-bot` manages) and **send nothing when they are unset**. No credential is committed, and a fresh install no longer reports the operator's details to a third party. The install-notification feature is retained for operators who configure a bot.
- Re-verified with a pattern that actually matches the value - `grep -rE '[0-9]{8,10}:[A-Za-z0-9_-]{30,}'` over `installer/ full/ lite/ config/ install.sh website/` - which now returns **0**.
- The README Security Notes and Known Issues text were corrected in the same change so they describe the new behaviour instead of the old claim.

## Regression and False-Positive Audit of All Commits (September 2026)

A full pass over the project's history was run against the **V23 reference archive** (`/var/home/rscimung/Downloads/V23 Linux Ubuntu, Debian, Kali.zip`) to separate genuine regressions from changes that only look like them. The findings below are the actionable ones; the rest of this section is the register of what was investigated and deliberately **not** reported.

### Real bugs found and fixed (96-99)

96. **udp-request fallback URL doubled `/udp/`** (`installer/request.sh`) - see regression 17. Regression introduced by `f0e4c10`; V23's line was correct. Fixed and the corrected URL returns 200.
97. **Edition-agnostic crontab in `installer/xray.sh`** - see regression 18. `expire-ssh` was added by the Bug-72 fix and `limit-ip-ssh` inherited from V23; neither exists in the lite edition. Fixed to append only lines whose command resolves.
98. **Committed Telegram bot token removed** (`installer/full.sh`, `installer/lite.sh`) - see the addendum above. This is the entry that `bugs-fixed.md` already claimed was done; the claim was false and the code is now changed to match. The install notification reads `/etc/funny/.keybot` and `/etc/funny/.chatid` and is skipped when they are unset.
99. **SlowDNS never answered because the UDP 53 redirect was shadowed** (`installer/slowdns.sh`) - **the most consequential find of the cycle.** `udp-request` runs with `-mode=system` and inserts wildcard captures (`udp dpts:1:8988` and `dpts:1:65535`) at the **top** of `nat PREROUTING` when it starts, and it starts *after* `slowdns.sh` has placed the `udp dport 53 -> REDIRECT --to-ports 5300` rule. iptables is first-match, so every inbound UDP 53 packet was redirected to udp-custom (8989) and `dnstt` on 5300 never saw a query: the delegated nameserver resolved to the host, but the host stayed silent. Inherited from V23 (V23 has the same `-mode=system` unit and the same ordering), not a fork regression - but it made the whole feature non-functional.
   - **Confirmed live by rule counters**, not by inference: the `dpt:53 -> 5300` rule had **0 packets** while the `dpts:1:8988 -> 8989` rule above it carried all of them.
   - `installer/slowdns.sh` now installs `/usr/local/bin/slowdns-fixnet.sh` plus a `slowdns-fixnet` oneshot + 15-second timer that deletes any stale copy and re-inserts the redirect at **position 1**, so it is always evaluated before the wildcards and survives a reboot or a service restart. This mirrors the existing `udp-request-fixnet` host-SNAT guard.
   - **Verified live:** after the change, Google's resolver returns `Status: 3, Comment: Response from 202.155.17.126.` for a name in the delegated zone, where it had returned `Status: 2, Name servers did not respond [202.155.17.126]`. The nameserver is now answering.

### Live reinstall verification (fresh Debian 12, full edition)

Fresh OS via the panel's own reinstall path, then `install.sh` (`full`, `autosc.rohcuan.dpdns.org`, `dual`, nameserver `slowdns.rohcuan.dpdns.org`). `INSTALL SUCCESS` after ~21 minutes.

- **Services:** all panel services `active` - `nginx ssh sshd dropbear ws v2ray xray xray@grpc xray@upgrade xray@split haproxy openvpn wg-quick@wg0 noobzvpns dnstt udp-custom udp-request xl2tpd ipsec badvpn-udpgw fail2ban cron`, plus the new `slowdns-fixnet.timer`.
- **Fix 97 exercised:** `/etc/crontab` holds 16 panel lines and **every one of their commands exists** (the full edition ships `expire-ssh` and `limit-ip-ssh`, so nothing is skipped). On lite the same code omits those two, giving 14 - verified in the sandbox.
- **Fix 96:** the install took the release-CDN primary for `udp-request` (so the fallback was not exercised); the corrected fallback URL was verified separately to return 200 from the host.
- **Fix 98:** `grep` over the installed `/usr/bin` finds no committed token, and `dm-menu` has no hardcoded Gmail address.
- **Fix 99:** `dnstt` listening on 5300 and now answering externally (above).
- **Other fixes:** `badvpn-udpgw` binary present and `LISTEN 127.0.0.1:7300`; `fail2ban` active with jails `dropbear,sshd`; `/etc/funny/format.sh` md5 `d7715e9e5f73297442e8beabfb04b08b`; `v2ray test` reports `Configuration OK.`; 1422 files in `/usr/bin` with **0 non-executable**; `menu` present.
- **Certificate:** issued by **ZeroSSL** (`CN = autosc.rohcuan.dpdns.org`, valid to 2026-12-24) - the documented automated ACME fallback, Let's Encrypt being rate-limited at the time; `/etc/haproxy/funny.pem` present.
- **SSH:** the Debian cloud image leaves `Port 22` uncommented, so the panel's appended `Port 3303` leaves both listening - port 22 stays usable (unlike a netboot image, where `#Port 22` is commented and only 3303 opens).
- **Reboot check:** the host was rebooted and re-verified. Every panel service returned (the only non-`active` name is the intentionally absent `xray.service`, above), the SlowDNS fix persisted - the timer re-asserted the redirect so rule 1 is again `dpt:53 -> 5300`, and Google's resolver again reports `Response from 202.155.17.126` for a name in the delegated zone - the crontab still holds exactly 16 lines, `badvpn-udpgw` still listens on 7300, `v2ray test` still reports `Configuration OK.`, the certificate is still in place, `menu` is present, and `/usr/bin` still has 0 non-executable files. All expected ports are listening (22, 3303, 80, 443, 2052/2053/2082/2083/2087/2095/2096, 777, 855, 1194, 1723, 3128, 7300, 8001-8003, 8080, 8443, 8880, 10080-10083, 14016, 2019/2020/2023, 23456/24456/25432/31234/33456).

### Investigated and deliberately not reported as bugs

- **`lite/menu-system.sh` runs `chmod /usr/bin/warp.sh` with no mode** (full uses `chmod +x ...`). This is *not* a bug: the very next line in both files is `chmod +x /usr/bin/*`, the same reliability guard already agreed to be beneficial, which makes the file executable regardless. The only difference is a cosmetic `chmod: missing operand` line during install.
- **shellcheck `SC2128` across ~50 menus** ("expanding an array without an index") - false positive. `rainbow_sep()` declares `local -a green=(...)`, shadowing the exported scalar `green` **inside the function only**. Tested directly: the separator renders 19 distinct RGB colours and `${green}` outside the function still expands to the scalar escape.
- **`json/{grpc,split,upgrade,ws}.json` are not valid JSON** - they are templates whose inline `#vless`/`#vmess` marker lines are rewritten by the account scripts, and they are byte-identical to V23. Expected.
- **Zip "content mismatches" and "non-755 entries"** - harness artifacts. Every entry is `0755`; the entries that differ from their source are the Go tools, which ship as prebuilt ELF binaries while the source is `.go`.
- **`backups`, `log-format`, `log-source`, `menu-warp`, `menu-rout`, `restore-route` look like dangling commands** - the first three are English words inside comments; the last three are shell functions defined in the same file (V23 does the same). No broken references.
- **Port `977` removed from `upstream default_backend`** (fix 16) - safe: no file in the tree references 977 any more, so the entry was already dead.
- **The `rere` download removed from `install.sh`** (V23 fetched `/usr/bin/rere`) - nothing in the tree executes a `rere` binary; `/rere` exists only as an nginx WebSocket location for the VMess-HTTP transport.
- **`curl ... -o file || wget -q url` fallback without `-O`** - safe: tested that `curl -f` leaves no partial file on a 404, so wget cannot create a `file.1` and the `./file` that follows is the complete download.
- **`xray.service` is absent after a reboot** - by design, not a defect. `installer/xray.sh` deliberately removes the upstream `xray.service` that `install-release.sh` has just created (lines 62-63) and installs its own templated `xray@.service`; the main Xray's config is an empty `{}` and no transport uses it. Every transport is served by `xray@grpc`/`@upgrade`/`@split` and `v2ray`. It appears `active` immediately after an install only because `install-release.sh` started it before `xray.sh` deleted the unit; after a reboot it is correctly gone, and the post-reboot check sees 19 listening `xray`/`v2ray` sockets. The one residue is a dangling `/etc/systemd/system/multi-user.target.wants/xray.service` symlink, which systemd ignores (`list-unit-files` reports 0, no boot warning). Cosmetic, so left alone.

### Documented claims that are imprecise (corrected here, not code changes)

- `is-decision.md` section 5 still describes the hand-off as `exec screen -S fninstall bash /root/fn-install.sh`. The code is deliberately **not** `exec` any more (`screen -d -R fninstall bash "$SELF" && exit 0`, with a fall-through), because `exec` replaced the shell and died silently when screen failed. Corrected by an appended note rather than editing the decision text.
- Fix 58's file list names `lite/backup.sh`/`lite/bmenu.sh` as having gained `/etc/wireguard`, `/etc/slowdns` etc. The lite edition ships none of those services (WireGuard, SlowDNS, L2TP and OpenVPN are full-only by design), so the additions are, correctly, full-only; no data is lost because a lite host has nothing to back up in those paths.
- Fix 62 names the Go validator `isNumeric`; the code calls it `isPositiveInt`. The validation is present in both `change-limit-ip-*.go` and `limit-ip.go`; only the name in the note is wrong.

### Documented inherited defaults, deliberately not changed

- `installer/set-br.sh` ships a Gmail address and app password for `msmtp`, and `installer/l2tp.sh` a default `VPN_IPSEC_PSK='myvpn'`. Both are inherited from V23 and both are already called out in the README's **Security Notes** ("Secrets are committed to the repository … Rotate them, and do not reuse this repository's defaults"). They are pre-existing, documented defaults rather than a false claim of being fixed, so they are left as they are and left to the owner to decide. Unlike the Telegram token, nothing here asserted they were already removed.
- The duplicate authorization check (`install.sh` calls `permision`, then `full.sh`/`lite.sh` call it again) is inherited from V23 as well. It costs two extra HTTP requests per install and is harmless, so it is noted rather than changed.

### Static-verification results (all clean)

- `bash -n` on **207** shell scripts: 0 failures.
- shellcheck at **error** severity: **0** findings in the current tree vs 5 in V23 (including V23's genuinely broken `website/restore-ftp.sh`, which failed to parse). Warning-level diff vs V23 produced only the cosmetic SC2128/unused-colour noise above.
- Zip archives: 115/98 entries, 0 mismatches, **0 non-755**; packed `dm-menu` byte-identical to source.
- All **62** OS-reinstall menu invocations match upstream's supported distro/version list (0 typos) - the R-1 regression stays fixed.
- Every **active** download URL in `install.sh`/`installer/*.sh` returns 200 (only the two bare base-URL assignments do not, which is expected).
- The Go tools' shipped binaries contain the Bug-62 path literal (`/etc/xray/limit/ip/xray/`) and the Bug-72 `passwd` call, i.e. the prebuilt binaries are not stale relative to their sources.

## Audit Follow-up - Deployment Note and Open Items (September 2026)

### Deployment note - the ACME address used for the verification install

The certificate on the freshly installed test host was issued with the placeholder address `admin@rohcuan.dpdns.org`. The installer writes whatever address it is given to `/etc/funny/.email`, and `dm-menu` now reads it from there (the fix for the hardcoded addresses), so replacing it is a one-file edit followed by a certificate re-issue. Set a real operator address before treating this host as anything other than a test.

### Still open by the owner's decision - not defects introduced by this audit

- **Hardcoded WhatsApp contact in the SSH banner** (`installer/ssh.sh:71-72`). Tracked as README Known Issues item 4 and explicitly deferred by the owner. The same class of hardcoding as the Telegram token, but it is a contact rather than a credential, and nothing ever claimed it had been removed, so it was not changed here.
- **Inherited secrets left in place.** `installer/set-br.sh` ships a Gmail address and app password for `msmtp`, and `installer/l2tp.sh` a default `VPN_IPSEC_PSK='myvpn'`. Both come from V23, both are already called out in the README's Security Notes, and neither was ever documented as fixed - so they are recorded defaults for the owner to rotate, not false-positive claims.
- **The lite edition was not live-verified in this cycle.** The full edition was installed end to end on a fresh OS and re-checked after a reboot; fix 97's lite behaviour (the cron block omitting `expire-ssh` and `limit-ip-ssh`) was verified only in a sandbox with a lite command set - full 16 lines, lite 14, unchanged by a second run. The code path is identical and the only variable is which commands exist, but a real lite install is still worth running when convenient.

### Left as-is deliberately

- The dangling `/etc/systemd/system/multi-user.target.wants/xray.service` symlink - the unit three lines above removes `xray.service` on purpose and installs its own `xray@.service`, so the symlink points at nothing. systemd ignores it (`list-unit-files` reports 0, no boot warning); adding a cleanup would be churn for no behavioural gain.
- The duplicated authorization check (`install.sh` calls `permision`, then `full.sh`/`lite.sh` call it again) - inherited from V23, costs two extra HTTP requests per install, harmless.

## Contact Details Updated to the Operator's Own (September 2026)

Closed the last hardcoded-contact item. The SSH banner written by `installer/ssh.sh` carried the previous author's details: an order/trial line pointing at `wa.me/62858630085249`, and a `chat.whatsapp.com` group invite belonging to a third party.

- `installer/ssh.sh` now shows `https://wa.me/6289512992313` on the order/trial line, and replaces the group invite with `❖Ƭʜᴇ TELEGRAM => https://t.me/rohcuan`.
- The panel's own systemd units that advertised another party's channel were repointed to the operator as well: `installer/slowdns.sh` and `full/menu-dnstt.sh` (`Documentation=https://t.me/fn_project`) and `installer/vpn.sh` (`Documentation=https://t.me/geovpn`) now all use `https://t.me/rohcuan`.
- `full/menu-dnstt.sh` is a packed entry, so `menu/full.zip` was rebuilt in place: 115 entries, entry list identical, 0 content mismatches, 0 non-755, and the packed copy verified byte-identical to its source.
- Verified: the old number, the old group invite and both old `t.me` targets return 0 occurrences across `installer/`, `full/` and `lite/`.
- README: the Known Issues list drops the "hardcoded WhatsApp number" entry, the change is recorded in the since-fixed list, and the arrangement is recorded as an intentional decision (`is-decision.md` section 9).

### Correction to the open-items list above

The "Hardcoded WhatsApp contact" bullet in the Audit Follow-up above was written before the operator supplied their own details. It is superseded by the "Contact Details Updated to the Operator's Own" section that follows it: the banner now carries `wa.me/6289512992313` and `t.me/rohcuan`, and the README no longer lists a hardcoded WhatsApp number as a known issue. Still open from that list: the Gmail app password and the L2TP PSK (inherited defaults, owner's call) and a live lite install (fix 97's lite path is sandbox-verified only).

## Google Drive and Email Backup Paths Removed (September 2026)

- Deleted `full/backup-gd.sh` and `lite/backup-gd.sh`, and removed the `backup-gd` entries from the archives: `menu/full.zip` 115 -> 114, `menu/lite.zip` 98 -> 97 entries.
- `full/bmenu.sh` and `lite/bmenu.sh`: the "Backup to Google Drive" option is gone and the remaining entries renumbered (1 backup, 2-4 restore).
- `installer/set-br.sh`: dropped the rclone install and remote-config fetch, and the `msmtp`/`bsd-mailx` block that wrote `/etc/msmtprc` with the previous author's Gmail address and app password - together with the port-587 firewall rules and the `www-data` chown that only existed for it. The script now installs wondershaper only.
- The only `mail` call sites in the tree were in the two deleted scripts, so nothing sends email any more. `/etc/funny/.email` is retained: ACME (`dm-menu`) reads it.
- Verified: `backup-gd`, `rclone`, `drive.google`, `smtp.gmail`, `msmtp`, `bsd-mailx` and the old Gmail address now appear nowhere in `installer/ full/ lite/ config/ install.sh README.md` except the explanatory comments recording the removal. The archives were rebuilt and re-verified - 0 content mismatches, 0 non-755, `backup-gd` absent, and the packed `bmenu` updated to match its source.
- This closes the Gmail app-password bullet from the audit follow-up above. What remains open from that list is the L2TP `VPN_IPSEC_PSK` (an inherited default) and a live lite install. The arrangement is recorded as decision 11.

## Backup Delivery Simplified to a Telegram Attachment (September 2026)

- `full/backup.sh` and `lite/backup.sh`: removed the file-host upload (file.io -> tmpfiles.org -> litterbox.catbox.moe), the `Your ID` and `Link Backup` caption fields, the "AutoDelete After 7 Days" claim and the commented-out `sendMessage` block. The archive is now sent only as a Telegram document (`sendDocument`), captioned with the email, server IP and date/domain.
- `full/bmenu.sh` and `lite/bmenu.sh`: option 1 now reads "Backup to Telegram" instead of "Backup to File.io (Telegram)".
- README: the backup menu table, the "Where it goes" section and the stale file.io note were updated.
- `menu/full.zip` (114 entries) and `menu/lite.zip` (97 entries) were rebuilt: 0 content mismatches, 0 non-755, and the packed `backup`/`bmenu` verified to contain no file-host references.
- Verified: `file.io`, `tmpfiles`, `litterbox`, `upload_link` and `id_link` no longer appear in either backup script or in the packed entries. Recorded as decision 12.
