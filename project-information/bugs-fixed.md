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
