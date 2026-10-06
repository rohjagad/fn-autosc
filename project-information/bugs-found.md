# Bugs Found

> **⚠ APPEND-ONLY:** Do not delete or overwrite existing entries. Always add new content at the very bottom of this file.

This file records defects and operational issues found during source review and
live testing on a fresh Debian 12 VPS.

## KVM End-to-End Client Test Findings (verified with real traffic)

These were verified by connecting a real Debian 12 KVM guest to the live VPS as
a protocol client and measuring actual traffic. Unlike the container tests, the
KVM could create `tun`/`wg` interfaces, so OpenVPN and WireGuard data planes
were exercised for real.

### `udp-request` broad SNAT hijacks VPN client subnets (CRITICAL, CONFIRMED)

- Root cause is the same rule documented under "SNAT self-lockout", but the
  earlier fix only protected the VPS management address.
- The rule sits at the **top** of `nat POSTROUTING`:

  ```text
  1  RETURN     10.245.234.252
  2  SNAT       10.0.0.0/8  !10.0.0.0/8  to:103.59.94.47   <-- runs before VPN MASQUERADE
  ...
  7  MASQUERADE 10.6.0.0/24                                <-- OpenVPN clients
  8  MASQUERADE 10.7.0.0/24
  ```

- `udp-request -mode=system` re-inserts this rule at position 1 every time the
  service restarts, and the `udp-request-fixnet.timer` only re-asserts the host
  `RETURN` rule.
- `103.59.94.47` is **not present on any local interface** (provider-side public
  IP; `ens3` is `10.245.234.252`), so SNAT to it breaks the return path.
- Result: OpenVPN (`10.6.0.0/24`) and WireGuard (`10.99.0.0/24`, `10.66.66.0/24`)
  clients connect and authenticate, and the server forwards their packets out
  `ens3`, but replies never return.
- A/B verified on the live VPS:

  ```text
  Broad SNAT present : ping 8.8.8.8 over OpenVPN -> 100% packet loss
  Broad SNAT removed : ping 8.8.8.8 over OpenVPN -> 0% loss, ~32 ms
  ```

- Fix direction: exclude the VPN client subnets from the broad SNAT, or place
  the per-subnet MASQUERADE rules ahead of it in a rule the udp-request
  restart cannot reorder above.

### `menu-noobz` uses removed `noobzvpns` CLI flags (CONFIRMED)

- Installed binary is `noobzvpns 3.3.1-b`, which uses subcommands:
  `add`, `renew`, `remove`, `print`, `print-all`, etc.
- `full/menu-noobz.sh` still calls the old flag form:

  ```text
  noobzvpns --add-user "$user" "$pass"
  noobzvpns --expired-user "$user" "$masaaktif"
  noobzvpns --remove-user "$name"
  noobzvpns --info-all-user
  ```

- Live output:

  ```text
  error: unexpected argument '--add-user' found
  ```

- So Add / Delete / List in the NoobzVPN menu are all non-functional against the
  binary the installer fetches today.
- Also the delete function referenced `$user` (from `create`) instead of the
  `$name` it just read, so the expiry line was never matched.

### `cls` is not a valid command (CONFIRMED, introduced during TUI restyle)

- Nine scripts call a bare `cls` where the original used `clear`:

  ```text
  full/bmenu.sh        full/dm-menu.sh   full/menu-argo.sh
  full/menu-bot.sh     full/menu-dnstt.sh full/menu-noobz.sh
  full/menu-system.sh  full/menu-wg.sh   full/xl2tp.sh
  ```

- `cls: command not found` on Debian; screen never clears on that line.

### OpenVPN config URL advertised by the menu does not exist (CONFIRMED)

- `addssh`/`trial-ssh` print:

  ```text
  Config OVPN : http://<domain>/web/tcp.ovpn
  ```

- Live checks:

  ```text
  /web/tcp.ovpn             -> 404
  /web/client-tcp-1194.ovpn -> 200
  ```

- The installer copies the client profile to
  `/var/www/html/client-tcp-1194.ovpn` only; nothing publishes `tcp.ovpn`.
  (Also present in the original vendor zip, not a regression.)
- Note: nginx `location /web/` maps straight onto the site root
  (`/web/tcp.ovpn` -> `/var/www/html/tcp.ovpn`), so the alias must be written
  to `/var/www/html/tcp.ovpn`, not `/var/www/html/web/tcp.ovpn`.

### SplitHTTP transport fails through nginx (CONFIRMED)

- `location /splitvm` proxies to `127.0.0.1:2019` but sets no
  `proxy_read_timeout`; global `client_body_timeout` is 12s.
- Live xray client through a real KVM guest:

  ```text
  curl --socks5 ... http://ipv4.icanhazip.com
  curl: (52) Empty reply from server
  ```

- nginx access log shows the corresponding upload as `408`, and the xray split
  access log stays empty while WS / HTTPUpgrade / gRPC all log accepted
  connections and full traffic.
- vmess-WS, vmess-HTTPUpgrade and vmess-gRPC all transferred real payloads
  (~220-280 KB/s) through the same guest.

- After adding the proxy timeouts, SplitHTTP still did not carry traffic from a
  real xray client. Debug output showed an HTTP-version mismatch rather than a
  timeout:

  ```text
  failed to GET https://<domain>/splitvm/<id> ...
  malformed HTTP response "\x00\x00\x12\x04\x00\x00\x00..."
  ```

  The client's SplitHTTP "packet-up" transport expects an HTTP/1.x reply, but
  the server path is served over HTTP/2 (`listen ... ssl http2`). The nginx
  timeout fix is necessary but not sufficient; the transport/h2 configuration
  still needs correction for SplitHTTP to work end-to-end.

## Critical Runtime Bugs

### `udp-request` SNAT self-lockout


- `udp-request-linux-amd64 -mode=system` added this rule:

  ```text
  iptables -t nat -A POSTROUTING -s 10.0.0.0/8 ! -d 10.0.0.0/8 -j SNAT --to-source <public-ip>
  ```

- The VPS management address was `10.245.234.252`, inside `10.0.0.0/8`.
- Host traffic was therefore caught by the tunnel SNAT rule.
- Symptoms: installer downloads stalled, VPS internet access failed, DNS failed,
  and external HTTP/HTTPS access became unreliable.

### `noobzvpns` IPv6 bind failure

- The VPS had no usable IPv6 address.
- `noobzvpns` attempted to bind `[::]:443` and exited with:

  ```text
  tcp_ssl: ([::]:443): Address family not supported by protocol
  ```

### Separate authorization gate in encrypted `fix.sh`

- The original encrypted fix binary contacted:

  ```text
  https://raw.githubusercontent.com/rohmatsb-biz/cobaizin/main/izin.txt
  ```

- It rejected authorized VPSs that were present in
  `rohjagad/fn-autosc-auth/izin.txt`.
- On rejection it printed a shutdown message and called `reboot`.

### Undefined sysctl variables in original `fix.sh`

- The decrypted script referenced `NEW_FILE_MAX`, `NF_CONNTRACK_MAX`, and
  `NF_CONNTRACK_TIMEOUT` without assigning values.
- This could produce an empty `fs.file-max` assignment and empty conntrack
  entries, making the fix ineffective or invalid.

## Source and Configuration Bugs

### Stale GitHub address in `/etc/hosts`

- `installer/v2ray.sh` wrote:

  ```text
  199.232.68.133 raw.githubusercontent.com
  ```

- This is a stale Fastly address and can break GitHub downloads when DNS or
  routing differs.
- It was still reachable during testing, so it was not changed at that time.

### Missing SlowDNS configuration

- `dnstt.service` failed on the fresh install because the nameserver/domain
  configuration was not set.
- This is expected until the operator configures a SlowDNS nameserver, but the
  installer reports the service as failed on an otherwise fresh installation.

### Fail2ban missing SSH log input

- `fail2ban.service` failed with:

  ```text
  Have not found any log file for sshd jail
  ```

- The configured jail expected an SSH log file that was not present on the
  fresh Debian installation.

### Libreswan/IPsec crash

- `ipsec.service` failed with an abort signal during live testing.
- The service reached `status=ABRT` and entered systemd restart throttling.
- Root cause was not established during the test.

### Lite installer duplicates website installation

- `installer/lite.sh` downloads and runs `website/install.sh` twice.
- This is redundant and may repeat package/configuration work.

### Menu public-IP labels are reversed

- The main menu assigns the IPv4 endpoint to `ip6` and the IPv6 endpoint to
  `ip4`:

  ```text
  ip6=$(curl -sS ipv4.icanhazip.com)
  ip4=$(curl -sS ipv6.icanhazip.com)
  ```

- On an IPv4-only VPS this produced a blank or misleading `IP SERVER` display.

### Menu execution requires a real terminal

- Several menus call `clear`, query terminal state, and read interactively.
- Non-TTY execution produced `TERM environment variable not set` and incomplete
  output. This is an interactive usability limitation, not a service failure.

### Original menu smoke test was incomplete

- Before the later TUI work, account menus and submenus had not been exercised
  end-to-end through an interactive terminal.
- Only the main installation and service state had been verified.

## Dependency and Hosting Findings

### Original NoobzVPN download URL returned 404

- The original upstream path referenced a renamed or unavailable binary.
- The requested `noobzvpns.x86_64` path returned HTTP 404 during validation.

### Protected `fix.sh` was opaque

- The original `fix/fix.sh` was a stripped x86-64 ELF rather than readable
  shell source.
- Its behavior and source provenance could not be audited directly until the
  decrypted shell payload was captured.

### Installer dependency and hosting findings beyond the above

### Public installer depends on many mutable downloads

- The installer downloads scripts and binaries at runtime from raw GitHub,
  upstream release URLs, and package repositories.
- Most downloads do not use checksums, so availability and content depend on
  those external services at install time.

## Comprehensive Audit & Live-Verified Bugs (September 2026 Audit)

### 1. Fatal Bash Syntax Error in `menu-system.sh` (CONFIRMED)
- **Files:** `full/menu-system.sh:608-629`, `lite/menu-system.sh:608-629`, and inside `menu/full.zip`, `menu/lite.zip`.
- **Cause:** Stray double quote `"` on line 609 inside `rocky()`. Inverts quote parsing so `echo -e "` on line 621 closes the quote, and line 629 `read -p "Continue (y/n): " osw` crashes with:
  ```text
  syntax error near unexpected token `y/n'
  ```
- **Impact:** System menu cannot be executed by bash. Verified on live Debian 12 VPS.

### 2. Missing Functions in Menus (CONFIRMED)
- **`full/menu-dnstt.sh:182`:** Option 4 calls `typer`, which does not exist anywhere in the codebase (`typer: command not found`).
- **`full/menu-argo.sh:229` & `lite/menu-argo.sh:229`:** Option 2 calls `reres`, which does not exist anywhere in the codebase (`reres: command not found`).
- **`full/menu-system.sh:185`:** Calls `chmod /usr/bin/warp.sh` without a mode operand (`chmod: missing operand after '/usr/bin/warp.sh'`).

### 3. Obsolete Packages Break Debian 12 Installer (CONFIRMED)
- **Files:** `installer/package.sh:13,78`, `installer/slowdns.sh:59`.
- **Cause:**
  - `apt install -y ... python ...`: Debian 12 has no package named `python` (`E: Package 'python' has no installation candidate`).
  - `apt install -y ... squid3 ...`: Debian 12 has no package named `squid3` (`E: Unable to locate package squid3`).
- **Impact:** APT aborts the entire command with exit code 100 on Debian 12. Bundled packages (`jq`, `certbot`, `openvpn`, `dropbear`, `stunnel4`, `fail2ban`, `chrony`) fail to install. Verified on live VPS.

### 4. IPv6 Breaks Authorization on Dual-Stack VPS (CONFIRMED)
- **Files:** All scripts in `fn-autosc` (~199 occurrences).
- **Cause:** `LOCAL_IP=$(curl -s ifconfig.me)` runs without `-4`. On dual-stack servers (like the test VPS), `ifconfig.me` returns an IPv6 address (`2001:df0:27b::1:50ef`). Since `fn-autosc-auth/izin.txt` only records IPv4 addresses, `MATCH` is always empty.
- **Impact:** "Your IP doesn't have on database" and immediate exit 1 on any server with IPv6 enabled. Verified on live VPS.

### 5. Stale Fastly IP Causes SSL Error on GitHub Downloads (CONFIRMED)
- **File:** `installer/v2ray.sh:65-69`.
- **Cause:** Hardcodes `199.232.68.133 raw.githubusercontent.com` into `/etc/hosts`. The IP currently serves a certificate for `*.github.io`.
- **Impact:** Any standard curl/wget to `raw.githubusercontent.com` fails with:
  ```text
  curl: (60) SSL: no alternative certificate subject name matches target host name '199.232.68.133'
  ```
  Verified on live VPS.

### 6. SlowDNS Port 53 Redirection Collision (CONFIRMED)
- **File:** `installer/slowdns.sh:126,129`.
- **Cause:** Line 126 inserts `PREROUTING ... --dport 53 -j REDIRECT --to-ports 5300`. Line 129 then inserts `PREROUTING ... --dport 53 -j REDIRECT --to-ports 530`. Because `iptables -I` without an index prepends at position 1, the port 530 rule takes precedence.
- **Impact:** All inbound DNS queries on port 53 are redirected to port 530 where nothing listens (DNS server listens on 5300), breaking SlowDNS.

### 7. HAProxy Never Enabled or Started by Installer (CONFIRMED)
- **File:** `installer/stunnel5.sh`.
- **Cause:** Installs haproxy and writes `/etc/haproxy/haproxy.cfg`, but never executes `systemctl enable haproxy` or `systemctl start haproxy`.
- **Impact:** SSH over SSL on port 777 fails on fresh installs until `dm-menu.sh` is manually invoked.

### 8. Web Restore Apache Site Never Enabled (CONFIRMED)
- **File:** `website/install.sh:10,28`.
- **Cause:** Writes `/etc/apache2/sites-available/upload.conf` and changes port to 855, but never runs `a2ensite upload.conf`.
- **Impact:** Apache falls back to default `000-default.conf` serving `/var/www/html/` on port 855 instead of the Web Restore application.

### 9. Wildcard Script Deletion in `/root/` (CONFIRMED)
- **File:** `installer/noobz.sh:141`.
- **Cause:** Executes `rm -f /root/*.sh` at script completion.
- **Impact:** Wipes out all shell scripts in `/root/`, including operator custom tools and other pending installers.

### 10. NoobzVPN User Deletion Wipes Entire Database (CONFIRMED)
- **File:** `full/menu-noobz.sh:173`.
- **Cause:** Runs `sed -i "/^### $name $exp/,/^},{/d" /etc/noobzvpns/.noob`. The file `.noob` is plain text (`### user exp`) and does not contain `},{`.
- **Impact:** Sed deletes from the target user through the remainder of the file, destroying all subsequent user records.

### 11. Account Lock Scripts Duplicate Instead of Removing Users (CONFIRMED)
- **Files:** `full/locked-xray-*.sh` and `lite/locked-xray-*.sh` (8 files).
- **Cause:** Copied from unlock scripts; calls `sed -i '/#vmess$/a\...` to add the user to `config.json`, then attempts deletion using `$user` while the input was `$name` (`$user` is empty).
- **Impact:** Never disables the account in Xray/V2ray; instead creates duplicate user entries in the JSON config.

### 12. Account Expiration Cleaner (`xp.sh`) Multi-Failure (CONFIRMED)
- **File:** `full/xp.sh`.
- **Bugs:**
  1. WireGuard: `if [[ $exp < $today ]]` compares against undefined `$today` (empty string). Evaluates false; expired WG users are never deleted.
  2. Missing file crash: `done < /etc/funny/.wireguard` crashes with `No such file or directory` if no WireGuard users have been added.
  3. L2TP: `[[ "$exp2" = "0" ]]` uses string equality instead of `-le 0`. Accounts missed for >0 days are skipped forever.
  4. L2TP service typo: `systemctl restart xl2tp` fails (`xl2tpd` is the unit name).
  5. SSH username padding: pads `$username` with spaces up to 15 characters before `userdel --force $username`.
  6. Leftover variables: SSH and L2TP Telegram notifications reference `$exp` and `$user` from the prior loop.
  7. NoobzVPN credentials: reads non-existent `/etc/noobzvpns/.chatid` and `.keybot`.

### 13. Extend Scripts Fail to Update Expiry in User Logs (CONFIRMED)
- **Files:** `full/extend-*.sh` and `lite/extend-*.sh` (8 files).
- **Cause:** Uses `sed -i "s/Expired: $exp/Expired: $exp4/"` (no space before colon), whereas all `add-*.sh` scripts create logs with `Expired : $exp` (space before colon).
- **Impact:** Regex never matches; user log file retains old expiration date indefinitely.

### 14. Non-Existent `xray@http` and `xray@ws` Systemd Services (CONFIRMED)
- **`xray@http` (8 files):** `full/auto-delete-http.sh:108`, `lite/auto-delete-http.sh:108`, `full/extend-http.sh:127`, `lite/extend-http.sh:127`, `full/change-quota-http.sh:197`, `lite/change-quota-http.sh:197`, `full/locked-xray-http.sh:183`, `lite/locked-xray-http.sh:183`. Actual unit is `xray@upgrade`.
- **`xray@ws` (9 files):** `full/restore-ftp.sh:87`, `lite/restore-ftp.sh:87`, `website/restore-ftp.sh:36`, `full/bmenu.sh:119,172,314`, `lite/bmenu.sh:119,172,314`. WebSocket is managed by `v2ray.service`.
- **Impact:** Systemd restart fails (`Unit not found`); configuration changes are never reloaded.

### 15. Incomplete Backup Restore (CONFIRMED)
- **Files:** `full/restore-ftp.sh`, `lite/restore-ftp.sh`.
- **Cause:** Backups archive `/etc/v2ray` and `/etc/crontab`, but restore scripts omit `cp -r v2ray /etc/` and `cp crontab /etc/`.
- **Impact:** Restoring a backup completely loses all V2Ray/WebSocket accounts and crontab schedules.

### 16. Protocol Mismatch in Nginx `default_backend` Upstream (CONFIRMED)
- **Files:** `config/4.conf:64-67`, `config/6.conf`, `config/dual.conf`.
- **Cause:**
  ```nginx
  upstream default_backend {
      server 127.0.0.1:2080 weight=1; # SSH WebSocket
      server 127.0.0.1:977 weight=1;  # Xray Vmess
  }
  ```
- **Impact:** Round-robins across two incompatible protocols on `/`. 50% of SSH-WS and Vmess connections fail.
- **Port 80 redirect:** Top server block redirects port 80 to HTTPS 301, breaking advertised plain HTTP proxying on port 80.

### 17. Deprecated Cloudflare Warp Endpoint Returns 404 (CONFIRMED)
- **File:** `full/menu-wg.sh:225`.
- **Cause:** Calls `https://api.cloudflareclient.com/v0a737/reg`. Endpoint returns HTTP 404.
- **Impact:** Warp configuration generation fails. Verified live on VPS.

### 18. Dependency on `strings` Binary (CONFIRMED)
- **Files:** `full/change-id-*.sh`, `full/list-xray-*.sh` (17 occurrences).
- **Cause:** Pipes awk output into `| strings`. `strings` is part of `binutils` and not installed by default on minimal Linux.
- **Impact:** Command fails with `strings: command not found`, returning empty UUIDs.

### 19. System Log Truncation & Lockout in `limit-ip-ssh.sh` (CONFIRMED)
- **File:** `full/limit-ip-ssh.sh:214-216`.
- **Cause:** Runs `echo "" > /var/log/auth.log` every 5 minutes in cron.
- **Impact:** Destroys system authentication audit trail; breaks Fail2ban SSH jail monitoring.
- **Session tracking:** Greps historical login events from `auth.log` instead of active sessions, locking out legitimate users who logged in multiple times in the past.

### 20. UID Check in Go Helpers Includes `nobody` (CONFIRMED)
- **Files:** `full/delete-ssh.go:36`, `full/list-ssh.go:36`.
- **Cause:** `id >= 1000` matches system user `nobody` (UID 65534).
- **Impact:** `nobody` is displayed in SSH user lists and can be deleted via `delete-ssh`.

### 21. Empty `rclone.conf` in Miscellaneous Repository (CONFIRMED)
- **File:** `fn-autosc-miscellaneous/rclone.conf`.
- **Cause:** Contains only `[dr] / type = drive / scope = drive` with no OAuth client credentials or tokens.
- **Impact:** Google Drive backups via `backup-gd.sh` fail immediately with authorization errors.

### 22. Unattended Installation Blocked by Interactive Debconf Prompts (CONFIRMED)
- **Files:** `installer/set-br.sh:12`, `installer/l2tp.sh:111`, `installer/vpn.sh:78`, `installer/full.sh`, `installer/lite.sh`.
- **Cause:**
  - `msmtp-mta` package triggers an interactive debconf prompt: `Enable AppArmor support? [yes/no]`.
  - `iptables-persistent` package triggers interactive prompts: `Save current IPv4 rules?` and `Save current IPv6 rules?`.
  - Main installers lacked explicit non-interactive front-end environment exports.
- **Impact:** Live installer hangs indefinitely waiting for terminal input, failing automated or non-interactive deployment.

### 23. Path Inconsistency for Public IP Address File (CONFIRMED)
- **File:** `installer/l2tp.sh:83`.
- **Cause:** Attempts to read `PUBLIC_IP=$(cat /etc/funny/.ip);`.
- **Impact:** `/etc/funny/.ip` is never generated by any installer (canonical file is `/etc/.ip` created in `installer/full.sh:91`). Causes L2TP IPsec configuration to use an empty server IP.

### 24. Path Inconsistency for NoobzVPN Account Database (CONFIRMED)
- **Files:** `full/menu-noobz.sh` (lines 132, 159, 172, 173), `full/xp.sh` (lines 311, 319, 331), `lite/xp.sh` (lines 310, 318, 330).
- **Cause:**
  - Installers (`installer/package.sh:52`, `installer/noobz.sh:62`) initialize database at `/etc/funny/.noob`.
  - Menu and cleanup scripts read and write to `/etc/noobzvpns/.noob`.
- **Impact:** Accounts added via `menu-noobz.sh` are recorded in `/etc/noobzvpns/.noob`, bypassing the installer's file. Furthermore, auto-expiration (`xp.sh`) scans `/etc/noobzvpns/.noob`, which may desync or fail if directories differ, causing unmanaged accounts.

---

### 25. Account Creation Breaks V2Ray/Xray Config JSON (CONFIRMED)
- **Files:** All 24 `add-{vless,vmess,trojan}-{ws,http,grpc,split}.sh` scripts in `full/` and `lite/`.
- **Cause:** The `sed -i '/#marker$/a\### user exp\n},{"id":"uuid","email":"user"}'` pattern appends a `},{ }` block after the `#vless`/`#vmess`/`#trojan` marker comment. The leading `}` in `},{` closes the first client object, but the original template already has a closing `}` on the next line, producing an extra unmatched brace.
- **Impact:** First account creation in any protocol/transport produces invalid JSON. V2Ray/Xray service crashes on restart and refuses to start until the malformed JSON is manually repaired. Every subsequent account creation also fails.
- **Reproduction:** Run `add-vless-ws`, then `v2ray test -c /etc/v2ray/config.json` → `invalid character '}' after array element`.

### 26. SlowDNS Nameserver Prompt Delayed ~15 Minutes Into Installation (CONFIRMED)
- **Files:** `installer/full.sh`, `installer/slowdns.sh`.
- **Cause:** The installer collects Domain, Email, and IP Type at the start of `full.sh`, then runs ~15 minutes of package/service installation before `slowdns.sh` prompts for the SlowDNS Nameserver.
- **Impact:** User must remain at the terminal watching a long install, waiting for a single prompt that appears after all packages are installed. Creates a fill → wait → fill experience.

### 27. Menu ZIP Files Packaged Without Execute Permissions (CONFIRMED)
- **Files:** `menu/full.zip`, `menu/lite.zip`.
- **Cause:** The `zip` command was run on source files that had `644` permissions. The zip stores file permissions, so `unzip -o` extracts all menu scripts as `644` (not executable).
- **Impact:** Running `menu` or any menu command returns `permission denied`. The `chmod +x *` in `full.sh` line 123 is supposed to fix this but it runs in `/usr/bin` affecting all system files — a blunt workaround that may not always execute depending on the shell's working directory at that point.

## Live Audit and Verification Cycle (September 2026)

- **Target VPS:** 202.155.17.126 (Debian 12 Bookworm, KVM).
- **Testing Cycle:**
  1. Cloned repository and performed static code analysis.
  2. Verified all 21 initial bugs plus newly uncovered deployment issues (Bugs 22-27).
  3. Replaced obsolete dependencies, fixed broken bash syntax, unified IPv4 resolution, and corrected service units.
  4. Compiled all Go binaries with `-ldflags="-s -w"` and rebuilt `menu/full.zip` and `menu/lite.zip`.
  5. Performed complete OS reinstallation via `bin456789/reinstall` to pristine Debian 12.
  6. Successfully executed full installation with dual-stack networking and SlowDNS.
  7. Confirmed 19 active systemd services and operational TUI menu interface.
  8. Created accounts (VLESS WS, VMESS WS, Trojan WS, VLESS gRPC) and verified JSON config validity.
  9. Confirmed end-to-end tunnel connectivity via Xray client (VLESS WS TLS → VPS → internet).

---

## Live Audit Cycle 2: Deep Component Verification (Bugs 28–40)

### 28. Account Deletion Leaves Trailing Commas in JSON Configs Crashing V2Ray/Xray (CONFIRMED)
- **Files:** `full/delete-{ws,split,grpc,http}.sh`, `lite/delete-{ws,split,grpc,http}.sh`, `full/xp.sh`, `lite/xp.sh`, `full/kill-{ws,split,grpc,http}.sh`, `lite/kill-{ws,split,grpc,http}.sh`.
- **Cause:** Account deletion scripts execute `sed -i "/### $user $exp/ {N;d}" <config.json>`, stripping the user block and its comment header. Because accounts are added with leading commas following the template entry, deleting the newest account leaves a dangling trailing comma preceding the array's closing bracket (`}, \n ]`).
- **Impact:** Go's standard JSON decoder (RFC 8259) rejects trailing commas. Service restarts crash with `invalid character ']' looking for beginning of value`. V2Ray and Xray daemons fail to boot, knocking all client tunnels offline. Verified live on Debian 12 VPS.

### 29. Trial Account Self-Deletion Command Broken by Unescaped Quotes (CONFIRMED)
- **Files:** All 24 `trial-*.sh` scripts in `full/` and `lite/`.
- **Cause:** Scripts schedule auto-deletion via:
  ```bash
  echo "sed -i "/### $user $exp/ {N;d}" /etc/v2ray/config.json && systemctl restart v2ray ..." | at now + 60 minutes
  ```
  Unescaped nested double quotes cause bash to prematurely terminate the string and attempt to execute `d}` as an independent shell command: `/usr/bin/trial-vless-ws: line 131: d}: No such file or directory`.
- **Impact:** The `at` daemon receives an empty/truncated command payload. Trial accounts are never automatically deleted after 60 minutes and persist indefinitely. Verified live on Debian 12 VPS.

### 30. Trial and Unlock Scripts Use Broken Append-After Pattern (CONFIRMED)
- **Files:** 24 `trial-*.sh` scripts and 8 `unlock-*.sh` scripts in `full/` and `lite/`.
- **Cause:** While regular `add-*.sh` scripts were updated to use next-line substitution (`/#marker$/{n;s/}/...`), trial and unlock scripts still execute `sed -i '/#marker$/a\### user exp\n},{"id":...` which appends directly after the comment marker.
- **Impact:** Injects entries between the `#marker` comment and the closing brace. Once a trial or unlock account exists, regular `add-*.sh` scripts fail to match their expected pattern, causing subsequent account creation to silently fail (`realuser WAS NOT ADDED!`). Verified live on Debian 12 VPS.

### 31. `kill-ws.sh` Automatically Deletes Accounts with Unlimited Quota (CONFIRMED)
- **Files:** `full/kill-ws.sh:98-106`, `lite/kill-ws.sh:98-106`.
- **Cause:** In `add-*-ws.sh`, accounts created with Quota = 0 (unlimited) intentionally omit creating `/etc/xray/quota/ws/$user`. However, `kill-ws.sh` (running every 5 minutes in crontab) contains a logic defect checking `if [[ ! -f "$quota_file" ]]; then` and unconditionally deletes the user from `/etc/v2ray/config.json`.
- **Impact:** Any WebSocket account configured with unlimited quota is deleted within 5 minutes of creation with log status `Deleted (Quota File Missing)`.

### 32. SlowDNS Installer Wipes Entire Configuration Directory (CONFIRMED)
- **Files:** `installer/slowdns.sh:71-72`.
- **Cause:** `full.sh` saves the administrator's chosen nameserver into `/etc/slowdns/nsdomain` upfront. When `slowdns.sh` executes later in the install chain, line 71 executes `rm -rf /etc/slowdns /root/dnstt`, destroying the saved configuration before it can be read.
- **Impact:** The check `if [[ -s /etc/slowdns/nsdomain ]]` evaluates to false, forcing the installer to stop at `read -rp "Your Nameserver: " -e Nameserver` and breaking unattended automated deployments. Verified live on Debian 12 VPS.

### 33. NoobzVPN Auto-Expiration Deletes Adjacent Unexpired Accounts (CONFIRMED)
- **Files:** `full/xp.sh:331-332`, `lite/xp.sh:330-331`.
- **Cause:** `/etc/funny/.noob` records are single lines (`### $user $exp`). `xp.sh` executes `sed -i "/### $user $exp/ {N;d}" /etc/funny/.noob`. The `N` command reads the next line (the subsequent user) into pattern space and deletes both. Furthermore, line 332 executes `noobzvpns --remove-user "$user"` which fails (`error: unexpected argument '--remove-user' found`).
- **Impact:** Legitimate unexpired accounts are purged from the database while the expired account is never removed from the active `noobzvpns` service. Verified live on Debian 12 VPS.

### 34. Broken `flock` Syntax in Crontab Executes `xp` Unprotected After Delay (CONFIRMED)
- **Files:** `installer/xray.sh:140`.
- **Cause:** Crontab schedules `0,15,30,45 * * * * root flock -n /tmp/xp.lock sleep 300 && /usr/bin/xp`. The shell operator `&&` has lower precedence than flock; flock acquires the lock exclusively for `sleep 300`, releases the lock upon timeout, and then runs `/usr/bin/xp`.
- **Impact:** `/usr/bin/xp` runs completely unlocked, allowing race conditions, while being artificially delayed by 5 minutes on every execution cycle. Verified live on Debian 12 VPS.

### 35. Undefined `$TEKS` Variable Fails Telegram Backup Notification (CONFIRMED)
- **Files:** `full/backup-gd.sh:107-108`, `lite/backup-gd.sh:107-108`.
- **Cause:** Message summary text is assembled in variable `$opwares` on line 112, but line 108 invokes `curl` using unassigned `$TEKS`.
- **Impact:** Telegram API responds with `400 Bad Request: message text is empty`; backup alerts are dropped.

### 36. Path Mismatch Breaks Web-Based Restore (CONFIRMED)
- **Files:** `website/upload.php:17,22`, `website/install.sh`, `full/restore-ftp.sh:61-64`.
- **Cause:** `upload.php` saves uploaded archives to `/var/www/uploads/` and triggers `sudo /usr/bin/restore-ftp`. However, `website/install.sh` never deploys `website/restore-ftp.sh` to `/usr/bin/restore-ftp`. The installed script searches `/root/*backup*.zip`.
- **Impact:** Uploading a backup via Apache port 855 fails 100% of the time with `File backup.zip Not Found`.

### 37. `delete-split.sh` Deletes Quota File from Wrong Transport Directory (CONFIRMED)
- **Files:** `full/delete-split.sh:125`, `lite/delete-split.sh:125`.
- **Cause:** Line 125 executes `rm -f /etc/xray/quota/ws/$user` instead of targeting `/etc/xray/quota/split/$user`.
- **Impact:** Orphaned files accumulate in `/etc/xray/quota/split/` while identically named accounts on WebSocket transport lose their quota configurations.

### 38. Missing `qrencode` Package Breaks WireGuard QR Display (CONFIRMED)
- **Files:** `full/menu-wg.sh:364`.
- **Cause:** Option 5 ("Show WireGuard Config") calls `qrencode -t ansiutf8 -l L < ...`, but package `qrencode` is never installed by any setup script.
- **Impact:** Terminal errors out with `qrencode: command not found`. Verified live on Debian 12 VPS.

### 39. WireGuard WARP Registration Shell Variable Expansion Quoted Out (CONFIRMED)
- **Files:** `full/menu-wg.sh:226,252`.
- **Cause:** Line 226 passes `sudo wg set wg0 peer '$CLOUDFLAREKEY' endpoint '$IPV4':51820 ...` inside single quotes, preventing variable evaluation. `$IPV4` is also never defined.
- **Impact:** Literal unexpanded strings are passed to `wg`, causing WARP peering to fail.

### 40. `iptables-restore -t` Runs in Test Mode Without Applying Rules (CONFIRMED)
- **Files:** `installer/l2tp.sh:313`, `installer/vpn.sh:178`.
- **Cause:** Scripts execute `iptables-restore -t < /etc/iptables.up.rules`. The `-t` (`--test`) option tests rule parsing without loading or committing rules to the kernel netfilter tables.
- **Impact:** Firewall configuration from `/etc/iptables.up.rules` is never actually applied on system boot.

---

## Live Audit Cycle 3: Post-Fresh-Install System Audit (Bugs 52–61)

All bugs verified on fresh Debian 12 VPS (`202.155.17.126`) reinstalled via `bin456789/reinstall` followed by fresh `full.sh` execution.

### 52. `xp.sh` SSH Expiration Leaves Ghost Logs and Uses Undefined Variables (CONFIRMED)
- **Files:** `full/xp.sh:225-248`, `lite/xp.sh:215-238`.
- **Cause:** In the SSH auto-expiration loop:
  1. `/var/log/create/ssh/${username}.log` is never deleted upon account expiry.
  2. The Telegram notification references `$exp`, which is undefined in the SSH loop (evaluates to empty or retains the value from the preceding gRPC loop).
  3. The cleanup line executes `rm -rf /etc/funny/limit/ssh/ip/$user` where `$user` is undefined (loop variable is `$username`) and the path is incorrect (`/etc/xray/limit/ip/ssh/$username`).
- **Impact:** Expired SSH accounts remain permanently listed in database tools (`log-acc-ssh` and `pwd-ssh`). Expiration notifications display empty dates. Verified live on Debian 12 VPS: created `testexp52`, ran `xp`; user was deleted from `/etc/passwd` but `/var/log/create/ssh/testexp52.log` remained and was listed in `log-acc-ssh`.

### 53. `trial-ssh.sh` Scheduled Expiration Leaves Orphaned Database Logs (CONFIRMED)
- **Files:** `full/trial-ssh.sh:53-62`.
- **Cause:** `schedule_user_expiration()` schedules `pkill -u $username; userdel -f $username` via `at`, omitting deletion of `/var/log/create/ssh/${username}.log` and `/etc/xray/limit/ip/ssh/${username}`.
- **Impact:** When trial accounts expire, their logs remain in `/var/log/create/ssh/`, polluting account lists in `log-acc-ssh` indefinitely. Verified live on Debian 12 VPS: trial account self-deletion command in `at -c <job>` lacked log and limit cleanup.

### 54. Domain Update in `dm-menu.sh` Uses Single Quotes, Corrupts cert2 Keys, and Misses gRPC (CONFIRMED)
- **Files:** `full/dm-menu.sh:193-195,267-271`, `lite/dm-menu.sh:193-195,267-271`.
- **Cause:**
  1. Lines 267–271 use single quotes: `sed -i 's/${old_domain}/${host}/g' /var/log/create/xray/*`. Single quotes prevent variable expansion in bash, so literal `${old_domain}` is searched instead of the actual domain name.
  2. Line 270 duplicates `split` and omits `grpc` (`/var/log/create/xray/grpc/*`).
  3. `cert2()` appends (`>>`) new certificates and keys to `/etc/xray/xray.crt` and `/etc/xray/xray.key`, duplicating keys and breaking cryptographic parsers on renewal. It also never updates `/etc/haproxy/funny.pem`.
- **Impact:** Changing domain leaves all saved account connection links pointing to the old domain. Reissuing certificates with Certbot corrupts key files.

### 55. "Restart All Services" in `menu-system.sh` Misses 12 Core Services (CONFIRMED)
- **Files:** `full/menu-system.sh:76-96`, `lite/menu-system.sh:76-96`.
- **Cause:** `resall()` only restarts 11 services and omits `dropbear`, `haproxy`, `openvpn`, `wg-quick@wg0`, `noobzvpns`, `dnstt`, `udp-custom`, `udp-request`, `xl2tpd`, `ipsec`, `fn-ohp`, `opn`.
- **Impact:** Selecting option 2 leaves half the VPN, proxy, and load-balancer daemons un-restarted after system updates or configuration adjustments.

### 56. OS Reinstall Menu Prompt Variable Mismatch (CONFIRMED)
- **Files:** `full/menu-system.sh:555`.
- **Cause:** In `information()`, `read -p "Continue (y/n): " osw` stores the user's response in `osw`, but line 555 checks `elif [[ $ip_version == "n" ]]; then`.
- **Impact:** When the user enters `n` to cancel the OS reinstallation, the condition evaluates to false, causing execution to proceed to the OS selection menu instead of exiting.

### 57. `udp.sh` Installer Deletes Itself Mid-Execution (CONFIRMED)
- **Files:** `installer/udp.sh:69`.
- **Cause:** Script executes `rm -fr /root/udp*`. Because the script is running from `/root/udp.sh`, the glob matches and deletes the executing script file itself before it completes.
- **Impact:** Bash can seek to incorrect file offsets or abort execution mid-stream when its own script file is unlinked during execution.

### 58. Backup and Restore Omit Non-Xray VPN Services (CONFIRMED)
- **Files:** `full/backup.sh`, `lite/backup.sh`, `full/bmenu.sh`, `lite/bmenu.sh`, `full/backup-gd.sh`, `full/restore-ftp.sh`, `lite/restore-ftp.sh`, `website/restore-ftp.sh`.
- **Cause:** Backup routines strictly archive `/etc/xray`, `/etc/v2ray`, `/var/log/create`, `/etc/funny`, and user databases, completely omitting `/etc/wireguard`, `/etc/slowdns`, `/etc/noobzvpns`, `/etc/ppp`, and `/etc/ipsec.d`.
- **Impact:** Restoring a backup on a new server wipes out all WireGuard peers, NoobzVPN users, SlowDNS keys, and L2TP/IPSec credentials.

### 59. `auto-delete-*.sh` Daemons Omit Deleting Quota Usage Files (CONFIRMED)
- **Files:** `full/auto-delete-{ws,grpc,http,split}.sh`, `lite/auto-delete-{ws,grpc,http,split}.sh`.
- **Cause:** Daemons run `rm -f /etc/xray/quota/<proto>/$user` without wildcard matching.
- **Impact:** Leaves `/etc/xray/quota/<proto>/${user}_usage` orphaned on disk indefinitely after deleting unregistered accounts.

### 60. SlowDNS Menu Missing Public Key and Connection Details (CONFIRMED)
- **Files:** `full/menu-dnstt.sh:105-120`.
- **Cause:** SlowDNS menu only offers options to change nameserver, renew server keys, or restart service. There is no option to display the server public key or client connection parameters.
- **Impact:** Users setting up SlowDNS clients (HTTP Custom, NetMod, OpenTunnel) cannot retrieve their server public key from the menu and must manually read `/etc/slowdns/server.pub` via root shell.

### 61. OpenVPN Generic `dev tun` Collides with `udp-request` TUN Requirement (CONFIRMED)
- **Files:** `installer/vpn.sh:80-95`.
- **Cause:** `udp-request-linux-amd64` hardcodes `tun0` when initializing its system TUN interface (`[ERRO] error init TUN exit status 2`). `installer/vpn.sh` extracts server configs with generic `dev tun`, which causes `openvpn-server@server-tcp-1194` to allocate `tun0` first, preventing `udp-request` from starting and causing continuous crash-restarts.
- **Impact:** `udp-request` service enters permanent failure (`activating (auto-restart)`). Verified live on Debian 12 VPS: `tun0` was held by OpenVPN; reassigning OpenVPN to `dev tun2` / `dev tun3` allowed both OpenVPN and `udp-request` to run simultaneously and stably.



## Live Audit Cycle 4: Focus-Area Regression and Client-Path Audit (Bugs 62–71)

### 62. Change-Limit-IP Tools Never Update the On-Disk Limit File (CONFIRMED)
- **Files:** `full/change-limit-ip-{ws,grpc,http,split}.go`, `lite/change-limit-ip-{ws,grpc,http,split}.go`, `full/limit-ip.go`.
- **Cause:** The Go tools rewrote only the `Limit IP:` line inside the account log (`/var/log/create/xray/<proto>/<user>.log`) and never touched `/etc/xray/limit/ip/xray/<proto>/<user>`, which is the file every enforcement cron actually reads. Non-numeric input was also accepted verbatim.
- **Impact:** Changing an account's IP limit silently did nothing. Verified live on Debian 12 VPS: after changing limit 2 → 5, the log showed `Limit IP: 5` while `/etc/xray/limit/ip/xray/ws/testvm2` still contained `2`, so the enforcer kept locking at the old limit.

### 63. Deleting a VMess Account Leaves Trailing Commas and Crash-Loops V2Ray (CONFIRMED)
- **Files:** Shared comma fix-up `sed -i -z 's/},\n *\]/}\n        ]/'` (missing `g` flag) in ~34 scripts across `full/` and `lite/` (delete, lock/unlock, change-quota, kill, trial at-jobs, xp).
- **Cause:** A VMess account exists in four inbounds, each ending with `},\n        ]`. The single-substitution sed replaced only the first match per invocation, leaving the other three inbounds with trailing commas.
- **Impact:** After deleting a vmess user, `/etc/v2ray/config.json` became invalid JSON; V2Ray crash-looped (`status=1`, `restart=4`). Verified live on Debian 12 VPS: 4 `#vmess` markers → delete left 3 trailing commas → `JSON_BROKEN` → v2ray crash-loop.

### 64. SSH IP-Limit Enrollment Uses GID Instead of UID (CONFIRMED)
- **Files:** `full/limit-ip-ssh.sh`.
- **Cause:** The `/etc/passwd` parse discarded field 3 (UID) and compared field 4 (GID) against 1000, while also lacking an upper bound. System accounts with GID 65534 (`sync`, `_apt`, `sshd`, `strongswan`) were enrolled as if they were SSH customers.
- **Impact:** Junk limit files under `/etc/xray/limit/ip/ssh/` for system users; the lock loop iterated non-existent users on every cron run. Verified live on Debian 12 VPS: limit files present for `sync`, `_apt`, `sshd`, `strongswan`.

### 65. Lite OS-Reinstall Menu Prompt Tests the Wrong Variable (CONFIRMED)
- **Files:** `lite/menu-system.sh`.
- **Cause:** The prompt reads into `$osw`, but the negative branch tests `elif [[ $ip_version == "n" ]]`, an unrelated/empty variable.
- **Impact:** Entering `n` at the OS-reinstall prompt never exits and falls through into the reinstall path.

### 66. `xp.sh` Wildcard Deletion Cross-Destroys Longer Usernames (CONFIRMED)
- **Files:** `full/xp.sh`, `lite/xp.sh` (4 deletion sites each).
- **Cause:** Expiry cleanup ran `rm -f /etc/xray/quota/ws/$user*` (and sibling paths) — a prefix glob shared with the original V23 sources.
- **Impact:** Expiring user `xpw1` also deletes `xpw10`'s quota/log/limit files while `xpw10` is still active. Verified live on Debian 12 VPS after fix: expiring `xpw1` left `xpw10`'s quota file, log, and config marker intact.

### 67. Menu Delete Scripts Leave `${user}_usage` Orphaned (CONFIRMED)
- **Files:** `full/delete-{ws,grpc,http,split}.sh`, `lite/delete-{ws,grpc,http,split}.sh`.
- **Cause:** Deletion removed the quota limit file, limit-IP file, log, and config marker, but never the `/etc/xray/quota/<proto>/<user>_usage` counter that `quota-*.sh` creates on every quota change.
- **Impact:** Orphaned usage files accumulate forever and (with any prefix-based cleanup) can misreport quota for the next user reusing the same username. Verified live on Debian 12 VPS after fix: delete removed both `testvm2` and `testvm2_usage`.

### 68. IP-Limit Enforcer Deletes the Config From the Marker to End-of-File (CONFIRMED)
- **Files:** `full/limit-ip-{ws,grpc,http,split}.sh`, `lite/limit-ip-{ws,grpc,http,split}.sh`.
- **Cause:** The triggered-delete used `sed -i "/^### $user $exp/,/^},{/d"` with `$exp` never assigned, and the end pattern `^},{` matches nothing (verified: `^},{` count = 0 in all four live configs — the identical line exists in original V23). An unmatched range deletes from the start pattern to the last line of the file.
- **Impact:** The first account that exceeded its IP limit wiped the rest of its config (all accounts after it) and left broken JSON. Verified live on Debian 12 VPS: `$exp` undefined, `^},{` count 0, original line identical.

### 69. WS IP-Limit Probe Calls the XRay Stats API on a V2Ray Port (CONFIRMED)
- **Files:** the same 8 `limit-ip-*.sh` scripts.
- **Cause:** The scripts run `xray api statsonline --server=127.0.0.1:10080`, but the WS transports on port 10080 are served by V2Ray, which returns `Unimplemented ... unknown service xray.app.stats.command.StatsService` and exposes no online-session metric at all. The empty result then fed `[[ "" -gt "2" ]]`, producing integer-expression errors every 5 minutes.
- **Impact:** The WS limit check could never trigger and error-spammed cron output. Verified live on Debian 12 VPS: `Unimplemented` response on :10080, while `xray api statsonline` works against the xray-backed gRPC port :10083. (Decision recorded: v2ray-served transports now probe once and exit cleanly; xray-backed transports enforce for real.)

### 70. Dropbear Login Events Are Invisible to the SSH IP Limit and Login Checker (CONFIRMED, pre-existing in V23)
- **Files:** `full/limit-ip-ssh.sh`, `full/cek-login-ssh.sh`.
- **Cause:** On Debian 12 the dropbear unit (the daemon actually serving SSH accounts on port 109) starts with `-EF` and logs only to the systemd journal — `/var/log/auth.log` contains zero dropbear lines (verified live: `grep -c dropbear /var/log/auth.log` = 0 while the journal showed `Password auth succeeded for 'kvs1' ...`). Both scripts grep the auth log for `Password auth succeeded`.
- **Impact:** SSH-account logins were never counted: the multi-login IP limit never triggered for any real client, and `cek-login-ssh` printed an empty dropbear table. Verified live on Debian 12 VPS.

### 71. Fixed Field Offsets Cannot Parse RFC3339 Auth-Log Timestamps (CONFIRMED, pre-existing in V23)
- **Files:** `full/limit-ip-ssh.sh`, `full/cek-login-ssh.sh`.
- **Cause:** Debian 12's rsyslog writes RFC3339 timestamps (`2026-09-23T23:10:07.792582+08:00 localhost sshd[82746]: Accepted password for ...`) while the parsers assume the classic `Sep 23 23:10:07` prefix with fixed positions (user = field 9, IP = field 11). On RFC3339 lines those positions hold the IP and `port`, so fields are shifted by two.
- **Impact:** The OpenSSH branch counted nothing or mis-assigned fields on Debian 12, and `cek-login-ssh` displayed IP addresses in the Username column. Verified live on Debian 12 VPS.

## Live Audit Cycle 4 Addendum: SSH Login-Path Expiry Finding (Bug 72)

### 72. Expired SSH Accounts Are Not Refused at Login Until xp Cleanup (CONFIRMED, pre-existing in V23)
- **Files:** expiry path of `full/addssh.sh`, `full/trial-ssh.sh`, `full/xp.sh` (enforcement gap; fixed in `full/expire-ssh.sh`, `full/extend-ssh.go`, `installer/xray.sh`).
- **Cause:** SSH accounts receive a shadow expiry date via `useradd -e`, but the dropbear daemon that actually serves SSH logins (Debian 12, v2022.83, built without PAM) contains no account-expiry check at all (`strings /usr/sbin/dropbear | grep -i expired` returns nothing) and never reads the shadow expire field during authentication. The only enforcement is `xp`'s cron, which deletes expired accounts every 15 minutes. Between the expiry moment and the next `xp` run, expired accounts authenticate normally.
- **Impact:** Client-tested on the KVM VM against the Debian 12 VPS: an account with expiry set to Sep 22, 2026 authenticated and ran a full session from the VM (`Password auth succeeded for 'kvsx'` in the journal at 23:33:38; client saw the session start, exit 1 - no refusal) and only became unusable when `xp` deleted the user at the 23:45 cron run. Expired customers could keep using the service for up to 15 minutes after expiry, and an expired-but-not-yet-deleted account was indistinguishable from an active one to the client.

## Fresh-Reinstall Audit Cycle (Bug 73)

### 73. Reinstall Stacks Duplicate Cron Entries for Every Daemon (CONFIRMED)
- **Files:** `installer/xray.sh` (cron block install; fixed with a strip-before-append guard).
- **Cause:** The installer appended the 16-line daemon cron block to `/etc/crontab` unconditionally (`>>`). On a reinstall over an existing setup the old lines were still there, so every daemon line existed twice.
- **Impact:** Verified live on the reinstalled Debian 12 VPS: all 16 daemon lines present ×2 (32 `flock` lines). Every 5-minute daemon ran twice per tick (serialized only by `flock`), the full `xp` sweep ran twice, and each IP-limit lock scheduled double at-unlock jobs.

### 74. Backup Upload Produces an Empty Link (file.io API Discontinued) (CONFIRMED)
- **Files:** `full/backup.sh`, `lite/backup.sh` (fixed with fallback upload chain).
- **Cause:** The scripts POST the backup zip to `https://file.io` and parse `.link`/`.key` from the JSON response. file.io discontinued anonymous uploads: the endpoint now returns HTTP 301 to its marketing landing page (a Gatsby HTML site), so `upload_link` and `id_link` were always empty. `curl -s` without `-L` never even followed the redirect. Probes from the VPS confirmed transfer.sh (empty), 0x0.st (uploads disabled: "AI botnet spam"), and bashupload (empty) are also unusable.
- **Impact:** Verified live on the fresh Debian 12 VPS: every backup completed the archive but recorded `Link Backup: ` (empty), so off-site restores were impossible - the backup feature was silently dead.

### 75. Lock Message Lists Timestamp Fragments Instead of IP Addresses (CONFIRMED, pre-existing in V23)
- **Files:** `full/limit-ip-ssh.sh` (one-token fix).
- **Cause:** The multi-login log line format is `PID - USER - IP - TIME`, so the IP is always field 5. The lock-notification builder used `awk '{print $NF}'`, which returns the last token of the timestamp (`23:09:02` / `2026-09-23T21:04:17+08:00`) instead of the address. Same defect existed in the pristine V23 original.
- **Impact:** Every SSH lock notification (log/Telegram `[ Time Login ]` section) listed time fragments where the offending IP addresses should be, making abuse review useless.

### 76. Input Prompts and Create-Account Headers Render Plain White (CONFIRMED, UI inconsistency left by the TUI restyle)
- **Files:** 138 shell scripts across `full/` and `lite/` (all `add-*`, `trial-*`, `addssh`, `change-*`, `delete-*`, `lock`/`unlock`, `menu-*`, `routing`, `xp`, `backup-gd`, `xl2tp`), `install.sh`, `installer/full.sh`, `installer/lite.sh`, `installer/slowdns.sh`, and 21 Go programs (`change-limit-ip-*`, `log-database-xray-*`, `limit-ip`, `extend-ssh`, `delete-ssh`, `pwd-ssh`, `log-acc-ssh`).
- **Cause:** Earlier cycles restyled the menu/banner layer of the TUI (English text, FN AutoSC branding, colors) but never touched the input layer. Every `read -p "..."` prompt, the `════ Create VMess WS ════` header boxes, the `echo -n` prompts, and the Go `fmt.Print("Input username: ")` prompts were still emitted with no ANSI color at all.
- **Impact:** Verified on the VPS: the create-account screen showed a colored header context but the actual `Username:` / `Limit IP:` / `Expired (days):` prompts and validation errors rendered plain white, so the restyle looked half-finished on exactly the screens users touch most.

### 77. Telegram Notifications Carry Raw ANSI Escape Sequences (CONFIRMED, regression introduced by fix 78)
- **Files:** the 48 `add-*` / `trial-*` scripts in `full/` and `lite/` (vmess/vless/trojan x grpc/http/split/ws) that build a `TEKS` account-details block and send it with `curl --data-urlencode "text=$TEKS"`.
- **Cause:** Fix 78 colorized the `TEKS` blocks (rules, titles) so the on-screen account card renders in color. `TEKS` is consumed three ways, but only two of them expand the escapes: `format_display "$TEKS"` (terminal) and `echo -e "$TEKS" > logfile`. The third, the Telegram `curl`, transmits the string verbatim, and the Bot API does not interpret ANSI - so operators received literal `^[[96;1m` / `^[[1;33m` garbage wedged into the UUID/link/details fields. Before fix 78 `TEKS` held no escapes at all (`git show 2e84f30:full/xp.sh` and the pristine V23 copy both contain 0 `\033`), confirming this as a pure regression rather than pre-existing behaviour.
- **Impact:** Every create/trial notification on all 48 paths (both `full` and `lite`) reached Telegram unreadable, on precisely the events where the panel's UUID, remarks, and `vmess://`/`vless://`/`trojan://` links must be copyable.

### 78. Input Prompts Colored Cyan by the TUI Restyle (CONFIRMED, scope error in fixes 76/78)
- **Files:** the same set restyled by fix 78 - the **520** `read -p` / `read -rp` / `read -n 1 -s -r -p` prompts, the **8** `echo` prompts (2 `echo -ne`, 6 `echo -e "...\c"`), and the **31** Go `fmt.Print` input prompts across `full/`, `lite/`, `install.sh`, `installer/` and the 21 `.go` programs.
- **Cause:** Fix 76 recorded "prompts render plain white" as a defect and fix 78 therefore colored **every** input prompt cyan (`$'\033[96;1m...\033[0m'` ANSI-C quoting, `echo -ne`, `fmt.Print("\033[96;1m...")`). Reviewing the live screens showed that premise was only half right: the plain white was correct for the **input field itself**. What needed the color is the header layer *around* it - the yellow title and the rainbow separator rule - not the `Username:` / `Select menu :` line the operator actually types on. The prompts should sit on the default foreground like every other form input in the panel.
- **Impact:** Every input prompt in the panel rendered bright cyan: `Username:`, `Limit IP:`, `Expired (days):`, `Input UUID (Empty Default):`, the `Select menu :` option selects, `Press ENTER to go back`, and all 31 Go prompts (`Input username:`, `Day Extend:`, `Input New IP Limit:`, ...). The cyan fought the yellow titles and rainbow rules directly above it and drew more attention than the account data the screen exists to show.

### 79. Quantity Fields Accept 0 and Never State Their Unit (CONFIRMED, pre-existing in V23)
- **Files:** every quantity input prompt - the **96** shell `read` prompts (`Limit Ip`, `Limit Quota`, `Active Time`, `Expired (days)`, `Expired (minutes)`, `Duration (Days)`, `Duration Day`, `Limit IP`, ` Input New Quota (GB) `) across the 12 `add-*` scripts in both `full/` and `lite/`, `full/addssh.sh`, the 8 `extend-{ws,http,grpc,split}.sh`, `full/trial-ssh.sh`, `full/menu-noobz.sh`, `full/xl2tp.sh`, `full/menu-wg.sh` and the 8 `change-quota-*.sh`; plus the **10** Go `fmt.Print` prompts in the 8 `change-limit-ip-*.go`, `full/limit-ip.go` and `full/extend-ssh.go`.
- **Cause:** the fields were written as bare numeric reads with no range check and no unit on the prompt - `read -p "Limit Ip: " ip`, `read -p "Limit Quota: " quota`, `read -p "Active Time: " masaaktif` - so the operator could not tell whether the number meant days, GB, minutes or a connection count, and any integer including `0` was accepted and then interpreted differently by every consumer.
- **What `0` actually did, each path verified against the code:**
    - **xray quota `0`** - `add-*` skips its `[[ $quota -gt 0 ]]` write, so no quota file exists, and `quota-*.sh` only enforces `if [[ -f "$quota_file" ]]`. Silently unlimited.
    - **xray IP limit `0`** - no limit file is written and the Bug-68 guard in `limit-ip-*.sh` (`if ! [[ "$limit" =~ ^[1-9][0-9]*$ ]] then continue`) skips enforcement. Also silently unlimited.
    - **`change-quota` `0`** - both `isNumeric("0")` and `^[0-9]+$` accept it, the file is rewritten to **0 bytes**, and the next `quota_used > 0` sweep deletes the account outright.
    - **SSH IP limit `0`** - `addssh.sh`'s guarded write is skipped, then `limit-ip-ssh.sh` *creates* the missing file filled with `2`, so the stored limit contradicts what was typed; meanwhile `limit-ip.go` writing `0` makes `cekcek -gt 0` true on the first login and locks the account.
    - **days `0`** - `xp.sh` deletes at `exp2 -le 0` and `useradd -e <today>` expires the account the same day; `extend-ssh.go` accepts `strconv.Atoi("0")` and extends 0 days.
- **Impact:** an operator who types `0` by mistake gets one of four outcomes - an unlimited account, an account deleted on the next quota sweep, an account locked on first login, or an expiry of today - and none is signalled at the point of entry, because the prompt shows neither the unit nor the valid range. A stray keypress is indistinguishable from a deliberate one.
- **Related:** whether `0` should mean "unlimited" was considered and rejected as a design; see `is-decision.md` section 4.

### 80. The 0 Rule Printed on Every Quantity Field Instead of Stated Once (CONFIRMED, usability defect introduced by fix 81's presentation)
- **Files:** the same **192** shell quantity prompt lines (96 first-reads + 96 loop re-reads) and **10** Go `fmt.Print` prompts that fix 81 rewrote - the 12 `add-*` scripts in both `full/` and `lite/`, `full/addssh.sh`, the 8 `extend-{ws,http,grpc,split}.sh`, `full/trial-ssh.sh`, `full/menu-noobz.sh`, `full/xl2tp.sh`, `full/menu-wg.sh`, the 8 `change-quota-*.sh`, the 8 `change-limit-ip-*.go`, `full/limit-ip.go` and `full/extend-ssh.go`.
- **Cause:** fix 81 attached the range notice to the individual field it constrains. That is right for a rule that differs per field, but wrong for one that is identical everywhere on the screen: `0 not allowed` was therefore repeated on each of the three quantity reads of an `add-*` form *and* again on each loop re-read, so one screen printed the same sentence up to six times. Nothing about the sentence was wrong - the repetition was. The suffix also landed on the count prompts where V23's `Limit Ip: ` / `Limit IP: ` had already been unambiguous, adding noise without adding information.
- **Impact:** account creation is the panel's hot path, and the repeated suffix pushed the prompts the operator is actually typing against further down the screen while forcing them to re-read the identical rule between `Username`, `Password` and the value being entered. The unit, which is the part that genuinely varies per field, was drowned out by the part that does not.
- **Related:** fix 81 (the rejection loops and red error, which this change deliberately leaves in place); placement recorded in `is-decision.md` section 4.

### 81. The 0 Notice Sits Flush Against the Form and Shares the Prompts' Plain White (CONFIRMED, presentation gap left by fix 82)
- **Files:** the **47** shell `echo "0 not allowed"` notices and the **10** Go `fmt.Println("0 not allowed")` notices that fix 82 introduced - one per screen across the 12 `add-*` scripts in both `full/` and `lite/`, `full/addssh.sh`, the 8 `extend-{ws,http,grpc,split}.sh`, `full/trial-ssh.sh`, `full/menu-noobz.sh`, `full/xl2tp.sh`, `full/menu-wg.sh`, the 8 `change-quota-*.sh`, the 8 `change-limit-ip-*.go`, `full/limit-ip.go` and `full/extend-ssh.go`.
- **Cause:** fix 82 correctly reduced the rule from every field to one notice per screen, but emitted it as an unadorned `echo` with no whitespace before it and no colour of its own. It therefore landed directly under `Password:` and directly over `Limit IP:` in the same default foreground as both, so it read as one more line of the form rather than as the rule governing the fields below. The reduction was right; the rendering gave the notice no more prominence than the prompts it is supposed to explain, and no breathing room to be read as a separate statement.
- **Impact:** on the create-account screens - the panel's hot path - an operator scanning the form sees `Password:`, then a line of text indistinguishable in weight and colour from the prompt above it, then the field to type in. The notice is the only line on the screen that is an instruction rather than a prompt, and nothing in its presentation says so, which is the same reason fix 81 attached it to every field in the first place: it was not visually separable from the form.
- **Related:** fix 82 (which set the placement); the panel's orange, `orange='\033[38;5;208m'`, already defined in 8 menu scripts and as `colorOrange` in the Go programs.

### 82. Account Cards Print Their Separators and Title as Literal Escape Text (CONFIRMED, self-introduced by `012774e`, made visible by the rainbow-separator restyle)
- **Files:** `config/format.sh` - `format_display()`'s fallback branch (`echo "$line"`, pre-fix line 69) and its `last_sep` subscript (pre-fix line 23) - the single renderer sourced by all **50** account-card callers (**26** in `full/`, **24** in `lite/`: every `add-*`, `trial-*` and `addssh` script, so every protocol in both trees).
- **Cause:** commit `012774e` (ours, 2026-09-21) replaced the working `echo -e "$TEKS"` at `add-vmess-ws.sh:220` and its siblings with `source /etc/funny/format.sh; format_display "$TEKS"`. The new renderer routes any line without a `:` through a bare `echo "$line"`, and `echo` without `-e` does not expand backslash escapes, so the card's escape-carrying colon-less lines printed verbatim. Its separator test `^[=]{3,}$` matches only a *bare* `===` run, so an escape-prefixed separator never populated `sep_lines`; with `nseps=0`, `local last_sep=${sep_lines[$((nseps-1))]:-999}` subscripted index `-1` of an empty array and bash wrote `sep_lines: bad array subscript` to stderr ahead of every card. The rainbow-separator restyle (`79eddef`, 2026-09-24) then changed the separators from `\033[96;1m=====…` to a 25-segment truecolor run, turning a short string of junk into a screen-filling wall of it - the amplifier, not the cause.
- **Impact:** on the real `add-vmess-ws` card - 32 lines, 11 of which carry escapes - **9 printed as raw `\033[38;2;…m` text**: all **8** rainbow separators plus the yellow `Xray VMess WS` title, behind an error line, while **16** lines rendered correctly (the colon-bearing key/value rows and the 2 `Link` rows, which also carry a colon and so take an `echo -e` branch). The separators and title *are* the card's structure, so the post-creation screen - the one moment an operator reads back the UUID, expiry and copyable `vmess://` links for a customer - looked corrupted precisely when that data matters most. All **50** callers were affected identically, because they source the single `/etc/funny/format.sh`.
- **Related:** bug 77's found entry listed `format_display "$TEKS"` among the consumers that *do* expand escapes and therefore cleared it, sanitising only the Telegram payload (the strip recorded as fix 79); that premise held only for the colon-bearing rows, which is why the fault survived that audit untouched.

### 83. Account Logs Lost Their Restyling Because the Card Rules, Title and Link Lines Carry Escape Codes (CONFIRMED, regression introduced by fixes 78 and 79)
- **Files:** the card blocks (`TEKS="` / `TEXT="` / `message=`) of all **50** account-card scripts - **26** in `full/` (the 12 `add-*`, the 13 `trial-*` and `addssh.sh`) and **24** in `lite/` (the 12 `add-*` and 12 `trial-*`) - plus the two consumers that style them, `config/format.sh` (`format_display`) and the five Go log viewers (`log-acc-ssh`, `log-database-xray-{ws,http,grpc,split}`).
- **Cause:** fix 78 (`fad2fb4`) wrapped the card's `Xray VMess WS` title and its two `Link` lines in `\033[1;33m…\033[0m` inside the `TEKS` blocks; fix 79 (`79eddef`) replaced the card's plain `====` rules with 25-segment rainbow `\033[38;2;…m-` runs. Both consumers detect structure by **text prefix on the raw line** - `format_display` tests `^[=]{3,}$` for rules and `^Link\ ` for links, the Go viewers test `HasPrefix(trimmed,"=="|"--"|"━━")` and `HasPrefix(trimmed,"Link ")` - and an escape-prefixed line matches none of them. So the rules were never detected and printed verbatim, the title never met the "between two rules" test, and the `Link` rows fell through to the generic `key: value` branch.
- **Impact:** the account log lost the whole standardized styling that `a7b3613` established and that `012774e`/`format_display` was written to reproduce. The screen operators read an account back from showed raw rainbow dash rules instead of rainbow `=` outer / blue `-` inner rules, a yellow title instead of purple, and green `Link` rows instead of deep purple - on every account, in both trees. On the terminal card the same defect surfaced as the literal-escape corruption recorded as bug 82.
- **Related:** bug 82 (same escape-prefix root cause, on the `echo` fallback rather than the detection tests); fix 85 reverts the card's structural lines to plain, which restores detection in both consumers.

### 84. `change-id-grpc` Silently Fails to Change the ID Because Its `sed` Pattern Loses the Quotes (CONFIRMED by local reproduction, inherited from V23)
- **Files:** `full/change-id-grpc.sh:131-134`, `lite/change-id-grpc.sh:131-134`.
- **Cause:** the substitution is written `sed -i "s|"id": "${old}"|"id": "${new}"|" ...`. Bash consumes the inner `"` as quoting delimiters, so the string that actually reaches `sed` is `s|id: OLD|id: NEW|` - the double quotes around `id` are gone. Against a real config line (`      "id": "OLD-UUID",`) that pattern does not match, so the command exits 0 having changed nothing. Line 134 has the same class of defect from the other direction: `sed -i 's/${old}/${new}/g'` uses single quotes, so `${old}`/`${new}` reach `sed` literally and the log rewrite is a guaranteed no-op.
- **Impact:** an operator using the gRPC "change id" menu option to rotate an account's UUID is told nothing and gets an unchanged config - the old ID keeps working and the new one never takes effect, which is precisely the opposite of the security operation the menu exists for. The log line keeps the stale UUID too, so the account card and the config disagree.
- **Reproduction:** `printf '      "id": "OLD-UUID",\n' | sed "s|"id": "OLD-UUID"|"id": "NEW-UUID"|"` returns the line unchanged; the correctly quoted form returns `      "id": "NEW-UUID",`. `change-id-ws/http/split` do not share the defect.

### 85. The Locked-HTTP Notification Prints an Empty Username Because It Uses `$user` Instead of `$name` (CONFIRMED by inspection, regression from the TUI restyle)
- **Files:** `full/locked-xray-http.sh:104`, `lite/locked-xray-http.sh:104`.
- **Cause:** the notification body reads `<b>👤 Username :</b> <code>$user</code>`, but this script assigns `name` (the variable filled by `read -p "Input Username to Locked: " name` and used by the JSON deletion, `"/### $name $exp/ {N;d}"`). `$user` is never assigned on this path. The three sibling scripts (`locked-xray-ws/grpc/split`) all use `$name` on the equivalent line.
- **Impact:** every HTTP lock notification is sent to Telegram with the username field blank, so the operator cannot tell which account was locked from the message alone - the same defect that bug 11 fixed for the deletion target, left behind on the message body of the HTTP variant only.
- **Reproduction:** run `bash -n` clean but `bash -u`/shellcheck flags `user` as referenced-but-unassigned (SC2154) only in the HTTP variant.

### 86. The lite Menu Uses `$purple` and `$orange` Colour Variables It Never Defines (CONFIRMED by inspection, introduced by the menu standardization)
- **Files:** `lite/menu.sh:196` and `lite/menu.sh:213`.
- **Cause:** the bundled menu prints `${purple}TOTAL ACCOUNTS${NC}` and `${orange}Press [Ctrl + C] to exit${NC}`, but `lite/menu.sh` never assigns `purple` or `orange`. The full menu does define both (`full/menu.sh:182-183`, `export purple='\033[1;35m'` / `export orange='\033[38;5;208m'`), and the lite file was synced to the full file's *usage* during the menu-styling standardization without carrying the *definitions* across. V23's `lite/menu.sh` used neither variable.
- **Impact:** on lite installs the "TOTAL ACCOUNTS" heading and the "Press [Ctrl + C] to exit" footer render in the default foreground instead of purple and orange, so the lite menu is visibly inconsistent with the full menu and with the rest of the panel's palette.

### 87. `installer/request.sh` Falls Back to a 404 URL for the UDP Request Binary (CONFIRMED, 404 verified upstream)
- **Files:** `installer/request.sh:66`.
- **Cause:** the download is `wget ... github.com/rohjagad/fn-autosc-miscellaneous/releases/download/v1.23/udp-request-linux-amd64 || wget ... ${hosting}/udp-request-linux-amd64`. The primary URL is valid, but the fallback points at the repository root, where the file does not exist - it is committed at `udp/udp-request-linux-amd64`. `https://raw.githubusercontent.com/rohjagad/fn-autosc/main/udp-request-linux-amd64` returns **404**; `.../udp/udp-request-linux-amd64` returns 200.
- **Impact:** installing the UDP-request service has no working second source. If the GitHub release is ever unavailable (rate limit, deletion, network policy on the release host) the install aborts after the fallback also fails, leaving a half-written `/root/udp-request/` directory and no service - even though the binary is present in the repository.
- **Reproduction:** `curl -o /dev/null -w '%{http_code}' https://raw.githubusercontent.com/rohjagad/fn-autosc/main/udp-request-linux-amd64` -> 404, versus `.../udp/udp-request-linux-amd64` -> 200.

### 88. `limit-ip-ssh.sh` Iterates the Username Array Unquoted (CONFIRMED by inspection, inherited from V23)
- **Files:** `full/limit-ip-ssh.sh:256`.
- **Cause:** `for user in ${username[@]}` expands the array without quotes, so each element is subject to word splitting and pathname expansion. ShellCheck rates this an *error* (SC2068). Every sibling loop in the file quotes correctly.
- **Impact:** usernames are normally single tokens so the common case survives, but any entry containing whitespace or a glob metacharacter is split into several bogus "usernames". The loop then writes a default limit file for each fragment (`/etc/xray/limit/ip/ssh/<fragment>`), creating stray limiter entries for accounts that do not exist - and leaving the real account's limit unset for that pass.
- **Reproduction:** `username=("a b"); for u in ${username[@]}; do echo "[$u]"; done` prints `[a]` and `[b]`; the quoted form prints `[a b]`.

### 89. The System Menu's OS-Reinstall Options Cannot Work Because the Reinstall Fork Is Stale (CONFIRMED live against the test VPS, aborts safely)
- **Files:** `full/menu-system.sh` and `lite/menu-system.sh` - every case that runs `curl -O https://raw.githubusercontent.com/rohjagad/reinstall/main/reinstall.sh && bash reinstall.sh <os> <ver> && reboot`, e.g. `full/menu-system.sh:559-562` (Debian 9-12), and the OpenEuler/OpenSUSE/Ubuntu/Alpine/Rocky blocks below it.
- **Cause:** the panel's `reinstall.sh` is a fork carrying `SCRIPT_VERSION=4BACD833-A585-23BA-6CBB-9AA4E08E0004`, but it fetches the *upstream* `trans.sh` and then refuses to continue unless it finds its own GUID inside it (`curl -Lo $initrd_dir/trans.sh $confhome/trans.sh; if ! grep -iq "$SCRIPT_VERSION" $initrd_dir/trans.sh; then error_and_exit "This script is outdated, please download reinstall.sh again."`). Upstream has moved to `...0005`, so the fork's GUID is never present and every reinstall run aborts at the initrd stage.
- **Impact:** every "Reinstall OS" entry in the System menu is dead on every machine, across all of `full/` and `lite/` - the panel's recovery path for a broken or compromised box cannot run at all. Re-downloading, as the error message instructs, changes nothing because the *fork* is what is stale, not the local copy.
- **Reproduction (live, this VPS):** `bash reinstall.sh debian 12 --username root --password '***' --ssh-port 22` reaches `***** MOD DEBIAN INITRD *****`, downloads `bin456789/reinstall/main/trans.sh`, then prints `ERROR / This script is outdated`. Comparing the two sources confirms the cause: `rohjagad/reinstall` has `SCRIPT_VERSION=...0004` while `bin456789/reinstall` has `...0005`, and only the latter's GUID appears in `trans.sh`. Substituting the upstream script re-runs the same command successfully, which isolates the fault to the fork.
- **Note:** the failure is safe - it aborts before writing the disk, and the affected machine is left neither modified nor boot-primed (grub still has only its normal menuentry, `/boot` holds only the installed kernels, and the box keeps running the old system).

### 90. `xl2tp` Prints Its "Already Exists" Warning With an Undefined Colour Variable (CONFIRMED by inspection)
- **Files:** `full/xl2tp.sh:102`.
- **Cause:** the duplicate-account warning is written `echo -e "Username ${RED}${VPN_USER}${NC} already exists, please choose another"`, but the file defines only the lower-case palette - `red='\033[0;31m'`, `green`, `blue`, `purple`, `orange`, `NC` (lines 56-61). In bash `${RED}` is a different, unset variable, so it expands to nothing and the warning loses its colour while `${NC}` still resets. The lower-case `red` is used nowhere by this file.
- **Impact:** the one warning an operator sees when they pick a username that is already taken renders without the red emphasis the rest of the panel gives to errors, so it reads as ordinary output instead of a rejection.
- **Related:** the same class of defect as bug 86 (colour variables referenced but never defined); `lite/xl2tp.sh` is clean.

### 91. The Installer Cannot Bootstrap Itself on a Minimal Debian, and Misreports It as a Licence Failure (CONFIRMED live on a freshly reinstalled Debian 12)
- **Files:** `install.sh` (lines 3-5, 24, 39, 72-84) and `README.md:73-77`.
- **Cause:** the README's install line is `bash <(curl -fsSL https://raw.githubusercontent.com/rohjagad/fn-autosc/main/install.sh)` and it states "The installer bootstraps `curl`/`wget`, configures Debian mirrors on stripped images". Neither is true: `install.sh` never installs either tool. `full()`/`lite()` fetch the payload with `curl -fsSL "${hosting}/installer/full.sh" -o full.sh || wget -q ...` and then `chmod +x full.sh; ./full.sh`, so with neither binary present the download fails and the follow-up commands run against a file that was never created. The `apt install wget curl -y` that would have supplied them sits at `installer/full.sh:106` - behind the very download that cannot happen.
- **Impact:** on a minimal Debian - which is exactly what the panel's own "Reinstall OS" feature produces (bug 89) - the installation cannot begin, and the README's documented command cannot even be typed. The failure is then misreported: with `curl` absent, `LOCAL_IP=$(curl -4 -s ifconfig.me)` (line 24) and `PERMISSION_DATA=$(curl -s "$PERMISSION_URL")` (line 39) both return empty, so the authorization step falls through to `Your IP doesn’t have on database` and exits - sending the operator to check their licence when the real problem is a missing downloader.
- **Reproduction (live, fresh Debian 12 after the step-3 reinstall):** `command -v curl` and `command -v wget` both print nothing; `printf 'full\n' | bash install.sh` outputs `/root/install.sh: line 24: curl: command not found`, the same at line 39, then `Your IP doesn’t have on database`. Installing `curl` and `wget` by hand and re-running the identical command proceeds normally (licence accepted, `full.sh` starts), which isolates the fault to the absent bootstrap rather than to authorization.

### 92. The Reinstall Menu Offers 13 OS/Version Combinations the Wired Script Rejects (CONFIRMED live, regression from fix 93/91)
- **Files:** `full/menu-system.sh`, `lite/menu-system.sh` - every `bash reinstall.sh <os> <ver>` invocation (31 per file).
- **Cause:** fix 91 repointed the whole reinstall menu from the stale `rohjagad/reinstall` fork to the maintained upstream `bin456789/reinstall` so the feature would run at all (bug 89). The *commands* were carried over unchanged, but the fork's and upstream's supported version lists have drifted apart: upstream answers anything it does not recognise with `ERROR: Please specify a proper os` plus its usage text and exits, so the option does nothing (the trailing `&& reboot` never runs either).
- **Impact:** 13 of the 31 menu entries are dead - the operator picks an OS, the script prints a usage wall and nothing else happens. Specifically: `openeuler 24.04` (upstream `24.03`), `opensuse 15.5`/`15.6` (upstream `16.0`/`tumbleweed`), `ubuntu 16.04` (upstream `>=18.04`), `alpine 3.17`/`3.18`/`3.19`/`3.20` (upstream `3.21`-`3.24`), `alma 9` (upstream spells it `almalinux`), `nixos 24.05` (upstream `26.05`), `fedora 40` (upstream `43|44`), plus two outright typos that never worked under either script: `gento` (should be `gentoo`) and `kali` (upstream requires a branch, `kali rolling`/`last-snapshot`).
- **Reproduction (live):** `bash reinstall.sh alpine 3.17` -> `***** ERROR ***** / Please specify a proper os` + usage; the same command with `alpine 3.23` proceeds and begins fetching. The panel offered `3.17`.
- **Related:** fix 93/91; the fork is still recorded for reference in `is-decision.md` section 6.

### 93. `install.sh` Aborts Silently When `screen` Cannot Start (CONFIRMED by reproduction, defect in the new session hand-off)
- **Files:** `install.sh` - the persistent-session block added by `743377a`.
- **Cause:** the hand-off was `exec screen -S fninstall bash "$SELF"`. `exec` *replaces* the shell, so the install only survives if the launched command succeeds. `screen` can legitimately fail to start on a tty - an unusable `TERM`, an unwritable `/run/screen`, a container without `/dev/pts` - and in that case the shell has already been replaced, so control never returns, the fallback never runs, and the installer ends without a message or any installation. `shopt -s execfail` does not help: it only covers a failure to *execute* the file, and here screen executes fine and then exits non-zero.
- **Impact:** on any host where screen cannot take over, the documented installer does nothing at all - silently. Worse than the disconnection problem the feature was added to solve, because a disconnection at least leaves partial progress and an error.
- **Reproduction:** with a `screen` stub that prints `cannot open terminal` and exits 1 on `PATH`, `bash -c 'exec screen -S x true; echo REACHED'` never prints `REACHED` (shell replaced, exit 1), whereas the fixed form `screen -d -R x true && exit 0; echo CONTINUES` prints `CONTINUES`. The happy path is unchanged: a working screen still hands off and the parent exits 0.

Found 94. **udp-request fallback download 404s** (`installer/request.sh`) - the raw fallback built `${hosting}/udp/udp-request-linux-amd64` while `hosting` already ends in `/udp`, so the fallback could never succeed; the release-CDN primary masked it. Regression introduced by `f0e4c10`; V23's equivalent line used `${hosting}/udp-request-linux-amd64`.

Found 95. **Lite crontab schedules tools lite does not ship** (`installer/xray.sh`, run by both editions) - `expire-ssh` (added by the Bug-72 fix) and `limit-ip-ssh` (inherited from V23) have no counterpart in `lite/` or `menu/lite.zip`, so cron failed every 5 minutes on lite installs.

Found 96. **The Telegram bot token was never actually removed** (`installer/full.sh`, `installer/lite.sh`) - `bugs-fixed.md` recorded it as fixed and "verified" with `grep -rE 'bot[0-9]{6,}:[A-Za-z0-9_-]{20,}'`, but the committed value has no `bot` prefix, so the pattern could never match and reported 0 for a file that still held a live credential. A false-positive verification, not a fix.

Found 97. **SlowDNS never answered because the UDP 53 redirect was shadowed** (`installer/slowdns.sh`) - `udp-request` inserts wildcard UDP captures (`dpts:1:8988`, `dpts:1:65535`) at the top of `nat PREROUTING` when it starts, after `slowdns.sh` has inserted the `dport 53 -> 5300` redirect, and iptables is first-match, so UDP 53 went to udp-custom and `dnstt` never received a query. The delegated nameserver resolved to the host but the host did not answer. Inherited from V23. Confirmed live by rule counters (0 packets on the 53 rule) and fixed with a re-assert timer; the host now answers (`Response from 202.155.17.126`).

Found 98. **The WS IP limit can never fire: `json/ws.json` lost `statsUserOnline`** (`json/ws.json`, consumed by `full/limit-ip-ws.sh` / `lite/limit-ip-ws.sh`) - the template's `policy.levels."0"` block has `statsUserDownlink` and `statsUserUplink` but not `statsUserOnline`. This is the V23 (V2Ray-era) WS template with only the log path patched; the 1.20 reference - the Xray-WS design the migration claims to restore - and the current `grpc.json`/`split.json`/`upgrade.json` all set `statsUserOnline: true`. Without it Xray never registers the `user>>><email>>>online` counter, so `xray api statsonline` fails for every user, not only for a nonexistent probe. `limit-ip-ws.sh` reads that value into `cek`; the empty result fails its `^[0-9]+$` guard, the loop `continue`s, and the concurrent-IP limit is silently never enforced. The log-derived "Total IP Login" in `cek-xray-ws` still shows a number, which makes it look like limiting works.
- **Confirmed live (Debian 12, before the fix):** a real vmess-WS tunnel was established as user `cence` (socks client -> `127.0.0.1:23456`, path `/vmess`); `curl --limit-rate 60k` pulled **6,168,293 bytes** through it, and for the whole transfer `xray api statsonline --server=127.0.0.1:10080 -email cence` returned `app/stats/command: user>>>cence>>>online not found` on every poll.
- **Why the migration's live check missed it:** it accepted that same `user>>>probe>>>online not found` string as proof the stats service was healthy. The probe email never exists, so the string is returned whether or not online tracking is enabled; only a real active session distinguishes the two. A false-positive verification of the same kind as `Found 96`.

Found 99. **The WS quota service never records usage: `xray api stats` is called without `-name`** (`full/quota-ws.sh`, `lite/quota-ws.sh`, lines 96-106) - the migration translated V2Ray's `v2ray api stats` (which lists all counters when no name is given) into `xray api stats` with no `-name`. Xray's `stats` subcommand requires `-name` (see `xray help api stats`); without it the RPC returns `app/stats/command:  not found`, so `usage_data` is empty, `inb` fails the emptiness guard and every user is skipped with "Data inbound usage for user <u> is incomplete. Skipping." on each 30-second pass. The same block kept V2Ray's unit handling (`sed 's/MB//'`, then `* 1048576`), which would have mis-scaled Xray's raw byte counters by 1,048,576x even if the query had worked, and it never resets the counters it accumulates into `<user>_usage`.
- **Confirmed live:** the exact command printed `failed to get stats: rpc error: code = Unknown desc = app/stats/command:  not found.` with empty output; after 6.1 MB of traffic through `cence` there was still no `/etc/xray/quota/ws/cence_usage` (only the limit file), so quota-limited WS accounts are never locked.
- **Related:** the three sibling transports (`quota-grpc`/`quota-http`/`quota-split`) use the correct Xray pattern - `statsquery` to read, `xray api stats -name ... -reset` to clear - and are unaffected. This is the same mechanical `v2ray` -> `xray` substitution that produced `Found 100`.

Found 100. **`cek-xray-ws` prints blank traffic: the same missing `-name` call** (`full/cek-xray-ws.sh`, `lite/cek-xray-ws.sh`, lines 81-84) - the "cek-xray-ws" screen (WS menu option 7) reads `uplink`/`downlink` with `xray api stats --server=127.0.0.1:10080` and no `-name`, the same V2Ray-style call as `Found 99`. Both commands fail, so the screen prints the RPC error twice and then `Traffic Uplink:  connections` / `Traffic Downlink:  connections` with empty values, for a user that is connected at that moment. The label is also wrong: the counters are bytes, not connections.
- **Confirmed live:** with user `cence` present in `ws.log` from the tunnel test above, `cek-xray-ws` rendered `Traffic Uplink:  connections` and `Traffic Downlink:  connections` and printed `failed to get stats ... not found.` for each line.

Found 101. **`cek-xray-ws`'s "Total IP Login" always reads 1** (`full/cek-xray-ws.sh`, `lite/cek-xray-ws.sh`, line 53) - the counter is built as `echo "$logs" | awk '{print $1}' | sort -u | wc -l`, but every Xray access line begins with the date (`2026/09/25 14:38:38.794691 from 203.0.113.7:0 accepted ... email: cence`), so `$1` is the day and the unique count is 1 for as long as the log holds. The client address is the field after `from` (`$4`, `ip:port`). Inherited from V23 (`/tmp` reference `cek-xray-ws.sh:53` is identical); the gRPC/HTTP/split equivalents are Go programs that call `statsonline` for this number, so the shell WS tool is the odd one out.
- **Confirmed live:** with two concurrent clients (X-Forwarded-For `203.0.113.7` and `198.51.100.9`) the panel recorded `Total IP Login: 1 / 2` - and the limiter itself saw 2 (see `Found 98`), so the display disagreed with enforcement.

Found 102. **gRPC is unreachable on port 443 for dual-stack installs** (`config/dual.conf`) - the two `listen 443 ssl default_server;` lines omit `http2`, so nginx never negotiates HTTP/2 on 443 and every `grpc_pass` location fails immediately. `config/4.conf` ships `listen 443 ssl http2 reuseport;` and works; `config/dual.conf` - the file `installer/diamond.sh` fetches when the operator answers `dual`, the panel's own recommended choice - does not. Inherited from V23 (V23's `config/dual.conf` is also `listen 443 ssl default_server;`).
- **Confirmed live with a real external client** (a KVM guest on the local machine, source IP 157.15.139.236): all three gRPC combinations (`vmess-grpc`, `vless-grpc`, `trojan-grpc`) returned `http=000` on 443, while the identical links returned `200` with 1 MB transferred on 2053 - a listener that does carry `http2`. Adding `http2` to the two 443 listeners made all three pass, with no regression for the ws or httpupgrade transports.

Found 103. **SplitHTTP over TLS never completes through nginx** (`config/4.conf`, `config/6.conf`, `config/dual.conf`) - the three SplitHTTP locations (`/splitvm`, `/splitvl`, `/splittr`) set `proxy_http_version 1.1` but not `proxy_request_buffering off;` / `proxy_buffering off;`, so nginx buffers the streaming request/response pair that xhttp relies on. The transport works over plain HTTP (port 80) but the TLS form printed on every account card (`TLS: 443, 2053, ...`) hangs and times out.
- **Confirmed live:** the panel-generated `vm_split`/`vl_split`/`tr_split` TLS links all returned `http=000`, while their NoneTLS twins returned `200` with 1,000,000 bytes. With the two buffering directives added, all three TLS links return `200` (xhttp then runs over h2 because nginx streams).

Found 104. **Every `change-id-*` reports success without changing the UUID** (`full/change-id-{ws,http,grpc,split}.sh` and the `lite/` copies) - the extraction `old=$(grep "${user}" <json> | awk -F'"id": "' '{print $2}' ...)` also matches the `### <user> <date>` marker line, so `old` is multi-line and the follow-up `sed "s|\"id\": \"${old}\"|..."` aborts with `sed: -e expression #1, char 15: unterminated 's' command`. The script never checks sed's status, still rewrites the log line and prints `UUID Update Successful!`.
- **Confirmed live:** for all eight vmess/vless accounts (four transports) the JSON id was byte-identical before and after while the screen showed a fresh UUID, and the run printed the sed errors. Two further defects sit in the same block: the card-line sed matches `UUID   : ` (three spaces) while the card writes `UUID    : ` (four), and the ws/http/split variants use a single-quoted `sed 's/${old}/${new}/g'`, whose variables are never expanded.

Found 105. **Over-quota WS accounts are not deleted by the quota service** (`full/quota-ws.sh`, `lite/quota-ws.sh`) - `exp=$(grep -w "^### $user" ws.json | awk '{print $3}')` has no `| sort -u`, unlike `quota-grpc`/`quota-http`/`quota-split`, `kill-*` and `xp`. WS place each account in four inbound blocks, so `exp` becomes four identical lines and the delete `sed "/### $user $exp/ {N;d}"` fails with `unterminated address regex`; the code then still runs `rm -f "$usage_file" "$quota_file"` and restarts, so the account survives with its quota file removed - effectively unlimited - until `kill-ws` later deletes it as "Quota File Missing".
- **Confirmed live:** the sed reproduces the error directly; account `q_ws` stayed in the config (8 matching lines) with `quota=none` after quota-ws's trigger, and `/etc/xray/.quota.logs` recorded the follow-up deletion by kill-ws.

Found 106. **A failed backup deletes the only copy and reports success** (`full/backup.sh`, `lite/backup.sh`) - the `curl ... sendDocument` result is ignored, then `rm -fr /root/backup*` runs unconditionally and the script prints `Backup sent to Telegram`. With `/etc/funny/.chatid` and `/etc/funny/.keybot` absent (the state of a fresh install) or on any network failure, the archive is destroyed and nothing is delivered.
- **Confirmed live:** `backup` on the fresh host printed "Backup sent to Telegram" while `/root` held no archive at all; with the fix it keeps `/root/backup.zip` (3.6 MB, 156 files) and exits 1.

Found 107. **`trial-ssh` advertises `Limit IP: 1` but never writes the limit file** (`full/trial-ssh.sh`) - `create_ssh_user` runs `useradd` and `passwd` only and never creates `/etc/xray/limit/ip/ssh/<user>`, unlike `addssh` which does. `limit-ip-ssh` then reads an empty file, defaults the limit to **2** and writes that back, so the trial account silently allows two IPs where its own card says one.
- **Confirmed live:** the generated `trial563` had no limit file, and `limit-ip-ssh`'s fallback is `iplimit=2`.

Found 108. **`xp` silently deletes any account whose expiry date cannot be parsed** (`full/xp.sh`, `lite/xp.sh`, all six dated blocks: ws, upgrade, split, grpc, L2TP, Noobz) - each block computes `exp=$(... | cut -d ' ' -f 3)` then `d1=$(date -d "$exp" +%s)` and `exp2=$(( (d1 - d2) / 86400 ))`. When `date` cannot parse the value it prints nothing, `d1` is empty, bash's arithmetic treats it as 0, `exp2` becomes a large negative and `[[ "$exp2" -le 0 ]]` is true - so the account is removed from the config, its card/log is deleted and its quota and limit files are removed, as if it had expired. The WireGuard branch has the same failure mode differently: `[[ $exp < $now ]]` is a string comparison, so an empty expiry sorts below any date and the client is deleted.
- **Confirmed live:** an account whose `###` date was set to `99-99-99` was deleted by a single `xp` run (config 4 -> 0 markers, log gone) while a valid future-dated account survived; after the fix the bad-date account is kept with `Skipping <user>: unparseable expiry '99-99-99'` and a genuinely expired account (20-01-01) is still removed.
- **Related:** this is the most likely explanation for the unexplained disappearance of the account `vm_ws` during the campaign (see bugs-fixed.md): a corrupted date makes `xp` destroy the account and its files without writing anything to `/etc/xray/.quota.logs`, which is exactly the trace-free state that was observed.

Found 109. **Every install accepts connections with publicly-known default credentials** (`json/{ws,grpc,split,upgrade}.json`, `installer/xray.sh`) - the templates ship fixed client ids and passwords and the repository is public, while the account scripts only ADD clients - nothing ever removes the shipped defaults. `installer/xray.sh` randomises only the `rerechan-store` occurrences in `ws.json`; everything else stays as committed:
- `ws.json`: `cfbbaafc-8d52-450c-9fb0-145bc8221e6d` (vless :14016 and vmess :23456)
- `grpc.json`: `cfbbaafc-8d52-450c-9fb0-145bc8221e6d` (vless, vmess, trojan)
- `split.json`: vmess `019e0bf3-dd56-11e9-aa37-5600024c1d6a`, vless `af7d5cf8-442d-4bb3-8a76-eb367178781d`, trojan password `diy2020`
- `upgrade.json`: `nonescript-fn-project` (vmess, vless, trojan)
- **Confirmed live:** with the four templates as shipped, **11 of 12** probed combinations authenticated through nginx with nothing but the committed value (vless/vmess ws, all three gRPC, all three SplitHTTP, and vmess/vless HTTPUpgrade) and each pulled 300,000 bytes. (The twelfth row used a non-default test credential by mistake; `rerechan-store`'s own occurrences are the only ones the installer already replaced.)

Found 110. **`xp` and `quota-ws` delete accounts without leaving any audit line** (`full/xp.sh`, `full/quota-ws.sh`, both editions) - only the `kill-*` daemons write to `/etc/xray/.quota.logs`. When `xp` or `quota-ws` removes an account (config entry, card, quota and limit files) there is no record anywhere on the host of what was removed or why - which is why an account that vanished during the campaign could not be attributed (see the observation in bugs-fixed.md).
- **Confirmed live:** a fresh `xp` run that deleted an expired account left `/etc/xray/.quota.logs` byte-for-byte empty, and the same for a `quota-ws` deletion.

Found 111. **`change-id-*` leaves the saved account card's vmess links pointing at the dead UUID** (`full/change-id-*`, `lite/change-id-*`) - the card stores the vmess share links as `vmess://<base64>` blobs, and the plaintext replacement that updates the `UUID :` line and the vless/trojan links cannot reach inside base64. After a UUID change the operator copying the card's vmess link hands out a credential that no longer exists.
- **Confirmed live before the fix:** after changing an account's id, the card's decoded `vmess://` link still carried the previous UUID.

Found 112. **`cek-xray-ws` exits 1 when no account has connected** (`full/cek-xray-ws.sh`, `lite/cek-xray-ws.sh`) - the empty-log path prints `No active users found!` and `exit 1`, while the Go `cek-xray-grpc/http/split` exit 0 for the same state. It is a normal state (the log is cleared every five minutes by `kill-ws`), not an error.

Found 113. **`quota-ws` spams the journal for every idle account** (`full/quota-ws.sh`, `lite/quota-ws.sh`) - each 30-second cycle prints `Data usage for user <u> is incomplete. Skipping.` for every account with no fresh API counters, i.e. almost always for idle accounts, burying real messages.

Found 114. **`upgrade.json`'s trojan default client is declared with `id` instead of `password`** (`json/upgrade.json`, inbound :8002) - trojan inbounds read `settings.clients[].password`; an entry with only an `id` has no password and can never authenticate, so the HTTPUpgrade trojan template account is dead out of the box. The other three templates (`ws`, `grpc`, `split`) declare their trojan client as `password`; only `upgrade.json` differs. Inherited from V23.
- **Found while verifying the credential fix:** after a fresh install the randomised HTTPUpgrade-trojan credential failed (`http=000`) while a real `add-trojan-http` account on the same path returned `200`; dumping the inbound showed `{"id": "…"}` for the template client and `{"password": "…", "email": "trhu"}` for the script-added one. After renaming the field the templated credential works (`200`, 300,000 bytes).

## Observation - stale catch-all documentation and unreachable VMess-WS inbounds (September 26, 2026)

The README's "Why arbitrary paths are unstable" section states that nginx `location /` "load-balances between two backends" and lists `127.0.0.1:2080` (SSH WebSocket) and `127.0.0.1:977` (VMess WS catch-all). The shipped `config/4.conf`, `config/6.conf` and `config/dual.conf` carry only `127.0.0.1:2080` in `upstream default_backend`; the `:977` line was deliberately removed in `68c4068` ("Bug 16: Remove incompatible port 977 from nginx default_backend upstream"), so the documentation has described a two-backend balance that no longer exists. In the same area, `/etc/xray/json/ws.json` still carried three VMess-WS inbounds that no nginx location reaches: `:977` (`/`, the old catch-all) and `:96` (`/kuota-habis`, referenced by no script) were dead, while `:95` (`/worryfree`) duplicated the `:23456` inbound for the NoneTLS form of the same account (every `add-vmess-ws` writes the account into all `#vmess` inbounds). Not functional defects, but dead configuration and a stale description that made the transport paths harder to reason about. Cleaned up as part of the canonical path rename below.

## Observation - stray `/rere` entry in SlowDNS's PATH (September 26, 2026)

`installer/slowdns.sh` appends `:/rere` to root's `PATH` (`export PATH="/usr/local/go/bin:$PATH:/rere"`). `/rere` was never a directory the panel created: it existed only as the nginx location for the VMess HTTPUpgrade transport (and a `rere` binary download that was removed from `install.sh` in an earlier fix). That location is now `/vmhu`, so the PATH entry is doubly vestigial. It is harmless - appending a non-existent directory to `PATH` changes no command resolution - and was left in place because the SlowDNS installer is otherwise unrelated to the transport paths.

## Follow-up - SlowDNS `/rere` PATH entry removed (September 26, 2026)

The observation above is superseded. `installer/slowdns.sh` now appends `export PATH="/usr/local/go/bin:$PATH"`, matching the clean form the same script already uses in `install_slowdns()`, and the dead `:/rere` entry was removed from `/root/.bashrc` on the live host. No `:/rere` remains anywhere in the tree; `slowdns.sh` passes `bash -n` and shellcheck.

Found 115. **`kill-ws` deletes an over-quota account with a sed *range* that runs past its own record** (`full/kill-ws.sh`, `lite/kill-ws.sh`, over-quota branch) - `sed -i "/^### $user $exp/,/^###/d"` has no end anchor of its own: the range stops at the *next* `###` marker, or at end-of-file when the account is the last one in the file.
- **Confirmed live, last-account case:** with the target as the final marker, a single `kill-ws` run truncated `/etc/xray/json/ws.json` from 155 to 50 lines - it swallowed the closing brackets, the JSON became invalid (`unexpected EOF`) and **`xray@ws` failed to start**, taking the WebSocket transport down (restored from a snapshot).
- **Confirmed live, mid-file case:** triggering on the first of three accounts left the file syntactically valid but removed every `###` marker; the middle account's client object survived in the config while becoming invisible to `xp`, `quota-*`, `limit-ip-*`, `lock`, `delete` and `extend` (they all enumerate `^###`) - an orphaned, unmanageable account that still authenticates.
- The sibling scripts (`kill-http/split/grpc`, `limit-ip-*`, `quota-*`, `delete-*`, `xp`, `locked-*`) all use the safe `/### user exp/ {N;d}` form; only `kill-ws` carries the range. Inherited from V23.

Found 116. **`quota-http`, `quota-split` and `quota-grpc` never reload Xray after deleting an over-quota account** (`full/quota-{http,split,grpc}.sh`) - `quota-ws` ends its deletion with `systemctl restart xray@ws`, the other three never restart anything, so the deleted client stays live in the running core.
- **Confirmed live:** an HTTPUpgrade account over its quota was removed from `upgrade.json`, yet its link kept returning `200` (300 KB); it only stopped (`000`) after a manual `systemctl restart xray@upgrade`.

Found 117. **A quota deletion leaves the account card behind as a phantom "Active" account** (`full/quota-*.sh`, all four transports) - the daemon removes the client and the quota/usage files but never touches `/var/log/create/xray/<transport>/<user>.log`, and still prints/sends "has been locked".
- **Confirmed live:** after `quota-ws` deleted `t_quota`, `ws.json` had no entry and the quota files were gone, but `t_quota.log` remained; the Lock menu still listed it as `Active`, and `unlock-ws` answered "No locked accounts found" (it only lists `*.locked`), so the account cannot be restored.
- `kill-*` and `xp` both remove the card when they delete an account, so `quota-*` is the outlier; the leftover card also makes the deleted name appear in `change-quota-*` and `change-limit-ip-*`.

Found 118. **`quota-http`, `quota-split` and `quota-grpc` delete accounts without writing any audit line** - only `quota-ws` writes to `/etc/xray/.quota.logs` (fix 112 was applied to `ws` only), so an over-quota deletion on the other three transports is silent, the exact class fix 112 set out to remove.

## Observation - reference audit against V23 and Autoscript 1.20 (September 26, 2026)

Both archives were extracted and their MD5s match the values recorded in `original-source-do-not-edit/README.md` (`fdc1097ec7e10047a6d5af4c0e1cf6d5` and `a3d06894546eb982e4ab474cddbbb3c0`), so the comparison is against the intended bytes. Diffing our tree against both found three points worth recording.

**1. The `:977` catch-all backend is gone - a divergence from *both* references.** Both archives carry it in `upstream default_backend`:
- V23: `server 127.0.0.1:2080` + `server 127.0.0.1:977`
- 1.20: `server 127.0.0.1:2080` + `127.0.0.1:2081` + `server 127.0.0.1:977`
- ours: `server 127.0.0.1:2080` only

`68c4068` removed the 977 line ("Bug 16: Remove incompatible port 977") and the canonical-path change then removed the `:977` inbound, so `location /` now reaches only the SSH-WebSocket backend. It is deliberate and the README documents it, but it is a straight behavioural removal versus both upstream versions: an arbitrary-path VMess client that could connect against upstream (roughly half the time, given the load balance) can never connect now. Recorded for the owner rather than changed in either direction.

**2. `cek-xray-ws.go` (and `lite/`) is dead source.** `44c4c90` added a Go `cek-xray-ws` and built it into `menu/*.zip`; `73ace38` (the V2Ray -> Xray migration) switched the packaged entry back to the shell script `cek-xray-ws.sh` but left the `.go` in the tree. A sweep of every `full/*.go` against the shipped zip shows `cek-xray-ws` is the only one whose packaged form is not a compiled binary - the other seventeen are ELF. The README's "Go binaries" table still maps `cek-xray-ws` to `cek-xray-ws.go`.

**3. Correction to Found 117.** `auto-delete-*` already removes an orphaned card and its quota files when the user is neither in the config nor `.locked` - confirmed live by planting a card with no config entry and watching `auto-delete-ws` delete it and its quota file on the next run. So the phantom card a quota deletion left behind was transient (cleaned within the five-minute cron cycle), not permanent, and `unlock-*` refusing to list it is correct because a quota deletion is terminal. The substantive part of fix 119 is the message wording; the extra card removal only closes the up-to-five-minute window and matches what `kill-*` already did.

## Audit follow-up - decisions taken (September 26, 2026)

The three points from the reference audit were reviewed and settled:

- **`:977` catch-all (observation 1):** kept removed. `location /` is the SSH-WebSocket endpoint, so upstream's round-robin made SSH-WebSocket fail roughly half the time; deterministic routing is the better trade. Recorded as `is-decision.md` section 17 so a later reviewer does not read its absence against upstream as an accidental regression.
- **Dead `cek-xray-ws.go` (observation 2):** `full/cek-xray-ws.go` and `lite/cek-xray-ws.go` were deleted. They were V2Ray-era sources that the migration stopped building; the shipped `cek-xray-ws` is the shell script and the archives still contain it. Git history keeps the sources if a Go variant is ever wanted again.
- **Quota card removal (observation 3):** kept. Removing the card immediately closes the up-to-five-minute window `auto-delete-*` would otherwise cover, keeps the deletion complete when that GC cannot run, and matches `kill-*` and `xp`. Recorded as an addendum to `is-decision.md` section 16; the substantive part of fix 119 is the corrected wording.

### Correction to the audit follow-up

Only `full/cek-xray-ws.go` ever existed - `lite/` never carried a Go `cek-xray-ws` (its Go sources are `cek-xray-grpc/http/split.go` and the other tools). The observation's heading "(and `lite/`)" and the follow-up's "`full/cek-xray-ws.go` and `lite/cek-xray-ws.go` were deleted" were therefore both inaccurate, and the first removal attempt listed a non-existent `lite/cek-xray-ws.go`, so `git rm` aborted without deleting anything. `full/cek-xray-ws.go` is now genuinely removed; the shipped `cek-xray-ws` is unchanged in both editions - the shell script `full/cek-xray-ws.sh` / `lite/cek-xray-ws.sh`, which the archives still carry.

## Four-Repository Scan - all four repositories (September 26, 2026)

All four of the project's repositories were scanned: `fn-autosc` (the panel), `fn-autosc-auth`
(the rental authorization list), `fn-autosc-miscellaneous` (the non-forkable assets) and
`fn-autosc-api` (the restored HTTP API). Every candidate was verified live on the test VPS with the
local `/dev/kvm` guest as a real external client, or proven from the source with a concrete trigger.
The VPS was then reinstalled to Debian 12 with the upstream reinstaller and the panel reinstalled
from the repositories, and the fixes were re-verified on that clean install.

### `fn-autosc-api`

Found 119. **A missing required field did not stop a handler - the error JSON became the value**
(`fn-autosc-api/lib.sh`, every handler) - `need` was always called as `user="$(need username)"`, so
its `fail` ran inside a command-substitution subshell: the `exit` ended only the subshell, the
assignment kept the error text, and the handler carried on and ran the panel script with
`{"status":"error","message":"missing required field: username"}` as the username. The caller saw a
nested, garbled error (`the panel did not create '{"status":"error",...}'`). Confirmed live against
`/add-vmess` and `/addssh` with an empty body.

Found 120. **`core` accepts `http` but the API reported the panel's internal name `upgrade`**
(`fn-autosc-api/handlers/list-xray`, `delete-xray`) - `add-*` takes `core=http`, but `list-xray`
returned `transport:"upgrade"` and `delete-xray` `deleted_from:["upgrade"]`, and `core=upgrade` is
rejected. A caller could not feed a listed transport back into add/delete/renew. Confirmed live.

Found 121. **The API reported success without checking, and returned shell errors as success**
(`fn-autosc-api/handlers/*`) - `delete-xray` and `delete-noobz` reported a successful removal
without verifying it (unlike `add-xray`/`addssh`/`delete-ssh`); `delete-ssh` reported success for a
username that never existed; and the handlers that call SSH/Noobz tools ran them unconditionally, so
on the lite edition (which ships none of them) `list-ssh`/`cek-ssh` returned
`{"status":"success","text":"bash: /usr/bin/list-ssh: No such file or directory"}`. Confirmed by
inspection and reproduced on the VPS with the tool path removed.

Found 122. **The reference's `renew-ssh`, `renew-xray` and `password-ssh` endpoints were missing**
(`fn-autosc-api/handlers/`) - the FN-API reference README documents them and the panel ships the
tools behind them (`extend-ssh`, `extend-{ws,http,split,grpc}`, `pwd-ssh`), but the restored layer
404'd them. Confirmed against the reference README and the panel tree.

Found 123. **The server's GET handlers inherited the server's stdin** (`fn-autosc-api/server`) -
`subprocess.run(input=None)` leaves the child's stdin as the server's, so a GET handler's
`body=$(cat)` reads the server's stdin instead of seeing EOF. Under systemd that is `/dev/null` so it
works, but a manually run server blocks. The reference's 401 `WWW-Authenticate` and OPTIONS `Allow`
headers were also missing.

Found 124. **`menu-api install` reported a partial install as success** (`fn-autosc-api/menu-api`) -
the handler fetch loop used `curl ... && chmod`, so a handler that 404'd was silently skipped and the
install still printed success. This is the state the raw-CDN staleness produced during the previous
session. Confirmed by inspection.

### `fn-autosc` panel

Found 125. **`addssh` leaked the Telegram API response into the account card** (`full/addssh.sh`) -
`send_telegram_notification`'s `curl` was not silenced, unlike every sibling, so the JSON Telegram
returns (or the 404 body when no bot is configured, as on a fresh install) was printed into the
card - and therefore into the `text` field of `/api/addssh`. Observed live.

Found 126. **The WireGuard expiry cleanup could never fire** (`full/xp.sh`, `lite/xp.sh`) - the block
guards with `[[ "$exp" =~ ^[0-9]{2}-[0-9]{2}-[0-9]{2}$ ]]`, but `menu-wg.sh` writes `%Y-%m-%d`. The
regex can never match a 4-digit year, so expired WireGuard peers, their client configs and their
`.wireguard` entries were never removed. Regression introduced by fix 110's guard, which used the
Xray cards' `%y-%m-%d` shape.

Found 127. **The SSH IP limiter iterated a scalar as an array, so it was dead** (`full/limit-ip-ssh.sh`) -
`username=$(while ... done < /etc/passwd)` is a newline-separated scalar, but the loop was
`for user in "${username[@]}"`, which yields one word containing every username. No account ever
matched the " - user - " login count and nothing was ever locked. Regression introduced by fix 90's
quoting change; that fix's verification used an array literal, not the scalar the script builds.

Found 128. **The gRPC, HTTPUpgrade and SplitHTTP "Check Online Users" tools queried the WebSocket
stats API** (`full/cek-xray-{grpc,http,split}.go`, both editions) - all three passed
`--server=127.0.0.1:10080`, the WS port, instead of their own 10081/10082/10083 (which the shell
`limit-ip-*` siblings use), so menu option 7 printed no accounts for three of the four transports.

Found 129. **A WS routing change or legacy restore silently re-broke WS IP limiting**
(`full/routing-ws.sh` four blocks, `full/bmenu.sh`, both editions) - the regenerated `ws.json`
`policy.levels."0"` block omitted `statsUserOnline`, the flag Found 98 / fix 100 restored. Every
sibling routing script sets it; the WS one did not, so after a routing change the online counter was
never created again and `limit-ip-ws` stopped enforcing.

Found 130. **`cert2` truncated the live certificate when certbot failed, and `fn` left HAProxy on the
old one** (`full/dm-menu.sh`, `lite/dm-menu.sh`) - `copy_certificates` ran `cat /etc/letsencrypt/... >
/etc/xray/xray.crt`, and the shell creates/truncates the destination before reading the source, so a
failed certbot (rate limit, HTTP-01 failure) left 0-byte cert/key files and nginx failed to start.
`fn()` replaced the certificate but never rebuilt `/etc/haproxy/funny.pem`.

Found 131. **Three smaller panel defects** - `xl2tp.sh` overwrote the card's `domain=$(cat
/etc/xray/domain)` with `domain=$IP2`, a variable that exists nowhere, so the L2TP card printed a
blank Domain; `menu-system.sh`'s rocky reinstall used `clear :` instead of `clear ;`, feeding `:` to
`clear`; and the HTTPUpgrade and SplitHTTP viewers had their titles swapped.

### `fn-autosc` installer and config

Found 132. **The SlowDNS fixnet timer inserted an `INPUT` ACCEPT rule every 15 seconds, forever**
(`installer/slowdns.sh`) - the nat redirect is delete-then-insert, but the companion
`iptables -I INPUT -p udp --dport 5300 -j ACCEPT` had no delete, and the timer runs it every 15s.
The test host held **904** duplicate rules when the scan started (903 of 903 INPUT rules). Regression
introduced by fix 97's timer; the sibling `udp-request` guard gets this right.

Found 133. **`/vlspl` and `/trspl` never received the SplitHTTP timeouts** (`config/4.conf`,
`6.conf`, `dual.conf`) - `/vmspl` carries `proxy_read_timeout/send_timeout/connect_timeout/
client_body_timeout 300s`, the other two only the buffering directives, so the http-level
`client_body_timeout 12;` still governed the VLESS/Trojan SplitHTTP request body. Introduced by the
canonical path rename, which added the two locations; fix 105 had scoped itself to `/splitvm`.

Found 134. **No `client_max_body_size`, so every gRPC upload above 1 MB was rejected with 413**
(`config/4.conf`, `6.conf`, `dual.conf`) - nginx's default 1m applies to a gRPC stream's single
request body. Confirmed live: a 3 MB POST to `/vmgr` returned 413 and a 4 KB one 200.

Found 135. **Three public-IP lookups omitted `-4`** (`installer/vpn.sh`, `installer/full.sh`,
`installer/wg.sh`) - on this dual-stack host `wget -qO- icanhazip.com` returns an IPv6 literal
(confirmed: `2001:df0:27b::1:50ef`), which malformed the OpenVPN profile's `remote`, the squid ACL
and the WireGuard `Endpoint`. The project fixed this class in bug 4 and missed these three.

Found 136. **A failed permission download was reported as an expired licence** (`install.sh` and
twelve sub-installers) - `PERMISSION_DATA=$(curl -s "$URL" || { echo "Failed..."; exit 1; })` put the
`exit` inside the subshell, so the assignment kept the error text and the gate went on to print
"Your IP doesn't have on database". Confirmed live.

Found 137. **`set-br.sh` never removed its clone** (`installer/set-br.sh`) - `rm -rf wondershaper` ran
from inside `/root/wondershaper`, so the tree survived and a re-install hit an existing directory.

### `fn-autosc` website

Found 138. **The web-restore endpoint was unauthenticated root code execution** (`website/upload.php`,
`website/install.sh`) - `upload.php` accepted a `.zip` and ran `sudo /usr/bin/restore-ftp`, which
unpacks the archive over `/etc/passwd`, `/etc/shadow`, `/etc/group`, `/etc/crontab`, `/etc/xray`,
`/etc/funny` and more, with no authentication of any kind. The apache vhost serves it on
`0.0.0.0:855` and the installer enables it on every install, so anyone who could reach that port
could overwrite `/etc/shadow` and take over the host. Confirmed live from the KVM client: port 855
reachable, the form served with no credential field, and a POST processed through to the file-type
check.

### Observations from this scan

- **`fn-autosc-auth` carries no defect.** The list is data: the only accuracy note is that the first
  entry (`vm-test-debian12 157.15.139.236 2026-09-16`) has expired, which matters only if the panel
  itself is run from that test guest.
- **The authorization gate fails closed only because of its comment header.** With `LOCAL_IP` empty
  (ifconfig.me unreachable) `grep "$LOCAL_IP"` matches every `###` line; the first is the
  `# Format: ### ...` comment, whose fourth field is `<rental-label>` and does not parse as a date, so
  `REMAINING_DAYS` is negative and the gate blocks. Verified live against the real `izin.txt`. If the
  comment header is ever removed an empty `LOCAL_IP` would authorize the first entry - `install.sh`
  guards this case, the twelve sub-installers and the 180 panel scripts do not.
- **`calculate_remaining_days`\'s invalid-date branch is dead code** in every copy: `local
  expired_date=$(date ...)` makes `$?` the status of `local`, not of `date`. The caller's
  `REMAINING_DAYS < 0` check still blocks, so behaviour is unchanged.
- **`unlock-ws` has no confirmation prompt while its three siblings do** - this matches **both**
  reference archives exactly (V23 and 1.20), so it is inherited, not introduced; recorded rather than
  changed.
- **`fn-autosc-miscellaneous` assets are valid** - `acme.sh` parses, and the `cloudflared` deb, the
  `go`, `libreswan` and `vnstat` tarballs are intact. `rclone.conf` and `rclone-install.sh` are dead
  after the Google Drive backup removal (decision 11) but harmless.
- **`full/restore-ftp.sh` is dead**: the zip installs it as `/usr/bin/restore-ftp`, then
  `website/install.sh` overwrites it with the website copy, which is the one that runs.

## Second Pass on the API Layer (September 26, 2026)

Continuing the scan into areas the first pass did not reach - the API's behaviour under hostile or
concurrent input, the daemons' functional paths, `change-id`, the backup/restore pair and the raw
assets - found two more defects, both in `fn-autosc-api`.

Found 139. **A caller-supplied name was used as a regular expression** (`fn-autosc-api/handlers/delete-xray`,
`renew-xray`, `add-xray`, `add/delete-noobz`) - the handlers test membership with
`grep -qE "^### ${user}( |$)"`, interpolating the name unescaped. `add-*` validates the name first,
but `delete-xray` and `renew-xray` do not, so the name was an ERE.
- **Confirmed live:** `DELETE /delete-xray {"username":"a.b"}` matched (and removed) the unrelated
  account `axb` while reporting `deleted_from:["ws"]` for a name that never existed, and
  `{"username":".*"}` deleted **every account of the transport**. `renew-xray` had the same match.
- The NoobzVPN handlers had the weaker form of it (`grep -q "$user"`).
- Secondary effect, also confirmed: because the config entry is removed under the regex name while
  the delete script looks for the literal name, the account's card, quota file and limit file are
  left behind - and their survival then **blocks re-creating that username** ("exists in log file").

Found 140. **Concurrent requests ran the panel's scripts in parallel** (`fn-autosc-api/server`) -
the reference is a single-threaded `HTTPServer`, which serialised everything. The restored server
used `ThreadingHTTPServer`, so two requests could run two panel scripts at once - and those scripts
rewrite whole shared files (`json/*.json`, `/etc/passwd`, the service units) with no locking.
- **Confirmed live:** twelve concurrent `/add-vmess` calls returned eight successes and four errors,
  and only **8 of the 12** accounts existed afterwards (`xray -test` still passed, so the config was
  not corrupted - the edits were simply lost). A threading change was described as hardening in the
  last session; it was a correctness regression.

### Fix 136 revision - the request-body cap was lifted too widely

The same review caught a defect in this session's own fix 136. Setting `client_max_body_size 0` in
the `http` block removed nginx's 1 MB request-body bound from **every** location, including the
WebSocket, HTTPUpgrade and `/` locations, which do not set `proxy_request_buffering off` and
therefore buffer the body to disk - turning the fix into a disk-fill DoS on the public listener. It
is now set only on the locations that carry the tunnel as a request body and stream it (the three
gRPC locations, which also gain `proxy_request_buffering off`, and the three SplitHTTP locations).
Verified live: a 3 MB POST to `/vmws` is back to `413`, a 3 MB POST to `/vmgr` is not, and a real
3 MB gRPC tunnel upload still completes.

### Checked in the second pass and found clean

- **`xp` for Xray** (the block whose WireGuard sibling fix 128 changed): an expired `ws` account and
  an expired `grpc` account were both removed with `xp: deleted <user> (expiry 20-01-01)` audit lines
  and a future-dated account survived.
- **`change-id-ws`** (fixes 104/111): the config id, the card's `UUID` line and **both** base64
  `vmess://` links all moved to the new UUID together; the config stayed valid.
- **create -> delete -> recreate** on ws/http/split/grpc and vless/ws leaves no card, quota or limit
  file behind, so a deleted name can be created again.
- **Cron and services** on the fresh install: `/etc/crontab` carries all 16 panel lines with every
  command resolving, cron ran 88 commands in 30 minutes with no failures, no systemd unit failed,
  and `opn`, `squid`, `fn-ohp`, `dnstt` and `haproxy` are all active. `backup` and `xp` are
  scheduled (an earlier look was misled by output truncation).
- **Backup and restore are symmetric:** `backup.sh` archives exactly the set `restore-ftp.sh` copies
  back, and the restore's `cp -r xray /etc/` merges into the existing directory (it does not nest).
- **`config/squid.conf` and `config/format.sh`** exist and are served (200); the squid ACL placeholder
  `rerechan` is substituted with the host's IPv4 at install.
- **Risky-pattern sweeps** found nothing: no unquoted `rm -rf $var`, no truncating redirect to a
  system file, no `eval`, and the only `curl | bash` is the standard NodeSource setup in
  `installer/package.sh`.
- **Log rotation**: `logrotate.timer` is active and `/etc/logrotate.d` covers the xray/nginx logs;
  the panel's `kill-*` daemons truncate `ws.log` every five minutes anyway, so the transport logs do
  not grow without bound.

### Noted, not defects

- `other/fnohp` is a **32-bit i386** Go binary while `other/fn.ohp` is 64-bit; only `fnohp` is used,
  and `fn.ohp` is downloaded to `/etc/fn.ohp` and never referenced. It runs on this host (i386
  emulation) but is a portability smell rather than a defect.
- `other/dinda` is a Python script with CRLF line endings; it is run as `python3 -O <file>`, so the
  endings are harmless.
- `website/restore-ftp.sh` restarts `ssh`, the four `xray@*` units, `nginx` and `cron` but not
  `haproxy`, `dropbear` or the `quota-*` daemons; all of those run independently, so nothing is left
  in a broken state.

## Third Pass - Quota Enforcement, SSH Ports and the Cards (September 26, 2026)

### Quota, and the client `level` Xray needs to count it

Found 141. **Per-account quota enforcement was dead on every transport: the panel's clients
carried no `level`** (`full/add-*.sh`, `full/trial-*.sh`, `full/unlock-*.sh` and the `lite/` copies,
56 scripts) - the quota daemons read the per-user traffic counters
`user>>><email>>>traffic>>>uplink/downlink` with `xray api statsquery` and parse them with
`grep value`. On the pinned Xray 25.3.6, a client written as
`{"id": "..","alterid": 0,"email": ".."}` produces **no traffic counters at all** - only the
`>>>online` counter, which does not need a level, so the feature looked alive. The extraction
therefore returned nothing, the daemon `continue`d for every account, no `<user>_usage` file was ever
accumulated, and an over-quota account was **never** deleted.

- **Confirmed live, both directions, on the current install.** A vmess-ws account created by the
  panel and driven with 1,000,000 bytes of real traffic had **no** `user>>>qfix>>>traffic>>>`
  counters (`xray api statsquery` listed only the `api` and `blocked` counters) and `quota-ws` left
  it alone. Adding `"level": 0` to that one client and restarting made both counters appear; the
  daemon then accumulated `usage 1001442 > quota 300000` and deleted the account, removed its card
  and quota files, wrote `quota-ws: deleted qfix ...` and restarted `xray@ws`.
- **Repeated from a clean account with the fixed add script, no hand editing:** the account's client
  literal carried `"level": 0`, the counters appeared, and watched every 15 s the daemon deleted it
  by **t=30 s** (markers 1 -> 0, audit line written, counters cleared by the restart).
- **The sibling transports are the same code** - `add-*-{http,split,grpc}` write the identical
  client shape, and the fix carries each new account's `"level": 0` in `upgrade.json`, `split.json`
  and `grpc.json` as well.
- **Discrepancy to flag:** the fix-101 verification in `bugs-fixed.md` records
  `/etc/xray/quota/ws/bugtest_usage = 46973216` and an accumulator that rose by 8,519,875 bytes for an
  8,000,000-byte transfer - i.e. it observed the counters working. That was also on pinned Xray
  25.3.6. Either that account was written with a level by the test harness rather than by the panel's
  own add script, or the behaviour differs in a way this pass did not reproduce. The A/B above is
  reproducible on the shipped code and is what the fix is based on; the earlier note should not be
  read as proof that the panel's clients were being counted.

Found 142. **The installer closed SSH port 22 while everything else assumes it stays open**
(`installer/ssh.sh`) - the script appended `Port 3303` to `sshd_config`, and because sshd listens
**only** on the ports named by active `Port` directives and Debian ships the default as a commented
`#Port 22`, that *closed* 22. Whether it did depended on the base image (a netboot image leaves it
commented, an older cloud image left it active), and the cloud image the panel's own reinstaller now
fetches leaves it commented - confirmed on the fresh install (`#Port 22`, `Port 3303`, only 3303
listening). Three things depend on 22 being open:
- the SSH and trial cards (`OpenSSH : 22, 3303`) and the README's port table;
- **dnstt's forward target**: `ExecStart=/etc/slowdns/dns-server ... 127.0.0.1:22`, so with nothing
  on 22 the SlowDNS SSH-over-DNS tunnel accepts the DNS query and then fails to reach SSH - the
  SlowDNS feature was broken, not just mislabelled;
- the operator's own access: install over port 22 and the port they connected on is gone afterwards,
  while the documentation still advertises it.

Found 143. **The Stunnel5/HAProxy card advertised port 443** (`full/addssh.sh`, `full/trial-ssh.sh`) -
443 is nginx (the Xray TLS listener); the HAProxy TLS frontend binds **777**, which is what actually
answers with `SSH-2.0-dropbear` after its TLS handshake (verified with `openssl s_client`). A client
following the card's `STUNNEL5 : 443` never reaches SSH. Inherited from V23, which had the same
`bind *:777` / card-443 mismatch; the 1.20 reference dropped the line instead.

### Observations from the third pass

- **A `quota-*` deletion leaves the account's limit file behind.** After the over-quota deletion,
  `/etc/xray/limit/ip/xray/ws/<user>` was still present (the card, quota and usage files are removed).
  It is harmless - the add scripts overwrite the limit file for a reused name and `auto-delete-*`
  does not read it - but it is inconsistent with `delete-*`, which removes it.
- **Up to one 30-second interval of usage is lost if `xray@<transport>` restarts between a transfer
  and the daemon's read**, because the counters are in memory and the usage file only accumulates
  what a cycle has already read. It under-charges, never over-charges.
- **`other/fnohp` is 32-bit i386** and the unused `other/fn.ohp` is 64-bit; `other/dinda` has CRLF
  endings (harmless, it runs as `python3 -O <file>`).

### Source-grounded attributions for Found 130, 141 and 142 (September 26, 2026)

Reading both archives settles where these came from:

- **Found 130 (the certificate copy) is self-inflicted, not inherited.** The references' `cert2`
  stage copies the pair with `cp`; their acme stage appends with `>>`. Our tree's `cat … > …` form
  was introduced by commit `873e529` (bugs 52-61) - a "fix" that traded the references'
  append-duplication for truncate-on-failure. Fix 143 restores the references' `cp` (guarded).
- **Found 141 (`level`) is shared with both references.** Neither archive writes a `level`
  anywhere. The defect is inherited; the fix is a divergence that the pinned Xray makes necessary.
- **Found 142 (SSH port 22) is shared with both references.** Both append `Port 3303`, neither keeps
  22 explicitly, and both point dnstt at `127.0.0.1:22` and print `OpenSSH : 22, 3303` on every card.
  The panel has always assumed 22 stays open; the fix makes it so.
- **Found 130's `STUNNEL5` sibling (Found 143):** the 443 mismatch is V23's (which also binds 777);
  1.20 dropped the line entirely, and its card has no `STUNNEL5` row.

## Fourth Pass - Reference-Driven (September 26, 2026)

Both archives were re-read again, this time diffing our tree against them field by field (cards,
nginx locations/directives, daemon logic, menus, Go tools, installer package lists) and checking each
difference's provenance. Two defects surfaced that our tree carries and the references do not, in the
"the reference is a better baseline" sense.

Found 144. **The SSH and trial cards under-report OpenVPN** (`full/addssh.sh`, `full/trial-ssh.sh`) -
they print `OVPN TCP : 1194` and `Config OVPN : .../tcp.ovpn`, while the panel installs and runs
**two** OpenVPN servers and publishes a combined archive.
- Both references' `vpn.sh` create the TCP 1194 *and* UDP 2200 servers; ours does too - confirmed
  live: `openvpn-server@server-tcp-1194` and `openvpn-server@server-udp-2200` both `active`, and
  `2200/udp` is listening.
- Both create `/var/www/html/openvpn.zip` containing `client-tcp-1194.ovpn` and
  `client-udp-2200.ovpn`; both `/web/tcp.ovpn` and `/web/openvpn.zip` return 200.
- **1.20's card already says `OVPN TCP/UDP: 1194 / 2200` and points at `openvpn.zip`** (both in
  `addssh.sh` and `trial-ssh.sh`); **V23's card has the same omission ours does.** Ours inherited
  V23's line, so a client following the card never learns about the UDP server and is given only the
  TCP profile.
- The `NoneTLS` list difference in the same cards (`…, 2086, 2095` in 1.20 vs `…, 2095` here) is
  **not** a defect: V23 and ours serve the OpenVPN-WebSocket with `dinda` on 2086 and nginx does not
  bind it, while 1.20 dropped dinda and put 2086 back in nginx. Both are self-consistent.

Found 145. **`menu-bot` cannot install its bot: the tree runs Node 20, the bot needs Node 16**
(`installer/package.sh`) - commit `74b4c6b` ("... Node 16 EOL ...") changed
`deb.nodesource.com/setup_16.x` to `setup_20.x`.
- The bot `menu-bot` unpacks from `bot.zip` pins `node-pty ^0.9.0` and `node-termios 0.0.13` - native
  addons from the Node 16 era.
- **Confirmed live:** with the installed Node 20, `npm install` in the unpacked bot fails at
  `node-pty` (`src/unix/pty.cc`, `NODE_MODULE(pty, init)`, `make ... Error 1`), `node_modules` is
  left empty and `node server.js` dies on a missing module - so `menu-bot`'s install produces a
  `bot.service` that cannot start.
- **Confirmed live the other way:** with a portable Node 16.20.2, `npm install` reports
  `added 29 packages`, both `node-pty` and `node-termios` build, and the bot starts ("Couldn't load
  the configuration file, starting the wizard.").
- **Both reference archives install Node 16** (`setup_16.x`) for exactly this reason, and
  `setup_16.x` is still served (200). `node-termios` has no release newer than 0.0.13, so the bot
  cannot be moved to Node 20 without patching the third-party bundle first.
- The README advertises the Telegram bot (`menu-bot`) as a supported feature, so this is a broken
  advertised feature, not a cosmetic one.

### Where the source says our tree is right and a reference is wrong

- **`apt install python` cannot succeed on Debian 12** - the `python` package does not exist
  (`apt-cache policy python` -> Candidate: none). Both references' `package.sh` list `python` on the
  same `apt install` line as `jq`, `certbot`, `fail2ban` and the rest, so that whole line aborts and
  none of those packages install. Ours says `python3`, which is why our fresh installs populate.
- **The SSH limit path:** both references clean `/etc/funny/limit/ssh/ip/` in `xp.sh`, a directory
  nothing creates, while writing and reading `/etc/xray/limit/ip/ssh/`. Ours uses that one path
  everywhere (`addssh`, `trial-ssh`, `limit-ip-ssh`, `cek-login-ssh`, `delete-ssh`, `limit-ip.go`,
  `xp`), so an expired SSH account's limit file is actually removed.
- **1.20 regressed parts of the daemons that V23 had right:** its `quota-*` no longer restarts the
  Xray instance after deleting an over-quota account (V23 restarted `v2ray`), its `xp` removes quota
  files with the `$user*` glob that a later audit reverted here, and its `auto-delete-*` removes only
  the quota file and leaves `<user>_usage` behind. Ours keeps the exact-pair paths and the restart.

## Fifth Pass - Account Management, Cron, Time/Date, Limits (September 26, 2026)

A dedicated pass over the areas named - account management, cron, time/date, the limiter, quota /
GB bandwidth, IP limit, trial IP limit and SSH account management - diffing our tree against both
archives token by token (paths, units, services, operators) and exercising the flows live. **No new
defect was confirmed in our tree.** The pass did establish, with the source as evidence, where ours
is right and a reference is wrong, and it recorded one latent risk that could not be reproduced.

### Reference defects our tree already fixes (each verified against both archives)

| Area | The references | Ours |
| :-- | :-- | :-- |
| HTTPUpgrade service name | `auto-delete-http` / `change-quota-http` / `extend-http` / `locked-xray-http` restart **`xray@http`**, a unit nothing ever creates - the installer enables `xray@upgrade`, so those restarts never happen | restarts `xray@upgrade` (the enabled unit) |
| Node package | both list `python` on the `apt install` line; there is no `python` package on Debian 12 (`Candidate: none`), so the whole line - `jq`, `certbot`, `fail2ban` and the rest - aborts | `python3` |
| SplitHTTP delete | `delete-split` removes `/etc/xray/quota/**ws**/$user` - a different transport's file - and leaves the split account's own quota files, so a deleted split account is orphaned and a same-named WS account loses its quota | `/etc/xray/quota/split/` plus `${user}_usage` |
| SSH IP-limit state | `xp` cleans `/etc/funny/limit/ssh/ip/`, a directory nothing creates, while the limit lives in `/etc/xray/limit/ip/ssh/`, so an expired SSH account's limit file survives | one path throughout |
| WireGuard expiry | `xp` guards on `^[0-9]{2}-[0-9]{2}-[0-9]{2}$` while `menu-wg` writes `%Y-%m-%d`, so the WG cleanup never fires (Found 126) | the 4-digit shape `menu-wg` actually writes |
| Noobz state | mix `/etc/noobzvpns/.noob`, `.chatid`, `.keybot` **and** `/etc/funny/…` | one set under `/etc/funny` |
| restore-ftp | `systemctl **resrart** xray@split` (a typo, so the restart never runs) | the correct verb |

### Verified correct in our tree, live on the fresh install

- **Trial** (vmess-ws): created `trial051`, config date `26-09-27`, card present, limit file `1`,
  quota file `1073741824` (1 GB in bytes), and an `at` job 60 minutes out; `atd` is active.
- **All twelve trial scripts** write both the IP-limit and quota files (same as 1.20), and
  `trial-ssh` writes the limit file its card advertises (Found 107's fix).
- **Trial count in the card vs the file**: `Limit IP: 1` and the file `1`.
- **SSH IP limiter, end to end**: with `Limit IP 1` and two distinct logins, it locked the account
  (`passwd -S` -> `L`) and scheduled the 15-minute auto-unlock. `passwd -l` prefixes the shadow hash
  with `!` and leaves the password intact - confirmed by comparing the hash before and after.
- **Xray unlock**: after simulating the limiter's lock (client removed, card renamed `.locked`),
  `unlock-ws` restored the client **with `"level": 0`**, renamed the card back and left the limit and
  quota files untouched, config valid.
- **Units and operators**: `quota-*` all trigger on `-gt` and `kill-*` all on `-ge` (matching 1.20),
  with the per-transport quota paths correct in every daemon.
- **Time/date**: the expiry format matches between writer and reader on both families; the SSH
  expiry is enforced by the OS at local midnight and the Xray one by `xp`, so the UTC-vs-local
  arithmetic difference is not customer-visible.
- **Cron**: `/etc/crontab` carries the full panel block; `atd` active; `kill-*`/`quota-*` conditions
  consistent.

### Observation - the cron daemons share files but not a lock (unreproduced)

`xp` (minutes 0/15/30/45) and the `*/5` daemons (`kill-*`, `limit-ip-*`, `auto-delete-*`) start at
the same minute and each `sed -i`s the same `json/*.json`; each holds only its **own** `flock`, so
two different daemons can read-modify-write the same file concurrently. That is the same class as
Found 140 (the API's threaded handlers) - but unlike that one it did **not** reproduce: ten iterations
with an expired account (for `xp`) and an over-quota account (for `kill-ws`) ran concurrently and no
edit was ever lost, because each daemon's edit window is a single fast `sed`, not a multi-second
script. Recorded as a latent risk rather than a confirmed defect, since the audit's rule is to
demonstrate before claiming.

## Sixth Pass - The Panel's UDP Capture Swallows Its Own UDP VPNs (September 26, 2026)

Found 146. **`udp-request`'s wildcard capture hijacks the handshakes of the panel's own UDP
services, so WireGuard and OpenVPN-UDP are dead** (`installer/request.sh`, `installer/udp.sh`) -
`udp-request` runs with `-mode=system` and inserts, at the top of nat `PREROUTING`, captures for
**every** UDP port:

```text
-A PREROUTING -i ens3 -p udp --dport 8990:65535 -j REDIRECT --to-ports 8989
-A PREROUTING -i ens3 -p udp --dport 1:8988    -j REDIRECT --to-ports 8989
-A PREROUTING -i ens3 -p udp --dport 1:65535   -j DNAT --to-destination :36711
```

iptables is first-match, so every inbound UDP packet that is not port 53 (which `slowdns` re-asserts
above the captures) is taken before it reaches its service. That includes the panel's own
`WireGuard` (51820), `OpenVPN UDP` (2200), `IPsec/IKE` (500, 4500) and `L2TP` (1701).

- **Confirmed live, WireGuard A/B.** A client created by `menu-wg` (config `Endpoint =
  202.155.17.126:51820`, peer registered on `wg0`) came up with **no handshake**: the server peer's
  `wg show` transfer stayed `0 0` while the wildcard rule's counter rose by 28 packets - the
  handshake was landing on the capture. `UdpInDatagrams` also rose, so the packets do reach the host;
  they are simply redirected. With `RETURN` rules for udp dport 51820/2200 inserted above the
  captures the tunnel came up immediately: ping to `10.66.66.1` **0% loss**, ping `1.1.1.1` **0%
  loss**, egress `202.155.17.126`.
- **Confirmed live, OpenVPN UDP.** `openvpn --config udp.ovpn` (the profile the card advertises,
  `remote 202.155.17.126 2200`) brought up `tun0 10.7.0.6` and routed the client's traffic through
  the VPS (`ifconfig.me` -> `202.155.17.126`).
- **Inherited from both references:** neither archive reserves any of those ports above the capture
  (`grep -rhoE 'dport (51820|2200|500|4500|1701)'` finds nothing in V23 or 1.20 either). This is the
  same shape as Found 97 - the SlowDNS UDP-53 redirect shadowed by the same capture - but fix 97
  protected **only port 53**, so the other UDP services stayed broken.
- **Tightened after the first attempt:** the re-asserting timer kept the default
  `AccuracySec=1min`, which left the services captured for up to a minute after a `udp-request`
  restart; `AccuracySec=1s` brings the restoration to 15 s (measured).

## Seventh Pass - The Lite Edition on a Fresh OS (September 26, 2026)

The OS was reinstalled and **lite** installed from the repositories to exercise the edition that had
only ever been read, not run. Two defects, one of them a failed service on every lite install.

Found 147. **`dropbear.service` fails on every lite install** (`installer/lite.sh`) - `package.sh`
installs the `dropbear` package and Debian enables and starts it on its default port 22, but the
script that moves dropbear onto ports 109/111 is `installer/ssh.sh`, and **`lite.sh` never runs it**
(it installs only package/xray/diamond/website, matching both references). sshd already owns 22, so
dropbear cannot bind.
- **Confirmed live on the fresh lite install:** `systemctl --failed` -> `dropbear.service loaded
  failed`, and its journal `Failed listening on '22': Error listening: Address already in use` /
  `Early exit: No listening ports available.` / `Start request repeated too quickly.`
- **Inherited:** both reference `lite.sh` files are the same - package/xray/diamond/website, no
  ssh.sh - so their lite editions ship a failing dropbear too.
- Lite genuinely has no SSH tooling (no `addssh`, `delete-ssh`, `list-ssh`, `extend-ssh`, `pwd-ssh`,
  `limit-ip-ssh`, `expire-ssh`, no `menu-ssh` option), so the service is not merely misconfigured,
  it is unused.

Found 148. **The README's "Variants - Full vs Lite" table over-states lite** (`README.md`) - it marks
`SSH / Dropbear / SSH WebSocket` as `✅ | ✅`, but lite installs none of them, and (separately) still
said `Node.js 20` after fix 147 moved the tree back to Node 16. The other rows match the lite
installer's step list; the lite transport matrix was verified separately (below).

### Verified on the lite install

- **Transports (KVM client, real traffic):** 4/4 - vmess ws 200/1,000,000; vmess grpc 200/1,000,000
  plus a **3 MB upload** 200 (fix 136's body-size cap holds in lite too); vless sandbox
  splithttp 200/1,000,000; trojan httpupgrade 200/1,000,000.
- **The API's lite behaviour (fix 123):** `add-vmess` succeeded, and the full-only endpoints returned
  a clean `this panel edition does not ship '<tool>'` - `addssh`, `list-ssh`, `cek-ssh` (for
  `cek-login-ssh`) and `add-noobz` (for `noobzvpns`) - instead of the shell error once reported as
  success. `ping`, `list-xray`, `delete-xray` and the designed `add-ss` error all behaved.
- **Crontab:** 20 non-comment lines with **no** `expire-ssh`/`limit-ip-ssh` lines (fix 95 holding on
  a real lite install).
- **Units:** nginx + all four `xray@*` + all four `quota-*` active, `xray -test` OK on all four
  configs, `nginx -t` OK; the only failure was dropbear, above.
- Lite does not install SlowDNS/UDP/Noobz/WireGuard/OpenVPN/OHP - by design, matching both
  references' `lite.sh`; the README table already marks those rows `❌`.

## Eighth Pass - The Still-Untested Services (September 27, 2026)

This pass drove the services that had never been exercised: SlowDNS/dnstt, NoobzVPN, the dinda
OVPN-WS proxy, BadVPN udpgw, Cloudflare WARP, and a first end-to-end L2TP/IPsec attempt. Two
defects, both inherited and both live-verified.

Found 149. **Cloudflare WARP could never be installed on a full install** (`full/menu-system.sh`,
`lite/menu-system.sh`) - `menu-warp`'s `install()` aborted at a guard testing
`/etc/wireguard/params`, and that file is written by `installer/wg.sh`. Every full install therefore
prints `WireGuard sudah diinstal.` and exits the whole system menu before any WARP code runs.
- **Confirmed live:** `menu-system` -> 3 (WARP) -> 1 (Install) printed that message and the menu
  script exited, with `/etc/wireguard/params` present because wg.sh always writes it.
- **Inherited:** both references' `Full/menu-system.sh` and `Lite/menu-system.sh` carry the same
  guard, and both references' `full.sh` also run wg.sh, so their WARP menu is dead on a full install
  too. WARP is a separate WireGuard interface (`wgcf`), so the guard tests the wrong thing; the
  correct "already installed" check already exists a few lines below (`/usr/bin/warp.sh`).
- The lite copy also ran `chmod /usr/bin/warp.sh` (no mode), so `warp.sh` was left non-executable and
  the WARP submenu's status/restart/account entries would fail; the full copy already had `chmod +x`.

Found 150. **L2TP/IPsec cannot negotiate on Debian and Ubuntu** (`installer/l2tp.sh`) - the script
installs **strongSwan** (`apt install strongswan`) but writes a **libreswan** `ipsec.conf`
(`protostack=netkey`, `interfaces=%defaultroute`, `ikev2=never`, `ike=...;modp1024`,
`phase2alg=...`). On the live host strongSwan 5.9.8's starter logged `unknown keyword 'ikev2'` and
`skipped invalid proposal string: aes256-sha2`, so the connection loaded with **no valid IKE
proposal** and every client was answered with `NO_PROPOSAL_CHOSEN`.
- **Confirmed live, A/B:** before the fix a client's `ipsec up` returned `received NO_PROPOSAL_CHOSEN`
  / `establishing connection 'L2TP-PSK' failed`; after re-writing the three lines in strongSwan
  syntax the same client negotiated `selected proposal: ESP:AES_CBC_128/HMAC_SHA1_96` and the
  server's xl2tpd logged `Call established with ...`.
- **Inherited:** both references' `installer/l2tp.sh` have the same strongswan-install /
  libreswan-config mismatch. Only CentOS builds libreswan, where the template is correct.
- The full PPP leg could not be finished in the test guest (its Debian cloud kernel ships no `ppp`
  modules), but IPsec/IKE/ESP and the L2TP control connection - exactly what the defect broke - both
  succeed after the fix.

### Verified working, or explained (no new defect)

- **SlowDNS / dnstt - works end to end.** `dnstt-client -udp <vps>:53` over the `slowdns-fixnet`
  UDP 53 -> 5300 redirect carried a real SSH session (`TUNNEL_OK`, root@localhost).
- **NoobzVPN - transports work, no Linux client.** Server 3.3.1-b answers the configured
  `HTTP/1.1 101 Switching Protocols` on 8080 (plain) and 8443 (TLS 1.3), both reachable from
  outside; the menu's create and delete paths drive `noobzvpns add --password/--expired` and
  `noobzvpns remove` correctly and update `/etc/funny/.noob`. The client protocol is proprietary to
  the Android app, so no tunnel was driven.
- **dinda (OVPN-WS :2086) - service works, port blocked upstream.** From loopback it answers
  `HTTP/1.1 101 Switching Protocols` for `X-Real-Host: 127.0.0.1:22` and `127.0.0.1:1194` and
  `403 Forbidden!` for a foreign host. From outside, 2086 (and 2082/2095/2096, which nginx serves as
  the other NonTLS ports) never reach the VPS: `tcpdump -ni ens3` captured **0 packets** during
  probes from several continents, so the filtering is upstream of the host. The port choices are
  identical to both references; nothing in the repository can change a provider firewall.
- **BadVPN udpgw - works.** Relaying a datagram to a loopback echo through `127.0.0.1:7300`
  returned the echoed payload once the client framed packets the way badvpn does (PacketProto, a
  *little-endian* two-byte length prefix). The loopback bind is what the badvpn documentation itself
  prescribes (`--listen-addr 127.0.0.1:7300`, reached through the SSH tunnel).
- **WARP runtime after the fix** - `warp.sh wgd` brought `wgcf` up with the default route left on
  ens3 (its `from <server-ip> lookup main` rule protects the SSH path). Note that the same install
  path adds the Debian **unstable** repository and runs `apt install linux-headers-$(uname -r)`,
  which pulled a new kernel and a large dependency set; that is inherited behaviour, recorded here,
  and the test host was cleaned back up (WARP removed, unstable repo deleted, extra kernel purged).

## Ninth Pass - The Xray IP Limit (September 27, 2026)

Asked to verify that the per-account "limit IP" works for vmess/vless/trojan with the client
connecting through Cloudflare (a Cloudflare edge IP, SNI/host = the panel domain).

### The limit itself works

With an account at `Limit IP: 1` and two concurrent clients from two different real addresses
(157.15.139.236 through Cloudflare and 202.155.17.126), `xray api statsonline` reported
`value: 2`, and running the limiter exactly as cron does
(`flock -n /tmp/limit-ip-ws.lock limit-ip-ws`) removed the account from `ws.json` and moved its card
to `.locked`. Xray's access log showed the real client address (`from 157.15.139.236:0 accepted ...
email: ipl_vm`), so behind Cloudflare the panel still sees the true client. The count is
concurrent-IP based - a client that goes idle stops counting - which matches the "multilogin"
intent.

Found 151. **The Xray IP limit trusted a client-supplied `X-Forwarded-For`** (`config/4.conf`,
`config/6.conf`, `config/dual.conf`) - the Xray-serving nginx locations forwarded
`X-Forwarded-For $proxy_add_x_forwarded_for`, which keeps whatever the client sent and appends
nginx's peer, and Xray (vmess/vless/trojan over ws/grpc/splithttp/httpupgrade) takes the first entry
as the client address. A client could therefore choose the address that the "online" statistic -
the number `limit-ip-*.sh` enforces - is counted against.
- **Confirmed live** through Cloudflare (client -> 104.17.2.81, SNI/host autosc.rohcuan.dpdns.org):
  a vmess client that sent `X-Forwarded-For: 9.9.9.9` was recorded by Xray as
  `from 9.9.9.9:0 accepted tcp:ifconfig.me:443 email: ipl_sp`, and `statsonline` counted it, while
  nginx's own access log (which uses the trusted `$clientRealIp` map) still showed the real client
  157.15.139.236 and the Cloudflare edge separately. That defeats the device limit: one person can
  run many devices against one account, all sending the same forged address, and the count never
  reaches the limit.
- **Inherited:** both references ship the same `map $http_x_forwarded_for $clientRealIp` and the
  same `$proxy_add_x_forwarded_for` proxy headers; only the log format used the trusted value.

## Closure of Earlier Recordings (September 27, 2026)

The owner asked for everything still open in this file to be fixed, and for the recorded
regression/strictness/over-engineering items outside `is-decision.md` to be fixed too. Both archives
were re-verified first (MD5/SHA match `original-source-do-not-edit/README.md`).

- **The `rohjagad/FN-API/main/bot.zip` fetch contradicted decision 18** ("nothing fetches or
  modifies FN-API"). `full/menu-bot.sh` and `lite/menu-bot.sh` did exactly that. The bundle is now
  vendored in this repository as `other/bot.zip` (24,845 bytes, sha256 `a0bc5bf758abd5df9b1ba8847cb6e5d8a085568af2b76d96a46ceb69ca9393c3`) and both menus fetch
  it from `.../fn-autosc/main/other/bot.zip`; the menu archives were updated in place (only the
  `menu-bot` member changed, +166 bytes, every other member byte-identical). Fix 155.
- **The stale Fastly hosts entry in `installer/v2ray.sh`** ("still reachable, not changed") is moot:
  that script no longer exists - it went with the remaining V2Ray residue - so the entry is gone.
- **The "dead" `restore-ftp.sh`** is not dead and needs no change: the live `/usr/bin/restore-ftp`
  is the 1978-byte `website/restore-ftp.sh` installed by `website/install.sh`, and the 3345-byte
  `full/restore-ftp.sh` / `lite/restore-ftp.sh` in the menu archives are the fallback for when that
  fetch fails. Kept; the earlier "dead" wording was imprecise and is corrected here.
- **The empty `rclone.conf` (early finding 21) and `rclone-install.sh`** were removed from
  `rohjagad/fn-autosc-miscellaneous` (misc `4dd9424`): decision 11 says the committed rclone remote
  must not survive, and the panel references rclone nowhere. Fix 159.
- **`calculate_remaining_days`'s invalid-date branch is dead in every copy** (`local x=$(date ...)`
  captures the status of `local`). Confirmed harmless - the caller's `REMAINING_DAYS < 0` check still
  refuses - and left as is: repairing it across ~190 copies would be churn for no behavioural change.
- **`unlock-ws` has no confirmation** while its siblings do; this matches both references exactly and
  is left under decision 21. **The licence gate's empty-`LOCAL_IP` case** still fails closed through
  the `# Format:` comment; decision 21 already covers not adding the guard to ~190 files.
- **The README's arbitrary-paths section** already describes the single SSH-WebSocket backend (no
  `:977` mention remains), so there was nothing to close.
- **The menus define `output()` but never call it** while the installers do (both references call it
  in the menus). Recorded as a divergence, not changed: it only omits the licence banner, the gate
  itself still runs, and inserting the call into every menu is cosmetic churn.
- **My own shipped Cloudflare list from fix 154 had a wrong CIDR** - `2c0f:f248::/29` where Cloudflare
  publishes `2c0f:f248::/32`. A /29 trusts addresses Cloudflare does not own. The three configs are
  re-synced to Cloudflare's exact published lists and a refresher now keeps them current. Fixes 156/157.

## Eleventh Pass - Thorough Sweep of Every File (September 27, 2026)

Both archives re-verified (MD5/SHA match the README). Two independent reads covered every shell
script in `full/` and `lite/` plus `install.sh`, `installer/`, `fix/`, `website/`, `config/`,
`json/`, `other/` and `udp/`; every candidate below was then driven live on the test VPS or checked
against the running services before it was recorded. Ten defects, all fixed; the inherited ones are
noted, and the source was checked first each time.

Found 152. **`list-xray-*` showed other accounts and an empty credential** (`full/list-xray-{ws,http,split,grpc}.sh`, and `lite/`) - the extraction was `grep "${user}" ... | awk -F'"id": "' ...`, an **unanchored** grep over the whole config, so listing `bob` also matched `bobby`'s marker and client, and only `"id"` was read, so a **trojan** account (which stores `"password"`) printed nothing.
- **Confirmed live:** listing `lbob` showed `lbob` *and* `lbobby`, and the credential field came out empty; a trojan account's real `"password"` was never printed.
- **Inherited:** both references have the same line (V23's reads `/etc/v2ray/config.json` and appends `| strings`, which ours dropped in the migration). Fixed by mirroring the anchored form `change-id-*` already uses.

Found 153. **`extend-*` rewrote an expiry it could not parse, destroying the account** (`full/extend-{ws,http,split,grpc}.sh`, `lite/`, and the WireGuard extend in `menu-wg.sh`) - `d1=$(date -d "$exp" +%s)` prints nothing for an unreadable date, bash treats empty as 0, and the new date is computed from 1970.
- **Confirmed live:** with an account whose stored date was `GARBAGE-DATE`, `extend-ws` rewrote the marker to `### ext1 70-01-07` - a past date, so the next `xp` sweep deletes the account.
- **Inherited:** both references parse without a guard; `xp.sh` got exactly this guard in fix 110 and `extend-*` did not. Fixed with the same guard.

Found 154. **A menu prompt that reads EOF recursed until the stack overflowed** (every menu that answers an invalid option by re-entering itself, e.g. `full/menu-bot.sh`'s `mna`, `lite/`, `bmenu.sh`, `dm-menu.sh`, `menu-*`, `xl2tp.sh`) - `read -p "Input option: " opt` with stdin at EOF yields an empty option, the `*)` branch calls the menu again, the next read also fails, and so on.
- **Confirmed live:** `printf 'x\n' | menu-bot` never returned (killed by a timeout) and the kernel log recorded `menu-bot[...]: segfault ... error 6` at a stack address - an overflow, not a script error. It does not happen on a tty, only when stdin ends (piped input, a dropped terminal).
- **Inherited:** both references recurse the same way. Fixed by making the menu prompt exit on a failed read (`read ... || exit 0`, 57 sites).

Found 155. **Restore moved a glob of archives** (`website/restore-ftp.sh`, `full/restore-ftp.sh`, `lite/restore-ftp.sh`, `full/bmenu.sh`, `lite/bmenu.sh`) - `mv /var/www/uploads/*.zip /root/backup.zip` fails with two or more archives ("target is not a directory"), no `backup.zip` is produced, and every web restore stays broken until the directory is cleaned by hand. `upload.php` names each upload uniquely and never prunes.
- **Inherited:** both references use the same glob. Fixed: move the single newest archive.

Found 156. **`/etc/wireguard/params` is world-readable and holds the server private key** (`installer/wg.sh`) - it is written with the default umask, so any local user can read the WireGuard private key, and `backup.sh` archives it.
- **Confirmed live:** `644 root:root`, containing `server_priv_key`. **Inherited.** Fixed with `chmod 600`.

Found 157. **The invalid-date guard in `calculate_remaining_days` is dead code** (every copy, ~191 files) - `local expired_date=$(date ...)` makes `$?` the status of `local`, not of `date`, so the branch can never run; an unparseable date becomes a large negative and the gate blocks through the caller's `< 0` check instead.
- **Inherited.** Behaviour was already fail-closed, so this is a correctness fix, not a hole: `local expired_date` and the assignment are now separate statements, and the guard fires as intended.

Found 158. **The lite edition restarts services it does not ship and keeps a dead TLS frontend** (`lite/menu-system.sh`, `lite/xp.sh`, `installer/lite.sh`) - `ws.service` is created only by `installer/ssh.sh`, which lite never runs, yet the menus restart it; the same menus `systemctl restart dropbear`, re-enabling the service `lite.sh` had just disabled because it cannot bind port 22; and `diamond.sh` still runs `stunnel5.sh`, so every lite install gets HAProxy on `:777` forwarding to `dropbear:109` - a port with no listener.
- **Inherited** (both references' lite runs `diamond.sh` with stunnel5). Fixed: guard the `ws` restarts, do not restart dropbear in lite, and stop/disable haproxy in lite.

Found 159. **The L2TP installer wrote empty-credential accounts** (`installer/l2tp.sh`) - `VPN_USER` and `VPN_PASSWORD` are never assigned, so it wrote `"" l2tpd "" *` into `/etc/ppp/chap-secrets` and `:<hash of "">:xauth-psk` into `/etc/ipsec.d/passwd`, i.e. a valid empty username/password pair next to the public PSK `myvpn`.
- **Confirmed live earlier** (`"$VPN_USER" l2tpd "$VPN_PASSWORD" *` present). **Inherited** from both references. Fixed: the files are created empty and `xl2tp.sh`, which already owns them, appends the real accounts.

Found 160. **The WS and HTTPUpgrade nginx locations lack the streaming timeouts SplitHTTP has** (`config/4.conf`, `6.conf`, `dual.conf`) - an idle WebSocket or HTTPUpgrade tunnel is cut at nginx's 60-second default while the SplitHTTP locations carry `proxy_read_timeout/send_timeout 300s`.
- **Ours to fix:** the SplitHTTP timeouts came from fix 133, so this was an incomplete fix rather than an inherited defect (the references set none). The three `proxy_*_timeout`s are now set once at the `http` level.

Found 161. **Argo "Details" reads a file nothing writes** (`full/menu-argo.sh`, `lite/menu-argo.sh`) - `doms=$(cat /etc/xray/domssh)` on a path no script creates, printing `cat: ... No such file or directory` and leaving the value unused.
- **Inherited** (both references have the read). Fixed by dropping the line.

Found 162. **The self-signed certificate path does not refresh the HAProxy bundle** (`full/dm-menu.sh`, `lite/dm-menu.sh`, `dmsl`) - HAProxy serves `/etc/haproxy/funny.pem`, and every other issuance path in the file rebuilds it, but `dmsl` does not; it also removes `/etc/xray/funny.pem`, which never exists. Port 777 keeps the previous certificate after a re-issue.
- Fixed: rebuild `/etc/haproxy/funny.pem`, remove the right path, and restart haproxy.

### Checked and found clean, or recorded as not-a-defect

- **`udp-custom` and `udp-request` no longer conflict.** Both config.json files say `listen: :36711`, but live they bind **36711** and **8989** respectively, both services active with zero restarts; the request config's `listen` key is simply unused/misleading. Recorded, not changed.
- **`fix/fix.sh` conntrack keys** are applied on the tested host (module loaded, `nf_conntrack_max` = the configured value); the boot-ordering concern is recorded only.
- **`fix/fix-decrypted-original.sh`** is a retained audit artefact (the decrypted original payload), not shipped by any installer; it is deliberately left byte-for-byte.
- Ports/paths across all 12 nginx locations vs the JSON inbounds vs the card links; every unit restarted vs the units the installers create; the `###` markers; trojan `password` vs vless/vmess `id`; `upload.php`'s token auth and filename handling; the cron entries; and the archive-vs-source sweep (0 diffs after repacking) - all clean.

Found 163. **The menu archives ship entries with no execute bit** (`menu/full.zip`, `menu/lite.zip`, and every repack step that produces them) - the entries never touched kept `-rwxr-xr-x`, but the ones repacked in the recent passes carried `-rw-r--r--`, because the panel's sources are **0644 in the repository** and the repack copies them with `cp` before zipping. A real install masks it: `installer/full.sh` and `installer/lite.sh` both run `chmod +x *` after `unzip`. Any *manual* unpack - including the project's own refresh step - does not, so the extracted script lands 0644 and the menu cannot be started. Live, `/usr/bin/menu-system` answered `Permission denied` (exit 126) both directly and from the main menu's option 10, and `/usr/bin/menu-bot` was 0644 as well; the six affected full entries were `bmenu`, `menu`, `menu-bot`, `menu-ssh`, `menu-system`, `menu-x`, and the four lite entries `bmenu`, `menu`, `menu-bot`, `menu-system`.
- **Ours** (the archives are rebuilt by hand; the references fetch a prebuilt zip, so there is nothing to compare). Introduced by this session's repacks.

Found 164. **The XTLS transport menus and the account-creation flows spin forever when input ends** (`full/x-{ws,http,split,grpc}.sh`, `lite/`, and the `add-*` family) - the transport menus' `read -p "Input option: " opws` is unguarded and their `*)` default re-invokes the menu, so an EOF re-enters forever; the `add-*` scripts' `read -p "Username: " user` sits inside an `until` loop with no guard, so the empty username keeps the loop alive. Same class as Found 154, but fix 162 guarded the `menu-*` family and neither of these.
- **Live:** `printf '0\n' | x-ws` re-rendered the menu **393 times in 3 s** (x-http 387, x-split 210, x-grpc 339), recursing until the stack overflows; `printf '1\n' | x-ws` printed `Username cannot be empty.` without end. Pressing Ctrl-D in a transport submenu does the same.
- **Partly inherited:** the references' `x-ws.sh` carries the same unguarded `read -p "Input Option: " opws`.

Found 165. **`delete-ssh` reports success when the system user was not removed** (`full/delete-ssh.go`, `lite/`) - the tool prints `User X has been successfully deleted.` without checking whether `userdel` succeeded. When the account still has a session or a lingering `systemd --user`, `userdel` fails (rc 8, "currently used by process"), yet the operator is told the account is gone.
- **Live:** `printf '3\nclitest1\n' | menu-ssh` printed "successfully deleted" twice while `id clitest1` still resolved and `/etc/passwd` kept the entry; `userdel clitest1` in the same state returned rc 8. After killing the user's processes the manual `userdel` returned 0 and the account was gone.
- **Recorded, fix pending** (needs the Go tool rebuilt for both editions).

Found 166. **The SlowDNS tunnel opens a session but its data phase stalls** (SlowDNS server + `dnstt-client`) - the server side is correct: `dnstt` is active running `dns-server -udp :5300 -privkey-file server.key slowdns.rohcuan.dpdns.org 127.0.0.1:22`, the `53 -> 5300` iptables rule is present, port 5300 listens, and `/etc/slowdns/server.pub` equals the public key `menu-dnstt` prints (`6320d0...012b`). The client reaches the server and logs `begin session`, but negotiates **effective MTU 127** against the server's **932**, and the SSH banner exchange then times out.
- **Live:** reproduced from **two independent client networks** - the workstation and the KVM guest - both `dnstt-client -udp 202.155.17.126:53 -pubkey 6320d0... slowdns.rohcuan.dpdns.org 127.0.0.1:PORT`, both `begin session` then `Connection timed out during banner exchange` over a 60-90 s window.
- **Ours (investigation open):** not fixed. The asymmetry suggests the client-side UDP data path (large DNS answers not getting through), which may be the network rather than the panel - needs a retest from a native network before deciding. Server config, keys, service and redirection are all verified good.

### Also verified this pass (no defect)

- **WireGuard end-to-end from the client:** peer created with the menu, the panel-published config fetched (`/web/wireguard-<user>.conf`), `wg-quick up`, ICMP to `10.66.66.1` 2/2 0% loss, and egress through the tunnel = `202.155.17.126`. Delete removed the peer.
- **L2TP** create writes `chap-secrets`/`ipsec.d/passwd`/`/etc/funny/.l2tp`, and **delete asks you to pick a numbered client**, not a name (with the right input all three files are cleaned). Services `xl2tpd`/`ipsec` active.
- **System menu:** `Restart All Services` leaves every service active; `Change SSH Banner` writes the file (restored to the shipped banner afterwards); `View Service & Port Details` prints; `Reinstall OS` only opens its own submenu (1. Reinstall OS / 2. Back) and nothing starts; `Cloudflare WARP` and `Cloudflare Argo Tunnel` submenus render (Argo's list is `1/3/0` in the source, not a gap).
- **Domain menu:** `dm-menu > 4` writes a self-signed cert; `dm-menu > 2 > 1 > 4` (acme.sh, IPv4) issued and installed a real **ZeroSSL** certificate with `Verify return code: 0 (ok)`, and `https://<domain>/web/tcp.ovpn` returns 200 afterwards. `curl https://<domain>/` alone still fails by design - `/` is the SSH-WebSocket catch-all.
- **Backup menu** starts a backup and lists the collected directories (`xray`, `wireguard`, `slowdns`).

Found 165 - update: fixed as Fix 173. `userdel` is now `userdel -f` and its error is checked, so the menu no longer claims success when the account survives (verified live with a session holding the account).

Found 167. **The WARP off-switch does nothing on a box its own installer set up** (`full/menu-system.sh` and `lite/`, the `Cloudflare WARP` submenu) - `install()` runs the P3TERX `warp.sh`, which brings WARP up as a **wireguard-go/`wgcf` interface** (`wg-quick@wgcf`), while `enable()`/`disable()` call `warp-cli connect` / `warp-cli disconnect`. On a box installed that way `warp-cli` has no registration, so `disconnect` changes nothing - yet the menu prints `success disable warp`.
- **Live:** after `Cloudflare WARP > 1. Install Cloudflare WARP`, egress became `104.28.213.128` (a Cloudflare WARP address) with `wg-quick@wgcf` active. Running `Cloudflare WARP > 5. Disable WARP Service` printed nothing useful and egress stayed `104.28.213.128`; only a manual `wg-quick down wgcf` restored `202.155.17.126`. The submenu has 9 entries (install/status/restart/enable/disable/token/create/back/exit).
- **Inherited** (both references have the identical `warp-cli connect`/`disconnect`), but the references' `install()` also uses `warp.sh`, so the pair is broken there too. **Not fixed** - the right fix is a design choice (drive `wg-quick@wgcf` from enable/disable, or at least report the real state instead of "success"); recorded for that decision.

Found 167 - update: fixed as Fix 174. Enable/disable now drive `wg-quick@wgcf` (what `install()` creates) and verify the result instead of always printing success.

Found 168. **Enabling WARP locks the operator out of the whole panel** (`LOCAL_IP=$(curl -4 -s ifconfig.me)` at the top of every menu) - the licence gate binds to the machine's **live egress** IP and matches it against `fn-autosc-auth`'s `### <user> <ip> <date>` lines. WARP sends egress through Cloudflare, so the gate no longer sees the licensed IP and exits with `Your IP is not in the database`; every menu command then refuses to run, including the WARP menu that would turn WARP off. The operator is stuck until they disable WARP from a shell.
- **Live:** with WARP down, `menu-system` renders and its egress is `202.155.17.126` (also the value in `/etc/.ip`); after `Cloudflare WARP > Enable`, egress became `104.28.245.128` and `menu-system` printed `Your IP is not in the database`. Manual `systemctl disable --now wg-quick@wgcf` restored `202.155.17.126` and the menus.
- **Ours** (the gate is our repository's `fn-autosc-auth` list; the check itself is inherited). **Not fixed** - changing the licence gate is a licensing decision: it could compare against the machine's configured IP (`/etc/.ip`) or accept *either* that or the live egress, but that is the owner's call.

Found 166 - correction: NOT a panel defect (test-path DNS interception). The "session opens but data stalls" reading was wrong on two counts. First, the client's `begin session` and `effective MTU 127` lines are printed **locally with zero network I/O** (`dnstt-client/main.go`: MTU is pure arithmetic on the domain-name length, the session is a local KCP object) - they prove nothing reached the server. Second, nothing from the test networks ever reaches the VPS on UDP/53: a plain `dig @202.155.17.126 google.com` was answered by someone else on the path while the VPS counters stayed put, a unique-nonce query (`<nonce>.slowdns.rohcuan.dpdns.org`) **timed out and never appeared in the server log**, and a temporary second `dns-server` on UDP/5353 (same keys, removed afterwards) also received nothing - while the panel's real server on :5300 stayed silent in its own log through every attempt. The "two independent client networks" were one uplink (the guest NATs through the host), and that uplink intercepts/filters outbound DNS. Meanwhile the panel side is verified correct: `dnstt` active on `:5300` forwarding to `127.0.0.1:22`, `server.pub` equals the key the menu prints, the `53 -> 5300` redirect is kept first in nat PREROUTING by `slowdns-fixnet` (every 15 s, which is also why raw rule counters cannot be used as evidence), and the server demonstrably receives outside queries (background `NXDOMAIN: not authoritative` entries from internet scanners). End-to-end SlowDNS from a network that does not intercept DNS is still unverified from here and remains the only open item on this path.

Found 169. **The root installer missed the lifetime change** (`install.sh`, the `permision()` gate) - Decision 28 patched 192 copies across `full/`, `lite/` and `installer/`, but `install.sh` carries its own 193rd copy and was not patched. A `lifetime` machine dies at the entry point (`calculate_remaining_days "lifetime"` -> "Invalid expiration date") before ever reaching the lifetime-aware sub-installers. Ours (introduced by our own Decision 28 patch, not inherited - both references gate on a date unconditionally).
- Live check: code read shows the unconditional `REMAINING_DAYS=$(calculate_remaining_days "$EXPIRED_DATE")` with no lifetime branch; unit harness confirms `lifetime` exits 1 here while the patched copies exit 0.

Found 170. **Extending one account rewrites a longer-named account** (`full/extend-{ws,http,split,grpc}.sh`, `lite/`, line 134) - `sed -i "/### $user/c\### $user $exp4"` is unanchored, so extending `ali` also rewrites `alice`'s marker line (verified locally and on the VPS sed: `ali` test corrupts `alice` to the same new date). Inherited from both references (V23 `extend-ws.sh:115` identical), but destructive (wrong expiry on a paying account), so fixed rather than recorded.
- Live check: `/tmp` reproduction on both host and VPS shows unanchored corrupts, anchored (`/^### $user /`) leaves `alice` untouched. Live `ws.json` currently has 0 markers (no accounts), so no live corruption observed - the defect triggers only when prefix-colliding usernames coexist.

Found 171. **Expired WireGuard clients remain connected and continue tunnelling indefinitely** (`full/xp.sh`, `lite/xp.sh`, lines 305-345) - when a WireGuard account expires, `xp.sh` deletes its client entry from `/etc/wireguard/wg0.conf` on disk and its record from `/etc/funny/.wireguard`. However, unlike every other protocol branch in `xp.sh` (which restarts `xray@ws/upgrade/split/grpc`, `ssh`, `ipsec/xl2tpd`, or `noobzvpns`), the WireGuard cleanup block never ran `systemctl restart wg-quick@wg0`. Because WireGuard runs in-kernel, editing `/etc/wireguard/wg0.conf` on disk does not update the active in-kernel peer table.
- **Live reproduction on VPS:** created account `wgexp`, brought it up on the KVM client (`157.15.139.236`), and verified ICMP ping to `10.66.66.1` and HTTP egress through `202.155.17.126`. Set the account's date in `/etc/funny/.wireguard` to `2020-01-01` and ran `/usr/bin/xp`. `xp` deleted `wgexp` from disk (`Config on disk has wgexp? 0`), but `Kernel wireguard has wgexp peer? 1`. The expired client continued pinging with 0% packet loss and continued tunnelling all traffic through the VPS.
- **Inherited from both references** (V23 `full/xp.sh:279` and 1.20 `Full/xp.sh:279` share the identical omission).

Found 172. **Restore scripts hang on existing files and duplicate service restarts** (`full/restore-ftp.sh`, `lite/restore-ftp.sh`, `website/restore-ftp.sh`, `full/bmenu.sh`, `lite/bmenu.sh`) - `unzip backup.zip` without `-o` prompts interactively on standard input when staging files exist in `/root/backup/` (`replace backup/passwd? [y]es, [n]o, [A]ll, [N]one, [r]ename:`). In non-interactive contexts (such as `website/upload.php` triggering `sudo /usr/bin/restore-ftp` without a tty), the process hangs indefinitely on stdin. In addition, `full/bmenu.sh` and `lite/bmenu.sh` duplicate `systemctl restart xray@ws` back-to-back across all three restore functions (`restore()`, `restf()`, `resold()`).
- **Inherited from both references** (both references lack `-o` and carry the duplicated `xray@ws` restarts).

Found 173. **`auto-delete-*` daemons restart all four Xray transports every 5 minutes even when zero accounts are deleted** (`full/auto-delete-{ws,grpc,split,http}.sh`, `lite/auto-delete-{ws,grpc,split,http}.sh`, lines 105-120) - when crontab invokes `auto-delete-*` every 5 minutes, if any active users exist on the server (the directory has `.log` files), the service restart (`systemctl restart xray@<transport>`) was placed outside the `if [ -n "$deleted_users" ]; then` condition. Every 5 minutes, all four Xray daemons restarted, abruptly resetting active WebSocket, gRPC, SplitHTTP, and HTTPUpgrade connections for paying users.
- **Confirmed live on VPS:** created active user `testlive` in `ws.json`. Running `auto-delete-ws` reported `0 files deleted`, but restarted `xray@ws` unconditionally (MainPID changed from 58501 to 58629).
- **Inherited from both references** (V23 `full/auto-delete-ws.sh:109` and 1.20 `Full/auto-delete-ws.sh:109` share the identical unconditional restart).

Found 174. **`quota-{grpc,http,split}` daemons spam the systemd journal with "incomplete. Skipping" every 30 seconds for idle users** (`full/quota-{grpc,http,split}.sh`, `lite/quota-{grpc,http,split}.sh`, line 112) - in Fix 115, `quota-ws.sh` was silenced when `inb` or `outb` was empty, but its three sister daemons (`grpc`, `http`, `split`) across both editions were overlooked. For every account with no traffic in that 30-second interval, each daemon logged `Data usage for user X is incomplete. Skipping.` to systemd every 30 seconds.
- **Confirmed live on VPS:** created `testidle` on gRPC; `journalctl -u quota-grpc` logged `Data usage for user testidle is incomplete. Skipping.` on the next 30-second tick.
- **Inherited from both references** (both references carry the identical noisy `echo`).

Found 175. **The XTLS transport menus reject the two-digit option numbers they display** (`full/x-{ws,grpc,split,http}.sh`, `lite/x-{ws,grpc,split,http}.sh`, lines 145-165) - all four transport menus display items 1 through 9 with leading zeroes (`01. Create VMess Account`, `02. Create VLess Account`, ..., `09. Extend Account`). However, the `case` dispatcher only matched literal `1)` through `9)` without the leading zero. When a user typed the number as shown on the screen (`01`, `02`, ..., `09`), the input matched `*)`, redrawing the menu without executing the requested action.
- **Confirmed live on VPS:** sending `01` to `x-ws` redrew the menu twice without launching `add-vmess-ws`; sending `1` matched `1)` and launched `add-vmess-ws`.
- **Inherited from both references** (both V23 and 1.20 wrote `01`..`09` in the display and single digits in the `case` statement).

Found 176. **`menu-api` gate rejects `lifetime` license entries, and handlers lacked executable permissions in git** (`fn-autosc-api/menu-api`, `fn-autosc-api/handlers/*`) - `menu-api` carries its own `gate()` function that parses `$EXPIRED_DATE` using `$(date -d "$EXPIRED_DATE" +%s)`. When an authorization entry is marked `lifetime` (Decision 28), `date -d "lifetime"` fails, bash arithmetic produces a negative number, and `menu-api` exits with `Authorization has expired.`, locking lifetime machines out of the API installer and management menu. Additionally, `handlers/password-ssh`, `handlers/renew-ssh`, `handlers/renew-xray`, and `server` in the `fn-autosc-api` repository had `100644` non-executable permissions in git.
- **Confirmed by evaluation:** running `gate` logic with `EXPIRED_DATE="lifetime"` failed with `invalid date` and calculated a large negative day count, failing the `< 0` check.
- **Ours:** introduced during the original FN-API layer restoration and missed during the Decision 28 sweep across the primary repository.

Found 177. **Bandwidth usage in main menus truncated all fractional gigabytes to whole integers** (`full/menu.sh:174`, `lite/menu.sh:70`) - in `format_usage()`, when total traffic exceeded 1024 MB, the gigabyte conversion was calculated with `$(echo "$value / 1024" | bc)`. Because `bc` defaults to scale 0 (integer division), fractional gigabytes were completely discarded before `printf "%.2f"`: 1500 MB (1.46 GB) was printed as `1.00 GB`, 2500 MB (2.44 GB) as `2.00 GB`, and 4500 MB as `4.00 GB`, hiding up to 0.99 GB of active bandwidth consumption from the operator.
- **Confirmed live on VPS:** with 1118 MB today's usage, old code calculated `1` -> `1.00 GB`. With `scale=2; $value / 1024`, `menu` renders accurately as `Today: 1.09 GB`.
- **Inherited from both references** (V23 `full/menu.sh:145` shares the identical division without scale).

Found 178. **Lite edition resurrected the dead HAProxy port-777 frontend after install and failed on `ws` in Restart All Services** (`installer/lite.sh`, `lite/menu-system.sh`, `lite/dm-menu.sh`) - Fix 166 attempted to disable HAProxy in `installer/lite.sh`, but placed the disable command *before* `diamond.sh` ran. `diamond.sh` invokes `stunnel5.sh`, which unconditionally re-enabled and restarted HAProxy on port 777. Because lite does not ship or run Dropbear on port 109, port 777 was left open on the internet accepting TLS connections with no responsive backend. Furthermore, `lite/menu-system.sh:116` in `resall()` executed un-guarded `systemctl restart ws` (a unit exclusive to full, producing systemd unit errors on lite), line 127 restarted `haproxy`, and `lite/dm-menu.sh` restarted `haproxy` on every certificate renewal, constantly reviving the dead port 777 listener.
- **Confirmed by code inspection and evaluation:** `diamond.sh` runs at line 140 of `installer/lite.sh`, undoing line 98's `systemctl disable --now haproxy`; `lite/menu-system.sh` line 116 had no error suppression or unit check for `ws`.
- **Inherited from both references** (both references' lite installers ran `diamond.sh -> stunnel5.sh` and retained `ws` restarts in `resall`).

Found 179. **Submenus and restore confirmation loops spun indefinitely on EOF** (`full/menu-dnstt.sh:119`, `full/menu-system.sh:330,357,394,732`, `lite/menu-system.sh:315,342,379,717`, `full/menu-ssh.sh:126`, `full/xl2tp.sh:104,176,223,272`, `full/routing-{ws,grpc,split,http}.sh:602-605`, `lite/routing-{ws,grpc,split,http}.sh`) - Fix 162 and Fix 172 guarded main menus and account creation scripts against EOF, but missed several submenus and loops. In `menu-dnstt`, option read without `|| exit 0` fell to `*) clear; mna89 ;;`, looping 54 times in 3 seconds. In `xl2tp.sh`, `until [[ $VPN_USER =~ ... ]]` and client selection loops without `|| exit 0` spun at 100% CPU on EOF, timing out with exit code 124. In `menu-system`, `change_timezone()`, `menuwg()`, and `add()` recursively re-invoked themselves on EOF. In all 8 `routing-*` scripts, `restore-route()`'s `while true; do read -p ...` without `|| exit 0` spun 53,684 iterations in 3 seconds on EOF.
- **Confirmed live on VPS:** `menu-dnstt < /dev/null` looped 54 times before timeout; `printf '1\n' | xl2tp` hung at 100% CPU and timed out (code 124); `routing-ws` spun >50k times in 3 seconds.
- **Inherited from both references** (both V23 and 1.20 lacked EOF guards across all these functions).

Found 180. **Unguarded IP lookups during OpenVPN/Squid and WireGuard installation corrupted configs on network failure** (`installer/vpn.sh:75,233`, `installer/wg.sh:143`) - `installer/vpn.sh` fetched `MYIP1` via `wget -qO- ipv4.icanhazip.com` without `-4` or fallback. If `icanhazip.com` timed out or failed, `MYIP1` was empty, turning `s/rerechan/$MYIP1/g` into `s/rerechan//g`, which mutated `rerechan-rerechan/255.255.255.255` into `-/255.255.255.255` in `/etc/squid/squid.conf`. Squid cannot parse this invalid ACL range and crashes on startup. Similarly, `installer/wg.sh` fetched `curl -4 -s ipinfo.io/ip` with no fallback, writing `ip=` into `/etc/wireguard/params` and producing broken client endpoints (`:51820`).
- **Confirmed by inspection:** `installer/vpn.sh` and `installer/wg.sh` already possess `$LOCAL_IP` from the auth gate and `/etc/.ip` from `installer/full.sh:93`, but neither fallback was utilized.
- **Inherited from both references** (both V23 and 1.20 use raw single-lookup `wget`/`curl` with no error fallback).

Found 181. **`config/4.conf` carried a leftover port-80 301 redirect block that broke NoneTLS connections on IPv4 installs** (`config/4.conf:79-84`) - `config/4.conf` contained an obsolete test block immediately preceding the primary server block:
```nginx
    # IGNORE THIS
    server {
        listen 80;
        return 301 https://$host$request_uri;
    }
```
Because this block was declared first on port 80 without a `server_name`, Nginx treated it as the `default_server` for port 80. Any NoneTLS request connecting via direct IP address or non-matching Host header received an HTTP 301 redirect to HTTPS rather than reaching the transport location blocks (`/vmws`, `/vlws`, `/trws`, `/vlhu`, `/trspl`, `/`). Neither `6.conf` nor `dual.conf` carried this block; both handled port 80 directly inside the main server block alongside port 443.
- **Confirmed by inspection and verification:** `config/6.conf` and `config/dual.conf` have 0 redirect blocks; removing the snippet aligns all 15 location directives across `4.conf`, `6.conf`, and `dual.conf`. `nginx -t` verifies syntax OK.
- **Inherited from V23** (V23 `config/4.conf:69-73` carried this snippet; 1.20 did not).

Found 182. **`cek-xray-ws.sh` leaked raw `No such file or directory` errors on missing quota/limit files** (`full/cek-xray-ws.sh:60-70`, `lite/cek-xray-ws.sh`) - unlike the Go implementations (`cek-xray-{grpc,http,split}.go`), which check file existence via `ReadFile` and cleanly report `Not available`, `cek-xray-ws.sh` executed `cat "/etc/xray/quota/ws/${user}_usage"`, `cat "/etc/xray/quota/ws/${user}"`, and `cat "/etc/xray/limit/ip/xray/ws/${user}"` with no stderr redirection. When accounts had not yet transferred data or had no limit set, `cat` spewed error lines directly onto the user's terminal.
- **Confirmed live on VPS:** running `cek-xray-ws` on fresh account `testsilent` printed `cat: /etc/xray/quota/ws/testsilent_usage: No such file or directory`.
- **Inherited from both references** (both V23 and 1.20 omitted error suppression on these reads).

Found 183. **Unconfigured Telegram bot credentials spewed `No such file or directory` errors across 136 scripts** (`full/*.sh`, `lite/*.sh`, ~151 sites) - every account creation, deletion, renewal, lock, unlock, check, and lifecycle daemon read `CHATID=$(cat /etc/funny/.chatid)` and `KEY=$(cat /etc/funny/.keybot)` without `2>/dev/null`. On servers where the operator had not set up a Telegram bot, every script execution printed `cat: /etc/funny/.chatid: No such file or directory` and `cat: /etc/funny/.keybot: No such file or directory` into terminal output, stderr streams, cron journals, and API response error payloads.
- **Confirmed live on VPS:** executing `add-vmess-ws` without configured bot leaked two `cat: No such file or directory` error messages into output.
- **Inherited from both references** (both V23 and 1.20 lacked stderr redirection on these credential reads).

Found 184. **Unconditional appends in `ssh.sh` and `slowdns.sh` multiplied `/etc/shells` and `.bashrc` lines on reinstall** (`installer/ssh.sh:165,237`, `installer/slowdns.sh:75`) - `echo "/bin/false" >> /etc/shells`, `echo "/usr/sbin/nologin" >> /etc/shells`, `echo -e "PS1=..." >> /root/.bashrc`, and `echo "export PATH="/usr/local/go/bin:$PATH"" >> /root/.bashrc` were appended without deduplication checks. Every re-execution of the installer stacked duplicate entries in `/etc/shells` and `/root/.bashrc`. In `slowdns.sh`, unescaped nested double quotes also caused `$PATH` to be expanded at install time rather than dynamically evaluated upon login.
- **Confirmed by inspection:** `/root/.bashrc` and `/etc/shells` had accumulated duplicate lines across reinstall testing.
- **Inherited from both references** (both V23 and 1.20 appended these lines unconditionally).

Found 185. **`check_install wireguard` in `installer/wg.sh` checked the exit status of `qrencode` instead of WireGuard** (`installer/wg.sh:120-139`) - `check_install()` checked `[[ 0 -eq $? ]]` against the preceding command. In `installer/wg.sh`, line 137 ran `apt install qrencode -y` immediately before `check_install wireguard` on line 138. If `apt install wireguard` failed, but `qrencode` succeeded, `check_install` validated `qrencode`'s status and reported `[OK] wireguard is installed`, proceeding with missing binaries.
- **Confirmed by inspection:** `check_install()` took `$1` but never referenced it inside the function, evaluating only `$?` of whatever command ran directly above it.
- **Inherited from both references** (both V23 and 1.20 carry this identical flawed test function).

Found 186. **`backup.sh` omitted `/var/www/html/` configs, leaving restored WireGuard accounts without downloadable config files** (`full/backup.sh`, `full/restore-ftp.sh`, `lite/restore-ftp.sh`, `full/bmenu.sh`, `lite/bmenu.sh`) - when an account was created via `menu-wg`, its configuration was generated at `/var/www/html/wireguard-${user}.conf` to allow downloading via HTTP (`/web/wireguard-<user>.conf`) and displaying QR codes in option 5 ("Show WireGuard Config"). However, `backup.sh` only archived `/etc/wireguard`, omitting `/var/www/html/`. When a backup was restored on a fresh server, all WireGuard accounts existed in `wg0.conf`, but running option 5 failed with `cat: /var/www/html/wireguard-<user>.conf: No such file or directory` and `qrencode` failed. In addition, 7 restore locations in `restore-ftp.sh` and `bmenu.sh` carried a copy-pasted message `echo "Backing up data"` instead of `Restoring backup data...`.
- **Confirmed live on VPS:** created `wgbaktest`, ran `backup`, verified `wireguard-wgbaktest.conf` was absent from `backup.zip`. After removing the local file and restoring, `menu-wg` option 5 failed to find the file.
- **Inherited from both references** (both V23 and 1.20 omitted `/var/www/html/` from backups and printed `Backing up data` during restore).

Found 187. **`upload.php` staged uploaded backup archives world-readable (`0644`) and never cleaned up failed uploads** (`website/upload.php:82`) - `upload.php` set `chmod($target_file, 0644)` on uploaded backup files in `/var/www/uploads/`. Because backup archives contain `/etc/shadow`, `/etc/gshadow`, WireGuard private keys, and Xray credentials, world-readable mode exposed sensitive credentials to unprivileged local processes. Furthermore, if `restore-ftp` failed (such as an invalid zip), `$target_file` remained in `/var/www/uploads/` indefinitely.
- **Confirmed by inspection:** `chmod` was explicitly set to `0644`, and there was no cleanup handler after `shell_exec("sudo /usr/bin/restore-ftp")`.
- **Ours:** introduced during web-restore security enhancement and missed during permissions hardening.

Found 188. **WARP submenu invoked non-existent commands (`warp -4/-6/-T`), wiped terminal output instantly, and ran `chmod +x /usr/bin/*`** (`full/menu-system.sh`, `lite/menu-system.sh`, lines 220-335) - the WARP submenu carried multiple broken invocations:
1. `akun4()`, `akun6()`, and `token()` executed `warp -4 > /root/wgcf.conf`, `warp -6`, and `warp -T $token`. The system has no `warp` binary (WARP was installed by P3TERX's `warp.sh`, while `-4/-6/-T` were flags from an unrelated script, Fscarmen `warp`). Calling these printed `warp: command not found` and `cat: /root/wgcf.conf: No such file or directory`.
2. In `status()`, running `warp.sh status` before WARP was installed printed `warp.sh: command not found`.
3. In `status()`, `enable()`, `disable()`, `restart()`, `akun4()`, `akun6()`, and `token()`, the actions returned immediately to `menuwg()`, which instantly executed `clear`. In interactive sessions, status and account displays were wiped within milliseconds before the user could read them.
4. Line 226 in `install()` executed `chmod +x /usr/bin/*`, modifying permissions across all 1500+ system binaries in `/usr/bin/`.
- **Confirmed live on VPS:** running status or account creation printed `command not found` and was instantly wiped by the menu loop.
- **Inherited from both references** (both V23 and 1.20 carried these identical broken calls, lack of pauses, and `chmod +x /usr/bin/*`).

Found 189. **System menu actions (`detail`, `resall`, `bnnr`) exited without pausing, wiping output immediately in main menu** (`full/menu-system.sh`, `lite/menu-system.sh`, lines 95-145, 570-605) - when `menu-system` was invoked from `menu.sh` (option 10), selecting option 5 (View Service & Port Details), option 2 (Restart All Services), or option 8 (Change SSH Banner) executed the action and exited immediately without waiting for user input. `menu.sh` immediately caught the return, cleared the terminal, and re-rendered the main menu. The operator was unable to view the service/port details or see confirmation of service restart. Furthermore, `lite/menu-system.sh`'s `detail()` displayed SSH ports (22, 109, 111, 2080, 53, 5300) that the lite edition does not ship.
- **Confirmed live on VPS:** pressing `10 -> 5` from `menu` rendered the main menu immediately without allowing the operator to read the port details.
- **Inherited from both references** (both V23 and 1.20 omitted pauses on these functions and carried the copy-pasted SSH port list in lite).

Found 190. **`menu-argo` and `menu-dnstt` action options exited without pausing, wiping success messages and details** (`full/menu-argo.sh`, `lite/menu-argo.sh`, `full/menu-dnstt.sh`) - in `menu-argo.sh`, selecting option 3 (Argo Tunnel Details) printed the details and exited the menu immediately rather than pausing and returning to `tamp()`. When `/etc/xray/domargo` was missing, it also leaked `cat: /etc/xray/domargo: No such file or directory`. When called from `menu.sh`, the details were instantly wiped by the main menu's `clear`. In `menu-dnstt.sh`, options 1 (Change Nameserver), 2 (Renew Server Keys), and 3 (Restart SlowDNS Service) printed their success messages and exited immediately without pausing or returning to `mna89()`, causing `menu.sh` to immediately clear the terminal and erase the confirmation notice.
- **Confirmed live on VPS:** running option 3 in `menu-argo` and option 3 in `menu-dnstt` from `menu` immediately redrew the main menu without allowing the operator to read the output.
- **Inherited from both references** (both V23 and 1.20 omitted pauses and return loops on these menu actions).

Found 191. **`menu-noobz.sh` actions exited immediately without pausing, crashed with invalid `--info-all-user`, and jumped to main menu on empty delete** (`full/menu-noobz.sh`) - three defects in `menu-noobz`:
1. In `main()`, case statements `1|01) clear ; create ;;` etc. lacked loop-back to `main`. When called from `menu.sh`, account creation details and user listings were wiped in milliseconds.
2. In `noobz_list_users()`, fallback `noobzvpns --info-all-user` was passed to the modern `noobzvpns` binary, which rejected it with `error: unexpected argument '--info-all-user' found`.
3. In `delete()`, line 184 had `if [ -z "$name" ]; then menu`, jumping completely out of `menu-noobz` into the main panel menu on empty input or EOF.
- **Confirmed live on VPS:** running option 3 produced `unexpected argument '--info-all-user'` and wiped output immediately into `menu.sh`.
- **Inherited from both references** (both V23 and 1.20 carried these identical bugs).

Found 192. **Restore routines never restarted restored VPN and quota services, leaving stale in-memory state and broken sockets** (`full/restore-ftp.sh`, `lite/restore-ftp.sh`, `website/restore-ftp.sh`, `full/bmenu.sh`, `lite/bmenu.sh`) - all five restore scripts unpacked archives containing `/etc/wireguard`, `/etc/slowdns`, `/etc/noobzvpns`, `/etc/ppp`, `/etc/ipsec.*`, and `/etc/xray/quota/`, but only restarted `ssh`, `xray@*`, `nginx`, and `cron`. Restored VPN services (`wg-quick@wg0`, `dnstt`, `noobzvpns`, `xl2tpd`, `ipsec`, `dropbear`, and the `quota-*` daemons) were never restarted, continuing to run stale credentials and leaving UNIX domain sockets in broken states (such as `noobzvpns` `db.socket` failing with ConnectionRefused until manually restarted).
- **Confirmed live on VPS:** running `restore-ftp` restored `/etc/noobzvpns`, leaving `noobzvpns` IPC socket in ConnectionRefused state until service restart.
- **Inherited from both references** (both V23 and 1.20 omitted these service restarts in restore routines).

Found 193. **Nginx config offered deprecated TLSv1.1 and 3DES ciphers** (`config/4.conf`, `config/6.conf`, `config/dual.conf`) - all three nginx configuration templates specified `ssl_protocols TLSv1.1 TLSv1.2 TLSv1.3;` and included `EECDH+ECDSA+3DES:EECDH+aRSA+3DES:RSA+3DES` in the cipher list. TLSv1.1 was deprecated by RFC 8996 (March 2021) and 3DES is vulnerable to Sweet32. While OpenSSL on the live server happened to reject TLSv1.1 handshakes at the library level, the config still advertised a deprecated protocol and weak ciphers.
- **Confirmed live on VPS:** `grep ssl_protocols /etc/nginx/nginx.conf` showed `TLSv1.1 TLSv1.2 TLSv1.3`, and `openssl s_client -tls1_1` confirmed the protocol was listed but rejected at the library level.
- **Inherited from both references** (both V23 and 1.20 had identical TLSv1.1 and 3DES configs).

Found 194. **Lock/unlock scripts proceeded with empty username on EOF, risking config corruption** (`full/locked-xray-{ws,grpc,http,split}.sh`, `full/unlock-{ws,grpc,http,split}.sh`, `lite/locked-xray-{ws,grpc,http,split}.sh`, `lite/unlock-{ws,grpc,http,split}.sh`) - all 16 lock/unlock scripts had `read -p "Input Username to Lock/Unlock: " name` without EOF guard or empty-name check. If `read` failed (EOF/pipe disconnect), `$name` was empty, and the script proceeded to `grep` against `/var/log/create/xray/ws/.log` (empty filename) and `sed` with empty `$name` against the Xray JSON config, potentially matching and corrupting unrelated entries.
- **Confirmed by code inspection:** empty `$name` produces `sed -i "/###  / {N;d}" /etc/xray/json/ws.json` which matches any `### ` line.
- **Inherited from both references** (both V23 and 1.20 had identical unguarded reads).

Found 195. **NoobzVPN installer downloaded generic GitHub certificates instead of using domain ACME cert** (`installer/noobz.sh`) - the NoobzVPN installer ran after `diamond.sh` (which issues domain-specific ACME certificates to `/etc/xray/xray.crt+key`) but downloaded generic certificates from `https://raw.githubusercontent.com/rohjagad/noobzvpns/master/cert.pem+key.pem` instead of linking to the domain cert. This caused TLS certificate mismatch for all NoobzVPN TCP_SSL connections on port 8443.
- **Confirmed live on VPS:** `diff /etc/noobzvpns/cert.pem /etc/xray/xray.crt` showed `DIFFERENT cert`. `openssl s_client -connect 127.0.0.1:8443` showed a generic certificate, not the domain's ZeroSSL cert.
- **Inherited from both references** (both V23 and 1.20 downloaded separate generic certs for NoobzVPN).

Found 196. **Certificate renewal functions in domain menu never restarted NoobzVPN, leaving stale TLS cert in memory** (`full/dm-menu.sh`, `lite/dm-menu.sh`) - all five certificate renewal/generation functions (`acme()` IPv4, `acme()` IPv6, `cert2()`, `fn()`, `dmsl()`) updated `/etc/xray/xray.crt+key` but never restarted `noobzvpns`. Since NoobzVPN reads its certificate at startup (now via symlinks to the domain cert), it continued serving the old certificate until the next service restart or reboot. This is particularly problematic because `dm-menu` restarts `haproxy` and `nginx` after cert renewal but not `noobzvpns`.
- **Confirmed by code inspection:** grep across both `full/dm-menu.sh` and `lite/dm-menu.sh` showed 0 `noobzvpns` references before the fix.
- **New bug introduced by Fix 201** (symlink change makes this restart necessary; previously NoobzVPN had independent certs that weren't renewed at all).

Found 197. **`installer/noobz.sh`: `chmod +x /etc/noobzvpns/*` followed symlinks to domain certificate key, risking world-executable private key** (`installer/noobz.sh`) - after Fix 201 changed `cert.pem` and `key.pem` to symlinks pointing at `/etc/xray/xray.crt+key`, the subsequent `chmod +x /etc/noobzvpns/*` glob would follow the symlinks (without `-h`) and apply `+x` to the actual key files at `/etc/xray/xray.key`, making the private key world-executable (perms `0755` instead of `0644`). Neither V23 nor 1.20 had this issue because they wrote real cert files. This was introduced by Fix 201.
- **Identified by regression audit against both V23 and 1.20 references.**

Found 198. **`full/xp.sh`: SSH expiry section missing `xp_log` call and `dropbear` restart lacked `2>/dev/null || true` guard** (`full/xp.sh`, `lite/xp.sh`) - every other protocol's expiry section in `xp.sh` logs the deletion with `xp_log "deleted $user (expiry $exp)"`, but the SSH section at line ~244 had no `xp_log` call, leaving SSH account deletions untracked in `.quota.logs`. Additionally, `systemctl restart dropbear` in `full/xp.sh` (added in commit `68c4068`) had no `2>/dev/null || true` guard, meaning a failure to restart dropbear (e.g. not installed) would print an error per expired SSH user. Neither V23 nor 1.20 has `dropbear` in the SSH expiry restart block at all.
- **Identified by regression audit against both V23 and 1.20 references.**

Found 199. **`change-quota-{ws,http,split,grpc}.sh`: service restart executes BEFORE new quota is written to disk, so restarted services re-read the old value** (`full/change-quota-{ws,http,split,grpc}.sh`, `lite/change-quota-{ws,http,split,grpc}.sh`) - all 8 change-quota scripts run `systemctl daemon-reload` + `systemctl restart xray@{transport}` + `systemctl restart quota-{transport}` at lines 210-212, but the new quota value isn't written to `/etc/xray/quota/{transport}/${user}` until line 223 (`echo "${new_quota_bytes}" > "${quota_file}"`). The restarted quota daemon re-reads the **old** value from disk. The user sees "Successfully updated" but the quota is stale until the next manual restart. Additionally, a dead-code validation block (lines 216-219) that can never fire (the while loop above already guarantees valid input) sits between the restart and the write, containing a `return 1` that would leave services restarted with wrong data if somehow reached.
- **Inherited from both V23 and 1.20** (V23 lines 196-209, 1.20 lines 196-209 — same restart-before-write order).

Found 200. **`quota-{ws,http,split,grpc}.sh`: non-numeric `previous_usage` from corrupt usage file crashes bash arithmetic** (`full/quota-{ws,http,split,grpc}.sh`, `lite/quota-{ws,http,split,grpc}.sh`) - all 8 quota daemon scripts read `previous_usage=$(cat "$usage_file")` and feed it directly into `$((quota_used + previous_usage))`. If the usage file is empty, contains whitespace, or is corrupt from a partial write, bash `$((...))` produces an arithmetic error, breaking the quota check loop for that user. V23 used `bc` (more tolerant of non-numeric input); our version uses bash arithmetic (stricter).
- **Regression introduced when V23's `bc`-based arithmetic was replaced with bash `$((...))` arithmetic.**

Found 201. **`full/xl2tp.sh`: L2TP password read has no EOF guard and `CLIENT_NUMBER` is used uninitialized** (`full/xl2tp.sh`) - `read -p "Password : " VPN_PASSWORD` at line 113 has no `|| exit 0`, so Ctrl+D produces an empty password and the script creates an L2TP account with a blank password in `/etc/ppp/chap-secrets`. Additionally, the `until [[ ${CLIENT_NUMBER} -ge 1 ...]]` loop (delete function) evaluates `${CLIENT_NUMBER}` before any assignment, producing a stderr error `integer expression expected` on the first iteration.
- **Inherited from both V23 and 1.20** (V23/1.20 lines 113 and 129 — same pattern).

Found 202. **`full/xp.sh` and `lite/xp.sh`: SSH expiry section logs wrong `$exp` — uses stale value from previous xray-grpc loop** (`full/xp.sh` line 248, `lite/xp.sh` line 248) - the `xp_log "deleted $username (expiry $exp)"` call in the SSH expiry section executes before `exp="$tgl $bulantahun"` (the SSH account's actual expiry). At that point, `$exp` still holds the value from the last iteration of the xray-grpc expiry loop (line ~189). The audit log records the wrong protocol's expiry date for every SSH deletion.
- **Inherited from both V23 and 1.20** (same variable ordering).
- **Introduced to our code by Fix 204** which added `xp_log` to the SSH section without noticing `$exp` was set after the log call.

Found 203. **`full/pwd-ssh.go`: `sleep()` function produces zero-second sleeps due to integer division** (`full/pwd-ssh.go` line 174) - `sleep(500)` calls `exec.Command("sleep", fmt.Sprintf("%d", 500/1000))` which evaluates to `sleep 0` (Go integer division). The "Connecting..." and "Generating..." status messages flash invisible. Also, the `updateLogPassword` function has a double `defer file.Close()` on the same variable — when `file` is reassigned from `os.Open` to `os.Create`, the first defer closes the second file (captures variable, not value), leaking the original file descriptor.
- **Inherited from both V23 and 1.20** (same `sleep` function and `updateLogPassword` pattern).

Found 204. **`full/extend-ssh.go`: panics on accounts with "never" expiry** (`full/extend-ssh.go` line 106) - `chage -l` returns `Account expires : never` for accounts without expiry. The code does `time.Parse("Jan 02, 2006", "never")` which returns a parse error, causing the program to exit with "Error retrieving expiration date" and no user-friendly explanation.
- **Inherited from both V23 and 1.20.**

Found 205. **`full/delete-ssh.go` and `full/list-ssh.go`: index-out-of-range panic on malformed `/etc/passwd` lines** (`full/delete-ssh.go` line 33, `full/list-ssh.go` line 33) - `fields := strings.Split(line, ":")` followed by `fields[0]` and `fields[2]` without checking `len(fields) >= 3`. A malformed passwd line with fewer than 3 colon-separated fields causes a Go panic. `limit-ip.go` has this guard but these two files don't.
- **Inherited from both V23 and 1.20.**

Found 206. **`full/kill-{http,split,grpc}.sh` and `lite/kill-{http,split,grpc}.sh`: unguarded `$exp` before sed deletes wrong JSON entries** (line 110-111 in all 6 files) — when a user's quota is exceeded, the kill script extracts `$exp` via `grep -w "^### $user"`. If the user's comment line is missing or malformed, `$exp` is empty and `sed -i "/### $user / {N;d}"` matches any comment containing that username, potentially deleting unrelated users' entries from the xray JSON config. `kill-ws.sh` already has `if [[ -n "$exp" ]]` guard; the other three transports (http, split, grpc) do not, in both full and lite editions.
- **Inherited from both V23 and 1.20.**

Found 207. **`full/routing-{ws,http,split,grpc}.sh`: empty `$line` from missing `"outbounds":` corrupts xray JSON** (4 occurrences per file, 16 total) — `line=$(grep -n '"outbounds":' ... | head -1)` followed by `sed -i "${line},$d"`. If `"outbounds":` is not found, `$line` is empty. GNU sed errors on `,\$d` with empty start → sed fails, but script continues (no `set -e`) and appends a new outbounds section to the untouched file, producing duplicate outbounds → invalid JSON → xray fails to start.
- **Inherited from both V23 and 1.20.**

Found 208. **`full/unlock-{ws,http,split,grpc}.sh`: no validation that typed username has a `.locked` file** (line 148-149 in ws/split/grpc, line 150-151 in http) — after listing locked accounts, the script accepts any typed username. If the user types a non-locked or non-existent name, `uuid`, `exp2`, and `protokol2` are all empty. The script injects malformed JSON (empty UUID/expiry) into the xray config, then `mv` on a non-existent `.locked` file fails silently. Xray restarts with broken config.
- **Inherited from V23.**

Found 209. **`full/unlock-split.sh`: Telegram notification says "X-RAY DELETED ACOUNT" instead of unlock message** (line 109) — copy-paste error from `delete-split.sh`. The operator sees a deletion notification when the action was actually an unlock.
- **Inherited from V23.**

Found 210. **Tree-wide unanchored `sed -i "/### $user $exp/"` in 50 files (delete-*, kill-*, quota-*, trial-*, xp.sh, locked-xray-*)** — the `sed` pattern `/### $user $exp/` lacks a `^` anchor. User `ali` matches `alice`'s comment line `### alice 2026-10-01` because `### ali` is a substring. Locking, deleting, or quota-killing user `ali` silently destroys user `alice`'s config entry too. Found 170 fixed only `extend-*.sh`; the remaining 50 files across full/ and lite/ were not addressed.
- **Inherited from both V23 and 1.20.**

Found 211. **`full/limit-ip-{ws,http,split,grpc}.sh` and `lite/limit-ip-{ws,http,split,grpc}.sh`: IP limit read from `.log` file instead of authoritative limit file** (line 99 in all 8 files) — `limit=$(grep "Limit IP:" /var/log/create/xray/<transport>/${user}.log | awk '{print $3}')` reads the IP limit from the account creation log. The authoritative source is `/etc/xray/limit/ip/xray/<transport>/$user` (written by `add-*.sh`, read by `cek-xray-*.sh` for display). If the limit is changed after creation (by `change-limit-ip-*.go`), enforcement still uses the stale creation-time value.
- **Inherited from both V23 and 1.20.**

Found 212. **`installer/slowdns.sh`: keypair regenerated on every reinstall, disconnecting all SlowDNS clients** (line 98) — the installer preserves `nsdomain` across reinstalls (saved before `rm -rf /etc/slowdns`, restored after) but does not preserve the server keypair (`server.key`, `server.pub`). Line 98 unconditionally runs `-gen-key`, producing a new keypair. Existing clients configured with the old public key can no longer connect.
- **Inherited from both V23 and 1.20** (neither preserves keys).

Found 213. **`full/addssh.sh`: no username validation — accepts spaces, slashes, empty strings, existing system accounts** (line 113) — unlike the xray `add-*.sh` scripts which validate `^[a-z0-9_]+$`, `addssh.sh` accepts any input as the SSH username. A username containing `/` causes path traversal in the limit file write (`echo "$iplimit" > "/etc/xray/limit/ip/ssh/${username}"`). A username matching an existing system account (e.g., `www-data`) causes `useradd` to fail silently but the script continues and sets a new password on the existing system user via `chpasswd`. Additionally, the `passwd` call on line 97 is redundant with `chpasswd` on line 98 and leaks interactive prompts to stdout.
- **Inherited from both V23 and 1.20.**

Found 214. **All 24 `add-*.sh` scripts: duplicate detection uses `== '1'` instead of `-gt 0`** (line 96 in each) — `client_exists=$(grep -w $user ... | wc -l)` counts matches. The check `if [[ ${client_exists} == '1' ]]` only rejects when exactly 1 match exists. If 2+ entries already exist (from concurrent adds, botched restores, or manual edits), the check passes and a third duplicate entry is injected.
- **Inherited from both V23 and 1.20.**

Found 215. **`lite/dm-menu.sh`: missing `systemctl restart haproxy` after certificate issuance** (IPv4 path ~line 136, IPv6 path ~line 162, self-signed ~line 407) — `full/dm-menu.sh` restarts haproxy at all 3 certificate issuance points because haproxy reads its own PEM bundle (`/etc/haproxy/funny.pem`). `lite/dm-menu.sh` writes the same PEM but never restarts haproxy, so it continues serving the old certificate until reboot.
- **Inherited from both V23 and 1.20** (lite editions never had the haproxy restart).

Found 216. **`full/extend-{ws,http,split,grpc}.sh` and `lite/extend-{ws,http,split,grpc}.sh`: missing `return` after unparseable-expiry fallback — falls through to corrupt date calculation** (line 128 in all 8 files) — when `$exp` cannot be parsed to a timestamp (`$d1` is empty), the script calls the menu function (`x-ws` etc.) but does not `return`. If the menu command returns normally (user navigates back), execution falls through to `d2=$(date -d "$now" +%s)` and `exp2=$(( (d1 - d2) / 86400 ))` with empty `d1`, producing `exp2 = negative number` → `exp3 = negative + masaaktif` → wrong expiry date written to JSON and log file.
- **Inherited from both V23 and 1.20.**

Found 217. **`config/dual.conf`: duplicate IPv4+IPv6 listeners on same ports without `ipv6only=on` — nginx fails to start on default Debian 12** (lines 82-92 vs 95-102) — `listen [::]:2053 ssl http2 reuseport;` and `listen 2053 ssl http2 reuseport;` both bind to the same port. On Debian 12 with default `net.ipv6.bindv6only=0`, the `[::]` socket already accepts IPv4 connections, so the explicit IPv4 listener fails with "Address already in use". Affects ports 2053, 2083, 2087, 2096, 80, 8880, 2052, 2082, 2095, and 443.
- **Inherited from V23.**

Found 218. **`full/restore-ftp.sh`, `lite/restore-ftp.sh`, `website/restore-ftp.sh`: restore never rebuilds `/etc/haproxy/funny.pem` — HAProxy serves wrong certificate after restore** — the restore scripts overwrite `/etc/xray/xray.crt` and `/etc/xray/xray.key` from the backup archive but never rebuild the HAProxy PEM bundle (`/etc/haproxy/funny.pem = crt + key`), and never restart HAProxy. After a backup restore, HAProxy (serving port 777/Stunnel5) continues using the pre-restore certificate, which may belong to a different domain or be expired. Every other cert-touching operation in the codebase (`dm-menu.sh`, `cert2()`, `dmsl()`) rebuilds `funny.pem` and restarts haproxy.
- **Inherited from both V23 and 1.20.**

Found 219. **`full/cek-login-ssh.sh`: global login count shown per row instead of per-user count** (lines 92-93, 113, 115, 139, 141) — `countdb=$(wc -l < "$DB_SRC")` counts total login events across all users. The value is printed in the "Login Count" column for every row, so all users show the same total. V23 correctly used `sort | uniq | wc -l` over temporary per-user files. `show_total_users` adds `countdb + countsh` (total events) and labels the result "Total Active Users" — also wrong.
- **Introduced in our code; V23 had per-user accounting.**

Found 220. **All 48 `add-*.sh` and `trial-*.sh` scripts (full + lite): deprecated `$[expr]` arithmetic syntax for quota calculation** — `echo -e "$[$quota * 1024 * 1024 * 1024]"` uses `$[...]` which is undocumented, removed in some shells, and exhibits signed 32-bit overflow on 32-bit systems for quotas ≥ 2 GB.
- **Inherited from both V23 and 1.20.**

Found 221. **`installer/xray.sh`: JSON config files and xray log files created with `chmod +x` (755) instead of `chmod 644`** (lines 106-109, 142-147) — data files should not be executable. An executable `*.json` or `*.log` can be accidentally invoked by shell globs or wrapper scripts, and security scanners flag it.
- **Inherited from both V23 and 1.20.**

Found 222. **`full/cek-xray-ws.sh`: display tool truncates live xray access log, breaking IP-limit enforcement between cron ticks** (line 96, `echo -n > /var/log/xray/ws.log`) — every invocation of the "check online users" display erases the log that `limit-ip-ws` (every 5 min) and `kill-ws` (every 5 min) rely on. Running it between two daemon ticks causes the enforcer to see 0 connections, potentially missing over-limit users for one cycle. V23 does not truncate in `cek-xray-ws.sh`.
- **Introduced in our code; not present in V23.**

Found 223. **`full/trial-ssh.sh`: username collision — no existence check before using generated name** (line 99) — `username="trial$(shuf -i 100-999 -n 1)"` picks from 900 values with no check for existing accounts. If a previous uncleaned trial happens to have the same number, `create_ssh_user` returns non-zero and the script exits with no account created and no retry.
- **Inherited from both V23 and 1.20.**

Found 224. **`full/menu-bot.sh` and `lite/menu-bot.sh`: Telegram Chat ID accepted without numeric validation — non-numeric input produces invalid JSON** (line 125 and ~291) — `"owner": $itd` in the config.json heredoc is not quoted. If the operator enters a non-numeric string (e.g., a username handle or accidental text), the resulting JSON is malformed and the Node.js bot crashes on startup with a parse error.
- **Inherited from both V23 and 1.20.**

Found 225. **`website/script.js`: hardcoded `backup.zip` filename check prevents uploading renamed backups** (line 15) — `file.name !== 'backup.zip'` rejects any backup file not named exactly `backup.zip`. The server-side (`upload.php`, `restore-ftp.sh`) accepts any `.zip` file. Operators cannot upload `backup-2026-09-28.zip` or any renamed backup.
- **Inherited from V23.**

Found 226. **`installer/l2tp.sh`: hardcoded IPsec PSK `'myvpn'` — every installation uses the same well-known shared secret** (line 77) — `VPN_IPSEC_PSK='myvpn'` is written to `/etc/ipsec.secrets` on every install. An attacker who knows the PSK can impersonate the VPN server. Additionally, `full/xl2tp.sh` (the menu that displays credentials to the operator) has the PSK hardcoded as a display literal rather than reading from ipsec.secrets, so even if the PSK were manually changed the display would still show `myvpn`.
- **Inherited from both V23 and 1.20.**

Found 227. **`installer/diamond.sh`: `pkill -f "${portd}"` — `$portd` is a command name column from `lsof`, not a PID; multi-line value and COMMAND header produce wrong or unsafe kill** (line 115-116) — `lsof -i:80 | awk '{print $1}'` returns the COMMAND column including the header line `COMMAND`. `pkill -f "$portd"` then uses the multi-line string as a regex pattern, matching unintended processes or nothing useful. The correct tool is `fuser -k 80/tcp`.
- **Inherited from V23** (V23 used `pkill ${portd}` without `-f`).

Found 228. **`installer/diamond.sh`: `systemctl restart apache2` with no error suppression — always fails on non-Apache servers** (line 193) — Apache is not installed by this stack; the bare `restart` prints an error and can abort callers that check exit codes.
- **Inherited from V23.**

Found 229. **`full/menu-system.sh` and `lite/menu-system.sh`: WARP installation uses dead `git.io/warp.sh` URL** (line 225 full, line 210 lite) — `git.io` was shut down by GitHub in January 2023. `wget git.io/warp.sh` always returns a 404 HTML page; `bash warp.sh install` then fails or installs nothing. WARP installation has been silently broken since 2023.
- **Inherited from V23.**

Found 230. **`full/menu-system.sh` and `lite/menu-system.sh`: `information()` OS-reinstall function shows hardcoded placeholder `123@@@` as the root password** (line 729 full, line 709 lite) — the function is meant to display the new root password before wiping. The placeholder is never replaced with a real value, so the operator is shown `123@@@` and would not know their actual new root password.
- **Inherited from V23.**

Found 231. **`full/backup.sh` and `lite/backup.sh`: `/etc/haproxy/` not included in backup** — HAProxy's TLS PEM bundle (`funny.pem`) and any custom HAProxy config are excluded. If `/etc/xray/xray.crt`/`xray.key` are also absent from a backup (e.g. cert not yet issued at backup time), `restore-ftp.sh`'s PEM rebuild also fails, leaving HAProxy with no valid certificate after restore.
- **Inherited from V23.**

Found 232. **`full/quota-{ws,http,split,grpc}.sh` and `lite/quota-{ws,http,split,grpc}.sh`: `grep -C 2 "$user"` cross-user substring match corrupts quota accounting** (line 106 in all 8 files) — `xray api statsquery` returns all users' stats as a flat text blob. `grep -C 2 "$user"` matches any line containing `$user` as a substring, so user `alice` matches `alice2`'s stat lines. Context window overlap also bleeds adjacent values. When a username is a prefix of another, the daemon charges the wrong bytes to the wrong account, causing false quota-exceeded deletions or silent under-charging.
- **Inherited from V23.**

Found 233. **`full/xp.sh` and `lite/xp.sh`: WireGuard peer deletion uses `sed "/^### Client X$/,/^$/d"` — open-ended range wipes all subsequent peers when last block has no trailing blank line** (line 317 full, line 316 lite) — `sed` range `/start/,/end/` never closes when there is no blank line at EOF; it deletes from the matched marker to end of file, wiping all remaining peer configurations. The subsequent `head -${line}` truncation also drops `PersistentKeepalive` and other lines after `AllowedIPs` in surviving peer blocks.
- **Inherited from both V23 and 1.20.**

Found 234. **`full/xp.sh` and `lite/xp.sh`: WireGuard expiry uses strict `<` — accounts live one extra day past expiry** (line 315/314) — `[[ $exp < $now ]]` is false when `$exp == $now` (expiry day). Xray accounts use `[[ "$exp2" -le "0" ]]` (≤ 0 days remaining = delete today). WireGuard accounts survive one extra day, inconsistent with all other transports.
- **Inherited from both V23 and 1.20.**

Found 235. **`full/dm-menu.sh` and `lite/dm-menu.sh`: nginx never reloaded when domain is changed but cert renewal is declined** — `dm()` updates `nginx.conf` server_name, then asks to renew the cert. If the operator answers `n`, the function returns without reloading nginx. The new `server_name` is not active until a manual restart; connections using the new domain as SNI continue to fail.
- **Introduced in our code** (references restarted nginx unconditionally).

Found 236. **`full/limit-ip-ssh.sh`: `cekcek` counts total login events, not unique source IPs** (line 280) — `cekcek=$(… | wc -l)` counts all log lines for the user. The limit file stores a maximum number of concurrent source IPs, but the enforcement compares event-count against IP-limit. A single IP making 3 connections triggers the lock (correct count, wrong metric); 5 different IPs each connecting once bypass the lock until `iplimit < 5`.
- **Inherited from V23.**

Found 237. **`full/menu-noobz.sh`: `noobzvpns remove --help` probe is unreliable — may silently call wrong subcommand** (lines 103, 113) — the probe tests `noobzvpns add --help` and `noobzvpns remove --help`. If the binary treats `--help` as an unrecognised argument and exits non-zero, the probe falls through to the legacy `--remove-user`/`--add-user` path even on a current binary that only understands `remove`/`add`. The account is then not removed from the daemon while the `.noob` record is deleted, orphaning it.
- **Introduced in our code** (references called the commands directly with no probe).

Found 238. **`full/xp.sh` and `lite/xp.sh`: NoobzVPN Telegram notification uses bare `-d` instead of `--data-urlencode`** (line 395/394) — all other Telegram calls in `xp.sh` use `--data-urlencode`. The NoobzVPN block uses `curl … -d "chat_id=$CHATID&text=$TEKS"`. If `$TEKS` contains `&`, `=`, or `+` (possible in expiry dates or usernames), the Telegram API receives a malformed message body.
- **Inherited from V23** (NoobzVPN section was absent; introduced when we added it).

Found 239. **`full/change-quota-{ws,http,split,grpc}.sh` and lite variants: `echo -n > file` is non-portable — writes literal `-n` under dash/sh** (line 205 in all 8 files) — under `/bin/sh` (dash), `echo -n` prints the literal string `-n\n`, leaving `-n` in the usage file instead of an empty file. The correct POSIX truncation is `> file`.
- **Inherited from V23.**

Found 240. **`installer/vpn.sh`: hardcoded `x86_64-linux-gnu` path for `openvpn-plugin-auth-pam.so` fails on ARM64** (line 101) — `cp /usr/lib/x86_64-linux-gnu/openvpn/plugins/openvpn-plugin-auth-pam.so …` fails silently on ARM64 (aarch64) where the path is `aarch64-linux-gnu`. OpenVPN PAM authentication is silently broken on non-x86 installs.
- **Inherited from both V23 and 1.20.**

Found 241. **`config/4.conf`, `config/6.conf`, `config/dual.conf`: gRPC locations missing `grpc_read_timeout`/`grpc_send_timeout`** — without these directives nginx uses its 60-second compiled-in default for gRPC streams, killing idle-but-alive gRPC connections. The `proxy_read_timeout 300s` set elsewhere does not apply to `grpc_pass` backends.
- **Inherited from V23.**

Found 242. **`website/upload.php`: PHP upload size error returns a generic unhelpful message** — when the backup zip exceeds `upload_max_filesize` (typically 2MB default), `$_FILES['backup']['error']` is `UPLOAD_ERR_INI_SIZE`. The code only checks for `UPLOAD_ERR_OK`, so size failures fall through to the generic "No file uploaded or an error occurred" message with no actionable feedback.
- **Inherited from V23.**

Found 243. **`full/cek-login-ssh.sh`: `show_total_users` reads temp files after they are deleted** (line 184–185) — `rm -f "$DB_SRC" "$SSH_SRC"` runs before `show_total_users`, which re-reads those files with `sed`. Both `uniq_db` and `uniq_ssh` are always 0, so "Total Active Users" always prints `0` regardless of actual login activity.
- **Introduced in our Fix 225** (added `show_total_users` without checking call order).

Found 244. **`full/xp.sh` and `lite/xp.sh`: `systemctl restart xray@<transport>` called inside the per-user expiry loop — N restarts for N expired users** (lines 104/142/180/218 in full) — every expired account triggers its own `daemon-reload` + `restart`. With N expired accounts: N service disruptions, N clearings of in-memory Xray stats, N dropped live connections for non-expired users. The WireGuard, L2TP, SSH, and NoobzVPN sections in the same file all correctly restart once after the loop using a flag. Only the four Xray sections (WS, HTTP, split, gRPC) had this defect.
- **Inherited from both V23 and 1.20.**

Found 245. **`full/xp.sh` and `lite/xp.sh`: WireGuard expiry block reads `$now` from a prior section — never sets its own** (line 315/314) — `now` is last set by the L2TP section (line 281/280). If any earlier section calls `exit` or the script is refactored, `now` is unset and the WireGuard comparison silently skips all accounts. All other expiry sections (`now=\`date +"%Y-%m-%d"\``) set `now` at the start of their block.
- **Inherited from V23.**

Found 246. **`full/menu-wg.sh`: IP pool exhaustion check `dot_exists == '1'` fails if `grep -c` returns >1** (line 177) — `grep -c "10.66.66.X"` returns the count of matching lines. If an IP appears in the file more than once (duplicate entry from a partial write), the exhaustion check `== '1'` is false and the IP is assigned to a new client that shares it with an existing one, causing non-deterministic routing.
- **Inherited from V23.**

Found 247. **`full/menu-wg.sh`: WireGuard peer `delete()` uses same broken `sed range + head` pattern** (lines 286–294) — same as the `xp.sh` WireGuard deletion bug (Found 233): `sed -i "/^### Client X$/,/^$/d"` open-ended range at EOF, followed by `head -${line}` truncation that drops `PersistentKeepalive` and other post-`AllowedIPs` lines in surviving peers.
- **Inherited from V23.**

Found 248. **`full/xp.sh` and `lite/xp.sh`: split and gRPC expiry loops still restart Xray per-user inside the loop** (lines 187/225 full, equivalent lite) — Fix 250 (commit 2c14275) correctly moved the WS and HTTP restarts outside their loops using flags, but the Python replacement for split and gRPC missed the correct pattern (differing blank-line count before the next section comment). Both `xray@split` and `xray@grpc` were still being restarted once per expired user inside the loop.
- **Regression introduced by incomplete Fix 250.**

Found 249. **`full/menu-dnstt.sh`: indented `echo -e` writes `[Service]` and `[Install]` with leading spaces into the systemd unit file — systemd ignores them, service never starts** (lines 138–153) — the `echo -e "..."` block generating `/etc/systemd/system/dnstt.service` is indented with 16 spaces inside the script. Those spaces are literal in the output file. systemd does not recognise `"                [Service]"` as a section header; the `[Service]` and `[Install]` blocks are silently dropped, so `ExecStart` and `WantedBy` are lost. The service installs but never starts after a nameserver change.
- **Inherited from V23.**

Found 250. **`installer/noobz.sh`: `chmod +x` on JSON and TOML config files** (line 131) — `chmod +x /etc/noobzvpns/config.json /etc/noobzvpns/config.toml` marks config files as executable. With default umask they become mode 755 (world-readable and executable). These files may contain sensitive paths and service configuration. Correct permission is 600.
- **Inherited from V23.**

Found 251. **`full/menu-wg.sh`: WireGuard `extend()` adds +1 extra day — systematic off-by-one** (line 329) — `duration=$(expr $diff + $extend + 1)` gives WireGuard accounts one extra day compared to every other transport's renewal. The `xl2tp.sh` extend function (line 243) uses `expr $diff + $extend` without `+1`. An operator extending by 30 days gives 31 days to WireGuard users only.
- **Inherited from V23.**

Found 252. **`full/auto-delete-{ws,http,split,grpc}.sh`: removes ancillary files for orphaned users but never edits the Xray JSON** (lines 105–111 in all 4) — the trigger is "user has a log file but is NOT in the JSON config". The script correctly deletes `.log`, quota, and limit files for such orphans — but never removes the user's Xray inbound entry from `ws.json`/`upgrade.json`/etc. if the reverse is true (user in JSON but no log file). Orphaned JSON entries accumulate indefinitely.
- **Inherited from V23.** (This is how auto-delete was designed — it cleans stale log files, not stale JSON entries. Not a destructive bug, but the function name and Telegram message are misleading.)

Found 253. **`full/menu-dnstt.sh`: quoted heredoc delimiter `'SVCEOF'` prevents `$nsdomen` from expanding in the systemd unit file** (line 138) — after Fix 255 (heredoc to remove leading spaces), the delimiter was single-quoted, which suppresses all variable expansion inside the heredoc. `$nsdomen` is written literally as the string `$nsdomen` into the `ExecStart` line. The `dns-server` process starts with the literal argument `$nsdomen` and connects to no nameserver.
- **Regression introduced by Fix 255** (quoted delimiter was used to avoid needing to escape the heredoc body).

Found 254. **`full/menu-wg.sh`: `grep -c "10.66.66.X"` matches partial IPs — `.2` matches `.20`, `.200`, `.22`, etc.** (line 172) — when allocating the next free WireGuard IP, `grep -c "10.66.66.2"` matches any line containing that substring, including `10.66.66.20/32`, `10.66.66.200/32`, `10.66.66.22/32`. IP `.2` appears "occupied" whenever `.20`–`.29` or `.200`–`.209` or `.220`–`.229` exist. Many valid IPs are permanently skipped, compressing the usable pool from 253 to far fewer slots on a busy server.
- **Inherited from V23.**

Found 255. **`full/menu-system.sh` and `lite/menu-system.sh`: OS reinstall menu display labels don't match the install commands** — Ubuntu option 1 displays "Ubuntu 26.04" but installs `ubuntu 16.04`. Alpine options 2–4 display versions 2 higher than what actually gets installed (display 3.22/3.23/3.24, install 3.20/3.19/3.18). An operator who selects based on the displayed version gets a different OS. These are destructive reinstall operations.
- **Regression introduced by our R72-C fix** (we corrected the install commands to valid versions but forgot to update the display labels).

Found 256. **`installer/request.sh`: `chmod +x config.json` sets execute bit on a JSON config file** (line 91) — should be `chmod 600`.
- **Inherited from V23.**

Found 257. **`full/xp.sh` and `lite/xp.sh`: `grpc_expired` flag never initialized to `0` before the gRPC expiry loop** (line 194 full, 191 lite) — Fix 250/254 added batched-restart flags for all 4 Xray transports. `ws_expired=0`, `http_expired=0`, and `split_expired=0` are all initialized before their loops, but `grpc_expired=0` was omitted. When no gRPC user expires, `$grpc_expired` is unset; `[[ "" -eq 1 ]]` evaluates to false by luck in bash but errors under `set -u` or non-bash shells.
- **Regression introduced by Fix 250/254** (incomplete flag initialization).

Found 258. **`lite/xp.sh`: WS expiry loop still restarts `xray@ws` per-user inside the loop — Fix 250 was never applied to lite WS** (lines 102–104) — Fix 250 moved WS/HTTP/split/grpc restarts outside loops using flags in `full/xp.sh`. The same fix was applied to lite for HTTP/split/grpc but the lite WS section was missed. It still has `clear; systemctl daemon-reload; systemctl restart xray@ws` inside the `if [[ "$exp2" -le "0" ]]; then` block. N expired WS users → N xray@ws restarts.
- **Regression introduced by incomplete Fix 250.**

Found 259. **`lite/dm-menu.sh` (3 locations) and `lite/restore-ftp.sh` (1 location): `systemctl restart haproxy` revives port 777 with no backend on lite edition** — Fix 184 (Found 178) removed haproxy restarts from `lite/menu-system.sh` but missed `lite/dm-menu.sh` (lines 136, 162, 408) and `lite/restore-ftp.sh` (line 124). Every certificate renewal or backup restore on lite starts HAProxy on port 777 forwarding to Dropbear port 109 which lite doesn't run.
- **Residual from incomplete Fix 184.**

Found 260. **`lite/unlock-{ws,http,split,grpc}.sh`: missing `.locked` file existence validation — Fix 214 only applied to full/ (4 files)** — Fix 214 added `if [ ! -f ".../${name}.locked" ]; then echo ...; exit 1; fi` to all 4 full/ unlock scripts. The identical check was never applied to the 4 lite/ copies. Typing a non-existent username in lite injects empty UUID/expiry into the xray config.
- **Regression from incomplete Fix 214.**

Found 261. **`full/menu-wg.sh`: WireGuard extend has no guard for unparseable stored expiry** (line 327–328) — Fix 161 (Found 153) claimed to guard `menu-wg.sh` extend, but the guard was never applied. `date -d "${exp_old}" +%s` with an empty or corrupted `exp_old` produces empty output, arithmetic treats it as 0, and the new expiry date is computed from epoch 1970.
- **Residual from incomplete Fix 161.**

Found 262. **`installer/l2tp.sh`: `$NET_IFACE` self-reference on first assignment** (line 78) — `NET_IFACE=$(ip -o $NET_IFACE -4 route show to default | awk '{print $5}')` references `$NET_IFACE` before it is set. Expands to empty, making the command `ip -o -4 route show to default` which works by accident because the stray empty argument is ignored.
- **Inherited from V23.**

Found 263. **19 remaining `echo -n >` instances across `list-xray-*.sh`, `kill-ws.sh`, `extend-*.sh`, and `cek-xray-ws.sh` (full + lite)** — Fix 245 (Found 239) replaced `echo -n > file` with `> file` only in the 8 `change-quota-*.sh` files. The same non-portable pattern survived in 19 other locations: 4 `list-xray-*.sh` (both editions), 1 `kill-ws.sh` (both editions), 4 `extend-*.sh` (both editions), and 1 `cek-xray-ws.sh` (lite). Under dash/sh, `echo -n` writes literal `-n\n` to the file instead of truncating it.
- **Inherited from V23.** Fix 245 was incomplete.

Found 264. **`full/bmenu.sh` and `lite/bmenu.sh`: all 3 restore functions (`restore`, `restf`, `resold`) never restore `/etc/haproxy/` from backup or rebuild `funny.pem`** — `backup.sh` archives `/etc/haproxy` (Fix 237), but bmenu's 3 restore paths only copy xray, funny, wireguard, slowdns, noobzvpns, ppp, ipsec — never haproxy. After any bmenu restore, HAProxy serves a stale or missing PEM; port 777 SSH-over-SSL breaks. `full/restore-ftp.sh` and `website/restore-ftp.sh` do restore haproxy correctly.
- **Inherited from V23** (V23 didn't archive haproxy at all; gap introduced when backup.sh started saving it).

Found 265. **`full/bmenu.sh` and `lite/bmenu.sh`: `restore()` and `resold()` have no error check on wget/unzip — a failed download corrupts system files** — if wget fails or returns HTML error page, `unzip` fails, `cd /root/backup` succeeds on a stale directory, and `cp passwd /etc/` overwrites the current passwd with stale data. `restf()` has an `if [ -f "$file" ]` guard but `restore()` and `resold()` do not.
- **Inherited from V23** (restore). `resold()` is new code.

Found 266. **`installer/package.sh`: Node.js 16 setup URL is EOL — `nodesource.com/setup_16.x` returns 404** (line 92) — Node 16 reached end of life on 2023-09-11. NodeSource has removed the setup script. The Telegram terminal bot (`bot.zip`) depends on Node.js.
- **Inherited from V23.**

Found 267. **`installer/slowdns.sh`: Go download URL points to private GitHub release, not official `go.dev`** (line 75) — `https://github.com/rohjagad/fn-autosc-miscellaneous/releases/download/v1.23/go1.22.0.linux-amd64.tar.gz` depends on the release asset existing in that repo. Also hardcodes `amd64`, failing on ARM64.
- **Introduced by our code** (V23 used a different hosting URL).

Found 268. **`installer/full.sh`, `installer/lite.sh`, `install.sh`: unguarded `read` in `while true` loop spins infinitely on EOF, filling disk with gigabytes of log output** (lines 75-95 full/lite, 154-165 install) — if `read -p "Input Domain: "` hits EOF (closed stdin, interrupted connection, or non-interactive execution), `read` fails with exit code 1, leaving the variable empty. The loop prints "Domain cannot be empty" and immediately `continue`s, looping millions of times per second. Verified live on the VPS: PID 3865 spun for over a day, writing a 17.7 GB `/tmp/install.log` that consumed 100% of the 20 GB root partition and caused multiple systemd units to fail (`certbot`, `logrotate`, `man-db`, `plocate`, `vnstat`).
- **Inherited from V23.** (Menus were guarded in Fix 162/172; installer entry points were missed).

Found 269. **`menu/full.zip`: compiled Go binaries `extend-ssh`, `pwd-ssh`, `list-ssh`, `delete-ssh` were stale — repack only updated `.sh` files** — `menu/full.zip` contained binaries dated Sept 24 (or Sept 23 for `list-ssh`). Subsequent source fixes in `full/*.go` (Fix 209: `pwd-ssh` integer division sleep and double-defer fd leak; Fix 210: `extend-ssh` never-expiry panic; Fix 211: `list-ssh`/`delete-ssh` malformed passwd field guard; R72-A: `extend-ssh` never-expiry extend from today) were compiled locally on the VPS but never re-archived into `menu/full.zip`. Fresh installs from `installer/full.sh` extracted the pre-fix binaries from the zip into `/usr/bin/`.
- **Packaging/repack pipeline gap.**

Found 270. **`installer/package.sh`: Fix 271 changed Node.js from 16 to 20, re-introducing Found 145** (line 92) — Fix 271 bumped `setup_16.x` to `setup_20.x` based on EOL status. However, Found 145 explicitly documents that the Telegram terminal bot (`bot.zip`) pins `node-pty ^0.9.0` and `node-termios 0.0.13`, native C++ addons that fail to build against Node 20 (`NODE_MODULE(pty, init) Error 1`). NodeSource still serves `setup_16.x` (verified 200 HTTP OK). Bumping to Node 20 silently broke the bot installation.
- **Regression introduced by Fix 271** (reverted to `setup_16.x`).

Found 271. **`installer/slowdns.sh`: Go download bypassed pinned repository asset (Decision 8)** (line 75) — Fix 272 replaced the pinned release URL from `fn-autosc-miscellaneous` with a direct call to `go.dev/dl/go1.22.0.linux-${GOARCH}.tar.gz`. Decision 8 mandates that pinned dependencies stay on our fork/release infrastructure first, with canonical upstream as fallback.
- **Decision 8 alignment.**

Found 272. **`full/menu-noobz.sh`: Telegram notifications on user add and delete used bare `-d "chat_id=$CHATID&text=$TEKS"`** (lines 154, 192) — identical to Found 238 in `xp.sh`. Multi-line account cards sent via bare `-d` without `--data-urlencode` are not URL-encoded, causing Telegram API failures or malformed messages when account data contains special characters (`&`, `+`, `=`, etc.). Output was also not suppressed to `/dev/null 2>&1`, leaking curl output onto the operator's screen.
- **Introduced in our code** (when Noobz Telegram notification was added).

Found 273. **`full/trial-ssh.sh`: `send_telegram_notification` used bare `-d`, lacked timeout and stderr suppression** (lines 25-28) — `curl -s -X POST ... -d "chat_id=${chat_id}" -d "text=${message}" > /dev/null` omitted `--max-time 10` (hangs indefinitely on network stall), omitted `--data-urlencode` for the multi-line card message, and only redirected stdout (`> /dev/null`), leaking curl error messages to the terminal.
- **Inherited from V23.**

Found 274. **80 scripts across `full/` and `lite/`: Telegram notifications passed multi-line HTML text via bare `-d` instead of `--data-urlencode`** — all `auto-delete-*`, `change-id-*`, `change-quota-*`, `delete-*`, `dm-menu.sh`, `limit-ip-*`, `locked-xray-*`, `quota-*`, and `unlock-*` scripts used `-d "...text=$TEXT&parse_mode=html"`. curl's `-d` flag expects already-URL-encoded data; passing raw multi-line strings with HTML tags (`<b>`, `<code>`, `⚠️`), newlines, and potential `&` characters in account fields risks truncation or malformed POST bodies.
- **Inherited from V23.**

Found 275. **`full/menu-argo.sh` and `lite/menu-argo.sh`: duplicate `hostname: $domargo` in cloudflared ingress; setup() never starts service; option 2 missing** (lines 151-168, 228-238) — in `config.yml`, rule 1 matches all traffic for `$domargo` to port 80, completely shadowing rule 2 (`service: http://localhost:2080`) with the identical hostname. Modern `cloudflared` rejects this or logs that rule 2 will never be executed. Furthermore, `setup()` ran `cloudflared service install` but never started or enabled the service (`systemctl enable --now cloudflared`), leaving the tunnel dead after setup. Option 2 ("Restart Argo Tunnel") was missing from the menu, leaving a gap (`1, 3, 0`).
- **Inherited from V23.**

Found 276. **`full/xl2tp.sh`: `create()`, `delete()`, `extend()` exit immediately without pausing, wiping credentials in `menu.sh`** (lines 156, 205, 260) — after printing account credentials (`Domain`, `IPsec PSK`, `Username`, `Password`, `Expired`), the functions return to `main()` which exits. When called from `menu.sh` option 7, `menu.sh` immediately calls `clear` and redraws the main menu. The operator never gets to see or copy the generated L2TP VPN credentials.
- **Inherited from V23.**

Found 277. **`full/xl2tp.sh`: `extend()` lacks unparseable date guard, unanchored sed corrupts prefix usernames, past expiry subtracts days** (lines 240-249) — `d1=$(date -d "$exp" +%s)` has no validation; a corrupted date produces empty output and bash arithmetic computes epoch 1970 (same bug as Found 153). `sed -i "s/### $user $exp/..."` is unanchored at line start, corrupting prefix-sharing usernames like `ali` and `alice` (Found 170). If an account is already expired (`exp2 < 0`), `exp3=$((exp2 + masaaktif))` subtracts the elapsed days instead of extending from today (R72-A class).
- **Inherited from V23.**

Found 278. **`full/xl2tp.sh` and `full/xp.sh` / `lite/xp.sh`: IPsec user deletion hardcodes `$1$` MD5 hash format in sed pattern** (lines 189 in xl2tp.sh, 300 in full/xp.sh, 299 in lite/xp.sh) — `sed -i '/^'"$user"':\$1\$/d' /etc/ipsec.d/passwd` strictly matches `$1$`. If the password was hashed with SHA-256 (`$5$`), SHA-512 (`$6$`), or any non-MD5 format, the user line is never deleted from `/etc/ipsec.d/passwd`, leaving orphaned credentials active in IPsec.
- **Inherited from V23.**

Found 279. **`full/limit-ip.go`: strictly refuses to set IP limit on accounts with no existing limit file, and prints "Success" before validation** (lines 241, 258-262) — `if _, err := os.Stat(limitFile); err == nil` checks whether `/etc/xray/limit/ip/ssh/<user>` exists before prompting. If an SSH account was created with `ip=0` (unlimited, no file created per R72-B) or the file was deleted, `limit-ip` prints `Error: Limit IP ... tidak ditemukan!` and exits, preventing the operator from adding an IP limit. Furthermore, `loadingSucces()` (displaying "Success" in green) was called before `if !isPositiveInt(newIPLimit)` input validation.
- **Inherited from V23** (over-strict file existence gate).

Found 280. **`full/menu-ssh.sh` (options 4, 5, 7) and `full/x-*.sh` / `lite/x-*.sh` (options 7, 10, 11 across all 8 files): informative display tools wipe output immediately without pause** — `cek-login-ssh` (active logins), `log-acc-ssh` (account card), `list-ssh` (member table), `cek-xray-*` (online users/traffic), `log-database-xray-*` (Xray account cards), and `list-xray-*` (account listings) printed to stdout and exited immediately. The parent menu scripts exited back to `menu.sh`, which immediately cleared the terminal and redrew the main menu, making all informative output unreadable (Found 189 class).
- **Inherited from V23.**

Found 281. **`full/menu-system.sh` and `lite/menu-system.sh`: all 31 `reinstall.sh` invocations omit `--username root` — causes interactive prompt that breaks redirected execution** (lines 616-792 full, 596-772 lite) — `reinstall.sh` prompts for username on standard input when `--username` is not specified. When invoked non-interactively or with residual standard input from pipes/subshells, the input prompt consumes whatever line follows on stdin as the username (e.g., creating a user named `sleep` instead of `root`).
- **Inherited from V23** (where all reinstall commands were added without username flags).

Found 282. **14 submenu scripts across `full/` and `lite/`: missing "Back to Main Menu" (Option 0) traps operator in submenus** — `menu-ssh.sh` (options 1-9), `menu-x.sh` (options 1-4), all 8 transport menus `x-{ws,http,split,grpc}.sh` (options 1-17 in full and lite), `bmenu.sh` (options 1-4 in full and lite), `dm-menu.sh` (options 1-4 in full and lite), and `menu-noobz.sh` (options 1-3) lacked a "Back to Main Menu" option. Typing `0` or an invalid option either trapped the user in the submenu by redrawing it, or exited the shell session (`exit 0` in menu-noobz). The operator was unable to return to the main menu without terminating the session or sending SIGINT.
- **Inherited from V23.**

Found 283. **`full/menu-wg.sh`: `warp()` never extracts `$CLOUDFLAREKEY` from `warp.json`, causing `wg set peer ""` failure; keys require manual entry** (lines 231-241) — in `warp()`, the Cloudflare API response was piped to `tee warp.json` but `$CLOUDFLAREKEY` was never parsed from `warp.json`. `sudo wg set wg0 peer "$CLOUDFLAREKEY"` executed with an empty peer key, silently failing to attach the WARP peer. Additionally, the script prompted the operator to manually generate and input both private and public keys instead of auto-generating them via `wg genkey` and `wg pubkey` when left blank.
- **Inherited from V23** (where V23 used unexpanded single quotes `'$CLOUDFLAREKEY'`).

Found 284. **`full/menu-wg.sh`: empty username in `delete()`, `extend()`, `show()` matches all entries via unanchored `grep -qw ""`** (lines 285, 311, 380) — if the operator presses Enter without typing a username, `grep -qw ""` matches every line in `/etc/funny/.wireguard` and `wg0.conf`. In `extend()`, this returned the expiry of the first client in the file, prompted for duration, and corrupted `/etc/funny/.wireguard` for an empty user.
- **Inherited from V23.**

Found 285. **`full/menu-noobz.sh`: `create()` allows empty/invalid usernames and duplicate records; `delete()` operates on nonexistent users** (lines 121, 171) — `create()` read username and password without validation or checking `/etc/funny/.noob` for existing records, writing malformed `###  <exp>` entries or duplicate users into the database. `delete()` only checked `[ -z "$name" ]`; if the typed username was not in `/etc/funny/.noob`, it executed deletion commands on `noobzvpns`, cleared the screen, and sent a false "Account Deleted" Telegram notification.
- **Inherited from V23.**

Found 286. **`full/cek-login-ssh.sh`: `get_limit_ip()` returns hardcoded `"2"` as default when no limit file exists** (line 166) — system accounts without a limit file (including `root`, operator accounts, and SSH accounts created with `ip=0`) display `Limit IP: 2` in the live login table. This is misleading: an operator seeing `root ... Limit IP: 2` might believe root has an enforced 2-IP limit when there is none. The default should be `"No Limit"`.
- **Inherited from V23** (verified live: `root` showed `Limit IP: 2` in `cek-login-ssh` output despite no `/etc/xray/limit/ip/ssh/root` file existing).

Found 287. **`full/menu-wg.sh`: `create()` displays `Domain: autosc.rohcuan.dpdns.org / bug.com.autosc.rohcuan.dpdns.org`** (line 212) — the domain display line contains a literal `bug.com.` prefix: `echo -e " Domain\t: $domain / bug.com.${domain}"`. The `bug.com.` segment was a placeholder test string that was committed to V23 and propagated forward.
- **Inherited from V23** (verified live: created WG account showed domain `autosc.rohcuan.dpdns.org / bug.com.autosc.rohcuan.dpdns.org`).

Found 288. **`config/format.sh`: Account cards across all 50 `add-*`, `trial-*`, `addssh` scripts in `full/` and `lite/` immediately clear terminal on creation because `format_display()` lacks a pause** (line 76) — after formatting and printing the account card, `format_display` returned without pausing. The invoking script exited, returning to the transport submenu which exited to `menu.sh`, which immediately cleared the terminal and redrew the main menu. The operator never got to view or copy generated credentials, UUIDs, or configuration links.
- **Inherited from V23 / formatting restyle** (verified live: account creation in menu wiped credentials within milliseconds).

Found 289. **`full/limit-ip.go`: `Credit()` calls `os.Exit(1)` unconditionally on success; `readFile()` prints errors for missing optional bot files; unconfigured bot attempts failed Telegram POST** (lines 47, 121-166) — `Credit()` executed `os.Exit(1)` upon completion, causing `limit-ip` to exit with failure status 1 even when an IP limit was updated successfully. `readFile` printed red error text when optional `/etc/funny/.chatid` or `/etc/funny/.keybot` were absent. `sendTelegramNotification` made an unauthenticated POST request to `api.telegram.org/bot/sendMessage`, displaying `404 Not Found`.
- **Inherited from V23.**

Found 290. **`full/change-quota-*.sh` and `lite/change-quota-*.sh` (8 files): `Sc_Credit()` calls `exit 1` unconditionally on successful quota change** (line 117) — in `change-quota-ws.sh`, `change-quota-http.sh`, `change-quota-split.sh`, `change-quota-grpc.sh` across both editions, `Sc_Credit()` contained an unconditional `exit 1`. Whenever an operator updated an account quota, the script exited with failure code 1 instead of 0.
- **Inherited from V23.**

Found 291. **`full/menu-system.sh` and `lite/menu-system.sh`: Missing Option 0 (Back to Main Menu) in `systemd()` traps operator; submenus exit on action instead of staying in menu** (lines 370-410, 820-850) — in `systemd()`, options only listed 1-8 without a "Back to Main Menu" (Option 0). Typing 0 or invalid input looped `systemd`, trapping the operator. Submenu options 1, 2, 3, 5, 6, 7, 8 did not re-call `systemd`, ejecting the operator from the system menu after any action. In `menu-warp()`, options 1-7 failed to loop back to `menuwg`.
- **Inherited from V23.**

Found 292. **`full/menu-bot.sh` and `lite/menu-bot.sh`: Missing Option 0 (Back to Main Menu) in `mna()`; options 1-5 exit immediately without pausing or returning to menu** (lines 200-240, 360-425) — `mna()` lacked Option 0 to return to the main menu. Options 1-5 exited immediately on completion, and options 2 (`notif`), 3 (`setbotup`), and 5 (`rpot`) had no pause, causing confirmation cards and bug report information to be wiped immediately by `menu.sh`.
- **Inherited from V23.**

Found 293. **`full/bmenu.sh` and `lite/bmenu.sh`: options 1-4 eject operator from menu on action; `restore()`, `restf()`, `resold()`, and `backup.sh` lack pause before returning** — in `bmenu()`, options 1-4 did not re-call `bmenu`. In `restore()`, `restf()`, `resold()`, and `backup.sh`, output was printed and the script exited immediately without pausing, so `menu.sh` immediately cleared the screen and wiped the restore confirmation or backup status before the operator could read it.
- **Inherited from V23.**

Found 294. **`full/xl2tp.sh`, `full/menu-ssh.sh`, `full/menu-x.sh`, and 8 transport menus `x-*.sh`: submenu options eject operator on completion instead of returning to submenu** — in `xl2tp.sh` `main()`, cases 1-3 exited without calling `main`. In `menu-ssh.sh`, cases 1-9 exited without calling `menu-ssh`. In `menu-x.sh`, cases 1-4 exited without calling `menu-x`. In `full/x-*.sh` and `lite/x-*.sh`, cases 1-17 exited without re-calling their menu functions (`xws`, `xhttp`, `xsplit`, `xgrpc`), kicking the operator out after every operation.
- **Inherited from V23.**

Found 300. **`full/menu-wg.sh` accepted an empty WireGuard username and created a blank peer** (`full/menu-wg.sh`, `create()`) — the create flow read `user` without checking the read result or validating the value. Sending an empty username followed by a valid duration created `### Client ` in `/etc/wireguard/wg0.conf`, a blank-name record in `/etc/funny/.wireguard`, and `/var/www/html/wireguard-.conf`. The peer had no usable account name and could collide with later file/config operations.
- **Confirmed live on the VPS:** `printf '1\n\n1\nx\n' | menu-wg` created the blank marker and file; the test snapshot was restored and `wg-quick@wg0` restarted. This is separate from the already-guarded top-level menu EOF path.
- **Inherited from both V23 and Autoscript New 1.20:** both references have the same unguarded `read user` in the WireGuard create function. The fix follows the existing account-name convention used by Xray and Noobz menus.

Found 301. **`full/menu-wg.sh` error paths fell through into WireGuard mutations** (`create()` and `extend()`) — on a duplicate create, missing extend user, or exhausted IP pool, the function called `goback` but did not return. Once `goback`'s `menu` command returned, the rest of the function executed using the rejected name. A duplicate create appended another peer and database row; a nonexistent extend appended a phantom `/etc/funny/.wireguard` record.
- **Confirmed live on the VPS:** with a stubbed `menu` that returned immediately, creating existing `wgtest1` produced two `### Client wgtest1` markers and two database rows; extending `not_a_real_wg_user` created one phantom database row. The exact `/etc/wireguard/wg0.conf`, `/etc/funny/.wireguard`, and web config snapshots were restored, then `wg-quick@wg0` was restarted and active.
- **Inherited from both V23 and Autoscript New 1.20:** both use `goback` without a following return. This became materially dangerous once account lifecycle state was tested under a returning caller.

Found 302. **`full/menu-noobz.sh` created panel-only NoobzVPN records when the server rejected a username** (`create()`) — the menu allowed any length of `[a-zA-Z0-9_]+`, while the installed `noobzvpns` command requires a 1–16-character name. It then appended `### <user> <expiry>` to `/etc/funny/.noob` without checking the `noobzvpns add` exit status. A rejected longer username therefore appeared in the panel database despite no account existing in NoobzVPN.
- **Confirmed live on the VPS:** direct `noobzvpns add` and the menu both rejected `noobz_conflict_audit` with `CoreError(UsernameError ... expected: "^[a-zA-Z0-9\\.\\-\\_]{1,16}$")`; the menu nevertheless wrote one `.noob` record and `noobzvpns print-all` contained zero matching users. The `.noob` and Noobz database snapshots were restored and `noobzvpns` restarted active.
- **Inherited from V23:** its menu also accepts an unrestricted username and unconditionally writes its panel record. The installed binary's length rule is the compatibility ceiling; this menu continues its existing stricter punctuation policy.

Found 303. **`full/menu-dnstt.sh` wrote arbitrary Nameserver input into the SlowDNS service unit** (change nameserver option) — it accepted whitespace and control text, stored it in `/etc/slowdns/nsdomain`, and interpolated it into the `ExecStart` line of `/etc/systemd/system/dnstt.service`. For example, `bad name` persisted as two command arguments rather than a DNS hostname; a newline could also change the generated unit structure.
- **Confirmed live on the VPS:** `menu-dnstt` option 1 accepted `bad name`, wrote it to `nsdomain`, and generated `ExecStart=... bad name 127.0.0.1:22`. The original nameserver and exact unit file were restored, `daemon-reload` run, and `dnstt` returned active.
- **Inherited from V23:** it directly interpolates the same unvalidated prompt. SlowDNS expects an authoritative DNS hostname, so validation is required at this configuration boundary.

Found 304. **`full/dm-menu.sh` and `lite/dm-menu.sh` accepted an invalid new server domain and persisted it across live configuration** (`dm()`) — `bad domain` was written to `/etc/xray/domain`, substituted into nginx as `server_name bad domain;`, and substituted through every saved account card before any SSL renewal choice. The invalid value then became the advertised connection endpoint and could contain `sed` replacement syntax.
- **Confirmed live on the VPS:** `dm-menu` option 1 accepted `bad domain`, wrote it to the domain file and nginx config, and rewrote seven account-card files. Domain, nginx config, and the altered card values were restored; nginx is active. The nginx syntax happened to parse the two tokens, so it does not make the invalid endpoint safe.
- **Inherited from V23 and Autoscript New 1.20:** both take the raw prompt straight into the same persistent files and substitutions. The installer only excludes spaces, but this runtime domain-change boundary must guard all config consumers.

Found 305. **Certificate and restore paths exposed private keys to every local user** (`installer/diamond.sh`, `full/dm-menu.sh`, `lite/dm-menu.sh`, `full/bmenu.sh`, `lite/bmenu.sh`, and all `restore-ftp.sh` variants) — certificate paths ran `chmod 644` on `/etc/xray/xray.key`; every path that rebuilt `/etc/haproxy/funny.pem` set that combined certificate-and-key bundle to `0644`. Both files contain the TLS private key, so an unprivileged local process could read and exfiltrate the server's TLS identity.
- **Confirmed live on the VPS:** `/etc/xray/xray.key` began at mode `0644`. Changing it to `0600`, then restarting nginx, HAProxy, NoobzVPN, and all four Xray services, left every service active. The secure mode remains applied on the VPS.
- **Inherited from both V23 and Autoscript New 1.20:** both set the Xray key and rebuilt HAProxy bundles to `0644`. The older audit only verified that mode after a different symlink-permission repair; it was not an intentional access-control decision.

Found 306. **`full/delete-{ws,grpc,http,split}.sh` and lite variants restarted the Xray service, deleted quota/log/limit files, and sent a "Deleted Successfully" Telegram notification even when the supplied username did not exist** — all four delete scripts checked `if [ -n "$exp" ]` to guard only the JSON config edit; the `rm -f` and `systemctl restart` calls fell outside that guard. Entering a nonexistent username printed "User not found in config.json!" but still restarted the affected transport, deleted `${user}.log`, `$user` quota, `${user}_usage`, and `$user` IP-limit files, and fired the deletion Telegram notification.
- **Confirmed live on the VPS:** `delete-ws notarealuser999` (pre-fix) restarted `xray@ws` even though the "not found" path was taken; ws.json was unchanged. After the fix, `xray@ws` was not restarted, ws.json was unchanged, and no files were deleted.
- **Inherited from both V23 and Autoscript New 1.20:** both have the same out-of-guard pattern.

Found 307. **`full/menu-argo.sh` and `lite/menu-argo.sh` accepted an invalid Argo tunnel domain and persisted it to config and YAML** (setup, option 1) — the setup function read the tunnel subdomain with no validation, wrote it directly to `/etc/xray/domargo` and the cloudflared ingress `hostname:` field in `/etc/cloudflared/config.yml`. Whitespace or any non-FQDN value would produce a broken cloudflared ingress.
- **Inherited from V23 and Autoscript New 1.20:** both accept the same raw prompt. The fix applies the same FQDN regex as the domain change (Fix 304) and SlowDNS (Fix 303) boundaries.

Found 308. **`full/addssh.sh` allowed creating SSH accounts with empty passwords** (`main()` line 128) — `read -p "Password: " password` had no empty-string check. An empty `password` caused `chpasswd` to set a blank password on the system account, enabling passwordless SSH/Dropbear logins.
- **Inherited from V23 and Autoscript New 1.20:** neither reference validates the SSH password.

Found 309. **`full/routing-{ws,grpc,http,split}.sh` and lite variants embedded empty strings into live Xray outbound config** (`trojanjir()`, `vlessjir()`, `vmessjir()`) — all three routing invocation sites in each file read Name, Domain, Port, Password/UUID, and Path with no empty-string guards or EOF protection. Any empty field was interpolated into `sed` operations that overwrote the live `outbounds` and `routing` sections of `/etc/xray/json/*.json`, producing invalid JSON or an Xray config with blank server address, empty credentials, or port `""`.
- **Inherited from both V23 and Autoscript New 1.20:** same unguarded reads across all routing functions.

Found 310. **Phase 1 cryptographic credentials and private keys exposed or leaked across installers and restore paths** (`installer/stunnel5.sh`, `installer/wg.sh`, `installer/slowdns.sh`, `installer/l2tp.sh`, `full/bmenu.sh`, `lite/bmenu.sh`, all `restore-ftp.sh` variants, `full/menu-bot.sh`, `lite/menu-bot.sh`, `full/xl2tp.sh`, `full/xp.sh`, `lite/xp.sh`) — multiple file paths handling TLS keys, WireGuard keys, L2TP credentials, or bot API secrets lacked `0600` protection or leaked keys:
1. `installer/stunnel5.sh` piped the certificate and private key via `tee /etc/haproxy/funny.pem`, leaking the TLS private key to stdout and omitting `chmod 600`.
2. `installer/wg.sh` wrote `/etc/wireguard/wg0.conf` containing the server's private key but never set `chmod 600 /etc/wireguard/wg0.conf`, leaving it world-readable `0644`.
3. `installer/slowdns.sh` wrote `/etc/slowdns/server.key` without ensuring `chmod 600`.
4. `installer/l2tp.sh` marked `/etc/funny/.l2tp` executable (`chmod +x`).
5. `full/bmenu.sh`, `lite/bmenu.sh`, and all 3 `restore-ftp.sh` variants (`full`, `lite`, `website`) restored `/etc/xray/xray.key`, `/etc/wireguard/wg0.conf`, `/etc/wireguard/params`, `/etc/ipsec.secrets`, `/etc/ppp/chap-secrets`, `/etc/ipsec.d/passwd`, `/etc/funny/.keybot`, and `/etc/funny/.chatid` without enforcing `chmod 600`, leaving restored keys world-readable if the backup archive had `0644` permissions.
6. `full/menu-bot.sh` and `lite/menu-bot.sh` wrote Telegram credentials (`/etc/funny/.keybot` and `.chatid`) with default umask `0644` without `chmod 600`.
- **Confirmed live on the VPS:** `/etc/wireguard/wg0.conf` had mode `0644` (world-readable) while `params` was `0600`. Changing `wg0.conf` to `0600` left `wg-quick@wg0` active.
- **Inherited from both V23 and Autoscript New 1.20:** both reference archives omitted `0600` on restored keys, WireGuard configs, and bot credentials.

Found 325. **Phase 15: Dual-edition package synchronization and binary build verification** (`menu/full.zip`, `menu/lite.zip`, `full/`, `lite/`) —
1. Package parity audit: verified byte-for-byte matching between all 114 entries in `menu/full.zip` and `full/`, and all 97 entries in `menu/lite.zip` and `lite/`.
2. Permission audit: verified all entries in both `full.zip` and `lite.zip` have external attribute `0755` (executable).
3. Go binary compilation audit: verified all 28 Go source files across `full/` and `lite/` compile cleanly with zero errors under `go build`.
- **Confirmed live on the VPS:** deployed `full.zip` to `/usr/bin/`; verified mode `0755` across all installed panel binaries; all 16 core services verified active with 0 failed units.

Found 326. **Documentation drift: non-append-only docs contradicted the reverted fixes** (`README.md`, `project-information/fn-api.md`, `project-information/is-decision.md`) —
1. `README.md` said `Node.js 20` in the install order (`Install base packages, directories, Node.js 20`) and in the changelog (`Node.js 16 (end of life) updated to Node.js 20 LTS`), while `installer/package.sh:92` runs `setup_16.x` per Fix 275 / Found 145 / Found 270. The variants table (`Base packages + Node.js 16`) was already correct.
2. `project-information/fn-api.md` hardening table claimed `ThreadingHTTPServer`, and the second-pass note claimed handler execution `serialised by a lock (cheap paths stay parallel)`, while the live `server` in `rohjagad/fn-autosc-api` is single-threaded `HTTPServer` with no lock (verified via `https://raw.githubusercontent.com/rohjagad/fn-autosc-api/main/server`: `from http.server import BaseHTTPRequestHandler, HTTPServer`, `class Server(HTTPServer)`, header comment `The server is single-threaded, like the reference`).
3. `project-information/is-decision.md` section 18 said the server `threads the server`, contradicting the revert recorded in `bug-fixes-regression.md` sections 26-27.
4. `project-information/fn-api.md` unit row documented `Restart=always` without the live `RestartSec=3s` hardening from Fix 324.
- **Resolution rule:** append-only history is kept as-is; the non-append-only docs above are corrected in place to match the reverted code.

Found 327. **Web-restore rejects every real backup: PHP `upload_max_filesize = 2M` vs 3.7MB `backup.zip`** (`website/install.sh`, `/etc/php/*/apache2/php.ini`) —
live Phase 15 test: valid-token upload of the system's own 3.7MB `backup.zip` failed with `UPLOAD_ERR_INI_SIZE` (`Error: File exceeds maximum upload size`). Found 242 had improved the error message but the cap itself (PHP default 2M, `post_max_size = 8M`) was never raised, so no real backup could ever be web-restored. No uploader tuning exists anywhere in the tree (`upload_max_filesize` unreferenced).
- **Confirmed live:** `php -r ini_get` → `2M / 8M`; 3699620-byte upload rejected before `restore-ftp` ran.

Found 328. **Web-restore sudoers rule never installed: `EDITOR='tee -a' visudo` idiom is a no-op** (`website/install.sh`) —
after raising the cap (Found 327), the valid-token upload reached `sudo /usr/bin/restore-ftp` and died with `sudo: a password is required`. `/etc/sudoers` and `/etc/sudoers.d/*` contain no `restore-ftp` rule: piping `echo ... | EDITOR='tee -a' visudo` runs `tee -a <tmpfile>` with an empty stdin instead of editing sudoers, so the rule was silently never written. Every authenticated web-restore since the key gate (Decision 19) was therefore broken end-to-end.
- **Confirmed live:** `sudo -U www-data -l` showed no rule; system left intact (restore never executed).

Found 329. **Parallel API deletes killed `xray@ws` via systemd start-limit-hit** (`installer/xray.sh` unit, live `/etc/systemd/system/xray@.service`) —
after Phase 16, `xray@ws` was found `failed (Result: start-limit-hit)`. The journal shows xray itself started cleanly every time (config OK, all listeners up); something issued ~8 `restart xray@ws` within ~45s at 15:00 (15:00:02 … 15:00:47), tripping the default limiter (5 starts/10s). Root cause: each API `delete-xray`/`add-xray` call runs the panel delete/add script, which restarts the transport **once per call** — 6 parallel Phase-16 deletes fanned out to 6 restarts in seconds (the 5 parallel adds earlier were already borderline). Genuine crash-loops are unaffected (xray exits are still `Restart=on-failure`); only the *external-restart* budget was too tight for API fan-out and the :00 cron batch.
- **Confirmed live:** `journalctl -u xray@ws` start-limit-hit at 15:00:47; service recovered with `reset-failed + start`; all 4 transports active after.

Found 330. **Same start-limit-hit exposure on every other automation-restarted unit** (follow-up to Found 329, found by auditing the burst vector) —
`limit-ip-ssh` restarts `ssh`/`sshd`/`ws` per lock, `xp` restarts `ssh`/`sshd`/`ws`/`dropbear` per expired batch, and every `add-*` restarts its `quota-*` daemon service: all carried systemd's default 5-starts/10s budget, so the same cron-batch/API fan-out that killed `xray@ws` could take down SSH access or the quota daemons next. Panel daemons themselves already batch one restart per run (flags), so the remaining risk is purely multi-process bursts — a unit-budget problem, not a script-loop problem (234 `systemctl restart xray@` sites were counted and deliberately left alone: per-script debounce would skip semantically necessary restarts).
- **Confirmed live:** `systemctl cat ssh|ws` showed no `StartLimit*` overrides (defaults active).

Found 331. **Migrate SplitHTTP to XHTTP on Xray 25.3.6: `network: splithttp` + `/vmspl` paths renamed** —
Xray 25.x renamed the SplitHTTP transport to XHTTP (`json:"xhttpSettings"` confirmed in the 25.3.6 binary; `splithttp` remains only as a deprecated alias). All wire-visible strings migrated: `"network": "xhttp"` + `"xhttpSettings"` in `json/split.json` and the 12 `add-*-split`/`trial-*-split` scripts (full+lite), link `type=splithttp` → `type=xhttp`, nginx locations `/vmspl`→`/vmxh`, `/vlspl`→`/vlxh`, `/trspl`→`/trxh` in `config/4.conf`, `6.conf`, `dual.conf`, and every user-facing `SplitHTTP`/`Split HTTP` display string → `XHTTP` (cards, menus, Telegram texts). Deliberately **kept** machine identifiers: `*-split.sh` filenames, `xray@split` service, `split.json`, log/quota/limit dirs, and API `core=split` (renaming those would break the API contract, cron, and live units for zero wire benefit — same precedent as public `http` vs internal `upgrade.json`).
- **Confirmed live:** new `split.json` passes `xray run -test` on 25.3.6 (`Configuration OK`).

Found 332. **Auth fetch single-sourced to GitHub raw; Cloudflare Pages is faster for this region** —
all 193 permission gates fetched `izin.txt` only from `raw.githubusercontent.com`. `https://fn-autosc-auth.pages.dev/izin.txt` serves byte-identical content (7 `###` entries on both) with better peering; GitHub stays as fallback.
- **Confirmed live:** Pages URL returns 7 entries from the VPS; gate (`menu-api status`) green.

Found 333. **Full rename `split` → `xhttp` for every machine identifier** (follow-up to Found 331, per explicit direction) —
`*-split.sh` → `*-xhttp.sh` (45 files via `git mv`), `split.json` → `xhttp.json`, service `xray@split` → `xray@xhttp`, data dirs (`/var/log/create/xray/`, `/etc/xray/quota/`, `/etc/xray/limit/ip/xray/`, `/var/log/xray/*.log`) → `xhttp`, function/var/case names (`xsplit()` → `xxhttp()`, `opsplit`, `ceksplit`, `vxsplit`, `split_expired`), menu texts, cron entries, and API `core=split` → `core=xhttp` (with a one-line legacy alias per handler so old clients keep working). Deliberately untouched: language builtins (`strings.Split`, awk `split()`) and append-only history.
- **Verified (repo):** zero `split` tokens outside builtins/history; `bash -n` clean; Go diffs are renames only.

Found 334. **Phase 1: restore paths leave the API token unhardened and the restore key mis-owned** (`full/bmenu.sh`, `lite/bmenu.sh` ×3 restore functions each, `full/restore-ftp.sh`, `lite/restore-ftp.sh`, `website/restore-ftp.sh`) —
1. `cp -r xray /etc/` restores `/etc/xray/.key` (the API root credential) with whatever mode the zip carries, but the post-restore chmod block never touches it — every other secret in the block (`xray.key`, `funny.pem`, wg/ipsec/bot creds, `.restore.key`) is re-secured, the API token is not. A backup taken before Fix 305-era hardening (or any zip that stores 0644) leaves the root API credential world-readable after every restore.
2. `cp -r funny /etc/` restores `/etc/funny/.restore.key` and the block does `chmod 640` but never `chown root:www-data`, so when the archive carries `root:root` ownership the web-server user can no longer read it and the *next* web-restore fails closed with 401 even with the right key (reliability, not just secrecy). `website/install.sh` creates it correctly (`chown root:www-data` + `640`); the 9 restore blocks did not re-assert it.
- **Inherited pattern:** same class as Found 305 (V23/1.20 omitted `0600` on restored keys) — this is the two lines that fix left uncovered.

Found 335. **Phase 3: seven custom units without the burst budget carry systemd defaults (5 starts/10s)** (`installer/udp.sh` → `udp-custom`, `installer/request.sh` → `udp-request`, `installer/slowdns.sh` + `full/menu-dnstt.sh` → `dnstt`, `installer/ssh.sh` → `badvpn-udpgw`, `installer/vpn.sh` → `fn-ohp` + `opn`, `full/menu-bot.sh` + `lite/menu-bot.sh` → `bot`, plus `fn-autosc-api/menu-api` → `api.service`) —
Fix 329/330 widened `xray@`, `quota-*`, `ws`, `ssh`/`dropbear` to `StartLimitIntervalSec=120`/`StartLimitBurst=30` after parallel API deletes killed `xray@ws` via `start-limit-hit`, but these seven units kept the defaults: any burst of external restarts (or a fast crash-loop at `RestartSec=2-3s`) trips the limiter and parks the unit in `failed` until a manual `reset-failed`. Same class, same two lines, left uncovered.
- **Confirmed by inspection:** `grep -n StartLimit` hits none of the nine template sites before this fix; every site already calls `systemctl daemon-reload` after writing its unit, so no reload fix is needed. `noobzvpns.service` is fetched from upstream at install time (not a repo template) and the panel never burst-restarts it — deliberately untouched. Per-user daemon-loop batching stays in Fase 21; this fix only widens the unit budget.

Found 336. **Phase 4: `xp` SSH branch deletes accounts whose shadow expiry is corrupt** (`full/xp.sh`, `lite/xp.sh`, SSH loop) —
every Xray/L2TP/Noobz/WireGuard branch skips unparseable expiries (Found 108 fix: `Skipping $user...` + `continue`), but the SSH branch fed shadow field 8 straight into `$(( $userexp * 86400 ))`: a non-numeric field evaluates to 0, `exp2` goes hugely negative, and the account is `userdel`eted with its log/limit files removed — the same silent-destruction class as Found 108, in the one branch the fix missed. Reachable only via a corrupted `/etc/shadow` field, but the guard costs four lines and matches the siblings exactly.
- **Confirmed by logic reproduction:** `corrupt:abc`/`weird:12x34` → previously DELETE, now SKIP; genuine `alice:20000` still DELETE, future `bob` still KEEP.

Found 337. **Phase 4: `fn-api.md` contract still names the pre-rename transport** (`project-information/fn-api.md:155,163,175`) —
the endpoint table and the "named the same everywhere" paragraph list `core` as `ws|http|split|grpc` and the delete backend as `delete-*-split`, with zero `xhttp` mentions anywhere in the file — Fix 333 renamed code/handlers/README but missed this contract doc. Non-append-only → corrected in place (`xhttp` canonical, `split` noted as legacy alias, matching the API README).
- **Confirmed by inspection:** `grep -n "chmod 640 /etc/funny/.restore.key"` hits 9 restore blocks, 0 of which mention `/etc/xray/.key` or `chown root:www-data` before this fix. No live VPS mutation was needed (pure permission re-assertion, `|| true` guarded).

Found 338. **Phase 5: lite unlock-xhttp Telegram title says the account was DELETED** (`lite/unlock-xhttp.sh:111`) —
the unlock notification body reads `X-RAY DELETED ACOUNT` while the other seven unlock scripts (all three siblings in `full/`, the other three in `lite/`, both http variants) read `UNLOCK ...` — a copy-paste leftover that tells the operator the exact opposite of the operation that just ran (account restored, `.locked`→`.log`, service restarted). Same notification-text class as Found 85; one line restores full/lite parity (verified via `diff`: empty after fix).

Found 339. **Phase 7: `addssh` ignores a failed `useradd` and reports success anyway** (`full/addssh.sh:157`) —
`create_ssh_user` returns 1 when `useradd` fails, but the caller discards the status and proceeds to `chage`, card, Telegram, log and display — a phantom success for an account that does not exist (reachable via a double-create race; `trial-ssh.sh` already guards its caller with `exit 1`). One-word fix (`|| return`).
- **Also Phase 7:** the first `read -p "Username: "` had no EOF guard while every retry carries `|| exit 1` — added the same guard (Fase 20 pattern, in-scope per the Phase 7 `read -p` scan).

Found 340. **Phase 10: four submenus accept `0` but not the displayed `00` spelling** (`full/menu-ssh.sh:139`, `full/menu-x.sh:145`, `full/menu-system.sh:375,410`, `lite/menu-system.sh:360,395`) —
18 of 24 back-branches use `0|00)` (Fix 181 precedent for accepting displayed variants); these six used bare `0)`, so typing the documented `00` fell into `*)` redisplay instead of going back. Same action, wider spelling — zero behavior risk.

Found 341. **Phase 12: installers accept non-FQDN domains that `dm-menu` would reject** (`installer/full.sh:87-90`, `installer/lite.sh:87-90`) —
both install loops check only non-empty + no-spaces, then write `/etc/xray/domain` and sed it into nginx/ACME paths — while `dm-menu.sh:298` (Found 304 fix) enforces the full RFC FQDN regex for the same value post-install. A typo like `test..com` sails through install: ACME fails, the box silently runs self-signed until someone notices. Same regex, added as one `elif`-style branch per installer (language-matched messages).

Found 342. **Phase 13: API installer fetches hang unbounded on stalled network** (`fn-autosc-api/menu-api:56,60,63`) —
the license-gate curls carry `--max-time 15`, but the three `install_api` fetch lines (`server`, `lib.sh`, 19 × handlers) used bare `curl -fsSL`: `-f` fails fast on HTTP errors yet a blackholed/stalled connection hangs per-file with no bound (21 files). Same-class precedent as the gate caps; bounded at 60s per file (generous for binaries, still fail-fast via the existing `FAILED to fetch` + `return 1`). Verified: blackhole fetch aborts at exactly the cap, healthy fetch unaffected (~1.2s).

Found 343. **Phase 14: API token shorter than the documented 40 chars on 4% of installs** (`fn-autosc-api/menu-api:18`) —
`token()` drew 32 bytes → 44 base64 chars, then stripped `/+=` and cut to 40: measured 41/1000 draws below 40 (min 36), contradicting the README/live-plan/`fn-api.md` "40 char" claim and weakening the root credential by up to 24 bits on unlucky installs. One-word fix: draw 48 bytes (exact multiple of 3, so zero `=` padding; only `/+` stripped, ~62 chars remain) — 0/2000 short after the change.

Found 344. **Phase 15: API restart fan-out quantified — implementation deferred to a live-VPS session** (design recorded, explicitly NOT implemented here) —
static audit of the handler→panel call chains: `add-xray` = 1 restart/call, `delete-xray` = up to 4/call (one per transport holding the account), `renew-xray` = 1/call, the other six mutating handlers = 0. A 6+6 burst therefore fans out to ~12–30 `systemctl restart` in seconds; the widened unit budgets (Fix 329/330/335) absorb it, but the fan-out itself remains.
- **Recorded design (trailing-edge, for live implementation):** panel `add-*`/`delete-*`/`extend-*` gain an env gate (`FN_API_BATCH` set → skip internal restart, touch `/run/fn-api/dirty-<transport>`); handlers set it, then join-or-schedule one `at now + 15s` flush (marker-file dedupe; the single-threaded server makes scheduling race-free); the flusher `xray -test`-gates and restarts each dirty transport once. Schedule-before-touch ordering: a crash costs at most a redundant restart, never a lost one.
- **Deferral (gate §5.5):** this changes restart *timing* (account-activation latency becomes ≤15s via API) — behavior-visible work that must be proven on the live VPS (`at`-daemon semantics, burst journal counts, single-call latency). Landing it untested from static audit would violate the acceptance gate. Status: design accepted, code pending a live session. Live criteria already in Fase 15 plan (burst 6+6 → grep-verified + 1 restart/transport + active, no `reset-failed`).

Found 345. **Phase 16: handler input shaping verified end-to-end; panel-mirroring guards added** (`fn-autosc-api/handlers/*`) —
`j()`'s `head -1` already neutralizes embedded newlines (verified: `"30\ninjected"` → `"30"`), but non-string scalars and out-of-panel names flowed into the panel's interactive re-prompts and failed obscurely at EOF. Added exact panel mirrors: `add-xray` (username `^[a-z0-9_]+$`, expired/limit-ip/quota `^[1-9][0-9]*$`), `addssh` (limit-ip/expired numeric; username tightened in Phase 7), `add-noobz` (username `^[a-zA-Z0-9_]{1,16}$`, expired numeric), `renew-*` (days numeric). Panel rules confirmed uniform across all 12 `add-*` scripts before mirroring.
- **Verified live-locally via stub panel:** valid shape pipes exactly `user|ip|quota|days|` + empty-uuid; 8/8 malformed add-xray inputs, 3/3 addssh, 2/2 add-noobz, 3/3 renew inputs rejected explicitly naming field+rule; valid input with metachar password and JSON-number expiry passes guards (reaches panel, fails only at stub-verify as designed). No false rejects.

Found 346. **Phase 17: license gates hang forever on slow network and match the wrong machine on similar IPs** (all 193 gate blocks in `full/`, `lite/`, `installer/`, `install.sh`) —
1. None of the gate curls (`ifconfig.me`, Pages, GitHub) had a timeout, so one stalled download hangs the panel script or 5-minute cron job with no limit (`menu-api` already caps its own at 15s). Added `--max-time 15` everywhere (plus `--timeout=15` on the one `wget` fallback in `install.sh`).
2. `grep "$LOCAL_IP"` matches by substring: proven live-locally that IP `1.2.3.4` also matches the line for `11.2.3.44`, so a machine could pass with someone else's license line. Switched to `grep -wF` (exact text, word edges): `1.2.3.4` now matches only its own line.
- **Verified:** zero leftover un-timed/anchored patterns via grep; `bash -n` clean on every touched script; zips repacked (114/97, `0755`, byte-identical).

Found 347. **Phase 18: unquoted variables in delete-adjacent grep/sed** (27 files) —
`sed -i $MYIP2/$MYIP3` (`installer/vpn.sh`, the plan's named example), `grep -w $user` in all 24 `add-*.sh` duplicate checks, `grep -w $VPN_USER` (`full/xl2tp.sh`), `grep -qw $1` + `is-active $1` (`installer/wg.sh`). All proven safe-today (validated charsets / literal installer args — quoting changes zero behavior), quoted anyway per the plan: one bad future edit away from a word-split config wipe.
- **Verified:** zero unquoted leftovers via grep; `bash -n` clean on all 27; zips repacked.

Found 348. **Phase 19: background message sends with no time limit** (quota daemons, restore display, install info) —
1. `send_log` in all 8 `quota-*.sh` used bare `curl -s -X POST`: these run in 30-second loops, so one stuck Telegram send stalls the whole quota pass (the `limit-ip` sisters already cap theirs). Capped at 10s.
2. Cosmetic lookups (`icanhazip` in 3 `restore-ftp.sh`, `ipinfo.io` in `diamond.sh`) could hold up restore/install completion text. Capped at 10s each — they only fill display lines, so a timeout just leaves them blank.
3. All 62 OS-reinstall `curl -O` lines in both `menu-system.sh` capped at 120s (big file, generous). The `&&` chain already stops a failed download from running; now a stalled one stops too.
- **Also Phase 19 (API side):** `menu-api uninstall` now clears the failed-state flag (`reset-failed`), so a unit that once tripped its limiter starts fresh on reinstall; README notes the Method column is convention-only (the server answers any method — proven in Phase 1).
- **Verified:** `bash -n` clean everywhere; fallback binary URL returns 200; zips repacked.
- **Openly not done:** atomic staging/rollback + checksums for the installer (needs a live box to prove; stays in the Fase 19 plan as future work, same honest status as Found 344).

Found 349. **Phase 21: daemons restarted the service once per user instead of once per run** (`limit-ip-*`, `quota-*`, `kill-*`, all transports, both editions — 24 files) —
a cron run that locked/deleted N users issued N back-to-back `systemctl restart`s (the `xp`/`auto-delete` daemons already batch correctly and were the template). Each in-loop restart is now a `need_restart=1` flag; one `xray -test`-gated restart fires after the loop (quota resets its flag each 30s pass; `send_log` per-user notices unchanged).
- **Verified live-locally in a sandbox** (fake license server, fake xray API, restart counter): 2 locked users → exactly 1 restart with only the right accounts removed; 2 over-quota users → 1 restart with cards/quota/limit cleaned and the healthy account's usage file kept; 2 kill triggers (over-quota + missing-file) → 1 restart; zero-trigger run → 0 restarts, config untouched. All 24 files `bash -n` clean; static scan confirms zero in-loop restarts remain; zips repacked.

Found 350. **Phase 22: background daemons edited the same config file with no shared lock** (`xp`, `limit-ip-*`, `quota-*`, `kill-*` — 26 files, both editions) —
each daemon had only its own cron lock, so overlapping runs (aligned cron ticks, the 30-second quota loop) read-modify-wrote the same JSON: entries could vanish while the file stayed valid. Each JSON file now has one lock (`/tmp/xray-json-<name>.lock`, held only around the edit + restart, max 30s wait, never nested so no deadlock); a waiter that times out skips that run/section and the next tick retries.
- **Verified live-locally in a sandbox:** a two-process counter lost 40 of 80 updates unlocked vs 0 locked; worse, the pre-lock daemons under a triple pile-up silently dropped a healthy account (`k1`) with the JSON still valid — the exact real-world damage. With locks, two full pile-up rounds deleted exactly the 5 triggered accounts, kept the healthy one, left valid JSON, 3 restarts, 0 skips.
- **Openly out of scope:** menu/API scripts also write these files but run at human speed behind an already one-at-a-time API server; their window is tiny and nothing on record ever hit it. If that changes, the same one-lock-per-file pattern applies.

Found 351. **Live: `unlock-*` re-adds an account that is already there, breaking the config** (all 8 `unlock-*.sh`) —
found by doing it live: with the account still in JSON, unlock appended a second copy → duplicate user → `xray -test` fails → the transport can never restart again until repaired by hand (repaired on the spot, `Configuration OK` restored). Guard added: exact full-line match (`grep -qxF "### $user $exp"`) skips the re-add and the run continues to card restore + restart normally. Proven live with the same scenario (skip message, single entry, valid config).
- Note: the first attempt used a name-only match; refined to full-line exact so operator typos can't cause a wrong skip.

Found 352. **Live: XHTTP quota enforcement was dead two ways on the live box** —
1. No `quota-xhttp.service` unit existed (rename created `xhttp.json` + `xray@xhttp` but never the quota daemon), while stale `quota-split.service` kept running and error-looping on the deleted `split.json`. Stopped/disabled/removed the stale unit; created + enabled + started `quota-xhttp.service` from the repo template. Full cycle proven live: over-quota account deleted totally with audit line, both services stay active.
2. Repo bug behind it: `quota-xhttp.sh` (both editions) still defined `function split()` but called `xhttp` — instant exit 127, so the daemon could never have worked even with a unit (missed by the rename; the other three transports match). One-word fix per edition; zips repacked.
- Side note: usage counters only get judged when fresh traffic exists (idle passes stay quiet by design), so a freshly-tripped quota fires on the next activity, not the next tick.

Found 353. **Live: IP-limit counters are blind behind the reverse proxy — the limiter cannot trigger in production** (design-level, fix deferred) —
measured live: 3 concurrent sessions from one address read back 1, then 1-2-2 across reads for 4 sessions (client multiplexing + timing noise); every proxied connection reaches xray as 127.0.0.1 and no PROXY protocol exists anywhere, so `statsonline` can never count two real client addresses apart. Any two-device abuse looks like 1 and `cek > limit` never fires. The display side (log-based) can see real addresses, which is why screens and enforcement disagree.
- **Not hot-fixed:** the cures (PROXY protocol on every transport, or log-based counting) are rollout-risky and need a staged plan + rollback, not a live edit. Directions recorded; enforcement stays as-is (harmless: it under-enforces, never over-locks).
















Found 354. **Main menu shows `ON` where it should show the XHTTP account count** (`full/menu.sh`) —
`XTLS XHTTP : $xhttp` under TOTAL ACCOUNTS prints `ON` instead of a number. Cause: the split→xhttp rename gave the XHTTP *count* (`xhttp=... | wc -l`, line 88) the same name as the pre-existing HTTP-upgrade *status* (`xhttp=ON/OFF`, ex-V23 lines 188-190), and the status block runs later so it wins. V23 kept three distinct names (`split` count, `xhttp` HTTP status, `xsplit` split status); the rename collapsed two of them. `lite/menu.sh` and `full/menu-x.sh` are unaffected (count flows straight to display). Whole-TUI sweep (every `full/*.sh` + `lite/*.sh`, count-assign vs ON/OFF-assign set intersection) finds this the only collision.
Found 355. **Main-menu short labels still say `HTTP UP`/`HTTP` for the HTTP-upgrade transport** —
after Fix 353 restored the count, the labels themselves remained inconsistent with the `WS`/`XHTTP`/`gRPC` short style used everywhere else (`XTLS HTTP UP :`, `HTTP:`, plus `HTTP :` in `menu-x`/lite and lite's `HTTP Upgrade (HTTP)` option tag).
Found 356. **"List All Accounts" dumps every card at once — unreadable with many users** —
the four `list-xray-*.sh` (both editions) looped all accounts printing a full block each, while the sibling "Check Database Logs" (option 10) already had the neat numbered-chooser UX (`01. user` + Total + number-or-name prompt showing one card). Same TUI sweep also caught a copy-paste title: `list-xray-http.sh` headed itself "Member XTLS WebSocket Account".
Found 357. **List-account chooser (Fix 355) does not look like Check Database Logs** —
follow-up styling: the new chooser kept the old blue `━━━` separators and `=[ Member ... ]=` header while option 10 uses rainbow `===` separators, centered `XTLS <T> DATABASE`-style headers, blue rules around Total and the orange exit line.
Found 358. **Restyled list chooser printed a blank line instead of the top rainbow** —
the `RSEP=` definition landed after its first use (behind the `accsess.log` truncation line), so the header's opening separator rendered empty in all 8 `list-xray-*.sh`.
Found 359. **Auth gate fetches sequentially and trusts error pages** —
all 192 gates ran `curl primary || curl fallback`, which waits out the primary's full timeout before trying the backup — and worse, never tries the backup on an HTTP error page at all, because `curl -s` exits 0. Measured live: Pages once took 5.3s while GitHub took 0.6s in the same minute.
Found 360. **Background daemons stopped enforcing during auth outages** —
follow-up to the blackout rule: `xp`/`limit-ip-*`/`quota-*`/`kill-*`/`auto-delete-*`/`expire-ssh` (36 files) exited on fetch failure, so expiry/quota/IP enforcement paused whenever both auth sources were unreachable.
Found 361. **Rainbow separators use `=` while the panel's short style moved on** —
operator request: all rainbow `===================================` dividers (42 shell `rainbow_sep` defaults/calls, 9 Go `rainbowSep` calls, plus the embedded `RSEP` in the 8 `list-xray-*.sh`) should render as `-` like the rest of the modern separators. Plain (non-rainbow) `===` card borders and purple dividers intentionally untouched.
Found 362. **TUI still uses `===` separators and some submenus are unstyled** —
operator rule: no `===` anywhere (rainbow, plain, or any other color); title boxes and the very bottom line use rainbow `---`, inner dividers use blue `---`. Audit found `===` in 92 files (Telegram `TEKS` cards in `add-*`/`trial-*`/`xp`/`backup`, plain TUI boxes in `routing-*`/`menu-wg`/`menu-system`/`menu-bot`/`menu-dnstt`/`menu-argo`/`dm-menu`/`xl2tp`, cyan `---===` hybrids in `change-id-*` and WARP screens, log lines in `kill-*`, `extend-ssh.go`), and 16 submenu files with no rainbow/blue styling at all (`routing-*`/`change-id-*` had no `rainbow_sep` infra).
Found 363. **Check-online-user screens use the wrong separator style** —
`cek-xray-ws.sh` (full+lite) and `cek-xray-grpc/http/xhttp.go` (full+lite) frame with blue `━━━━━━━━━━━━━━━━━━━━━━━` (19 wide) instead of the panel standard (rainbow `---` title/bottom, blue `---` inner, 35 wide). Right color family, wrong glyph and width.
Found 364. **Extend/delete account screens use `━━━` frames** —
`extend-ws/http/grpc/xhttp.sh` (full+lite) use dark-blue 49-wide `━━━`; `delete-ws/http/grpc/xhttp.sh` (full+lite) use yellow 35-wide `━━━`. Both are interactive picker/result screens, so both are non-standard terminal style.
Found 365. **Go interactive tools use non-standard frames** —
`delete-ssh.go`/`list-ssh.go` use cyan 42-wide `━━━`; `pwd-ssh.go` uses plain 47-wide `━━━`; `change-limit-ip-*.go` (full+lite) use plain 50-wide `───`; `limit-ip.go` uses BlueCyan 50-wide `───` banner. All are interactive screens.
Found 366. **Menu misc islands outside the standard** —
`menu-noobz.sh` plain 28-wide `═══` cards plus blue 42-wide `╭─╮/╰─╯` frames; `menu-argo.sh` (full+lite) plain 33-wide `═══` details card; `menu-system.sh` (full+lite) `change_timezone` green `═══` + `lolcat` frames; `bmenu.sh`/`restore-ftp.sh` (full+lite) plain 25-wide `━━━` result cards; `cek-login-ssh.sh` (full only) `═══` headers plus plain 30-wide `───` rules; `limit-ip-ssh.sh` (full only) plain colorless 42–46-wide `---` headers; `dm-menu.sh` (full+lite) yellow 35-wide `---` dividers (the only off-color dash offender).
Found 367. **Some interactive screens have no terminal frame at all** —
`limit-ip-ws/http/grpc/xhttp.sh` and `change-quota-ws/http/grpc/xhttp.sh` (full+lite) carry separators only in the Telegram payload (`<b>━━━</b>`); their terminal picker/result output prints with no frame. `expire-ssh.sh` (full only) prints terminal status with no separator anywhere (cron daemon, low priority).
Found 368. **Installer and Telegram payloads outside the standard (decision needed)** —
`installer/slowdns.sh` uses 24-wide `===`; `installer/full.sh`/`lite.sh` use 51-wide `───` plus 31-wide `___` banners and 25-wide `===` Telegram text. Telegram payloads in `add-*`/`trial-*`/`xp`/`backup` (plain 17–32-wide `---`) and in `change-id-*`/`limit-ip-*`/`locked-*`/`unlock-*`/`change-quota-*`/`auto-delete-*`/`quota-*`/`kill-*` (`<b>━━━</b>`/`<code>───</code>`) predate the standard. Restyling them changes what users see in Telegram, so this needs an operator call before touching.
