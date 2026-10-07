# Live-Testing Phase Plan

Live test for `fn-autosc` on VPS `202.155.17.126` (domain `autosc.rohcuan.dpdns.org`, SSH port `3303`).

Two test channels. Every phase uses both:

- **Channel K (KVM client):** real traffic from local VM(s). Proves data really flows.
- **Channel S (SSH TUI):** operator drives only the menus over SSH. Proves the TUI works.

```
VM-1 ──┐
VM-2 ──┼──(internet)──► VPS 202.155.17.126 (nginx, haproxy, xray, daemons)
VM-3 ──┘                      ▲
                              │ SSH -p 3303, run `menu`, press keys only
```

---

## 1. Test Channels

### Channel K: KVM clients (`/dev/kvm`)

- Host always has `/dev/kvm` ready. Multi-VM allowed (VM-1, VM-2, ...). **`/dev/kvm` VMs are the required traffic clients for every phase with K steps — no phase passes on Channel S alone where K steps exist.**
- Standard build (proven 2026-10-07): plain `qemu-system-x86_64` (no libvirt), Debian 12 cloud image + cloud-init seed (`tester`/`testpass`, SSH forwarded: VM-1 → `127.0.0.1:2221`, VM-2 → `127.0.0.1:2222`), 2 GB RAM each. Client tooling per VM: `curl`, `sshpass`, `xray-core` 25.3.6 (same as VPS), `wg-quick`, `openvpn` as the phase needs.
- Asset688888volatility: VM disks/seeds lived in `/tmp/opencode/kvm` (wiped on host reboot) — rebuild from base image + seeds if gone, or persist outside `/tmp` before the next round.
- One VM is enough for most phases. Use 2 VMs for: IP-limit (Fase 9), concurrency/loadbalance (Fase 20 + LB), parallel transport testing (Fase 6 went 2× faster split HU/XHTTP across VMs).
- KVM is also the fault-injection box: DROP/slow network mocks (Fase 18/19/22) run here, never on the VPS data path.
- Session hygiene (learned hard): NEVER `pkill -f "xray run"` over SSH — the pattern matches your own remote command line and kills the session; use `pkill -9 -x xray`. A backgrounded xray holds the SSH session open on exit — start clients in a held (background-shell) session and drive tests from separate calls.

### Channel S: SSH TUI (pure keyboard)

- Connect: `ssh -p 3303 root@202.155.17.126`, then run `menu`.
- Rule: **keys only** — type menu numbers, `0` back, `Enter`, `Ctrl+D`. Do NOT run `/usr/bin/add-*` directly in this channel. If the menu cannot do it, that is a finding.
- Use a normal terminal (min 80x24, `TERM=xterm`). Screenshot or copy text for every screen you check.

---

## 2. TUI Quality Bar (applies to every phase)

Check these three on every screen you open:

1. **Wording:** simple words a junior IT understands. No typo. Same term everywhere (e.g. do not mix `Expired` / `Kadaluarsa` on one screen). Units shown (`GB`, `days`, `IP`).
2. **Navigation:** every number works. `0` goes back to parent, never drops to shell. Wrong number re-shows the menu. Empty `Enter` is rejected with a clear message, no crash. `Ctrl+D` (EOF) exits cleanly (`exit 0`).
3. **Layout tidiness:** header centered, separator lines same length, `Label : value` colons aligned, no wrapped/truncated lines at 80 cols, colors reset at end, account card stays on screen (pause) before clear. Title/bottom separators rainbow `---` 35, inner dividers blue `---` 35, exactly 3 blank lines after each `clear`, picker lists green-numbered (`01.`) with `Total Accounts` and number-or-name input. Cards/notices: bare uppercase titles, `Protocol :` + `Transport:` rows, `DD-Mon-YYYY` dates, `XRAY` spelling, green-double titles / blue-single links in Telegram, titles centered on card width in TUI with left payload.

If any screen fails one of the three, note: menu name + option + what you typed + what you saw.

---

## 3. Safety Rules

1. **Test account names:** only `testcard*` or `livetest*`. Never touch `wgtest1`, `wglive1`.
2. **Snapshot before mutating:**
   ```bash
   cp -a /etc/xray/json /tmp/snap-xray-json
   cp -a /etc/funny /tmp/snap-funny
   cp -a /etc/wireguard /tmp/snap-wireguard
   ```
3. **Cleanup after each phase:** delete test accounts via the menu, remove `.locked` leftovers, confirm `xray run -test -config /etc/xray/json/<touched>.json` prints `Configuration OK.`, and `systemctl --failed` is `0`.

---

## 4. Mandatory References

Each phase result must be compared against these 7 sources, not judged by feeling:

| # | Source | Location | Role |
| :- | :--- | :--- | :--- |
| 1 | Bugs Fixed | `project-information/bugs-fixed.md` | The thing you test must still behave as fixed. |
| 2 | Original sources | `original-source-do-not-edit/V23...zip`, `.../1.20.zip` | Upstream behavior baseline. |
| 3 | Git history | `git log --stat` / `git log -p` | Why a limit/config exists. |
| 4 | Regression notes | `project-information/bug-fixes-regression.md` | Section-35 rule: rejecting bad input is not a bug. |
| 5 | Bugs Found | `project-information/bugs-found.md` | Old failure cases must stay fixed. |
| 6 | FN-API spec | `project-information/fn-api.md` | Contract for Fase 16. |
| 7 | Decisions | `project-information/is-decision.md` | If behavior matches a decision (e.g. Xray 25.3.6, Dropbear 2019.78, SSH accounts `-s /bin/false -M`, quota = full delete, `0` rejected), it is PASS, not fail. |

---

## 5. Phase Map (21 phases)

```
F1 baseline → F2 proxy/TLS → F3 SSH → F4 WS → F5 gRPC → F6 HTTPUpgrade+XHTTP
→ F7 tunnels → F8 create/dup → F9 IP-limit/lock → F10 quota → F11 extend/pwd/delete
→ F12 expiry xp → F13 TUI sweep + fault injection → F14 domain/cert
→ F15 backup/restore → F16 API → F17 XHTTP migration → F18 auth fallback
→ F19 gate hardness → F20 daemon race → F21 drift + tool honesty
```

Each phase below lists: **Goal**, **K** (client traffic), **S** (menu walk), **PASS**.

### Fase 1: Baseline OS, permissions, sysctl

- **Goal:** host healthy before traffic.
- **K:** none (no traffic yet).
- **S:** open `menu` → `menu-system` → status screens. Check quality bar: version lines readable, no overflow.
- **Steps:** 16 units active (`nginx`, `haproxy`, `xray@ws`, `xray@grpc`, `xray@upgrade`, `xray@xhttp`, `noobzvpns`, `dnstt`, `wg-quick@wg0`, `openvpn`, `xl2tpd`, `dropbear`, `ws`, `fn-ohp`, `udp-custom`, `udp-request`); `systemctl --failed` = 0; modes `0600` on `/etc/xray/xray.key`, `/etc/haproxy/funny.pem`, `/etc/xray/.key`, `0640` on `/etc/funny/.restore.key`, `0644` on crt; `fs.file-max=1000000`, `nf_conntrack_max=262144`.
- **PASS:** all active, 0 failed, modes exact, TUI status matches `systemctl`.

### Fase 2: Nginx, HAProxy, TLS inbound

- **Goal:** port 443/80 routing correct.
- **K:** from VM: `curl` TLS handshake to domain:443 (expect TLS 1.3; installs ship **self-signed** by default with CN = install domain — trusted LE/ZeroSSL only after manual Domain-menu issuance, so do NOT expect a public chain on fresh installs); port 80 served without redirect loop; TCP open on 777 (stunnel-wrapped SSH, no HTTP banner by design).
- **S:** `menu-system` → nginx/haproxy status screens. Wording: `ON/OFF` consistent. Layout: port lists aligned.
- **PASS:** TLS ok, 80 ok, 777 TCP-only per `installer/stunnel5.sh`.

### Fase 3: SSH, Dropbear, SSH-WS, OHP

- **Goal:** all SSH front-ends accept password logins.
- **K:** VM-1: OpenSSH password login on 22 and 3303 (forward-only, shell `/bin/false` by design, `Could not chdir` message is cosmetic); Dropbear banner `SSH-2.0-dropbear_2019.78` on 111/109; WS path `/` reaches `wsEpro` (2080); OHP port 9088 TCP-open. Containment (every run): `ssh testcard_ssh_0X@host id` exits non-zero with no output; `sftp` and `scp` fail; `ssh -N -L <port>:127.0.0.1:80` still carries HTTP through (forwarding is the product, Decision 7); `ssh -X` gets no X11 channel (`X11Forwarding no`).
- **S:** `menu-ssh` → create `livetest_ssh*` via menu only. Check card: ports listed (`22, 3303`, `111, 109`), pause before clear, `0` back to main.
- **PASS:** logins work, banner exact, card readable; containment denials hold while forwarding works.

### Fase 4: Xray WebSocket (VMess, VLESS, Trojan)

- **Goal:** real payload through WS.
- **K:** create one account per proto; VM runs xray client (`/vmws`, `/vlws`, `/trws`, TLS 443); download 1–5 MB file; checksum == direct download. Repeat one via port 80 NonTLS. Spot-check one color alias (e.g. `/red` vs `/vmws`) returns the identical status.
- **S:** `menu-x` → create each account via TUI. Check: bare `ACCOUNT DETAIL` title, `Protocol :` + `Transport:` rows, `Network: WebSocket`, full link; duplicate name rejected clearly. Sequential creates rotate color-only link paths (canonical paths never appear in links — decode 2+ links to confirm), and `Path Alt`/`Service Alt` rows list the rotation set.
- **PASS:** 3/3 checksums match, NonTLS ok.

### Fase 5: Xray gRPC (`vmgr`, `vlgr`, `trgr`)

- **Goal:** gRPC streaming works behind nginx.
- **K:** same as F4 but service names `vmgr`/`vlgr`/`trgr`; transfer >3 MB both directions. Spot-check one color service alias returns the canonical status.
- **S:** same TUI card checks in `menu-x` gRPC entries; wording `gRPC` spelled same everywhere.
- **PASS:** 3/3 transfers match.

### Fase 6: HTTPUpgrade + XHTTP

- **Goal:** modern transports work.
- **K:** HTTPUpgrade paths `/vmhu`, `/vlhu`, `/trhu`; XHTTP paths `/vmxh`, `/vlxh`, `/trxh` with `network: xhttp` (no `mode: packet-up` needed); 1 MB download each, checksum match. Spot-check one color alias per path the same way as F4.
- **S:** card must show `Network: HTTP Upgrade` / `Network: XHTTP` with correct path. Old path `/vmspl` must not appear anywhere.
- **PASS:** 6/6 match, no stale path text.

### Fase 7: Tunnels (WireGuard, Noobz, SlowDNS, L2TP, OpenVPN)

- **Goal:** each tunnel connects (or fails only for documented reason).
- **K:** WG: `wg-quick up`, ping `10.66.66.1`. Noobz on 8080/8443 with payload auth. SlowDNS via UDP 53 (needs public NS delegation — note if skipped). L2TP: SA forms (cloud kernel has no PPP data path — note if control-only). OpenVPN TCP 1194 + UDP 2200, TLS handshake ok.
- **S:** `menu-wg`, `menu-noobz`, `menu-dnstt` → create `livetest_*` via TUI; card per tunnel complete and pause-readable.
- **PASS:** WG + Noobz + OpenVPN live; SlowDNS/L2TP judged per known-limitation note, not as fail.

### Fase 8: Create cycle + duplicate guard

- **Goal:** accounts created cleanly, doubles refused.
- **K:** none extra (accounts from F4–F7 reused).
- **S:** in each `add-*` screen: try empty name (rejected), bad chars (rejected, no shell eval), existing name (duplicate message), `0` for limit/quota/days (`0 not allowed`, Decision 4). Verify JSON has `"level": 0`. Rotation: sequential creates spread across canonical + colors (`/etc/xray/.colorseq` advances; decode links to confirm), and across domains when extras exist (`/etc/xray/.domainseq`; card shows used `Domain` + available `Domains`).
- **PASS:** all rejections clean, JSON valid.

### Fase 9: IP-limit + lock/unlock

- **Goal:** concurrent-IP abuse locks, unlock restores.
- **K:** account limit-IP=1 (or 2); hold slow downloads (`curl --limit-rate`, 10 MB file) from VM-1 + VM-2 at the same time; confirm `statsonline` reads 2, then run `limit-ip-*`; expect card → `.locked`, JSON entry removed, sessions cut. Same-NAT caveat: two VMs behind one host egress share ONE source IP — route VM-2 through a WG tunnel account so the VPS sees tunnel IP as the 2nd address (proven 2026-10-07); restart VM-2's xray AFTER `wg-quick up` so its connection actually traverses the tunnel.
- **S:** do lock + `unlock-*` via TUI only (direct unlock, no confirmation). Multilogin locks auto-lift (~15 min via cron sweeper — verify due-epoch file in `/etc/xray/autounlock/<t>/`); manual locks stay indefinite. Confirm re-unlock of already-present account prints skip message (no duplicate JSON).
- **PASS:** lock file exists, unlock restores same UUID, `Configuration OK.`

### Fase 10: Quota + full delete

- **Goal:** over-quota = deleted (Decision 16), not locked.
- **K:** small-quota account (e.g. 5 GB file quota tripped by test or usage-file plant + trickle traffic); run `quota-*`; expect JSON + quota + usage + card all gone, audit line in `.quota.logs`.
- **S:** create + delete via TUI; card gone, message says `deleted`, service stays active.
- **PASS:** total cleanup, valid JSON, both services active.

### Fase 11: Extend, password change, safe delete

- **Goal:** edits work, bad deletes harmless.
- **K:** SSH login with new password after `pwd-ssh` change.
- **S:** `extend-*` (date grows, format `DD-Mon-YYYY`); `delete-*` existing (clean); `delete-* notarealuser999` (prints `User not found`, no restart, nothing deleted).
- **PASS:** date math right, new password works, phantom delete side-effect free.

### Fase 12: Expiry sweep (`xp` + cron)

- **Goal:** yesterday-expired accounts reaped, one restart per transport.
- **K:** none (server-side).
- **S:** plant expired `livetest_*` via TUI-created account + backdated marker; run `xp` from `menu-system`; verify gone from JSON + DB.
- **PASS:** exact accounts reaped, journal shows 1 stop/start per touched transport, no storm.

### Fase 13: Full TUI sweep + fault injection (TUI-focused)

- **Goal:** every menu survives operator mistakes and reads tidy.
- **K:** none.
- **S:** visit ALL: `menu`, `menu-x`, `menu-ssh`, `menu-wg`, `menu-noobz`, `menu-dnstt`, `menu-system`, `menu-bot`, `menu-argo`, `bmenu`, `dm-menu`. Per menu: press `0` (back to parent), `00` (spell/behavior), `99` (invalid re-show), empty Enter, `Ctrl+D`. Per numeric field: `0`, `-1`, `abc`, `1.5`, metachars (`;`, `$()`, `*`). `dm-menu` options are 1–6 + 0 (add/remove/list, cert-per-chosen-domain ×3); stacked screens separated by blank-line air; picker lists numbered with number-or-name input; per-domain cards aligned. Record every screen against the §2 quality bar (wording/navigation/layout). This is the main TUI-tidiness gate.
- **PASS:** zero crashes/hangs/shell-drops; all rejections worded; layout checklist clean.

### Fase 14: Domain list, rotation, and cert safety

- **Rotation semantics (operator rule):** rotation is link-text insertion ONLY — the rotated domain is substituted into link hosts on the card; no connection/server-side change (all domains terminate on the same VPS/nginx). There is NO default domain: the installer domain is the primary entry, extras round-robin via `/etc/xray/.domainseq` with no implicit default. Telegram cards show `Domains :` (full list) only; TUI/`.log` keep `Domain :` + `Domains :`.
- **Goal:** extra domains add cleanly, rotation spreads, TLS never bricks.
- **K:** add nip.io-style or operator test domains pointing here (proven set: primary + 2 extras); `openssl s_client` shows each in SANs after the auto self-sign; decode N sequential links to prove round-robin across ALL domains with no stickiness; remove extras one by one; LE cert restored byte-identical after (back up `/etc/xray/xray.crt/.key` before, restore + reload after).
- **S:** `dm-menu`: options 1–6 present; `bad domain` rejected, files unchanged; add validates + dedupes; list shows one shared-framed card per domain with matching protocol counts; remove empties the file and restores single `server_name` (no `.tmp` leftovers). Options 4–6 pick a domain first — test ONLY the cancel path (invalid choice returns clean, no issuance ever runs in tests: LE rate limits); unpointed domains print the skip notice instead of failing issuance.
- **PASS:** add/remove/list round-trip clean; cancel paths write nothing; cert identical after restore; nginx -t clean throughout.

### Fase 15: Telegram backup + web restore

- **Goal:** backup arrives, restore needs the key.
- **K:** none (server-side + Telegram client).
- **S:** `bmenu` → backup: zip arrives as Telegram document with Domain/IP/Date caption, no public link. Without bot creds the backup must fail safe: archive staged, clear `Telegram credentials are not configured` message, archive KEPT at `/root/backup.zip`, exit 0, no hang. Restore page `:855/upload.php`: no token → 401, wrong token → 401, right token (`/etc/funny/.restore.key`) → extracted; restored `.key` back to `0600`.
- **PASS:** 401/401/ok, modes correct. (Destructive: snapshot first, restore to test box if possible.)

### Fase 16: REST API suite (FN-API)

- **Install:** the API is NOT in this repo — clone `rohjagad/fn-autosc-api` on the VPS and run its `menu-api` option 1 (install). Token lands in `/etc/xray/.key` (`0600`); service `api.service` binds `127.0.0.1:9000`.
- **Goal:** headless contract holds + concurrent safe.
- **K:** VM sends HTTP to `https://<domain>/api/*`: no-auth → 401, bad token → 401, traversal `..%2f` → deny (400 edge / 404 app, both deny); CRUD `ping`, `add-vmess`, `list-xray`, `renew-xray`, `delete-xray`; `add-ss`/`add-socks` → explicit unsupported error; 5× parallel `add-vmess` all succeed, JSON valid (single-threaded design).
- **S:** `menu-api status/install` screens: counts honest, `0` exits, invalid re-shows.
- **PASS:** auth matrix + CRUD + 5/5 parallel, per `fn-api.md`.

### Fase 17: XHTTP migration live

- **Goal:** rename `split`→`xhttp` complete in production.
- **K:** `add-vmess-xhttp` link decodes to `"net":"xhttp"`, path `/vmxh`; traffic checksum match; `/vmspl` unrouted; `core=xhttp` works, legacy `split` alias still accepted.
- **S:** card shows `Path: /vmxh`, `Network: XHTTP`; `delete-xhttp` via TUI leaves valid JSON + active service.
- **PASS:** traffic + card + alias + cleanup all green.

### Fase 18: Auth URL race (Pages + GitHub, first valid wins)

- **Goal:** license gate survives one source down.
- **K:** VM checks both URLs return same `###` count.
- **S:** `menu-api status` green on primary; block primary (temp `/etc/hosts`) → still green (race: whichever valid reply arrives first wins, Decision 29); block both → fail-closed (`Failed to download permissions.`, non-zero exit) before any mutation; remove blocks after.
- **PASS:** green/green/fail-closed, box clean after.

### Fase 19: Gate hardness (network + matching)

- **Goal:** gate never passes open or on wrong IP.
- **K:** block `ifconfig.me` → explicit fail (no empty-IP continue); serve HTML error as `izin.txt` (local mock) → reject, nothing printed; substring test (`11.2.3.44` must not pass `1.2.3.4`) on a gate copy; broken/empty date → fail-closed.
- **S:** each refusal message exact (`Your IP is not in the database`, etc.), no DB leak to output; production gate green after mocks removed.
- **PASS:** all closed, messages exact.

### Fase 20: Daemon race + restart audit

- **Goal:** shared JSON stays valid when daemons collide; restarts counted.
- **K:** plant N triggers (expired + over-quota + over-IP `livetest_*`); fire `xp` + `limit-ip-*` + `quota-*` together; count `Stopping xray@<t>` in journal; next `*/5` cron tick with no triggers → zero restarts.
- **S:** observe via `menu-system` log/status screens (no direct daemon edits).
- **PASS:** valid JSON, right accounts reaped/locked, 1 restart per touched transport per run, 0 failed units.

### Fase 21: Template drift + tool honesty

- **Goal:** template = installed = card; tools tell the truth.
- **K:** new account link UUID/password == JSON; deleted == gone everywhere.
- **S:** `cek-xray-*`, `list-ssh`, `cek-login-ssh` vs raw state (`grep '^###'`, `chage`, `passwd -S`): no fake `UNLOCKED`/`No Expiry`/`0/0`; missing-binary simulation errors explicitly (then restore binary). Drift matrix: 36 color locations present with canonical-matching status; rotated link paths + domains decode valid; `server_name` lists primary + extras with no placeholder.
- **PASS:** 1:1 ports/paths, no placeholder `server_name`, no false success.

---

## 6. Run Order & Cleanup

1. F0 fresh-install baseline (when re-imaging): wipe via `bin456789/reinstall` (preserve root password with `--password`), `apt install curl screen`, pipe `full` + Domain + Email + `dual` + SlowDNS-NS into `install.sh` from `main` HEAD. Verify F1 before any traffic.
2. F1 → F2 → F3 (infra first; stop on red).
3. F4 → F5 → F6 → F7 (transports; one VM per proto set, reuse accounts; split across 2 VMs for speed).
4. F8 → F9 → F10 → F11 → F12 (lifecycle/enforcement; clean accounts between phases).
5. F13 (TUI sweep; can run in parallel with KVM transfers from another terminal).
6. F14 → F15 (domain/backup; snapshot first, most disruptive last among panel phases).
7. F16 (API; needs token from `/etc/xray/.key`, shred local copy after).
8. F17 → F18 → F19 (migration + auth; network mocks removed immediately after).
9. F20 → F21 (race + honesty; final `box-as-found`: 0 test accounts, valid JSONs, 0 failed units).
10. LB (loadbalance = nginx active): 4 concurrent 10 MB downloads across WS+HU+XHTTP+gRPC from both VMs, all checksums match — proves the 443/80 frontend fans out under load.

Log per phase: commands/keys pressed, expected vs actual, checksums, journal counts, and any TUI wording/layout photo or pasted screen.
