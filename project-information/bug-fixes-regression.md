# Bug Fix Regressions & Side Effects

> **⚠ APPEND-ONLY:** Do not delete or overwrite existing entries. Always add new content at the very bottom of this file.

This document records regressions, incomplete patches, and side effects introduced by previous bug fixes, audited against the original script archive (`/var/home/rscimung/Downloads/V23 Linux Ubuntu, Debian, Kali.zip`) and verified via live Debian 12 VPS testing.

---

## 1. Account Locking Omits Trailing-Comma JSON Cleanup (Regression from Bug 11 & Bug 28)
- **Files:** `full/locked-xray-ws.sh`, `full/locked-xray-grpc.sh`, `full/locked-xray-http.sh`, `full/locked-xray-split.sh`, `lite/locked-xray-ws.sh`, `lite/locked-xray-grpc.sh`, `lite/locked-xray-http.sh`, `lite/locked-xray-split.sh`.
- **Cause:** Bug 11 corrected the sed delete target variable from undefined `$user` to `$name`. However, Bug 28's trailing-comma cleanup (`sed -i -z 's/},\n *\]/}\n        ]/' <config>`) was applied to `delete-*.sh`, `kill-*.sh`, `xp.sh`, and `trial-*.sh`, but omitted from all 8 `locked-xray-*.sh` scripts.
- **Impact:** Locking an account via `locked-xray-*` deletes the user block using `{N;d}` but leaves a trailing comma preceding `]`. Service restart fails with `invalid character ']' looking for beginning of value`, taking the entire transport offline. Furthermore, subsequent unlocking via `unlock-*` fails to recover the corrupted file.
- **Verification:** Verified live on Debian 12 VPS: created `testlock`, executed `locked-xray-ws`, `v2ray test` immediately failed with syntax error on character `]`.

## 2. Duplicate Terminal Output and Screen Clears in Lock and Unlock Scripts (Regression from TUI Restyle)
- **Files:** All 8 `locked-xray-*.sh` and 8 `unlock-*.sh` scripts across `full/` and `lite/`.
- **Cause:** TUI restyling inserted new rainbow-bordered status cards at lines 150-165, but the original unstyled summary blocks (`Detail Locked X-Ray WS` / `Detail Unlock X-Ray WS`) and trailing `clear` calls at lines 175-195 were never removed.
- **Impact:** Terminal renders the updated details, immediately wipes the screen, and prints the legacy unstyled output, causing visual stutter and inconsistent UI presentation.
- **Verification:** Confirmed during live interactive testing of `locked-xray-ws` and `unlock-ws`.

## 3. WebSocket Extend Script Edits Obsolete `/etc/xray/json/ws.json` (Regression from Bug 14 & Bug 13)
- **Files:** `full/extend-ws.sh:81,99,108,115`, `lite/extend-ws.sh:81,99,108,115`.
- **Cause:** Bug 14 migrated WebSocket transport from `xray@ws` to `v2ray` using `/etc/v2ray/config.json`. Bug 13 updated the regex spacing in `extend-ws.sh`. However, the configuration path in `extend-ws.sh` was never migrated from `/etc/xray/json/ws.json` to `/etc/v2ray/config.json`.
- **Impact:**
  1. `extend-ws` checks `NUMBER_OF_CLIENTS` against `/etc/xray/json/ws.json`, which contains no clients. The script always aborts with `You have no existing clients!` and loops back to menu.
  2. If clients were present in `ws.json`, `extend-ws` updates `ws.json` while `v2ray` continues running `/etc/v2ray/config.json`. Active user expiration dates are never updated in runtime config, causing `xp.sh` to delete accounts at the original expiration time.
- **Verification:** Verified live on Debian 12 VPS: active user `user1` existed in `/etc/v2ray/config.json`; executing `extend-ws` printed `You have no existing clients!` and aborted.

## 4. `lite/list-xray-ws.sh` Reads Dead `/etc/xray/json/ws.json` Config (Regression from Bug 14)
- **Files:** `lite/list-xray-ws.sh:110`.
- **Cause:** `full/list-xray-ws.sh` was updated to read from `/etc/v2ray/config.json`, but `lite/list-xray-ws.sh` was missed and retains `uid=$(grep "${user}" /etc/xray/json/ws.json | awk -F'"id": "' ...)`.
- **Impact:** In the Lite variant, `list-xray-ws` fails to extract client UUIDs, displaying blank UUID fields for all WebSocket accounts.

## 5. Background `quota-*.sh` Daemons Omit Trailing-Comma Cleanup (Regression from Bug 28)
- **Files:** `full/quota-ws.sh:124`, `full/quota-split.sh:121`, `full/quota-http.sh:121`, `full/quota-grpc.sh:121`, `lite/quota-ws.sh:124`, `lite/quota-split.sh:121`, `lite/quota-http.sh:121`, `lite/quota-grpc.sh:121`.
- **Cause:** When a user exceeds bandwidth limits, all 8 `quota-*.sh` daemons execute `sed -i "/### $user $exp/ {N;d}" <config>` followed by `systemctl restart <service>`. Bug 28's trailing-comma cleanup was never added to these daemons.
- **Impact:** Whenever an account exceeds its quota, the daemon deletes the user, leaves a dangling comma in JSON, and restarts the service. The service fails to parse the config and crashes, knocking all other active users off the server.

## 6. `quota-*.sh` Daemons Crash on Unlimited-Quota Accounts (Regression from Bug 31)
- **Files:** `full/quota-ws.sh:123`, `full/quota-split.sh:120`, `full/quota-http.sh:120`, `full/quota-grpc.sh:120`, `lite/quota-ws.sh:123`, `lite/quota-split.sh:120`, `lite/quota-http.sh:120`, `lite/quota-grpc.sh:120`.
- **Cause:** Bug 31 documented that accounts configured with Quota = 0 omit creating `/etc/xray/quota/<transport>/$user`. The background quota daemons execute `quota_limit=$(cat "$quota_file")` every 30 seconds unconditionally without checking `[[ -f "$quota_file" ]]`.
- **Impact:** For all unlimited-quota users, `cat` outputs `No such file or directory` into stderr, and subsequent comparison expressions (`bc -l` or bash `-gt`) throw arithmetic/syntax errors continuously every 30 seconds.

## 7. `limit-ip-ssh.sh` Still Truncates `/var/log/auth.log` via `${LOG}` Variable (Regression from Bug 19)
- **Files:** `full/limit-ip-ssh.sh:198`.
- **Cause:** Bug 19 commented out line 196 (`# echo "" > /var/log/auth.log`) to protect audit trails. However, line 198 directly below it was left untouched: `echo "" > ${LOG}`, where `LOG="/var/log/auth.log"` was assigned at line 62.
- **Impact:** The script continues to completely erase `/var/log/auth.log` every 5 minutes when triggered by crontab (`*/5 * * * * root flock -n /tmp/limit-ip-ssh.lock limit-ip-ssh`), wiping all SSH security logs and blinding Fail2ban.
- **Verification:** Verified live on Debian 12 VPS: recorded 14 lines in `/var/log/auth.log`; executed `/usr/bin/limit-ip-ssh`; file was immediately truncated to 1 blank line.

## 8. HAProxy (Loadbalance) Started with Default Config and Never Reloads (Regression from Bug 7)
- **Files:** `installer/stunnel5.sh:31-32`.
- **Cause:** Bug 7 added `systemctl enable haproxy` and `systemctl start haproxy` to `stunnel5.sh`. On Debian 12, `apt install haproxy` automatically launches HAProxy in the background with the distribution default configuration. When `stunnel5.sh` writes `/etc/haproxy/haproxy.cfg` and calls `systemctl start haproxy`, systemd ignores the command because the unit is already `active (running)`.
- **Impact:** HAProxy continues running with Debian's default empty frontend configuration. Port 777 is never bound, SSL frontend `ssh-ssl` is inactive, and the load balancer feature remains non-functional until manually restarted.
- **Verification:** Verified live on Debian 12 VPS: `systemctl is-active haproxy` reported `active`, but `ss -tlpn | grep 777` returned nothing. After executing `systemctl restart haproxy`, port 777 immediately opened (`0.0.0.0:777`).

## 9. Installation Telegram Notification Silently Drops on Dual-Stack Hosts (Regression from Bug 4)
- **Files:** `installer/full.sh:238`, `installer/lite.sh:174`.
- **Cause:** Bug 4 added `-4` to `curl ifconfig.me` calls across the project. However, the installation completion notification `curl -s --max-time 10 ... https://api.telegram.org/bot$KEY/sendMessage` was not updated with `-4`.
- **Impact:** On dual-stack hosts, `api.telegram.org` resolves to IPv6 (`2001:67c:4e8:f004::9`). When outbound IPv6 routing is unroutable or delayed, `curl` attempts IPv6 first. With `--max-time 10`, the connection times out before falling back to IPv4. The command fails silently (`>/dev/null 2>&1`), and the user never receives the installation completion notification.
- **Verification:** Confirmed via verbose curl trace on Debian 12 VPS: initial attempt hit `[2001:67c:4e8:f004::9]:443`, requiring fallback to IPv4 `149.154.166.110:443`.

## 10. Destructive Wildcard Deletion in `vpn.sh` Erases Active Installer Files (Regression from Bug 9)
- **Files:** `installer/vpn.sh:267,269`.
- **Cause:** Bug 9 removed `rm -f /root/*.sh` from `installer/noobz.sh`. However, identical destructive cleanup commands were overlooked in `installer/vpn.sh`:
  ```bash
  rm -f /root/*.sh
  rm -f /root/install
  rm -f /root/*install*
  ```
- **Impact:** `vpn.sh` runs at step 6 of the 14-step installation sequence. Mid-install, it deletes `/root/install-fn.sh`, any bootstrap scripts, and `/root/installer.log`.
- **Verification:** Confirmed on live VPS: `/root/installer.log` was completely missing after installation finished despite being redirected during spawn.

## 11. Restore Script Path Conflict Between Web and CLI Interfaces (Regression from Bug 36)
- **Files:** `website/install.sh`, `website/restore-ftp.sh`, `full/restore-ftp.sh`, `lite/restore-ftp.sh`.
- **Cause:** Bug 36 added `wget ... restore-ftp.sh -O /usr/bin/restore-ftp` to `website/install.sh` so web restore could run. However, `website/restore-ftp.sh` searches strictly `/var/www/uploads/*.zip`, while `full/restore-ftp.sh` (from `menu/full.zip`) searches strictly `/root/*backup*.zip` with an IP authorization check.
- **Impact:** Whichever file is installed last clobbers the other. If web restore is deployed, terminal restore from `/root/` fails with `backup.zip not found`. If CLI restore is extracted from `menu.zip`, Apache's `sudo /usr/bin/restore-ftp` fails because `/var/www/uploads/` is never checked.
- **Fix Path:** Consolidate restore logic to check both `/var/www/uploads/*.zip` and `/root/*backup*.zip`.

## 12. SSH Multi-Login Lock Re-applies Forever After Automatic Unlock (Regression from Bug 19)
- **Files:** `full/limit-ip-ssh.sh`.
- **Cause:** Bug 19 removed the destructive `auth.log` truncation at line 196 and regression `## 7.` removed the remaining `echo "" > ${LOG}` truncation - both correct protections for the audit trail. However, the multi-login counter that previously relied on the log being wiped every run kept counting *every* historical `Accepted` line in the whole file. Once a user had exceeded the limit once, the accumulated count never dropped below the limit again, so every 5-minute cron run re-locked the account immediately after each 15-minute at-job unlock.
- **Impact:** A user who ever exceeded their IP limit was re-locked within 5 minutes of every automatic unlock - effectively a permanent lockout requiring manual `passwd -u`. Logins from days earlier also counted toward today's limit, so stale history could lock a user who was well within their limit now.
- **Verification:** Verified live on Debian 12 VPS: with only 20-minute-old login events present, `kvs2` stayed unlocked (`P`) after a run; with 3 fresh events the same account locked (`L`); after manually unlocking past the 10-minute window, a re-run left the account `P` with no re-lock message - the exact sequence that previously re-locked forever. The window (10 minutes) is intentionally shorter than the 15-minute unlock delay, so no run can re-count the logins that caused the lock it is already serving.

## 13. `auto-delete-*.sh` Wildcard Quota Deletion Cross-Destroys Longer Usernames (Regression from Bug 59)
- **Files:** `full/auto-delete-{ws,grpc,http,split}.sh`, `lite/auto-delete-{ws,grpc,http,split}.sh`.
- **Cause:** Bug 59 fixed orphaned `${user}_usage` files by changing the daemon's quota removal from the exact path to `rm -f /etc/xray/quota/<proto>/$user*`. The prefix glob also matches any *longer* username that starts with the same characters, so cleaning up ghost `xpw1` also removed `xpw10`'s quota, usage, and log state while `xpw10` was still an active paying account.
- **Impact:** The auto-delete daemon silently destroying active customers' quota accounting every 5 minutes, resetting or deleting their quota files.
- **Verification:** Verified live on Debian 12 VPS: the daemon removed the ghost `tst` while `tsta`'s quota file and config marker survived intact, with `JSON_OK` on `/etc/v2ray/config.json`.

## 14. Account Cards Print Separator and Title Lines as Literal Escape Text (Regression from the Styled-Output Restyle)
- **Files:** `config/format.sh` (`format_display()`'s fallback `echo` and its `last_sep` subscript); every `add-*`, `trial-*` and `addssh` script in `full/` and `lite/` is affected because all **50** of them `source /etc/funny/format.sh`.
- **Cause:** `012774e` replaced the working `echo -e "$TEKS"` (e.g. `add-vmess-ws.sh:220` in its pre-image) with `source /etc/funny/format.sh; format_display "$TEKS"`. The new renderer's fallback for any line without a `:` was a bare `echo "$line"`, and `echo` does not expand backslash escapes, so the card's rainbow separators and its `Xray VMess WS` title printed as `\033[38;2;…m` text. Its `^[=]{3,}$` separator test only matches a *bare* `===` run, so an escape-prefixed separator never filled `sep_lines`; with `nseps=0` the expression `${sep_lines[$((nseps-1))]:-999}` subscripted index `-1` of an empty array and bash reported `sep_lines: bad array subscript` on stderr before every card.
- **Impact:** on the real `add-vmess-ws` card, 9 of its 32 lines - all 8 rainbow separators and the yellow title - rendered as raw escape text behind an error line, while only the 16 colon-bearing rows rendered. The card is the post-creation screen where the operator reads back UUID, expiry and copyable links, so it looked corrupted at the moment the data matters most; a later separator restyle (`79eddef`) widened the junk from a short string to a screen-filling wall, which is how the fault was noticed.
- **Verification:** a 26-assertion gate replays the real card through both renderers - pre-fix reproduces 72 bytes of stderr, the `bad array subscript` message and 9 junk lines, fixed gives 0/0/25. A full paced account creation on the Debian 12 VPS confirmed it end-to-end (0 `bad array subscript`, 0 literal-backslash lines, card head rendering as dashes), after which cleanup restored the config byte-exactly (4749 - 404 = 4345, strict JSON `PARSE_OK`) with only the pre-existing `rentang` account, 0 at-jobs and `v2ray` active.
- **Fix:** `config/format.sh` now uses `echo -e "$line"` in the fallback and guards the subscript with `if (( nseps > 0 ))`; recorded as fix 84 with the `(Regression Fix)` marker. The separator regex was deliberately left alone so `format_display` does not repaint the rainbow dashes the card already carries.

## 15. Account Log Restyling Disabled by Escapes Embedded in the Card Rules, Title and Link Lines (Regression from fixes 78 and 79)
- **Files:** the card blocks of all **50** `add-*` / `trial-*` / `addssh` scripts in `full/` and `lite/`, plus the two consumers `config/format.sh` and the five `log-*` Go viewers.
- **Cause:** fix 78 (`fad2fb4`) wrapped the card's title and `Link` lines in `\033[1;33m…\033[0m`; fix 79 (`79eddef`) replaced the card's plain `=` rules with 25-segment rainbow `\033[38;2;…m-` runs. Both consumers detect structure by prefix on the raw line - `format_display` tests `^[=]{3,}$` and `^Link\ `, the Go viewers test `HasPrefix(trimmed,"==")` and `HasPrefix(trimmed,"Link ")` - and an escape-prefixed line matches none of them.
- **Impact:** the account log lost the standard styling `a7b3613` had established: the rules printed verbatim instead of being repainted to rainbow `=` outer / blue `-` inner, the section title stayed yellow instead of purple, and the `Link` rows fell to the generic value branch and rendered green instead of deep purple. Because it is the screen operators read an account back from, the loss showed on every account.
- **Verification:** a faithful port of the Go `formatLogForTerminal` detects **0** separators in the escaped card and **8** after the revert; `format_display` goes from **9** junk lines to **0**, with the full palette restored (2 rainbow / 6 blue / 1 purple / 2 deep purple / 14 green).
- **Fix:** the card blocks' structural lines are plain again (fix 85, `(Regression Fix)`), so both consumers restyle them; the create-account FORM rules and titles were deliberately left in the rainbow-dash / yellow style that the operator had asked to keep.

## 16. Status of Regression 11 - Resolved

Regression 11 above is presented with a `Fix Path` and no `Verification`, which now reads as open. It is not: checked against the tree, all three scripts resolve the web-vs-CLI path conflict by looking in **both** locations.

- `full/restore-ftp.sh`, `lite/restore-ftp.sh` and `website/restore-ftp.sh` each reference `/var/www/uploads/*.zip` **and** `/root/*backup*.zip`, so whichever interface invokes restore, the archive is found regardless of which one was installed last. The block is identical across the three files.
- This entry is recorded here rather than edited in place because these documents are append-only; regression 11 should be read as closed, and any future listing derived from a "has Fix Path but no Verification" heuristic will flag it as a false positive.

## 17. udp-request Raw Fallback URL Doubled Its Own Path (Regression from f0e4c10)

`installer/request.sh` sets `hosting="https://raw.githubusercontent.com/rohjagad/fn-autosc/main/udp"` - the base already ends in `/udp`, because the original line always used it as `${hosting}/udp-request-linux-amd64`. Commit `f0e4c10` (the bugs 84-91 sweep) added a release-CDN primary URL and a raw fallback, but wrote the fallback as `${hosting}/udp/udp-request-linux-amd64`, resolving to `.../main/udp/udp/udp-request-linux-amd64` -> **404**.

- The V23 original is the proof of intent: same `hosting` value, line `wget ... ${hosting}/udp-request-linux-amd64` - a single `/udp`. The fork changed only the repo in the base URL, then the fallback was written against the wrong base.
- The sibling `installer/udp.sh` gets it right because **its** `hosting` is `.../main` (no `/udp`), so `${hosting}/udp/udp-custom-linux-amd64` is correct. The two files' bases differ, which is exactly how the mistake slipped through.
- Impact is confined to the fallback: the normal path is the release asset (`fn-autosc-miscellaneous/.../v1.23/udp-request-linux-amd64`, 200). Only when the CDN fails would the panel fall back to a 404, leaving `udp-request` without its binary and the service unable to start - i.e. precisely in the situation the fallback exists for.
- Fixed to `${hosting}/udp-request-linux-amd64` (200). A tree-wide scan for the same class - a `${hosting}` usage that repeats a path segment already present in the base - found no other instance.

## 18. Crontab Scheduled Commands the Installed Edition Does Not Ship (Regression from the Bug-72 Fix)

`installer/xray.sh` appends the panel's cron block unconditionally, and both `installer/full.sh` and `installer/lite.sh` run that same script. Two of the seventeen lines name tools that only the full edition ships:

```
*/5 * * * * root flock -n /tmp/expire-ssh.lock expire-ssh
*/5 * * * * root flock -n /tmp/limit-ip-ssh.lock limit-ip-ssh
```

The lite edition has no SSH tooling at all (`lite/` contains no `*ssh*` file and `menu/lite.zip` no `*ssh*` entry), so on every lite install those two cron jobs run every five minutes and fail with `flock: failed to execute expire-ssh: No such file or directory`.

- `expire-ssh` is **new in this fork** - the Bug-72 fix added `full/expire-ssh.sh` and registered its cron line - so that half is a regression introduced by a fix.
- `limit-ip-ssh` is **inherited from V23**: V23's `installer/xray.sh` already appended the same line while V23's lite also shipped no `limit-ip-ssh`. The audit did not create it, but it is the same defect and is fixed with it.
- Fixed by resolving each line's program and appending the line only when it exists (`command -v`, with an `/usr/bin/<name>` fallback): full keeps all 16 lines, lite keeps 14, and the strip-before-append idempotency is unchanged. Verified in a sandbox with full/lite command sets: full 16 (once `/usr/bin/xp` is present as on a real install), lite 14, and a second run changes nothing.

## 19. WS-on-Xray Migration Reused the V2Ray Template and V2Ray API Calls (Regression from 73ace38 / 7328b32)

The migration that moved the WebSocket transport from V2Ray to `xray@ws` (decision 13) worked from the **V23 (V2Ray-era) WS template and WS scripts** and sanitised them mechanically, instead of adopting the **1.20 reference**, which already served WS with Xray. Two classes of defect entered with it:

- **Template:** `json/ws.json` is V23's file with only the log path rewritten (`/var/log/v2ray/access.log` -> `/var/log/xray/ws.log`). That drop loses `"statsUserOnline": true`, which the 1.20 template and all three sibling Xray templates set. V23's file and 1.20's file differ by exactly that flag and the log path, so the omission is provable against the reference.
- **Commands:** the sweep's "6 `v2ray api stats` -> `xray api stats`" substitution assumed the two CLIs are equivalent. They are not: V2Ray's `stats` lists counters when `-name` is omitted, Xray's returns `app/stats/command:  not found` without it (`xray help api stats`). The affected calls were `quota-ws.sh` (usage accounting) and `cek-xray-ws.sh` (traffic readout); the correct translation is `statsquery`, which is what the sibling Xray transports already used.

**Impact:** with the WS transport the operator had no IP limiting (the online counter was never created), no quota enforcement (no `_usage` was ever written) and a blank traffic readout - the three features that make per-account limits meaningful. The migration's live check did not catch it because it accepted `user>>>probe>>>online not found` as evidence of health; a nonexistent probe email returns that string either way (the same false-positive shape as regression 18's sibling entry, Found 96).

**Fix:** fixes 100-103 - restore `statsUserOnline`, and read the traffic counters the way the sibling transports do. Verified live end-to-end: `statsonline` reports 2 for two client IPs, `limit-ip-ws` deletes the over-limit account, the quota accumulator rises exactly once per transfer, and `cek-xray-ws` shows both the traffic and the correct IP count. See `bugs-fixed.md`, "WS-on-Xray Migration: IP Limit, Quota and Traffic Readout Repaired".

## 20. The Per-Transport Tools Diverge From Their Own Siblings (WS especially), and the Backup Deletes Before It Knows

The whole-account sweep found that several tools behave differently depending on the transport even though the same operation is meant to be identical, and that a few inherited blocks never learned the guard their neighbours have. All are fixed as 104-109; the pattern is worth recording because it is how the WS-specific defects keep appearing.

- **`change-id-*`** (`full/` and `lite/`, all four transports) extracts the old id with `grep "${user}" <json>`, which also matches the `### <user> <date>` marker line. The result is multi-line, the `sed` that should rewrite the id dies with `unterminated 's' command`, and the script prints success regardless. The sibling `extend-*`/`delete-*`/`locked-*` blocks all use `| sort | uniq` or an anchored `^###` pattern; `change-id` never did. Inherited from V23.
- **`quota-ws.sh`** is the one quota script whose expiry extraction lacks `| sort -u`; WS is the one transport that repeats each account across four inbounds, so the delete pattern becomes invalid and the account is left over-quota but unlimited. `quota-grpc`/`quota-http`/`quota-split` and every `kill-*` have the guard. This is the same "the WS script kept V2Ray-era code" shape as the fixes 100-103 cycle.
- **`trial-ssh.sh`** creates a user without the `/etc/xray/limit/ip/ssh/<user>` file that `addssh` writes, so `limit-ip-ssh` silently defaults the account to 2 IPs instead of the 1 on its card.
- **`backup.sh`** (both editions) ignores the Telegram response, deletes `/root/backup*` unconditionally and prints `Backup sent to Telegram`. V23 did the same against a file host, but the Telegram-only redesign removed the fallback destination, so a failed delivery now leaves no copy anywhere instead of a stale one on a host.

The two nginx regressions in this cycle are inherited from V23 as well: `config/dual.conf` never carried `http2` on 443 (only `config/4.conf` did), and no config ever set the SplitHTTP buffering directives, so the two transports that need them - gRPC and TLS SplitHTTP - were broken by default in the dual-stack install the panel recommends.

## 21. `xp.sh` Deletes Accounts Whose Expiry Cannot Be Parsed (Inherited)

Every dated cleanup block in `xp.sh` - four Xray transports, L2TP and Noobz - computes `d1=$(date -d "$exp" +%s)` and then `exp2=$(( (d1 - d2) / 86400 ))`. `date` prints nothing for an unparseable value, bash treats the empty `d1` as 0, `exp2` becomes a large negative and `[[ "$exp2" -le 0 ]]` is true, so the account is removed from its config and its card, quota and limit files are deleted - the same cleanup the block performs for a genuinely expired account, but unreachable and with no message. The WireGuard branch shares the failure through `[[ $exp < $now ]]`: an empty expiry sorts below any date. Inherited from V23.

This is the best explanation for an account (`vm_ws`) that vanished during the live campaign with no `/etc/xray/.quota.logs` entry: `xp` and `quota-ws` delete without logging, so a corrupted date destroys an account and leaves no trace. Fix 110 guards every block; the lesson recorded in `bugs-fixed.md` is that those two deleters should log, so a future recurrence can be attributed.

## 22. Shipped Templates Carried Usable Public Credentials, and One Trojan Client Was Malformed (Inherited)

All four Xray templates ship a default client each and the repository is public, while every account script only ADDS clients - nothing removes the shipped one. The installer randomised only the `rerechan-store` occurrences in `ws.json`, so `cfbbaafc-…` (ws vless/vmess and all of gRPC), the split ids plus the password `diy2020`, and `nonescript-fn-project` (all of HTTPUpgrade) remained valid credentials on every install; probing from an external client with nothing but the committed values authenticated 11 of 12 combinations. The same sweep found `json/upgrade.json`'s trojan client declared with `id` instead of `password`, so that template account could never authenticate at all. Both are inherited from V23. Fixed by randomising all six defaults at install (and in the legacy-restore repair) and by correcting the field name - Found 109/114, fixes 111/116.

Related, same class: `xp` and `quota-ws` deleted accounts with no audit line (fix 112), `change-id-*` left the card's base64 vmess links pointing at the old UUID (fix 113), `cek-xray-ws` returned 1 when idle (fix 114) and `quota-ws` logged a skip message for every idle account every 30 seconds (fix 115).

## 23. Quota and kill Daemons Corrupted, Orphaned or Silently Deleted Accounts (Inherited)

Live testing of the lifecycle features found three inherited defects in the quota/kill family. `kill-ws`'s over-quota branch deleted with a sed *range* (`/^### user exp/,/^###/d`) instead of the `{N;d}` pair used everywhere else: when the account was the file's last marker the range ran to end-of-file and truncated `ws.json` (invalid JSON, `xray@ws` failed to start, WebSocket transport down), and otherwise it ate the next account's marker, leaving that account's client object orphaned and invisible to every panel tool. `quota-{http,split,grpc}` never reloaded their Xray service, so a deleted over-quota client kept working until an unrelated restart. And `quota-*` left the account card behind - a phantom "Active" entry the Lock menu still offered while `unlock-*` could not restore it (it only lists `*.locked`) - while printing "has been locked"; on three transports it also wrote no audit line at all. Found 115-118 / fixes 117-120.

## 24. Reference Audit - Divergences From Both Upstream Versions (September 26, 2026)

Both reference archives were verified (MD5 matches) and diffed against our tree for the three regression classes the owner asked about - over-engineering, over-fixing, and fixes that break other code.

- **No cross-breakage found.** Nothing outside the append-only docs still references anything we removed (`v2ray`, `backup-gd`, `/etc/v2ray`, `/worryfree`, `/kuota-habis`); every command a menu dispatches resolves to a file in the packed archive; and every commit that touched a `.go` source also rebuilt `menu/*.zip`, so no shipped binary is stale.
- **Our lifecycle fixes are less destructive than upstream, not more.** New 1.20's `xp.sh` carries nine range deletes of the form `/^### $user $exp/,/^},{/d` (which never match their end anchor and truncate the file) and no unparseable-expiry guard; ours has zero range deletes and six guards.
- **Two deliberate divergences from both references**, recorded in the observation in bugs-found.md: the `:977` catch-all backend/inbound is gone, and `quota-*` now removes the account card and says "deleted" where upstream kept the card and said "has been locked".
- **One piece of dead code left by the migration:** `full/cek-xray-ws.go` / `lite/cek-xray-ws.go` are never built or packaged.

## 25. Fixes From Earlier Cycles Regressed Themselves, and the References Say So (September 26, 2026)

The four-repository scan's most valuable result is not the new defects but that **five of them were
introduced by earlier fixes in this same audit**, each in a place the fix did not reach. All five
were checked against both reference archives before being changed.

- **WireGuard expiry (Found 126) - regression from fix 110.** Fix 110 added a date guard to every
  `xp.sh` block. The Xray cards carry `%y-%m-%d`, so the guard was written as
  `^[0-9]{2}-[0-9]{2}-[0-9]{2}$`; `menu-wg.sh` writes `%Y-%m-%d`. The guard therefore disabled the
  WireGuard cleanup entirely. The correctness test is the writer, not the siblings.
- **SSH IP limiter (Found 127) - regression from fix 90.** Fix 90 quoted `for user in
  ${username[@]}` as `"${username[@]}"`. The array syntax is only meaningful when `username` is an
  array; the script assigns it from a command substitution, so it is a scalar and the quoted form
  iterates once with the whole blob. **The verification in fix 90 used an array literal
  (`username=("a b")`), not the scalar the script actually builds** - a verification that tested the
  fix rather than the code.
- **SlowDNS fixnet timer (Found 132) - regression from fix 97.** Fix 97 added a 15-second timer to
  re-assert the forwarded UDP 53 redirect. Its nat rule is delete-then-insert; the companion `INPUT`
  accept it also performs was a bare insert, so the chain grew by one rule every 15 seconds (904 at
  the time of the scan). The sibling `udp-request` guard, which fix 97 cites as its model, does the
  delete first.
- **SplitHTTP timeouts (Found 133) - regression from the canonical path rename.** Fix 105 gave
  `/splitvm` the long timeouts and scoped itself explicitly to that location. The rename then created
  `/vlspl` and `/trspl` by moving the other two locations and did not carry the directives with them,
  so the two transports the fix was about were still broken over TLS.
- **WS online counter (Found 129) - fix 100 was not applied where it also mattered.** Fix 100 restored
  `statsUserOnline` to `json/ws.json`. `routing-ws.sh` and `bmenu.sh` *regenerate* that file's policy
  tail, and they still omitted it, so any WS routing change or legacy restore undid the fix. The
  sweep looked for the flag in the template and stopped there.

Two more are the same shape in the new API layer: `lib.sh`'s `need` (Found 119) and the installer's
permission guard (Found 136) both put an `exit` inside a command substitution, where it ends only the
subshell. In the API the consequence was worse than in the installer because the handler kept running
and fed the error text to a root script.

The lesson recorded for the next cycle: a fix that adds a guard must be verified against the value
the counterpart *actually produces* (fix 126/127), a fix that touches one location must be repeated
in every location that expresses the same thing (fix 133/129), and any `exit` inside `$( )` is dead
(fix 119/136).

## 26. The Same Session's Own Changes, Re-checked (September 26, 2026)

Two of this session's changes were themselves defective, and were caught and corrected by
re-testing them rather than trusting them:

- **The threaded server (Found 140).** The restored `fn-autosc-api` replaced the reference's
  single-threaded `HTTPServer` with `ThreadingHTTPServer` as a hardening measure. The panel's
  scripts are not concurrency-safe - they rewrite whole shared files - and twelve concurrent creates
  lost four of them. The reference's single-threading was load-bearing, not a limitation to improve
  away. Restored by a lock around handler execution.
- **`client_max_body_size 0` (fix 136).** Raising the limit in the `http` block fixed the gRPC 413
  but also lifted nginx's 1 MB bound on the buffering locations, which is a disk-fill DoS. Scoped to
  the streaming locations.

Both are the same lesson as regression 25: a change that is "more capable" than the original needs
the original's constraints re-derived before it is assumed safe.

## 27. Source-Grounded Review: Over-Fixes, False Positives and Over-Engineering (September 26, 2026)

Both reference archives were re-read (MD5-verified) and diffed against our tree specifically for the
three classes the owner asked about. The evidence is a presence matrix over the same strings in
`V23`, `1.20` and our tree, cross-checked file by file where a count differed.

### Over-fixes - changes that went beyond the reference and caused harm

- **`limit-ip-ssh`'s loop (fix 90).** Both references write
  `username=$(while ... done < /etc/passwd)` and then **`for user in ${username[@]}` - deliberately
  unquoted**, because the variable is a newline-separated *scalar* and the unquoted form is the
  idiom that splits it. Fix 90 "hardened" that to `"${username[@]}"`, which iterates once with the
  whole blob, so **the SSH IP limiter stopped enforcing** (Found 127). This is the clearest
  over-fix in the tree: the reference was right and the fix broke it. Fix 129 restored the
  reference's semantics (`for user in $username`). A tree-wide scan for the same shape - a variable
  used as `"${name[@]}"` that is assigned as a scalar - now finds **none**: `users`, `usernames`,
  `data` and `frames` are all real arrays, exactly as in the references.
- **The certificate copy (commit `873e529`, bugs 52-61).** The references' acme stage uses
  `cat ...fullchain.pem >> /etc/xray/xray.crt` (which silently never renews, because the first
  chain in the file wins) and their `cert2` stage uses `cp`. Our tree changed the form to
  `cat ...fullchain.pem > /etc/xray/xray.crt`, which fixes the append-duplication but introduces
  truncate-on-failure (Found 130). The fix (143) is the guarded `cp` form - the shape the
  references already use for the same job. Both of this tree's forms were worse than the reference's
  `cert2`, in different ways.
- **The API server's threading (our own code).** The FN-API reference `core/server` is a plain
  single-threaded `HTTPServer`. The restored layer was built with `ThreadingHTTPServer` as
  "hardening"; when that lost four of twelve concurrent creates, a lock was added - which made the
  threading pointless for handlers. Since nginx fronts the server and buffers requests, thread-per-
  connection buys nothing. Reverted to `HTTPServer` and the lock removed: simpler, and the
  reference's design.

### Divergences that are *not* over-fixes - the source was checked and the change is needed

- **`"level": 0` on clients (fix 143).** Neither archive writes a `level` anywhere - the string does
  not occur in either tree's scripts or JSON. The pinned Xray 25.3.6 does not emit per-user traffic
  counters without it, so the quota feature cannot work otherwise (A/B in Found 141). The
  references share the defect; this is a necessary divergence, not an over-fix.
- **`client_max_body_size 0` (fix 136).** Absent from both archives. The 413 on a >1 MB gRPC upload
  was reproduced live, and the fix is scoped to the streaming locations only.
- **`-4` on public-IP lookups (bug 4 and later).** Neither archive uses `-4` at all (0 occurrences
  each; ours has 203). The lookups are gated on a **dual-stack** host returning an IPv6 literal -
  confirmed on the test VPS (`icanhazip.com` -> `2001:df0:27b::…`) - and the rental gate compares the
  result against an IPv4-only `izin.txt`, so the change is load-bearing. It is a large mechanical
  divergence from both references and is recorded as such.
- **Keeping SSH port 22 (fix 144).** Both archives' installers append `Port 3303` and neither keeps
  22 explicitly, and both then point dnstt at `127.0.0.1:22` and print `OpenSSH : 22, 3303` on every
  card. Their design *assumes* 22 stays listening; ours just closed it on the image our own
  reinstaller fetches. The fix makes the panel deliver what both references intend.

### Fixes that match the newer reference rather than diverging

- **`cek-xray-{grpc,http,split}.go` ports (fix 130):** V23 has all three on `10080` (wrong); **1.20
  has 10083/10081/10082** - exactly what our fix restores. The migration had copied V23's files.
- **`statsUserOnline` coverage (fixes 100/129):** 1.20 carries it in
  `Json/ws.json`, `routing-ws.sh` and the three siblings; ours now carries it in exactly those plus
  `bmenu.sh`. V23 had it only for the non-WS transports.
- **The quota read/reset pattern (fix 101):** 1.20's `quota-ws.sh` is
  `xray api statsquery … | grep -C 2 … | grep value` + `xray api stats -name … -reset` - character
  for character the shape our fix adopted. V23 used the V2Ray `api stats` form.
- **The `at` quoting in the trial scripts (commit `cfa878e`):** the references write
  `echo "sed -i "/### $user $exp/ {N;d}" …" | at …`, whose nested unescaped quotes mangle the
  command. Our single-quote/concatenation form is the correct one - a real fix, not an over-fix.

### Additions that appear in neither reference (recorded, not defects)

- `expire-ssh` + its cron line - a cleanup tool the references do not have; they rely on `useradd -e`
  alone. Kept.
- `install.sh`'s downloader bootstrap, its screen/tmux hand-off and its empty-`LOCAL_IP` guard - all
  ours. The references' `install.sh` is 124 lines and downloads a now-dead handler bundle.
- The whole `fn-autosc-api` repository, and `client_max_body_size`/`level` as above.
- Cosmetic: the install summary's `SSH Port:` line and `menu-api`'s inactive-service warning.

## 28. The Reference Archive Is the Bug Holders in These Areas (September 26, 2026)

Following the fifth pass, it is worth recording the shape of what it found. In account management,
cron, time/date, the limiter, quota and the IP limit - the areas the owner asked about - **every
token-level divergence from both archives was one our tree had already fixed**, not one it had
introduced:

- a service that is never created (`xray@http` restarts in the four HTTPUpgrade scripts, against an
  installer that enables `xray@upgrade`);
- a package that does not exist (`python` on Debian 12, aborting the whole `apt install` line);
- a wrong transport's quota path in `delete-split` (`/etc/xray/quota/ws/`);
- a state path nothing creates (`/etc/funny/limit/ssh/ip/`);
- a date regex that cannot match the dates the writer emits (`^[0-9]{2}-…` vs `%Y-%m-%d`);
- split NoobzVPN state between `/etc/noobzvpns/…` and `/etc/funny/…`;
- and a typo that silently disables a restart (`systemctl resrart xray@split`).

This is the complement of regression 27. There, our own changes had to be re-checked against the
source because they were "more capable" than it. Here, the source is simply wrong in seven places and
the tree already carries the corrections - which is the point of keeping both archives: the audit
has to cut both ways, keeping our divergences only where they are justified and matching the source
where it is right.

## 29. Fix 97 Protected One UDP Port and Left the Rest Captured (Inherited, Then Half-Fixed Here)

Found 97 diagnosed the panel's own `udp-request` wildcard capture swallowing the SlowDNS
UDP-53 redirect and fixed it with a 15-second re-assert timer for **port 53 only**. The capture
itself is `dpts:1:8988` + `dpts:8990:65535` (plus a `1:65535` DNAT for `udp-request` itself), so it
swallows *every* other inbound UDP service the panel installs - WireGuard 51820, OpenVPN UDP 2200,
IPsec/IKE 500/4500 and L2TP 1701 - and fix 97 left those to be discovered later (Found 146).

The lesson is the same one regression 25 recorded in the other direction: a fix that names one value
out of a family has to ask whether the family has other members. Here the "family" was not other
transports of the same tool but other ports of the same capture. Fix 148 generalises it, and the
timer's default `AccuracySec=1min` - which made even the port-53 fix restore up to a minute late -
is now `1s`.

## 30. Self-Review of the Newest Fixes - Over-Engineering, Over-Strictness, Regression (September 27, 2026)

The owner asked for the whole fix history to be re-checked for the three classes. Both archives were
re-verified first (MD5/SHA match `original-source-do-not-edit/README.md`); then `bugs-fixed.md`,
`bugs-found.md`, `is-decision.md` and the commit log were read, and every fix made since the previous
review (sections 25-29, which end at fix ~142) was checked against both versions.

### Regression

- **Fix 151 exposed a heavy, previously unreachable installer.** Removing the guard that made the WARP
  menu abort on every full install also made its Debian branch run for the first time:
  `deb http://deb.debian.org/debian/ unstable main` plus `apt install linux-headers-$(uname -r)`. On
  the test host that pulled **linux-image-6.1.0-53** - a new kernel - along with llvm and the media
  stack (observed live). Nothing was wrong before because nothing could reach it. Fixed: the unstable
  repository and the kernel headers are now used only when the running kernel has **no** WireGuard
  module; Debian 12 ships it in-tree (`modinfo wireguard` -> `.../wireguard.ko` on the test host, so
  the in-tree branch is taken). Both references have the unconditional lines, so they share the
  hazard; the guard is ours, added because our fix is what made it reachable.
- **The nginx trust change (fixes 153/154) has no hidden consumer.** A tree-wide search finds no
  script, menu, Go tool or PHP page that reads `$http_x_forwarded_for`, `X-Real-IP` or the nginx
  access log, and the API server does not either. Changing what those headers carry, or what
  `$remote_addr` means, therefore cannot regress a panel feature - only what Xray and the SSH-WebSocket
  backend see, which is the point of the change.

### Over-strictness - checked, and none is a trap

- **Decision 4 (reject 0 on every quantity field).** Driven live through the API: `add-vmess` with
  `expired:0`, `limit-ip:0` and `quota:0` each returned `{"status":"error","message":"the panel did
  not create ..."}` and left **0 accounts and 0 cards** - the validation loops end in `|| exit 1`, so
  EOF terminates them instead of spinning. An API caller using the references' `0` gets a clean error,
  not a hang and not a half-created account. The references accept any value (`read -p "Limit Ip:"`,
  `if [[ $quota -gt 0 ]]`, `date -d "$masaaktif days"`), so this is a deliberate, documented
  divergence that fails safe. The one rough edge is cosmetic: the API's error text embeds the
  script's own output, including the `cat: /etc/funny/.chatid: No such file` lines when the bot is
  not configured.
- **Decision 7 (`-s /bin/false -M`)** stays inside the SSH forwarding accounts and was verified live.
- **Decision 16 (quota breach deletes, IP breach locks)** is deliberate, and the IP breach being the
  *recoverable* one is what keeps the Cloudflare item below non-destructive.
- **Decision 19 (restore key, fails closed)** - a fresh install always writes `/etc/funny/.restore.key`,
  and an archive predating it leaves that file in place, so a restore cannot lock the operator out.
- **Fix 154's Cloudflare range list - the one real fragility.** `real_ip_header CF-Connecting-IP` is
  honoured only for peers inside `set_real_ip_from`, so if Cloudflare publishes a new range and the
  list is not refreshed, requests from that edge keep the edge as `$remote_addr` and the IP limit
  would count Cloudflare edges instead of clients - locking accounts that exceed their limit (and
  `unlock-*` restores them, so it is recoverable, not destructive). Maintenance rule: refresh
  `set_real_ip_from` from `https://www.cloudflare.com/ips-v4` and `/ips-v6` and reload nginx; because
  every install downloads the current `config/*.conf` from the repository, keeping the repository's
  list current is the rule for us.

### Over-engineering - checked, nothing to undo

- The two `*-fixnet` timers, the `set_real_ip_from` block and the API repository each answer a
  reproduced defect; none is infrastructure without a failure behind it.
- The previous review's over-fixes stay reverted and re-scanned clean: no variable is iterated as
  `"${x[@]}"` unless it is a real array (`users`/`usernames`/`data` are all `x=( ... )`, in ours and
  in the references), no `proxy_add_x_forwarded_for` remains, and the certificate stage uses
  acme.sh's install rather than an append.
- Additions present in neither archive are still only the ones this review can justify: the
  `set_real_ip_from` block, `udp-request-fixnet` and `keyexchange=ikev1` are count-0 in both V23 and
  1.20, and each traces to a defect reproduced on the test host.

## 31. The Recorded Fragility Is Now Delivered, and the Open Recordings Are Closed (September 27, 2026)

Section 30 left one item recorded rather than fixed - the Cloudflare range list behind
`set_real_ip_from` - and the owner asked for everything open to be fixed instead. This records the
result; the details are in the tenth pass of `bugs-fixed.md`.

- **The ranges are now self-refreshing (fix 157).** `installer/cf-realip.sh` rewrites
  `set_real_ip_from` from `https://www.cloudflare.com/ips-v4` and `/ips-v6`, guarded so a failed
  fetch, a malformed list or a failing `nginx -t` leaves the configuration exactly as it was, and
  `installer/diamond.sh` installs it as `/usr/local/bin/cf-realip-refresh` and schedules it weekly
  (`0 4 * * 0`). So a range Cloudflare adds later is trusted on the next run instead of being counted
  as a client. Verified live: a no-op when current (byte-identical config, no backup left), and a
  clean restore-and-reload after two ranges were deleted by hand.
- **The list itself was wrong (fix 156).** Fix 154 shipped `2c0f:f248::/29`; Cloudflare publishes
  `2c0f:f248::/32`. The broader /29 trusted addresses Cloudflare does not own. All three configs now
  match Cloudflare's published lists exactly, which the refresher also proves at install time.
- **The vendored bot bundle closes decision 18's exception (fix 155).** `menu-bot` fetched
  `rohjagad/FN-API/main/bot.zip`; the bundle (24,845 bytes) is now committed as `other/bot.zip` and
  both menus read it from this repository. The menu archives were updated in place with a single
  changed member (+166 bytes; every other member byte-identical), not rebuilt from source.
- **Tidies delivered elsewhere:** `fn-autosc-api` strips escape sequences from `panel_reason` so a
  refusal is readable (API `f89dc34`), and `fn-autosc-miscellaneous` dropped the dead committed
  `rclone.conf` and `rclone-install.sh` that decision 11 says must not survive (misc `4dd9424`).
- **Confirmed to need no change**, with the reasons in `bugs-found.md`: the `v2ray.sh` Fastly entry
  (that script is gone), the `restore-ftp.sh` "dead file" (it is the fallback copy), the dead
  invalid-date branch and the empty-`LOCAL_IP` gate (both fail safe), `unlock-ws`'s missing
  confirmation and the menus' unused `output()` (both match the references' behaviour when compared
  file by file).

## 32. Section 30/31 Reversed: the Cloudflare Range Hardening Is Gone (September 27, 2026)

Sections 30 and 31 recorded the Cloudflare range list as a fragility and then "fixed" it with a
refresher. The owner's follow-up reframed the trade correctly, and it is worth recording against those
two sections: **the IP limit exists to work for ordinary users, not to resist a client that forges a
header.** The hardened form (`set_real_ip_from` + `CF-Connecting-IP`) made the everyday case depend on
a list that must be kept current - a range Cloudflare adds between refreshes would not be trusted, the
new edge would be counted, and ordinary accounts would be locked. The map the panel already had
(`$clientRealIp`: the last address in the chain, with `""` and `default` falling back to the peer) has
no such dependency, and Cloudflare's own chaining rule is what makes it correct behind the CDN.

So fix 154's hardening, and the refresher from 156/157, are reverted: the configs and the live host
send `$clientRealIp` again, `installer/cf-realip.sh`, its `diamond.sh` wiring and the weekly cron are
removed, and the reasoning is `is-decision.md` section 24. This is the same lesson as section 25 in a
new place - a change that is "more secure" than the original can still be the wrong change when it
moves the failure onto normal traffic. Forged headers are explicitly out of scope.

## 33. Both IP-Limit Changes This Session Were Inventions the References Already Had (September 27, 2026)

Sections 30-32 tracked the forwarded-header and `real_ip` work. Re-reading both archives for the
follow-up shows the whole sequence was unnecessary: the references already send
`X-Real-IP $remote_addr` plus `X-Forwarded-For $proxy_add_x_forwarded_for` to every Xray upstream, and
Xray takes the first entry of that chain - the real client behind Cloudflare and the peer otherwise.
Their `$clientRealIp` map is for the access log only. Fix 153's header substitution, fix 154's
`set_real_ip_from` and the refresher are all reverted; the tree and the live host carry the
references' lines.

This is section 25's lesson in a new key: before adding a mechanism, check whether the source already
solves the problem. The IP limit works through Cloudflare with no range list and no header rewriting,
so a new Cloudflare range is a non-issue.

## 34. Eleventh Pass: What This Sweep Found That the Earlier Ones Did Not (September 27, 2026)

A full read of both editions plus the installer, website and configs produced ten defects (Found
152-162 / fixes 160-170) that the previous passes had not surfaced. Two are worth naming as lessons:

- **The last pass's own work had a hole (Found 160).** Fix 133 added streaming timeouts to the
  SplitHTTP locations only; WS and HTTPUpgrade kept nginx's 60-second default. The lesson from
  section 29 applies to more than ports: when a fix touches one member of a family - here four
  transports - check the other members in the same pass.
- **A guard that cannot fire is worse than no guard (Found 157).** `calculate_remaining_days` looked
  like it validated the licence date, but `$?` after `local` made the branch dead; the gate only
  blocked because the callers happened to re-check. It was safe, but it was not doing what it said.

The sweep also confirmed **three suspected defects are not real**, which is worth recording so they
are not "fixed" later: `udp-custom` and `udp-request` do **not** collide on 36711 (live they bind
36711 and 8989; only the request config's unused `listen` key is misleading); `fix/fix.sh`'s
conntrack keys do apply on the tested host; and `fix/fix-decrypted-original.sh` is a retained audit
artefact that no installer ships, so its internal inconsistency is intentional.

Two sub-audits read every file and were checked against the running services before anything was
changed - the same rule as section 25: a file-level suspicion is not a finding until it is
reproduced.

## 35. The Eleven Fixes Re-Checked: Regression, Over-Strictness, Over-Engineering, and the Source (September 27, 2026)

The owner asked whether the ten new fixes had themselves been put through the same four checks as the
older ones. They had **not** - each was reproduced live, but none had been re-read for regression
risk, over-strictness, over-engineering, or against the archives. They have now, and **two of my own
edits failed the check and are repaired in the same commit**.

| Fix | Regression | Over-strict / over-engineered | Source |
| :-- | :-- | :-- | :-- |
| 160 `list-xray` anchor | none - the value only labels a row, and `change-id-*` already used this exact form on the same data | no | refs carry the same unanchored grep plus a trailing `| strings` we dropped; anchoring is a deliberate improvement, not invented logic |
| 161 `extend` guard | none - every marker the panel writes is `%y-%m-%d`; only a corrupted one is refused | refuses rather than writing 1970, i.e. the safe side | refs have no guard; the model is `xp.sh`'s guard from fix 110, ours |
| 162 `read \|\| exit 0` | **checked:** all 57 guarded reads are immediately followed by `case`, so they are menu prompts; none is a prompt where EOF could mean "use the default" | no | refs recurse the same way (inherited bug) |
| 163 newest archive | none - the newest upload is the one just made | no | refs move the glob (inherited bug). **Repaired:** `bmenu` could `mv /root/backup.zip` onto itself |
| 164 wg `chmod 600` | none - only root sources the file | no | refs apply no mode (inherited) |
| 165 invalid-date guard | none - both the old and new paths end in `exit 1`, and the caller's `<0` check is untouched | 191 files is churn, but it is one mechanical change that makes dead code live rather than new behaviour | refs carry the same dead guard (inherited) |
| 166 lite | none - lite advertises no SSH, so 777/`ws`/dropbear serve nothing there | no | refs' lite also runs `diamond.sh`+`stunnel5.sh` (inherited). **Repaired:** my edit left a duplicate `ws` restart in `bnnr` |
| 167 l2tp empty files | none - `xl2tp.sh` creates `ipsec.d/passwd` with `>>` on the first account, and `chap-secrets` is created empty | no | refs write the same empty entries (inherited) |
| 168 http-level timeouts | holds idle sockets for 300 s instead of 60 s on every proxied location; the SplitHTTP locations already used 300 s | three directives at `http` level rather than six copies in locations | refs set none; fix 133 (ours) covered SplitHTTP only - this completes it |
| 169 `domssh` | none - the value was unused | no | refs write only `domargo` and read `domssh`; dead there too (inherited) |
| 170 `dmsl` HAProxy bundle | haproxy restart is guarded (`|| true`) for lite | also narrows `chmod 644 /etc/xray/*`, which had been chmod-ing the API token as well, to the two certificate files | the other issuance paths in the same file already rebuilt the bundle |

Net: no over-strictness and no over-engineering in the set, one fix completed a previous one (168), one
is a narrowing rather than a new mechanism (170's chmod), and the two genuine mistakes were mine, not
the references' - recorded here rather than quietly amended.

### Rule added - the four checks belong in this file

To answer "is it documented?" for the process and not only for these instances: **every fix from now
on is re-checked for regression, over-strictness that could bite later, over-engineering, and
agreement with both reference archives, and the result is written here** - one row per fix in a
section like 27 or 35. Reproduction is necessary but not sufficient: sections 25, 26 and 35 all
found defects in changes that had already been verified live. The archives must be MD5/SHA-verified
against `original-source-do-not-edit/README.md` before they are used as the reference, and when a
suspected defect turns out to be the references' own behaviour, that is recorded too (section 28),
so it is not "fixed" into a divergence later.

## 36. Dropbear 2019.78 Pin - the Four Checks (September 27, 2026)

Decision 25 pins Dropbear to 2019.78. It is a behaviour change, not a bug fix, so the section 35 rule
is applied to it here.

| Check | Result |
| :-- | :-- |
| **Regression** | The service plumbing is untouched (init script, unit, ports 111/109/69, host keys), so nothing the panel does against Dropbear changes. The build is deliberately made **without PAM**, matching the Debian package - which is what `expire-ssh.sh` depends on (bug 72) - and 2019.78 emits the same `Password auth succeeded for '<user>'` journal line that `limit-ip-ssh.sh` and `cek-login-ssh.sh` parse. Only the binary version changes. |
| **Over-strictness** | None. The build is skipped when `dropbear -V` already reports v2019.78, so re-runs cost nothing (verified: 3 s, binary untouched). A checksum mismatch or a failed build warns and leaves the installed build in place rather than aborting the install. Only `dropbear-bin` is held, and only so an upgrade cannot undo the pin; the `dropbear` plumbing package is not held. |
| **Over-engineering** | One installer block and one dependency line. It reuses the existing pinned-asset pattern (the misc repository's `main` + `v1.23` release, as vnstat/libreswan/go already do) and the upstream tarball, and adds no service, timer or daemon. |
| **vs the source** | Both references run plain `apt install dropbear` and take the base image's build; neither pins a version. This is therefore a **recorded divergence chosen by the owner** (decision 25), not an invented mechanism - and it changes no port, path or config key the references use. |

**Known, accepted differences:** 2019.78 predates ed25519 host keys and RSA-SHA2, but negotiates with
current clients over its ECDSA host key, so password auth is unaffected (verified live); it logs one
harmless `Failed loading .../dropbear_dss_host_key` on start because it supports DSS and the Debian
package no longer generates that key - no DSS key is created, since DSA is weak and unnecessary. Lite
is unaffected (it never runs `ssh.sh` and disables Dropbear, fix 149).

## 37. SSH Services Version Block - the Four Checks (September 27, 2026)

Decision 27 adds the SSH-family version block. Section 35's rule applied to it:

| Check | Result |
| :-- | :-- |
| **Regression** | Display-only: the SSH menu's nine options and their case branches are untouched, and every probe is a read-only `--version`-style flag. `udp-request` is deliberately not probed because an unknown flag starts its daemon - that is why it is excluded rather than run. |
| **Over-strictness** | None: each value falls back to `n/a`, so a partial install (no OpenVPN, no Squid, absent `ws`) still renders the menu. Nothing depends on the versions being present. |
| **Over-engineering** | One block of nine `command | grep | awk` lines and a `printf`; it reuses each tool's own version output, adds no dependency, no helper function and no caching. |
| **vs the source** | Neither reference shows service versions anywhere (their menus print only the main-menu XTLS line), so this is owner-requested, recorded as decision 27 - not invented logic replacing a reference behaviour. |

### Correction to section 37 - four probes, not nine

Section 37 counted nine `command | grep | awk` lines. Decision 27's correction narrowed the menu block
to the four SSH front-ends (OpenSSH, Dropbear, WS ePro, Stunnel5), so it is four probes in a single
column. The four checks themselves are unchanged: display-only, `n/a` fallback, no new dependency, and
still an owner-requested divergence (the references show no service version at all).
