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
