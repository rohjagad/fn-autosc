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

- Host always has `/dev/kvm` ready. Multi-VM allowed (VM-1, VM-2, ...).
- Simple setup: 1 Debian 12 VM per test role (e.g. VM-1 = xray client, VM-2 = second IP for limit test).
- Each VM needs: `curl`, `xray-core` (same version as VPS), `ssh`, `wg-quick`, `noobz` client where needed.
- One VM is enough for most phases. Use 2 VMs only for: IP-limit (Fase 9), concurrency (Fase 16/20).

### Channel S: SSH TUI (pure keyboard)

- Connect: `ssh -p 3303 root@202.155.17.126`, then run `menu`.
- Rule: **keys only** — type menu numbers, `0` back, `Enter`, `Ctrl+D`. Do NOT run `/usr/bin/add-*` directly in this channel. If the menu cannot do it, that is a finding.
- Use a normal terminal (min 80x24, `TERM=xterm`). Screenshot or copy text for every screen you check.

---

## 2. TUI Quality Bar (applies to every phase)

Check these three on every screen you open:

1. **Wording:** simple words a junior IT understands. No typo. Same term everywhere (e.g. do not mix `Expired` / `Kadaluarsa` on one screen). Units shown (`GB`, `days`, `IP`).
2. **Navigation:** every number works. `0` goes back to parent, never drops to shell. Wrong number re-shows the menu. Empty `Enter` is rejected with a clear message, no crash. `Ctrl+D` (EOF) exits cleanly (`exit 0`).
3. **Layout tidiness:** header centered, separator lines same length, `Label : value` colons aligned, no wrapped/truncated lines at 80 cols, colors reset at end, account card stays on screen (pause) before clear.

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
- **K:** from VM: `curl` TLS handshake to domain:443 (expect TLS 1.3, valid cert); port 80 served without redirect loop; TCP open on 777 (stunnel-wrapped SSH, no HTTP banner by design).
- **S:** `menu-system` → nginx/haproxy status screens. Wording: `ON/OFF` consistent. Layout: port lists aligned.
- **PASS:** TLS ok, 80 ok, 777 TCP-only per `installer/stunnel5.sh`.

### Fase 3: SSH, Dropbear, SSH-WS, OHP

- **Goal:** all SSH front-ends accept password logins.
- **K:** VM-1: OpenSSH password login on 22 and 3303 (forward-only, shell `/bin/false` by design, `Could not chdir` message is cosmetic); Dropbear banner `SSH-2.0-dropbear_2019.78` on 111/109; WS path `/` reaches `wsEpro` (2080); OHP port 9088 TCP-open. Containment (every run): `ssh testcard_ssh_0X@host id` exits non-zero with no output; `sftp` and `scp` fail; `ssh -N -L <port>:127.0.0.1:80` still carries HTTP through (forwarding is the product, Decision 7); `ssh -X` gets no X11 channel (`X11Forwarding no`).
- **S:** `menu-ssh` → create `livetest_ssh*` via menu only. Check card: ports listed (`22, 3303`, `111, 109`), pause before clear, `0` back to main.
- **PASS:** logins work, banner exact, card readable; containment denials hold while forwarding works.

### Fase 4: Xray WebSocket (VMess, VLESS, Trojan)

- **Goal:** real payload through WS.
- **K:** create one account per proto; VM runs xray client (`/vmws`, `/vlws`, `/trws`, TLS 443); download 1–5 MB file; checksum == direct download. Repeat one via port 80 NonTLS.
- **S:** `menu-x` → create each account via TUI. Check: card shows `Path`, `Network: WebSocket`, full link; duplicate name rejected clearly.
- **PASS:** 3/3 checksums match, NonTLS ok.

### Fase 5: Xray gRPC (`vmgr`, `vlgr`, `trgr`)

- **Goal:** gRPC streaming works behind nginx.
- **K:** same as F4 but service names `vmgr`/`vlgr`/`trgr`; transfer >3 MB both directions.
- **S:** same TUI card checks in `menu-x` gRPC entries; wording `gRPC` spelled same everywhere.
- **PASS:** 3/3 transfers match.

### Fase 6: HTTPUpgrade + XHTTP

- **Goal:** modern transports work.
- **K:** HTTPUpgrade paths `/vmhu`, `/vlhu`, `/trhu`; XHTTP paths `/vmxh`, `/vlxh`, `/trxh` with `network: xhttp` (no `mode: packet-up` needed); 1 MB download each, checksum match.
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
- **S:** in each `add-*` screen: try empty name (rejected), bad chars (rejected, no shell eval), existing name (duplicate message), `0` for limit/quota/days (`0 not allowed`, Decision 4). Verify JSON has `"level": 0`.
- **PASS:** all rejections clean, JSON valid.

### Fase 9: IP-limit + lock/unlock

- **Goal:** concurrent-IP abuse locks, unlock restores.
- **K:** account limit-IP=1 (or 2); hold slow downloads from VM-1 + VM-2 at the same time; run `limit-ip-*`; expect card → `.locked`, JSON entry removed, sessions cut.
- **S:** do lock + `unlock-*` via TUI only. Confirm prompt `y/n` works, `n` cancels safely, re-unlock of already-present account prints skip message (no duplicate JSON).
- **PASS:** lock file exists, unlock restores same UUID, `Configuration OK.`

### Fase 10: Quota + full delete

- **Goal:** over-quota = deleted (Decision 16), not locked.
- **K:** small-quota account (e.g. 5 GB file quota tripped by test or usage-file plant + trickle traffic); run `quota-*`; expect JSON + quota + usage + card all gone, audit line in `.quota.logs`.
- **S:** create + delete via TUI; card gone, message says `deleted`, service stays active.
- **PASS:** total cleanup, valid JSON, both services active.

### Fase 11: Extend, password change, safe delete

- **Goal:** edits work, bad deletes harmless.
- **K:** SSH login with new password after `pwd-ssh` change.
- **S:** `extend-*` (date grows, format `YY-MM-DD`); `delete-*` existing (clean); `delete-* notarealuser999` (prints `User not found`, no restart, nothing deleted).
- **PASS:** date math right, new password works, phantom delete side-effect free.

### Fase 12: Expiry sweep (`xp` + cron)

- **Goal:** yesterday-expired accounts reaped, one restart per transport.
- **K:** none (server-side).
- **S:** plant expired `livetest_*` via TUI-created account + backdated marker; run `xp` from `menu-system`; verify gone from JSON + DB.
- **PASS:** exact accounts reaped, journal shows 1 stop/start per touched transport, no storm.

### Fase 13: Full TUI sweep + fault injection (TUI-focused)

- **Goal:** every menu survives operator mistakes and reads tidy.
- **K:** none.
- **S:** visit ALL: `menu`, `menu-x`, `menu-ssh`, `menu-wg`, `menu-noobz`, `menu-dnstt`, `menu-system`, `menu-bot`, `menu-argo`, `bmenu`, `dm-menu`. Per menu: press `0` (back to parent), `00` (spell/behavior), `99` (invalid re-show), empty Enter, `Ctrl+D`. Per numeric field: `0`, `-1`, `abc`, `1.5`, metachars (`;`, `$()`, `*`). Record every screen against the §2 quality bar (wording/navigation/layout). This is the main TUI-tidiness gate.
- **PASS:** zero crashes/hangs/shell-drops; all rejections worded; layout checklist clean.

### Fase 14: Domain move + cert fallback

- **Goal:** domain change safe, TLS never bricks.
- **K:** after valid change, TLS cert covers new name; traffic still flows.
- **S:** `dm-menu`: `bad domain` rejected, files unchanged; valid change updates domain file + nginx + new cards consistently. Cert-fail simulation (rate-limit 429) falls back without killing nginx/haproxy.
- **PASS:** invalid input harmless, valid move consistent, fallback keeps 443 up.

### Fase 15: Telegram backup + web restore

- **Goal:** backup arrives, restore needs the key.
- **K:** none (server-side + Telegram client).
- **S:** `bmenu` → backup: zip arrives as Telegram document with Domain/IP/Date caption, no public link. Restore page `:855/upload.php`: no token → 401, wrong token → 401, right token (`/etc/funny/.restore.key`) → extracted; restored `.key` back to `0600`.
- **PASS:** 401/401/ok, modes correct. (Destructive: snapshot first, restore to test box if possible.)

### Fase 16: REST API suite (FN-API)

- **Goal:** headless contract holds + concurrent safe.
- **K:** VM sends HTTP to `https://<domain>/api/*`: no-auth → 401, bad token → 401, traversal `..%2f` → deny (400 edge / 404 app, both deny); CRUD `ping`, `add-vmess`, `list-xray`, `renew-xray`, `delete-xray`; `add-ss`/`add-socks` → explicit unsupported error; 5× parallel `add-vmess` all succeed, JSON valid (single-threaded design).
- **S:** `menu-api status/install` screens: counts honest, `0` exits, invalid re-shows.
- **PASS:** auth matrix + CRUD + 5/5 parallel, per `fn-api.md`.

### Fase 17: XHTTP migration live

- **Goal:** rename `split`→`xhttp` complete in production.
- **K:** `add-vmess-xhttp` link decodes to `"net":"xhttp"`, path `/vmxh`; traffic checksum match; `/vmspl` unrouted; `core=xhttp` works, legacy `split` alias still accepted.
- **S:** card shows `Path: /vmxh`, `Network: XHTTP`; `delete-xhttp` via TUI leaves valid JSON + active service.
- **PASS:** traffic + card + alias + cleanup all green.

### Fase 18: Auth URL fallback (Pages → GitHub)

- **Goal:** license gate survives one source down.
- **K:** VM checks both URLs return same `###` count.
- **S:** `menu-api status` green on primary; block primary (temp `/etc/hosts`) → still green via fallback; block both → fail-closed (`Failed to download permissions.`, non-zero exit) before any mutation; remove blocks after.
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
- **S:** `cek-xray-*`, `list-ssh`, `cek-login-ssh` vs raw state (`grep '^###'`, `chage`, `passwd -S`): no fake `UNLOCKED`/`No Expiry`/`0/0`; missing-binary simulation errors explicitly (then restore binary).
- **PASS:** 1:1 ports/paths, no placeholder `server_name`, no false success.

---

## 6. Run Order & Cleanup

1. F1 → F2 → F3 (infra first; stop on red).
2. F4 → F5 → F6 → F7 (transports; one VM per proto set, reuse accounts).
3. F8 → F9 → F10 → F11 → F12 (lifecycle/enforcement; clean accounts between phases).
4. F13 (TUI sweep; can run in parallel with KVM transfers from another terminal).
5. F14 → F15 (domain/backup; snapshot first, most disruptive last among panel phases).
6. F16 (API; needs token from `/etc/xray/.key`, shred local copy after).
7. F17 → F18 → F19 (migration + auth; network mocks removed immediately after).
8. F20 → F21 (race + honesty; final `box-as-found`: 0 test accounts, valid JSONs, 0 failed units).

Log per phase: commands/keys pressed, expected vs actual, checksums, journal counts, and any TUI wording/layout photo or pasted screen.
