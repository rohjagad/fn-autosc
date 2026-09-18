# Bugs Found

This file records defects and operational issues found during source review and
live testing on a fresh Debian 12 VPS.

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

### Public installer depends on many mutable downloads

- The installer downloads scripts and binaries at runtime from raw GitHub,
  upstream release URLs, and package repositories.
- Most downloads do not use checksums, so availability and content depend on
  those external services at install time.
