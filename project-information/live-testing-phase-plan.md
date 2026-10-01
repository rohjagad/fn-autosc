# Live-Testing Phase Plan

This document establishes the end-to-end live testing phase plan for validating `fn-autosc` against the live VPS and external client environment. It provides executable test matrices, safety protocols, verification criteria, and rollback procedures.

---

## 1. Test Environment Architecture

Testing relies on real network traffic and real client execution rather than source inspection or local mock harnesses:

| Component | Specification | Details |
| :--- | :--- | :--- |
| **External Client** | Local Debian 12 KVM (`/dev/kvm`) | Isolated virtual guest executing real clients (`curl`, `xray-core`, `ssh`, `wireguard-tools`, `strongswan`, `dnstt-client`) |
| **Target Server** | VPS `202.155.17.126` | Debian 12 host running `fn-autosc` stack |
| **SSH Management** | Port `3303` | Non-standard port per Decision 22 |
| **Public FQDN** | `autosc.rohcuan.dpdns.org` | Target for TLS certificates, SNI, and client configs |
| **Credentials** | Stored securely | Remote execution via authenticated non-interactive SSH (`sshpass`) |

---

## 2. Safety & Zero-Side-Effect Protocol

Live testing interacts with active system state and production daemons. All tests must follow this safety protocol:

1. **Temporary Account Names:**
   - All test accounts must use the prefix `testcard*` or `livetest*`.
   - Never modify or delete persistent operational accounts (e.g., `wgtest1`, `wglive1`).

2. **Pre-Test State Snapshots:**
   - Before executing mutating tests, snapshot affected configuration files:
     ```bash
     cp -a /etc/xray/json /tmp/snap-xray-json
     cp -a /etc/funny /tmp/snap-funny
     cp -a /etc/wireguard /tmp/snap-wireguard
     cp -a /etc/passwd /etc/shadow /tmp/snap-auth/
     ```

3. **Post-Test State Restoration & Cleanup:**
   - Delete all created temporary accounts using the panel's official deletion tooling or restore snapshots.
   - Sweep transient log files: `/var/log/create/*/<user>.*`.
   - Ensure clean JSON syntax with `xray run -test -config <file>`.

4. **Health Check Gate:**
   - No phase is complete if any systemd service is `failed` or inactive that was previously active.

---

## 3. Live-Testing Phases

```
┌────────────────────────────────────────────────────────┐
│ Phase 1: Environment Baseline & Security Audit         │
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│ Phase 2: External Protocol Connectivity Matrix         │
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│ Phase 3: Account Lifecycle & Quota/Limit Verification  │
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│ Phase 4: Interactive TUI Menu & Input Fault Injection  │
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│ Phase 5: Administrative Workflows & Disaster Recovery  │
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│ Phase 6: FN-API Remote Operations & Concurrency        │
└────────────────────────────────────────────────────────┘
```

---

### Phase 1: Environment Baseline & Security Audit

Verifies host-level system integrity, running processes, open ports, and file permissions before traffic testing.

#### Verification Matrix

| Target | Expected State | Validation Command |
| :--- | :--- | :--- |
| **System Services** | `active (running)` for all core daemons | `systemctl is-active nginx haproxy xray@ws xray@grpc xray@upgrade xray@split noobzvpns dnstt wg-quick@wg0 openvpn xl2tpd dropbear ws fn-ohp udp-custom udp-request` |
| **Failed Units** | `0` failed units | `systemctl --failed --no-legend` |
| **Private Keys** | Mode `0600` owned by `root:root` | `stat -c '%a %n' /etc/xray/xray.key /etc/haproxy/funny.pem` |
| **Public Certs** | Mode `0644` | `stat -c '%a %n' /etc/xray/xray.crt` |
| **REST API Token** | Mode `0600` | `stat -c '%a %n' /etc/xray/.key` |
| **Web Restore Key** | Mode `0640` owned by `root:www-data` | `stat -c '%a %U:%G %n' /etc/funny/.restore.key` |
| **Kernel Sysctl** | Optimized values active | `sysctl fs.file-max net.netfilter.nf_conntrack_max` |

---

### Phase 2: External Protocol Connectivity Matrix

Validates end-to-end data transfer from the external KVM client to the VPS across every supported transport.

#### Test Execution Protocol

Each protocol is tested by generating a test account, connecting from the KVM client, downloading a known payload, and recording latency/throughput:

```
[KVM Client] ───(Public IPv4 / DNS)───► [Nginx / HAProxy / Ports] ───► [Backend Daemons] ───► [Internet Egress]
```

#### Protocol Test Matrix

| # | Protocol | Inbound Port | Transport / Layer | Client Test Tool | Success Criteria |
| :- | :--- | :--- | :--- | :--- | :--- |
| 1 | **OpenSSH** | `22`, `3303` | Direct TCP | `ssh -p <port>` | Authenticates with password; port forward succeeds; interactive shell denied (`/bin/false`) |
| 2 | **Dropbear** | `111`, `109` | Direct TCP (v2019.78) | `ssh -p <port>` | ECDSA key negotiation; password auth successful |
| 3 | **SSH-WS** | `80`, `443` | WebSocket / Nginx | `wstunnel` / `curl` | Upgrades HTTP/1.1 to WS on `/`; reaches `wsEpro` (port 2080) |
| 4 | **VMess-WS** | `443`, `80` | WS on `/vmws` | `xray-core` client | TLS and non-TLS connections establish; HTTP 200 payload returned |
| 5 | **VLESS-WS** | `443`, `80` | WS on `/vlws` | `xray-core` client | Connection established; HTTP 200 payload returned |
| 6 | **Trojan-WS** | `443`, `80` | WS on `/trws` | `xray-core` client | Connection established; HTTP 200 payload returned |
| 7 | **VMess-gRPC** | `443` | gRPC service `vmgr` | `xray-core` client | TLS connection establishes; bidirectional streaming works |
| 8 | **VLESS-gRPC** | `443` | gRPC service `vlgr` | `xray-core` client | TLS connection establishes; bidirectional streaming works |
| 9 | **Trojan-gRPC** | `443` | gRPC service `trgr` | `xray-core` client | TLS connection establishes; bidirectional streaming works |
| 10 | **VMess-HTTPUpgrade** | `443`, `80` | HTTPUpgrade `/vmhu` | `xray-core` client | Connects over standard HTTPUpgrade mechanism |
| 11 | **VMess-SplitHTTP** | `443` | SplitHTTP `/vmspl` | `xray-core` client | Upload and download streams operate without 12s body timeout |
| 12 | **WireGuard** | `51820` (UDP) | WireGuard kernel | `wg-quick up` | Handshake established; bidirectional ping to `10.66.66.1` |
| 13 | **NoobzVPN** | `8080`, `8443` | TCP / Custom Payload | `noobzvpns` client | TCP handshake; authentication completes; proxy functional |
| 14 | **SlowDNS** | `53` (UDP) | DNSTT tunnel | `dnstt-client` | DNS tunnel resolves nameserver records and tunnels to SSH |
| 15 | **L2TP / IPsec** | `500`, `4500`, `1701` | StrongSwan + xl2tpd | Native L2TP client | IPsec SA established; PPP chap secrets match; IP assigned |
| 16 | **OpenVPN** | `1194` (TCP/UDP) | TUN device | `openvpn --config` | TLS handshake completes; routing pushed; traffic passes |

---

### Phase 3: Account Lifecycle & Quota/Limit Verification

Validates state transitions throughout an account's lifetime: creation, usage, concurrency locking, quota deletion, manual extension, auto-expiry, and safe removal.

#### Lifecycle Matrix

| Step | Operation | Target Scripts | Validation Test |
| :--- | :--- | :--- | :--- |
| **3.1** | **Creation** | `add-*`, `trial-*`, `addssh` | 1. Account created with valid credentials.<br>2. Card displays credentials without clearing screen.<br>3. Config has client entry with `"level": 0`.<br>4. Re-submitting same name rejected as duplicate. |
| **3.2** | **IP Concurrency Enforcement** | `limit-ip-*`, `limit-ip.go` | 1. Connect two distinct client IPs with limit=1.<br>2. Run `limit-ip-<transport>`.<br>3. Verify account moved to `<user>.locked`.<br>4. Client is removed from config; subsequent logins fail.<br>5. Run `unlock-<transport>`; verify account restored cleanly. |
| **3.3** | **Quota Limit Enforcement** | `quota-*`, `kill-*` | 1. Generate account with 1 GB quota.<br>2. Simulate traffic above quota threshold.<br>3. Run `quota-<transport>`.<br>4. Verify account is completely deleted (Decision 16); client removed from JSON; log and quota files wiped. |
| **3.4** | **Extension / Renewal** | `extend-*` | 1. Extend account expiry by 10 days.<br>2. Verify JSON marker updated (`### user YY-MM-DD`).<br>3. Verify system shadow expiration updated for SSH. |
| **3.5** | **Auto-Expiry Sweeper** | `xp.sh` | 1. Plant account with expiry `yesterday`.<br>2. Run `xp.sh`.<br>3. Verify account deleted; single service restart triggered. |
| **3.6** | **Safe Deletion** | `delete-*` | 1. Delete existing user: verify clean removal from config and filesystem.<br>2. Delete non-existent user: verify zero file deletions, zero service restarts, exit code 0 (Fix 306). |

---

### Phase 4: Interactive TUI Menu & Input Fault Injection

Validates all menu dispatchers, ensuring stability under hostile, invalid, or truncated operator input.

#### Fault Injection Suite

For each menu script (`menu`, `menu-x`, `menu-ssh`, `menu-wg`, `menu-noobz`, `menu-dnstt`, `menu-system`, `menu-bot`, `menu-argo`, `bmenu`, `dm-menu`):

| Test Case | Input Injected | Expected Behavior |
| :--- | :--- | :--- |
| **Empty Enter** | `\n` | Prompt repeats or exits cleanly to parent menu; zero mutations executed. |
| **Immediate EOF** | `Ctrl+D` (EOF) | Exits cleanly (`exit 0` / `return`); no infinite loop; no blank file created. |
| **Option 0** | `0` | Returns cleanly to the parent menu level. |
| **Invalid Submenu Option** | `999`, `abc`, `!@#` | Prints invalid option notice and re-shows menu; does not exit or hang. |
| **Zero Numeric Input** | `0` on quantity | Prints `0 not allowed` warning; prompts again (Decision 4). |
| **Negative / Float** | `-5`, `3.14`, `1e5` | Rejected by numeric regex; prompt repeats. |
| **Invalid Domain Input** | `bad domain`, `foo..bar`, `a` | Rejected by FQDN regex; leaves config untouched (Fix 304, 307). |
| **Submenu Loop** | Valid action completed | After viewing output and pressing any key, returns to current submenu, not main menu. |

---

### Phase 5: Administrative Workflows & Disaster Recovery

Validates high-privilege configuration modifications, backups, and restores.

#### Test Protocol

1. **Domain Change & SSL Fallback:**
   - Execute `dm-menu` with invalid domain: verify refusal.
   - Execute `dm-menu` with current domain: verify nginx re-links, certificates verified, services reloaded without downtime.
   - Test ACME fallback logic: verify ZeroSSL and self-signed paths activate when primary CA fails.

2. **Telegram Backup & Restore:**
   - Run `backup`: verify backup archive sent as document to Telegram bot (Decision 12).
   - Verify archive contains required configuration directories (`/etc/xray`, `/etc/wireguard`, etc.).
   - Verify no private tokens or plain credentials leaked in captions.
   - Run test restore via `bmenu`: verify files restored and key permissions reset to `0600` (Fix 305).

3. **Web Restore Endpoint Security:**
   - Send `POST` to `https://<domain>:855/upload.php` without token: must return `403 Forbidden` / reject file.
   - Send `POST` with incorrect token: must return `403 Forbidden`.
   - Send `POST` with valid token from `/etc/funny/.restore.key`: upload accepted and unpacked securely.

---

### Phase 6: FN-API Remote Operations & Concurrency

Validates the headless REST API interface (`rohjagad/fn-autosc-api`) serving `/api/*`.

#### Test Execution Protocol

All API calls executed from the KVM client via `curl` against `https://autosc.rohcuan.dpdns.org/api/<endpoint>`:

```bash
API_KEY=$(ssh -p 3303 root@202.155.17.126 'cat /etc/xray/.key')
curl -sk -H "Authorization: $API_KEY" https://autosc.rohcuan.dpdns.org/api/ping
```

#### API Verification Matrix

| Endpoint | Method | Payload / Test Case | Success Criteria |
| :--- | :--- | :--- | :--- |
| **Auth Gate** | Any | No header / Bad token | HTTP `401 Unauthorized` |
| **Path Traversal** | GET | `/api/..%2f..%2fetc/passwd` | HTTP `404 Script not found` (single path segment rule) |
| `ping` | GET | None | `{"status":"success","message":"pong"}` |
| `add-vmess` | POST | `{"username":"apitest1","core":"ws","expired":7,"limit-ip":1,"quota":2}` | Account created; JSON links returned; `status: success` |
| `list-xray` | GET | None | Account list includes `apitest1`; transport names match (`ws`, `grpc`, `http`, `split`) |
| `renew-xray` | POST | `{"username":"apitest1","days":7,"core":"ws"}` | Expiry date incremented; returns updated date |
| `delete-xray` | DELETE | `{"username":"apitest1"}` | Account deleted from `ws.json`; returns `status: success` |
| `delete-xray` (Regex Injection) | DELETE | `{"username":".*"}` | Rejected; does not match or delete all accounts (Fix 141) |
| `add-ss` / `add-socks` | POST | None | HTTP 200 with `{"status":"error","message":"unsupported endpoint ..."}` |
| **Concurrency** | POST | 5 parallel `add-vmess` calls | Serialized by lock; exactly 5 accounts created; 0 JSON corruptions |

---

## 4. Runbook & Pass/Fail Criteria

### Execution Order
1. Phase 1 (Baseline) must pass before opening Phase 2.
2. Phase 2 (Connectivity) must achieve 100% success on all primary protocols before lifecycle testing.
3. Mutating tests in Phases 3, 4, 5, and 6 must snapshot state before and verify clean state after.

### Overall Pass Criteria
- **Zero Failed Units:** `systemctl --failed` returns empty.
- **Zero Configuration Corruption:** `xray run -test` returns `Configuration OK.` across all four JSON configs.
- **Zero Orphan State:** No dangling test files in `/var/log/create/` or `/tmp/`.
- **Zero Security Degradation:** Private keys remain `0600`, web restore remains token-authenticated.
