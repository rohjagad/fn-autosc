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

## Backup Caption Reduced to Domain / IP / Date (September 2026)

- `full/backup.sh` and `lite/backup.sh`: the caption's `Email` line was replaced by the domain, so the attachment is captioned `Domain` / `IP` / `Date`; the now-unused `email=$(cat /etc/funny/.email)` read was dropped. `/etc/funny/.email` remains in use by ACME (`dm-menu`).
- README "Where it goes" updated to describe the caption as domain / IP / date.
- `menu/full.zip` (114 entries) and `menu/lite.zip` (97 entries) rebuilt: 0 mismatches, 0 non-755, packed `backup` verified to match its source.

## Telegram Bot Menu: Dead Placeholder Replaced with Bot Auto Backup (September 2026)

- The Telegram Bot menu (`menu-bot`, main-menu option 6) had an option 2 "Set Up Bot Menu Panel" whose only action was `echo "Feature coming soon"` - an abandoned placeholder. It is now **"Set Up Bot Auto Backup"**.
- Its action calls a new `setbotup()`: it runs the existing bot setup (API key + chat ID, written to `/etc/funny/.keybot` and `/etc/funny/.chatid`) and then guarantees the 4x/day scheduled backup exists in `/etc/crontab` (`grep -q ... || echo ...` - idempotent). It finishes with a short summary (chat ID, schedule, delivery = Telegram document). Since Telegram is now the only backup channel, this entry is how an operator turns automatic backup delivery on.
- Applied identically to `full/menu-bot.sh` and `lite/menu-bot.sh`; the README's `menu-bot` section was corrected to list the four options the menu actually presents.
- An earlier attempt had renamed the separate *Terminal Bot* menu (the Node.js bot installer reached through option 3) instead; that was a misreading of the request and was reverted - the terminal-bot menu keeps its own name and options.
- Archives rebuilt: `menu/full.zip` (114 entries) and `menu/lite.zip` (97 entries), 0 content mismatches, 0 non-755.

### Revision - bot credentials split from notifications and auto backup

The bot menu was restructured so the credentials are entered **once**:

- **1. Set Up Bot Credentials** - prompts for the Telegram chat ID and the bot API key and writes them to `/etc/funny/.chatid` and `/etc/funny/.keybot` (the old `add()` flow, renamed to `creds()` and asking for the chat ID first).
- **2. Set Up Bot Notifications** - reads those files and never asks again; sends one test message so the operator can see the bot works, reporting success or Telegram's error.
- **3. Set Up Bot Auto Backup** - reads the same files and never asks again; additionally guarantees the 4x/day backup cron line exists and prints the summary.
- Both new entries go through a `havecreds` guard that tells the operator to run option 1 first when the files are missing.

"Terminal Bot Menu" and "Report Script Bug" moved to options 4 and 5. Applied to `full/menu-bot.sh` and `lite/menu-bot.sh`; README section updated. Archives rebuilt (114 / 97 entries, 0 mismatches, 0 non-755), and `notif()` verified to contain no `read -p`.

### Revision - bot credentials show the registered values and accept changes

"Set Up Bot Credentials" now opens with the values already registered

```
=====================
[ Bot Credentials ]
=====================
 Registered Chat ID : <current or "<not set>">
 Registered API Key : <current or "<not set>">

 Press ENTER on a field to keep its value.
```

and its two prompts accept a replacement (a blank line keeps the registered value). If, after keeping/replacing, either value would still be empty, it reports "Both values are required" and re-opens the form instead of writing empty files - so a fresh setup can never store blanks.

The three prompts also carry an EOF guard (`read ... || return`): previously, running the menu without a terminal made `read` fail instantly and the function recursed without end; now it returns. Verified in a sandbox with a patched path - entering both values saves them; pressing ENTER on both keeps the registered pair; changing only the chat ID keeps the key; and with stdin exhausted the function exits instead of looping.

## WebSocket Transport Migrated from V2Ray to Xray (September 2026)

- WS is served by `xray@ws`; V2Ray is removed from the install path, the scripts, the backup set and the host. See decision 13.
- 51 files under `full/`/`lite/` updated: 147 `/etc/v2ray/config.json` -> `/etc/xray/json/ws.json`, 66 `systemctl restart v2ray` -> `xray@ws`, 8 log-path references -> `/var/log/xray/ws.log`, 6 `v2ray api stats` -> `xray api stats`, plus the main menu's WS status probe. `json/ws.json`'s log path was updated; the retired `/etc/v2ray` tree was dropped from backup and restore; and the legacy restore's path-dependent `mv` (a self-move after the path change) was replaced with a UUID-only repair.
- The structure was aligned with the **1.20 reference archive**: the WS setup lives in `installer/xray.sh` with no separate installer, logs to `/var/log/xray/ws.log`, and enforces with `xray api statsonline --server=127.0.0.1:10080`.
- No shipped binary embedded either v2ray path, so no Go rebuild was needed. `bash -n` passes on every changed script; archives rebuilt (114/97 entries, 0 mismatches, 0 non-755, and no packed entry mentions v2ray).
- **Verified live on the Debian 12 VPS:** `xray run -test -config /etc/xray/json/ws.json` -> `Configuration OK.`; all six WS ports (14016/23456/25432/95/96/10080) are bound by `xray`; `statsonline` now answers from the stats service - the error changed from `Unimplemented ... unknown service xray.app.stats.command.StatsService` to the expected `app/stats/command: user>>>probe>>>online not found` - so the limiter's probe passes and `/usr/bin/limit-ip-ws` produced **0** "IP limit check skipped" lines where it previously skipped on every run. A test vmess-WS account was then created: it was written to `/etc/xray/json/ws.json` (the old v2ray path is absent), the account card rendered its TLS/None links, `xray run -test` stayed `Configuration OK.` and `xray@ws` stayed active, and `delete-ws` removed it cleanly with the JSON still valid. Afterwards `v2ray` is inactive/disabled, its binary and `/etc/v2ray` are gone, and nginx, ws, and `xray@grpc/@upgrade/@split` remained active.

## V2Ray Residue Removed from the Code Trees (September 2026)

Follow-up to the WS migration (decision 13). A **case-insensitive** sweep found residue the first pass had missed - that pass searched case-sensitively and only covered `full/` and `lite/`.

- `website/restore-ftp.sh` - a **third tree** - still copied the retired `v2ray` directory on restore and finished with `systemctl restart v2ray`. The copy is gone and the restart now targets `xray@ws`.
- The four `limit-ip-*.sh` scripts carried the stale Bug-69 comment ("the WS transport is served by V2Ray..."), copied into the gRPC/HTTP/split limiters where it was never true; all eight files now describe the probe as a regression guard that Xray answers.
- `quota-ws.sh` comment -> "Xray API"; `menu-argo.sh` label -> "Xray / Sing-box"; the four `xp.sh` "Auto Remove Xray / V2ray ..." headers -> "Xray ...".
- The bundled **`v2ray/v2ray-linux-64.zip` asset (16 MB) is deleted** - nothing has fetched it since decision 13.
- Verified: no case-insensitive `v2ray` match remains anywhere under `full/ lite/ installer/ website/ config/ json/ fix/ other/ udp/ install.sh`; `bash -n` passes on every changed script; the archives were rebuilt (7 entries per edition) with **0** packed references. The only surviving mentions are the historical records in `project-information/` and the two reference archives.

## WS-on-Xray Migration: IP Limit, Quota and Traffic Readout Repaired (September 2026)

Follow-up to the V2Ray -> Xray migration (decision 13). That migration was built on the **V23 (V2Ray-era) WS template and scripts with mechanical substitutions**, instead of the 1.20 reference which already served WS with Xray. Four defects - three introduced by the migration, one inherited in the same tool - left the WS IP limit and quota enforcement inert. All four are fixed and verified live.

### Real bugs found and fixed (100-103)

100. **The WS IP limit could never fire** (`json/ws.json`) - see Found 98. The template's `policy.levels."0"` had lost `"statsUserOnline": true`, which is present in the 1.20 `Json/ws.json` and in the current `grpc.json`/`split.json`/`upgrade.json`. Without it Xray never registers the `user>>><email>>>online` map, so `xray api statsonline` fails for every user; `limit-ip-ws.sh` reads that value into `cek`, the empty string fails its `^[0-9]+$` guard and the loop `continue`s silently. The line is restored.
    - **Verified live (real path):** a socks -> vmess-WS client was run against `xray@ws` (inbound `127.0.0.1:23456`, path `/vmess`) sent the `X-Forwarded-For` header nginx supplies (`203.0.113.7`, then two sessions `203.0.113.7` + `198.51.100.9`). Before the fix, `statsonline -email cence` answered `app/stats/command: user>>>cence>>>online not found` for the entire transfer (6,168,293 bytes); after it, `{"stat":{"name":"user>>>cence>>>online","value":2}}` with both addresses in `statsonlineiplist`. Pinned Xray 25.3.6 adopts the first `X-Forwarded-For` value as the session source (`transport/internet/websocket/hub.go:67-74`), which is why the nginx-fronted path is tracked; it deliberately refuses to count `127.0.0.1` itself (`app/stats/online_map.go:36-38`).
    - **End-to-end enforcement proven:** with `Limit IP: 1` and two concurrent client IPs, `/usr/bin/limit-ip-ws` removed the account from `/etc/xray/json/ws.json` (8 -> 0 matching lines), created `/var/log/create/xray/ws/cence.locked`, restarted `xray@ws` (still `active`) and left the config `Configuration OK.`
101. **The WS quota service never recorded usage** (`full/quota-ws.sh`, `lite/quota-ws.sh`) - see Found 99. The migration rewrote `v2ray api stats` to `xray api stats`, but Xray's `stats` requires `-name`; without one the RPC returns `app/stats/command:  not found`, so the service skipped every user forever. It also kept V2Ray's MB handling (`sed 's/MB//'` then `* 1048576`) and never reset the counters it accumulated. Replaced with the pattern the three sibling transports already use: `statsquery` to read raw bytes, `inb + outb`, accumulate into `<user>_usage`, then `xray api stats -name ... -reset`.
    - **Verified live:** the old command returned `... not found` and no `/etc/xray/quota/ws/<user>_usage` existed after megabytes of traffic; only the limit file was present. After the fix a controlled sequence shows the accumulator unchanged across an idle 30-second cycle (**delta 0**), rising by **8,519,875 bytes** after an 8,000,000-byte transfer, then unchanged again over the next idle cycle - recorded once, no double counting.
102. **`cek-xray-ws` printed blank traffic** (`full/cek-xray-ws.sh`, `lite/cek-xray-ws.sh`) - see Found 100. Same missing `-name`; the screen printed the RPC error twice and then `Traffic Uplink:  connections` / `Traffic Downlink:  connections` with empty values, for a connected user. Now read via `statsquery -pattern` and shown with their byte counts (formatted). Verified live during an active session: `Traffic Uplink: 156 bytes (156 B)`, `Traffic Downlink: 23150711 bytes (22.07 MB)`.
103. **`cek-xray-ws`'s "Total IP Login" always read 1** (`full/cek-xray-ws.sh`, `lite/cek-xray-ws.sh`) - see Found 101. It de-duplicated `awk '{print $1}'`, i.e. the **date** column of the access log, so the count was 1 for as long as the log spanned a single day. The client address is the token after `from`; the counter now extracts that and strips the port. Verified live with two sessions: `Total IP Login: 2 / 2`, matching `statsonline = 2`, where it previously showed `1`.

### Why the migration's own live check missed it

The migration's verification treated `app/stats/command: user>>>probe>>>online not found` as proof the stats service was healthy. That string is exactly what a **nonexistent** probe email always returns, whether or not online tracking is enabled, so it cannot distinguish a healthy service from the broken one - the same false-positive shape as Found 96. It also assumed the six `v2ray api stats` -> `xray api stats` substitutions were equivalent; Xray's `stats` needs an explicit `-name` (V2Ray's listed everything), so they were not.

### Static verification

- `bash -n` passes on all four changed scripts; the `full/` and `lite/` copies are byte-identical.
- `xray run -test -config /etc/xray/json/ws.json` -> `Configuration OK.`
- No bare `xray api stats` (without `-name`) remains under `full/` or `lite/`; `json/ws.json` now differs from the 1.20 reference template only by its trailing newline.

### Fresh-reinstall verification of fixes 100-103 (Debian 12, full edition)

The VPS was reinstalled from scratch with upstream `bin456789/reinstall` (`debian 12`; SSH moves to the panel's 3303) and then `install.sh` (`full`, `autosc.rohcuan.dpdns.org`, `dual`, nameserver `slowdns.rohcuan.dpdns.org`) reached `INSTALL SUCCESS`. The install pulled the committed code, so this exercises the **shipped** path, not a hand patch. The panel install took about 12 minutes.

- **Deployed artefacts:** `/etc/xray/json/ws.json` carries `"statsUserOnline": true` (lines 197-199) and `xray run -test` reports `Configuration OK.`; `/usr/bin/quota-ws` and `/usr/bin/cek-xray-ws` are md5-identical to `full/quota-ws.sh` / `full/cek-xray-ws.sh` at `c032912` and to the packed `menu/full.zip` entries; no bare `xray api stats` (without `-name`) remains; the crontab schedules `limit-ip-ws`.
- **Fix 100 (IP limit):** a test vmess-WS account (`bugtest`, `Limit IP: 1`) was opened from two client addresses, `203.0.113.7` and `198.51.100.9`, supplied the way nginx does (`X-Forwarded-For`). `xray api statsonline -email bugtest` returned **2** and `statsonlineiplist` named both addresses. `/usr/bin/limit-ip-ws` then removed the account (8 -> 0 rows), created `/var/log/create/xray/ws/bugtest.locked`, and left `xray@ws` `active` with the config still `Configuration OK.`
- **Fix 101 (quota):** quota-ws wrote `/etc/xray/quota/ws/bugtest_usage = 46973216` after the sessions' traffic - previously no `_usage` file was ever produced.
- **Fix 102 (traffic):** `cek-xray-ws` printed `Traffic Uplink: 156 bytes (156 B)` and `Traffic Downlink: 36225156 bytes (34.54 MB)`.
- **Fix 103 (IP count):** the same screen printed `Total IP Login: 2 / 1`, matching `statsonline`.
- **Environment notes (host-specific, not code):** this VPS's IPv6 cannot reach Fastly, so the Debian installer's mirror check stalled and was unblocked by pinning IPv4 in the installer environment - the same recovery recorded for the earlier cycle (decision 8). The installed system then received `Acquire::ForceIPv4 "true"` in `/etc/apt/apt.conf.d/` so apt does not repeat the hang. The test account and its files were removed afterwards and `/etc/hosts` was restored to its standard content. Final state: all panel services `active`, SSH on 3303, `menu` present, 0 non-executable files in `/usr/bin`, no v2ray, and the ZeroSSL certificate for `autosc.rohcuan.dpdns.org` valid to 2026-12-24.

## Full Live Feature Test Campaign and Six Fixes (September 2026)

Every panel feature was exercised against a **real external client**: a Debian 12 KVM guest (`fnclient`) running on the local machine's `/dev/kvm`, with Xray 25.3.6 installed from the upstream release. It connects over the Internet to `autosc.rohcuan.dpdns.org` (nginx -> the Xray inbounds), so the VPS sees genuine remote source addresses; a second client and some checks run from the VPS itself. Unless stated otherwise everything below was observed live.

### Real bugs found and fixed (104-109)

104. **gRPC dead on port 443 for dual-stack installs** (`config/dual.conf`) - see Found 102. Added `http2` to both 443 listeners, matching `config/4.conf`. Verified: gRPC `vmess`/`vless`/`trojan` go from `000` to `200` on 443, ws and httpupgrade unaffected.
105. **SplitHTTP/TLS threw away by nginx buffering** (`config/4.conf`, `config/6.conf`, `config/dual.conf`) - see Found 103. Added `proxy_request_buffering off;` and `proxy_buffering off;` to the `/splitvm`, `/splitvl` and `/splittr` locations. Verified: the three TLS split links go from `000` to `200` with 1 MB transferred.
106. **`change-id-*` silently did nothing** (`full/` and `lite/` for ws/http/grpc/split) - see Found 104. The id/password extraction now anchors on the account's `"email"` field and pulls only the id/password token; the card line is matched with a whitespace-tolerant `-E` pattern; and the "replace everywhere in the log" sed is quoted so its variables expand (and is guarded against an empty old value). Verified for all four transports: the JSON id changes, the card's `UUID` line follows it, sed reports no errors, the service restarts and the config stays `Configuration OK.`
107. **Over-quota WS accounts escaped quota-ws** (`full/quota-ws.sh`, `lite/quota-ws.sh`) - see Found 105. Added `| sort -u` to the expiry extraction, matching the sibling transports. Verified live with real traffic: an over-quota WS vmess account is now deleted by quota-ws itself within its 30-second cycle, config still valid.
108. **A failed backup destroyed the only copy** (`full/backup.sh`, `lite/backup.sh`) - see Found 106. The credentials are read with `2>/dev/null` and checked up front (keeping the archive and exiting 1 when unset), the upload timeout is 120 s, the response is inspected for `"ok":true`, and the archive is deleted only on a confirmed delivery. Verified: with no credentials the archive is kept (3.6 MB, 156 files) and the script exits 1 instead of claiming success.
109. **`trial-ssh` never wrote its IP limit** (`full/trial-ssh.sh`) - see Found 107. `create_ssh_user` now writes `1` to `/etc/xray/limit/ip/ssh/<user>`, matching the card and `addssh`. Verified: the next trial account carries the limit file with value 1.

### Transport matrix - 21/21 with a real external client

One account per protocol x transport (`add-vmess-/vless-/trojan-` x `ws/http/grpc/split`) was created through the panel's own menus, and each panel-generated share link was turned into an Xray client config and used to pull 1 MB from `speed.cloudflare.com`. **21 of 21 links passed** (TLS and NoneTLS forms where the card offers both): ws 6/6, HTTPUpgrade 6/6, gRPC 3/3, SplitHTTP 6/6. Before fixes 104-105 this was 15/21 (all gRPC and all split-TLS failed).

### Account tools across all protocols x transports

`change-quota`, `change-limit-ip`, `extend`, `locked-xray`, `unlock` were run against all 12 accounts and `change-id` against the 8 vmess/vless ones; every JSON/quota/limit/lock side effect was asserted. All pass after fixes 104-106, and `list-xray-*`, `cek-xray-*` and `log-database-xray-*` run clean for all four transports. (`cek-xray-ws` exits 1 with "No active users found!" when the log is empty - the Go siblings exit 0 - which is a cosmetic difference, not a defect: it only affects the menu's return code.)

### Enforcement

- **Multi-login (limit-ip)** for **all four transports**: an account with `Limit IP: 1` was opened from two genuinely distinct public addresses (the client VM's 157.15.139.236 and the VPS's own 202.155.17.126). `statsonline` reported **online=2** with both addresses listed, and `limit-ip-<tr>` deleted the account, wrote the `.locked` file and left the service active - 4/4.
- **Expiry (`xp`)** deleted back-dated accounts in ws, upgrade, split and grpc - 4/4.
- **`auto-delete-*` GC** removed an orphan log plus its quota and limit files whose owner was absent from the JSON.
- **Quota expiry (`quota-ws`)** deleted an over-quota WS account within its own cycle after fix 107.
- **SSH multi-login (`limit-ip-ssh`)** locked an account after repeated logins (`passwd -S` -> `L`), and `expire-ssh` ran clean.

### SSH

`addssh` created an account that logged in successfully on **all four SSH listeners** (OpenSSH 3303, Dropbear 111/109/69); the only message is the missing home directory, which is the documented tunnel-only design (decision 7). `trial-ssh` created an account (with its limit file after fix 109) and scheduled its `at` cleanup; `extend-ssh` moved the expiry; `delete-ssh` removed the user; `expire-ssh` ran clean.

### Trials, cron, backup, system menu

- **Trials:** `trial-vmess-ws`, `trial-vless-ws`, `trial-trojan-ws`, `trial-vmess-http`, `trial-vless-grpc`, `trial-trojan-split` each created an account (with its log) and queued the `at` cleanup job; `trial-ssh` likewise.
- **Cron:** all **16** panel crontab commands were run once with their `flock` wrapper - **16/16 exited 0** (backup, xp, expire-ssh, the four limit-ip-*, the four auto-delete-*, the four kill-*).
- **Backup:** produced a 3.6 MB archive containing 156 files including the expected `/etc/xray`, `/etc/funny`, `/etc/crontab`, `/etc/passwd` and `/etc/shadow` paths; after fix 108 it is retained when delivery cannot happen.
- **System menu:** option 2 (Restart All Services) restarted every panel service and all returned `active`; option 5 (Service & Port Details) rendered; option 8 (Change SSH Banner) replaced `/etc/issue.net` and the original was restored. The shipped banner already carries the operator's contacts.

### Revision - EOF guards on the change-id prompts (fix 106)

While driving `change-id-*` non-interactively the username prompt and the gRPC `(y/n)` confirmation were found to spin at 100% CPU once stdin reached EOF: `read` fails, the variable stays empty, the `while true` branch never matches and the loop repeats instantly. This is the same class as the earlier bot-menu EOF fix. All eight files now read `read ... || exit 1`, so an exhausted stdin exits instead of spinning; interactive behaviour is unchanged.

### Additional fix - `xp` deleted accounts with an unparseable expiry (fix 110)

Found while investigating the disappearance of the account `vm_ws` during the campaign (see Found 108). All six dated blocks in `full/xp.sh` and `lite/xp.sh` now verify the parsed date before using it: `d1=$(date -d "$exp" +%s 2>/dev/null)`, and when `d1` is empty the account is skipped with a message instead of being deleted. The WireGuard branch additionally requires `$exp` to match `^[0-9]{2}-[0-9]{2}-[0-9]{2}$` before its string comparison.

- **Verified live:** `datetest4` (`### datetest4 99-99-99`) survives with `Skipping datetest4: unparseable expiry '99-99-99'`, while `datetest5` (`### datetest5 20-01-01`) is still deleted with its log. Config remained valid.

### Observation - one account disappeared during the campaign and could not be attributed

While re-running the mutator matrix the account `vm_ws` was found completely gone (no config entry, no card/log, no quota or limit file) with no entry in `/etc/xray/.quota.logs`. It was present when the first matrix finished at ~16:40 and absent from the backup taken at ~16:53. A canary account with the same shape (created, extended, locked, unlocked, then run through `xp`, `kill-ws`, `limit-ip-ws`, `auto-delete-ws` and `quota-ws`) survived all of them, so none of the daemons deletes a healthy account; the most plausible cause is Found 108 - a corrupted `###` date (for example from an interrupted edit) makes `xp` delete the account and its files silently. Fix 110 removes that path. The lesson worth recording is that `xp` and `quota-ws` delete without writing to `/etc/xray/.quota.logs`; adding a deletion log to them would make any future recurrence attributable.

## Open-Bug Sweep: Default Credentials, Audit Logging and Card Links (September 2026)

The five defects still open after the campaign were taken in turn, live-verified, fixed and re-verified.

### Real bugs found and fixed (111-115)

111. **Public default credentials accepted on every install** (`installer/xray.sh`, `full/bmenu.sh`, `lite/bmenu.sh`) - see Found 109. `installer/xray.sh` now replaces **all six** committed defaults (`rerechan-store`, `cfbbaafc-8d52-450c-9fb0-145bc8221e6d`, `019e0bf3-dd56-11e9-aa37-5600024c1d6a`, `af7d5cf8-442d-4bb3-8a76-eb367178781d`, `diy2020`, `nonescript-fn-project`) with freshly generated UUIDs across all four templates; the same loop replaces the single `rerechan-store` substitution in `bmenu.sh`'s legacy-restore repair.
112. **Silent deletions** (`full/xp.sh`, `full/quota-ws.sh` and the `lite` copies) - see Found 110. `xp` writes an `xp: deleted <user> (expiry <date>)` line for every block (four Xray transports, L2TP, Noobz and WireGuard) and `quota-ws` writes `quota-ws: deleted <user> (usage X > quota Y)` to `/etc/xray/.quota.logs` before removing anything.
113. **Stale vmess links in the account card** (`full/change-id-*`, `lite/change-id-*`) - see Found 111. After the plaintext update each script rewrites the card's `vmess://<base64>` blobs through a small python step that decodes the JSON, replaces the id and re-encodes it; skipped silently if `python3` is absent.
114. **`cek-xray-ws` exited 1 when idle** (`full/cek-xray-ws.sh`, `lite/cek-xray-ws.sh`) - see Found 112. The empty-log path now exits 0 like the Go siblings.
115. **`quota-ws` journal spam** (`full/quota-ws.sh`, `lite/quota-ws.sh`) - see Found 113. The per-user `incomplete. Skipping.` message is gone; the loop still skips.

### Live verification

- **Found 109 reproduced live:** with the shipped templates, 11/12 probed combinations authenticated through nginx using only the committed value and pulled 300,000 bytes each. (Fix 111 is exercised by the reinstall below.)
- **Fix 112:** deleting an expired account produced `2026-09-26 09:16:33 xp: deleted xplog (expiry 20-01-01)` in `/etc/xray/.quota.logs`, which was empty before; an over-quota deletion produced `2026-09-26 09:18:13 quota-ws: deleted qlog_ws (usage 6899237 > quota 5242880)`.
- **Fix 113:** after changing an account's id the card's decoded `vmess://` link carried the new UUID (`388b6abb-...` -> `c2c5ba3b-...`), matching the config.
- **Fix 114:** `cek-xray-ws` with a cleared log now exits 0.
- **Fix 115:** zero `incomplete. Skipping.` lines in the journal across a full 30-second cycle where there had been one per idle account.

## Fresh-Reinstall Verification of Fixes 111-115 (September 26, 2026) and One Further Fix

The VPS was reinstalled from scratch (upstream `bin456789/reinstall` `debian 12`) and the panel reinstalled from the committed code, then every fixed behaviour was re-checked from a **real external client** - the rebuilt Debian 12 / Xray 25.3.6 KVM guest on the local machine (source IP 157.15.139.236).

- **Fix 111 (credentials):** in the four installed templates the committed defaults appear **0** times; each inbound carries a per-install UUID. Probing through nginx from the client VM with **nothing but the committed values** gives **0/11 authenticated** (vless/vmess/trojan across ws/gRPC/SplitHTTP/HTTPUpgrade), where before the fix 11/12 connected. The same paths with the **new per-install credentials** give **12/12 authenticated** (300,000 bytes each), proving the randomisation produced valid configs.
- **Fix 112 (deletion logging):** exercised again on the fresh host - `xp` wrote `2026-09-26 … xp: deleted xplog (expiry 20-01-01)` and `quota-ws` wrote `quota-ws: deleted qlog_ws (usage 6899237 > quota 5242880)` to `/etc/xray/.quota.logs`.
- **Fix 113 (card links):** changing an account id updated the card's decoded `vmess://` link to the new UUID.
- **Fix 114 (cek exit):** `cek-xray-ws` with a cleared log exits 0.
- **Fix 115 (quota noise):** zero `incomplete. Skipping.` lines across a full cycle.

### Additional fix - the HTTPUpgrade trojan template account was dead (fix 116)

Found 114 was discovered during the verification above. `json/upgrade.json`'s trojan client now uses `password` like the other three templates, so the shipped account is well-formed and the installer's randomisation lands in the right field. Verified on the reinstalled host: the templated (randomised) HTTPUpgrade-trojan credential now authenticates (`200`, 300,000 bytes), and the positive sweep is **12/12**.

### Second fresh-reinstall verification (September 26, 2026) - the whole cycle, end to end

After fix 116 was committed the entire cycle was run again from scratch, so this install pulled the final code (including the corrected `json/upgrade.json`). Fresh Debian 12 via `bin456789/reinstall`, then `install.sh` (`full`, `autosc.rohcuan.dpdns.org`, `dual`, nameserver `slowdns.rohcuan.dpdns.org`) to `INSTALL SUCCESS`; SSH moved to 3303.

- **Templates:** every committed default (`rerechan-store`, `cfbbaafc-…`, `019e0bf3-…`, `af7d5cf8-…`, `diy2020`, `nonescript-fn-project`) occurs **0** times in `/etc/xray/json/*.json`; the HTTPUpgrade trojan client now declares `password`; all four configs report `Configuration OK.`, every service is `active`, `menu` is present and `/usr/bin` has 0 non-executable files.
- **Negative (external client VM, 157.15.139.236):** probing through nginx with **only the committed default values** gives **0/11 authenticated** across ws/gRPC/SplitHTTP/HTTPUpgrade.
- **Positive:** the same paths with the **new per-install credentials** give **12/12 authenticated** (300,000 bytes each), including the previously dead HTTPUpgrade trojan.

That closes the open-bug sweep: the shipped installer no longer exposes any usable default credential, deletions are logged, the change-id card links follow the UUID, `cek-xray-ws` exits 0 when idle, and `quota-ws` no longer spams the journal.

## Transport Path Rename to a Canonical Scheme (September 26, 2026)

Requested change: each protocol/transport pair now has exactly one path and the previous paths are removed (no aliases kept).

| Protocol | Transport | Old path | New path |
| :--- | :--- | :--- | :--- |
| VMess | WebSocket | `/vmess` (TLS) + `/worryfree` (NoneTLS) | `/vmws` |
| VLESS | WebSocket | `/vless` | `/vlws` |
| Trojan | WebSocket | `/trojanws` | `/trws` |
| VMess | HTTPUpgrade | `/rere` | `/vmhu` |
| VLESS | HTTPUpgrade | `/imam` | `/vlhu` |
| Trojan | HTTPUpgrade | `/luqito` | `/trhu` |
| VMess | SplitHTTP | `/splitvm` | `/vmspl` |
| VLESS | SplitHTTP | `/splitvl` | `/vlspl` |
| Trojan | SplitHTTP | `/splittr` | `/trspl` |
| VMess | gRPC | `vmess-grpc` | `vmgr` |
| VLESS | gRPC | `vless-grpc` | `vlgr` |
| Trojan | gRPC | `trojan-grpc` | `trgr` |

Changed: the four `json/*.json` templates, the three `config/*.conf` nginx configs, every `full/` and `lite/` `add-*`/`trial-*` script (link generation and the account cards), `menu/full.zip` and `menu/lite.zip`, and the README transport table. Because `/vmws` now serves both the TLS and the NoneTLS form, the redundant `:95`/`:96`/`:977` VMess-WS inbounds and their `/worryfree`/`/kuota-habis` locations were removed (see the observation in bugs-found.md); `location /` (SSH-over-WS to `wsEpro` on `:2080`) is unchanged. The gRPC menu's *command* names (`add-vmess-grpc`, ...) deliberately still contain the old string.

Verified live after a clean reinstall of the OS and the panel (details below).

### Live verification (clean reinstall)

Fresh Debian 12 via `bin456789/reinstall`, then the panel from commit `4797f92` to `INSTALL SUCCESS`. On that install `nginx -t` passes, all four Xray configs report `Configuration OK.`, every inbound carries its new path (`/vlws`, `/vmws`, `/trws`; `vlgr`/`vmgr`/`trgr`; `/vmspl`/`/vlspl`/`/trspl`; `/vmhu`/`/vlhu`/`/trhu`), no committed default credential appears anywhere in `/etc/xray/json`, and no old path appears in the live nginx config.

- **Positive - 21/21.** One account was created for each of the twelve protocol/transport combinations using the panel's own `add-*` script, and the card it printed was replayed from the external client VM (source IP 157.15.139.236). Every TLS link and every NoneTLS link (all transports except gRPC) returned `200` with 300,000 bytes - WebSocket, HTTPUpgrade and SplitHTTP now share one path between their TLS and NoneTLS forms exactly as intended.
- **Negative - 12/12.** The same credentials rebuilt against the old paths (`/vmess`, `/vless`, `/trojanws`, `/rere`, `/imam`, `/luqito`, `/splitvm`, `/splitvl`, `/splittr`, `vmess-grpc`, `vless-grpc`, `trojan-grpc`) all failed (`http=000`), confirming the old paths were removed rather than kept as aliases.

### Broader live pass - local KVM client against the VPS (September 26, 2026)

A full feature pass was run with the local `/dev/kvm` guest (Xray 25.3.6, public IP 157.15.139.236) as the external client against the freshly installed VPS. The transport work is what the rename touches; the rest re-checks the panel after the reinstall.

- **Transport matrix - 21/21.** One account per protocol/transport combination was created with the panel's own `add-*` script and each card replayed from the client: every TLS link and every NoneTLS link returned `200` with 300,000 bytes - WebSocket, HTTPUpgrade and SplitHTTP on both the TLS and the NoneTLS form of their single path, and gRPC (TLS only). `cek-xray-ws` then showed each account with `Total IP Login` and its quota usage.
- **Multi-login / IP limit.** With `iplim` (Limit IP 1) online from two genuinely different hosts - the VPS itself (202.155.17.126) and the KVM guest (157.15.139.236) - `limit-ip-ws` removed the account, moved its card to `iplim.locked`, and reloaded `xray@ws` (`Configuration OK.`). The nginx access log carried the client-supplied `X-Forwarded-For` values (`198.51.100.7`, `203.0.113.9`) next to the real addresses, confirming the forwarded IP is what the online counter uses.
- **Trials.** All twelve `trial-*` scripts produced an account (three per transport) and queued an `at` job - twelve in total.
- **`xp`.** An account retimed to `20-01-01` was deleted and logged: `2026-09-26 11:26:19 xp: deleted xptest (expiry 20-01-01)`.
- **extend / delete.** `extend-ws` moved an expiry from `26-10-26` to `26-11-25`; `delete-ws` removed its account.
- **Backup.** With `/etc/funny/.chatid` and `/etc/funny/.keybot` absent, `backup` exited 1 after reporting `Telegram credentials are not configured` **and kept the archive** at `/root/backup.zip` (3,713,842 bytes) - fix 108's behaviour.
- **cron / menu.** Sixteen panel cron lines present; `menu` present.
- All test accounts, cards, quota/limit files and `at` jobs were removed afterwards; every service is active and every Xray config reports `Configuration OK.`

### Follow-up - the vestigial `:/rere` PATH entry was removed (September 26, 2026)

Tidy-up of the observation in bugs-found.md: `installer/slowdns.sh` appended `:/rere` - a directory that has never existed - to root's `PATH`, while the other branch of the same script already used the clean `"/usr/local/go/bin:$PATH"`. The two now agree, and the dead entry was stripped from `/root/.bashrc` on the live host. No behaviour change (a non-existent directory never contributed to command resolution); `bash -n` and shellcheck are clean.

## Lifecycle Daemon Fixes - kill-ws and quota-* (September 26, 2026)

A KVM-client pass over expiration, IP limit, bandwidth, renew, change-IP, change-bandwidth and lock/unlock found the following. All are fixed and verified live.

117. **`kill-ws` range delete** (`full/kill-ws.sh`, `lite/kill-ws.sh`) - see Found 115. The over-quota branch now uses the same safe form as every sibling script: `sed -i "/### $user $exp/ {N;d}"` followed by the `sed -z 's/},\n *\]/}\n        ]/g'` trailing-comma cleanup.
118. **`quota-{http,split,grpc}` never reloaded Xray** - see Found 116. Each ends its deletion with `systemctl restart xray@upgrade|@split|@grpc`, matching `quota-ws`.
119. **Phantom card and wrong wording on a quota deletion** - see Found 117. All four `quota-*` daemons now `rm -f` the account card and print "has been deleted" instead of "has been locked".
120. **Missing audit lines on `quota-{http,split,grpc}`** - see Found 118. Each writes `quota-<transport>: deleted <user> (usage X > quota Y)` to `/etc/xray/.quota.logs`, as `quota-ws` already did.

### What was already correct

Still verified working in the same pass: `extend-*` moves the expiry in both the config and the account card (`26-10-26` -> `26-11-05`); `change-limit-ip-*` updates the card and the enforced `limit/ip` file together; `change-quota-*` rewrites the quota file, resets the usage on request and updates the card; the manual lock (`locked-xray-*`) removes the client and moves the card to `.locked` preserving UUID and expiry, and `unlock-*` restores it to the same UUID with a working link; `xp` deletes expired accounts and logs them.

### Live verification of fixes 117-120

- **Fix 117:** an over-quota `kill-ws` deletion of the file's *last* account now removes exactly the marker and its object (153 -> 151 lines) and leaves `Configuration OK.` with `xray@ws` active - where the old range truncated the file to 50 lines and the service failed.
- **Fixes 118/119/120:** an HTTPUpgrade account pushed just over its quota had its client removed from `upgrade.json`, its card and quota files removed, a `2026-09-26 17:41:21 quota-http: deleted t_h3 (usage 1355936 > quota 1048577)` line written, and its link **failed immediately** (0/1) with `xray@upgrade` active. The same check on `quota-ws` gave the identical result (`quota-ws: deleted t_w3`, card gone, link 0/1).

## Four-Repository Scan - Fixes 121-140, and Reinstall Verification (September 26, 2026)

The fixes for Found 119-138. Fixes 121-126 are the `fn-autosc-api` repository (commit `1834b9b`);
127-133 and 140 are the panel and its website (commits `3e30a6a`, `cc06436`, with `menu/full.zip` and
`menu/lite.zip` rebuilt - the panel installs from those archives, not from the loose sources);
134-139 are the installer and configs (commit `3e30a6a`).

| Fix | Found | Fix |
| :-- | :-- | :-- |
| 121 | 119 | `lib.sh` gains `require <field> <var>`, which assigns in the caller's shell, so `fail`'s `exit` ends the handler; every `$(need ...)` call site converted. |
| 122 | 120 | `list-xray` and `delete-xray` report `http`, the name `core` accepts, instead of `upgrade`. |
| 123 | 121 | `delete-xray`/`delete-noobz` verify the removal and distinguish "no such account" from "the panel failed to remove it"; `delete-ssh` fails on a name that never existed; `require_tool` answers "this panel edition does not ship '<tool>'" instead of a shell error reported as success. |
| 124 | 122 | `renew-xray` (per `core`, keeping the account's usage), `renew-ssh` and `password-ssh` added, each verifying the expiry or the shadow hash actually changed; `menu-api`'s handler list and the status screen updated. |
| 125 | 123 | The server passes an empty string rather than `None` as stdin, so a GET handler sees EOF; the reference's `WWW-Authenticate` on 401 and `Allow` on OPTIONS restored. |
| 126 | 124 | `menu-api install` aborts when the server, `lib.sh` or any handler fails to fetch, and warns when the service is not active. |
| 127 | 125 | `addssh` silences the Telegram `curl`, matching every sibling. |
| 128 | 126 | The WG guard now matches `^[0-9]{4}-[0-9]{2}-[0-9]{2}$` - the `%Y-%m-%d` shape `menu-wg` writes. |
| 129 | 127 | `limit-ip-ssh` iterates the scalar (`for user in $username`). |
| 130 | 128 | The three Go viewers query 10081/10082/10083; binaries rebuilt. |
| 131 | 129 | `statsUserOnline` added to all four `routing-ws.sh` blocks and the `bmenu.sh` repair tail. |
| 132 | 130 | `copy_certificates` refuses to touch the live pair unless certbot produced non-empty files (and uses `cp`, which does not truncate); its caller reports the outcome; `fn()` rebuilds `/etc/haproxy/funny.pem`. |
| 133 | 131 | `domain=$IP2` dropped; `clear :` becomes `clear ;`; the two viewer titles swapped. |
| 134 | 132 | The fixnet script inserts the `INPUT` rule only when absent (`iptables -C ... || iptables -I ...`), and the two install-time inserts are guarded the same way. |
| 135 | 133 | The four 300s timeout directives added to `/vlspl` and `/trspl` in all three configs, matching `/vmspl`. |
| 136 | 134 | `client_max_body_size 0;` in the `http` block of all three configs. |
| 137 | 135 | `-4` (and `ipv4.icanhazip.com`) on the three lookups. |
| 138 | 136 | The download guard moved outside the substitution: `PERMISSION_DATA=$(curl -s "$URL") || { ...; exit 1; }`. |
| 139 | 137 | `set-br.sh` removes `/root/wondershaper` before cloning and after building. |
| 140 | 138 | `upload.php` requires a key before it accepts the upload - a dedicated `/etc/funny/.restore.key` generated by `website/install.sh` (`root:www-data`, 0640; the 0600 API token stays root-only), supplied as the form's `token` field or an `Authorization` header and compared with `hash_equals`; fails closed when the file is missing. The form gains the field. |

### Verified before the reinstall

- **API (fixes 121-126, from the KVM client through nginx):** `{}` to `/add-vmess` gives
  `{"status":"error","message":"missing required field: username"}` (was the nested garbage), an
  uppercase name gives the explicit validation error, `list-xray` reports `ws/http/split/grpc`,
  `renew-xray` extended ws `26-09-28`→`26-10-05` and http likewise, `addssh`/`renew-ssh`
  (`Oct 01`→`Oct 08`)/`password-ssh`/`delete-ssh` all behaved, a whitespace password was rejected,
  `delete-ssh` twice gave "no such account" the second time, and `add-ss` gave the designed error.
- **Fix 132 functionally:** an expired peer planted at `2020-01-01` (the 4-digit shape `menu-wg`
  writes) was removed from `wg0.conf` and `.wireguard` and left
  `xp: deleted wireguard client wgt (expiry 2020-01-01)` in `/etc/xray/.quota.logs`, while a
  `2099-01-01` peer survived.
- **Fix 129:** `for user in $username` iterates 3 users where `"${username[@]}"` iterated 1.
- **Fix 134:** after cleaning 904 rules, three runs of the guarded insert leave exactly 1.
- **Fix 140:** 401 without a key and with a wrong key, the file-type check reached only with the
  right one, from the KVM client over the network and via both the form field and the header.

### Reinstall verification (OS reinstalled, panel reinstalled from the repositories)

The VPS was reinstalled to Debian 12 with the upstream reinstaller
(`bash reinstall.sh debian 12 --username root --password ...`), then the panel was installed from
`main` with `install.sh` and the answers `full / <domain> / <email> / dual / <slowdns-ns>`. Result:
`INSTALL SUCCESS`, all services active (nginx, `xray@ws/grpc/split/upgrade`, `quota-*`, noobzvpns,
fn-ohp, haproxy, udp-custom, udp-request, dropbear, ssh, badvpn-udpgw, openvpn), `xray -test
Configuration OK.` for the templates, `nginx -t` successful, no committed default credential left in
any template, and `statsUserOnline` present in all four.

Every installed panel tool was then compared byte-for-byte with the repository: only
`/usr/bin/restore-ftp` differs, because `website/install.sh` overwrites the archive's copy with the
website one - expected.

The fixes re-verified on that clean install:

- `limit-ip-ssh` iterates the scalar; `routing-ws`/`bmenu` carry `statsUserOnline`; `dm-menu` has the
  guarded copy; `xl2tp` no longer references `IP2`; `menu-system` has no `clear :`; `addssh`'s
  notification is silenced; `cep-xray-*` binaries carry their own ports; `xp` carries the 4-digit WG
  regex.
- **Fix 134:** `iptables -S INPUT | grep -c 'dport 5300'` is **1** (it was 904) with the timer active.
- **Fix 135:** `/vmspl`, `/vlspl` and `/trspl` all carry `client_body_timeout 300s`.
- **Fix 136:** `client_max_body_size 0;` present.
- **Fix 137:** `/etc/.ip` is `202.155.17.126` on a host that has a global IPv6.
- **Fix 140:** run from the pushed repo, `website/install.sh` created `/etc/funny/.restore.key`
  (0640 root:www-data), deployed the gated `upload.php`, and the endpoint answered 401 without and
  with a wrong key and passed the gate with the right one.

### End-to-end traffic after the reinstall (KVM client, `xtest.py`)

One account per protocol/transport was created through the API and driven with a real Xray client
from the KVM guest; each download pulled 1,000,000 bytes and each gRPC account also uploaded
3,145,728 bytes:

| tag | protocol | transport | download | upload |
| :-- | :-- | :-- | :-- | :-- |
| r_vlws | vless | ws | 200, 1,000,000 | - |
| r_vmws | vmess | ws | 200, 1,000,000 | - |
| r_vmhu | vmess | httpupgrade | 200, 1,000,000 | - |
| r_trspl | trojan | splithttp | 200, 1,000,000 | - |
| r_vlspl | vless | splithttp | 200, 1,000,000 | - |
| r_vmspl | vmess | splithttp | 200, 1,000,000 | - |
| r_trgr | trojan | grpc | 200, 1,000,000 | 200, 3,145,728 |
| r_vmgr | vmess | grpc | 200, 1,000,000 | 200, 3,145,728 |

8/8 with no regression, and the 3 MB gRPC upload is the end-to-end proof of fix 136 (it returned 413
before). The test accounts were then removed and the API token and restore key rotated.

### Correction

The sentence "`cep-xray-*` binaries carry their own ports" in the reinstall-verification list above
should read "`cek-xray-*` binaries carry their own ports".

## Second Pass on the API Layer - Fixes 141-142 (September 26, 2026)

| Fix | Found | Change |
| :-- | :-- | :-- |
| 141 | 139 | `lib.sh` gains `re_escape`, which quotes a value for a `grep -E` pattern; `delete-xray`, `renew-xray` and `add-xray` build `^### <escaped-name>` from it, and the NoobzVPN handlers use `grep -F`. |
| 142 | 140 | `server` holds a module-level lock around the handler subprocess, so the panel's scripts - which rewrite whole shared files - never run concurrently. Cheap paths (auth, 404, OPTIONS) still run in parallel. |

Verified live after the change: `DELETE /delete-xray {"username":".*"}` and `{"username":"a.b"}`
now answer `no such account` and change nothing; the ordinary lifecycle still works; and **12/12**
concurrent `/add-vmess` calls succeed, giving 12 markers, 12 client objects and a config that
`xray -test` accepts. The fixed `lib.sh`, `server` and five handlers on the test host were compared
by MD5 with the repository and match.

Fix 136 was corrected in the same pass: `client_max_body_size 0` now applies only to the gRPC and
SplitHTTP locations (see the revision note in `bugs-found.md`).

## Third Pass - Fixes 143-145 (September 26, 2026)

| Fix | Found | Change |
| :-- | :-- | :-- |
| 143 | 141 | Every client literal the panel writes now carries `"level": 0` - 56 scripts (`add-*`, `trial-*`, `unlock-*`, both editions, 72 client literals), and `menu/full.zip` / `menu/lite.zip` rebuilt. |
| 144 | 142 | `installer/ssh.sh` now guarantees both `Port 22` and `Port 3303` are present, idempotently, instead of relying on the base image's `#Port 22`; the install summary prints `SSH Port: 22, 3303`. |
| 145 | 143 | The cards say `STUNNEL5 : 777` and the README's row lists `777` only. |

Verified live for fix 143 (see Found 141): a panel-created account now produces per-user traffic
counters and `quota-ws` deletes it once over quota, watched from a clean account through t=30 s.
Verified live for fix 144: after applying the same block to the running host, `ss` shows both 22 and
3303 listening, an external client gets `SSH-2.0-OpenSSH` on **both**, and `127.0.0.1:22` - dnstt's
forward target - answers again. Fix 145 was verified by `openssl s_client -connect :777`, which
returns `SSH-2.0-dropbear` (while `:443` returns nothing SSH-related).

### Correction to fix 101's live verification (September 26, 2026)

Fix 101's verification, above, records `/etc/xray/quota/ws/bugtest_usage = 46973216` and an
accumulator that "rose by 8,519,875 bytes after an 8,000,000-byte transfer ... recorded once, no
double counting". **That observation cannot have come from an account the panel created.** The
counters it describes (`user>>><email>>>traffic>>>uplink/downlink`) do not exist for a client
written the way `add-vmess-ws` writes them - neither archive writes a `level` either, and the pinned
Xray 25.3.6 only emits those counters for a client that carries one (Found 141, with a repeated A/B).
Either the test account was written by hand with an explicit `level`, or the reading was of something
else. It should not be cited as proof that the shipped path accounted usage; the A/B in Found 141 is
what the fix is based on.

The rest of fix 101 stands: adopting 1.20's `statsquery … | grep value` + `api stats -name … -reset`
shape is correct, and is what makes the counters readable once they exist.

## Fourth Pass - Fixes 146-147 (September 26, 2026)

| Fix | Found | Change |
| :-- | :-- | :-- |
| 146 | 144 | `full/addssh.sh` and `full/trial-ssh.sh` print `OVPN TCP/UDP: 1194 / 2200` and `Config OVPN : http://${domain}/web/openvpn.zip`, matching 1.20 and the two servers the panel actually runs. `OVPN WS : 2086` is kept - it is accurate for the `dinda` design this tree (and V23) uses. `menu/full.zip` rebuilt. |
| 147 | 145 | `installer/package.sh` installs Node **16** again (`setup_16.x`), matching both references, with a comment recording why: the bot's native dependencies do not build on Node 20 and `node-termios` has no newer release. |

Verified for fix 146: the built card shows the new lines, and the URLs it names are the ones the
panel serves (both 200). Verified for fix 147 by the A/B in Found 145 - the bot builds and starts on
Node 16 and cannot on Node 20.

## Sixth Pass - Fix 148 (September 26, 2026)

| Fix | Found | Change |
| :-- | :-- | :-- |
| 148 | 146 | `installer/request.sh`'s `udp-request-fixnet` guard now re-asserts `RETURN` rules for udp dport `51820`, `2200`, `500`, `4500` and `1701` above `udp-request`'s wildcard captures, alongside the host-SNAT exclusion it already did - delete-then-insert, on the existing 15-second timer, which also gains `AccuracySec=1s`. `installer/slowdns.sh`'s timer gets the same `AccuracySec`. |

Verified live: with the guard ran by systemd, a fresh `menu-wg` client tunnelled (ping `10.66.66.1`
and `1.1.1.1` at 0% loss, egress `202.155.17.126`), an OpenVPN UDP client brought up `tun0` and
egressed through the VPS, and after `systemctl restart udp-request` broke the ordering the timer
restored the bypasses in **15 s** (previously up to a minute).

## Seventh Pass - Fixes 149-150 (September 26, 2026)

| Fix | Found | Change |
| :-- | :-- | :-- |
| 149 | 147 | `installer/lite.sh` disables the dropbear service after `package.sh`: lite never runs `ssh.sh`, so dropbear stays on port 22, which sshd owns, and it failed on every install. Lite ships no SSH tooling, so the service is unused. |
| 150 | 148 | The README's "Variants" table marks `SSH / Dropbear / SSH WebSocket` as `❌` for lite and says `Node.js 16`. |

Verified live for fix 149: applying the same disable on the running lite host left
`systemctl --failed` empty with sshd still listening on 22.

### Fresh-reinstall acceptance of fixes 147-150 (Debian 12, September 27, 2026)

The OS was reinstalled twice: once for the lite run above, then again for a fresh **full** install,
which is what the tree is normally deployed as. Both pulled the committed code, so they exercise the
shipped path.

**Lite install (before the full reinstall):**

- `dropbear.service` was the only failed unit, exactly as Found 147 describes; disabling it left
  `systemctl --failed` empty with sshd still on 22 (fix 149).
- Transports from the KVM client: **4/4** - vmess ws, vmess grpc (with a 3 MB upload), vless
  splithttp, trojan httpupgrade, all 200 with 1,000,000 bytes.
- The API's lite behaviour: `add-vmess` succeeded and the full-only endpoints answered
  `this panel edition does not ship '<tool>'` for `addssh`, `list-ssh`, `cek-ssh`/`cek-login-ssh`
  and `add-noobz`/`noobzvpns`, instead of the shell error once reported as success.
- Fix 147 verified on the installed Node: `node -v` -> `v16.20.2`, `npm install` built both
  `node-pty` and `node-termios`, and the bot started.
- Fix 140 verified: `upload.php` answered 401 without the key and passed the gate with it; the key
  is `640 root:www-data`.

**Full install (fresh OS):** Node `v16.20.2`, SSH on 22/3303/109/111, **0 failed units**, every
service active (nginx, the four `xray@*`, the four `quota-*`, dnstt, noobzvpns, badvpn-udpgw, opn,
fn-ohp, haproxy, squid, wg-quick@wg0, xl2tpd, strongswan), 22 non-comment cron lines including the
two SSH ones, both fixnet timers active and **five VPN-bypass rules** in nat PREROUTING. Then:

- **API lifecycle:** ping, `list-xray` (4), `renew-xray` (`26-09-29` -> `26-10-04`), `addssh`,
  `renew-ssh`, `password-ssh`, `add-noobz`, `list-noobz`, `delete-ssh`, `delete-noobz` - all as
  designed.
- **Transports from the KVM:** 4/4 again, including the 3 MB gRPC upload.
- **The VPNs the sixth pass fixed, now from a fresh install:** a `menu-wg` client tunnelled (tunnel
  ping 0% loss, egress `202.155.17.126`) and an OpenVPN UDP client brought up `tun0 10.7.0.6` with
  egress through the VPS - both on the installer-written bypass rules, with no manual rule needed.
- Test accounts and the WG peer were removed; the host ended at 0 xray, 0 ssh and 0 WG peers.

## Eighth Pass - Fixes 151-152 (September 27, 2026)

| Fix | Found | Change |
| :-- | :-- | :-- |
| 151 | 149 | `full/menu-system.sh` and `lite/menu-system.sh`: remove the `/etc/wireguard/params` guard that made the WARP installer abort on every full install, and give lite's copy the same `chmod +x /usr/bin/warp.sh` as full. |
| 152 | 150 | `installer/l2tp.sh`: after writing `ipsec.conf`, normalise it to strongSwan syntax (`keyexchange=ikev1`, `ike=`/`esp=` in strongSwan form) whenever strongSwan is the installed implementation, so Debian/Ubuntu can negotiate IKEv1 again. CentOS's libreswan config is left untouched. |

Verified live for fix 151: the fixed menu ran the WARP install through to completion - `warp.sh
install` finished, the WARP client reported `IPv4 Network : WARP` / `IPv6 Network : WARP`,
`warp.sh wgd` brought up the `wgcf` interface with the default route still on ens3 (SSH unaffected),
and the panel stayed healthy. WARP was then uninstalled, the Debian unstable repository it added was
removed and the extra kernel it pulled was purged.

Verified live for fix 152: with the normalised config the same client's `ipsec up L2TP-PSK` reported
`selected proposal: ESP:AES_CBC_128/HMAC_SHA1_96` and `connection 'L2TP-PSK' established
successfully` (previously `NO_PROPOSAL_CHOSEN`), and the server's xl2tpd logged
`Call established with 157.15.139.236`. The IPsec SA and the L2TP control connection are the two
things the defect broke; the PPP session itself could not be finished in the test guest because its
Debian cloud kernel carries no `ppp` modules.

## Ninth Pass - Fix 153 (September 27, 2026)

| Fix | Found | Change |
| :-- | :-- | :-- |
| 153 | 151 | `config/4.conf`, `config/6.conf`, `config/dual.conf`: send the panel's own trusted `$clientRealIp` map value as `X-Real-IP` and `X-Forwarded-For` to the upstreams instead of `$remote_addr` / `$proxy_add_x_forwarded_for`, so the address the IP limit counts cannot be chosen by the client. |

Verified live for fix 153: after editing the installed `nginx.conf` the same way, `nginx -t` passed
and nginx reloaded; the client that forged `X-Forwarded-For: 9.9.9.9` was then recorded as
`from 157.15.139.236:0` - exactly like a client that sent no such header - while `statsonline`
still reported 2 for two real concurrent addresses, so counting is unchanged and is now unforgeable
behind Cloudflare. The map and log format were left exactly as they were (the map already produced
the trusted value), and the same substitution also gives the SSH-WebSocket (`location /`) and API
locations the true client address when the panel is behind Cloudflare, instead of the edge address.

### Correction to fix 153 - the value must be *trustworthy*, not just "the panel's map"

Fix 153 originally sent `$clientRealIp` (the map over `X-Forwarded-For`) to the upstreams. Driving
the edge cases showed that was too fragile, so the configs now trust Cloudflare's own
`CF-Connecting-IP` only when the peer is inside Cloudflare's published ranges and pass only
`$remote_addr` upstream:

```
set_real_ip_from <each Cloudflare ipv4/ipv6 range>;
real_ip_header CF-Connecting-IP;
real_ip_recursive on;
...
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $remote_addr;
```

`$remote_addr` is then the real client behind Cloudflare and the true TCP peer otherwise, and the
map gained `default $remote_addr` so it can never come out empty.

All four cases driven live from one client (157.15.139.236):

| request | fix 153 alone | hardened |
| :-- | :-- | :-- |
| via Cloudflare, `X-Forwarded-For: junk` | real client | real client |
| direct, `X-Forwarded-For: junk` | `127.0.0.1` (map empty, header dropped) | real client |
| direct, `X-Forwarded-For: 9.9.9.9` | `9.9.9.9` (spoofed) | real client |
| direct, `CF-Connecting-IP: 7.7.7.7` | - | real client (header ignored: peer is not Cloudflare) |

Cost: Cloudflare's ranges are listed in the three configs and should be refreshed if Cloudflare
changes them (they publish `https://www.cloudflare.com/ips-v4` and `/ips-v6`). A different
proxy/CDN in front would need its own `set_real_ip_from` entries; with no proxy at all the list is
inert and `$remote_addr` is the true peer. The map and log format are still the panel's own.

## Tenth Pass - Closing the Open Recordings (September 27, 2026)

| Fix | Closes | Change |
| :-- | :-- | :-- |
| 155 | the FN-API fetch observation | `other/bot.zip` vendored (sha256 `a0bc5bf758abd5df9b1ba8847cb6e5d8a085568af2b76d96a46ceb69ca9393c3`); `full/menu-bot.sh` and `lite/menu-bot.sh` fetch `${hosting}/other/bot.zip`; both menu archives updated in place (only the `menu-bot` member). |
| 156 | my own wrong CIDR in fix 154 | `config/4.conf`, `config/6.conf`, `config/dual.conf`: `set_real_ip_from` re-synced to Cloudflare's published lists (`2c0f:f248::/29` -> `/32`). |
| 157 | the fix-154 fragility (section 30) | `installer/cf-realip.sh` refreshes `set_real_ip_from` from Cloudflare's lists, `nginx -t`-guarded and fully best-effort; `installer/diamond.sh` installs it to `/usr/local/bin/cf-realip-refresh` and schedules it weekly. |
| 158 | (fn-autosc-api) | `lib.sh`: `panel_reason` strips escape sequences, so a refusal reason is readable instead of embedding `ESC[2J` and friends. |
| 159 | early finding 21 | `rohjagad/fn-autosc-miscellaneous` drops the dead committed `rclone.conf` and `rclone-install.sh`. |

Verified live for fix 157: running the refresher when the list was current left `nginx.conf`
byte-identical (no reload, no backup left behind); after deleting two ranges by hand it restored the
full published set and reloaded cleanly (`nginx -t` OK, `https://.../web/tcp.ovpn` = 200).

### Correction to fix 156 in the tenth pass

Fix 156 is recorded above as re-syncing the three configs from `/29` to `/32`. Checked against git,
that is not what happened: `165a535` (fix 153) is the commit that carried `2c0f:f248::/29`, and
`e40be5c` (fix 154) is the commit that had already corrected it to `2c0f:f248::/32` when it rewrote
the block. The repository's configs have been correct since `e40be5c`; the `/29` survived only in the
**live** apply of fix 153 on the test host, which the run of `cf-realip-refresh` (fix 157) then
replaced with Cloudflare's published `/32`. Fix 156's entry is therefore a re-verification, not a
change to the repository, and the substantive correction for a live host is fix 157's refresher.

### Correction to that correction - where the /29 actually came from

Checked against git, neither `165a535` nor `e40be5c` ever carried `2c0f:f248::/29`: `165a535` has no
`set_real_ip_from` block at all (fix 153 only changed the forwarded-header values), and `e40be5c`
added the block with Cloudflare's published `2c0f:f248::/32`. The `/29` existed only in the
**host-side** script that applied the real_ip change to the live nginx.conf during fix 154 - the
repository was correct throughout. What fix 157 changed on a live host is therefore the whole point:
the refresher replaced the hand-written list with Cloudflare's published one. Fix 156 and the two
correction notes can be read together as: repository correct; live apply off by one CIDR; refresher
delivers the authoritative list at install and weekly.

### Reversal of the fix-153/154 hardening - the limiter must work, not resist forgery

The strictness delivered by fix 154 (and its refresher, fixes 156/157) - `set_real_ip_from` plus
`real_ip_header CF-Connecting-IP`, so that a client could not choose the counted address - has been
**reverted** on the owner's instruction: the limit has to work for a regular user, and a regular user
does not forge headers, while the range list made the everyday case depend on being kept current (a
new Cloudflare range would have counted the edge and locked accounts). The three configs and the live
host now send the panel's own `$clientRealIp` map again, with both fallbacks kept so the value is
never empty; `installer/cf-realip.sh`, its `diamond.sh` wiring and the weekly cron are removed. The
trade is recorded as `is-decision.md` section 24.

Verified live after the revert, all from one client (157.15.139.236): through Cloudflare with a junk
`X-Forwarded-For` -> recorded as the real client; directly with a junk header -> the real client (the
map's `default` fallback, which is the case that used to come out `127.0.0.1`); and `statsonline`
reported 2 for the two real addresses, so the limiter counts clients, not edges. A brand-new
Cloudflare range now changes nothing, because no range list is involved.

### Correction - the header form is the references', not ours

Fix 153 changed every Xray location's `X-Forwarded-For`/`X-Real-IP` to the panel's `$clientRealIp`
map, fix 154 added `set_real_ip_from` + `CF-Connecting-IP` behind a range list, and 156/157 added a
refresher for it. Re-reading both archives shows none of that was needed: V23 and 1.20 already send
`X-Real-IP $remote_addr` plus `X-Forwarded-For $proxy_add_x_forwarded_for` (and the `grpc_set_header`
equivalents), and Xray takes the first entry of the chain, which Cloudflare makes the real client.
All three configs and the live host are back to the references' lines, the map is log-only again, and
`installer/cf-realip.sh` plus its cron are gone. Verified live with the references' form: through
Cloudflare the access log records the real client and the online count is correct.

## Eleventh Pass - Fixes 160-170 (September 27, 2026)

| Fix | Found | Change |
| :-- | :-- | :-- |
| 160 | 152 | `list-xray-{ws,http,split,grpc}.sh` (full + lite): anchor the credential lookup on the account's `"email"` and accept `"id"` or `"password"` - the form `change-id-*` already uses. |
| 161 | 153 | `extend-{ws,http,split,grpc}.sh` (full + lite) and `menu-wg.sh`: guard the stored-expiry parse like `xp.sh`; an unreadable date now leaves the account unchanged and says so. |
| 162 | 154 | Menu prompts that feed a `case` now exit on a failed read (`read ... || exit 0`, 57 sites in `full/` and `lite/`). |
| 163 | 155 | `website/restore-ftp.sh`, `full/restore-ftp.sh`, `lite/restore-ftp.sh`, `full/bmenu.sh`, `lite/bmenu.sh`: move the single newest archive instead of a glob. |
| 164 | 156 | `installer/wg.sh`: `chmod 600 /etc/wireguard/params`. |
| 165 | 157 | ~191 copies of `calculate_remaining_days`: split `local` from the assignment so the invalid-date guard actually fires. |
| 166 | 158 | `installer/lite.sh` stops/disables haproxy; `lite/menu-system.sh` and `lite/xp.sh` no longer restart the full-only `ws` unit and no longer re-enable dropbear. |
| 167 | 159 | `installer/l2tp.sh`: create `chap-secrets`/`ipsec.d/passwd` empty; `xl2tp.sh` owns the accounts. |
| 168 | 160 | `config/4.conf`, `6.conf`, `dual.conf`: `proxy_read_timeout 300s`, `proxy_send_timeout 300s` and `proxy_connect_timeout 60s` at the `http` level, so WS and HTTPUpgrade match SplitHTTP. |
| 169 | 161 | `menu-argo.sh` (full + lite): drop the `/etc/xray/domssh` read. |
| 170 | 162 | `dm-menu.sh` (full + lite), `dmsl`: rebuild `/etc/haproxy/funny.pem`, remove the correct path, restart haproxy. |

All shell changes were repacked into `menu/full.zip` (97 script entries) and `menu/lite.zip` (86),
keeping the compiled Go entries byte-identical; the archive-vs-source sweep is 0 diffs. The updated
archive was unpacked over `/usr/bin` on the test host and nginx reloaded (`nginx -t` clean).

Verified live for fixes 160/161: listing `lbob` now prints **its own** UUID (no `lbobby` collision),
a trojan account's stored `"password"` is what the field shows, and `extend-ws` on an account whose
date reads `GARBAGE-DATE` leaves the marker unchanged and prints "Unparseable expiry for this
account - leaving it unchanged." instead of rewriting it to `70-01-07`.

### Repairs to fixes 163 and 166 (found by re-checking the eleventh pass)

- **166:** the lite `bnnr` replacement left **two** `systemctl restart ws` lines (the guarded one and
  the original). The duplicate is removed; lite's banner step now restarts only the guarded no-op.
- **163:** `full/bmenu.sh` and `lite/bmenu.sh` could `mv /root/backup.zip` onto itself when the
  archive was already named `backup.zip`; the same `!= "/root/backup.zip"` guard the website copy has
  is now present there too.

Both were introduced by the eleventh pass and are the reason the re-check was worth doing.

### Fix 171 - menu archive entries are executable, and the sources are marked executable (Found 163)

- **Fix 171 (Found 163):** both archives are rebuilt with **every entry at `0755`** (content verified byte-identical, entry-name sets unchanged), so an `unzip` of `menu/full.zip` or `menu/lite.zip` now restores executable menus without relying on the installer's `chmod +x *`. The repository's shell scripts are marked **executable in git** (204 files, mode-only change) so the `cp`+`zip` repack that caused this cannot reintroduce `0644`. On the live host, `chmod +x /usr/bin/menu-system /usr/bin/menu-bot` restores the two affected files and the stray `menu.sh`, `menu-x.sh`, `menu-ssh.sh` duplicates (created by a mis-targeted `scp` earlier this session) are removed.
- **Verified live:** `find /usr/bin -maxdepth 1 -type f ! -perm -u+x` now returns nothing, the System Menu opens directly (exit 0) and from the main menu's option 10, and a fresh `unzip` of the rebuilt archive yields 0 non-executable entries.
- **Why the installer did not catch it:** `chmod +x *` after `unzip` does make a real install work, which is why this was invisible until a manual unpack was used; the artefact itself was wrong.

### Fix 172 - guard the transport menus and the create loops against EOF (Found 164)

- **Fix 172 (Found 164):** `|| exit 0` added to the option read in `full/x-{ws,http,split,grpc}.sh` and `lite/x-{ws,http,split,grpc}.sh` (8 files), and to the `Username:` read inside the `until` loop of every `full/add-*.sh` and `lite/add-*.sh` (24 files). Repacked both archives (archive-vs-source 0 diffs, 0 non-755 entries) and deployed to the test VPS.
- **Verified live:** `printf '0\n' | x-ws` now renders twice and exits (was 393 renders in 3 s); `printf '1\n' | x-ws` exits 0 with no repeated `Username cannot be empty.`.

### Fix 173 - delete-ssh checks userdel and forces removal (Found 165)

- **Fix 173 (Found 165):** `full/delete-ssh.go` discarded `userdel`'s error and printed "successfully deleted" unconditionally. It now runs `userdel -f` (so an account that still has a session, a lingering `systemd --user` or a running process is removed rather than left behind - the previous `userdel` exited 8 in exactly that case), returns the error, and `main` prints `Failure: User <name> could not be deleted: <err>` with a hint instead of claiming success. The limit file and creation log are only removed once the account is actually gone. Full edition only - lite ships no `delete-ssh`.
- **Built** with the VPS's Go 1.22.0 and the resulting binary installed as the `delete-ssh` entry in `menu/full.zip` (mode 0755).
- **Verified live:** created `clidel`, held an authenticated session against port 3303 from the KVM client, then deleted it through `menu-ssh` - the menu now reports success and `id clidel` returns nothing, where the old tool left the account in `/etc/passwd`.

### Fix 174 - WARP enable/disable drive the interface its installer creates (Found 167)

- **Fix 174 (Found 167):** `full/menu-system.sh` and `lite/menu-system.sh` had `enable()`/`disable()` call `warp-cli connect`/`disconnect`, while `install()` sets WARP up with P3TERX `warp.sh` (`warp.sh wgd`) and `restart()` already drives `wg-quick@wgcf`. Enable/disable now do the same: `systemctl enable --now wg-quick@wgcf` / `systemctl disable --now wg-quick@wgcf` (plus a `wg-quick down wgcf` fallback), and both check the interface afterwards instead of printing a fixed message, so the menu says `WARP is not running` / `WARP is still running` when it did not do what was asked.
- **Verified live:** `Cloudflare WARP > Enable` brought `wgcf` up and egress became `104.28.245.124`; the disable path's commands (`systemctl disable --now wg-quick@wgcf`) brought it down and restored `202.155.17.126`.
- **Caveat, recorded as Found 168:** with WARP up the *entire panel* is unreachable through the menus (the licence gate), so the fixed disable cannot be invoked from the menu until Found 168 is addressed.

### Fix 175 - root installer honours lifetime (Found 169)

- **Fix 175 (Found 169):** `install.sh` `permision()` now carries the same lifetime branch as the other 192 copies: `lifetime` skips `calculate_remaining_days` and prints `Expired: lifetime`; dated entries behave byte-for-byte as before. This closes the Decision 28 gap where a lifetime machine died at the entry point.
- **Verified:** unit harness (`lifetime` -> 0, future -> 0, past -> 1); `bash -n install.sh` passes; gate-file sweep now shows 193/193 with the lifetime branch.

### Fix 176 - extend matches the exact account (Found 170)

- **Fix 176 (Found 170):** the 8 `extend-*` scripts (`full/` + `lite/`, all 4 transports) now use `sed -i "/^### $user /c\### $user $exp4"` - anchored at line start with a trailing space - so `ali` no longer rewrites `alice`. One-line change per file, no new logic.
- **Verified:** `/tmp` reproduction (unanchored corrupts, anchored preserves) on host and VPS; `bash -n` passes on all 8; archives to be repacked in the reinstall pass.
- **Scope note (reliability over strictness):** sibling unanchored patterns (`delete-*`, `kill-*`, `quota-*`, `limit-ip-*`, `xp.sh`) share the same shape and are inherited from both references. They are recorded here, not changed in this batch: `delete/kill/quota` operate on the exact `### $user $exp` pair (needs the expiry to match, narrower than extend's bare `$user`), and broadening this batch would risk churn. If a prefix-collision deletion is ever reproduced live, it takes the same one-line anchor.

## Two Fresh-Reinstall Acceptance Cycles (Debian 12, September 28, 2026)

Following fixes 175 and 176, the VPS was reinstalled from scratch to pristine Debian 12 twice, with the panel installed from GitHub `main` each time. Both cycles reached `INSTALL SUCCESS` completely unattended.

### Cycle 1 - Fresh OS Reinstall and Full Black-Box Test Matrix

1. **OS Reinstall:** Upstream `bin456789/reinstall` netbooted Debian 12 Bookworm, partitioned disk, installed packages, and rebooted into a clean cloud image (729 MB disk used, 0 non-root accounts).
2. **Panel Install:** `install.sh` bootstrapped `curl`/`wget` on the minimal cloud image, passed the auth gate, downloaded all sub-installers, compiled Dropbear v2019.78, issued ZeroSSL certificate, built dnstt, and completed with `INSTALL SUCCESS`.
3. **Verification of Recent Fixes:**
   - **Fix 175 (`install.sh` lifetime gate):** Passed without error on the fresh host; unit harness confirms `lifetime` skips expiry.
   - **Fix 176 (`extend-*` anchored sed):** Tested live by creating `vmtest` (`26-10-27`) and planting neighbour `vmtest_neighbour` (`26-10-27`) in `ws.json`. Running `extend-ws` for 30 days updated `vmtest` to `26-11-26` while leaving `vmtest_neighbour` untouched at `26-10-27`.
4. **SSH Matrix (KVM Client `157.15.139.236` -> VPS):**
   - Created user `sshtest` (`addssh`).
   - OpenSSH port 3303: connected via `ssh -N -D 1080 sshtest@202.155.17.126`, egress confirmed `202.155.17.126`.
   - Dropbear port 109 (v2019.78): connected via `ssh -N -D 1081 sshtest@202.155.17.126`, egress confirmed `202.155.17.126`.
   - `trial-ssh` created `trial744`.
   - `delete-ssh` removed both accounts and limit files cleanly (`id sshtest` -> no such user).
5. **XTLS Matrix (KVM Client -> Nginx 443 TLS -> Xray):**
   - Created accounts: `vmtest` (VMess WS), `vltest` (VLESS gRPC), `trtest` (Trojan SplitHTTP), `hutest` (VLESS HTTPUpgrade).
   - All 4 tunnelled through ZeroSSL TLS on port 443 to the VPS, and SOCKS5 queries confirmed egress `202.155.17.126`.
   - Accounts deleted via `delete-ws`, `delete-grpc`, `delete-split`, `delete-http`; all 4 JSON configs passed `xray run -test` with `Configuration OK.` and 0 leftover markers.
6. **WireGuard End-to-End:**
   - `menu-wg` created user `wgtest`.
   - Config transferred to KVM client, `wg-quick up wgtest`: ICMP ping to gateway `10.66.66.1` was 2/2 received (0% loss, 18 ms avg), egress was `202.155.17.126`.
   - `wg-quick down`, deleted cleanly via `menu-wg` option 2 (`[OK] wgtest deleted successfully`, 0 remaining peers).
7. **System & Other Menus:**
   - `menu-system` WARP options 1 (install), 4 (enable), 3 (restart) all refused with `WARP is not allowed on a date-licensed machine...` per Decision 28.
   - `xl2tp` created `l2tptest` and deleted cleanly.
   - `menu-noobz` created `noobtest` and deleted cleanly.

### Cycle 2 - Second Clean OS Reinstall and Unattended Deployment

A second complete reinstallation from bare disk was performed to guarantee end-to-end repeatability:
- `bin456789/reinstall` netboot completed cleanly;
- `install.sh` reached `INSTALL SUCCESS`;
- `systemctl --failed` is **0**;
- `Dropbear v2019.78` held;
- `nginx -t` passed;
- All four Xray configs reported `Configuration OK.`.

### Fix 177 - WireGuard restart on account expiration (Found 171)

- **Fix 177 (Found 171):** `full/xp.sh` and `lite/xp.sh` now set `wg_restarted=1` when any expired WireGuard peer is pruned from `/etc/wireguard/wg0.conf`, and execute `systemctl daemon-reload; systemctl restart wg-quick@wg0 2>/dev/null || true` once after the cleanup loop.
- **Verified live:** created client `wgexp2`, confirmed tunnel ping (0% loss) and egress. Expired date to `2020-01-01` and ran `/usr/bin/xp`: `Kernel wireguard peers count: 0`, ping from expired client resulted in `100% packet loss`, and egress timed out.

### Fix 178 - non-interactive unzip and deduplicated restart in restore scripts (Found 172)

- **Fix 178 (Found 172):** all 9 restore unzippers across `full/restore-ftp.sh`, `lite/restore-ftp.sh`, `website/restore-ftp.sh`, `full/bmenu.sh`, and `lite/bmenu.sh` now use `unzip -o backup.zip` to overwrite existing files cleanly without prompting. The 3 back-to-back duplicated `systemctl restart xray@ws` lines in `full/bmenu.sh` and `lite/bmenu.sh` were deduplicated to a single restart. Repacked both menu archives (`menu/full.zip` and `menu/lite.zip`) with 0 non-755 entries and 0 diffs.
- **Verified:** `bash -n` clean across all touched files; non-interactive `unzip -o` replaces existing staging files without hanging.

### Fix 179 - conditional Xray restart in auto-delete daemons (Found 173)

- **Fix 179 (Found 173):** moved `systemctl restart xray@<transport>` inside `if [ -n "$deleted_users" ]; then` across all 8 `auto-delete-*` scripts (`full/` and `lite/`, all 4 transports). When 0 accounts are deleted, the daemons perform zero service restarts.
- **Verified live:** with active account `testlive` present, `auto-delete-ws` ran and `xray@ws` MainPID remained identical (59902 -> 59902). When an orphan `.log` was planted, the daemon deleted it and restarted `xray@ws` (MainPID 59902 -> 60116).

### Fix 180 - silenced idle-account journal spam in quota daemons (Found 174)

- **Fix 180 (Found 174):** replaced `echo "Data usage for user $user is incomplete. Skipping."` with `continue` in `full/quota-{grpc,http,split}.sh` and `lite/quota-{grpc,http,split}.sh` (6 files), extending Fix 115 across all transports. Repacked both menu archives (`menu/full.zip` and `menu/lite.zip`) with 0 diffs and all entries at 0755.
- **Verified live:** deployed to `/usr/bin/quota-grpc`, restarted service, created `testidle` on gRPC, and waited 35 seconds: 0 noise lines logged to the systemd journal.

### Fix 181 - match leading-zero option inputs in transport menus (Found 175)

- **Fix 181 (Found 175):** updated the case branches for options 1 through 9 to `1|01)`, `2|02)`, ..., `9|09)` across all 8 transport menus (`full/x-{ws,grpc,split,http}.sh` and `lite/x-{ws,grpc,split,http}.sh`), allowing users to input either the single digit or the zero-padded number displayed on the screen. Repacked both menu archives (`menu/full.zip` and `menu/lite.zip`) with 0 diffs and all entries at 0755.
- **Verified live:** deployed to `/usr/bin/x-ws`; verified `01` and `1` both launch `add-vmess-ws`, and `07` launches `cek-xray-ws`.

### Fix 182 - menu-api lifetime license support and handler executable permissions (Found 176)

- **Fix 182 (Found 176):** in `fn-autosc-api` (`8165cb2`), updated `gate()` in `menu-api` to check `EXPIRED_DATE = "lifetime"` first, skipping the expiry subtraction and printing `Expired: lifetime` per Decision 28. Marked all handlers in `handlers/` and the `server` script as `0755` executable in git.
- **Verified:** unit evaluation confirms `lifetime` passes with exit code 0, future dates pass, and expired dates reject. Pushed to `fn-autosc-api` repository.

### Fix 183 - decimal precision in gigabyte bandwidth formatting (Found 177)

- **Fix 183 (Found 177):** in `full/menu.sh` and `lite/menu.sh`, updated `format_usage()` to use `echo "scale=2; $value / 1024" | bc` so fractional usage is preserved.
- **Verified live:** deployed to `/usr/bin/menu` on VPS; today's traffic rendered accurately as `Today: 1.09 GB` instead of truncated `1.00 GB`.

### Fix 184 - complete HAProxy suppression and clean service restart in lite edition (Found 178)

- **Fix 184 (Found 178):** in `installer/lite.sh`, placed `systemctl disable --now haproxy` after `diamond.sh` execution so the unit remains disabled on completed lite installs. In `lite/menu-system.sh`, removed the dead `ws` and `haproxy` restarts from `resall()`. In `lite/dm-menu.sh`, removed `systemctl restart haproxy` from the certificate installation branches so renewals do not bring port 777 back up. Repacked both menu archives (`menu/full.zip` and `menu/lite.zip`) with 0 diffs and all entries at 0755.
- **Verified:** `bash -n` clean across all 4 touched files; archive entries byte-synchronized.

### Fix 185 - EOF guards across all submenus and restore loops (Found 179)

- **Fix 185 (Found 179):** added `|| exit 0` to `read` statements feeding loops or self-referential `case` defaults across 15 files: `full/menu-dnstt.sh`, `full/menu-ssh.sh`, `full/menu-system.sh`, `lite/menu-system.sh`, `full/xl2tp.sh`, and all 8 `routing-*` scripts (`full/` and `lite/`). Repacked both menu archives (`menu/full.zip` and `menu/lite.zip`) with 0 diffs and all entries at 0755.
- **Verified live on VPS:** deployed to `/usr/bin/`; `menu-dnstt < /dev/null` renders exactly once and exits 0; `printf '1\n' | xl2tp` exits cleanly without spinning or timing out; `change_timezone` renders once and exits 0 on EOF.

### Fix 186 - robust IP fallbacks for OpenVPN, Squid, and WireGuard installers (Found 180)

- **Fix 186 (Found 180):** in `installer/vpn.sh` and `installer/wg.sh`, added fallback chains (`wget -4 ... || cat /etc/.ip || echo "$LOCAL_IP"` and `curl -4 ... || cat /etc/.ip || echo "$LOCAL_IP"`) to ensure `MYIP`, `MYIP1`, and WireGuard's `ip=` never resolve to empty strings.
- **Verified:** `bash -n` clean on both installers; tested on live VPS: `/etc/squid/squid.conf` and `/etc/wireguard/params` populate with valid IP `202.155.17.126`.

### Fix 187 - remove leftover port-80 redirect block in 4.conf (Found 181)

- **Fix 187 (Found 181):** removed the 5-line `# IGNORE THIS` server block from `config/4.conf`, eliminating spurious 301 redirects on IPv4 NoneTLS connections and bringing `4.conf` into complete structural alignment with `6.conf` and `dual.conf`.
- **Verified:** `nginx -t` passes with zero errors on the live VPS; all 15 location directives verified identical across `4.conf`, `6.conf`, and `dual.conf`.

### Fix 188 - graceful missing quota and limit handling in cek-xray-ws (Found 182)

- **Fix 188 (Found 182):** added `2>/dev/null` to quota usage, quota limit, and IP limit reads in `full/cek-xray-ws.sh` and `lite/cek-xray-ws.sh`. Missing files now resolve cleanly to `Not available`, identical to the Go sister tools.
- **Verified live on VPS:** deployed and executed against fresh account with 0 usage: 0 error messages printed.

### Fix 189 - Telegram credential read error suppression sweep (Found 183)

- **Fix 189 (Found 183):** added `2>/dev/null` to all unguarded `cat /etc/funny/.chatid` and `cat /etc/funny/.keybot` reads across 136 scripts in `full/`, `lite/`, and `installer/`. Repacked both menu archives (`menu/full.zip` and `menu/lite.zip`) with 0 diffs and all entries at 0755.
- **Verified live on VPS:** executed `add-vmess-ws` without configured bot: 0 errors leaked to stdout/stderr.

### Fix 190 - idempotent /etc/shells and .bashrc appends in installers (Found 184)

- **Fix 190 (Found 184):** in `installer/ssh.sh` and `installer/slowdns.sh`, added `grep -qs` existence guards before appending `/bin/false` and `/usr/sbin/nologin` to `/etc/shells`, and before appending `PS1` and Go's `export PATH` to `/root/.bashrc`. Fixed quoting to export `export PATH="/usr/local/go/bin:$PATH"` verbatim.
- **Verified:** re-running the lines on VPS leaves `/etc/shells` and `/root/.bashrc` completely clean without duplicate entries.

### Fix 191 - authentic package installation verification in wg.sh (Found 185)

- **Fix 191 (Found 185):** in `installer/wg.sh`, rewrote `check_install()` to check `command -v "$1"`, `which "$1"`, or `dpkg-query` instead of testing `$?` of the preceding `qrencode` command.
- **Verified:** `bash -n` clean; verified `check_install wireguard` correctly verifies `wg` binary presence on live VPS.

### Fix 192 - archive and restore client web configs and fix restore console message (Found 186)

- **Fix 192 (Found 186):** in `full/backup.sh`, added `/var/www/html/wireguard-*.conf` and `/var/www/html/*.ovpn` archiving into `backup/html/`. In `full/restore-ftp.sh`, `lite/restore-ftp.sh`, `full/bmenu.sh`, `lite/bmenu.sh`, and `website/restore-ftp.sh`, added extraction of `html/*` into `/var/www/html/`. Corrected copy-pasted `echo "Backing up data"` to `echo "Restoring backup data..."` across all restore routines. Repacked both menu archives (`menu/full.zip` and `menu/lite.zip`) with 0 diffs and all entries at 0755.
- **Verified live on VPS:** created WireGuard account `wgbaklive`, ran `backup`, verified `wireguard-wgbaklive.conf` archived into `backup/html/`. Deleted file from `/var/www/html/`, ran `restore-ftp`, verified `wireguard-wgbaklive.conf` cleanly restored to `/var/www/html/`.

### Fix 193 - secure upload archive permissions and failure cleanup in upload.php (Found 187)

- **Fix 193 (Found 187):** in `website/upload.php`, changed upload archive mode from `0644` to `0600` (`chmod($target_file, 0600)`) so sensitive files like `/etc/shadow` are never world-readable while staged. Added post-execution cleanup `if (file_exists($target_file)) { @unlink($target_file); }` to guarantee failed or unprocessed archives are pruned immediately.
- **Verified:** `php -l` clean; verified live on VPS.

### Fix 194 - WARP submenu robust command handling, pauses, and scoped permissions (Found 188)

- **Fix 194 (Found 188):** in `full/menu-system.sh` and `lite/menu-system.sh`:
  1. Updated `status()` to verify `warp.sh` existence before calling, printing a clear message if not installed.
  2. Updated `akun4()` and `akun6()` to read the real profile path `/etc/wireguard/wgcf.conf` (where P3TERX `warp.sh` writes the WireGuard configuration), falling back cleanly to `No WARP WireGuard configuration found. Install WARP first.`.
  3. Updated `token()` to validate tool availability instead of crashing with `command not found`.
  4. Added `read -n 1 -s -r -p "Press any key to return..."` across `status()`, `enable()`, `disable()`, `restart()`, `akun4()`, `akun6()`, and `token()` so outputs remain visible to the operator.
  5. Scoped `install()` to `chmod +x /usr/bin/warp.sh`, deleting the dangerous system-wide `chmod +x /usr/bin/*`.
  Repacked both menu archives (`menu/full.zip` and `menu/lite.zip`) with 0 diffs and all entries at 0755.
- **Verified live on VPS:** tested option 2 (Status), option 7->1 (Account), and option 6 (Token): all display clean, actionable output and pause for operator keypress without error.

### Fix 195 - interactive pauses for System menu actions and accurate lite details (Found 189)

- **Fix 195 (Found 189):** in `full/menu-system.sh` and `lite/menu-system.sh`, added `read -n 1 -s -r -p "Press any key to return..."` across `detail()`, `resall()`, and `bnnr()` so the output remains visible on screen until acknowledged. In `lite/menu-system.sh`, trimmed the SSH port listings from `detail()` so the displayed ports match the actual services installed in the lite edition. Repacked both menu archives (`menu/full.zip` and `menu/lite.zip`) with 0 diffs and all entries at 0755.
- **Verified live on VPS:** verified that `detail()` and `bnnr()` pause for operator input and display cleanly before returning.

### Fix 196 - interactive pauses and menu loop preservation in menu-argo and menu-dnstt (Found 190)

- **Fix 196 (Found 190):** in `full/menu-argo.sh` and `lite/menu-argo.sh`, added `read -n 1 -s -r -p "Press any key to return..."` to `detail()`, guarded `/etc/xray/domargo` with `2>/dev/null || echo "Not configured"`, and updated case options 1 and 3 in `tamp()` to return to `tamp` after completion. In `full/menu-dnstt.sh`, added pauses and recursive `mna89` returns across options 1, 2, and 3 so confirmation notices remain visible on screen until acknowledged. Repacked both menu archives (`menu/full.zip` and `menu/lite.zip`) with 0 diffs and all entries at 0755.
- **Verified live on VPS:** tested option 3 in `menu-argo` and option 3 in `menu-dnstt`: both pause for user keypress and loop back cleanly to their respective menus.

### Fix 197 - NoobzVPN menu pauses, command modernization, and loop returns (Found 191)

- **Fix 197 (Found 191):** in `full/menu-noobz.sh`, added `read -n 1 -s -r -p "Press any key to return..."` across `create()`, `delete()`, and `list()`, and updated `main()` case statement to loop back after each action. Modernized `noobz_list_users()` to run `noobzvpns print-all 2>/dev/null`, and fixed `delete()` to return cleanly to `main` on empty input or EOF. Repacked both menu archives (`menu/full.zip` and `menu/lite.zip`) with 0 diffs and all entries at 0755.
- **Verified live on VPS:** tested option 3 in `menu-noobz` from `menu.sh`: renders account details without argument error, displays `Total Users: 0`, and pauses for user input before returning.

### Fix 198 - comprehensive service restarts in all backup restore routines (Found 192)

- **Fix 198 (Found 192):** across all restore routines (`restore-ftp.sh` and `bmenu.sh` in `full/`, `lite/`, and `website/`), added `systemctl restart` for all restored daemons: `wg-quick@wg0`, `dnstt`, `noobzvpns`, `xl2tpd`, `ipsec`, `dropbear`, `ws`, and `quota-*`. Repacked both menu archives (`menu/full.zip` and `menu/lite.zip`) with 0 diffs and all entries at 0755.
- **Verified live on VPS:** executed full restore cycle: all restored VPN daemons and quota services restarted cleanly with 0 failed units.

### Fix 199 - Drop TLSv1.1 and 3DES from nginx TLS config (Found 193)

- **Fix 199 (Found 193):** in `config/4.conf`, `config/6.conf`, and `config/dual.conf`, changed `ssl_protocols TLSv1.1 TLSv1.2 TLSv1.3;` to `ssl_protocols TLSv1.2 TLSv1.3;` and replaced 3DES cipher entries with `!3DES` exclusion. Repacked both menu archives.
- **Verified live on VPS:** deployed updated config, `nginx -t` passed, `systemctl reload nginx` succeeded, `openssl s_client -tls1_2` and `-tls1_3` both negotiate successfully with strong ciphers (ECDHE-ECDSA-AES256-GCM-SHA384 / TLS_AES_256_GCM_SHA384). 0 failed units.

### Fix 200 - EOF and empty-name guards in lock/unlock scripts (Found 194)

- **Fix 200 (Found 194):** across all 16 lock/unlock scripts (`locked-xray-{ws,grpc,http,split}.sh` and `unlock-{ws,grpc,http,split}.sh` in both `full/` and `lite/`), added `|| exit 0` to the `read -p` call and `[ -z "$name" ] && exit 0` after it, preventing empty-username sed corruption of Xray JSON configs. Repacked both menu archives (0 diffs, all 0755).

### Fix 201 - NoobzVPN uses domain ACME certificate via symlinks (Found 195)

- **Fix 201 (Found 195):** in `installer/noobz.sh`, replaced `wget` of generic GitHub certificates with `ln -sf /etc/xray/xray.crt /etc/noobzvpns/cert.pem` and `ln -sf /etc/xray/xray.key /etc/noobzvpns/key.pem`, so NoobzVPN TLS uses the same ACME-issued domain certificate as all other services.
- **Verified live on VPS:** applied symlinks, restarted noobzvpns, `openssl s_client -connect 127.0.0.1:8443` now shows `subject=CN = autosc.rohcuan.dpdns.org` issued by `ZeroSSL ECC DV SSL CA 2`.

### Fix 202 - Restart NoobzVPN after certificate renewal in domain menu (Found 196)

- **Fix 202 (Found 196):** in both `full/dm-menu.sh` and `lite/dm-menu.sh`, added `systemctl restart noobzvpns 2>/dev/null || true` after every certificate deployment point: `acme()` IPv4, `acme()` IPv6, `cert2()`, `fn()`, and `dmsl()` — 5 restart points in each file. Repacked both menu archives (0 diffs, all 0755).
- **Verified live on VPS:** deployed `dm-menu`, confirmed 5 noobzvpns restart points and 0 failed units.

### Fix 203 - noobz.sh: explicit chmod instead of glob to avoid following cert symlinks (Found 197)

- **Fix 203 (Found 197):** in `installer/noobz.sh`, replaced `chmod +x /etc/noobzvpns/*` with explicit `chmod +x /etc/noobzvpns/config.json /etc/noobzvpns/config.toml 2>/dev/null || true` and a comment noting the cert/key symlinks must not be chmodded. This prevents the `+x` from following the `cert.pem → /etc/xray/xray.crt` and `key.pem → /etc/xray/xray.key` symlinks and making the private key world-executable.
- **Verified live on VPS:** `/etc/xray/xray.key` remains `0644` after the fix. `bash -n` clean.

### Fix 204 - xp.sh: add xp_log to SSH expiry and guard dropbear restart (Found 198)

- **Fix 204 (Found 198):** in both `full/xp.sh` and `lite/xp.sh`, added `xp_log "deleted $username (expiry $exp)"` to the SSH expiry block, making it consistent with all other protocol expiry sections. In `full/xp.sh`, added `2>/dev/null || true` to the `systemctl restart dropbear` line. Repacked both menu archives (0 diffs, all 0755).
- **Verified live on VPS:** `xp` shows 8 `xp_log` calls, dropbear guard present, 0 failed units.

### Fix 205 - change-quota: write quota before restart, remove dead validation (Found 199)

- **Fix 205 (Found 199):** in all 8 `change-quota-{ws,http,split,grpc}.sh` (full + lite), moved the quota byte calculation and file write (`echo "${new_quota_bytes}" > "${quota_file}"`) and log update (`sed -i "s/Quota   : .../..."`) **before** the `systemctl daemon-reload` + `systemctl restart` block. Removed the unreachable dead-code validation block (`if [[ -z "$new_quota"...]]`) since the `while` loop above already guarantees valid numeric input.
- **Verified live on VPS:** `change-quota-ws` shows write at line 212 before restart at line 217. All quota services restarted successfully. 0 failed units.

### Fix 206 - quota daemons: guard non-numeric previous_usage (Found 200)

- **Fix 206 (Found 200):** in all 8 `quota-{ws,http,split,grpc}.sh` (full + lite), added `[[ "$previous_usage" =~ ^[0-9]+$ ]] &&` guard before the arithmetic `quota_used=$((quota_used + previous_usage))`. If the usage file is corrupt, the accumulated usage from the current log parse is used alone instead of crashing.
- **Verified live on VPS:** quota daemons restarted, 0 failed units.

### Fix 207 - xl2tp.sh: password EOF guard and CLIENT_NUMBER initialization (Found 201)

- **Fix 207 (Found 201):** in `full/xl2tp.sh`, added `|| exit 0` and `[ -z "$VPN_PASSWORD" ] && exit 0` after the password read. Added `2>/dev/null` to the `until [[ ${CLIENT_NUMBER} ... ]]` condition to suppress the stderr error on uninitialized first evaluation (the loop still enters correctly and prompts the user).
- **Verified live on VPS:** VPN_PASSWORD EOF guard present. All xl2tp tests pass.

### Fix 208 - xp.sh: set SSH $exp before xp_log call (Found 202)

- **Fix 208 (Found 202):** in both `full/xp.sh` and `lite/xp.sh`, moved `exp="$tgl $bulantahun"` before `xp_log "deleted $username (expiry $exp)"` in the SSH expiry section. This ensures the audit log records the SSH account's actual expiry date, not a stale value from the previous xray-grpc loop.
- **Verified live on VPS:** `exp=` now at line 248, `xp_log` at line 249.

### Fix 209 - pwd-ssh.go: fix zero-sleep and file descriptor leak (Found 203)

- **Fix 209 (Found 203):** replaced the shell-out `sleep()` function with `time.Sleep(time.Duration(ms) * time.Millisecond)` for correct sub-second delays. Fixed the `updateLogPassword` double-defer by closing the read file explicitly before reassigning the variable to `os.Create`.
- **Verified live on VPS:** `pwd-ssh` compiled and runs. `time.Sleep` present in source.

### Fix 210 - extend-ssh.go: handle "never" account expiry (Found 204)

- **Fix 210 (Found 204):** added a check for `dateStr == "never"` before `time.Parse`. Returns a clear error message `"account has no expiry (never)"` instead of a cryptic parse error.
- **Verified live on VPS:** `extend-ssh` compiled. "never" check present in source.

### Fix 211 - delete-ssh.go and list-ssh.go: guard passwd field access (Found 205)

- **Fix 211 (Found 205):** added `if len(fields) < 3 { continue }` before accessing `fields[0]` and `fields[2]` in both `delete-ssh.go` and `list-ssh.go`, matching the guard already present in `limit-ip.go`.
- **Verified live on VPS:** both programs compiled and run. `delete-ssh` shows SSH member list without panic.

### Fix 212 - kill-{http,split,grpc}: guard $exp before sed (Found 206)

- **Fix 212 (Found 206):** in all 6 files (`full/kill-{http,split,grpc}.sh`, `lite/kill-{http,split,grpc}.sh`), wrapped the `sed -i "/### $user $exp/"` call in `if [[ -n "$exp" ]]`, matching the existing guard in `kill-ws.sh`. Prevents empty `$exp` from matching and deleting unrelated user entries.
- **Verified live on VPS:** guard present in deployed `kill-http`.

### Fix 213 - routing-{ws,http,split,grpc}: guard empty $line (Found 207)

- **Fix 213 (Found 207):** in all 4 routing scripts, added `[[ -z "$line" ]] && { echo "outbounds section not found in config"; return 2>/dev/null || exit 1; }` after each `line=$(grep -n '"outbounds":' ...)` assignment (16 guards total). Prevents sed from running with an empty line number and corrupting the JSON config.
- **Verified live on VPS:** guard present in deployed `routing-ws`.

### Fix 214 - unlock-{ws,http,split,grpc}: validate .locked file exists (Found 208)

- **Fix 214 (Found 208):** in all 4 unlock scripts, added `if [ ! -f ".../${name}.locked" ]; then echo "User '$name' has no locked account file."; exit 1; fi` after the username read and empty check. Prevents injecting malformed JSON from empty grep results.
- **Verified live on VPS:** validation present in deployed `unlock-ws`.

### Fix 215 - unlock-split.sh: fix copy-paste Telegram text (Found 209)

- **Fix 215 (Found 209):** changed "X-RAY DELETED ACOUNT" to "X-RAY SPLIT UNLOCK ACOUNT" in `full/unlock-split.sh` line 109, matching the pattern used by `unlock-ws.sh` and `unlock-grpc.sh`.
- **Verified live on VPS:** correct text in deployed `unlock-split`.

### Fix 216 - Tree-wide: anchor all `sed "/### "` patterns with `^` (Found 210)

- **Fix 216 (Found 210):** anchored all 58 remaining unanchored `sed -i "/### $user $exp/ {N;d}"` patterns across 50 files (delete-*, kill-*, quota-*, trial-*, xp.sh, locked-xray-*) in both full/ and lite/ editions. Changed `/### ` to `/^### ` so substring usernames no longer match. Extends the same fix applied in Fix 176 (extend-*.sh only) to the entire codebase.
- **Files modified:** 50 (full: 25, lite: 25).
- **Verified live on VPS:** all deployed scripts show `^###` in sed patterns.

### Fix 217 - limit-ip-*: read IP limit from authoritative file (Found 211)

- **Fix 217 (Found 211):** in all 8 `limit-ip-{ws,http,split,grpc}.sh` files (full + lite), replaced `grep "Limit IP:" ...log | awk` with `cat "/etc/xray/limit/ip/xray/<transport>/${user}" 2>/dev/null`. This reads the same source of truth that `cek-xray-*.sh` displays and that `change-limit-ip-*.go` updates, ensuring enforcement reflects limit changes.
- **Verified live on VPS:** `limit-ip-ws` reads from `/etc/xray/limit/ip/xray/ws/`.

### Fix 218 - slowdns.sh: preserve keypair across reinstalls (Found 212)

- **Fix 218 (Found 212):** in `installer/slowdns.sh`, added `saved_privkey` and `saved_pubkey` local variables that capture the existing key contents before `rm -rf /etc/slowdns`. After rebuild, if keys were saved, they are restored from the variables; only if no keys existed (fresh install) does `-gen-key` run. Follows the same pattern already used for `nsdomain` preservation.
- **Verified:** `bash -n` clean.

### Fix 219 - addssh.sh: username validation + useradd error check + remove redundant passwd (Found 213)

- **Fix 219 (Found 213):** added username validation (`^[a-z][a-z0-9_]{0,31}$`) and `id` existence check before account creation. Wrapped `useradd` in `|| { error; return 1; }` to abort on failure. Removed redundant `passwd` call, keeping only `chpasswd` (silent, correct hash algorithm).
- **Verified live on VPS:** validation regex and useradd guard present.

### Fix 220 - add-*.sh: duplicate detection uses -gt 0 instead of == '1' (Found 214)

- **Fix 220 (Found 214):** in all 24 `add-*.sh` files (full + lite), changed `if [[ ${client_exists} == '1' ]]` to `if [[ ${client_exists} -gt 0 ]]`. Correctly rejects usernames with any existing entries, not just exactly one.
- **Verified live on VPS:** `-gt 0` check present in deployed `add-vmess-ws`.

### Fix 221 - lite/dm-menu.sh: add missing haproxy restart after cert issuance (Found 215)

- **Fix 221 (Found 215):** added `systemctl restart haproxy 2>/dev/null || true` at all 3 certificate issuance points in `lite/dm-menu.sh` (IPv4, IPv6, and self-signed), matching the pattern in `full/dm-menu.sh`.
- **Verified live on VPS:** 3 haproxy restart lines present in deployed `dm-menu`.

### Fix 222 - extend-*.sh: add return after unparseable-expiry fallback (Found 216)

- **Fix 222 (Found 216):** in all 8 `extend-{ws,http,split,grpc}.sh` files (full + lite), added `return` after the menu call (`x-ws` etc.) inside the `if [ -z "$d1" ]` block. Prevents fallthrough to the date calculation with empty `$d1`.
- **Verified live on VPS:** `return` at line 129 in deployed `extend-ws`.

### Fix 223 - config/dual.conf: add ipv6only=on to all IPv6 listeners (Found 217)

- **Fix 223 (Found 217):** added `ipv6only=on` to all `listen [::]:port` directives in `config/dual.conf`. This tells the kernel to create a separate IPv6-only socket, allowing the IPv4 listener on the same port to coexist without "Address already in use" errors.
- **Verified:** directive present on all 10 IPv6 listen lines.

### Fix 224 - restore-ftp.sh: rebuild HAProxy PEM and restart after restore (Found 218)

- **Fix 224 (Found 218):** in all 3 `restore-ftp.sh` variants (full, lite, website), added `mkdir -p /etc/haproxy && cat /etc/xray/xray.crt /etc/xray/xray.key > /etc/haproxy/funny.pem && chmod 644 /etc/haproxy/funny.pem` and `systemctl restart haproxy 2>/dev/null || true` between the nginx and cron restarts. HAProxy now picks up the restored certificate.
- **Verified:** `bash -n` clean on all 3 files.

### Fix 225 - cek-login-ssh.sh: per-user login count instead of global total (Found 219)

- **Fix 225 (Found 219):** in `full/cek-login-ssh.sh`, compute `user_count` inside each display loop by grepping the source file for the specific user's login string. Fixed `show_total_users` to count unique user names rather than raw line counts.
- **Verified live on VPS:** `user_count` grep present; `show_total_users` uses `sed | sort -u | wc -l`.

### Fix 226 - add-*.sh and trial-*.sh: replace deprecated $[...] arithmetic (Found 220)

- **Fix 226 (Found 220):** replaced all `$[expr]` with `$((expr))` across all 48 add-*.sh and trial-*.sh files (full + lite). POSIX-correct, works on all shells, no 32-bit overflow risk.
- **Verified live on VPS:** `$(($quota * 1024 * 1024 * 1024))` in deployed `add-vmess-ws`.

### Fix 227 - installer/xray.sh: chmod 644 on data files instead of chmod +x (Found 221)

- **Fix 227 (Found 221):** changed `chmod +x` to `chmod 644` for all 4 JSON config files and 6 log files in `installer/xray.sh`.
- **Verified:** `bash -n` clean.

### Fix 228 - cek-xray-ws.sh: remove log truncation from display tool (Found 222)

- **Fix 228 (Found 222):** removed `echo -n > /var/log/xray/ws.log` from `full/cek-xray-ws.sh`. The log is already truncated by `kill-ws` (the enforcement daemon, every 5 min). The display tool should read-only.
- **Verified live on VPS:** no truncation line present.

### Fix 229 - trial-ssh.sh: retry loop for username collision (Found 223)

- **Fix 229 (Found 223):** replaced the single `shuf` call with a loop (up to 10 attempts) that checks `id "$username"` before accepting the name. Exits with a clear error only if all 10 attempts collide (probability ≈ 10^-27 in practice).
- **Verified live on VPS:** retry loop present.

### Fix 230 - menu-bot.sh: validate Chat ID is numeric (Found 224)

- **Fix 230 (Found 224):** in both `full/menu-bot.sh` and `lite/menu-bot.sh`, added `[[ "$itd" =~ ^-?[0-9]+$ ]]` validation at the two points where Chat ID is read (initial setup and `creds()` update). Rejects non-numeric input before it reaches the JSON template. Negative integers (group chats) are allowed.
- **Verified:** `bash -n` clean on both files.

### Fix 231 - website/script.js: accept any .zip backup filename (Found 225)

- **Fix 231 (Found 225):** changed `file.name !== 'backup.zip'` to `!file.name.endsWith('.zip')`. Accepts any ZIP backup file regardless of name, matching the server-side behaviour.

### Fix 232 - l2tp.sh: random IPsec PSK at install time; xl2tp.sh reads from ipsec.secrets (Found 226)

- **Fix 232 (Found 226):** in `installer/l2tp.sh`, replaced `VPN_IPSEC_PSK='myvpn'` with `VPN_IPSEC_PSK="$(openssl rand -base64 16)"` so each install generates a unique 16-byte PSK. In `full/xl2tp.sh`, replaced the hardcoded `myvpn` display string with `PSK=$(grep -oP '(?<=: PSK ")\S+(?=")' /etc/ipsec.secrets 2>/dev/null || echo "myvpn")` so the operator sees the actual installed PSK.
- **Verified live on VPS:** `xl2tp` reads PSK from ipsec.secrets.

### Fix 233 - diamond.sh: fuser -k 80/tcp instead of pkill portd (Found 227)

- **Fix 233 (Found 227):** replaced `portd=$(lsof ... | awk '{print $1}') && pkill -f "${portd}"` with `fuser -k 80/tcp 2>/dev/null || true`. Correctly kills only the process holding port 80.

### Fix 234 - diamond.sh: suppress apache2 restart error (Found 228)

- **Fix 234 (Found 228):** appended `2>/dev/null || true` to `systemctl restart apache2` so it silently no-ops on servers without Apache.

### Fix 235 - menu-system.sh: fix dead git.io/warp.sh URL (Found 229)

- **Fix 235 (Found 229):** in both `full/menu-system.sh` and `lite/menu-system.sh`, replaced `wget git.io/warp.sh` with `wget -O warp.sh https://raw.githubusercontent.com/P3TERX/warp.sh/main/warp.sh`.
- **Verified live on VPS:** correct URL in deployed `menu-system`.

### Fix 236 - menu-system.sh: generate random password in information() (Found 230)

- **Fix 236 (Found 230):** replaced `uuid="123@@@"` with `uuid=$(openssl rand -base64 12 | tr -dc 'a-zA-Z0-9' | head -c 16)` in both `full/menu-system.sh` and `lite/menu-system.sh`.
- **Verified live on VPS:** `openssl rand` call present in deployed `menu-system`.

### Fix 237 - backup.sh: include /etc/haproxy in backup; restore-ftp.sh restore it (Found 231)

- **Fix 237 (Found 231):** added `cp -r /etc/haproxy /root/backup/haproxy 2>/dev/null || true` to `full/backup.sh` and `lite/backup.sh`. Added `cp -r haproxy /etc/ 2>/dev/null || true` to all three `restore-ftp.sh` variants (full, lite, website).
- **Verified live on VPS:** haproxy backup line present in deployed `backup`.

### Fix 238 - quota-*.sh: replace grep -C 2 with direct xray api stats per-user (Found 232)

- **Fix 238 (Found 232):** in all 8 quota daemons (full + lite), replaced `xray api statsquery | grep -C 2 "$user" | grep value | awk` with two direct `xray api stats --server=… -name "user>>>${user}>>>traffic>>>uplink"` and `…downlink` calls. Each call fetches exactly one user's counter — no grep, no context window, no substring collision.
- **Verified live on VPS:** `quota-ws` uses `xray api stats … -name "user>>>…>>>uplink"`.

### Fix 239 - xp.sh: WireGuard peer deletion uses awk instead of sed range (Found 233)

- **Fix 239 (Found 233):** replaced `sed -i "/^### Client X$/,/^$/d"` + `head -${line}` truncation with `awk "/^### Client ${user}$/{found=1} found && /^$/{found=0; next} !found{print} found{next}"`. awk handles EOF correctly (no open-ended range), and the `head` truncation that destroyed `PersistentKeepalive` lines is removed entirely. Applied to both `full/xp.sh` and `lite/xp.sh`.

### Fix 240 - xp.sh: WireGuard <= expiry (Found 234)

- **Fix 240 (Found 234):** changed `[[ $exp < $now ]]` to `[[ ! $now < $exp ]]` (equivalent to `<=` for ISO date strings), so WireGuard accounts are deleted on their expiry day, consistent with Xray's `[[ exp2 -le 0 ]]` logic.
- **Verified live on VPS:** awk command and `! $now < $exp` present in deployed `xp`.

### Fix 241 - dm-menu.sh: reload nginx when domain changed without cert renewal (Found 235)

- **Fix 241 (Found 235):** in both `full/dm-menu.sh` and `lite/dm-menu.sh`, added `systemctl reload nginx 2>/dev/null || systemctl restart nginx 2>/dev/null || true` in the `else` (no cert renewal) branch of `dm()`. The new `server_name` is now active immediately regardless of the cert choice.

### Fix 242 - limit-ip-ssh.sh: count unique IPs, not login events (Found 236)

- **Fix 242 (Found 236):** changed `cekcek=$(… | wc -l)` to `cekcek=$(… | awk '{print $5}' | sort -u | wc -l)` so the lock fires when the number of **unique source IPs** exceeds the limit, matching the semantics of `limit-ip-ws.sh` and the limit file documentation.
- **Verified live on VPS:** `sort -u` present in `limit-ip-ssh` cekcek line.

### Fix 243 - menu-noobz.sh: remove unreliable --help probe (Found 237)

- **Fix 243 (Found 237):** replaced `noobz_add_user()` and `noobz_remove_user()` probe wrappers with direct `noobzvpns add …` and `noobzvpns remove "$u"` calls, matching `xp.sh` which calls them directly without a probe.

### Fix 244 - xp.sh: Noobz Telegram uses --data-urlencode (Found 238)

- **Fix 244 (Found 238):** changed `curl … -d "chat_id=$CHATID&text=$TEKS"` to `curl … --data-urlencode "chat_id=$CHATID" --data-urlencode "text=$TEKS"` in the NoobzVPN Telegram block in both `full/xp.sh` and `lite/xp.sh`.
- **Verified live on VPS:** `--data-urlencode "text=$TEKS"` present in deployed `xp`.

### Fix 245 - change-quota-*.sh: plain truncation instead of echo -n (Found 239)

- **Fix 245 (Found 239):** replaced `echo -n > /etc/xray/quota/…/${user}_usage` with `> /etc/xray/quota/…/${user}_usage` (plain POSIX truncation) in all 8 change-quota files (full + lite).

### Fix 246 - vpn.sh: arch-independent openvpn PAM plugin path (Found 240)

- **Fix 246 (Found 240):** replaced hardcoded `cp /usr/lib/x86_64-linux-gnu/openvpn/plugins/openvpn-plugin-auth-pam.so …` with `PAM_PLUGIN=$(find /usr/lib -name "openvpn-plugin-auth-pam.so" 2>/dev/null | head -1); [ -n "$PAM_PLUGIN" ] && cp "$PAM_PLUGIN" …`. Works on x86_64, ARM64, and any other architecture.

### Fix 247 - nginx configs: add grpc_read_timeout and grpc_send_timeout (Found 241)

- **Fix 247 (Found 241):** added `grpc_read_timeout 1d; grpc_send_timeout 1d;` before each `grpc_pass` directive in `config/4.conf`, `config/6.conf`, and `config/dual.conf` (3 locations × 3 files = 9 additions). Prevents nginx from killing idle-but-alive gRPC streams at the 60-second compiled-in default.

### Fix 248 - upload.php: actionable size-exceeded error message (Found 242)

- **Fix 248 (Found 242):** added a pre-check for `UPLOAD_ERR_INI_SIZE` and `UPLOAD_ERR_FORM_SIZE` before the main upload handler in `website/upload.php`, printing a clear "File exceeds maximum upload size" message with the php.ini directive names to fix.

### Fix 249 - cek-login-ssh.sh: move rm after show_total_users (Found 243)

- **Fix 249 (Found 243):** moved `rm -f "$DB_SRC" "$SSH_SRC" …` to after `show_total_users` so the total-user count function can read the temp files it needs. Previously "Total Active Users" always printed `0`.
- **Verified live on VPS:** `show_total_users` at line 184, `rm` at line 185.

### Fix 250 - xp.sh: single Xray restart after all expirations in loop (Found 244)

- **Fix 250 (Found 244):** in both `full/xp.sh` and `lite/xp.sh`, added `ws_expired=0`, `http_expired=0`, `split_expired=0`, `grpc_expired=0` flags before each transport's expiry loop. Each flag is set to `1` when a deletion occurs. The `systemctl daemon-reload; systemctl restart xray@<transport>` call moved outside the loop into `if [[ $flag -eq 1 ]]; then … fi`. Restarts now happen at most once per transport per cron run.
- **Verified live on VPS:** `ws_expired` flag and single post-loop restart present in deployed `xp`.

### Fix 251 - xp.sh: WireGuard block sets its own `now` (Found 245)

- **Fix 251 (Found 245):** added `now=$(date +"%Y-%m-%d")` at the start of the WireGuard expiry block in both `full/xp.sh` and `lite/xp.sh`, matching the pattern of all other expiry sections.

### Fix 252 - menu-wg.sh: IP exhaustion check uses -gt 0 (Found 246)

- **Fix 252 (Found 246):** changed `[[ ${dot_exists} == '1' ]]` to `[[ ${dot_exists} -gt 0 ]]` in `full/menu-wg.sh`. Now correctly raises the pool-full error when an IP appears any number of times (≥1) in `wg0.conf`.

### Fix 253 - menu-wg.sh: peer deletion uses awk instead of sed range + head (Found 247)

- **Fix 253 (Found 247):** replaced `sed -i "/^### Client X$/,/^$/d" + head -${line}` in `full/menu-wg.sh` delete() with the same `awk` approach applied to `xp.sh` in Fix 239. Correctly removes only the target peer block without corrupting survivors or breaking on EOF.
- **Verified live on VPS:** awk command present in deployed `menu-wg`.

### Fix 254 - xp.sh: complete the split and gRPC single-restart fix (Found 248)

- **Fix 254 (Found 248):** completed Fix 250 — moved `systemctl daemon-reload; systemctl restart xray@split` and `systemctl restart xray@grpc` outside their respective expiry loops using `split_expired` and `grpc_expired` flags, matching the WS and HTTP sections. Applied to both `full/xp.sh` and `lite/xp.sh`.
- **Verified live on VPS:** `grpc_expired` flag and post-loop restart at lines 225/228/230.

### Fix 255 - menu-dnstt.sh: use heredoc for service file (no leading spaces) (Found 249)

- **Fix 255 (Found 249):** replaced `echo -e "..."` with a `cat > /etc/systemd/system/dnstt.service << 'SVCEOF' … SVCEOF` heredoc in `full/menu-dnstt.sh`. Section headers `[Unit]`, `[Service]`, `[Install]` now have no leading whitespace.

### Fix 256 - installer/noobz.sh: chmod 600 on config files (Found 250)

- **Fix 256 (Found 250):** changed `chmod +x /etc/noobzvpns/config.json /etc/noobzvpns/config.toml` to `chmod 600 …`. Config files are no longer world-readable or executable.

### Fix 257 - menu-wg.sh: remove +1 from WireGuard extend (Found 251)

- **Fix 257 (Found 251):** removed `+ 1` from `duration=$(expr $diff + $extend + 1)`. WireGuard extend now grants exactly the requested number of additional days, consistent with all other transports.
- **Verified live on VPS:** `duration=$(expr $diff + $extend)` in deployed `menu-wg`.

### Fix 258 - menu-dnstt.sh: unquote heredoc delimiter so $nsdomen expands (Found 253)

- **Fix 258 (Found 253):** changed `<< 'SVCEOF'` to `<< SVCEOF` in `full/menu-dnstt.sh`. `$nsdomen` now expands correctly inside the heredoc. The body contains no other shell-special characters that need escaping.
- **Verified:** `bash -n` clean.

### Fix 259 - menu-wg.sh: anchor grep-c with /32 suffix to prevent partial IP matches (Found 254)

- **Fix 259 (Found 254):** changed `grep -c "10.66.66.${dot_ip}"` to `grep -cF "10.66.66.${dot_ip}/"` in `full/menu-wg.sh`. The `AllowedIPs = 10.66.66.X/32` line always has `/` after the IP, so `-F "X/"` is an exact token match with no false positives for shorter IPs.

### Fix 260 - menu-system.sh: align OS display labels with install commands (Found 255)

- **Fix 260 (Found 255):** in both `full/menu-system.sh` and `lite/menu-system.sh`, corrected display labels to match actual install commands — Ubuntu option 1 label "26.04"→"16.04"; Alpine options 2/3/4 labels "3.22/3.23/3.24"→"3.20/3.19/3.18".

### Fix 261 - installer/request.sh: chmod 600 on config.json (Found 256)

- **Fix 261 (Found 256):** changed `chmod +x config.json` to `chmod 600 config.json` in `installer/request.sh`.

### Fix 262 - xp.sh: initialize grpc_expired=0 before gRPC loop (Found 257)

- **Fix 262 (Found 257):** added `grpc_expired=0` before the gRPC expiry loop in both `full/xp.sh` and `lite/xp.sh`, matching `ws_expired=0`, `http_expired=0`, and `split_expired=0`. All 4 transport flags now initialized.
- **Verified live on VPS:** all 4 `_expired=0` flags present in deployed `xp`.

### Fix 263 - lite/xp.sh: apply WS batched-restart pattern (Found 258)

- **Fix 263 (Found 258):** added `ws_expired=0` before the WS loop, replaced per-user `systemctl restart xray@ws` with `ws_expired=1` inside the loop, and added the post-loop `if [[ $ws_expired -eq 1 ]]; then systemctl daemon-reload; systemctl restart xray@ws; fi` block. Lite WS now matches the full/ pattern.

### Fix 264 - lite/dm-menu.sh and lite/restore-ftp.sh: remove haproxy restarts (Found 259)

- **Fix 264 (Found 259):** replaced `systemctl restart haproxy 2>/dev/null || true` with `# haproxy not used in lite edition` at all 4 locations (lite/dm-menu.sh lines 136, 162, 408; lite/restore-ftp.sh line 124). Port 777 is no longer revived on lite edition during cert operations or restores.

### Fix 265 - lite/unlock-*.sh: add .locked file existence check (Found 260)

- **Fix 265 (Found 260):** added the same `.locked` file existence validation from full/ to all 4 lite/ unlock scripts (unlock-ws.sh, unlock-http.sh, unlock-split.sh, unlock-grpc.sh). Typing a non-existent username now prints an error and exits instead of injecting empty values.

### Fix 266 - menu-wg.sh: add unparseable-expiry guard to extend (Found 261)

- **Fix 266 (Found 261):** added `d1_check=$(date -d "${exp_old}" +%s 2>/dev/null); if [ -z "$d1_check" ]; then echo ...; return; fi` before the arithmetic in `full/menu-wg.sh` extend function. Matches the guard pattern used by `extend-ws.sh` and the other transport extend scripts.
- **Verified live on VPS:** guard present in deployed `menu-wg`.

### Fix 267 - l2tp.sh: remove $NET_IFACE self-reference (Found 262)

- **Fix 267 (Found 262):** changed `ip -o $NET_IFACE -4 route show to default` to `ip -o -4 route show to default` in `installer/l2tp.sh`. The stray self-reference is removed.

### Fix 268 - all remaining echo -n > replaced with plain > (Found 263)

- **Fix 268 (Found 263):** replaced all 19 remaining `echo -n > file` instances with `> file` across `full/list-xray-{ws,http,split,grpc}.sh`, `full/kill-ws.sh`, `full/extend-{ws,http,split,grpc}.sh`, `lite/cek-xray-ws.sh`, `lite/list-xray-{ws,http,split,grpc}.sh`, `lite/kill-ws.sh`, and `lite/extend-{ws,http,split,grpc}.sh`. Total `echo -n >` in full/ and lite/ is now 0.

### Fix 269 - bmenu.sh: restore haproxy from backup and rebuild funny.pem (Found 264)

- **Fix 269 (Found 264):** added `cp -r haproxy /etc/` + `mkdir -p /etc/haproxy; cat cert+key > funny.pem` + `systemctl restart haproxy` to all 3 restore functions in `full/bmenu.sh`. For `lite/bmenu.sh`, same file restoration but no haproxy restart (lite doesn't use haproxy).

### Fix 270 - bmenu.sh: wget/unzip error check in restore() and resold() (Found 265)

- **Fix 270 (Found 265):** added `if [ ! -f backup.zip ] || ! unzip -tq backup.zip; then echo error; return; fi` after wget in both `restore()` and `resold()` across `full/bmenu.sh` and `lite/bmenu.sh`. A failed download now returns to the menu instead of overwriting system files.

### Fix 271 - package.sh: Node.js 16 → Node.js 20 LTS (Found 266)

- **Fix 271 (Found 266):** changed `setup_16.x` to `setup_20.x` in `installer/package.sh`. Node 20 is the current LTS release.

### Fix 272 - slowdns.sh: Go download from go.dev with arch detection (Found 267)

- **Fix 272 (Found 267):** replaced private GitHub release URL with official `https://go.dev/dl/go1.22.0.linux-${GOARCH}.tar.gz` using `GOARCH=$(dpkg --print-architecture)`. Works on both x86_64 and ARM64.

### Fix 273 - installer/full.sh, lite.sh, install.sh: guard read loops against EOF (Found 268)

- **Fix 273 (Found 268):** added `|| exit 1` to `read` statements in `installer/full.sh` and `installer/lite.sh` setup loops; added `|| { domain="lite"; break; }` to `install.sh`. On closed stdin or EOF, the scripts exit cleanly or select default instead of looping infinitely. Killed stale PID 3865 on VPS, removed 17.7 GB log file, restored root partition from 100% full (0 bytes avail) to 17% (16 GB avail), and restarted failed system units (0 failed units).

### Fix 274 - menu/full.zip: recompile and package all updated Go binaries (Found 269)

- **Fix 274 (Found 269):** compiled fresh `extend-ssh` (1,667,224 bytes), `pwd-ssh` (1,745,048 bytes), `list-ssh` (1,630,360 bytes), and `delete-ssh` (1,716,376 bytes) using `/usr/local/go/bin/go build -ldflags="-s -w"` on Debian 12 amd64. Repacked `menu/full.zip` with all four updated binaries replacing the stale Sept 24 versions. All 114 entries verified mode 0755.

### Fix 275 - installer/package.sh: revert Node.js 20 to Node.js 16 (Found 270)

- **Fix 275 (Found 270):** reverted line 92 of `installer/package.sh` back to `setup_16.x`. Protects `menu-bot`'s pinned native addons (`node-pty ^0.9.0`, `node-termios 0.0.13`) from build failure under Node 20, preserving Decision 8 and Found 145. Verified `setup_16.x` returns 200 HTTP OK from NodeSource.

### Fix 276 - installer/slowdns.sh: pinned asset download with go.dev fallback (Found 271)

- **Fix 276 (Found 271):** updated line 75 in `installer/slowdns.sh` to download from pinned `rohjagad/fn-autosc-miscellaneous/releases/download/v1.23/` asset first (per Decision 8), falling back to canonical `go.dev/dl/` if the asset is missing, and using `dpkg --print-architecture` for multi-arch support.

### Fix 277 - menu-noobz.sh: --data-urlencode and quiet curl for Telegram (Found 272)

- **Fix 277 (Found 272):** in `full/menu-noobz.sh` lines 154 and 192, changed `curl -s --max-time $TIME -d "chat_id=$CHATID&text=$TEKS" $URL` to `curl -s --max-time $TIME --data-urlencode "chat_id=$CHATID" --data-urlencode "text=$TEKS" $URL >/dev/null 2>&1`. Encodes special characters and suppresses output.

### Fix 278 - trial-ssh.sh: --data-urlencode, timeout, and stderr redirect (Found 273)

- **Fix 278 (Found 273):** updated `send_telegram_notification` in `full/trial-ssh.sh` to include `--max-time 10`, `--data-urlencode "chat_id=$chat_id"` and `--data-urlencode "text=$message"`, with `>/dev/null 2>&1`. Aligns with `full/addssh.sh`.

### Fix 279 - full/ and lite/: --data-urlencode across 80 Telegram notification scripts (Found 274)

- **Fix 279 (Found 274):** updated all 80 `auto-delete-*`, `change-id-*`, `change-quota-*`, `delete-*`, `dm-menu.sh`, `limit-ip-*`, `locked-xray-*`, `quota-*`, and `unlock-*` scripts across both `full/` and `lite/` to pass `text` via `--data-urlencode "text=$TEXT"` (or `--data-urlencode "text=$log_message"`) while retaining query parameters via `-d "chat_id=...&parse_mode=html"`. Multi-line HTML strings are safely encoded. Repacked both `menu/full.zip` (114 entries) and `menu/lite.zip` (97 entries). All files pass `bash -n`.

### Fix 280 - menu-argo.sh: fix duplicate ingress, start service, restore option 2 (Found 275)

- **Fix 280 (Found 275):** in both `full/menu-argo.sh` and `lite/menu-argo.sh`: removed shadowed duplicate `hostname: $domargo` rule in `config.yml` (nginx on port 80 already handles all paths); added `systemctl daemon-reload && systemctl enable --now cloudflared` to `setup()`; restored option 2 (`restart_argo`) to cleanly restart cloudflared and eliminate the menu numbering gap (`1, 2, 3, 0`).

### Fix 281 - xl2tp.sh: add interactive pause to create, delete, extend (Found 276)

- **Fix 281 (Found 276):** added `read -n 1 -s -r -p "Press any key to return..." || true` and `echo ""` to `create()`, `delete()`, and `extend()` in `full/xl2tp.sh`. Generated credentials, deletion notices, and renewal cards remain visible on screen until the operator presses a key.

### Fix 282 - xl2tp.sh: date guard, anchored sed, extend from today if expired (Found 277)

- **Fix 282 (Found 277):** in `full/xl2tp.sh` `extend()`: added `d1=$(date -d "$exp" +%s 2>/dev/null)` error guard (aborts cleanly on corrupt dates); anchored sed replacement to `s/^### $user $exp/### $user $exp4/`; and added `if (( exp2 < 0 )); then exp2=0; fi` so accounts expired in the past extend forward from today instead of subtracting days.

### Fix 283 - xl2tp.sh and xp.sh: delete IPsec users regardless of hash algorithm (Found 278)

- **Fix 283 (Found 278):** changed `sed -i '/^'"$user"':\$1\$/d' /etc/ipsec.d/passwd` to `sed -i '/^'"$user"':/d' /etc/ipsec.d/passwd` in `full/xl2tp.sh` line 189, `full/xp.sh` line 300, and `lite/xp.sh` line 299. Cleans IPsec user entries regardless of whether MD5, SHA-256, SHA-512, or plaintext was used.

### Fix 284 - limit-ip.go: allow setting limits on accounts with no file; fix success order (Found 279)

- **Fix 284 (Found 279):** in `full/limit-ip.go`: removed `os.Stat(limitFile)` pre-check so operators can set IP limits on SSH accounts that currently have "No Limit Set" (or `ip=0`); moved `loadingSucces()` inside the `else` block after `isPositiveInt()` validation passes. Compiled fresh binary on Debian 12 amd64 with `-ldflags="-s -w"` (5,034,244 bytes) and updated `menu/full.zip`.

### Fix 285 - menu-ssh.sh and x-*.sh (8 files): add pause to informative display actions (Found 280)

- **Fix 285 (Found 280):** added `; echo "" ; read -n 1 -s -r -p "Press any key to return..." || true ;;` to options 4 (`cek-login-ssh`), 5 (`log-acc-ssh`), and 7 (`list-ssh`) in `full/menu-ssh.sh`, and to options 7 (`cek-xray-*`), 10 (`log-database-xray-*`), and 11 (`list-xray-*`) across all 8 transport menus (`full/x-{ws,http,split,grpc}.sh` and `lite/x-{ws,http,split,grpc}.sh`). Operators can now read account details, member lists, and active login tables before returning to the menu. Repacked `menu/full.zip` and `menu/lite.zip`.

### Fix 286 - menu-system.sh: pass --username root to all 31 reinstall.sh invocations (Found 281)

- **Fix 286 (Found 281):** added `--username root` to all 31 `bash reinstall.sh` invocations across `full/menu-system.sh` and `lite/menu-system.sh`. Prevents the installer from prompting on stdin, ensuring unattended and menu-driven OS reinstallations cleanly configure the root account. Repacked `menu/full.zip` and `menu/lite.zip`.

### Fix 287 - submenus: add Option 0 (Back to Main Menu) across 14 menu scripts (Found 282)

- **Fix 287 (Found 282):** added `${green}0${NC}. Back to Main Menu` (or `00` where options reach double digits) and `0|00) clear ; menu ;;` dispatcher handling across 14 submenu files: `full/menu-ssh.sh`, `full/menu-x.sh`, `full/x-{ws,http,split,grpc}.sh` (and all 4 `lite/` equivalents), `full/bmenu.sh` and `lite/bmenu.sh`, `full/dm-menu.sh` and `lite/dm-menu.sh`, and `full/menu-noobz.sh`. Also aligned `full/menu-wg.sh` (accepts `0|7)`) and `full/xl2tp.sh` (accepts `0|4)`). Verified live on VPS: typing `0` in every single submenu cleanly returns to `VPN MANAGEMENT PANEL`.

### Fix 288 - menu-wg.sh: extract $CLOUDFLAREKEY from warp.json and auto-generate keypair (Found 283)

- **Fix 288 (Found 283):** in `full/menu-wg.sh` `warp()`: added `CLOUDFLAREKEY=$(jq -r '.config.peers[0].public_key // empty' warp.json 2>/dev/null)` with validation error exit so the peer key is properly bound; and added auto-generation via `wg genkey` and `wg pubkey` when `PRIVATEKEY`/`PUBLICKEY` prompts are left empty.

### Fix 289 - menu-wg.sh: guard against empty username in delete, extend, show (Found 284)

- **Fix 289 (Found 284):** added `[ -z "$user" ] && { goback; return; }` immediately after reading username in `delete()`, `extend()`, and `show()` in `full/menu-wg.sh`. Prevents `grep -qw ""` from matching every client line in `/etc/funny/.wireguard` and corrupting the configuration.

### Fix 290 - menu-noobz.sh: validate username, reject duplicates, verify user exists on delete (Found 285)

- **Fix 290 (Found 285):** in `full/menu-noobz.sh`: added `^[a-zA-Z0-9_]+$` validation loop and `grep -qw "^### $user" /etc/funny/.noob` duplicate check to `create()`; required non-empty password; and added `if ! grep -qw "^### $name" "/etc/funny/.noob"; then echo "User not found"; return; fi` to `delete()`.

### Fix 291 - cek-login-ssh.sh: default Limit IP "No Limit" for accounts without file (Found 286)

- **Fix 291 (Found 286):** changed the `else` branch of `get_limit_ip()` from `echo "2"` to `echo "No Limit"` in `full/cek-login-ssh.sh`. System accounts and SSH accounts without limit files now correctly display `No Limit` instead of a misleading `2`.
- **Verified live on VPS:** `root` now shows `Limit IP: No Limit` in `cek-login-ssh` output.

### Fix 292 - menu-wg.sh: remove "bug.com." prefix from domain display in create() (Found 287)

- **Fix 292 (Found 287):** changed `echo -e " Domain\t: $domain / bug.com.${domain}"` to `echo -e " Domain\t: $domain"` in `full/menu-wg.sh` `create()`. Removed the accidental `bug.com.` test string that was committed in V23.
- **Verified live on VPS:** WireGuard account creation now shows only the correct domain.

### Fix 293 - format.sh: add interactive pause to format_display() for all 50 creation cards (Found 288)

- **Fix 293 (Found 288):** added `echo "" ; read -n 1 -s -r -p "Press any key to return..." || true ; echo ""` to the end of `format_display()` in `config/format.sh`. Prevents parent menus (`x-*`, `menu-ssh`, `menu`) from immediately wiping newly generated credentials, UUIDs, and links upon account creation.
- **Verified live on VPS:** account creation in menu now cleanly displays the account card and pauses for operator acknowledgement before returning.

### Fix 294 - limit-ip.go: fix success exit code, suppress optional file errors, guard Telegram POST (Found 289)

- **Fix 294 (Found 289):** in `full/limit-ip.go`: changed `Credit()` to `os.Exit(0)` instead of `os.Exit(1)`; silenced error prints in `readFile()` when optional `/etc/funny/.chatid` or `/etc/funny/.keybot` are absent; added `if CHATID == "" || KEY == "" { return }` in `sendTelegramNotification()`. Recompiled binary on Linux amd64 with `-ldflags="-s -w"` and updated `menu/full.zip`.
- **Verified live on VPS:** `limit-ip` updates limit without spurious file or Telegram errors, and exits with code 0.

### Fix 295 - change-quota-*.sh (8 files): change Sc_Credit() exit 1 to exit 0 on success (Found 290)

- **Fix 295 (Found 290):** changed `exit 1` to `exit 0` in `function Sc_Credit()` across all 8 `change-quota-*.sh` files in `full/` and `lite/`. Prevents successful quota adjustments from reporting failure status to callers.
- **Verified live on VPS:** updating quota with `change-quota-ws` now returns exit code 0.

### Fix 296 - menu-system.sh: add Option 0, preserve submenu navigation on action (Found 291)

- **Fix 296 (Found 291):** in `full/menu-system.sh` and `lite/menu-system.sh`: added `${green}0${NC}. Back to Main Menu` and `0|00) clear ; menu ;;` dispatcher handling in `systemd()`; added `systemd` calls to options 1, 2, 3, 5, 6, 7, 8 so operators remain in the system menu after actions; added `menuwg` calls to options 1-7 in `menuwg()` and `0) systemd ;;` to return to system menu; added `0) menuwg ;;` in `add()`.
- **Verified live on VPS:** option 5 (`detail`) displays details, pauses on keypress, and returns to system menu; option 0 returns to main menu.

### Fix 297 - menu-bot.sh: add Option 0, add pauses to notifications/backup/bug report (Found 292)

- **Fix 297 (Found 292):** in `full/menu-bot.sh` and `lite/menu-bot.sh`: added `${green}0${NC}. Back to Main Menu` and `0|00) clear ; menu ;;` in `mna()`; added `mna` calls to options 1-5; added `read -n 1 -s -r -p "Press any key to return..." || true` to `notif()`, `setbotup()`, and `rpot()`; aligned bug report contact with Decision 9 (`https://t.me/rohcuan`); added loop and pause to `menubot()` in `termbot()`.
- **Verified live on VPS:** bug report and bot setup menus now pause for reading and loop cleanly back to the bot menu.

### Fix 298 - bmenu.sh & backup.sh: loop on actions and pause before returning (Found 293)

- **Fix 298 (Found 293):** in `full/bmenu.sh` and `lite/bmenu.sh`: added `read -n 1 -s -r -p "Press any key to return..." || true` to `restore()`, `restf()`, and `resold()`; re-called `bmenu` in cases 1-4; in `full/backup.sh` and `lite/backup.sh`, added pause before returning on credentials missing or failure.
- **Verified live on VPS:** backup and restore workflows now keep status output visible and loop back to the backup menu.

### Fix 299 - xl2tp.sh, menu-ssh.sh, menu-x.sh, x-*.sh (8 files): loop submenus on action (Found 294)

- **Fix 299 (Found 294):** in `full/xl2tp.sh`: re-called `main` in cases 1, 2, 3 so operators return to L2TP menu; in `full/menu-ssh.sh`: re-called `menu-ssh` in cases 1-9; in `full/menu-x.sh`: re-called `menu-x` in cases 1-4; in all 8 transport menus (`full/x-*.sh` and `lite/x-*.sh`): re-called menu functions (`xws`, `xhttp`, `xsplit`, `xgrpc`) in cases 1-17. Repacked `menu/full.zip` and `menu/lite.zip`.
- **Verified live on VPS:** creating, extending, or deleting accounts in L2TP and transport menus now smoothly returns to the submenu.

### Fix 300 - menu-wg.sh: reject empty and invalid WireGuard usernames (Found 300)

- **Fix 300 (Found 300):** guarded the WireGuard create username read against EOF and required `^[a-zA-Z0-9_]+$`. Empty input exits without changing WireGuard state; invalid names are rejected and the prompt is shown again. Valid names continue through the existing duplicate check and account creation path.
- **Verified live:** before the fix, an empty username created `### Client `, a blank `.wireguard` record, and `/var/www/html/wireguard-.conf`. After deployment, `printf '1\n\n' | menu-wg` returned 0 with `wg0.conf` and `.wireguard` byte-state unchanged, no blank marker or blank config file, and `wg-quick@wg0` active.
- **Packaging:** `menu/full.zip` was rebuilt and its `menu-wg` entry verified byte-identical to `full/menu-wg.sh` with mode `0755`. Lite has no WireGuard menu and was not changed.

### Fix 301 - menu-wg.sh: stop after rejected WireGuard operations (Found 301)

- **Fix 301 (Found 301):** added `return` after the existing `goback` calls for duplicate usernames, an exhausted WireGuard pool, and a missing username during extension. Rejected operations now return before any config/database write.
- **Verified live:** the pre-fix duplicate create and nonexistent extend both wrote invalid state after `goback` returned. With the fix deployed, the same inputs leave `/etc/wireguard/wg0.conf` and `/etc/funny/.wireguard` unchanged; `wg-quick@wg0` remains active.

### Fix 302 - menu-noobz.sh: match server username limit and record only successful accounts (Found 302)

- **Fix 302 (Found 302):** limited NoobzVPN menu usernames to its existing safe alphabet and the server's 1–16-character limit. The panel now appends `/etc/funny/.noob` only after `noobzvpns add` succeeds; a command failure reports the error and leaves panel state untouched.
- **Verified live:** a 20-character test username was rejected by the pre-fix server but written to `.noob` by the menu. After deployment, the same input creates no panel record and no NoobzVPN account; the service remains active.

### Fix 303 - menu-dnstt.sh: validate SlowDNS nameserver hostnames (Found 303)

- **Fix 303 (Found 303):** require a dot-separated DNS hostname with valid alphanumeric/hyphen labels and a 2–63-letter top-level domain before updating `nsdomain` or generating the dnstt unit. EOF also returns without changes.
- **Verified live:** before the fix, `bad name` was written directly into both persisted locations. After deployment, it is rejected and leaves the nameserver file and unit byte-state unchanged; the current valid hostname is accepted and `dnstt` remains active.

### Fix 304 - dm-menu.sh: validate changed server domains (Found 304)

- **Fix 304 (Found 304):** in full and lite domain menus, require a valid dot-separated DNS hostname before changing the current domain, nginx `server_name`, or saved account cards. Invalid input displays an error and returns to the main menu without writes.
- **Verified live:** before the fix, `bad domain` changed all three state groups. After deployment, the same input leaves the domain file, nginx configuration, and account cards unchanged; the deployed valid domain remains served by active nginx.

### Fix 305 - certificate and restore paths: protect Xray private key and HAProxy bundle (Found 305)

- **Fix 305 (Found 305):** all certificate issue, renewal, self-signed, menu restore, and FTP/web restore paths now set `/etc/xray/xray.crt` to `0644` but `/etc/xray/xray.key` and `/etc/haproxy/funny.pem` to `0600`. The HAProxy bundle receives the same protection because it embeds the private key.
- **Verified live:** after changing the deployed key to `0600`, nginx, HAProxy, NoobzVPN, `xray@ws`, `xray@grpc`, `xray@upgrade`, and `xray@split` all restarted active. The updated full domain menu is deployed; installer source protects fresh installations.

### Fix 306 - delete-{ws,grpc,http,split}.sh: gate restart and file ops on user-found (Found 306)

- **Fix 306 (Found 306):** in all 8 delete scripts (full and lite for ws, grpc, http, split): moved `rm -f` (log, quota, limit files), `systemctl restart`, `send_log`, and the success display inside the `if [ -n "$exp" ]` block. The else branch now prints "User not found" and returns to the transport submenu without touching any files or services.
- **Verified live:** `delete-ws notarealuser999` (post-fix) produced `rc=0 restarted=no config_changed=no` with the not-found message; `xray@ws` remained active with no extra restarts.

### Fix 307 - menu-argo.sh: validate Argo tunnel domain (Found 307)

- **Fix 307 (Found 307):** in full and lite `menu-argo.sh`, required a valid FQDN before running `cloudflared tunnel route dns` or writing to `/etc/xray/domargo` and `config.yml`. Invalid input prints an error and returns from `setup()` without any changes.
- **Verified live:** deployed to `/usr/bin/menu-argo`; md5 matches source.

### Fix 308 - addssh.sh: require non-empty SSH password (Found 308)

- **Fix 308 (Found 308):** added an empty-password retry loop in `full/addssh.sh`. EOF exits with code 1 (existing behaviour for other read calls in the same script).
- **Verified:** deployed to `/usr/bin/addssh`; md5 matches source.

### Fix 309 - routing-*.sh: require all routing fields to be non-empty (Found 309)

- **Fix 309 (Found 309):** in all 8 routing scripts (full/lite × ws/grpc/http/split), all 3 invocation sites per file now guard with `|| return` on each read and a combined empty-string check before any Xray config is written.
- **Archives rebuilt and verified byte-identical, mode 755.**

### Fix 310 - Phase 1: Cryptographic key and credential permissions audit (Found 310)

- **Fix 310 (Found 310):**
  1. In `installer/stunnel5.sh`: replaced `cat ... | tee` with `>` and added `chmod 600 /etc/haproxy/funny.pem` to prevent stdout key leakage and world-readable bundle.
  2. In `installer/wg.sh`: added `chmod 600 /etc/wireguard/wg0.conf`.
  3. In `installer/slowdns.sh`: added `chmod 600 /etc/slowdns/server.key`.
  4. In `installer/l2tp.sh`: replaced `chmod +x` with `chmod 600 /etc/funny/.l2tp`.
  5. In `full/bmenu.sh` and `lite/bmenu.sh` (all 3 restore functions) and all `restore-ftp.sh` variants (`full`, `lite`, `website`): enforced `chmod 644 /etc/xray/xray.crt`, `chmod 600 /etc/xray/xray.key /etc/haproxy/funny.pem`, and `chmod 600 /etc/wireguard/wg0.conf /etc/wireguard/params /etc/ipsec.secrets* /etc/ppp/chap-secrets* /etc/ipsec.d/passwd* /etc/funny/.keybot /etc/funny/.chatid /etc/funny/.l2tp`, plus `chmod 640 /etc/funny/.restore.key`.
  6. In `full/menu-bot.sh` and `lite/menu-bot.sh`: added `chmod 600 /etc/funny/.keybot /etc/funny/.chatid` after writing bot credentials.
  7. In `full/xl2tp.sh`, `full/xp.sh`, and `lite/xp.sh`: added `/etc/funny/.l2tp` to `chmod 600`.
- **Verified live:** `/usr/bin/bmenu`, `menu-bot`, `restore-ftp`, `xl2tp`, `xp` deployed to VPS; live file permissions on `/etc/wireguard/wg0.conf`, `/etc/haproxy/funny.pem`, `/etc/xray/xray.key`, `/etc/funny/.l2tp` all verified `0600`; `/etc/funny/.restore.key` verified `0640`; all 16 core services verified active with 0 failed units.
- **Archives rebuilt:** `menu/full.zip` and `menu/lite.zip` repacked and verified at mode `0755`.

### Fix 311 - Phase 2: Sysctl and network routing idempotency and permissions (Found 311)

- **Fix 311 (Found 311):**
  1. In `fix/fix.sh`: added persistent assertion for `net.ipv4.ip_forward = 1` and made `net.netfilter.nf_conntrack_max` / `timeout` replacement update existing values instead of ignoring them.
  2. In `installer/vpn.sh`: robustly replaced or appended `net.ipv4.ip_forward=1` regardless of comment prefix or spacing.
  3. In `installer/udp.sh`: changed `chmod +x config.json` to `chmod 600 config.json`.
  4. In `installer/request.sh`: resolved default route network interface via `ip -o -4 route show to default` to reliably obtain host public interface instead of grabbing virtual tunnel adapters.
- **Verified live:** `/root/udp-custom/config.json` set to `0600`; updated `fix.sh` ran clean on VPS; verified sysctl values (`net.ipv4.ip_forward = 1`, `fs.file-max = 1000000`, `net.netfilter.nf_conntrack_max = 262144`); all 16 core services verified active.

### Fix 312 - Phase 3: Systemd restart storm prevention and RestartSec backoff (Found 312)

- **Fix 312 (Found 312):**
  1. In `full/xp.sh` and `lite/xp.sh`: batched SSH daemon restarts (`ssh`, `sshd`, `ws`, `dropbear`) and L2TP daemon restarts (`ipsec`, `xl2tpd`) to run once after account deletion loops instead of restarting repeatedly per expired user.
  2. In `installer/ssh.sh` (`ws.service`, `badvpn-udpgw.service`), `installer/xray.sh` (`xray@.service`, `quota-ws`, `quota-split`, `quota-http`, `quota-grpc`), `installer/slowdns.sh` (`dnstt.service`), `full/menu-dnstt.sh` (`dnstt.service`), `installer/vpn.sh` (`fn-ohp.service`, `opn.service`), and `full/menu-bot.sh` / `lite/menu-bot.sh` (`bot.service`): added `RestartSec=3s` backoff delay to prevent CPU spinning and rate-limit bursts.
  3. In `installer/udp.sh`: aligned `WantedBy` to `multi-user.target`.
- **Verified live:** `xp`, `menu-dnstt`, `menu-bot` deployed to VPS `/usr/bin/`; `RestartSec=3s` applied across all 10 live unit files and `daemon-reload` run; all 16 core services verified active with 0 failed units.
- **Archives rebuilt:** `menu/full.zip` and `menu/lite.zip` repacked and verified at mode `0755`.

### Fix 313 - Phase 4: Cron cleanup verification, Noobz batching, and WireGuard permission persistence (Found 313)

- **Fix 313 (Found 313):**
  1. In `full/xp.sh` and `lite/xp.sh`: verified Xray JSON configuration with `xray run -test -config` before performing service restarts for each transport (`ws`, `upgrade`, `split`, `grpc`).
  2. In `full/xp.sh` and `lite/xp.sh`: batched NoobzVPN service restarts outside the loop using `noobz_restarted=1`.
  3. In `full/xp.sh`, `lite/xp.sh`, and `full/menu-wg.sh`: enforced `chmod 600 /etc/wireguard/wg0.conf` immediately after updating the file from `/tmp/wg0.conf`.
  4. In `full/xp.sh` and `lite/xp.sh`: added `head -n 1` to single-line expiry date extraction across all transports.
- **Verified live:** `/usr/bin/xp` and `/usr/bin/menu-wg` deployed to VPS; `/usr/bin/xp` executed clean; all 16 core services verified active.
- **Archives rebuilt:** `menu/full.zip` and `menu/lite.zip` repacked and verified at mode `0755`.

### Fix 314 - Phase 5: IP limiter Telegram guard and validated Xray restarts during locking/unlocking (Found 314)

- **Fix 314 (Found 314):**
  1. In `full/limit-ip-*.sh`, `lite/limit-ip-*.sh`, `full/unlock-*.sh`, `lite/unlock-*.sh`, and `full/locked-xray-*.sh`: added `[ -z "$CHATID" ] || [ -z "$KEY" ] && return 0` to `send_log()` to prevent unauthenticated HTTP requests when bot tokens are empty.
  2. In all `limit-ip-*`, `unlock-*`, and `locked-xray-*` scripts: verified Xray JSON syntax with `xray run -test -config` before executing service restarts.
  3. Added `head -n 1` to single-line expiry date lookups in `limit-ip-*` and `locked-xray-*`.
- **Verified live:** `/usr/bin/limit-ip-*`, `/usr/bin/unlock-*`, and `/usr/bin/locked-xray-*` deployed to VPS; `/usr/bin/limit-ip-ws` ran clean; all 16 core services verified active.
- **Archives rebuilt:** `menu/full.zip` and `menu/lite.zip` repacked and verified at mode `0755`.

### Fix 315 - Phase 6: Quota/kill complete artifact removal, Telegram guard, and validated restarts (Found 315)

- **Fix 315 (Found 315):**
  1. In `full/quota-*.sh`, `lite/quota-*.sh`, `full/kill-*.sh`, and `lite/kill-*.sh` (16 files): added `rm -f /etc/xray/limit/ip/xray/<proto>/${user}` on account deletion so no orphaned limit files survive a quota breach per Decision 16.
  2. In `send_log()` across all 16 scripts: added `[ -z "$CHATID" ] || [ -z "$KEY" ] && return 0` to bypass unauthenticated requests when bot tokens are empty.
  3. Enforced `xray run -test -config` pre-restart validation on all quota/kill Xray service restarts.
  4. Added `head -n 1` to expiry date extractions.
- **Verified live:** `/usr/bin/quota-*` and `/usr/bin/kill-*` deployed to VPS; `/usr/bin/kill-ws` ran clean; all 16 core services verified active.
- **Archives rebuilt:** `menu/full.zip` and `menu/lite.zip` repacked and verified at mode `0755`.

### Fix 316 - Phase 7: Account creation Telegram alerts guard and validated Xray service restarts (Found 316)

- **Fix 316 (Found 316):**
  1. In all 48 `add-*` and `trial-*` scripts (`full/` and `lite/`): guarded Telegram notifications with `if [ -n "$CHATID" ] && [ -n "$KEY" ]`.
  2. In all 48 `add-*` and `trial-*` scripts: guarded `xray@<transport>` and `quota-<transport>` service restarts with `xray run -test -config`.
  3. In `full/addssh.sh` and `full/trial-ssh.sh`: guarded `send_telegram_notification()` with `[ -z "$chat_id" ] || [ -z "$key" ] && return 0`.
- **Verified live:** all 50 updated tools deployed to `/usr/bin/`; all 16 core services verified active.
- **Archives rebuilt:** `menu/full.zip` and `menu/lite.zip` repacked and verified at mode `0755`.

### Fix 317 - Reject `0` on IP and quota prompts per Decision 4 (Found 317)

- **Fix 317 (Found 317):**
  1. In all 24 `add-*.sh` scripts (`full/` and `lite/`) and `full/addssh.sh`: changed prompt notice from `0 = unlimited` to `0 not allowed`.
  2. Enforced regex `^[1-9][0-9]*$` for IP limit and quota prompts, rejecting `0` across all account creation scripts.
  3. Updated error prompt to `Value must be a whole number greater than 0.`.
- **Verified live:** deployed to `/usr/bin/` on VPS; verified prompt displays `0 not allowed` and rejects `0`; all 16 core services verified active.
- **Archives rebuilt:** `menu/full.zip` and `menu/lite.zip` repacked and verified at mode `0755`.

### Fix 318 - Phase 8: Hardening account modification, extension, and deletion handlers (Found 318)

- **Fix 318 (Found 318):**
  1. In all 32 management scripts across `full/` and `lite/` (`delete-*`, `extend-*`, `change-id-*`, `change-quota-*`): added `[ -z "$CHATID" ] || [ -z "$KEY" ] && return 0` to `send_log()`.
  2. Added `xray run -test -config` pre-restart validation before restarting `xray@<transport>` and `quota-<transport>`.
  3. Added `head -n 1` to single-line expiry date lookups.
  4. Added EOF guard handling to username prompt reads.
- **Verified live:** deployed to `/usr/bin/` on VPS; tested `delete-ws nonexistent999` live; verified 0 unwanted restarts, 0 deleted files, clean return to menu; all 16 core services verified active.
- **Archives rebuilt:** `menu/full.zip` and `menu/lite.zip` repacked and verified at mode `0755`.

### Fix 319 - Phase 9: Hardening additional protocols (WireGuard, NoobzVPN, L2TP, SlowDNS) (Found 319)

- **Fix 319 (Found 319):**
  1. In `full/menu-dnstt.sh`: added `chmod 600 /etc/slowdns/server.key` after server key renewal.
  2. In `full/menu-noobz.sh`: guarded Telegram notifications with `if [ -n "$CHATID" ] && [ -n "$KEY" ]` and added `head -n 1` to expiry lookup.
  3. In `full/menu-wg.sh`: enforced `chmod 600 /etc/wireguard/wg0.conf` after creating accounts, added missing `goback` in `extend()`, and hardened database line deletion pattern to `^$user[[:space:]]`.
  4. In `full/xl2tp.sh`: allowed `create()` loop to prompt again on duplicate usernames instead of terminating with `exit 1`, and enforced `chmod 600 /etc/funny/.l2tp` after extending accounts.
- **Verified live:** deployed to `/usr/bin/` on VPS; all 16 core services verified active with 0 failed units.
- **Archives rebuilt:** `menu/full.zip` repacked and verified at mode `0755`.

### Fix 320 - Phase 10: TUI menu retention, WireGuard submenu goback, and option 00 handling (Found 320)

- **Fix 320 (Found 320):**
  1. In `full/menu.sh` and `lite/menu.sh`: chained re-invocation of the parent menu after each submenu case execution to prevent dropping out to the shell.
  2. In `full/menu-wg.sh`: modified `goback()` to return to `main` (the WireGuard submenu) instead of the main menu, and removed redundant `goback` calls in the dispatcher.
  3. In `full/menu-dnstt.sh`: added `00` support to Option 0 handling.
- **Verified live:** deployed to `/usr/bin/` on VPS; verified menu retention across all actions; all 16 core services verified active with 0 failed units.
- **Archives rebuilt:** `menu/full.zip` and `menu/lite.zip` repacked and verified at mode `0755`.

### Fix 321 - Phase 11: Argo tunnel read pauses and option 00 handling (Found 321)

- **Fix 321 (Found 321):**
  1. In `full/menu-argo.sh` and `lite/menu-argo.sh`: added completion status and `read -n 1 -s -r -p` pauses after `setup()` and `restart_argo()`.
  2. In `full/menu-argo.sh` and `lite/menu-argo.sh`: expanded Option 0 dispatcher to accept `0|00)`.
- **Verified live:** deployed to `/usr/bin/menu-argo` on VPS; verified pause behavior and menu return; all 16 core services verified active with 0 failed units.
- **Archives rebuilt:** `menu/full.zip` and `menu/lite.zip` repacked and verified at mode `0755`.

### Fix 322 - Phase 12: Domain menu retention, certificate generator Option 0, read pauses, and Telegram guards (Found 322)

- **Fix 322 (Found 322):**
  1. In `full/dm-menu.sh` and `lite/dm-menu.sh`: chained re-invocation of `dm1` on all action branches in `dm1()` to prevent dropping out to the shell.
  2. Added Option 0 (Back to Domain Menu) to `cert()` dispatcher.
  3. Added read pauses after certificate issuance in `acme()`, `cert2()`, `fn()`, and `dmsl()`.
  4. Guarded all 4 Telegram log curl requests in `dm()` with `if [ -n "$CHATID" ] && [ -n "$KEY" ]`.
- **Verified live:** deployed to `/usr/bin/dm-menu` on VPS; verified clean navigation and menu retention; all 16 core services verified active with 0 failed units.
- **Archives rebuilt:** `menu/full.zip` and `menu/lite.zip` repacked and verified at mode `0755`.

### Fix 323 - Phase 13: Enforce mode 0600 on backup zip and validate Xray restart across all restore paths (Found 323)

- **Fix 323 (Found 323):**
  1. In `full/backup.sh` and `lite/backup.sh`: added `chmod 600 /root/backup.zip` immediately after archive creation to protect private keys and shadow hashes.
  2. In `full/bmenu.sh`, `lite/bmenu.sh`, `full/restore-ftp.sh`, `lite/restore-ftp.sh`, and `website/restore-ftp.sh`: guarded `xray@<transport>` service restarts with `xray run -test -config`.
  3. In `full/bmenu.sh` and `lite/bmenu.sh`: added empty-URL and EOF checks in `restore()` and `resold()`, and ensured `chmod 600 backup.zip` after download.
- **Verified live:** deployed to `/usr/bin/` on VPS; verified 0600 mode and clean services; all 16 core services verified active with 0 failed units.
- **Archives rebuilt:** `menu/full.zip` and `menu/lite.zip` repacked and verified at mode `0755`.

### Fix 324 - Phase 14: REST API verification and unit restart backoff (Found 324)

- **Fix 324 (Found 324):**
  1. Audited `fn-autosc-api` server and handlers: verified default bind to `127.0.0.1:9000`, single path segment rejection of traversal attempts, synchronous execution preventing race conditions on shared JSON/user files, and token enforcement against `/etc/xray/.key` (`0600`).
  2. Added `RestartSec=3s` backoff delay to `/etc/systemd/system/api.service` on the VPS.
- **Verified live:** `menu-api install` executed clean; `/api/ping` authenticated request returned 200 OK over HTTPS; traversal `/..%2fetc/passwd` returned 404; unauthenticated request returned 401; all 16 core services verified active with 0 failed units.

### Fix 325 - Phase 15: Dual-edition package synchronization and binary build verification (Found 325)

- **Fix 325 (Found 325):**
  1. Synchronized all 114 entries in `menu/full.zip` and all 97 entries in `menu/lite.zip` with source trees; verified exact byte parity across all script files.
  2. Verified all entries in both archives have external attribute `0755`.
  3. Verified all 28 Go source files in `full/` and `lite/` compile cleanly with 0 errors.
- **Verified live:** deployed `full.zip` directly to `/usr/bin/` on the VPS; verified mode `0755` across all panel binaries; all 16 core services verified active with 0 failed units.

### Fix 326 - Documentation consistency: align non-append-only docs with reverted fixes (Found 326)

- **Fix 326 (Found 326):** corrected in place (non-append-only docs are edited, not appended):
  1. `README.md`: install order `Node.js 20` → `Node.js 16`; changelog line → `Node.js 16 retained — Node 20 was tried (Fix 271) but reverted (Fix 275)`.
  2. `project-information/fn-api.md`: hardening table `ThreadingHTTPServer` → single-threaded `HTTPServer` (retained); lock note → reverted to single-threaded with lock removed; unit row gains `RestartSec=3s`.
  3. `project-information/is-decision.md` section 18: `threads the server` → `stays single-threaded like the reference (a threaded build was tried and reverted)`.
  4. `project-information/bug-finding-and-fixing-phase-plan.md` Fase 14: `threading lock` → single-threaded retained.
- **Verified:** `installer/package.sh:92` is `setup_16.x`; live API `server` imports `HTTPServer` (not threading) with single-threaded header comment; append-only history left untouched.

### Fix 327 - Web-restore PHP upload cap raised to 64M (Found 327)

- **Fix 327 (Found 327):** `website/install.sh` now sets `upload_max_filesize = 64M` and `post_max_size = 64M` in every `/etc/php/*/apache2/php.ini` before restarting apache2 (version-agnostic glob, idempotent `sed`). 64M mirrors the Telegram Bot API document ceiling so both restore ingress paths accept the same archives.
- **Verified live:** `/etc/php/8.2/apache2/php.ini` shows `64M / 64M` after `systemctl restart apache2`; the 3699620-byte self-backup passed PHP upload handling and reached `restore-ftp` (proving the cap, which then exposed Found 328).

### Fix 328 - Web-restore sudoers rule via drop-in instead of broken visudo idiom (Found 328)

- **Fix 328 (Found 328):** replaced the no-op `echo ... | sudo EDITOR='tee -a' visudo` block in `website/install.sh` with a `/etc/sudoers.d/restore-ftp` drop-in (`www-data ALL=(ALL) NOPASSWD: /usr/bin/restore-ftp`, mode `0440`), validated with `visudo -c -q -f` (file removed if invalid). Drop-in keeps `/etc/sudoers` itself untouched.
- **Verified live:** `visudo -c` → `parsed OK`; `sudo -U www-data -l` lists `(ALL) NOPASSWD: /usr/bin/restore-ftp`; valid-token upload of the system's own `backup.zip` returned `SUCCESSFULLY RESTORED YOUR VPS` (HTTP 200); all restored keys at `0600` (`xray.key`, `funny.pem`, `wg0.conf`, `server.key`, `ipsec.secrets`, `chap-secrets`); 7/7 services active, 0 failed units, `xray -test` OK, domain intact.

### Fix 329 - Widen xray@ unit start limiter so restart bursts cannot fail the transport (Found 329)

- **Fix 329 (Found 329):** added `StartLimitIntervalSec=120` + `StartLimitBurst=30` to `[Unit]` in `installer/xray.sh`'s `xray@.service` template (fresh installs inherit it); applied the same two lines live + `daemon-reload`. Crash-loop protection is unchanged (`Restart=on-failure`, `RestartSec=3s`); only the external-restart budget grew. The deeper fix (coalescing one restart per API fan-out) belongs to the `rohjagad/fn-autosc-api` handler layer, a separate repository — noted, not done here.
- **Verified live:** 8 back-to-back `systemctl restart xray@ws` (fatal under the old 5/10s budget) → unit stays `active`; all 4 transports active.

### Fix 330 - Same burst budget for quota-*, ws, ssh, dropbear (Found 330)

- **Fix 330 (Found 330):** same two lines (`StartLimitIntervalSec=120` + `StartLimitBurst=30`): direct `[Unit]` addition in the four `quota-*.service` templates and `ws.service` template (`installer/xray.sh`, `installer/ssh.sh`); drop-in files (`/etc/systemd/system/{ssh,dropbear}.service.d/fn-burst.conf`, distro units never edited) created by `installer/ssh.sh`, covering the `sshd` alias through `ssh.service`. Crash behavior untouched everywhere.
- **Verified live:** 8 back-to-back restarts each of `quota-ws`, `ws`, `ssh`, `dropbear` → all stay `active`; 0 failed units; pre-existing `Restart=`/`RestartSec=` values unchanged (`systemctl cat` diff shows only the two added lines).

### Fix 331 - SplitHTTP → XHTTP migration (Found 331)

- **Fix 331 (Found 331):** 43 files, pure renames (150 insertions / 150 deletions, no logic change): protocol + paths + display strings as in Found 331; non-append-only docs updated in place (`is-decision.md` path table, `fn-api.md`, both phase plans, `README.md` transport table/cron/log rows, keeping identifier columns intact).
- **Verified live:** `xray run -test` OK on new `split.json`; `bash -n` clean on all touched scripts; Go changes are string literals only.

### Fix 332 - Auth fetch: Cloudflare Pages primary, GitHub fallback (Found 332)

- **Fix 332 (Found 332):** 193 files, same two-line shape everywhere: `PERMISSION_URL=` replaced by `PERMISSION_PRIMARY` (Pages) + `PERMISSION_FALLBACK` (GitHub raw); fetch tries primary then fallback (`curl -s primary || curl -s fallback || { fail }`). The one stray non-canonical URL (`fix/fix-decrypted-original.sh` → `rohmatsb-biz/cobaizin`) deliberately untouched. Same change in `fn-autosc-api/menu-api` gate (keeping its `--max-time 15` caps).
- **Verified:** 193/193 converted, 0 old-var residuals, `bash -n` clean on all touched scripts; live gate green via Pages.

### Fix 333 - Full `split` → `xhttp` identifier rename (Found 333)

- **Fix 333 (Found 333):** mechanical 1:1 rename across both repos (fn-autosc: files, service instance, JSON, data dirs, function/vars, menus, cron, docs; fn-autosc-api: `core` mapping + `xhttp.json`/tool paths + README + plans, with legacy `split`→`xhttp` alias). Live migration moves data (accounts, quota, limit, logs) into `xhttp` homes, switches the systemd instance, updates crontab, and redeploys `/usr/bin` — verified end-to-end with account create/traffic/delete.

### Fix 334 - Phase 1: re-secure API token + restore-key ownership on every restore (Found 334)

- **Fix 334 (Found 334):** in all 9 restore blocks (`full/bmenu.sh` ×3, `lite/bmenu.sh` ×3, `full/restore-ftp.sh`, `lite/restore-ftp.sh`, `website/restore-ftp.sh`) appended two guarded lines after the existing `chmod 640 /etc/funny/.restore.key`: `chmod 600 /etc/xray/.key` (API token back to Decision-19 `0600 root`) and `chown root:www-data /etc/funny/.restore.key` (web-restore key readable by `www-data` again). Repacked `menu/full.zip` (114 entries) + `menu/lite.zip` (97 entries) deterministically (fixed timestamp, mode `0755`, byte-identical entries).
- **Verified:** `bash -n` clean on all 5 files; zip entries byte-identical to sources, 0 non-`0755` entries; no logic/input handling touched.

### Fix 335 - Phase 3: burst budget for the remaining seven custom units (Found 335)

- **Fix 335 (Found 335):** added `StartLimitIntervalSec=120` + `StartLimitBurst=30` to the `[Unit]` section of all nine templates (`installer/udp.sh`, `installer/request.sh`, `installer/slowdns.sh`, `full/menu-dnstt.sh`, `installer/ssh.sh` badvpn block, `installer/vpn.sh` ×2, `full/menu-bot.sh`, `lite/menu-bot.sh`) plus `api.service` in `fn-autosc-api/menu-api`; `fn-api.md` unit row updated in place. Repacked `menu/full.zip` (114) + `menu/lite.zip` (97) deterministically. Crash behavior untouched (genuine crash-loops still fail, only later).
- **Verified:** `bash -n` clean ×9; unit bodies extracted and `systemd-analyze verify` reports no syntax/section errors (only missing-binary warnings from the workstation, absent on target); zip entries byte-identical, 0 non-`0755`.

### Fix 336 - Phase 4: guard the `xp` SSH branch against corrupt shadow expiry (Found 336)

- **Fix 336 (Found 336):** four-line numeric guard (`[[ "$userexp" =~ ^[0-9]+$ ]] || { skip + continue }`) after the field-8 extraction in `full/xp.sh` + `lite/xp.sh`, mirroring the Found-108 guards in the sibling branches. Repacked `menu/full.zip` + `menu/lite.zip` (`xp` entry byte-identical).
- **Verified:** `bash -n` clean ×2; logic reproduction (DELETE stays for genuinely-expired, SKIP for corrupt, KEEP for future); zips deterministic.

### Fix 337 - Phase 4: `fn-api.md` transport names follow the xhttp rename (Found 337)

- **Fix 337 (Found 337):** three in-place edits (`:155` core enum, `:163` delete backends, `:175` naming paragraph) — `xhttp` canonical, `split` as legacy alias. No code touched.

### Fix 338 - Phase 5: lite unlock-xhttp notification title (Found 338)

- **Fix 338 (Found 338):** one line in `lite/unlock-xhttp.sh:111` (`DELETED` → `XHTTP UNLOCK`), restoring full/lite parity. Repacked `menu/lite.zip` (`unlock-xhttp` entry byte-identical); `menu/full.zip` untouched (no `full/` source changed — verified zero mismatched entries, reverted the no-op rebuild).
- **Verified:** `bash -n` clean; `diff full/unlock-xhttp.sh lite/unlock-xhttp.sh` empty; zip deterministic.

### Fix 339 - Phase 7: `addssh` honors `useradd` failure + first-prompt EOF guard (Found 339)

- **Fix 339 (Found 339):** `create_ssh_user ... || return` (mirrors `trial-ssh.sh`'s caller guard) and `|| exit 0` on the first username `read` (mirrors every retry in the same file). Repacked `menu/full.zip` (`addssh` entry byte-identical; lite ships no SSH tooling).
- **Verified:** `bash -n` clean; no prompt/validation logic altered.

### Fix 340 - Phase 10: accept `00` alongside `0` in the four remaining submenus (Found 340)

- **Fix 340 (Found 340):** `0)` → `0|00)` at six branches (same back-action, wider spelling). Repacked `menu/full.zip` + `menu/lite.zip` (entries byte-identical, 0 non-`0755`).
- **Verified:** `bash -n` clean ×4; census 24/24 branches `0|00)`; main menu intentionally unchanged (no parent to return to; Ctrl+C documented).

### Fix 341 - Phase 12: FQDN validation for installer domains (Found 341)

- **Fix 341 (Found 341):** the canonical FQDN branch in both installer loops (installers are fetched from GitHub, not zipped — no repack). Garbage now re-prompts instead of producing a self-signed-by-default install.
- **Verified:** `bash -n` clean ×2; accept/reject matrix matches `dm-menu` behavior (`test..com`, spaces, leading/trailing hyphens rejected; multi-level names accepted).

### Fix 342 - Phase 13: bound API installer fetches (Found 342)

- **Fix 342 (Found 342):** `--max-time 60` on the three `install_api` fetch lines in `fn-autosc-api/menu-api` (server, lib.sh, handlers loop). Staging/rollback, checksums and the remaining installer gaps stay in Fase 19 where they are tracked.
- **Verified:** `bash -n` clean; existing `FAILED to fetch` + `return 1` fail-fast path unchanged, now also time-bounded.

### Fix 345 - Phase 16: panel-mirroring input guards in five handlers (Found 345)

- **Fix 345 (Found 345):** exact panel-mirror regexes in `add-xray`, `addssh`, `add-noobz`, `renew-xray`, `renew-ssh` (code in `fn-autosc-api`). Coerced JSON numbers (`30`) still pass; only values the panel itself would refuse are rejected early with field+rule named.
- **Verified:** `bash -n` clean ×5; 16-case stub-panel matrix all explicit; valid metachar/numeric inputs unblocked.

### Fix 346 - Phase 17: gate timeouts + exact IP match, Noobz exact match, honest partial delete (Found 346)

- **Fix 346 (Found 346):** panel — `--max-time 15` on all gate curls + `grep -wF` IP match across 193 files (+ `install.sh` wget fallback); zips repacked. API — `grep -qwF` in `add/delete-noobz` (4 sites; proven `ali`/`alice` mix-up before), `partial:true` + `failed_from[]` in `delete-xray` when transports refuse, `require_tool` per transport in `cek-xray` instead of silent skip.
- **Verified:** panel grep shows zero leftovers, `bash -n` clean everywhere; API stub tests (collision refused, partial flag exact, missing tool named).

### Fix 347 - Phase 18: quote destructive-adjacent expansions + harden API server sockets (Found 347)

- **Fix 347 (Found 347):** panel — quotes in 27 files (3× `sed -i "$MYIP*"`, 24× `grep -w "$user"`, `"$VPN_USER"`, `"$1"` ×2); zips repacked. API `server` — 64-deep accept queue, 30s socket silence cap, 1MB body cap (413 + close, handler skipped), `WatchedFileHandler` for log rotation, broken-pipe guard on every reply path. Single-threaded kept; full request environment kept (locale-sensitive panel scripts depend on it — stripping it would change `sort`/`date` behavior).
- **Verified:** `bash -n`/`py_compile` clean; backlog pain reproduced before (2/12 through) and re-tested after; 413 closes TCP with server alive; rotation-safe logging; no token in logs.

### Fix 348 - Phase 19: time caps on background fetches + uninstall reset (Found 348)

- **Fix 348 (Found 348):** panel — 10s on 8 quota Telegram sends, 10s on restore/install info lookups, 120s on 62 reinstall downloads; zips repacked. API `menu-api` — `reset-failed` on uninstall; README method-convention note.
- **Verified:** `bash -n` clean everywhere; no request/response logic touched.

### Fix 349 - Phase 21: one restart per daemon run (Found 349)

- **Fix 349 (Found 349):** `need_restart` flag + single post-loop `xray -test`-gated restart in all 24 daemon files; per-user Telegram notices unchanged; zips repacked.
- **Verified:** sandbox runs (2-lock/2-quota/2-kill triggers → 1 restart each; zero-trigger → 0); `bash -n` clean ×24; no in-loop restart left by scan.

### Fix 350 - Phase 22: one shared lock per JSON file for daemons (Found 350)

- **Fix 350 (Found 350):** `exec 9` + `flock -w 30` around the edit sections of all 26 daemon files (per-file lock, held for milliseconds-to-seconds, skip-and-retry on timeout); zips repacked.
- **Verified:** counter race 40/80 lost → 0/80; pre-lock pile-up dropped a healthy account, locked pile-up exact; `bash -n` clean ×26.

### Fix 351 - Live: unlock skips re-add when already present (Found 351)

- **Fix 351 (Found 351):** exact-match guard in all 8 `unlock-*.sh`; zips repacked.
- **Verified live on the VPS:** duplicate scenario prints the skip message, single entry kept, `Configuration OK`, card restored.

### Fix 352 - Live: quota-xhttp resurrected (Found 352)

- **Fix 352 (Found 352):** repo `function split()` → `function xhttp()` (both editions) + zips; live box: stale `quota-split.service` stopped/disabled/removed, `quota-xhttp.service` created from template, enabled, active.
- **Verified live:** full over-quota cycle with audit line; `Configuration OK`; 0 failed units.

### Fix 343 - Phase 14: full-length API token (Found 343)

- **Fix 343 (Found 343):** `head -c 32` → `head -c 48` in `token()` (`fn-autosc-api/menu-api:18`); charset and 40-char cut unchanged, so existing tokens stay valid and rotation works as before.
- **Verified:** `bash -n` clean; 2000-draw distribution all exactly 40 (was 41/1000 short, min 36).
















### Fix 353 - Main menu XHTTP count clobbered by status variable (Found 354)

- **Fix 353 (Found 354):** renamed the HTTP-upgrade *status* pair `vxhttp`/`xhttp` → `vxhup`/`xhup` in `full/menu.sh` (status block + `HTTP: $xhup` display line); the XHTTP *count* `$xhttp` is untouched, so `XTLS XHTTP : $xhttp` shows the number again; `menu/full.zip` repacked entry-only (5-byte delta), `menu/lite.zip` byte-identical.
- **Verified:** `bash -n` clean; repo-wide collision sweep now empty; stubbed runtime run prints count `2` with independent ON/OFF statuses.
### Fix 354 - Short labels unified to HU (Found 355)

- **Fix 354 (Found 355):** `XTLS HTTP UP` → `XTLS HU` and `HTTP:` → `HU:` in `full/menu.sh` (colon alignment kept); `HTTP :` → `HU :` in `full/menu-x.sh` and `lite/menu.sh`; lite option tag `(HTTP)` → `(HU)`. Full transport names on cards/options untouched. Both zips entry-refreshed (2-byte deltas each).
- **Verified:** `bash -n` clean ×3; no `HTTP UP`/`HTTP: $` menu labels remain.
### Fix 355 - List accounts gets the numbered chooser (Found 356)

- **Fix 355 (Found 356):** all 8 `list-xray-*.sh` now print a numbered list + Total, accept number or name, and show that one account's block (same fields, locked/unlocked branches kept); empty database prints a clean message; out-of-range/unknown input prints `User not found`. Also fixed the `list-xray-http.sh` title to "Member XTLS HTTP Upgrade Account". Both zips entry-refreshed.
- **Verified live:** 2-account box lists + Total; pick-by-number and pick-by-name show the right card with UUID; bad name and `9` both rejected cleanly; API `list-xray` unaffected (reads JSON directly).
### Fix 356 - List chooser styled like Check Database Logs (Found 357)

- **Fix 356 (Found 357):** all 8 `list-xray-*.sh` now render rainbow separators, centered `XTLS <T> ACCOUNT LIST` headers, blue-rule/Total/blue-rule + orange exit line, and the plain `Input Username:` prompt — same visual shape as option 10. Card separators match. Both zips entry-refreshed.
- **Verified live:** stripped-color render shows identical structure to the database tool; pick-by-number still resolves correctly.
### Fix 357 - RSEP defined before first use (Found 358)

- **Fix 357 (Found 358):** moved the `RSEP='...'` definition above the header block in all 8 `list-xray-*.sh`. Both zips entry-refreshed.
- **Verified live:** title area renders rainbow/title/rainbow with no blank line; pick-by-number still resolves.
### Fix 358 - Auth gates race both sources, first valid wins (Found 359)

- **Fix 358 (Found 359):** all 192 gates (`full/`, `lite/`, `installer/`) plus `menu-api` (fn-autosc-api) now fetch Pages + GitHub at once and take the first *complete* reply containing `###` (`.done` markers prevent truncated reads; fast error pages are skipped, not trusted); 15s overall bound, fail-closed when both fail. Both zips refreshed.
- **Verified:** 4-scenario mock matrix (fast/slow good, fast-bad + slow-good, both bad, both down) all correct; live race takes ~1s with 7 entries and no temp leftovers; gate green on the VPS.
### Fix 359 - Daemons enforce through auth outages (Found 360)

- **Fix 359 (Found 360):** the 36 background-daemon gates now continue on *fetch failure* (`SKIP_AUTH=1`, `EXPIRED_DATE` treated as lifetime, unlicensed tag in logs) while an *unlisted/expired* machine still exits exactly as before; interactive menus, add/extend/delete and installer gates stay fail-closed. Both zips refreshed.
- **Verified live:** blackout test — menu/add/extend blocked, `xp` reaped an expired account (exit 0, audit line, valid config), live tunnel traffic clean throughout, quota units still active, box green after unblock.
### Fix 360 - Rainbow separators render dashes (Found 361)

- **Fix 360 (Found 361):** all rainbow inputs changed from 35 `=` to 35 `-` (same length, layout and centering preserved); plain card borders, purple dividers and code comments untouched. Both zips refreshed.
- **Verified:** rendered output contains 0 `=`; `bash -n` clean on all touched scripts; `gofmt` deltas pre-existing only.
### Fix 361 - No more `===`, all submenus rainbow/blue styled (Found 362)

- **Fix 361 (Found 362):** every `===` (3+ runs) replaced repo-wide — Telegram cards keep their width, only the character changed to `-`; TUI boxes now use rainbow `${separator}` for title frames and bottom lines, blue `${blue_sep}` for inner dividers (all 35 wide). `routing-*`/`change-id-*` (both editions) gained the standard `rainbow_sep` block; `extend-ssh.go` gained `rainbowSepGo` and its binary was rebuilt. Yellow `\e[33m` prompt dividers in `dm-menu`, log-file lines, and `━━━`/`───` box tools intentionally untouched (already dash/box style, not `===`). The one leftover `===` is a `#` code comment, never shown on screen. Both zips refreshed with ELF entries preserved.
- **Verified:** `grep ===` clean except that comment; `bash -n` clean on all touched scripts; `extend-ssh` builds and runs; box renders checked centered and tidy.
### Fix 362 - Terminal screens all rainbow/blue (Found 363-367)

- **Fix 362 (Found 363-367):** `cek-*` online checkers (8 files), `extend-*`/`delete-*` pickers and cards (16 files, plus recentered 49-wide titles to 35), Go SSH tools (`delete-lists-ssh` cyan 42, `pwd-ssh` plain 47, `change-limit-ip-*`/`limit-ip.go` 50-wide kept for wide tables with new `barisBiru` inner dividers), and the menu islands (`menu-noobz` cards + round `╭` frames, `menu-argo` details, `menu-system` timezone incl. `lolcat` removal on frame lines, `bmenu`/`restore-ftp` result cards, `cek-login-ssh` headers/rules, `limit-ip-ssh` headers colorized blue in place, `dm-menu` yellow dividers) all use rainbow title/bottom + blue inner. Title/bottom lines use `${separator}`, inner dividers `${blue_sep}`; wide data tables keep content-fit widths. All affected Go binaries rebuilt (19 total).
- **Verified:** `bash -n` clean; every converted Go tool builds; `grep` clean for `===`/`━━`/`──`/`══` outside comments, progress animations (`██`) and login-banner art; renders checked.
### Fix 363 - Telegram payloads and installer use dashes (Found 368)

- **Fix 363 (Found 368):** all Telegram `<b>━━━</b>`/`<code>───</code>` payloads and `═` cards swapped to `-` at the same widths (card layout unchanged, colors/tags kept); `installer/slowdns.sh` `===` box, `installer/full.sh`/`lite.sh` Telegram card + `___` install banners swapped the same way. SSH login-banner art (`issue.net`) and the root PS1 prompt art deliberately untouched (decorative art, not separators). Cron-daemon terminal one-liners (`expire-ssh`, `limit-ip-*` skip notices) left as-is (not interactive screens).
- **Verified:** same grep gates as Fix 362; installer scripts pass `bash -n`.
### Fix 364 - Change-limit tables readable (Found 369)

- **Fix 364 (Found 369):** table top back to rainbow (blue reserved for the colhead divider and pre-count divider); empty tables print a `No accounts found.` row instead of doubled bare lines; blank line after the username prompt so the next screen starts clean; error path shows the error directly instead of re-printing the whole banner. Binaries rebuilt.
- **Verified:** all 9 tools build; local + live renders checked.
### Fix 365 - Change-limit screens are one card (Found 370)

- **Fix 365 (Found 370):** brand line removed; banner-bottom doubles as table/card top so each screen is a single frame (title, table, count, bottom). `limit-ip.go` banner now titles the tool (`Menu Change Limit IP SSH`) instead of branding. Binaries rebuilt.
- **Verified:** all 9 tools build; populated + empty renders checked live.
### Fix 366 - Change-limit screens list like list-account (Found 371)

- **Fix 366 (Found 371):** the 9 change-limit tools drop the wide table for the list-account pattern — green `01.` numbering, `Total Accounts: N`, orange Ctrl+C hint, and number-or-name input (a number picks from the list, a name is used as-is). Details (expiry, current limit) still show on the Before card after picking. `limit-ip` main also gained its tool title. Binaries rebuilt.
- **Verified:** all 9 tools build; populated + empty renders checked.
### Fix 367 - Change-limit rows show current limit (Found 372)

- **Fix 367 (Found 372):** numbered rows now read `01. name  <limit>` (name padded to 20, limit right after), fed from the same limit source the Before card shows. Binaries rebuilt.
- **Verified:** all 9 tools build; populated render checked.
### Fix 368 - Change-quota screens list like change-limit (Found 373)

- **Fix 368 (Found 373):** the 8 change-quota tools now mirror the change-limit pattern — rainbow title/bottom, blue inner dividers, green `01.` numbering with current quota right-aligned, `Total Accounts`, orange hint, number-or-name input, empty state exits clean. Brand banner replaced with per-transport titles; BEFORE/AFTER/Credit cards on the same separators.
- **Verified:** `bash -n` clean; live 18-row render with quotas checked.
### Fix 369 - Air between stacked screens (Found 374)

- **Fix 369 (Found 374):** every `clear`/`clearScreen()` is now followed by one blank line, so each titled screen starts with breathing room even where clear does nothing. Pure insertions plus EOF-newline normalization; no logic touched. All affected Go binaries rebuilt.
- **Verified:** `bash -n` clean on all touched scripts; all 28 Go tools build; transition renders checked with clear sequences stripped (broken-terminal simulation).
### Fix 370 - Five-line gaps after every clear (Found 375)

- **Fix 370 (Found 375):** every `clear`/`clearScreen()` is now followed by exactly five blank lines (normalized, so reruns stay at five). Pure insertions; no logic touched. All affected Go binaries rebuilt.
- **Verified:** `bash -n` clean; all 28 Go tools build; per-clear count audited (zero off-spec).
### Fix 371 - Three-line gaps after every clear (Found 375 follow-up)

- **Fix 371:** operator dialed the spacing back from five blank lines to three. Same normalization (exactly three, rerun-stable). All affected Go binaries rebuilt.
- **Verified:** `bash -n` clean; all 28 Go tools build; per-clear count audited (zero off-spec).
### Fix 372 - Color path aliases with rotated links (Found 376)

- **Fix 372 (Found 376):** 36 nginx color locations (3 unique colors per each of the 12 backends) rewrite to canonical upstream — zero xray changes. All 48 link builders rotate the copyable link across canonical + colors via `/etc/xray/.colorseq`; cards stay the same length and descriptions keep the canonical path. No new terminal colors introduced (links/descriptions stay in the existing palette). Quiz: standalone `rewrite…break` before an `if` guard 502s on exact HU locations in this nginx build — HU colors use `proxy_pass` with URI form instead (WS-in-if and gRPC forms tested fine and were kept).
- **Verified:** all 36 aliases return their canonical's exact status live; 4 sequential creates cycled `/vmws`→`/red`→`/crimson`→`/scarlet`; `bash -n` clean; `nginx -t` clean.
### Fix 373 - Multi-domain rotation (Found 377)

- **Fix 373 (Found 377):** `/etc/xray/domains` holds extra domains; all 48 xray link builders plus both SSH cards rotate the connection domain round-robin via `/etc/xray/.domainseq` (primary first in list order, no privilege; clean fallback when the file is missing). Cards show the used `Domain` plus a `Domains` available line; link hosts follow the rotation. Domain menu gains add/remove with validation, dedupe, nginx `server_name` resync + reload; cert issuance covers only DNS-pointed domains (skips the rest instead of failing the whole order). Quiz: `grep -v … && mv` never moves on full match — removal uses `|| true`.
- **Verified:** live add/remove cycle with a nip.io domain; 2 sequential creates rotated primary then extra; link hosts decoded; `bash -n` clean.
### Fix 374 - Domain menu restructured with inventory cards (Found 378)

- **Fix 374 (Found 378):** menu is now Add / Remove / List / Acme / Certbot / Self-Sign (each cert flow picks a domain first with a DNS warning; self-signed CN follows the choice). Removed the dead single-domain changer, cert submenu, and certbot duplicate (reference-checked: only original or superseded lines went). List renders one shared-framed card per domain with the 7-type account roster. Quiz: naive first-`}` function matching eats nested definitions — anchor ends on the next sibling definition instead.
- **Verified:** `bash -n` clean both editions (identical modulo haproxy); two-domain cards, add/remove cycle, and pick-cancel all proven live with zero writes on cancel.
### Fix 375 - Self-signed default, manual trusted certs (Found 379)

- **Fix 375 (Found 379):** installer `issue_certificate()` now generates a self-signed cert directly (LE/ZeroSSL attempts removed from the install path; certbot package still installed for manual option 5). Adding a domain auto-generates and installs a multi-SAN self-signed covering primary + extras, and says so on screen (re-running trusted issuance stays manual via options 4/5).
- **Verified:** live add cycle served a dual-SAN self-signed, then the trusted LE cert was restored byte-identical; `bash -n` clean.
### Fix 376 - X11/agent forwarding off, exec denial proven (Found 380)

- **Fix 376 (Found 380):** `installer/ssh.sh` now enforces `X11Forwarding no` + `AllowAgentForwarding no` idempotently (replace-or-append, survives reinstalls); live box reloaded. `AllowTcpForwarding yes` kept (the product), `PermitTunnel` stays default no, no `Match`/`ForceCommand` added. Proven live: `id` exits 1 with no output, sftp/scp refused, `-L` tunnel still carries HTTP 101, X11 request fails on channel 0.
- **Verified:** `bash -n` clean; `sshd -t` clean; sessions survived reload; 0 failed units.
### Fix 377 - Plain-slash trojan links + backticked copyable links (Found 381)

- **Fix 377 (Found 381):** dropped the `%2f` encoding entirely in the 4 trojan WS builders (`full/`+`lite/`, add+trial): `epath` line deleted, TLS link uses plain `$opath` like the http/xhttp/grpc siblings (`?path=/navy`). All 84 xray link lines (`Link TLS`/`Link None` across 48 builders, both editions) plus the WG `Link Config` and SSH `Config OVPN` URLs are wrapped in literal backticks (escaped `` \` `` in source — bare backticks inside `TEKS="…"` execute as command substitution and blank the links, caught live before deploy). Companion fix in `fn-autosc-api/handlers/add-xray`: link extractor now excludes backticks (`[^[:space:]` `` ` `` `]+`) so API responses stay clean.
- **Verified:** TUI trojan create shows `` `trojan://…?path=/navy…` ``; `bash -n` clean on all touched scripts; zips repacked deterministically (0755, script↔zip parity rechecked); 27 full-edition scripts redeployed to live `/usr/bin` with remote `bash -n` clean.
### Fix 378 - Telegram-only backticks (Found 382)

- **Fix 378 (Found 382):** reverted the in-card backticks (cards, `.log` files and terminal output are plain again); the two `Link` lines are wrapped in backticks by an extra `sed` expression applied only to the Telegram `text=` payload in all 48 xray builders, and the `Config OVPN` line the same way at the SSH sender call sites. The `fn-autosc-api` extractor change from Fix 377 is reverted (nothing to exclude anymore).
- **Verified:** send-pipeline replay on sample cards wraps only link lines; `bash -n` clean on all touched scripts; zips repacked (0755, parity rechecked); full-edition scripts redeployed with remote `bash -n` clean; live TUI card shows plain links.
### Fix 379 - Copyable links via HTML code tags (Found 383)

- **Fix 379 (Found 383):** the send-time wrap now emits `<code>link</code>` instead of backticks in all 48 xray builders and at both SSH sender call sites; all card sends gained `parse_mode=html` + `disable_web_page_preview=1`, and `&` is escaped to `&amp;` first (links carry query `&`; Telegram decodes entities on copy, so the pasted link is pristine). Cards, `.log` files, terminal output and API responses remain untouched plain text.
- **Verified:** send-pipeline replay produces balanced-tag HTML with no raw `&`; card templates audited free of `<`/`>`; `bash -n` clean; zips repacked (0755, parity rechecked); full-edition scripts redeployed with remote `bash -n` clean.
### Fix 380 - Headed link blocks (Found 384)

- **Fix 380 (Found 384):** all 48 xray builders (both editions) print each link as its own block (`---`, `🟢 VMess WS TLS`, blank line, bare link); gRPC keeps a single block. The Telegram send-time wrap now targets bare-scheme lines (`^(vmess|vless|trojan)://…` → `<code>`), replacing the two `Link`-prefix expressions; `&amp;` escaping, HTML mode and preview-disable unchanged. Terminal, `.log` and API text stay plain.
- **Verified:** send-pipeline replay wraps only link lines; `bash -n` clean; zips repacked (0755, parity rechecked); full-edition scripts redeployed with remote `bash -n` clean.
### Fix 381 - Working code wrap + aligned colons (Found 385)

- **Fix 381 (Found 385):** link wrap redone as three single-scheme expressions (no alternation), verified byte-for-byte from the deployed file; every `Label : value` card row is additionally wrapped in `<code>` at send time (monospace → colons line up in Telegram), while separators, titles, blanks and bare-link handling are untouched. Source padding normalized per block (xray main/detail col 9, trojan ports col 10, grpc col 13, SSH col 12; `BadVpn/Udpgw` left as the documented exception — label longer than the column). Terminal cards, `.log` files and API output keep plain text with the same aligned padding.
- **Verified:** send-chain replay from repo bytes wraps only intended lines; `bash -n` clean; zips repacked (0755, parity rechecked); all 26 full-edition scripts hash-verified deployed; live TUI card shows aligned headed blocks.
### Fix 382 - Bold labels beside code values (Found 386)

- **Fix 382 (Found 386):** the send-time row wrap now emits `<b>label</b> <code>value</code>` as sibling entities in all 48 xray builders and both SSH senders (replacing whole-row `<code>`). Terminal cards, `.log` files and API output unchanged.
- **Verified:** send-pipeline replay yields sibling entities; `bash -n` clean; zips repacked (0755, parity rechecked); full-edition scripts redeployed with remote `bash -n` clean.
### Fix 383 - Path Alt rows, icon-free notices, aligned colons (Found 387)

- **Fix 383 (Found 387):** all 48 xray builders print `Path Alt : <colors>` (grpc: bare service-color words) sourced from their own `opaths` arrays; stripped 7 emoji codepoints from 64 notice templates (delete/extend/change-id/locked/unlock/limit-ip/quota/kill/auto-delete, both editions); normalized label padding per block (xray col 9, trojan ports col 10, grpc col 13, SSH col 12; `BadVpn/Udpgw` left — label longer than its column); plain-text senders (backup caption, noobz create/delete, limit-ip-ssh) gained `parse_mode=html` + the shared row-wrap; Go senders rewritten (`limit-ip.go` notice) or HTML-ified (`log-database-*`, `log-acc-ssh` forwarders) and all 10 affected binaries rebuilt (`CGO_ENABLED=0`, `-ldflags="-s -w"`) with zip ELF entries refreshed. xp plain notices (no labels/icons) intentionally untouched.
- **Verified:** `bash -n` + `gofmt` clean; live TUI create/extend/lock/unlock/delete + noobz cycle + backup all fired; zips repacked (0755, parity rechecked); scripts hash-verified and binaries hash-verified on the live box.
### Fix 384 - Whole-row code, ISP/Region rows (Found 388, Found 389)

- **Fix 384 (Found 388, Found 389):** row wrap emits whole-row `<code>label : value</code>` (no bold) in all 48 xray builders and both SSH senders; every account card and the backup caption gained `ISP`/`Region` rows (xray col 9, SSH col 12, backup col 8) sourced from `/root/.isp` + `/root/.region` with empty fallback.
- **Verified:** `bash -n` clean; zips repacked (0755, parity rechecked); full-edition scripts redeployed hash-verified; live TUI cards show the new rows.
### Fix 385 - Color-only links, whole-row notices, clean wording (Found 390, Found 391)

- **Fix 385 (Found 390, Found 391):** rotation arrays hold colors only with a self-sizing modulo (`% ${#opaths[@]}`) — canonical paths never appear in links again (4 sequential live creates cycled scarlet/red/crimson/scarlet). All baked notice rows rewritten as whole-row `<code>Label : value</code>` (delete/extend/change-id/change-quota/locked/unlock/limit-ip/quota/kill/auto-delete, both editions, plus the Go SSH notice which was rebuilt and redeployed). Wording: `ACOUNT`→`ACCOUNT`, notes rewritten in clean English (`badwidth`/`didalam` gone), `HABIS`→`Quota Exhausted`, `Pengguna Dihapus`→`Deleted Users`, `Clear Log`→`Log Cleanup`. `Protokol` deliberately kept — it is parsed from old log cards by list/cek/unlock, and renaming would strand existing locked accounts.
- **Verified:** `bash -n` + `gofmt` clean; zips repacked (0755, parity rechecked); scripts hash-verified and binaries hash-verified on the live box.
### Fix 386 - Path Alt column alignment (Found 392)

- **Fix 386 (Found 392):** `Path Alt:` (col 9, vmess/vless), `Path Alt :` (col 10, trojan), `Service Alt :` verified col 13 (grpc); SSH ports block padded uniformly to col 15 including `BadVpn/Udpgw`. A block-uniformity audit now reports zero strays outside terminal-only menus.
- **Verified:** live trojan card shows aligned Path/Path Alt/Network; `bash -n` clean; zips repacked (0755, parity rechecked); deployed scripts hash-verified.
### Fix 387 - Telegram card layout unification (Found 393–397)

- **Fix 387 (Found 393–397):** `Config OVPN   :` padded to col 15; Go SSH notice rules swapped to ASCII dashes (binary rebuilt, redeployed, hash-verified); every section title left-aligned (`Limit Detail`, `Detail Port …`); trojan ws/http/xhttp restructured to the shared three-section layout (top block → Limit Detail → Detail Port → Path/Network) with ports split out of the path block; missing `Detail Port WS/HU/XHTTP/GRPC` titles added to vless + grpc builders (titles uppercased to the link short codes); main titles unified to `Xray` + short codes wrapped double-icon (`🟢 Xray VMess HU 🟢`, …, `🟢 Xray Trojan WS 🟢`) while link rows keep their single-icon short form (`🟢 VMess HU TLS`). `🟢 SSH Account 🟢` keeps its name (not an Xray card).
- **Verified:** live trojan/vless/grpc/ssh cards show the unified layout; limit-ip change fires the dash-rule notice (`Telegram notification sent successfully!`); `bash -n` clean; zips repacked (0755, parity rechecked); deployed scripts grep-verified; box left with 0 test residue.
### Fix 388 - Blue link-row icons (Found 398)

- **Fix 388 (Found 398):** all 84 single-icon link headers across both editions switched from green to blue (`🔵 VMess WS TLS`, …, `🔵 Trojan GRPC`); the 12 double-icon card titles stay green (`🟢 Xray VMess WS 🟢`, …). `🟢 SSH Account 🟢` untouched (title, not a link row).
- **Verified:** live VMess WS card shows green title + blue link rows; `bash -n` clean; zips repacked (0755, parity rechecked); deployed scripts grep-verified; box left with 0 test residue.
### Fix 389 - Account-deleted titles, unified DD-Mon-YYYY dates (Found 399, Found 400)

- **Fix 389 (Found 399, Found 400):** delete titles swapped to `X-RAY … ACCOUNT DELETED` (8 files), matching the existing `Account Expired` / `Account Deleted` precedent. Every user-visible date now renders `07-Oct-2026`: Xray exp/exp4 generations, notice `Date` stamps (time kept), WG/Noobz/L2TP displays, SSH chage reformat (with fallback), Go `extend-ssh`/`limit-ip` displays (both binaries rebuilt, redeployed, hash-verified). Deliberately untouched internals: `useradd`/`usermod -e` (`YYYY-MM-DD`), chage parsing, epoch math, `.quota.logs`, dead `biji`/`hariini` lines. Auth repo converted (header + all 5 entries) — the gate parses via `date -d`, verified for the new shape.
- **Verified:** live VMess card `Expired : 06-Nov-2026`, live SSH card `Expired : 06-Nov-2026`, live delete fires `X-RAY WS ACCOUNT DELETED`; `bash -n` + `gofmt` clean; zips repacked (0755, parity rechecked); deployed scripts/binaries verified; box left with 0 test residue.
### Fix 390 - Bare delete title + Type row (Found 401)

- **Fix 390 (Found 401):** all 8 delete notices retitled to bare `<b>ACCOUNT DELETED</b>`; body now `Date/Username/Type/Expired` (`Type: WS/HU/XHTTP/GRPC` per transport, colon-aligned col 10) in both the Telegram card and the TUI echo.
- **Verified:** live delete shows `Client Name/Type: WS/Expired On: 06-Nov-2026` in TUI and fires the titled card; `bash -n` clean; zips repacked (0755, parity rechecked); deployed scripts verified; box left with 0 test residue.
### Fix 391 - Bare extend title, uppercase circle titles (Found 402–404)

- **Fix 391 (Found 402–404):** all 8 extend notices retitled to bare `<b>EXTEND EXPIRATION</b>` with `Type: WS/HU/XHTTP/GRPC` below `Username` (colon-aligned col 14) in card and TUI; extend `DATE` stamps converted to `%d-%b-%Y %H:%M:%S` (the `%y` variant Fix 389 missed); all 12 green-circle card titles uppercased (`🟢 XRAY VMESS WS 🟢`, …, `🟢 SSH ACCOUNT 🟢`). Blue link rows untouched by design.
- **Verified:** live extend shows `Type: WS` in TUI and fires the titled card; `bash -n` clean; zips repacked (0755, parity rechecked); deployed scripts verified; box left with 0 test residue.
### Fix 392 - Flush limit notice, bare Detail Port, canonical card skeleton (Found 405–407)

- **Fix 392 (Found 405–407):** Go SSH notice raw string dedented (payload now flush-left; binary rebuilt, redeployed hash-first after killing the stale uploader holding the old inode busy, exec verified live). All 48 `Detail Port …` headers trimmed to bare `Detail Port`. Canonical skeleton in all 12 builders (both editions, add+trial): title → 8-row account block → `Limit Detail` → port-only `Detail Port` → detail rows (`AlterID?/Path|Service`, `Path Alt|Service Alt`, `Network`, `Alpn?/Decrypt?`) → links; labels unified (`Service`, `Port`); every separator run normalized to 23 dashes.
- **Verified:** live VLess WS + Trojan GRPC cards show the canonical layout; `bash -n` + column audit clean; zips repacked (0755, parity rechecked); deployed scripts verified; box left with 0 test residue.
### Fix 393 - Restyled change TUIs (Found 408)

- **Fix 393 (Found 408):** short centered banners (`Change Limit IP WS/HU/XHTTP/GRPC`, `Change Quota WS/HU/XHTTP/GRPC`, 16 files both editions); credit functions/blocks removed (flows exit cleanly); Go errors in English; Before/After share `Username/Exp Date/IP Limit` at one column. Binaries rebuilt, shipped inside the zips, deployed via single-bundle upload with hash verify.
- **Verified:** live limit change shows the short banner + aligned Before; live quota change shows the short banner with no credit text; `bash -n` clean (Go `gofmt` drift is pre-existing, untouched); zips repacked (0755, parity rechecked); box left with 0 test residue.
### Fix 394 - Return pauses on change tools (Found 409)

- **Fix 394 (Found 409):** `Press any key to return...` pause added to the Go limit success + not-found paths and both shell quota exits (after telegram send on the success path). Binaries rebuilt, shipped in zips, deployed in one combined bundle with hash verify.
- **Verified:** live limit/quota runs wait on the result screen; `bash -n` clean; zips repacked (0755, parity rechecked); box left with 0 test residue.
### Fix 395 - Pause on empty no-accounts path (Found 410)

- **Fix 395 (Found 410):** `Press any key to return...` added to the Go limit and shell quota no-accounts branches (16 files, both editions). Binaries rebuilt, shipped in zips, deployed in one combined bundle with hash verify.
- **Verified:** empty-box option 15/16 now hold on `No active accounts found.` + pause instead of flashing; `bash -n` clean; zips repacked (0755, parity rechecked); box left with 0 test residue.
### Fix 396 - Centered TUI titles, 35-dash rainbows (Found 411, Found 412)

- **Fix 396 (Found 411, Found 412):** `format_display` centers title lines (main, section, link headers, wide-emoji compensated) using terminal width — Telegram payloads untouched and verified still left. All inline prompt rainbows regenerated to 35 segments in the main-menu gradient (26 files); Go rainbow/blue runs cut to 35 (change-limit ×8, limit-ip, delete/list/pwd-ssh); 7 binaries rebuilt. Deployed scripts + binaries (one bundle, hash-verified) and the renderer copy.
- **Verified:** live card shows centered titles in TUI with left payload on disk; `bash -n` clean; zips repacked (0755, parity rechecked); box left with 0 test residue.
### Fix 397 - Card-relative title centering (Found 413)

- **Fix 397 (Found 413):** renderer centers on width 35 (wide-emoji compensated); Go limit + shell quota banners re-padded to 35; all 24 `Create …` prompt titles recentered to 35. Telegram payloads still left (re-verified). Binaries rebuilt, one-bundle deploy with hash verify.
- **Verified:** live card title sits centered over the 35-dash body; `bash -n` clean; zips repacked (0755, parity rechecked); box left with 0 test residue (one `trial452` present is operator-made, preserved).
### Fix 398 - Number-or-name everywhere (Found 414)

- **Fix 398 (Found 414):** delete/extend/change-id lists numbered (`01. user  exp`, both editions); all pickers (delete/extend/change-id/unlock/lock, plus prompt wording on quota/list/Go) accept a list number or a username (`10#` base-guarded, out-of-range falls back to name lookup). Go binaries rebuilt.
- **Verified live per group:** delete #1, extend #1, change-id #1, lock #1, unlock #1, quota #1, limit #1 — all resolve by number; `bash -n` clean; zips repacked (0755, parity rechecked); one-bundle deploy with hash verify; box left with 0 test residue.
### Fix 399 - Names-only UUID picker with old/new display (Found 415)

- **Fix 399 (Found 415):** change-id lists numbered usernames only; after picking, the flow prints `Old UUID:` then prompts `New UUID:` (empty still auto-generates). Number mapping re-proven live across two accounts: pick `2` rotated only the displayed second user.
- **Verified:** `bash -n` clean; zips repacked (0755, parity rechecked); deployed scripts hash-verified; box left with 0 test residue (`trial452` is operator-made, preserved).
### Fix 400 - Random hint on UUID prompt (Found 416)

- **Fix 400 (Found 416):** prompt now `New UUID (Enter for random): ` in all 8 change-id scripts.
- **Verified:** `bash -n` clean; zips repacked (0755, parity rechecked); deployed scripts grep-verified.
### Fix 401 - Card-width title centering (Found 417)

- **Fix 401 (Found 417):** renderer measures the longest dash run in the card and centers titles on it (wide-emoji compensated), instead of a fixed 35. Payloads untouched.
- **Verified:** live render holds titles inside the 23-dash body; renderer hash-verified on box.
### Fix 402 - XRAY spelling unified (Found 418)

- **Fix 402 (Found 418):** all `X-RAY`/`X-Ray`/`X-ray` spellings converted to `XRAY` (68 files, both editions, shell + Go; commands/paths are lowercase and untouched, nothing parses the hyphenated forms). 3 cek binaries rebuilt.
- **Verified:** `bash -n` clean; zips repacked (0755, parity rechecked); one-bundle deploy with hash verify on scripts + binaries.
### Fix 403 - Xray multilogin auto-unlock (Found 419)

- **Fix 403 (Found 419):** lock writes a due-epoch state file (`/etc/xray/autounlock/<t>/<user>`, lock + 10 min so the unlock lands within 15 min on the 5-minute cron); each limit run sweeps due entries through a new non-interactive `unlock-<t>-auto` helper (same restore as manual unlock, silent, idempotent, `XRAY_BATCH` shares the caller flock + single restart); stale states self-clean; lock notices now promise the 15-minute auto-unlock. Manual flows untouched and indefinite. 8 helpers + 8 limit scripts, both editions.
- **Verified live:** past-due lock auto-restored via the cron path (json + log back, valid config, service active); ghost state cleaned; `bash -n` clean; zips repacked (0755, parity rechecked); one-bundle deploy with hash verify; box left with 0 test residue.
### Fix 404 - Delete-style multilogin cards (Found 420)

- **Fix 404 (Found 420):** all 8 multilogin lock notices restyled to the account-deleted shape: bare `<b>ACCOUNT LOCKED</b>` with `Date/Username/Type/Login/Status` (Type `WS/HU/XHTTP/GRPC`, col 10).
- **Verified:** restyled preview delivered live (`ok:true`); `bash -n` clean; zips repacked (0755, parity rechecked); one-bundle deploy with hash verify.
### Fix 405 - Split lock titles (Found 421)

- **Fix 405 (Found 421):** manual notices retitled bare `ACCOUNT LOCKED` (was `XRAY <T> LOCKED ACCOUNT`); multilogin notices retitled `MULTILOGIN LOCKED`. 16 files, both editions.
- **Verified:** restyled preview delivered live (`ok:true`); `bash -n` clean; zips repacked (0755, parity rechecked); one-bundle deploy with hash verify.
### Fix 406 - Protocol/Transport rows, bare unlock title (Found 422, Found 423)

- **Fix 406 (Found 422, Found 423):** all 48 cards carry `Protocol : <UPPER>` + `Transport : <SHORT>`; every `Protokol:` reader (shell + Go) accepts both spellings, extraction fixed to last-field (the spaced new rows broke `$2`), values uppercased at read, restore branches uppercased. 8 unlock notices retitled `ACCOUNT UNLOCKED`. 3 cek binaries rebuilt.
- **Verified live:** new card shows both rows; old-format lock→unlock cycle restores correctly (compat proven); `bash -n` clean; zips repacked (0755, parity rechecked); one-bundle deploy with hash verify; box left with 0 test residue.
### Fix 407 - Bare card titles (Found 424)

- **Fix 407 (Found 424):** all 48 cards titled `🟢 ACCOUNT DETAIL 🟢`; type info lives in Protocol/Transport rows and link headers. SSH card untouched.
- **Verified live:** new card renders bare title + both rows; `bash -n` clean; zips repacked (0755, parity rechecked); one-bundle deploy; box left with 0 test residue.
### Fix 408 - Col-10 top block (Found 425)

- **Fix 408 (Found 425):** top account block widened to col 10 across all 48 cards; extend log-swap handles old and new spacing. Block audit reports zero strays.
- **Verified live:** aligned card + extend moving log and json together; `bash -n` clean; zips repacked (0755, parity rechecked); one-bundle deploy; box left with 0 test residue.
### Fix 409 - Protocol/Transport rows on all notices (Found 426)

- **Fix 409 (Found 426):** delete/extend/multilogin `Type` replaced by the pair; lock/unlock `Protokol` renamed with `Transport` added; change-id/quota titles bared (`CHANGE UUID`/`CHANGE QUOTA`) with the pair added. Protocol read from the account log (both spellings, uppercased); Transport static per script. TUI echoes mirror. 64 files, both editions.
- **Verified live:** extend-by-name flows with new rows; `bash -n` clean; zips repacked (0755, parity rechecked); one-bundle deploy with hash verify; box left with 0 test residue.
### Fix 410 - Unlock parity, SSH notices, expiry spec (Found 427–429)

- **Fix 410 (Found 427–429):** Indonesian unlock confirmations removed (all unlocks direct like ws); SSH change title uppercased (`CHANGE LIMIT IP SSH`, binary rebuilt); SSH multilogin lock restyled to the shared `MULTILOGIN LOCKED` rows (`Type: SSH`, `Login: n / limit`, `Unlock Time` kept); expiry notices rewritten to the specced lowercase rows (8 sections, both editions).
- **Verified live:** direct unlock works; SSH layout + title in new binary; expiry run deletes and notifies in the new shape; `bash -n` clean; zips repacked (0755, parity rechecked); one-bundle deploys with hash verify; box left with 0 test residue.
### Fix 411 - Expiry code rows + bold title (Found 430)

- **Fix 411 (Found 430):** expiry rows colon-aligned at 12 inside whole-row `<code>`; title `<b>EXPIRED ACCOUNT</b>`; `parse_mode=html` added to the 4 Xray expiry sends (other xp sends untouched).
- **Verified live:** expiry run deletes and notifies in the final shape; `bash -n` clean; zips repacked (0755, parity rechecked); deployed + grep-verified; box left with 0 test residue.
### Fix 412 - Capitalized expiry labels (Found 431)

- **Fix 412 (Found 431):** expiry rows now `Username/Protocol/Transport/Expired at`, same columns and code wrap.
- **Verified live:** expiry run notifies in final shape and cleans up; `bash -n` clean; zips repacked (0755, parity rechecked); deployed + grep-verified; box left with 0 test residue.
### Fix 413 - bmenu curl timeout (Found 432)

- **Fix 413 (Found 432):** added `-m 10` to all 12 icanhazip fetches in `full/bmenu.sh` + `lite/bmenu.sh`, matching `restore-ftp.sh`.
- **Verified:** `bash -n` clean; zips repacked (0755, parity rechecked).
### Fix 414 - SSH Go error propagation (Found 433)

- **Fix 414 (Found 433):** `delete-ssh.go` returns `err` on any failed `rm`/`systemctl restart`; `extend-ssh.go` prints `Error unlocking account` and returns on failed `passwd -u` instead of claiming success.
- **Verified:** both binaries cross-compile (`GOOS=linux GOARCH=amd64`); `gofmt` drift pre-existing, untouched; zips repacked (0755, parity rechecked).
### Fix 415 - Telegram Domains-only cards (Found 434)

- **Fix 415 (Found 434):** all 48 Xray creation cards (both editions) strip the `Domain   :` line in the Telegram `sed` pipeline (`/^Domain   : /d` first expression); TUI and `.log` keep both lines. SSH cards (no rotation) untouched.
- **Verified live:** created `testcard_tg1` on fresh install — TUI/`.log` show both lines, simulated Telegram payload shows only `<code>Domains  : ...</code>`; account deleted after, box clean; `bash -n` clean; zips repacked (0755, parity rechecked); single-tarball deploy with hash verify.
### Fix 415 follow-up - SSH cards Domains-only (Found 434)

- **Fix 415 follow-up (Found 434):** `full/addssh.sh:240` + `full/trial-ssh.sh:184` caller pipelines strip `Domain     :` for Telegram; TUI/`.log` keep both lines. Single-domain non-rotation cards (WG/Noobz/L2TP) untouched — no list to fall back on.
- **Verified live:** deployed hash-verified; `.log` shows both lines, Telegram sim shows `Domains` only; `bash -n` clean; full.zip repacked (0755).
### Fix 416 - Template clients level 0 (Found 435)

- **Fix 416 (Found 435):** added `"level": 0` to all 12 default clients in `json/*.json` (last-property rule, marker comments preserved); same patch applied to live `/etc/xray/json/*.json` (snapshot first), all 4 `xray run -test` OK, daemons restarted, 0 failed.
- **Verified:** templates parse as JSONC (12/12 level 0); created accounts already carried it (live `livetest_lv1` proof); routing unchanged (0 is the default level per Decision 23).
### Fix 417 - Atomic self-signed publish (Found 436)

- **Fix 417 (Found 436):** `gen_selfsigned_all` (full + lite `dm-menu.sh`) now has openssl write same-directory temps (`/etc/xray/.xray-selfsigned.{crt,key}.tmp`, removed on failure) and publishes via `mv -f` (same-filesystem rename is atomic); `funny.pem` rebuilt via same-dir temp + `mv`, keeping the best-effort silent semantics when `/etc/haproxy` is absent (lite). No `/tmp` litter; surrounding perms/restarts untouched.
- **Verified:** `bash -n` clean on both files; sandbox replay of the exact new sequence (multi-SAN cert verifies via openssl, 644/600, no leftover tmps); openssl-failure path leaves no tmps; both zips repacked single-entry, IN-SYNC, 0755.
### Fix 418 - Expired lifetime indent (Found 437)

- **Fix 418 (Found 437):** `REMAINING_DAYS=$(calculate_remaining_days ...)` else-branch re-indented 4→8 spaces in 191 scripts (`full/`,`lite/`,`installer/`,`install.sh`); `full/quota-ws.sh:76` + `lite/quota-ws.sh:76` output-if 4→8. No logic change.
- **Verified:** `grep` for 4-space variants returns 0; `bash -n` clean; zips repacked (0755, IN-SYNC).
### Fix 419 - Blank-row cap at 3 (Found 438)

- **Fix 419 (Found 438):** `menu-wg.sh` warp triple-clear collapsed to single `clear`+3x; 8x post-clear `newline` removed; all 8 `change-quota-*.sh` `Loading_Animasi` second 3x removed; `menu-system.sh` `resall` extra `\n\n` removed, `bnnr` leading `\n` removed, `menu-warp` pre-`install()` clear removed (both editions).
- **Verified:** worst-case grep clean; `bash -n` clean on all touched files; zips repacked (0755, IN-SYNC).
### Fix 420 - SSH login check themed (Found 439)

- **Fix 420 (Found 439):** `full/cek-login-ssh.sh` now uses the general theme: full color block + `rainbow_sep`/`separator`/`blue_sep`, `SSH LOGIN CHECK` title card, purple `DROPBEAR/OPENSSH USER LOGIN` sections + purple table headers, `blue_sep` rules (35-wide), `separator` + purple/green total. Logic (Bug 70/71, per-user counts, temp cleanup) untouched; caller pause unchanged.
- **Verified live:** deployed to 157.10.253.95, title/section markers present, `bash -n` clean; zips repacked (0755, IN-SYNC).
### Fix 421 - WS color paths accept prefixes (Found 440)

- **Fix 421 (Found 440):** 9 WS color locations in `config/4.conf,6.conf,dual.conf` changed `location = /c` → `location ~ /c` (`red,crimson,scarlet,green,lime,emerald,blue,navy,azure`), mirroring canonical `location ~ /vmws/vlws/trws`; same `rewrite ... /vlws|/vmws|/trws break` + upstream kept. HU/XH exact aliases untouched.
- **Verified live:** live `/etc/nginx/nginx.conf` patched in place, `nginx -t` ok, service restarted active, `location ~ /green` present; zips do not ship nginx conf (installer pulls `config/`), no zip impact.
### Fix 422 - XTLS menu labels uniform (Found 441)

- **Fix 422 (Found 441):** `full/menu-x.sh` → `1. WebSocket` / `4. gRPC`; `lite/menu.sh` → `1. WebSocket` / `2. HTTP Upgrade` / `3. gRPC` / `4. XHTTP` (all parenthetical suffixes dropped). Wiring (`case` branches) untouched.
- **Verified live:** `/usr/bin/menu-x` on 157.10.253.95 shows `1. WebSocket`; `bash -n` clean; zips repacked (0755, IN-SYNC).
### Fix 423 - Unlock menus pause (Found 442)

- **Fix 423 (Found 442):** all 8 unlock callers (`full/lite x-ws/x-http/x-grpc/x-xhttp` option 13) now `...; echo ""; read -n 1 -s -r -p "Press any key to return..." || true; ...` like options 07/10/11. Empty-list and success outputs stay visible; `unlock-*.sh` bodies untouched (no double-pause).
- **Verified live:** `/usr/bin/x-ws` contains the pause on line 13; `bash -n` clean on all 8; zips repacked (0755, IN-SYNC).
### Fix 424 - Blue-circle headers left-aligned (Found 443)

- **Fix 424 (Found 443):** `config/format.sh` no longer centers `^🔵.*$`; only `🟢…🟢`/`Limit Detail`/`Detail Port` center. `🔵` lines fall through to plain left print, matching Telegram/`.log` (col 0). Green titles stay centered.
- **Verified:** simulated `TEKS` shows `🟢 ACCOUNT DETAIL 🟢` padded, both `🔵 VLess WS` lines at col 0; deployed to 157.10.253.95 (`/etc/funny/format.sh` updated); `bash -n` clean.
### Fix 425 - Prefix paths on all transports (Found 444)

- **Fix 425 (Found 444):** `config/4.conf,6.conf,dual.conf`: HU canonical + 9 colors `location =` → `location ~` with `rewrite /(.*) /<canon> break;` (colors also drop the `/<canon>` suffix from `proxy_pass`, mirroring proven WS blocks); XHTTP canonical `location /<canon>` → `location ~` with same rewrite, 9 colors `=` → `~` with `rewrite ^` → `rewrite /(.*)`; gRPC canonical + 9 colors `location ^~` → `location ~`, rewrites `^/<name>(.*)$` → `^.*/\\/<name>(.*)$` (prefix stripped, method suffix kept). Upstream ports/targets and guards (`websocket`/`POST`) untouched.
- **Verified live:** new `nginx.conf` diffed against live (server_name kept, only location/rewrite/proxy lines change), `nginx -t` ok, restarted active; parity per transport: `/a/vmhu`=`/a/yellow`=404, `/a/vmxh`=`/a/purple`=404, `POST /a/vlgr`=`POST /a/white`=415, `/a/b/vmws`=`/a/b/green`=400.
### Fix 426 - Remaining empty-flash menus pause (Found 445)

- **Fix 426 (Found 445):** all 8 lock callers (`full/lite x-*` option 17) now pause like option 13; `full/menu-ssh.sh` option 9 (`limit-ip`) now pauses like options 4/5/7 (Go binary untouched, no rebuild); `full/xl2tp.sh` `delete()`/`extend()` empty branches now `read ... || true` before `exit 1`. `locked-xray-*.sh`/`limit-ip` bodies untouched.
- **Verified:** `bash -n` clean; live `/usr/bin/x-ws` shows 5 pauses; zips repacked (0755, IN-SYNC).
### Fix 419 follow-up - Remaining upper spacings capped at 3 (Found 438)

- **Fix 419 follow-up (Found 438):** 40 more `clear`+3x+extra-blank spots merged: `menu-dnstt` (4), `menu-argo` (2+2 lite), `menu-noobz` (2), `menu-system`/`lite` (add/menuwg/detail/information/os/tampilan), `menu-bot`/`lite` (3+2 extra), 8 `routing-*.sh` (both editions). Bare `echo -e "` / `echo -e "\n` opening lines joined with next content line; inner message spacing kept.
- **Verified:** repo-wide audit of every `clear` in `full/*.sh`+`lite/*.sh`: all upper spacings exactly 3; `bash -n` clean; zips repacked (0755, IN-SYNC).
### Fix 427 - Main-menu lifetime padding (Found 446)

- **Fix 427 (Found 446):** `full/menu.sh:77` lifetime branch now `Expired      : lifetime`, aligned with the padded siblings. Other editions print unpadded labels throughout, so only the main menu needed it.
- **Verified live:** `/usr/bin/menu` carries the padded line; `bash -n` clean; zips repacked (0755, IN-SYNC).
### Fix 428 - SSH check 3-column table (Found 447)

- **Fix 428 (Found 447):** `full/cek-login-ssh.sh` two 5-column per-line tables replaced by one `show_logins`: unique users per daemon, rows `Username | count/limit | dropbear|openssh`, same theme (title card, blue rules, purple header), same log sources/counts/limit lookup/total. PID/IP columns dropped per spec.
- **Verified live:** `cek-login-ssh` on 157.10.253.95 prints `Username | Login | Type` with real rows (e.g. `root | 31/No Limit | openssh`); `bash -n` clean; zips repacked (0755, IN-SYNC).
### Fix 429 - SSH table refinements (Found 448)

- **Fix 429 (Found 448):** `full/cek-login-ssh.sh`: title card renamed to `SSH USER LOGIN`; duplicate section header removed (table follows title card); header/rows printed space-aligned with no `|`; login is `${count} / ${limit}` with limit lowercased and spaces hyphenated (`no-limit`, `unlimited`); type is `Dropbear`/`Openssh`. Sources/counts/total untouched.
- **Verified live:** `cek-login-ssh` on 157.10.253.95 prints the specced shape with real rows (`root  34 / no-limit  Openssh`); `bash -n` clean; zips repacked (0755, IN-SYNC).
### Fix 430 - SSH table equal gaps (Found 449)

- **Fix 430 (Found 449):** `full/cek-login-ssh.sh` `show_logins` now sizes columns from the longest content and prints both gaps as exactly 4 spaces (`%-<wu>s    %-<wl>s    %s`). Rows collected first, then header + rows share the format.
- **Verified live:** `cek-login-ssh` on 157.10.253.95 shows equal 4-space gaps; `bash -n` clean; zips repacked (0755, IN-SYNC).
### Fix 431 - Domains-only cards everywhere (Found 450-451)

- **Fix 431 (Found 450-451):** deleted the singular `Domain   :` TEKS line in all 50 card files (48 Xray + `addssh`/`trial-ssh`); every card now shows only `Domains  :`. TUI, Telegram and `.log` all follow (same `TEKS`); Telegram strips kept as no-op safety. Rotation re-verified: all links use `$rdomain`, none use `$domain`.
- **Verified live:** created `trial261` on 157.10.253.95 — card shows `Domains` only, link uses rotated domain + color path (`...@autosc.rohcuan.dpdns.org:443?path=/lime...`); account deleted after, 0 residue (no log, 0 refs in `ws.json`); `bash -n` clean on all 50; zips repacked (0755, IN-SYNC).
### Fix 432 - Backup shows auth username (Found 452)

- **Fix 432 (Found 452):** `full/backup.sh` + `lite/backup.sh` caption row now `Username : $USERNAME` (izIN.txt owner, same gate that prints it at startup); `Domain` row gone. Caption `<code>` pipeline, log append and TUI echoes follow (shared `TEKS`).
- **Verified:** caption pipeline renders `<code>Username : ID2</code>`; live `/usr/bin/backup` carries the row, 0 `Domain` rows; `bash -n` clean; zips repacked (0755, IN-SYNC).
### Fix 433 - Adjustable auto-backup interval (Found 453)

- **Fix 433 (Found 453):** `full/menu-bot.sh` + `lite/menu-bot.sh` `setbotup` now parses the live cron line (`*/h` / legacy `0,6,12,18` / hourly / none) into `Current interval  : ...`, prompts `New interval      :` (blank keeps, `^[1-9][0-9]*$` capped 24, re-prompts), rewrites the cron line to `0 */h * * *` (old lines removed, no duplicates) and restarts cron. Title block per sketch: full rainbow, `SETUP AUTO BACKUP`, short rainbow, blue rule.
- **Verified live:** drove `menu-bot` on 157.10.253.95 with dummy creds (removed after): legacy cron parsed as `every 6 hour`, entering 6 wrote `0 */6`; crontab restored to legacy after, creds removed; `bash -n` clean; zips repacked (0755, IN-SYNC).
### Fix 434 - Bot creds notice pauses (Found 454)

- **Fix 434 (Found 454):** `havecreds` (both editions) now waits `Press any key` before returning, covering callers option 2 (`notif`) and option 3 (`setbotup`). Bodies otherwise untouched.
- **Verified live:** notice + pause present in `/usr/bin/menu-bot`; `bash -n` clean; zips repacked (0755, IN-SYNC).
### Fix 435 - addssh recall (Found 455)

- **Fix 435 (Found 455):** `full/addssh.sh` invalid/duplicate branches call `main` (was undefined `add_ssh`) and pauses carry `|| true`. Lite has no SSH builder.
- **Verified:** `bash -n` clean.

### Fix 436 - dm-menu invalid-branch recall (Found 456)

- **Fix 436 (Found 456):** both editions `acme()` invalid IP branch runs `dm1` + `return` (was bare `cert`). Bodies otherwise untouched.
- **Verified:** `bash -n` clean both editions.

### Fix 437 - SlowDNS key chmod (Found 457)

- **Fix 437 (Found 457):** appended `/etc/slowdns/server.key` to the `chmod 600` private-key lists in `full/bmenu.sh` (3x), `lite/bmenu.sh` (3x), `full/restore-ftp.sh`, `lite/restore-ftp.sh`, `website/restore-ftp.sh`.
- **Verified:** `bash -n` clean all five; live restore entries updated via tarball deploy.

### Fix 438 - Restore zip/cd guards (Found 458)

- **Fix 438 (Found 458):** `resold()` aborts when the `outbounds` marker is missing; `restf()` (both bmenus) plus all three `restore-ftp.sh` validate `unzip -tq` before unpacking and guard `cd /root/backup`; URL-based blocks also got the `cd` guard. No SUCCESS on corrupt input.
- **Verified:** `bash -n` clean; deployed live.

### Fix 439 - menu-api exact IP match (Found 459)

- **Fix 439 (Found 459):** `fn-autosc-api/menu-api:42` uses `grep -wF "$LOCAL_IP"` like the panel gates (was substring `grep`).
- **Verified:** `bash -n` clean; committed in `fn-autosc-api` repo scope (sibling checkout).

### Fix 440 - limit-ip-ssh init + batched restarts (Found 460)

- **Fix 440 (Found 460):** `full/limit-ip-ssh.sh` initializes `nais=0`, collects `need_restart`, and runs one `daemon-reload + restart ssh/sshd/ws` after the loop; `passwd -l` stays per-user. `at`-based unlock kept (sweeper migration noted as follow-up).
- **Verified:** `bash -n` clean.

### Fix 441 - quota/kill numeric guards (Found 461)

- **Fix 441 (Found 461):** 8 `quota-*.sh` skip non-numeric `inb/outb` and non-numeric `quota_limit`; 8 `kill-*.sh` skip unless both `usage` and `quota_limit` match `^[0-9]+$`. Idle-user `continue` semantics unchanged.
- **Verified:** `bash -n` clean all 16.

### Fix 442 - Fetch timeout caps (Found 462)

- **Fix 442 (Found 462):** added `--max-time 15/30/60` to the `delete-*` date probe, `menu-wg` Cloudflare reg, installer IP fetches/summaries, `xray.sh` piped installer, `menu-system` repo/warp fetches; `wget` warp uses `--timeout=30`. No URL or logic changes.
- **Verified:** `bash -n` clean.

### Fix 443 - Go error surfacing (Found 463)

- **Fix 443 (Found 463):** `delete-ssh.go`/`list-ssh.go` return `"Error"` when `chage`/`passwd` fail (was fake `No Expiry`/`UNLOCKED`); 6 `cek-xray-*.go` report `Error reading config` to stderr on `ReadFile` failure and render `Not available` on bad quota integers.
- **Verified:** all 8 rebuild with `CGO_ENABLED=0 GOOS=linux GOARCH=amd64` (exit 0); new binaries carry the error strings; repacked into `menu/full.zip`/`menu/lite.zip` (0755); deployed live.

### Fix 444 - WS/HU parity + installer cert atomicity (Found 464)

- **Fix 444 (Found 464):** `config/{4,6,dual}.conf` WS/HU locations (canonical + 18 color aliases, 24 blocks per template) gain the XHTTP streaming set (`proxy_request_buffering off`, `client_max_body_size 0`, `proxy_buffering off`, 300s/300s/60s timeouts, `client_body_timeout 300s`); `installer/diamond.sh` writes via `.tmp` + `mv -f` and dual-stack installs a single cert (was concatenated two-cert bundle).
- **Verified live:** same patch applied to `/etc/nginx/nginx.conf` (24 blocks), `nginx -t` ok, reload clean, canonical `:443/vlws` and prefixed `:443/a/green` both `400`.

### Fix 445 - dm-menu cert/email/quoting/dmsl (Found 465)

- **Fix 445 (Found 465):** both editions — `acme()` initializes `email` from `/etc/funny/.email`, quotes `"$domain"` in acme/certbot/live paths, fallback writes via `.tmp` + `mv`; `dmsl()` delegates to `gen_selfsigned_all` (multi-SAN, atomic, no live delete) instead of single-CN `rm -fr` + direct write.
- **Verified:** `bash -n` clean both editions; deployed live.

### Fix 446 - udp-request empty-IP guard (Found 466)

- **Fix 446 (Found 466):** `installer/request.sh` `ExecStartPost` wraps the RETURN rules in `[ -n "$ip_nat" ]` (interpolated at generation), mirroring the fixnet helper; empty management IP now yields sleep+exit instead of an invalid rule.
- **Verified:** `bash -n` clean.

### Fix 447 - UUID/password charset gate (Found 467)

- **Fix 447 (Found 467):** 24 `add-*.sh` accept custom UUID only if `^[A-Za-z0-9_.-]+$`, else generate with the same fallback UX; 8 `change-id-*.sh` add EOF guard on the prompt and regenerate on unsafe input instead of interpolating raw across all four JSONs.
- **Verified:** `bash -n` clean all 32; standard `xray uuid` output passes the gate.

### Fix 448 - delete/extend name gate (Found 468)

- **Fix 448 (Found 468):** 16 `delete-*`/`extend-*` reset `user=""` when the resolved name fails `^[a-zA-Z0-9_]+$`, so metachar input (`.*`) lands in the existing not-found branch with no mutation, no restart. Numeric picks map through `users[]` first and are unaffected.
- **Verified:** `bash -n` clean all 16; deployed live.

### Fix 449 - Menu retention + quoting (Found 469)

- **Fix 449 (Found 469):** `menu-noobz.sh` quotes `"$TEKS"` in both Telegram sends; `xl2tp.sh` in-function `exit 0/1` become `return` (empty password now errors + returns); `os()` invalid branch loops with `sleep 2`; `menu-bot install()` adds EOF guards, empty-key rejection, and `return 1` instead of `exit 1` on bad chat ID.
- **Verified:** `bash -n` clean; deployed live.

### Fix 450 - Result pauses (Found 470)

- **Fix 450 (Found 470):** `x-{ws,http,grpc,xhttp}.sh` options 8/9/12 (both editions, 8 files) and `full/menu-ssh.sh` options 3/6/8 pause `Press any key` before redrawing. Same one-liner as every other pause.
- **Verified live:** `/usr/bin/x-ws` carries 8 pauses, `/usr/bin/menu-bot` 7; `bash -n` clean.

### Fix 451 - README truth refresh (Found 471)

- **Fix 451 (Found 471):** docs-only — rotation (colors-only), backup caption (Username + adjustable interval), installer (self-signed default, manual 4/5), 6-row domain table, renewal (pick + 4/5), single dual-stack cert, random PSK, Noobz domain pair, restore key-auth, Telegram-only delivery.
- **Verified:** each claim cross-checked against code cited in the entry.
### Fix 452 - gRPC rewrite single-slash (Found 472)

- **Fix 452 (Found 472):** 12 gRPC rewrite lines per template (`config/4.conf`, `config/6.conf`, `config/dual.conf`) changed `^.*/\/<name>(.*)$` to `^.*\/<name>(.*)$`, preserving the method-suffix `$1`. WS/HU/XHTTP form untouched.
- **Verified live:** same 12-line patch on `/etc/nginx/nginx.conf`, `nginx -t` ok, reload clean; color `black` + `orchid` then stream 5 MB matching `dffac395ec4b`.
### Fix 453 - XHTTP rewrite keeps suffix (Found 473)

- **Fix 453 (Found 473):** 12 XHTTP rewrite lines per template changed `rewrite /(.*) /<canon>` to `rewrite ^.*\/<name>(/.*)?$ /<canon>$1`; WS/HU form untouched (proven working, no session suffix there).
- **Verified live:** same 12-line patch on `/etc/nginx/nginx.conf`, `nginx -t` ok, reload clean; color `/purple` streams 5 MB matching `dffac395ec4b`.
### Fix 454 - Website sudoers prerequisites (Found 474)

- **Fix 454 (Found 474):** `website/install.sh` now `mkdir -p /etc/sudoers.d` and installs `sudo` (for `visudo`) before writing the drop-in. Live VPS got the drop-in directly (`visudo -c` ok).
- **Verified live:** right-token POST of the same-box backup returns `SUCCESSFULLY RESTORED YOUR VPS`; all 4 JSONs `Configuration OK`, 0 failed units, accounts intact, `600` key / `640` restore key preserved.
### Fix 455 - SSH unlock sweeper (Found 475)

- **Fix 455 (Found 475):** `full/limit-ip-ssh.sh` writes a due-epoch file (`/etc/xray/autounlock/ssh/$user`, lock + 900 s) instead of the `at` job, plus an end-of-run sweeper that `passwd -u`s due users still flag-locked and drops stale state. Lite ships no SSH limiter (single-edition change).
- **Verified live:** planted flag-lock + 20 s fuse → daemon run restored `P` status and consumed state; deployed to `/usr/bin` (hash-verified); zips repacked (0755).
### Fix 456 - WARP persist + keepalive + IPv4 (Found 476)

- **Fix 456 (Found 476):** `warp()` writes the peer block (`### WARP`, keepalive 25) into `wg0.conf` with idempotent replace, resolving the endpoint to IPv4 at setup (hostname fallback kept), then restarts. Full edition only (WG menu is full-only).
- **Verified live:** single `### WARP` block after 3 runs, peer present post-restart, keepalive traffic egressing; Cloudflare-side handshake completion unproven (no reply observed — external). Test peer removed after; zips repacked (0755).
