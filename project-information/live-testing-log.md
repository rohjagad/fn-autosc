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
