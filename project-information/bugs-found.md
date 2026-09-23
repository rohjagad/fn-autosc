# Bugs Found

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

## Live Audit and Verification Cycle (September 2026)

- **Target VPS:** 202.155.17.126 (Debian 12 Bookworm, KVM).
- **Testing Cycle:**
  1. Cloned repository and performed static code analysis.
  2. Verified all 21 initial bugs plus newly uncovered deployment issues (Bugs 22-24).
  3. Replaced obsolete dependencies, fixed broken bash syntax, unified IPv4 resolution, and corrected service units.
  4. Compiled all Go binaries with `-ldflags="-s -w"` and rebuilt `menu/full.zip` and `menu/lite.zip`.
  5. Performed complete OS reinstallation via `bin456789/reinstall` to pristine Debian 12.
  6. Successfully executed unattended full installation with dual-stack networking and SlowDNS.
  7. Confirmed 18 active systemd services and operational TUI menu interface.

