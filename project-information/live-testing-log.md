# Live-Testing Log — Fresh Reinstall Round (October 8, 2026)

VPS `157.10.253.95`, fresh Debian 12 via `bin456789/reinstall` (`--password` preserved),
panel `full` installed from `main` (`full` + `autosc.rohcuan.dpdns.org` +
`rohjagad@gmail.com` + `4` + `slowdns.rohcuan.dpdns.org`). Clients: KVM VM-1
(`2221`) + VM-2 (`2222`), xray 25.3.6. Ref hash file `f9test.bin` (10 MB,
`54bce9d3e0df`); `f4test.bin` (5 MB, `dffac395ec4b`).

| Phase | Result |
| :-- | :-- |
| F0 reinstall | Debian 12 fresh, SSH 22, same password. Install `INSTALL SUCCESS`, screen session. |
| F1 baseline | 16/16 units active, 0 failed, perms `600` key/pem, `640` restore key, `644` crt, sysctl exact. (`.key` absent until F16 — by design.) |
| F2 TLS/ports | Self-signed CN install domain, WS 400, port 80 101/200, 777 TCP-open. |
| F3 SSH | Password auth 22+3303 ok (`/bin/false`, cosmetic chdir msg), Dropbear `2019.78` on 111/109, sftp/scp dead, `-L` forwarding carries HTTP (`101`), OHP open. |
| F4 WS | 3/3 checksums match (`dffac395ec4b`) + NonTLS match; 443 parity 400 all; color-only rotation (`/red`,`/lime`,`/azure`). |
| F5 gRPC | **Found 472 live**: color services dead (upstream instant 200/0B, `$uri` un-rewritten — `^.*/\/<name>` needs double slash). Fix 452 deployed+reloaded → 3/3 MATCH (`black`,`ivory`,`orchid`). |
| F6 HU+XHTTP | HU MATCH. XHTTP all-dead → **Found 473**: `rewrite /(.*)` drops session uuid (client `unexpected status 404`). Fix 453 (suffix-preserving) → color `/purple` MATCH. |
| F7 tunnels | WG tunnel ping ok (stale DOWN interface confused early tests — client hygiene). OpenVPN `Initialization Sequence Completed` via Squid+PAM. Noobz 8080 `101` transport (auth layer unverified). L2TP account created (data-path note stands). SlowDNS skipped (no public NS delegation). |
| F8 create/dup | Empty/bad/dup/`0` all rejected with worded messages; `"level": 0` present. |
| F9 IP-limit | statsonline counts **sessions** (proven: value 2 from one IP) — tunnel detour unnecessary. 2 sessions vs limit 1 → locked (JSON clean, autounlock epoch file). TUI unlock restores **same UUID**, config OK. (VM2 tunnel-TCP rabbit hole: TCP via wg2 fails while ICMP passes — environment note, not panel.) |
| F10 quota | Planted over-quota reaped by cron tick: JSON+card+quota+usage+limit gone, audit line present, config OK. (Manual run skips counter-less accounts — correct idle behavior.) |
| F11 edits | pwd change proven (new RC=1 auth, old RC=5 denied); extend +15d exact (Nov 07 → Nov 22); phantom delete side-effect free (0 restarts); number-pick deletes listed account. |
| F12 expiry | Backdated marker reaped exactly, 1 restart per mutating run, no storm, config OK. |
| F13 TUI sweep | All 11 menus survive 99/0/empty/EOF; numeric abuse reworded; empty unlock holds message; bot creds notice shows; SSH `Username Login Type` table; dm-menu 6 options. |
| F14 domains | `bad domain` rejected; nip.io extra added (nginx reload, SAN auto-cover both); cards `Domains :` only; remove restores single `server_name`; LE cert restored, no `.tmp` leftovers. (Stale old VPS IP `202.155.17.126` visible in one display — cosmetic, from auth DB.) |
| F15 backup | No-creds fail-safe exact (message + staged 600 archive kept). POST 401/401. **Found 474**: web restore dead — `/etc/sudoers.d` + `visudo` missing at website-install time (see `fn-install.log`). Fix 454 → right-token restore `SUCCESSFULLY RESTORED`, 4/4 JSONs OK, 0 failed, perms kept. |
| F16 API | Installed via `menu-api` (127.0.0.1:9000, `.key` 600). Matrix 401/401/400-deny + ping ok; add/list/renew (`days`)/delete ok; `add-ss` explicit unsupported; 5/5 parallel ok. |
| F17 xhttp | Link decodes `xhttp`+color path; `/vmspl` unrouted; `core=xhttp` + legacy `split` alias both success; TUI delete leaves valid JSON + active service. |
| F18 auth | Pages 5 = GitHub 5; primary-blocked → fallback 5; both-blocked → fail-closed; hosts cleaned. |
| F19 gates | Substring denied (`-wF`), HTML-izin rejected, fetches capped (code), fail-closed (F18 live). |
| F20 race | Parallel `xp`+`quota`+`limit` → exact reap, valid JSON, trigger-gated restarts only, 0 failed. |
| F21 honesty | Counts match raw `###`; 36 colors; single primary `server_name`; missing binary errors explicitly (restored after). |
| LB | 4 concurrent 10 MB downloads WS+HU (VM-1) + XH+gRPC (VM-2), all `54bce9d3e0df`. |

Cleanup: all 14 Xray + SSH + 2 WG + L2TP + Noobz test accounts deleted via menus,
test bins + zips removed, 4/4 JSONs `Configuration OK`, 0 failed units, 0
`livetest` residue, no `.locked` leftovers.

## Time/Scheduling Audit (October 8, 2026, follow-up)

Schedules observed live: `backup 0 0,6,12,18`, `xp 0,15,30,45`,
`limit-ip`/`auto-delete`/`kill`/`expire-ssh` every 5 min (16 `flock` lines in
`/etc/crontab`), fixnet timers, self-signed cert 1 year (Oct 2026–2027).

- **Multilogin auto-lift watched end-to-end:** daemon-identical lock planted
  with 90 s fuse (`sed` remove + card to `.locked` + due epoch); the `*/5`
  cron tick restored the account with the **identical UUID** and consumed the
  state file. Real due (`+600`) therefore lifts within ~10–15 min. PASS.
- **Manual lock indefinite:** locked via menu (no due file written); survived
  the next cron tick still locked; TUI unlock restored same UUID. PASS.
- **statsonline semantics (note, not a bug):** the `online` value counts
  distinct source IPs with live traffic — idle clients and same-IP sessions
  read 1/empty. F9-style triggering needs 2 IPs or lucky CGNAT rotation.
- **atd active** on fresh install; SSH limiter still uses `at` (unchanged).
- **Operator error (twice):** `pkill -x xray` on the VPS kills the server
  daemons too (client and server share the process name). Recovered both
  times via `systemctl restart xray@*` (all active, configs re-validated).
  Lesson: never `pkill -x xray` on the VPS; kill clients from the VM side.

## SlowDNS End-to-End Proof (October 8, 2026)

- Built `dnstt-client` from the operator fork (`rohjagad/dnstt`, same source
  the installer builds the server from) plus upstream master for comparison.
- Red herrings killed along the way: client "begin session" prints
  unilaterally (no server contact needed); direct-resolver, resolver-chain
  simulation, version match, and MTU tweaks all behaved identically.
- Root cause of all remote failures: **this lab network filters QTYPE=TXT**
  (TXT to 8.8.8.8 also unanswered, A fine) — every remote tunnel query died
  on our side, never the server.
- Proof run **on the VPS via loopback** (no network filtering involved):
  fork-built client → `:5300` → banner
  `SSH-2.0-OpenSSH_9.2p1 Debian-2+deb12u10` received through the tunnel.
  Same pair also round-trips locally (echo target). SlowDNS panel/server/keys
  are correct.
- Still required for real clients: a live `slowdns` NS delegation (globally
  NXDOMAIN at time of writing) plus a standard SlowDNS client app.

## Untested-Areas Round (October 8, 2026)

- **SSH multilogin lock (new Fix-455 code):** 2 logins (VPS-local + host,
  distinct IPs) vs limit 1 → `passwd -l` locked + due file armed. Sweeper
  half already proven. PASS. (Note: `addssh` rejects uppercase — operator
  typo, not a bug.)
- **WARP:** Found 476 fixed (persist + keepalive + IPv4), peer survives
  restart as a single block, keepalives egress. Cloudflare handshake
  unanswered — external. Test peer removed.
- **Scheduled backup:** temporary `*/2` cron fired, zip gone afterwards =
  Telegram `ok:true` (code deletes only on receipt). Cron restored.
- **Argo:** needs interactive Cloudflare OAuth — operator step, not run.
- **VM lab note:** `pkill -x` cannot match >15-char names (use `pkill -f`
  with bracket guard, or PIDs); QEMU guests need `-device virtio-rng-pci`
  or first boot stalls silently; `kill -9` on VM disks risks auth DB
  damage (rebuilt both from base).

## Live round 2026-10-09 (test box 202.155.17.126) — F9 counter evidence

- `livetest_ipl2` (vless-grpc, limit-IP 1): statsonline=1 with (a) single flow, (b) VM + VPS-local flows (distinct TCP sources 10.66.66.2-via-WG and 127.0.0.1), (c) two parallel VM clients. xray sees all inbounds from 127.0.0.1 (nginx reverse-proxy, no PROXY protocol) → online caps at 1 → `cek > limit` unreachable. Recorded as Found 489; xray multilogin lock judged BLOCKED-by-topology, SSH limits tested separately.

## Live round 2026-10-09 — F10-ws correction + LB rerun notes

- `livetest_f801` (plant usage > quota): reaped by `kill-ws` file-based pass (marker gone, quota files gone, audit card in `.quota.logs`, ws.json `Configuration OK`). F10-ws PASS via kill daemon.
- LB first run anomalies explained (both test artifacts): ws leg failed because f801 was reaped mid-run by the same plant; grpc leg truncated (9.9/10 MB) by curl `--max-time 35` under 4-way contention. Rerun with live account + longer windows.

## Live round 2026-10-09 (test box 202.155.17.126, full plan execution) — VERDICT

- **F1:** 16/16 units active, 0 failed, key modes exact (600/600/640/644), sysctl exact. `/etc/xray/.key` absent (no API yet — installed in F16, removed after). PASS.
- **F2:** TLS 1.3 self-signed (expected), 80→200, 777 TCP-open, `/`→101 (WS catch-all). PASS.
- **F3:** SSH TUI-create ok; login 22+3303 ok (cosmetic chdir msg); dropbear banners exact; `id` rc=1 no output; sftp closed; `-L` carries HTTP 200; `-X` refused; OHP 9088 open. PASS.
- **F4:** vmess/vless/trojan WS-TLS 3/3 checksums match + NonTLS match + alias 400/400. Rotation fntest→fntest1 + colors cycling per account. PASS.
- **F5:** gRPC 3/3 transfers match (services black/ivory/orchid across both domains). PASS.
- **F6:** HU 3/3 + XHTTP 3/3 match; no `/vmspl` anywhere. PASS.
- **F7:** WG 2 accounts endpoints rotate + ping 10.66.66.1 ~26ms w/ handshake+transfer (initial 100% loss was stale interface state, clean cycle green); Noobz 101 on 8080 + TLS alert on 8443 (full login needs official client — known); SlowDNS loopback proof (dnstt-client built from fork, `begin session` + SSH banner through :5300); OpenVPN 1194 live-reject + 2200 silent pre-auth; L2TP control-only (known). WG/Noobz/L2TP cards now `Domains` (Fix 468). PASS per known-limitation notes.
- **F8:** empty/dup/0 guards proven; JSON `level:0`; rotation proven. PASS.
- **F9:** SSH lock (2 sources: lab-IP + WG-tunnel-IP) → `passwd -L`, due file, sweeper auto-lift proven sticky after log window aged (10-min R12 window caused 2 relocks — expected, not a bug). Xray multilogin BLOCKED-by-topology (Found 489). PASS (SSH) / documented (xray).
- **F10:** grpc full delete + audit line + valid JSON (quota-grpc via service loop); ws via kill-ws file pass (Found 491 correction). PASS.
- **F11:** extend +10d exact; phantom delete clean (stderr now silenced, Fix 467 deployed? repo-only — box runs old delete scripts; re-verify after deploy); pwd change + new-pw login ok. PASS.
- **F12:** planted f802 reaped, f801 intact, 1 restart, JSON valid, 0 failed. PASS. (Note: live plan says "run xp from menu-system" but no such menu entry — xp is cron/CLI; plan text slightly off.)
- **F13:** all 11 menus 0/99/empty/EOF clean, no crash/hang/shell-drop; WG/Noobz explicit invalid messages; dm-menu/bmenu re-show silently (allowed). Empty locked-list: `locked-xray-*` is a LOCK ACTION not a viewer — phantom input exposed Found 492. PASS (with 492 fixed).
- **F14:** nip.io add (nginx ok, SAN all 3), rotation dom1/2/3 across all 3 domains, nip.io traffic 200, remove #2 only (fntest1 untouched), server_name rebuilt, nginx -t clean. PASS.
- **F15:** no creds → exact fail-safe message + 3.7MB archive kept 0600 + exit 0. PASS.
- **F16:** API installed via menu-api (service active, .key 0600); 401/401/ping/traversal-404/unsupported-error/CRUD/5-parallel/JSON-valid; uninstalled after (service gone; note: uninstall keeps `.key` + `menu-api` — api-repo scope, logged). PASS.
- **F17:** XHTTP traffic+cards proven (F6); `core=xhttp`/legacy-alias via API not exercised — partial.
- **F18:** Pages blocked → gate exit 0 via GitHub; hosts restored; 6/6 content equal. PASS.
- **F19:** covered by Fix 466 (repo) + content equality; box runs pre-466 gates (deploy pending). Partial.
- **F20:** concurrent limiters → 4/4 JSON valid + 0 failed. PASS.
- **F21:** server_name correct, 36 ALT live, nginx -t clean; SSH table check inconclusive (banner matched first — recheck next round).
- **LB:** 4-way concurrent 10MB: ws/hu/xh byte-identical + grpc identical sequential (concurrent grpc truncated by curl max-time twice — client-side artifact, prefix byte-identical). PASS.
- **Findings this round:** 487 (delete stderr leak) → Fix 467; 488 (tunnel cards singular) → Fix 468; 489 (xray IP-limit unreachable, DEFERRED — needs PROXY protocol); 490 (retracted by 491); 491 (kill-ws enforces WS quota — correction, no code); 492 (phantom lock) → Fix 469.
- **Box-as-found:** 0 test accounts, JSONs valid, 0 failed units, server_name 2-domain, wg 0 peers active, no artifacts (self-match lesson: never `pkill -f` a pattern appearing in your own rm/scp args — use `pkill -x`).
- **Lab notes:** both VM images had aborted journals (unclean Oct-8 host shutdown) — rebuilt from base; kill stale QEMUs before reboot (port conflicts); QEMU `-nographic`+`-daemonize` incompatible; VM needs `-device virtio-rng-pci` + `media=cdrom` seed.

## Sync + re-verify 2026-10-09 (test box, operator: box is test-only, safe)

- Full `/usr/bin` sync from repo (138 KB tarball, sha256 match both ends, `bash -n` per file pre-install). Guard strings present in deployed `quota-grpc`/`limit-ip-ssh`/`bmenu`.
- Fix 466 re-proven ON BOX with deployed code: `calculate_remaining_days "garbage-date"` → `Permission data invalid.` + exit 1, no fall-through. F19 closed.
- Fix 467 re-proven ON BOX: `delete notarealuser999` (non-empty DB) → `not found` ×1, zero `cannot stat`/`No such file`. (Two earlier "0" readings were artifacts: empty-DB early-exit path + piped-stdin-never-echoed check.)
- VM-2 rebuilt from base image (old disk had same aborted journal), provisioned xray 25.3.6, UP on :2222. Both VMs warm.
- Lesson: never `pkill -f` a pattern that also appears in your own command's rm/scp args — it kills your own session (hit twice: `18081:` forward spec, `/tmp/dnstt-client` rm path). Use `pkill -x` (exact, ≤15 chars) or bracket-guards on BOTH sides.

## F9 remainder 2026-10-09 — manual lock + re-unlock skip (test box)

- Manual lock (`locked-xray-ws` #17) on `livetest_mlk1`: Locked card, marker out of JSON, `.locked` written, NO autounlock due file. Survived `limit-ip-ws` sweep (STILL-LOCKED) → indefinite proven.
- Unlock #13: `Unlocked` card (Status: Unlocked), marker restored 1×. Second unlock: `No locked accounts found to unlock.`, marker count stays 1 (no duplicate JSON). Skip-message proven.
- Account deleted via TUI after. Only F9-xray end-to-end remains blocked (Found 489); 16/16 inbounds bind 127.0.0.1 — verified no direct-traffic shortcut exists.

## Canary 489 2026-10-09 — PROXY protocol impossible on this nginx

- Patched live `nginx.conf` (4 trojan-ws locations) + `ws.json` (25432 inbound `acceptProxyProtocol`), snapshot first. `xray -test` OK, `nginx -t` emerg: unknown directive. Minimal-conf proof: binary lacks it. Reverted from snapshot, both tests green, no reload ever happened. 489 stays deferred with exact blockers (nginx replacement or stream-frontend redesign).

## Fix 472 proof 2026-10-09 — xray multilogin lock end-to-end (test box)

- `livetest_lck1` (vless-grpc, limit-IP 1): log tunjukkan 2 IP (`112.215.153.156` VM + `127.0.0.1` lokal); `limit-ip-grpc` → marker keluar JSON + `.locked` tertulis. F9-xray PASS. Statuses: statsonline tetap 1 (API buta, sesuai teori); enforcement kini via log.
- Spoof control (XFF 9.9.9.9, trafik jalan): log catat IP asli — overwrite `$remote_addr` unspoofable.
- Koreksi peta: 112.215.x.x adalah egress NAT lab sendiri (berubah-ubah antar sesi: .139.236 → .172.26 → .153.156), BUKAN operator lain. Histeria "intruder" dicabut; satu-satunya sesi asing terkonfirmasi hanya root pts dari 112.215.240.106.

## Re-proof 472 pasca-revert (append semantics, trafik jujur)

- `livetest_lck2` (limit 1): log `112.215.153.156` (VM-2) + `127.0.0.1` (lokal); limiter → TERKUNCI. Fix 472 final: counting dipertahankan, overwrite dibuang, D24 patuh.

## F17 alias 2026-10-09 (test box) — PASS

- API installed (service active, `.key` 0600). `add-vmess core=xhttp` → success, link decodes `net=xhttp path=/purple`, 2 MB traffic checksum MATCH direct. `core=split` → success normalized to `core=xhttp` (legacy alias live). Both deleted via API (`deleted_from:["xhttp"]`), JSON clean. API uninstalled after (service gone, token/handlers/menu removed).

## F0 fresh install 2026-10-09 (test box wiped, Debian 12.15 via reinstall.sh)

- Wipe authorized (no backup). `reinstall.sh --username root --password ... debian 12` → netboot → d-i preseed → fresh Debian (hostname `localhost`, port 22).
- Panel install from main HEAD (`full`, fntest domain, dual, NS): ~10 min, INSTALL SUCCESS. F1 on fresh box: 16/16 active, 0 failed, modes 600/600/640/644, sysctl exact, self-signed CN=installer domain, TLS 1.3.
- Smoke: TUI create (card) + TUI delete (gone). F0 PASS — first end-to-end installer validation with all current fixes native (no sync drift).

## F0-lite 2026-10-09 (wiped box #2, lite edition)

- Install lite from HEAD: success. State: xray×4 + nginx active, cert CN ok; openvpn/xl2tpd package-active (no panel tooling — by lite design); haproxy/noobz/ws/dropbear correctly absent-or-disabled AFTER Fix 473 (dropbear was failed=1 before fix, 0 after; fix verified live).
- TUI create (card) + delete (marker + card gone, JSON valid) on lite. Note: delete success line not captured in walk output (state-verified instead).
- SSH stays on 22 in lite (no 3303 move — lite never runs ssh.sh; consistent with design).

## Missed-ops catch-up 2026-10-09 (lite box, second wipe) — ALL PASS except noted

1. **change-uuid/quota:** `add-vmess-ws livetest_chgu` → `change-id-ws` blank (random `badea95f-...`) UUID-CHANGED, `Configuration OK`; `change-quota-ws` input `0` rejected (`Value must be...`), `9` → quota file `9663676416` + card `Quota : 9 GB` + success. PASS.
2. **Metachar injection:** empty→`cannot be empty`; `BAD;NAME`/`$(...)`/`Bad Name`→uppercase/space reject (3×), `$(touch /tmp/pwned)` NEVER executed (`/tmp/pwned` absent); `bad;name`/`bad*star`→lowercase-only reject (2×); duplicate→`already exists`; `0` for ip/quota/days→reject (3×); valid→created. PASS, no shell eval.
3. **Bot interval:** no creds→`Bot Credentials Not Set` notice, clean return; dummy creds + legacy cron→`Current interval : every 6 hour`, `0`/`abc`/`25` re-asked (3×), blank keeps (no write), `6`→single `0 */6` line. Cron restored to legacy, dummies removed. PASS.
4. **dm-menu 4/5/6:** invalid domain choice→`Invalid choice.` each; `xray.crt/.key` byte-identical after. Real issuance NOT run (LE rate-limit safety, per plan). Cancel-path PASS, issuance deferred by design.
5. **Unlock empty screens:** 4/4 `unlock-*` → `No locked accounts found to unlock.`, JSONs valid; TUI wrapper adds `Press any key` pause (source-verified). `locked-xray-*` empty-list untestable (foreign `livetest_lc1` present, untouched). PASS with note.
6. **Auth race:** both sources blocked→`Failed to download permissions.` exit 1, quota untouched (fail-closed pre-mutation); pages-only blocked→green via GitHub. Hosts restored, 0 entries. PASS.
7. **Limiters ws/http/xhttp live:** limit=1 accounts + 2 planted IPs per log → all 3 locked (JSON entry out, `.locked` written, `Configuration OK`); unlock restores exactly 1 entry (no dup); delete clean. Bonus: cron tick re-locked both HTTP accounts on planted lines before cleanup (periodic enforcement proven), plant lines removed after. PASS.
- **Box-as-found:** 0 own test accounts (foreign `livetest_lc1` VLESS-HU 22:08 left untouched — not ours, ask operator), 4/4 `Configuration OK`, 0 failed, /tmp clean.

## Full-round 2026-10-09/10 (wiped box 3, full edition) — PASS + 1 typo fix

- Fresh Debian 12.15 + full install HEAD: F1 16/16 active, 0 failed.
- OpenVPN penuh via KVM: UDP 2200 login (tun0 10.7.0.6, ping 10.7.0.1 ok) + TCP 1194 via squid (tun0 10.6.0.10, ping 10.6.0.1 ok); SSH-auth THROUGH tunnel sukses (chdir cosmetic per F3); akun dihapus via delete-ssh. UDP HTTP-data via :80 tak valid (port itu menyajikan banner SSH, bukan HTTP — bukan bug OVPN).
- SlowDNS loopback: dnstt-client 14 MB hash-mismatch saat transfer pertama (re-transfer ok) lalu session 425b100d dua-arah (client + server journal id sama) via :5300. Remote publik tetap terfilter lab.
- Restore round-trip token-asli: backup fail-safe staged, 401/401 tanpa-salah token, token benar SUCCESSFULLY RESTORED, 0 hash mismatch (11 berkas), 4/4 valid, .restore.key tetap 640.
- change-limit-ip live: 0 ditolak Invalid input, 7 tersimpan sinkron (file + kartu, Bug 62 terbukti).
- locked-xray kosong 4/4 + delete-ws no-clients + phantom-lock guard (JSON byte-identik).
- Issuance LE betulan (opsi 4 + IPv4): SUKSES, issuer Lets Encrypt 90 hari, s_client Verify return code 0; traffic vmess-WS via rantai LE asli (tanpa allowInsecure) checksum MATCH.
- Typo Ceritificate: Found 496 / Fix 474 / Section 260.
- L2TP tetap control-only (no /dev/ppp di box maupun kernel cloud, no IPsec): xl2tpd active + LNS valid, data path mustahil — blocker struktural.
- Noobz login penuh tetap butuh aplikasi resmi (port up, tanpa-auth fail-closed/timeout — partial).
- Box-as-found: 0 akun uji, 4/4 Configuration OK, 0 failed; VM-2 powered off bersih.

## Found 497 kill-chain + Fix 498 (2026-10-10, test box full) — PROVEN + FIXED LIVE

- Laporan operator: 2 akun xhttp lenyap total setelah multilogin, pesan "XRAY XHTTP Log Cleanup".
- Rantai terbukti: lock (JSON out + `.locked`) -> anchor `#vmess` hilang -> `unlock-xhttp-auto` exit 2 tapi JSON tetap 0 (insert sunyi gagal, `.locked` tetap dipindah) -> `auto-delete-xhttp` "Menghapus data..." (kartu + kuota + limit lenyap, telegram Log Cleanup).
- Akar: sed anchor-insert tanpa verifikasi di 16 berkas unlock (auto + manual). Pemicu anchor-hilang di box operator masih perlu dicek (`grep -c "^#vmess$" /etc/xray/json/*.json`;versi panel lama? kerusakan Bug-68 lama?).
- Fix 498: guard `grep -qxF` sebelum `mv`, gagal = LOUD + exit 1 + lock dipertahankan. Verified: rantai berhenti di unlock, akun selamat-terkunci; jalur normal utuh.
- Box-as-found: JSON backup dipulihkan, 0 akun uji, 4/4 Configuration OK, 0 failed, /tmp bersih.
- Follow-up sekelas (belum di-fix): `add-*`/`trial-*` insert sunyi saat anchor hilang (kartu tanpa JSON); cek anchor + hardening terpisah.

## Fix 499 lapis kedua + skop 4 transport (2026-10-10, test box full)

- Kebijakan operator: multilogin = lock 15 mnt, TIDAK PERNAH delete. Sudah sesuai desain; Fix 498 + 499 menegakkannya dua lapis.
- Skop: kelas silent-insert ada di SEMUA transport (ws/grpc/http/xhttp) — 16/16 guard unlock + 8/8 guard auto-delete terpasang (full + lite).
- Verified live lapis kedua: mangsa + state -> SKIP (lock-in-flight), kartu + kuota selamat; tanpa state -> "Menghapus data..." normal (orphan cleanup utuh).
- Penyebab di box operator belum pasti multilogin — butuh forensik box: anchor (`grep -c "^#vmess$" JSON`), `.quota.logs` (quota-delete by design?), urutan pesan telegram (MULTILOGIN LOCKED? Quota Exhausted? Log Cleanup?), versi panel.
- Box-as-found: 0 akun uji, 4/4 Configuration OK, 0 failed, /tmp bersih.

## VLESS + cross-transport proof, 24-script sync (2026-10-10, test box full)

- VLESS/xhttp rantai penuh dengan kode LAMA: lock -> hapus `#vless` -> unlock-auto exit 2 sunyi (JSON 0) -> auto-delete "Menghapus data..." (lenyap total). Guard baru: +state -> SKIP lock-in-flight; tanpa state -> cleanup normal. Kelas bug sama persis lintas protokol.
- 24 skrip fix (16 unlock + 8 auto-delete) di-sync ke /usr/bin test box (cmp- diverifikasi, 11 updated + 3 sudah).
- WS end-to-end: lock -> hapus `#vmess` -> unlock-ws-auto FIXED gagal LOUD (exit 1, `.locked` utuh, auto-delete 0 hapus, kuota utuh) -> anchor pulih -> unlock 1 entri -> delete bersih.
- Kesimpulan skop: ws/grpc/http/xhttp × vmess/vless/trojan semua berbentuk sama; guard menutup semuanya (16/16 + 8/8). FIX untuk add-*/trial-* sekelas masih follow-up.
- Box-as-found: 0 akun uji, 4/4 Configuration OK, 0 failed.

## Found 500 RACE + Fix 501 (2026-10-10) — root cause insiden kaya88, PROVEN + FIXED

- Bukti (forward telegram operator + mailbox live box): kaya88 VLESS/XHTTP limit 3->5. Lock 12:30:03 (4/3), lock 12:50:03 (10/3), unlock manual 12:50:30 (by owner), lock 12:55:02 (10/5), cleanup 12:55:02 (Deleted Users: kaya88). Mailbox 12:55:05: `Memeriksa kaya88.log` -> `Menghapus data...` + restart.
- Mekanisme: limit-ip hapus JSON -> curl telegram (blokir s/d 10 dtk) -> mv/state. auto-delete se-tick mendarat di jendela itu -> orphan -> habisi. Tanpa anchor rusak, tanpa quota, tanpa tangan manusia.
- Fix 501: 24 berkas reorder (mutasi dulu, notify terakhir). locked-xray/delete/xp sudah aman (terverifikasi urutannya).
- Sisaplay di box operator: deploy 24 skrip (limit-ip/kill/quota) + 24 sebelumnya (unlock/auto-delete) = 48 berkas ke /usr/bin; buat ulang kaya88.
- Box-as-found (test): 0 akun uji, 4/4 Configuration OK, 0 failed.

## CDN IP-limit accuracy round (2026-10-10, test box, /dev/kvm)
- Akun: livetest_cdnws/cdngrpc/cdnhttp/cdnxhttp (vmess, limit-ip 5). Klien: lab-host + KVM guest (egress sama 157.15.139.236) + VPS-lokal (202.155.17.126), semua via edge 104.17.3.81.
- WS dual (2 user riil, 12 req): distinct 22 edge, statsonline 12, `limit-ip-ws` MANUAL -> `.locked` (false lock limit-5); unlock ok (JSON 2 baris). HU single: 3 req -> 3 edge. XHTTP: direct 200 (UUID baru), CDN 3x200 -> 1 edge (salah alamat). gRPC: CDN 415 (dir+CF), direct 200.
- Samping: (a) recreate-xhttp yatim oleh operator (COLD2 hapus JSON entry yang baru dibuat + add gagal kartu-ada -> auto-delete sapu 22:30:12 — rantai orphan->cleanup terkonfirmasi lagi, no bug); (b) gRPC CDN 415; (c) guest KVM (SLIRP) TLS ke CF edge gagal (TCP ok, handshake ok, h2 stall) — butuh tap/passt untuk klien-penuh-dari-guest.
- Box-as-found: 4 akun uji utuh (terkunci: tidak ada), 4/4 Configuration OK, 0 klien tersisa. VM kvmcdn dibiarkan hidup (ssh 1222).

## CDN retest pasca-Fix 503 (2026-10-10, test box)
- Deploy: 50/50 append, nginx -t OK + reload. Lab egress sempat pindah 157.15.139.236 -> 140.213.x (CGNAT) di tengah sesi — tercatat.
- WS dual: distinct 3 riil, statsonline 3, limiter manual no-lock, akun utuh. HU/XHTTP CDN: IP riil. Direct: IP riil. gRPC CDN: masih 415 (terpisah).
- Box-as-found: 4 akun cdn utuh, 4/4 Configuration OK, xray@ws/grpc/xhttp + nginx active, 0 klien tersisa, VM kvmcdn hidup (1222).

## gRPC accuracy Fix 504 retest (2026-10-10, test box, via CDN)
- Deploy map + 12 baris, nginx -t OK + reload. Single CDN -> IP riil; dual (lab 140.213.x + VPS 202.x) -> distinct riil + 1 edge basi, statsonline 2, limiter manual no-lock; direct -> IP riil (fallback). Sisa VPS klien: 0.
- Box-as-found: 4 akun cdn utuh, 4/4 Configuration OK, servis + nginx active. VM kvmcdn hidup (1222).

## gRPC uniform Fix 505 retest (2026-10-11, test box, via CDN)
- Deploy map + 12 baris ×3, nginx -t OK + reload. Single CDN -> IP riil; dual -> TEPAT 2 IP riil, limiter no-lock; direct -> IP riil. 4 akun cdn utuh, 0 klien, VM kvmcdn hidup.

## Full matrix retest 3 proto x 4 transport x CDN/direct (2026-10-11, test box)
- Akun: vmess/vless/trojan × ws/grpc/hu/xhttp (12 akun, limit-ip 5). Klien lab-host via edge 104.17.3.81 (CDN) dan direct 202.155.17.126, SNI/host fntest.
- Direct: 12/12 `200`. CDN: 9/12 `200` (ws/hu/xhttp semua proto); semua yang konek mencatat IP RIIL di xray log (CGNAT lab 140.213.x, 0 edge).
- gRPC via CDN flaky di sisi Cloudflare: 18× `HTTP/2.0→200` vs 13× `HTTP/1.1→415` untuk request identik (toggle h2-to-origin ON; flap koneksi CF, bukan config origin — tak ada baris lain). Direct gRPC 3/3 `200`.
- Metodologi: bukti WS batch-1 dimakan truncate `kill-ws` cron (`> ws.log`, tiap 5 mnt) — diulang sinkron pasca-tick, terkumpul 00:23:12. File terbuat ulang milik www-data (temuan lama).
- Box-as-found: 12 akun cdn utuh, 0 klien tersisa, VM kvmcdn hidup.

## Edge-IP comparison for grpc-CDN flap (2026-10-11)
- 104.17.3.81 (pinned): h2/h1.1 flap (18×200 vs 13×415), kini 6/6 415.
- 104.17.70.206: TLS ok (cert ours) tapi frame h2 rusak di `/`, gRPC stall tanpa jejak di origin — PoP sakit/rute buruk, unusable.
- 104.21.83.135 (edge bimbel.ruangguru.com, SNI/host tetap fntest): gRPC 3/3 `HTTP/2.0→200`, xray log IP riil. Flap = spesifik edge, bukan zone.
- Kesimpulan: jangan pin satu edge IP; klien normal via DNS anycast dapat edge sehat otomatis. Tak ada perubahan panel (link akun pakai domain).

## CDN investigation closure (2026-10-11)
- Pertanyaan awal ("limit IP via CDN seems not accurate") terjawab tuntas: YA, dulu menghitung edge (Found 502) -> Fix 503 (3 transport) + Fix 505 (gRPC uniform, gantikan Fix 504). Re-proof 1=1 semua transport × kedua path, matrix 24 kombinasi (direct 12/12, CDN 9/12).
- 3 non-terbukti-bug panel: (1) gRPC 415 = flap h2/h1.1 per-edge Cloudflare (18 vs 13, toggle ON) — 104.21.83.135 bersih, 104.17.70.206 sakit; (2) guest KVM SLIRP tak bisa TLS-penuh ke edge (handshake ok, h2 stall) — butuh tap/passt; (3) `kill-ws` cron truncate ws.log tiap 5 mnt (memakan batch bukti sekali; www-data ownership).
- Pelajaran uji: jangan pin satu edge IP (matikan self-healing anycast); sinkronkan batch ws dengan tick cron; dua sumber (lab + VPS) untuk klaim multilogin.
- Status akhir: repo `main` bersih pushed; test box 12 akun cdn + VM kvmcdn hidup; live box BELUM terima Fix 503/505 (tunggu operator).

## IP evidence + CGNAT investigation (2026-10-31, live read-only)

- `senar90` lock 19:45:04 menampilkan `IPs (0)`; `ws.log` memang di-truncate `kill-ws` tiap 5 menit (baris 216), sedangkan notice membaca jendela 1 menit. `lite/cek-xray-ws.sh` juga men-truncate log yang sama (baris 129); full tidak.
- `xray api statsonlineiplist` mengembalikan map IP nyata untuk user aktif: `palem99` 2 IP, `pandan8` 1-2 IP, `senar90` 1 IP, `lantai9` 2 IP (berubah antar query). Ini sumber bukti yang dipakai Fix 508.
- `tuna88` punya 3 alamat `112.215.x` berbeda di log dan lock pada 12:10 (bukan menit `xp`); konsisten dengan satu perangkat CGNAT yang berputar IP, bukan bukti tiga perangkat. Fix 509 menunda lock sampai set IP yang sama stabil dua run 5 menit.
- Auto-unlock: state due ditulis `lock + 600` (10 menit), jadi pada cron 5 menit lock bisa lepas 10–15 menit — lebih cepat dari notice 15 menit. Fix 510 mengubahnya ke `+900` plus guard `mtime + 900` untuk state lama.
- Restore: semua jalur menyalin `/etc/funny` wholesale, sehingga `.install-commit`, `.update-commit`, `version`, dan `format.sh` ikut rollback. `/usr/bin` tidak ada di arsip, jadi script utama tetap; Fix 511 mempertahankan current marker/formatter saat restore dan `update.sh` menyegarkan `format.sh`.
- Tidak ada perubahan live: hanya `cat`, `ls`, `grep`, `xray api` read-only. Enam akun korban `xp` (Found 507) masih kehilangan quota/IP limit sampai operator mengizinkan repair.

## Fix 514–516 read-only audit (2026-11-01, rohserver1/3/6)

- `/usr/bin/restore-ftp` di ketiga box adalah varian web: head `#!/bin/bash` + `# Detail Informasi`, `PERMISSION_CFPAGES`/`Found 511` = 0. `update.sh` lama akan menimpanya dengan varian interaktif; Fix 514 memindahkan file ini ke `WEB_FILES` dan mengunduh `website/restore-ftp.sh`.
- rohserver6: HAProxy aktif di `777`, `/var/log/haproxy.log` + `/etc/rsyslog.d/49-haproxy.conf` tersedia, tetapi config belum punya `log`/`option logasap`; sesi 777 karena itu tidak punya bukti IP saat masih aktif. Fix 514 menambahkan logging start-of-session + pemetaan timestamp di `ssh-online`.
- Sesi WS aktif tetap memetakan ke IP riil (0 baris `127.0.0.1`); sesi 777 belum diuji live karena tidak ada klien 777 aktif dan box dijaga read-only.
- Uji lokal Fix 514–516: HAProxy parser/patch, SSH limiter A–J, Xray limiter 1–6, auth window 1 jam, IPv6 normalization, `bash -n` 8 limiter + 8 unlock + helper, `python3 -m py_compile` embedded helper, `tools/verify-payload.sh` 220 entri. Semua lulus.
- Tidak ada perubahan live: hanya `cat`, `ls`, `grep`, `journalctl`, `ss`, dan `xray api` read-only.

## SSH expiry restart + 418 source audit (2026-11-01, rohserver6, read-only)

- **418 bukan dari VPS.** `grep " 418 "` pada access log hanya menemukan angka **body bytes** (mis. `GET /emerald ... 101 418`), bukan status HTTP. Tidak ada `return 418` di `nginx -T`, tidak ada status 418 di access log, dan screenshot pelanggan berasal dari `blog.skillacademy.com`/TencentEdgeOne (`43.169.65.100`), yang menjawab `301` untuk Host sendiri dan `418` untuk Host lain. Tidak ada bukti server ini mengirim 418.
- **Restart 19:52 bukan limiter.** `ssh` stop/start dua kali, lalu `dropbear`, `ws`, `cron`, `nginx`, `haproxy`, dan seluruh `xray@*`/`quota-*` restart pada 19:52:09–19:52:18 adalah `resall()` dari menu (operator). `limit-ip-ssh` tidak menyentuh `dropbear`/`xray`. Pada 19:55:37 systemd mulai shutdown; reboot selesai 19:56:22.
- **Penyebab restart global SSH yang tersisa: `xp`.** Cron `xp` mulai 08:00:01 dan selesai 08:00:35–36; blok Auto Remove SSH me-restart `ssh`, `sshd` (alias yang sama, sehingga dua stop/start), `ws`, dan `dropbear` setelah satu akun SSH lewat expiry. Ini memutus semua sesi SSH/WS pengguna lain. Dropbear juga mencatat `Found left-over process ... Ignoring` untuk child lama, jadi restart itu tidak reliably mengeluarkan akun expired. Fix 517 mengganti blok tersebut dengan `pkill -KILL -u` per akun.
- **Jalur Xray juga melakukan restart global.** `xray@ws` stop/start dua kali pada 19:45:05–06 (dua akun expired/limit dalam satu run), diikuti lonjakan `101 /green` dari 205 (19:44) menjadi 630 (19:45) dan 606 (19:46) — reconnect storm seluruh klien WS Xray. Xray 25.3.6 tidak punya CLI remove-user, jadi ini dicatat sebagai follow-up, bukan bagian Fix 517.
- **Resource sehat, bukan kehabisan.** Setelah 18 jam: RAM 5937 MB (4910 tersedia), disk 13%, 704 established TCP, 316 TIME_WAIT, conntrack ~2k/20M, nginx `worker_connections 100000`, Xray/ws `LimitNOFILE=1000000`. Tidak ada OOM/fork/conntrack error di journal boot sebelumnya; satu-satunya warning berulang adalah `pppd` tanpa `/dev/ppp`.
- **Kesimpulan:** keluhan "SSH putus lalu harus reboot" pada box ini paling konsisten dengan restart global dari `xp`/limiter lama (semua sesi diputus, lalu klien berebut reconnect), bukan kegagalan kernel atau `418` dari VPS. Fix 515 menutup limiter SSH; Fix 517 menutup `xp`. Deploy tetap menunggu persetujuan operator.

## Local regression audit 507–519 (2026-11-01, no live changes)

- Rechecked Fix 507–517 against the current tree: `bash -n` for every shell file, `tools/verify-payload.sh` (119 full / 101 lite), full/lite payload install from a local HTTP server, the `xp` SSH-expiry harness (expired account only, no `systemctl`), the SSH limiter harness (stable set locks only the over-limit account; due retained on unlock failure; missing helper still sweeps; `Unlimited`/`0` handling), and the `limit-ip-ws` auto-unlock harness (two due users -> two unlocks + one restart; rc=1 keeps due; old `+600` due is not unlocked early).
- Found and fixed Found 518 (manifest installed the interactive `restore-ftp`; payload script timeout was 120 s) and Found 519 (HAProxy patch checked `log global` anywhere, so another frontend could suppress 777 logging). Both are installer/updater-side only.
- Deployment target pinned to `2833d8d03dc9f1cd22e0b2a130a417c18877be6a` (Fix 523; includes Fix 514–522). The updater now starts from the live marker (`.update-commit`, then `.install-commit`; fallback `6b967af`, live v1.23) instead of the stale `5c48741`. Still pending live deployment of Fix 514–523, six WS accounts missing quota/IP-limit data, and Xray per-transport expiry restart.

## Domain rename and per-domain counts (2026-11-01, no live changes)

- Local audit Found 521: `domain`/`domains` naming was ambiguous, account cards only showed the full `Domains :` set, and `dm-menu` option 3 printed the same global totals under every domain. Fixed locally by renaming the files to `/etc/xray/installer-domain`, `/etc/xray/rotated-domains`, `/etc/xray/.rotated-domainseq`, renaming the variables, adding `Installer Domain`/`Rotated Domain` card rows, and computing per-domain/per-protocol counts from cards (`Rotated Domain`, legacy `Rotated`, VMess/VLess/Trojan links, WireGuard `Endpoint`).
- Legacy files are migrated by `update.sh` (backed up under `$BACKUP/domain-files`, old names removed only after a successful install) and by the restore paths (old backup normalized before `cp -r xray /etc/`). The full `limit-ip` binary was rebuilt against the new path.
- Updater coverage now includes all 24 Xray add/trial scripts, `dm-menu`, `menu-wg`, `xl2tp`, `menu-noobz`, and the full `limit-ip` binary. Local checks: `bash -n` all shell files, `tools/verify-payload.sh` 119/101, rotation harness, domain-count harness, and bwrap migration test. Still pending live deployment (read-only).

## Installer/rotated separation (2026-11-01, no live changes)

- Follow-up to Fix 521: Found 522 removed the implicit installer domain from every rotation block. Xray/SSH/WireGuard now read only `/etc/xray/rotated-domains`; an empty list blocks account creation with a clear notice. The installer domain is seeded into the rotated list on a fresh install but can be deleted from it, while `/etc/xray/installer-domain` stays for Nginx and certificates.
- `dm-menu` now treats the rotated file as independent, marks the installer entry in the count report, shows legacy accounts separately when the installer entry was removed, and warns when the list is empty. `server_name` is deduplicated across installer + rotated domains; certificate selection still includes the installer domain.
- Legacy migration/restore seed the installer domain at the front of the old effective order only when converting old `domain`/`domains` files. Existing new-format lists—including an empty file—are not re-seeded, so deletions survive updates. Harnesses covered all 49 Xray/SSH add/trial scripts with `a.com,b.com`, only `b.com`, and empty (every script stops on empty and never falls back to the installer domain); WireGuard; report/remove/sync; fresh installer seeding; migration and restore seeding/skip cases. A full updater run against a local mirror of `8d87c3e` migrated `domain`/`domains` to `installer-domain`/`rotated-domains` with the installer first, installed the new scripts and full `limit-ip`, and a `--force` rerun after deleting the installer entry left the rotated list unchanged. Live VPS still untouched; deployment pending operator approval.

## Version display repair (2026-11-01, no live changes)

- Found 523: the fresh-install version was always `Unknown` because the installer called the GitHub API without `/repos` (404), and the main menu echoed `Unknown` for both missing markers. Fixed the endpoint, added a `git ls-remote` fallback, validated the SHA, and made the menu show `not recorded` / `not updated` for missing or invalid markers.
- `update.sh` now backfills `.install-commit` from the detected `FROM` when the install marker is empty/`Unknown`/invalid, `FROM` is a 40-hex commit, and `FROM` differs from `TARGET`. This covers both a box with no update marker and a box whose live marker is the documented v1.23 `6b967af`; a same-target rerun leaves the marker alone.
- Local checks: installer resolver with real API, fake API, git fallback, and both-fail; menu marker matrix; updater backfill matrix; `bash -n`. A full updater simulation to `2833d8d` from `.install-commit=Unknown`, `.update-commit=6b967af` (live v1.23 scenario) backfilled `6b967af` as the install version and wrote `2833d8d` as the update version; the installed menu printed `6b967af` / `2833d8d`, and a `--force` rerun kept the install marker. Live deployment still pending operator approval.

## Regression audit Fix 507–523 (2026-11-01, no live changes)

- Re-audited the recent range against the current tree: `bash -n` for every shell file, `tools/verify-payload.sh` (119 full / 101 lite), updater marker checks for all 56 full / 47 lite files, binary md5 pins, and remote target verification (103 files, 0 failures).
- Payload coverage: every changed deployable file from Fix 507–523 is either in `FILES`, `BINARIES`, `CONFIG_FILES`, or `WEB_FILES`. Installer-only files (`installer/*`, `menu/*.manifest`, `installer/payload.sh`) are intentionally not in the updater; full/lite `restore-ftp.sh` remain source-only because live `/usr/bin/restore-ftp` must stay the website variant (Fix 514). Other repository binaries were unchanged and are not shipped.
- Behavior rechecks: Fix 517 `xp` expired-account harness (`pkill -u` + `userdel`, no daemon restart), Fix 514–516 updater/payload and HAProxy scenarios, Fix 521/522 rotation and domain-count harnesses (all 49 Xray/SSH add/trial scripts, WireGuard, report/remove/nginx sync, migration/restore), and Fix 523 version resolver/menu/backfill matrices.
- Live-version scenario: the exact `main/update.sh` (sha256 matched HEAD) was run on full and lite sandboxes with `.update-commit=6b967af`, `.install-commit=Unknown`. It detected `6b967af -> 2833d8d`, migrated old `/etc/xray/domain` + `/etc/xray/domains` to `installer-domain` + `rotated-domains` (installer first), installed all payload files, and produced `Installed version : 6b967af`, `Updated version : 2833d8d`. A same-target `--force` rerun preserved the install marker.
- Result: no regression found. One refinement made during the audit: `.install-commit` backfill now also handles a box whose live version exists only in `.update-commit` (the documented v1.23 `6b967af` case), not just a box with no update marker.

## Live deployment - three VPS, Fix 507/514-523 and 25-account repair (2026-11-01)

- Deployed the exact `main/update.sh` to `rohserver6` (64.120.94.62), `rohserver1` (103.210.69.33), and `rohserver3` (157.10.253.95). Each box detected `full`, read its live `.update-commit=6b967af`, and reported `Live version: 6b967af -> 2833d8d` / `UPDATE SUCCESS: 6b967af -> 2833d8d (full)`. No hardcoded baseline was used.
- After deployment each box has `.install-commit=6b967af9e0ebadc76a265132e49d62a27ad72235` (backfilled from the detected live version) and `.update-commit=2833d8d03dc9f1cd22e0b2a130a417c18877be6a`; the installed menu prints `Installed version : 6b967af` and `Updated version : 2833d8d`.
- All three live boxes still used the legacy `domain`/`domains`/`.domainseq` layout. The updater backed them up under the update backup, created `installer-domain`, `rotated-domains`, and `.rotated-domainseq`, seeded the installer domain first, and removed the legacy names only after a successful install. Resulting installer domains: `moonandsea.us.ci` (rohserver6), `bungatidur.de5.net` (rohserver1), `sewamotor.us.ci` (rohserver3).
- Repaired 25 WS accounts whose quota-limit and IP-limit files had been deleted by the old empty-expiry `xp` path (`xp: deleted <user> (expiry )`):
  - rohserver6: `cuci33`, `kipas3`, `lalap23`, `lantai9`, `palem99`, `pandan8`, `senar90`
  - rohserver1: `cumi2`, `kopikapal`, `lengan9`, `panah55`, `patah4`, `selai40`, `serap0`, `siap90`, `tebu80`
  - rohserver3: `beras02`, `jeruk67`, `lapak2`, `makan0`, `papan0`, `petani8`, `simak80`, `tanah50`, `tisu9`
- Repair restored each quota and IP limit from the account card and left the usage file untouched. Defaults were 100 GB / IP 2; exceptions were `kopikapal` 50 GB, and `lengan9`, `patah4`, `simak80` 200 GB. All usage values were below the restored quota.
- Post-checks: all 25 repaired files remained present after the next `xp` cron run (`:45`), and no new `(expiry )` entries appeared. `cek-xray-ws` now shows numeric quota and IP limits instead of `Not available` for the affected accounts. The installed `xp` md5 is `eafb9f59c592aa12fb7f2ed4df30fea2` with six empty-expiry guards and five lock-in-flight guards.
- The updater also installed `/usr/bin/ssh-online`, enabled HAProxy `log global` in the global and `ssh-ssl` sections, and left SSH/Dropbear running (banner wiring was already present). All checked services stayed active.
- Re-ran the downloaded updater on all three boxes: `/root/fn-update.sh` sha256 `80357be8084f8a9449c2df72c19e825e037c99836af13df11c13ef38929b1151` matched `main`, and each printed `Already at 2833d8d03dc9f1cd22e0b2a130a417c18877be6a ... Nothing to do.` Installed `limit-ip` md5 `5ec7165a8c912c0b00184b1f1ea73c8e`, `format.sh` md5 `f648de38388e0b96ae761697eca1b3bd`, and the `menu`/`dm-menu` target markers were present.
- Remaining separate issue, not caused by the empty-expiry bug: `quota-xhttp` still logs `xhttp.json busy, skipping this pass`, and `tuna88` on rohserver6 still has no `_usage` file while online. This needs a separate quota-xhttp lock diagnosis/restart; it was left read-only in this pass.

## Post-update verification - three VPS (2026-11-01)

- Rechecked every deployed full payload file against target `2833d8d`: 56/56 md5 matches on rohserver6, rohserver1, and rohserver3. All 49 installed shell scripts pass `bash -n`.
- Version markers and menu display are correct on all three: `.install-commit=6b967af...`, `.update-commit=2833d8d...`, menu shows `Installed version : 6b967af` / `Updated version : 2833d8d`.
- Service/config health: no failed units; ssh, dropbear, haproxy, nginx, xray@ws, quota-ws, xray@xhttp, quota-xhttp active; `nginx -t`, `sshd -t`, and all four Xray config tests pass; HAProxy config is valid (the backend `option tcplog` warning pre-dates the update). HAProxy logging is present in `global` and `ssh-ssl`.
- Domain state: installer-domain and rotated-domains exist on all three, installer is first, legacy `domain`/`domains`/`.domainseq` are gone. A live run of the installed domain-count report completed and showed per-domain/per-protocol counts, including legacy/removed domains separately. No installed script still reads the legacy domain paths; only backup/restore normalization mentions them.
- Account state: all 25 repaired WS accounts still have quota/IP limits. The new `xp` ran at the next `:45` cron without adding any `(expiry )` entries, and the repaired files survived. `ssh-online` runs successfully and `cek-xray-ws` shows numeric limits/quotas.
- Minor pre-existing findings, not caused by the update: `quota-xhttp`/`xp`/`limit-ip-xhttp` still hit the shared `xhttp.json` lock and log `busy, skipping`; `tuna88` xhttp remains without a `_usage` file; `parang00` and `simpang32` remain in xhttp.json because the xhttp xp section skips on that lock; Nginx on rohserver6 still lists `jualbatik.us.ci` (not in the rotated list); and one rohserver3 Dropbear session resolved to 127.0.0.1 (limit 3, no lock). These are separate follow-ups.
- Result: the update is complete and no update-caused file, version, config, service, domain, or account regression was found.

## xHTTP lock, idle usage, and cleanup - three VPS (2026-11-02)

- Deployed `quota-xhttp`, `kill-xhttp`, `limit-ip-xhttp`, `xp`, and `ssh-online` to rohserver6 (64.120.94.62), rohserver1 (103.210.69.33), and rohserver3 (157.10.253.95). Installed md5s: `quota-xhttp=4452e2c81100d2eefa8b5ffcf39e083d`, `kill-xhttp=736a2e3ecf65932c78b3eeb9d499f032`, `limit-ip-xhttp=03e74649c05544e0da7ff2cc15882a7d`, `xp=e3a9e723c4ac18b5764e18f62b9c2308`, `ssh-online=c10c1fe19ec33d7ee162ab2dac1d0146`. All pass `bash -n`; `quota-xhttp` was restarted and stayed active on each box.
- Root cause of the xHTTP `busy` messages: the shared `/tmp/xray-json-xhttp.lock` was held across Xray stats calls, Telegram sends, and restarts. `quota-xhttp` alone ran every 30 seconds; a single stalled stats call held the lock long enough for `xp`/`kill-xhttp`/`limit-ip-xhttp` to wait 30 seconds and skip. The new code collects evidence outside the lock and holds it only for JSON/file mutation plus the fast config test.
- Post-deploy probes showed `busy=0/15` (rohserver6), `busy=0/15` (rohserver1), and `busy=0/15` (rohserver3). No `xhttp.json busy` message was written after deployment during the 09:10 and 09:15 UTC+8 cron ticks. The only busy messages in the 20-minute window were from 09:00, before the new files were installed.
- rohserver6 `xp` removed all 14 expired xHTTP accounts, including `parang00` (27-Oct-2026) and `simpang32` (28-Oct-2026). xHTTP JSON count went from 43 to 29. rohserver3 removed `katak88` and `nanas82` (02-Nov-2026) on its next run. Every new `.quota.logs` line had a real expiry; no new `(expiry )` false deletion was written.
- `quota-xhttp` now initializes a zero `_usage` file for idle quota accounts: `tuna88_usage=0` on rohserver6, `jajan90_usage=0` on rohserver1, and `katak88_usage=0`/`nanas82_usage=0`/`panah88_usage=0` on rohserver3 before the two expired accounts were removed. `tuna88` has no Xray traffic counters, so 0 B is the correct baseline until it sends traffic.
- rohserver6 `server_name` was rebuilt from the installer + rotated lists and no longer contains `jualbatik.us.ci`: `server_name moonandsea.us.ci airbersih.de5.net wisatajogja.cc.cd tukangcukur.ccwu.cc bubukcabe.us.ci mieramen.cc.cd;`. `nginx -t` passes and `nginx` is active.
- `ssh-online` now returns no `127.0.0.1` rows on any VPS (5/9/14 active sessions respectively). The ws resolver accepts the observed `opened` then `client:` order; a unit test using the live timestamps returns `140.213.65.123`.
- Health: `quota-xhttp`, `xray@xhttp`, `nginx`, and `haproxy` active on all three; no failed units; `xray run -test -config /etc/xray/json/xhttp.json` passes. The old rohserver6 fail2ban ban on the operator IP (`157.15.139.236`) was removed via Dropbear port 109 so root SSH on port 22 could be used for the repair.
- Updater run (2026-11-02): the `main` updater (`66df787`, target `2c2b3f73a52bd67a7c2dbf067ab1005fc3c31cd6`) moved all three boxes from `2833d8d` to `2c2b3f7`. rohserver6 and rohserver3 fetched directly; rohserver1's direct GitHub HTTPS timed out, so the same updater script ran through a temporary SSH reverse proxy to the local network. All three reported `UPDATE SUCCESS`; `.update-commit` now reads `2c2b3f73a52bd67a7c2dbf067ab1005fc3c31cd6`; installed `quota-xhttp`, `kill-xhttp`, `limit-ip-xhttp`, `xp`, and `ssh-online` md5s match the Fix 524 build above. The updater restarted `quota-xhttp` on each box (service start timestamps match the update), `quota-xhttp`/`xray@xhttp`/`nginx`/`haproxy` are active, and no units are failed. Backups: `/root/fn-update-backup-20261102-093402` (rohserver6), `-013833` (rohserver1), `-093403` (rohserver3). The temporary proxy was closed and left no persistent configuration.

## Post-update configuration audit - three VPS (2026-11-02)

- **Scope:** systemd units and timers, Nginx, HAProxy, SSH/Dropbear, cron, all Xray JSON configs, Fn/Noobz JSON, quota files, domains, certificates, and service logs. No live file was changed by this audit.
- **Passed:** `systemctl is-system-running` = `running`, no failed units. `quota-{ws,http,grpc,xhttp}`, `xray@{ws,grpc,upgrade,xhttp}`, `nginx`, `haproxy`, `cron`, `ssh`, `dropbear`, `fail2ban`, `ws`, `noobzvpns`, `wg-quick@wg0`, `xl2tpd`, `ipsec`, `squid`, `dnstt`, `fn-ohp`, `opn`, `udp-custom`, `udp-request`, and `badvpn-udpgw` are active and enabled. `slowdns-fixnet.timer` and `udp-request-fixnet.timer` report `Result=success`.
- **Config tests:** `nginx -t` passes on all three; `haproxy -c` is valid (one pre-existing backend `option tcplog` warning); `sshd -t`, `fail2ban-client -t`, and `squid -k parse` pass; `wg-quick strip wg0` passes; `/etc/noobzvpns/config.json` and `db_user.json` pass `jq`.
- **JSON note:** all four `/etc/xray/json/*.json` pass `xray run -test`. They are not strict `jq` JSON because they intentionally contain `#`/`###` account markers; after stripping lines beginning with `#`, each file is valid JSON. No project script uses `jq` on these four files.
- **Nginx/domains/certs:** `server_name` matches `/etc/xray/installer-domain` + `/etc/xray/rotated-domains` on all three; no duplicates in the rotated list; `.rotated-domainseq` is numeric and within range. The self-signed `/etc/xray/xray.crt` SAN covers every served domain (rohserver6 also carries the old `jualbatik.us.ci` as an extra SAN; no active name is missing). `xray.key` is `0600`, `xray.crt` `0644`, `/etc/haproxy/funny.pem` `0600`, and the HAProxy PEM fingerprint matches `xray.crt` on all three.
- **Cron:** `/etc/crontab` has the expected `xp`, `limit-ip-*`, `auto-delete-*`, `kill-*`, `expire-ssh`, and `backup` jobs; every command resolves to an executable. `xp` and `limit-ip-xhttp` ran after the update (09:45/10:00/10:05/10:10 local, 01:45/02:00/02:05/02:10 UTC). The mailbox was not actually empty when rechecked later; the accumulated cron output and its Fix 531/532 cleanup are recorded in the section below.
- **Update behavior:** no `xhttp.json busy` message after the update on any box; no new `(expiry )` line in `.quota.logs`; `ssh-online` returns zero `127.0.0.1` rows; all xHTTP quota files have a numeric `_usage` companion.
- **Operator-created unused accounts:** several WS accounts have no `_usage` file (rohserver6 4, rohserver1 6, rohserver3 1). These are accounts the operator created but never used and left in place; this is not a quota defect. The one usage-only file (`ws/simpang32_usage`) belongs to an account with no quota file. No cleanup was performed.
- **FN-API intentionally absent:** Nginx `/api/` points to `127.0.0.1:9000`, but `api.service` is not installed and the operator does not currently need it; `/api/` is unused. Nginx error traffic after the update is lower than before and is scanner/upstream noise. Plain `https://<domain>/` returns an HTTP/2 protocol error by design because `/` is the SSH-WebSocket catch-all. `quota-xhttp` still prints `TERM environment variable not set`; the same message predates the update.
- **rohserver1 auth was a transient dual-source outage:** at 01:39 UTC both `fn-autosc-auth.pages.dev` and `raw.githubusercontent.com` were unreachable, not GitHub alone; the restarted `quota-xhttp` therefore logged `Auth sources unreachable - continuing without license check`. Both sources now return 200 and contain `### ID1 103.210.69.33 lifetime`, matching the server's public IP. The running daemon kept its startup `(unlicensed)` state until restarted; quota processing was unaffected. Fix 525 later removed the licence fetch from `quota-xhttp` entirely, so this startup state no longer exists.

## Licence gate scope - three VPS (2026-11-02)

- Deployed the `main` updater `33fcbdb` (target `a726c4a5bb89e5bf82cacefd6c3e77843c88943a`, Fix 525) to rohserver6 (64.120.94.62), rohserver1 (103.210.69.33), and rohserver3 (157.10.253.95). All three detected `full`, reported `2c2b3f7 -> a726c4a` / `UPDATE SUCCESS`, and now have `.update-commit=a726c4a5bb89e5bf82cacefd6c3e77843c88943a`. Each full payload fetched 107 files. Backups: `/root/fn-update-backup-20261102-110233` (rohserver6), `-030328` (rohserver1), `-110429` (rohserver3).
- Scope checks on every box: `menu`, `quota-xhttp`, `kill-xhttp`, `xp`, `backup`, `bmenu`, and `auto-delete-ws` are installed with the Found-525 marker and no `PERMISSION_CFPAGES`; `menu-system`, `menu-wg`, `xl2tp`, `menu-noobz`, `extend-ws`, and `trial-ssh` retain the gate. `menu-system` calls `license_gate` exactly at the WARP install/enable/restart/add actions (lines 229/326/368/455); its other actions stay ungated. `menu` and `lite/menu` keep a licence-free `output()` and print the Found-523 version lines.
- Offline behavior: a fake `curl` that failed both auth URLs and answered `ifconfig.me` with the live public IP made installed `add-vmess-ws`, `extend-ws`, and `trial-ssh` exit 1 with `Failed to download permissions.` before any prompt or mutation. The installed `license_gate()` in `menu-system`, `menu-wg`, `xl2tp`, and `menu-noobz` returned 0 with `EXPIRED_DATE=lifetime` from a stubbed source and 1 with both sources failing.
- Non-gated behavior: `menu` ran with a fake curl that logged every call and input `0`; it completed with rc 0, zero `fn-autosc-auth` calls, zero `command not found`, and printed `Installed version : 6b967af` / `Updated version : a726c4a`. `menu-system` option 5 (service/port details) also completed with rc 0 and zero auth calls. `install.sh`'s `permision()` race was tested locally: Pages failing + GitHub succeeding returned 0; both failing returned 1.
- Health after the update: all four `quota-*` units, all four `xray@*`, `nginx`, `haproxy`, `ssh`, and `dropbear` active on all three; `systemctl --failed` empty. No `unbound variable`, `command not found`, `Failed to download permissions`, `Auth sources unreachable`, `PERMISSION_CFPAGES`, or `xhttp.json busy` entries appeared in journald after the update, and cron sessions completed normally. `quota-xhttp` restarted at update time and stayed active; the old `Expired: lifetime` / `Auth sources unreachable` startup lines are gone from the new process.
- WARP live actions were not exercised (they would move egress); the installed gate function and the unchanged Decision-28 date check were verified in isolation. The WireGuard menu's WARP peer add is gated as account creation; `disable`/`status`/`token` remain ungated.
- Result: no update-caused regression. Live maintenance no longer depends on the authorization sources; only installation, account creation, and extend are fail-closed.

## Backup Telegram IP - three VPS (2026-11-02)

- **Evidence:** `/etc/funny/backup.log` had zero empty `IP     :` entries on rohserver6 and rohserver1, but three on rohserver3: 12-Oct-2026 03:00 WIB, 20-Oct-2026 12:00 CST, and 01-Nov-2026 15:00 CST. All four public-IP probes (`ifconfig.me`, `ipv4.icanhazip.com`, `api.ipify.org`, `ipinfo.io/ip`) worked on all three boxes during the investigation, so the blank fields came from transient probe failures, not a permanent block.
- **Fix deployed:** the `main` updater `2e6bc5c` (target `cc1bf90cf94f7e431ddb0ff87bbc888fa186dbb3`, Fix 526) moved rohserver6, rohserver1, and rohserver3 from `a726c4a` to `cc1bf90`; all three reported `UPDATE SUCCESS` and now have `.update-commit=cc1bf90cf94f7e431ddb0ff87bbc888fa186dbb3`. Backups: `/root/fn-update-backup-20261102-112911` (rohserver6), `-032959` (rohserver1), `-113000` (rohserver3).
- **Installed code:** each `/usr/bin/backup` carries `Found 526`, `get_public_ipv4()`, and `MYIP=$(get_public_ipv4) || MYIP="unknown"`. The helper tries four public-IP services with an 8-second bound each, accepts only a valid dotted-quad IPv4, then falls back to `/etc/.ip`; the message uses `unknown` rather than a blank if nothing valid exists.
- **Live helper checks:** the installed helper returned the correct address on each box (`64.120.94.62`, `103.210.69.33`, `157.10.253.95`). With every probe stubbed to fail, it returned the same address from `/etc/.ip`; with every probe returning an invalid HTML body, it still returned the same address. The generated message line was `IP     : <correct address>` on all three.
- **Health:** all four `quota-*`, all four `xray@*`, Nginx, HAProxy, SSH, and Dropbear units stayed active; `systemctl --failed` is empty; no new auth, lock, expiry, or unbound-variable errors appeared after the update. No test Telegram backup was sent, so the next scheduled backup is the first production message using the new path.
- Result: the intermittent blank IP is fixed at the source, with a cached fallback that works when all live probes fail.

## Main-menu licence identity - three VPS (2026-11-02)

- **Change:** updater `19906ff` (target `d2d61da78afdf784241192c436c8a37b4bff0655`, Fix 527) moved rohserver6, rohserver1, and rohserver3 from `cc1bf90` to `d2d61da`; all three reported `UPDATE SUCCESS` and now have `.update-commit=d2d61da78afdf784241192c436c8a37b4bff0655`. Backups: `/root/fn-update-backup-20261102-115104` (rohserver6), `-035104` (rohserver1), `-115104` (rohserver3).
- **Live menu:** `TERM=xterm /usr/bin/menu < /dev/null` rendered the same lines the operator expects. rohserver6 showed `Username : SG1`, `IPv4 : 64.120.94.62`, `Expired : lifetime`; rohserver1 showed `ID1` / `103.210.69.33`; rohserver3 showed `ID2` / `157.10.253.95`. All three also showed `Installed version : 6b967af` / `Updated version : d2d61da`. The extracted `output()` produced the same values and returned 0.
- **Cache:** `/var/lib/fn-autosc/license-info` was `-rw------- root root` on each box with the matching line (`### SG1 64.120.94.62 lifetime`, `### ID1 103.210.69.33 lifetime`, `### ID2 157.10.253.95 lifetime`).
- **Offline:** a fake `curl` that exited 1 for every request still rendered the full menu on all three, with `Username : ... (cached)`, `IPv4 : ... (cached)`, `Expired : lifetime (cached)`, and `menu_rc=0`. This is a display-only read: no authorization gate ran and no `Failed to download permissions` message appeared.
- **Accuracy note:** the earlier Fix 525 live test recorded `menu` running with zero auth calls. Fix 527 intentionally supersedes that for `menu` only: it now performs a bounded, display-only auth read when the menu opens. `menu-system` and the maintenance/quota commands remain zero-auth.
- **Health:** all 12 checked services per box (`quota-*`, `xray@*`, Nginx, HAProxy, SSH, Dropbear) stayed active, `systemctl --failed` was empty, and no new auth, lock, expiry, or unbound-variable errors appeared.
- Result: the main menu again shows the licence username, VPS IPv4, and script expiry, and still opens from cache when both auth sources are unreachable.

## LICENSE heading - three VPS (2026-11-02)

- **Change:** updater `b505a19` (target `aa75243d5230512f24c7ea84eeef0211eebc64f2`, Fix 528) moved rohserver6, rohserver1, and rohserver3 from `d2d61da` to `aa75243`; all three reported `UPDATE SUCCESS` and now have `.update-commit=aa75243d5230512f24c7ea84eeef0211eebc64f2`. Backups: `/root/fn-update-backup-20261102-121208` (rohserver6), `-041208` (rohserver1), `-121208` (rohserver3).
- **Rendered menu:** all three showed `LICENSE` immediately above the same five lines: `Username`, `IPv4`, `Expired`, `Installed version`, `Updated version`. The heading uses the same purple style as `TOTAL ACCOUNTS` and `MENU`.
- **Offline:** a fake `curl` that failed every request still rendered the `LICENSE` block from cache with `(cached)` values and `menu_rc=0` on all three.
- **Health:** all 12 checked services per box stayed active, `systemctl --failed` was empty, and no new auth, lock, expiry, or unbound-variable errors appeared.
- Result: the licence and version lines are now grouped under a labelled section instead of appearing as unlabelled text.

## Account cards - rotated domain only - three VPS (2026-11-02)

- **Change:** updater `efffd2a` (target `5556e2b327744656e04b352b6a64950dbeb8be00`, Fix 530) moved rohserver6, rohserver1, and rohserver3 from `aa75243` to `5556e2b`; all three reported `UPDATE SUCCESS` and now have `.update-commit=5556e2b327744656e04b352b6a64950dbeb8be00`. Each full payload fetched 107 files. Backups: `/root/fn-update-backup-20261102-131151` (rohserver6), `-051240` (rohserver1), `-131345` (rohserver3).
- **Installed code:** every checked `/usr/bin` card script (`add-vmess-ws`, `add-vless-xhttp`, `add-trojan-grpc`, `trial-vmess-http`, `addssh`, `trial-ssh`, `menu-wg`, `xl2tp`, `menu-noobz`) reports `Installer Domain` count 0 and `Rotated Domain` count 1 on all three. Local and installed md5s match for the five sampled scripts. `dm-menu` still shows the installer domain (four rows); `menu` still carries `LICENSE`/`Found 528`; `backup` still carries `Found 529`.
- **Card channels:** the hash-matched `add-vmess-ws` template rendered with dummy values omitted `Installer Domain` from both the plain Telegram/log text and the `format_display` TUI output, while keeping `Rotated Domain`.
- **Menu regression check:** `TERM=xterm /usr/bin/menu </dev/null` on all three still rendered `LICENSE`, `Username`, `IPv4`, `Expired`, `Installed version : 6b967af`, and `Updated version : 5556e2b`.
- **Health:** `systemctl --failed` is empty; Nginx, HAProxy, `quota-xhttp`, `xray@xhttp`, SSH, and Dropbear are active on all three; no new `quota-xhttp` error or unbound-variable lines appeared.
- **Historical data:** pre-fix card logs that still contain the old row number 1 on rohserver6, 5 on rohserver1, and 0 on rohserver3 (67/64/54 total cards). New cards omit it; already-sent Telegram messages are unchanged. No historical log was rewritten.
- Result: account cards now show the rotated domain as the single user-facing domain row, while the installer domain remains only in the Domain Menu and internal Nginx/certificate anchor.

## Post-Fix-530 configuration audit - three VPS (2026-11-02)

- **Scope:** read-only audit after the Fix 530 deploy (target `5556e2b`): systemd units/timers, Nginx, HAProxy, SSH/Dropbear, cron, all four Xray JSON configs, Noobz JSON, domains/certificates, permissions, quota/IP-limit state, backup log, and journal since the update. No live file was changed.
- **Version and changed code:** all three boxes have `.update-commit=5556e2b327744656e04b352b6a64950dbeb8be00` and `.install-commit=6b967af9e0ebadc76a265132e49d62a27ad72235`; the menu still shows `Installed version : 6b967af` / `Updated version : 5556e2b`. All 29 `full/` scripts changed by `5556e2b` match the installed `/usr/bin` files by sha256 (the lite edition is not installed). Marker checks pass: `backup` = `Found 529`, `menu` = `Found 528`, `menu-wg`/`xl2tp`/`menu-noobz` = `Rotated Domain`, `dm-menu` = `Installer Domain`.
- **Fix 530 checks:** every installed card script has zero `Installer Domain` rows; only the non-card tools `dm-menu` and `limit-ip` retain the installer-domain wording. `dm-menu` still prints `Installer Domain` and the rotated list. No card or menu regression was found.
- **Systemd/config/JSON:** `systemctl is-system-running` is `running`; `systemctl --failed` is empty; all listed panel units are active (`ipsec` is enabled as an alias), and both fixnet timers report `Result=success`. `nginx -t`, `haproxy -c`, `sshd -t`, `fail2ban-client -t`, `squid -k parse`, `wg-quick strip wg0`, and the xl2tpd config test pass. All four Xray JSONs pass `xray run -test`; after stripping `#`/`###` marker lines they are valid JSON. `/etc/noobzvpns/config.json` and `db_user.json` pass `jq`. The only config-parser output is the pre-existing HAProxy backend `option tcplog` warning.
- **Domains/certificates:** `server_name` matches the installer + rotated lists on all three and the rotated lists have no duplicates. The self-signed `xray.crt` is valid to Oct 2027, its SAN covers every served name, and the HAProxy PEM fingerprint matches it. `xray.key` is `0600`, `xray.crt` `0644`, `funny.pem` `0600`; the Noobz `key.pem` is a symlink to the `0600` Xray key.
- **Cron:** `/etc/crontab` contains the expected `xp`, `limit-ip-*`, `auto-delete-*`, `kill-*`, `expire-ssh`, and `backup` jobs; every command resolves and there are no `at` jobs. `xp` and `limit-ip-xhttp` ran on schedule. No `xhttp.json busy` line, no new `(expiry )` line, and no new account deletion appeared after the update. The latest rohserver3 backup entry (02-Nov 12:00) has the correct IPv4; its three blank `IP     :` rows are historical (12-Oct, 20-Oct, 01-Nov), confirming the Fix 529 path works.
- **Account/quota state:** every carded account has a matching JSON entry, quota base, and IP limit on rohserver1 and rohserver3. rohserver6 still has the previously documented `ws/simpang32` usage-only file (no quota or IP-limit file) while the card says 100 GB / IP 2; all other carded accounts have both files. Several operator-created but unused WS accounts still lack an `_usage` file (4/6/1), which is expected until first traffic. `rohcuan` on rohserver1 is an existing OS user with a stale SSH limit file and no card. The xHTTP template defaults `2019@gmail.com`, `2020@gmail.com`, and `2023@gmail.com` remain alongside the cards; the HTTP/gRPC configs likewise keep three null-email template clients each.
- **Pre-existing issues observed, not caused by Fix 530:** `/var/log/xray/xhttp.log` is 300-403 MiB and growing (~20-30 MiB/day) with no xray logrotate entry; `kill-xhttp` does not truncate it and `limit-ip-xhttp` scans the whole file per user each run. Cron mailboxes are 82-115 MiB of repeated `TERM environment variable not set.` from `clear` in cron-run `limit-ip-*` scripts; the first message dates from 19-Oct. L2TP kernel support is missing on rohserver6 and rohserver3 (`ppp_generic`, `pppox`, and `l2tp_ppp` absent; pppd reports `/dev/ppp` errors), while rohserver1 has the modules. The `dnstt` unit nameserver still differs from `/etc/slowdns/nsdomain` on all three (unit file older than the nsdomain file), so SlowDNS delegation should be verified separately.
- **Post-update journal:** no `unbound variable`, `command not found`, auth-source, JSON-lock, expiry, or failed-start entry appeared after the update. rohserver6's post-update entries are the pre-existing pppd/L2TP failures; rohserver3's are external Nginx `.env` scanner requests. `xray@ws` on rohserver6 and `xray@xhttp` on rohserver1 have non-zero historical restart counters, but both became active before the Fix 530 deploy, so they are not caused by it.
- **Result:** no post-Fix-530 configuration regression was found. Code, markers, services, config parsers, JSON, domains, certificates, cron, and account guard files are consistent with target `5556e2b`; the items above are pre-existing operational issues and remain read-only findings.

## xHTTP log bound and cron mailbox - three VPS (2026-11-02)

- **Change:** updater `622fbd6` (target `7a56d8dda91f3f90a5fc65fef456b4d11f1b842a`, Fix 531/532) moved rohserver6, rohserver1, and rohserver3 from `5556e2b` to `7a56d8d`; all three reported `UPDATE SUCCESS` and `.update-commit` now matches. Each full payload fetched 107 files. Backups: `/root/fn-update-backup-20261102-150844` (rohserver6), `-070932` (rohserver1), `-151112` (rohserver3).
- **Installed code:** the 16 changed full scripts (`xp`, `expire-ssh`, `limit-ip-*`, `auto-delete-*`, `kill-*`, `backup`) match the local sha256 on all three. `kill-xhttp` carries `Found 531` and `Found 532`; `xp` and `limit-ip-xhttp` carry `Found 532`. The `kill-xhttp` truncation is the final command, after quota deletion, Telegram, and the one `xray@xhttp` restart.
- **xHTTP log:** before deployment the file was 403 MiB (rohserver6), 300 MiB (rohserver1), and 300 MiB (rohserver3). After the first post-deploy `kill-xhttp` cron tick: 27 KiB, 28 KiB, and 20 KiB. The next `limit-ip-xhttp` run has a small recent window instead of scanning the whole historical log.
- **Cron mailbox:** root mailboxes were 120,179,204 / 85,681,773 / 99,616,713 bytes, with mtimes 15:05:52 / 07:10:34 / 15:10:45, all before the update. They stayed unchanged through the first post-deploy cron tick and no new cron message was delivered. The non-TTY guard suppresses stdout/stderr before `clear`, so the previous `TERM environment variable not set.` flood stops at the source; old mail is left in place.
- **Health:** `systemctl --failed` is empty and Nginx, HAProxy, all four Xray units, all four quota units, SSH, and Dropbear are active on all three. The only post-update `TERM` journal line is the pre-existing `quota-xhttp` startup message from its service restart; the quota daemons were not part of the cron-output change.
- Result: both fixes are live through `update.sh`; the xHTTP log is bounded at the same 5-minute cadence as `ws.log`, and routine cron runs no longer grow root mail.

## Fix 533-538 - three VPS (2026-11-02)

- **Change:** updater `5de3d54b671bc80c08e111afea8b38fd342bd856` (target `0cf5dc1df15bf1817b9137e419cfb117cc44b685`, Fix 533 payload plus Fix 534-538 migrations) moved rohserver6, rohserver1, and rohserver3 from `7a56d8d` to `0cf5dc1`; all three reported `UPDATE SUCCESS` and `.update-commit` matches. Each full payload fetched 107 files. Backups: `/root/fn-update-backup-20261102-163613` (rohserver6), `-083727` (rohserver1), `-163827` (rohserver3).
- **Installed code:** the eight changed quota scripts (`full/` and `lite/` `quota-{ws,http,grpc,xhttp}.sh`) carry `Found 533`; the four installed full scripts match the local sha256 on all three boxes. `update.sh` restarts all four active `quota-*` services after the swap. `lite` is not installed on any live host.
- **Fix 533 - quota startup:** no `TERM environment variable not set.` line appeared after the restarted quota daemons on any box; the old pre-update journal entries remain historical. `haproxy -c` reports `Configuration file is valid`; the backend `option tcplog` count is 0 while the `ssh-ssl` frontend still has `option tcplog`, `option logasap`, and `log global`.
- **Fix 534 - dnstt:** the unit now uses the saved nsdomain on all three: rohserver6 `ns.jalanlancar7.my.id` (was `ns.kainmurah.us.ci`), rohserver1 `ns.lancarjaya1.my.id` (was `ns.mierebus.cc.cd`), rohserver3 `ns.haribaik4.my.id` (was `ns.basrengkita.us.ci`). `dnstt` is active on all three and the old unit is saved in the updater backup and `/root/fn-dnstt-backup-*.service`.
- **Fix 534 DNS caveat:** public DNS still has no `A`, `AAAA`, or `NS` record for the three `ns.*` names. The parent domains resolve to the VPS addresses (`jalanlancar7.my.id` -> 64.120.94.62, `lancarjaya1.my.id` -> 103.210.69.33, `haribaik4.my.id` -> 157.10.253.95), and their NS records point at Cloudflare. The unit is now internally consistent, but SlowDNS still needs the operator to publish or delegate the chosen name at the DNS provider; the updater does not create DNS records.
- **Fix 535 - simpang32:** rohserver6 only. `/etc/xray/quota/ws/simpang32` = `107374182400` and `/etc/xray/limit/ip/xray/ws/simpang32` = `2`; `simpang32_usage` remains 459,069,462 bytes. `list-xray-ws` reports `Limit IP: 2`, `Limit Quota: 100 GB`, and `Status Account XRAY: unlocked`. The card and usage file are in the updater backup. rohserver1 and rohserver3 have no simpang32 card and skipped the migration.
- **Fix 536 - default credentials:** all four live JSONs were already free of `rerechan-store`, `cfbbaafc-...`, `019e0bf3-...`, `af7d5cf8-...`, `diy2020`, and `nonescript-fn-project`; the installer's existing randomization had already run. The migration marked `.fix536-default-creds` without changing a file, and all four configs still pass `xray run -test` on every box. The template client objects remain as insertion anchors.
- **Fix 537 - root mail:** mailboxes were 120,179,204 / 85,681,773 / 99,616,713 bytes and are now 0 bytes with owner `mail:mail`, mode `0600`. Archives: `/root/fn-mail-backup-20261102-163651.gz` (2.5 MB), `-083812.gz` (1.8 MB), `-163846.gz` (2.2 MB); all pass `gzip -t`. The 16:40/08:40 cron tick ran all `limit-ip-*`, `kill-*`, `auto-delete-*`, and `expire-ssh` jobs and the mailbox mtime did not change.
- **Fix 538 - rohcuan:** rohserver1 only. `/etc/xray/limit/ip/ssh/rohcuan` was removed; `getent passwd rohcuan` still returns the OS user (`/home/rohcuan`, `/bin/bash`) and no panel card exists. The file was copied to the updater backup. rohserver6 and rohserver3 had no such file.
- **Health:** `systemctl --failed` is empty on all three; Nginx, HAProxy, SSH, Dropbear, `xray@{ws,grpc,xhttp,upgrade}`, `quota-{ws,http,grpc,xhttp}`, and `dnstt` are active. All four Xray configs pass `xray run -test`; no new account deletion, JSON lock, or unbound-variable error appeared after the update.
- **Markers:** rohserver6 has `.fix534-dnstt-synced`, `.fix535-simpang32`, `.fix536-default-creds`, `.fix537-mail-cleared`; rohserver1 has the same except `.fix535` plus `.fix538-rohcuan-limit`; rohserver3 has `.fix534`, `.fix536`, and `.fix537`. The missing markers are for migrations that did not apply to that host.
- Result: the six approved follow-ups are live through `update.sh`. The only remaining SlowDNS action is external DNS delegation for the chosen `ns.*` names.

## Fix 539-540 - three VPS (2026-11-02)

- **Change:** Fix 539 payload `24931ce37b27c9963600aeb2a29bbe198b697b6f` (updater `255298eed6ecb62970899b00729babad546204a1`) removes the template client anchors and adds `/usr/bin/xray-add-client`. Fix 540 payload `42af316784c87cf6fc8af3638b5fe02ef83caddd` (updater `5d123973f4a194ab5255d5083b5033320e0fd1f8`) changes `limit-ip-ssh` to enroll panel accounts only. All three boxes ended at `42af316`; each run reported `UPDATE SUCCESS` and `.update-commit` matches. rohserver6 and rohserver1 moved `0cf5dc1 -> 24931ce -> 42af316`; rohserver3 moved `0cf5dc1 -> 42af316` in one combined run. Each full run fetched 108 files. Backups: Fix 539 `/root/fn-update-backup-20261102-170422` (rohserver6), `-090606` (rohserver1); Fix 540 `-171211` (rohserver6), `-091006` (rohserver1); rohserver3 combined `-171211`.
- **Fix 539 - anchors:** the pre-migration backups held 12 anchor markers each (3 per JSON); the live `/etc/xray/json` files now hold 0. Account counts are unchanged before -> after: rohserver6 `ws 25 -> 25`, `xhttp 29 -> 29`; rohserver1 `31 -> 31`, `22 -> 22`; rohserver3 `18 -> 18`, `21 -> 21`; `upgrade` and `grpc` are empty on all three. All four configs pass `xray run -test` on every box. The installed `/usr/bin/xray-add-client` carries `Found 539`.
- **Fix 539 - insertion:** on live copies of the post-migration configs on rohserver6 and rohserver3, the helper inserted vless/vmess/trojan into `ws`, vless into `upgrade`, vmess into `xhttp`, and trojan into `grpc`. Every file passed `xray run -test` and every inserted user produced the expected `### <user> 01-Jan-2027` marker. The delete path (remove marker and client, strip the trailing comma) was tested on the live `ws.json` copy and stayed valid after sequential insertions.
- **Fix 540 - rohcuan:** on rohserver1 `/etc/xray/limit/ip/ssh/rohcuan` was removed again by `.fix540-rohcuan-limit`; `getent passwd rohcuan` still returns the OS account. The limit-file set now matches the SSH card set exactly (`cuka2` through `topi9`, 11 accounts) and the file stayed absent after the post-deploy cron tick. rohserver6 and rohserver3 had no `rohcuan` file, so their migration skipped and no `.fix540` marker was written.
- **Health:** all three boxes have no failed units; Nginx, HAProxy, SSH, Dropbear, `xray@{ws,grpc,xhttp,upgrade}`, `quota-{ws,http,grpc,xhttp}`, and `dnstt` are active. `simpang32` on rohserver6 still has quota `107374182400`, IP limit `2`, and usage 530,869,817 bytes. No new JSON, lock, expiry, or unbound-variable error appeared after the updates.
- Result: the templates no longer ship a usable default client, account insertion no longer depends on an anchor object, and the recurring `rohcuan` SSH limit file is gone while the OS user remains.

## Fix 541 - domain deletion cleanup - three VPS (2026-11-02)

- **Change:** updater `d02276a5f2f80cde463a8e5577bf839997f3683f` (target `ac4555d5bdff28be02374b4c82c456049cb601b2`) moved rohserver6, rohserver1, and rohserver3 from `42af316` to `ac4555d`; all reported `UPDATE SUCCESS` and `.update-commit` matches. Each full run fetched 108 files. Backups: `/root/fn-update-backup-20261102-180010` (rohserver6), `-100118` (rohserver1), `-180118` (rohserver3). The updater runs `.fix541-domain-cleanup` once.
- **Installed code:** `/usr/bin/dm-menu` carries five `Found 541` markers on all three. The installed `full` payload matches the local source. Domain Menu option 2 now removes the rotated-list entry, Nginx `server_name`, active certificate SAN, HAProxy PEM, ACME/Certbot state, and card references (including base64 `vmess://` links), then reloads Nginx/HAProxy without restarting NoobzVPN.
- **Stale SAN cleanup:** rohserver6's certificate SAN previously contained `jualbatik.us.ci`; it is now absent. rohserver1's previously contained `garamkristal.cc.cd`; it is now absent. rohserver3 had no stale name. Every certificate now contains exactly the installer domain plus the current rotated names. The old certificate/key/PEM are in the updater backup under `domain-cleanup/`; `/etc/xray/.quota.logs` keeps one audit line naming the removed entry.
- **SNI fallback:** `openssl s_client` against `127.0.0.1:443` with SNI `live.iflix.com` and with SNI `deleted-test.invalid` completed the handshake on every box. Nginx returned the current self-signed certificate (`Verify return code: 18`), proving that arbitrary SNI plus `allowInsecure=yes` still reaches the default 443 server after a name is removed.
- **Connection safety:** the migration and the delete path use `systemctl reload nginx` and `systemctl reload haproxy`; there is no restart of Nginx, HAProxy, Xray, NoobzVPN, or quota services. The `noobzvpns` unit has no reload and was deliberately left alone. Existing sessions therefore survive the certificate update.
- **Health:** `systemctl --failed` is empty; Nginx, HAProxy, SSH, Dropbear, `xray@{ws,grpc,xhttp,upgrade}`, `quota-{ws,http,grpc,xhttp}`, `dnstt`, and `noobzvpns` are active on all three. `nginx -t` passes and the HAProxy PEM fingerprint matches `xray.crt` on every box.
- Result: deleting a dead domain now leaves no configuration/certificate remnant and reassigns its account cards to a live domain, while the default Nginx server keeps arbitrary-SNI `allowInsecure` connections working and no service is restarted.

## Fix 542 - balanced card reassignment - three VPS (2026-11-02)

- **Change:** updater `310fa0fb8c010da368a08ab6fe2dde3721f1669a` (target `64226365c68774828e3d85ab51bf0b995c134593`) moved rohserver6, rohserver1, and rohserver3 from `ac4555d` to `6422636`; all reported `UPDATE SUCCESS` and `.update-commit` matches. Each full run fetched 108 files. Backups: `/root/fn-update-backup-20261102-183207` (rohserver6), `-103207` (rohserver1), `-183207` (rohserver3).
- **Installed code:** `/usr/bin/dm-menu` carries `Found 542` on all three and matches the local sha256 (`fc8f2022f4eb5a33421fa6a180eb627c744e4b9f426f0cad38a9c5e87598e407`). Account creation, deletion, quota, JSON, certificate, and service code are otherwise unchanged from Fix 541.
- **Balancing test:** a sandbox started with 2 cards on `live1`, 1 on `live2`, and 3 on `dead`; deleting `dead` produced `live1=3`, `live2=3`, `dead=0`. The base64 `vmess://` card decoded to the assigned domain, and no plain or encoded `dead.example.com` reference remained. The same run called only `systemctl reload nginx` and `systemctl reload haproxy`.
- **Health:** `systemctl --failed` is empty on all three; the certificate SAN, HAProxy PEM, domain lists, and services are unchanged from Fix 541. No live cards were moved because no domain has been deleted on the boxes since the deployment.
- Result: deleting a domain now distributes its cards across the least-used remaining domains, keeping the rotation balanced instead of sending everything to the first domain.

## Fix 543 - SlowDNS NULL queries - three VPS (2026-11-03)

- **Change:** updater `da7c76957681f6dd25e9086a471d09728bea7b6e` (target `5f378ba4e1b66a71cdafe658be3b35dbad86e1a7`, Fix 543) moved rohserver6, rohserver1, and rohserver3 from `6422636` to `5f378ba`; all reported `UPDATE SUCCESS` and `.update-commit` matches. `.fix543-dnstt-null` is present on all three. Each full run fetched 108 files. Backups: `/root/fn-update-backup-20261103-104411` (rohserver6), `-024553` (rohserver1), `-104628` (rohserver3); each backup contains the previous 7,261,921-byte `dns-server`.
- **Root cause evidence:** a packet capture on rohserver6 during the failing HTTP Custom attempt contained 426 inbound NULL queries from `202.152.254.73` and `202.152.254.75` to `64.120.94.62:53`, all under `ns-sg1.rohcuan.dpdns.org`; the unpatched server answered every one with `NXDOMAIN` and logged no session. A direct local probe reproduced NULL -> `NXDOMAIN`, TXT -> `FORMERR` (512-byte EDNS), and A -> `NXDOMAIN`. The working provider's authoritative server (`103.93.134.232`) answered the same NULL probe with `NOERROR`, one NULL answer, and zero-length RDATA, which defined the expected response shape.
- **Server verification:** on all three boxes, `dig @127.0.0.1 -p 5300 -t TYPE10 <40×a>.<nsdomain>` now returns `status: NOERROR`, `ANSWER: 1`, and `IN NULL`; `dnstt` is active and `systemctl --failed` is empty. The patched binary is built from dnstt commit `17aa1fed864cd5493e3d09a14df1b8b5cc1df123` with `installer/dnstt-null.patch`.
- **End-to-end NULL:** a patched NULL client on rohserver1 used rohserver6's real public key (`286ad791…651e`) and `ns-sg1.rohcuan.dpdns.org` through `64.120.94.62:53`. It established session `a7cc2ae1`, opened a stream, and received `SSH-2.0-OpenSSH_9.2p1 Debian-2+deb12u10`. A local run through rohserver6's real service and key also received the banner (session `2afee445`).
- **TXT compatibility:** the unmodified TXT client completed the same external path (session `36c41ff7`) and the local path (session `acd4bc0f`); both received the SSH banner. No TXT regression was found.
- **Scope:** no key, `/etc/slowdns/nsdomain`, systemd unit, firewall rule, DNS record, Xray, Nginx, HAProxy, SSH, Dropbear, or quota service was changed. Only `dnstt` was restarted by the migration. Temporary test binaries, sources, captures, and the two raw-table probe rules were removed.
- **Re-run:** after the deployment, `update.sh` on all three boxes returned `Already at 5f378ba4e1b66a71cdafe658be3b35dbad86e1a7 (...) Nothing to do.`
- **Caveat:** rohserver3's delegated name `ns.haribaik4.my.id` still has no public DNS record and remains a placeholder; the local TYPE10 probe validates its binary, not public delegation. rohserver6 and rohserver1 have working public SlowDNS paths.
- Result: HTTP Custom's NULL query mode is now served by all three patched dnstt binaries, and standard TXT clients continue to work.

## Fix 544 - SlowDNS CNAME/NS/MX/SRV support - three VPS (2026-11-03)

- **Change:** updater `9f33cefd1f37453729c79f56ca93baf2c92b55bc` (target `f6cb3b1ab5b30e4b8b6100309fdb657adad82d5d`) moved rohserver6, rohserver1, and rohserver3 from `5f378ba` to `f6cb3b1`; all reported `UPDATE SUCCESS`, `.update-commit` matches, `.fix544-dnstt-multi` is present, and 108 files were verified. Backups: `/root/fn-update-backup-20261103-114142` (rohserver6), `-034309` (rohserver1), `-114309` (rohserver3); each holds the previous `dns-server` (7,261,833 bytes; rohserver6's backup is 7,261,825 bytes).
- **Root cause:** HTTP Custom's Type dropdown sends QTYPE `16` TXT, `10` NULL, `5` CNAME, `2` NS, `15` MX, or `33` SRV. The Fix 543 binary accepted only TXT/NULL and answered the rest with `NXDOMAIN`, so those clients timed out before SSH authentication. The app's `libaio.so` maps those six names directly to the QTYPE values and decodes CNAME/NS as base32 names, MX/SRV as a 2/6-byte prefix plus a base32 name, NULL as raw bytes, and TXT with the length-prefixed decoder. The working provider `ns-id-biz.suneku.web.id` (`103.93.134.232`) returns lowercase base32 names for non-empty CNAME/MX/SRV answers, confirming the case and shape.
- **Server verification:** local `dig` on all three returns `status: NOERROR` with an answer for TYPE2, TYPE5, TYPE10, TYPE15, TYPE16, and TYPE33. Representative empty answers are `IN NS .`, `IN CNAME .`, `IN NULL \# 0`, `IN MX 0 .`, `IN TXT ""`, and `IN SRV 0 0 0 .`, matching the working provider's format. `dnstt` is active on every box and `systemctl --failed` is empty.
- **End-to-end:** the patched six-type client opened an SSH stream through the live public service on rohserver6 (6/6) and rohserver3 (6/6) from the sandbox, each receiving `SSH-2.0-OpenSSH_9.2p1 Debian-2+deb12u10`. rohserver1 passed 6/6 when the client ran on rohserver6, because the sandbox shares rohserver1's public IP and a direct loopback to its own port 53 is hairpin traffic. Empty-payload probes sent to the live server were answered with the expected per-type root names.
- **Bulk and MTU:** a local 512 KiB pseudorandom download completed byte-identically (matching SHA-256) through each of the six types. Server logs show MTU 932 for TXT/NULL and 153 for name-based sessions; no `encodePayloadAsName` error appeared. The same six-type test built with the VPS's Go 1.22 toolchain passed on rohserver1 before deployment.
- **Resolver checks:** Cloudflare DoH returned `Status 0` with one answer for all six types on `ns.rohserver1.dpdns.org`. Google DoH returned SERVFAIL for the tunnel domain, but it also returns SERVFAIL for the known-working provider `ns-id-biz.suneku.web.id`, so that behaviour is external to this server. Direct UDP 1.1.1.1 and fresh-name 8.8.8.8 queries returned NOERROR for the tested types.
- **Scope:** no key, `/etc/slowdns/nsdomain`, systemd unit, firewall rule, DNS record, Xray, Nginx, HAProxy, SSH, Dropbear, or quota service was changed. Only `dnstt` was restarted. Temporary test binaries, sources, patches, and probe scripts were removed from all three boxes; no stray `dns-server` or client process remains.
- **Re-run:** a second `update.sh` on all three boxes returned `Already at f6cb3b1ab5b30e4b8b6100309fdb657adad82d5d (...) Nothing to do.`
- **Caveat:** rohserver3's delegated name `ns.haribaik4.my.id` still has no public DNS record and remains a placeholder. Its direct-IP six-type test validates the binary, not public delegation; rohserver6 and rohserver1 have working public SlowDNS paths.
- **Regression audit (post-deploy):** the previous Fix 543 binary and the live Fix 544 binary were run side by side on rohserver6. All 19 cases that must not change were byte-identical: TXT, NULL, A, and AAAA at EDNS 4096/512/none; out-of-domain, apex, short-payload, two-question, opcode 1, class CH, and empty-name queries. The only differences were the four new types, where the old binary returned `NXDOMAIN` and the new one returns `NOERROR` with one answer. Six concurrent 1 MiB downloads (one per type) through a single server all matched SHA-256, with 2 sessions at MTU 932 and 4 at 153 and no `encodePayloadAsName`, `SetMtu`, or upstream errors. An encoder unit test round-tripped 0-155-byte payloads for all four name types (155 bytes = 248 base32 chars), kept the name within 255 octets, applied the MX/SRV prefixes, and rejected oversized input; the name-based budget stayed 155 versus 932 for TXT/NULL. All three live boxes remain at `f6cb3b1`, both markers present, `dnstt` active with 0 restarts, 0 failed units, and no error lines. Local six-type probes returned `NOERROR` with an answer on each box, and cross-host probes to public UDP 53 returned `NOERROR` with one answer for all six types on all three (rohserver6-to-itself is a known hairpin and was tested from rohserver3). No regression found.
- **Config audit (post-deploy):** the live units match the installer templates byte-for-byte: `dnstt.service` (with the synced nsdomain in `ExecStart`), `slowdns-fixnet.service`, `slowdns-fixnet.timer`, and `/usr/local/bin/slowdns-fixnet.sh`. `dnstt` is enabled and active with 0 restarts and no drop-ins; the fixnet timer is enabled/active and its last run succeeded. Each host has exactly one UDP 53 to 5300 nat redirect and one UDP 5300 INPUT accept, the redirect is ahead of the wildcard UDP captures, both `/etc/iptables.up.rules` and `/etc/iptables/rules.v4` hold one copy, `netfilter-persistent` is enabled/active, and no legacy rules conflict. There are no dnstt/SlowDNS cron entries, no extra slowdns units or timers, and no JSON file references SlowDNS or was modified by the deploy; the Xray JSON is unchanged since install and valid. `server.key` is mode 600, `server.pub` matches the key derived by the live binary, `nsdomain` matches the unit, and both markers are mode 600. Only `dnstt` restarted; SSH, Nginx, HAProxy, cron, and Xray start times predate the binary. `systemctl --failed` is empty. Three one-off `chacha20poly1305: message authentication failed` lines on rohserver6 at 12:27 were stale/wrong-key handshakes (none before, and 15 valid session events followed); rohserver1's only UDP 53 listeners are systemd-resolved stubs on 127.0.0.53/54, not a public conflict.
- **Config cleanup (post-audit):** rohserver6's static `/etc/resolv.conf` had 12 lines with repeated `nameserver`, `domain`, and `search` directives. The new updater housekeeping reduced it to 5 lines (three unique nameservers), kept the original as `/root/fn-update-backup/resolv.conf.20261103-133314` (12 lines, SHA-256 `24821615...a9af6`), and left DNS resolution working (`getent hosts github.com` and an HTTPS fetch returning 200). A second run made no change. rohserver1 (two unique nameservers plus systemd-resolved comments) and rohserver3 (one nameserver) were untouched. `installer/slowdns.sh` now only prepends `nameserver 1.1.1.1` when that exact line is absent and never replaces a resolver-managed symlink. rohserver3's `ns.haribaik4.my.id` still needs an `A` record in its Cloudflare zone; the apex already points to `157.10.253.95`, and the VPS has no zone credentials.
- Result: HTTP Custom's TXT, NULL, CNAME, NS, MX, and SRV Type settings are served by all three patched dnstt binaries, and standard TXT/NULL clients continue to work.

## Fix 545 preparation (2026-11-12, read-only)

- **Scope:** prepared the shared CGNAT-aware Xray IP limiter for `sg1.rohcuan.dpdns.org` (64.120.94.62), `id1.rohcuan.dpdns.org` (103.210.69.33), and `id2.rohcuan.dpdns.org` (157.10.253.95). No live file, service, cron entry, JSON config, or account was changed.
- **Host check:** all three are full-edition hosts at `.update-commit=f6cb3b1ab5b30e4b8b6100309fdb657adad82d5d` with the old four-copy `limit-ip-*` scripts, the same `xray@` stats ports, and the same `/etc/xray/limit/ip/xray/<transport>` and `/var/log/create/xray/<transport>` layout. Only `ws` and `xhttp` currently have `/etc/xray/autounlock/<transport>` directories; the limiter creates the directory when it locks an account, as before.
- **Evidence:** on id2, `siram44` (VLESS WS, limit 4) showed four stable CGNAT addresses in two correlated pairs plus two transient addresses; six IPs were briefly active, but the old 4-minute gate did not lock. The account is consistent with two phones, not four. See Found 545.
- **Local test:** an 18-case harness with a fake Xray API passed rotation, stable multilogin, spike reset, old-state migration, existing `.locked` skip, long-gap reset, early-due retention, and auto-unlock. A separate two-user restart-batching harness confirmed two locks in one pass produce two restarts (one immediate, one final), not one restart per locked user. `bash -n` passes for every changed script; `tools/verify-payload.sh` reports 121 full / 103 lite entries with no orphans.
- **Deployment:** completed 13-Nov-2026; see the deployment section below. Payload `da88b63` adds `limit-ip-common`; updater `27e504e` pins that commit and marker-checks all five files for `Found 545`. The cron schedule and existing limit files are unchanged.

## Fix 545 deployment - three VPS (2026-11-13)

- **Deploy:** updater `27e504e` (target `da88b63`) moved `id2` at 00:57:52, `id1` at 00:59:49, and `sg1` at 01:00:23 WIB from `f6cb3b1` to `da88b63`; each reported `UPDATE SUCCESS` with 109 files and 5 binaries. Backups: `/root/fn-update-backup-20261113-005752` (id2), `-005949` (id1), `-010023` (sg1).
- **Pre-deploy audit (read-only):** all three were full-edition `f6cb3b1` hosts with `.install-commit=6b967af`; all four `xray@` units, all four `quota-*` units, nginx, haproxy, ssh, dropbear, cron, and dnstt were active, with no failed units. All four JSON configs passed `xray run -test` and jq, and were byte-identical before and after. No template anchors or published default credentials were present. Domain files were already migrated, certificate SANs matched the installer+rotated list, HAProxy logging and SSH/Dropbear banners were already wired, and both mailboxes were empty. The conditional Fix 535/538/540 migrations had no matching account. The `/etc/resolv.conf` tidy was a no-op (id1 is resolver-managed; sg1 and id2 are clean). id1 had 1.2 GB free at 94% disk use, enough for the 21 MB backup.
- **Post-deploy verification:** `.update-commit=da88b63` on all three; `/usr/bin/limit-ip-common` is present (11,220 bytes, md5 `ca6cfdc220d6de4a8e4418286e1bc455`) and all five limiter files carry `Found 545`; the menu shows `Installed version : 6b967af` / `Updated version : da88b63`. No failed units; every service active; all four JSON md5s unchanged; quota services restarted at update time with no warnings; `/etc/crontab` unchanged.
- **Limiter live behavior:** the new sampler ran on the 01:05, 01:10, and 01:15 ticks on all three hosts (12 processes per host during a pass). Version-2 state files appeared with fresh `last` timestamps. `siram44` on id2 (limit 4) showed 2–3 simultaneous CGNAT IPs and stayed at `over 0`; no state file showed `over > 0`, no state had more eligible IPs than its limit, and no sample was stale. No `.locked` card and no Xray auto-unlock due file appeared. No false lock occurred during the 17.5–20 minute observation.
- **Stability during the observation window:** all four `xray@` units on all three hosts kept `NRestarts=0` (id2's `xray@xhttp` counter was already 1 from the pre-existing 07:33 crash). No new `fatal error` or `panic:` lines appeared during the 17.5–20 minute window. Load settled to sg1 1.6–2.7, id1 0.4–0.8, and id2 0.4–0.6 on 4/4/2 cores.
- **Later post-deploy observation (07:26 WIB):** sg1's `xray@ws` panicked at 01:24:31 and restarted at 01:24:41; id1's panicked at 05:29:11 and restarted at 05:29:15. Both are the same pre-existing Xray 25.3.6 `fatal error: concurrent map read and map write` signature (`app/stats.(*OnlineMap).AddIP`), and systemd recovered in 3–4 seconds; id2 had no new `ws` panic. This is an upstream Xray race: current upstream `main` replaces `OnlineMap` with a mutex-protected refcount implementation (`ForEach` holds the lock), so the proper fix is an Xray upgrade tracked separately. The updater, JSON, services, menu, cron, and limiter files are unaffected.
- **Unrelated live observations:** `/var/log/syslog` was 4.3–5.5 GB on id1/id2 and id1 was at 94% disk; both predated this change and were cleaned on 13-Nov-2026 (see the log-cleanup section below). An unrelated SSH lock (`renyah80`, limit 2) created `/etc/xray/autounlock/ssh/renyah80` at 01:10 with a 15-minute due time and unlocked on the next sweep; a second (`udang75`) unlocked at ~07:25 after its 07:20 due time, and `sambal1` unlocked after 07:30. Those are the existing SSH limiter, not Fix 545.
- **Result:** Fix 545 is live on all three hosts with no regression found in the updater, JSON configs, services, menu, cron, or limiter behavior. The only operational risk is the pre-existing Xray 25.3.6 `OnlineMap` race; plan an Xray upgrade separately.

## Log cleanup - id1/id2 (2026-11-13)

- **id1:** disk went from 943 MB free (96%) to 13 GB free (34%); `/var/log` went from 14 GB to 2.3 GB. The 5.1 GB active `syslog` and 5.5 GB `syslog.1` are now `syslog.2.gz` (475 MB) and `syslog.3.gz` (549 MB); the oldest compressed archive was removed by the existing `rotate 4` retention. Journal capped from 1.9 GB to 490 MB.
- **id2:** disk went from 4.5 GB free (77%) to 14 GB free (27%); `/var/log` went from 11 GB to 1.9 GB. The 4.0 GB active `syslog` and 4.3 GB `syslog.1` are now `syslog.2.gz` (364 MB) and `syslog.3.gz` (409 MB). Journal capped from 1.9 GB to 457 MB.
- **Method:** two forced `logrotate` runs for rsyslog under the existing weekly/rotate-4/compress/delaycompress policy, one forced nginx rotation, and `journalctl --vacuum-size=500M`. No active log was deleted; the last 2,000 lines of each active syslog were saved to `/root/log-tail-id1-20261113.txt` and `/root/log-tail-id2-20261113.txt`. id2 needed one extra rotation because the new syslog was momentarily empty when the second run started.
- **Verification:** rsyslog, nginx, haproxy, ssh, dropbear, cron, all four `xray@` units, all four `quota-*` units, and dnstt are active; 0 failed units; both syslogs are still receiving entries.
- **sg1:** left untouched; it has 79 GB free and no pressure.
- **Follow-up:** the 4–5 GB/week syslog growth is driven by Xray info-level logging. The logrotate policy was not changed; if the growth returns, consider a size-capped rotation rule or lowering the Xray log level separately.

## Fix 546 preparation - bounded log retention (2026-11-13)

- **Scope:** keep Xray's `"loglevel": "info"` on all four transports and cap retention instead. No live file was changed during preparation.
- **Measured growth after the cleanup:** id1 syslog ~0.7 GB/day and journal ~2.0 GB/day; id2 syslog ~1.0 GB/day and journal ~2.8 GB/day. Xray lines were 85–93% of syslog, dominated by `ws` and `xhttp`. Before the cleanup, id1 had 5.1 GB + 5.5 GB syslogs, `/var/log` at 14 GB, and 943 MB free (96%); id2 had 4.0 GB + 4.3 GB syslogs and `/var/log` at 11 GB.
- **Policy:** `/etc/logrotate.d/rsyslog` becomes `daily` / `rotate 7` / `maxsize 1G`, keeping the existing compression and postrotate reload; journald gets `SystemMaxUse=2G` and `SystemMaxFileSize=100M`. Expected steady state is ~2.5–3 GB of syslog plus 2 GB of journal, leaving more than 10 GB free on the 20 GB hosts.
- **Delivery:** one idempotent function in `update.sh`, marker `.fix546-log-caps`. It edits the existing rsyslog stanza in place, backs it up, validates with `logrotate -d`, restores on rejection, and forces one rotation only when the policy changes; the journald drop-in is rewritten only when its values differ.
- **Local verification:** a bubblewrap harness with fake `logrotate`, `systemctl`, and `journalctl` passed six cases (normal transform, idempotent rerun, normalization of an existing capped config, rollback on `logrotate -d` rejection, policy retention on a failed forced rotation, and drop-in retention on a failed journald restart). `bash -n update.sh` passes.
- **Deployment:** see the live section below after the updater run.
