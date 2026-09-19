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
