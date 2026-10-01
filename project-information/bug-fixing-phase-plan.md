# Bug-Fixing Phase Plan

This document establishes the master phase plan for auditing, fixing, and maintaining the `fn-autosc` codebase. It synthesizes findings from 309 fixed bugs, architectural decisions in `is-decision.md`, reference source behaviors (V23 and Autoscript New 1.20), regression records, and operational requirements.

---

## 1. Guiding Philosophy & Standards

To ensure long-term stability and maintainability without code churn:

1. **Shortest Working Diff Wins (The "Lazy Senior Developer" Rule):**
   - Do not write code that does not need to exist.
   - Use shell built-ins, standard POSIX utilities, and platform primitives over external tools or custom helpers.
   - Deletion over addition; boring over clever.
   - No unrequested abstractions, wrapper functions, or boilerplate for hypothetical future requirements.

2. **Zero Regressions & Non-Negotiables:**
   - Input validation at all trust and network boundaries (API, interactive TUI, web endpoints).
   - Strict prevention of data loss, credential exposure, or configuration corruption.
   - Preserving documented intentional behavior in `is-decision.md`.
   - Never break valid character sets or standard RFC configurations.

3. **Avoid Over-Strictness:**
   - Account usernames: preserve standard safe character sets (`[a-zA-Z0-9_]`), respecting daemon limits (e.g., NoobzVPN 16-char limit). Do not arbitrarily forbid valid user names.
   - Hostnames/Domains: require valid FQDN structure (`^([[:alnum:]]([[:alnum:]-]{0,61}[[:alnum:]])?\.)+[[:alpha:]]{2,63}$`) to prevent command injection and configuration breakage, but accept valid subdomains and hyphens.
   - Passwords: require non-empty input; do not mandate arbitrary complexity rules that break automated clients or existing user workflows.
   - Numeric quantities: enforce `^[1-9][0-9]*$` for duration/quota/IP limits per Decision 4 (`0` not allowed, no silent "unlimited").

4. **Reference Source Reconciliation (V23 & Autoscript New 1.20):**
   - If both reference versions already solve a problem (e.g., standard nginx proxy headers `X-Real-IP $remote_addr`), keep the reference solution rather than inventing new mechanisms.
   - Diverge only when required for security (e.g., `0600` on private keys, authenticating web restore, randomizing template UUIDs) or stability (pinning Xray 25.3.6, Dropbear 2019.78).

---

## 2. Four-Check Regression Gate (Section 35 Rule)

Every proposed fix must be evaluated against the four standard checks before commit:

| Check | Requirement |
| :--- | :--- |
| **1. Regression** | Does the change break any valid input, running service, client connection, or existing workflow? |
| **2. Over-Strictness** | Does the validation or logic reject legitimate values, edge-case characters, or standard configurations? |
| **3. Over-Engineering** | Is this the minimum code that solves the defect? Does it introduce unnecessary abstractions, helpers, or external tools? |
| **4. Alignment vs Source** | Does the change reconcile cleanly with V23, Autoscript New 1.20, and `is-decision.md`? If diverging, is the divergence documented and justified? |

---

## 3. Bug-Fixing Phases

The bug-fixing roadmap is structured into 7 distinct functional phases.

```
┌────────────────────────────────────────────────────────┐
│ Phase 1: Core Service & Daemon Reliability             │
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│ Phase 2: Input Boundary & Mutation Safety              │
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│ Phase 3: Interactive TUI Menus & Navigation Integrity  │
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│ Phase 4: Protocol Transports & Configuration Pipelines │
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│ Phase 5: Backup, Restore & Administrative Safety       │
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│ Phase 6: API Integration Layer (FN-API & Handlers)     │
└───────────────────────────┬────────────────────────────┘
                            │
┌───────────────────────────▼────────────────────────────┐
│ Phase 7: Packaging, Sync & Distribution Consistency    │
└────────────────────────────────────────────────────────┘
```

---

### Phase 1: Core Service & Daemon Reliability

Focuses on background background services, timers, cron scripts, process lifecycle, and file permissions.

- **Scope:**
  - `full/xp.sh`, `lite/xp.sh` (account expiry daemon).
  - `full/quota-*.sh`, `lite/quota-*.sh` (quota accounting daemons).
  - `full/kill-*.sh`, `lite/kill-*.sh` (quota cutoff scripts).
  - `full/limit-ip-*.sh`, `lite/limit-ip-*.sh` (concurrency limiters).
  - `full/auto-delete-*.sh`, `lite/auto-delete-*.sh` (stale card garbage collectors).
  - Systemd service units and timers (`cron`, `udp-custom`, `udp-request`, `dnstt`, `noobzvpns`, `xray@*`, `openvpn`).

- **Key Defect Targets & Auditing Criteria:**
  - Service restart storms: batch operations must execute at most one restart per transport per execution cycle (see Fix 250–257).
  - Service exit codes: ensure daemons return exit code `0` on successful runs (see Fix 294, 295).
  - File permissions: enforce `0600` on private keys (`xray.key`, `funny.pem`, bot tokens) and `0644` on public certificates (Fix 305).
  - Config mutation safety: clean removal using `/### <user> <exp>/ {N;d}` and trailing comma repair; never truncate or invalidate JSON.
  - Race conditions in temporary file operations: use atomic replacement (`mv` over staging file) instead of direct partial truncation.

---

### Phase 2: Input Boundary & Mutation Safety

Focuses on user input validation, EOF handling, and gating state modifications across account creation, modification, and deletion.

- **Scope:**
  - `full/add-*`, `lite/add-*`, `full/trial-*`, `lite/trial-*`.
  - `full/delete-*`, `lite/delete-*` (Xray, SSH, NoobzVPN, WireGuard, L2TP).
  - `full/extend-*`, `lite/extend-*`, `full/change-id-*`, `lite/change-id-*`, `full/change-quota-*`.
  - `full/routing-*`, `lite/routing-*`.
  - `full/xl2tp.sh`, `full/menu-noobz.sh`, `full/menu-wg.sh`.

- **Key Defect Targets & Auditing Criteria:**
  - Non-existent account guards: do not restart daemons, wipe files, or send notifications when accounts are not found (Fix 306).
  - Empty input / EOF handling: guard all `read` calls against empty input and terminal EOF (`|| exit 0` or `|| return`) to prevent unbounded loops or blank records (Fix 300, 308).
  - Error path fall-through: ensure early returns after error conditions or navigation returns (`goback`) to prevent executing mutations with invalid state (Fix 301).
  - Protocol-specific restrictions:
    - NoobzVPN: enforce 1–16 character name limit before invoking CLI; verify command exit status before saving panel records (Fix 302).
    - SSH/Dropbear: require non-empty passwords to avoid passwordless accounts (Fix 308).
    - WireGuard: validate alphanumeric names to avoid corrupted `wg0.conf` markers or broken file paths (Fix 300).
    - Routing scripts: require all fields (Name, Domain, Port, Password/UUID, Path) before modifying outbounds (Fix 309).

---

### Phase 3: Interactive TUI Menus & Navigation Integrity

Focuses on menu flow, operator traps, status display, and terminal state preservation.

- **Scope:**
  - `full/menu.sh`, `lite/menu.sh` (main menus).
  - `full/menu-x.sh`, `lite/menu-x.sh` and `x-*.sh` (transport menus).
  - `full/menu-ssh.sh` (SSH & proxy menu).
  - `full/menu-system.sh`, `lite/menu-system.sh` (system management).
  - `full/menu-bot.sh`, `lite/menu-bot.sh` (Telegram bot menu).
  - `full/menu-argo.sh`, `lite/menu-argo.sh` (Cloudflare Argo tunnel).
  - `full/menu-dnstt.sh`, `full/menu-noobz.sh`, `full/menu-wg.sh`, `full/xl2tp.sh`.
  - `full/bmenu.sh`, `lite/bmenu.sh` (backup & restore menu).

- **Key Defect Targets & Auditing Criteria:**
  - Navigation traps & Option 0: ensure every submenu contains an explicit Option `0` returning to parent menu, and that invalid inputs do not trap the user (Fix 287–290, 291, 292, 296).
  - Submenu action retention: after executing an action (create, delete, list, change), re-invoke the submenu instead of ejecting the operator back to the main menu or shell (Fix 294, 296, 297, 298, 299).
  - Screen wipe prevention: add explicit pauses (`read -n 1 -s -r -p "Press any key to return..."`) before screens are cleared so the operator can inspect credentials, status, or error messages (Fix 288, 293, 297, 298).
  - Formatting & branding: preserve operator contact information and layout consistency per Decisions 9, 26, and 27.

---

### Phase 4: Protocol Transports & Configuration Pipelines

Focuses on reverse proxy configurations, protocol templates, timeouts, and certificate management.

- **Scope:**
  - `config/4.conf`, `config/6.conf`, `config/dual.conf` (Nginx).
  - `json/ws.json`, `json/grpc.json`, `json/upgrade.json`, `json/split.json` (Xray).
  - `/etc/haproxy/haproxy.cfg`.
  - `installer/diamond.sh`, `full/dm-menu.sh`, `lite/dm-menu.sh` (domain and ACME issuance).
  - `installer/xray.sh`, `installer/ssh.sh`, `installer/noobz.sh`, `installer/slowdns.sh`, `installer/wg.sh`, `installer/l2tp.sh`.

- **Key Defect Targets & Auditing Criteria:**
  - Reverse proxy timeouts: maintain extended timeouts on streaming endpoints (e.g., SplitHTTP, gRPC) to prevent connection drops under large payloads (Fix 29).
  - Domain validation: require valid FQDNs before rewriting nginx server blocks, domain tracking files, or account cards (Fix 304, 307).
  - Certificate issuance & fallback: maintain automated ACME fallback to ZeroSSL and self-signed certificate generation to prevent startup failures on rate limits (Fix 140).
  - Template credentials: ensure all default credentials in JSON templates are randomized on install per Decision 14.
  - Port & transport mappings: adhere strictly to the canonical path and port schemes per Decisions 15 and 17.

---

### Phase 5: Backup, Restore & Administrative Safety

Focuses on disaster recovery, data persistence, and preventing privilege escalation.

- **Scope:**
  - `full/backup.sh`, `lite/backup.sh`.
  - `full/bmenu.sh`, `lite/bmenu.sh`.
  - `full/restore-ftp.sh`, `lite/restore-ftp.sh`, `website/restore-ftp.sh`.
  - `website/upload.php`, `website/install.sh`.

- **Key Defect Targets & Auditing Criteria:**
  - Channel isolation: Telegram-only delivery as document attachment; no public expiring file hosts or committed credentials (Decisions 11, 12).
  - Web restore authentication: strictly enforce `/etc/funny/.restore.key` token validation on `upload.php` before allowing file unpacking (Decision 19).
  - Restore permissions: ensure restored key files are set to `0600` immediately upon extraction (Fix 305).
  - Legacy backup compatibility: maintain repair loops in `bmenu.sh` for legacy archives without breaking current JSON structures.

---

### Phase 6: API Integration Layer (FN-API & Handlers)

Focuses on the headless REST API interface serving remote management and planned web interfaces.

- **Scope:**
  - `rohjagad/fn-autosc-api` (server, `lib.sh`, handlers).
  - `menu-api` (installer, status, token rotator).
  - Handlers in `/usr/bin/rere/*`.
  - Nginx `/api/` upstream proxy block.

- **Key Defect Targets & Auditing Criteria:**
  - Binding security: server must bind strictly to `127.0.0.1:9000` (Decision 18, `fn-api.md`).
  - Auth token security: verify `Authorization` header against `/etc/xray/.key` (mode `0600`).
  - Regex injection in lookups: escape usernames with `re_escape` before regex matching in deletion/search operations.
  - Concurrency serialization: handlers modifying shared state must acquire execution locks to prevent file corruption during concurrent requests.
  - Unsupported endpoint handling: `add-ss` and `add-socks` must return explicit unsupported errors rather than failing silently.

---

### Phase 7: Packaging, Sync & Distribution Consistency

Focuses on build reproducibility, binary parity, and archive synchronization.

- **Scope:**
  - `menu/full.zip`, `menu/lite.zip`.
  - Go source code and compiled binaries: `full/limit-ip.go`, `full/delete-ssh.go`, `full/extend-ssh.go`, `full/pwd-ssh.go`.
  - Installer scripts in `installer/` and root `install.sh`.

- **Key Defect Targets & Auditing Criteria:**
  - Archive byte-parity: all scripts modified in `full/` and `lite/` must be synchronized to `menu/full.zip` and `menu/lite.zip` with exact contents and executable permissions (`0755`).
  - Go compilation: compiled binaries in archives must be built on `linux/amd64` using Go standard toolchain with stripped symbols (`-ldflags="-s -w"`).
  - Dual edition parity: ensure fixes to shared functionality are applied consistently to both `full/` and `lite/` where applicable.

---

## 4. Execution Protocol & Verification Workflow

For every defect discovered and addressed:

1. **Reproduction & Live Baseline:**
   - Reproduce on the live VPS test environment or local harness.
   - Record exact pre-fix behavior and exit codes.
2. **Minimal Working Patch:**
   - Apply the most concise, edge-case-correct modification.
   - Run syntax check (`bash -n <script>` or `go vet`).
3. **Packaging & Deployment:**
   - Rebuild affected archives (`menu/full.zip`, `menu/lite.zip`) maintaining `0755` permissions.
   - Deploy script or binary to `/usr/bin/` on the live VPS.
4. **Live Verification:**
   - Verify post-fix behavior with both valid input and hostile/empty edge cases.
   - Confirm all dependent systemd units remain `active` with zero failed units.
5. **Documentation & Commit:**
   - Append defect details to `project-information/bugs-found.md`.
   - Append fix summary and verification results to `project-information/bugs-fixed.md`.
   - Record the four-check evaluation in `project-information/bug-fixes-regression.md`.
   - Commit with atomic git message referencing the fix number.
