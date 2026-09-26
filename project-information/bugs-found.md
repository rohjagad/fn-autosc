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
