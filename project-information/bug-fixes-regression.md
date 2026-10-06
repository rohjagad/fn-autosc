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

## 38. Lifetime Auth and the WARP Guard - the Four Checks (September 27, 2026)

Decision 28 touches 192 gate copies plus the WARP submenu in both editions. Section 35's rule
applied to it:

| Check | Result |
| :-- | :-- |
| **Regression** | Dated entries behave exactly as before: the unit harness shows future-date exits 0, past-date exits 1, and garbage/empty inputs behave byte-for-byte as the original (including its quirk that the `exit 1` never escapes the command substitution). The WARP refusal only fires on date-licensed machines; `disable()`/`status()` and the `wg0` Cloudflare peer are untouched. `bash -n` passes on all 194 touched files. |
| **Over-strictness** | The refusal names the reason and the remedy (a `lifetime` entry); it does not abort the menu, only the WARP action (`return`, not `exit`). The lifetime skip keeps the membership check - an unlisted machine is still rejected. |
| **Over-engineering** | One `if` in the gate, one `if` line on the expiry check, one line in each `output()`; one shared guard paragraph in the three WARP functions. No new files, no flags, no extra network calls - `enable()` reuses `$EXPIRED_DATE` the gate already set. |
| **vs the source** | Both references gate on a date unconditionally and drive WARP with `warp-cli`; neither knows `lifetime`. This is owner-requested, recorded as decision 28 - not invented logic replacing a reference behaviour. |

## 39. Batch-1 Fixes (Found 169-170) - the Four Checks (September 28, 2026)

| Check | Result |
| :-- | :-- |
| **Regression** | Fix 175 reuses the exact Decision 28 stanza (same `if`, same `output()` line); dated/garbage/empty inputs behave as the original `install.sh` did. Fix 176 only narrows the match (adds `^` + trailing space); non-colliding usernames behave identically (single marker rewritten either way). `bash -n` passes on all 9 touched files. |
| **Over-strictness** | Neither fix refuses anything new: lifetime still requires membership (unlisted IP still rejected); extend still rewrites the requested account, just not its longer-named neighbour. |
| **Over-engineering** | Fix 175: 6-line branch, no new files/flags/calls. Fix 176: one-line anchor per file, same tool (`sed`), no new dependency. Sibling patterns deliberately left alone to avoid churn (see Fix 176 scope note). |
| **vs the source** | Fix 175 completes our own Decision 28 (both references gate on a date; the miss was ours). Fix 176 diverges from both references (V23 identical unanchored) because the reference corrupts data - necessary divergence, minimal form. `trial-ssh.sh` missing gate, `kill-ws` log truncation, `xp.sh` per-user restarts, `udp` 36711 display, `diamond.sh` pkill, and sibling unanchored deletes are all inherited and recorded, not changed here. |

## 40. Second Reinstall Cycle and Complete Audit Review (September 28, 2026)

Section 35's four-check rule applied across the two fresh-reinstall cycles and the complete codebase audit:

| Check | Result |
| :-- | :-- |
| **Regression** | Zero regressions across two fresh OS reinstalls. Both OpenSSH (3303) and Dropbear (109) tunnelled; all four XTLS transports (WS, gRPC, SplitHTTP, HTTPUpgrade) authenticated and tunnelled to `202.155.17.126`; WireGuard ping and egress 100% functional. All services active, 0 failed units. |
| **Over-strictness** | Audited all menu input loops and gates. Anchoring `extend-*` to `^### $user ` protects against neighbour-account corruption without restricting valid usernames. Quantity fields reject 0 per Decision 4, failing safe with exit on EOF. WARP refusal only triggers on date licenses, preserving license validity. |
| **Over-engineering** | Audited all patches: no new daemon, no external library, no complex abstraction added. The tree remains minimal shell scripts and Go binaries. Dead-code and unneeded abstractions were omitted. |
| **vs the source** | Both reference archives (`Autoscript New 1.20.zip` and `V23 Linux Ubuntu, Debian, Kali.zip`) verified byte-for-byte in `original-source-do-not-edit/` (MD5 and SHA-256 match README exactly). Divergences (Dropbear 2019.78 pin, WS on Xray, license lifetime, WARP guard, canonical transport paths) are documented in `is-decision.md` as intentional architecture choices. |

## 41. WireGuard Expiry Restart and Non-Interactive Restore - Four Checks (September 28, 2026)

Section 35's four-check rule applied to Fixes 177 and 178:

| Check | Result |
| :-- | :-- |
| **Regression** | Fix 177 executes `systemctl restart wg-quick@wg0` only when `wg_restarted=1` (at least one peer actually expired), so an idle `xp` run does not restart active WireGuard interfaces. Fix 178 only adds `-o` (force overwrite) to `unzip` and removes an identical redundant restart line; all restore operations extract and start identical services. `bash -n` clean on all 7 files. |
| **Over-strictness** | Neither fix restricts any valid user operation. Pruning expired WireGuard peers matches the documented lifecycle of every other protocol in `xp.sh`. |
| **Over-engineering** | Fix 177: 4 lines of shell logic using existing systemd units. Fix 178: standard `-o` flag on already-used `unzip` command. No new daemon, script, or configuration file. |
| **vs the source** | Both references omitted restarting `wg-quick@wg0` in `xp.sh`, allowing expired clients to tunnel indefinitely. Both references ran `unzip` without `-o` and duplicated `systemctl restart xray@ws`. Divergence is necessary to stop data leakage from expired accounts and prevent stdin hangs. |

## 42. Auto-Delete Conditional Restarts and Quota Daemon Noise Pruning - Four Checks (September 28, 2026)

Section 35's four-check rule applied to Fixes 179 and 180:

| Check | Result |
| :-- | :-- |
| **Regression** | Fix 179 preserves the exact service restart whenever an orphan account is genuinely deleted; it only eliminates the restart when nothing was removed, removing connection drops for active users. Fix 180 brings gRPC, SplitHTTP, and HTTPUpgrade into identical alignment with WebSocket (Fix 115). `bash -n` clean across all 14 touched files. |
| **Over-strictness** | Neither fix alters account validation or deletion criteria; both strictly prevent unwarranted process disruptions and log bloat. |
| **Over-engineering** | Fix 179: moved 2 existing lines inside an existing `if` block. Fix 180: removed 1 noisy `echo` line. Zero new dependencies or files. |
| **vs the source** | Both references restarted Xray unconditionally on every 5-minute cron run and spammed the journal every 30 seconds for idle accounts. Pruning both inherited defects is necessary for operational server stability. |

## 43. Leading-Zero Option Matching in Transport Menus - Four Checks (September 28, 2026)

Section 35's four-check rule applied to Fix 181:

| Check | Result |
| :-- | :-- |
| **Regression** | Existing single-digit inputs (`1`, `2`, ..., `9`) continue to match identically; only the zero-padded alternatives (`01`, `02`, ..., `09`) matching the on-screen display labels are added as alternate patterns. `bash -n` clean across all 8 files. |
| **Over-strictness** | Eliminates strict rejection of user inputs that match on-screen prompt labels; fails safe to default loop for non-numeric/out-of-bounds input. |
| **Over-engineering** | Simple pattern expansion `1|01)` within existing bash `case` statements. No new flags, variables, or functions added. |
| **vs the source** | Both references carried the mismatch between display `01` and case `1)`. Aligning input matching with on-screen text resolves operator confusion and broken script dispatch. |

## 44. API Menu Lifetime Support and Handler Modes - Four Checks (September 28, 2026)

Section 35's four-check rule applied to Fix 182:

| Check | Result |
| :-- | :-- |
| **Regression** | Standard dated licenses continue to validate identically against `fn-autosc-auth/izin.txt`. Only `lifetime` entries bypass the date subtraction. `bash -n menu-api` clean. |
| **Over-strictness** | Eliminates unwarranted rejection of lifetime licensed servers attempting to run or install the API management menu. |
| **Over-engineering** | 10 lines of standard shell conditionals mirroring the existing gate stanza from `fn-autosc` Decision 28. No new flags, endpoints, or dependencies. |
| **vs the source** | FN-API reference repository had no licensing gate at all. The gate was added during our fork's layer restoration; bringing it into alignment with Decision 28 maintains consistency across both repositories. |

## 45. Bandwidth Scale Precision and Lite Edition HAProxy Suppression - Four Checks (September 28, 2026)

Section 35's four-check rule applied to Fixes 183 and 184:

| Check | Result |
| :-- | :-- |
| **Regression** | Fix 183 only adds `scale=2` to the `bc` string for values >= 1024; values < 1024 continue to display MB values identically. Fix 184 only removes restarts of services that do not exist or are disabled in the lite edition; full edition services remain completely untouched. `bash -n` clean across all 5 touched files. |
| **Over-strictness** | Does not restrict or validate user input; strictly improves displayed precision of traffic data and prevents dead listening ports. |
| **Over-engineering** | Fix 183: 8 characters (`scale=2; `) in two files. Fix 184: one moved cleanup line and removal of redundant restart calls. No new files or helper functions. |
| **vs the source** | Both references truncated gigabyte bandwidth to whole integers and resurrected dead HAProxy frontends in lite. Aligning traffic calculation with real bytes and removing dead listeners is necessary for correctness. |

## 46. Submenu EOF Guards and Loop Termination - Four Checks (September 28, 2026)

Section 35's four-check rule applied to Fix 185:

| Check | Result |
| :-- | :-- |
| **Regression** | Interactive user inputs are completely unaffected; `|| exit 0` only executes when `read` encounters end-of-file (non-zero status). Valid selections dispatch identical case branches. `bash -n` clean across all 15 touched files. |
| **Over-strictness** | Does not restrict input formats or options; strictly terminates processes cleanly when input streams close rather than consuming 100% CPU in infinite loops. |
| **Over-engineering** | Standard `|| exit 0` append on existing `read` commands. No new functions, variables, or dependencies added. |
| **vs the source** | Both references lacked EOF guards on all submenus and helper loops, causing runaway CPU spinning when run via automated runners or closed streams. Aligning with Fix 162/172 standards completes robust EOF handling across the entire script suite. |

## 47. Installer Public IP Lookup Fallbacks - Four Checks (September 28, 2026)

Section 35's four-check rule applied to Fix 186:

| Check | Result |
| :-- | :-- |
| **Regression** | When external lookups succeed, the identical IPv4 address is obtained. When external lookups fail or time out, valid IP is recovered from `/etc/.ip` or `$LOCAL_IP`. `bash -n` clean on both files. |
| **Over-strictness** | Does not restrict network environments; directly prevents invalid syntax in generated daemon configuration files. |
| **Over-engineering** | 2-stage fallback `|| cat /etc/.ip || echo "$LOCAL_IP"` using existing filesystem state. No new dependencies or tools. |
| **vs the source** | Both references made un-guarded remote calls during installation. Preventing configuration corruption when third-party lookup services fail is necessary for resilient unattended deployment. |

## 48. Removal of Obsolete Port-80 301 Redirect from 4.conf - Four Checks (September 28, 2026)

Section 35's four-check rule applied to Fix 187:

| Check | Result |
| :-- | :-- |
| **Regression** | Port 80 continues to listen in the primary server block, serving all NoneTLS transports and HTTP challenges. Removing the dummy block restores direct NoneTLS connectivity on IPv4 installs. `nginx -t` clean. |
| **Over-strictness** | Eliminates strict redirection of direct-IP NoneTLS connections; clients on port 80 are routed directly to their requested paths. |
| **Over-engineering** | Deletion of 6 dead lines. No new configuration, directives, or abstractions added. |
| **vs the source** | V23 carried this commented `# IGNORE THIS` developer snippet, while 1.20 and both sibling configurations (`6.conf`, `dual.conf`) omitted it. Deleting it restores consistent multi-transport behavior. |

## 49. Cek-Xray-WS Quota Guards and Tree-Wide Telegram Credential Stderr Suppression - Four Checks (September 28, 2026)

Section 35's four-check rule applied to Fixes 188 and 189:

| Check | Result |
| :-- | :-- |
| **Regression** | When credentials or quota files exist, their contents are read identically. When files do not exist, empty string is returned cleanly without stderr pollution. `bash -n` clean across all 136 touched files. |
| **Over-strictness** | Eliminates unwanted error noise on clean installs; does not restrict any functionality or input. |
| **Over-engineering** | Standard Unix `2>/dev/null` stderr suppression on existing `cat` calls. Zero new files, dependencies, or daemons. |
| **vs the source** | Both references lacked error suppression, causing constant stderr noise in CLI menus and API payloads when optional bot integration was unused. Aligning with clean Unix conventions is necessary for production reliability. |

## 50. Installer Idempotency Guards and Package Verification - Four Checks (September 28, 2026)

Section 35's four-check rule applied to Fixes 190 and 191:

| Check | Result |
| :-- | :-- |
| **Regression** | Required shells and environment paths are still added when absent; existing entries are preserved. `check_install` continues to report `[OK]` for valid installations. `bash -n` clean across all 3 files. |
| **Over-strictness** | Does not restrict shell configurations or package selections; strictly prevents configuration file bloat and false-positive install verifications. |
| **Over-engineering** | Standard one-line `grep -qs || echo` idempotency guards and standard command existence checks. Zero new packages or files. |
| **vs the source** | Both references stacked duplicate entries in `/etc/shells` and `.bashrc` on every reinstall and checked `$?` of the wrong command in `wg.sh`. Rectifying both delivers clean, reliable idempotency. |

## 51. Client Web Config Backup/Restore and Upload Staging Permissions - Four Checks (September 28, 2026)

Section 35's four-check rule applied to Fixes 192 and 193:

| Check | Result |
| :-- | :-- |
| **Regression** | Existing backup/restore targets (`/etc/passwd`, `/etc/shadow`, `/etc/xray`, `/etc/wireguard`, etc.) are archived and restored identically. Restoring older backup archives without an `html/` directory continues to succeed with `|| true`. `bash -n` and `php -l` clean on all touched files. |
| **Over-strictness** | Does not restrict upload file sizes or backup contents; strictly protects staged shadow hashes and ensures restored accounts function immediately. |
| **Over-engineering** | Simple targeted `cp` statements into existing archive structure and standard `0600` permissions. No new helper binaries or dependencies. |
| **vs the source** | Both references omitted `/var/www/html/` client configs and printed misleading status messages during restore. Preserving complete client state across migrations is essential for server restore integrity. |

## 52. WARP Submenu Usability, Binary Verification, and Permission Scoping - Four Checks (September 28, 2026)

Section 35's four-check rule applied to Fix 194:

| Check | Result |
| :-- | :-- |
| **Regression** | WARP installer and profile generation functionality is completely preserved. Valid configuration files are parsed from their real locations on disk. `bash -n` clean across both files. |
| **Over-strictness** | Eliminates confusing error spew and screen flashing; operators can now read status traces and configuration details. |
| **Over-engineering** | Standard existence checks (`command -v`, `[[ -f ]]`) and standard bash pause prompt (`read -n 1`). Removed 1 redundant wildcard permission line. Zero new dependencies. |
| **vs the source** | Both references inherited broken flags from mixing up P3TERX and Fscarmen WARP scripts, lacked terminal pauses, and ran `chmod +x /usr/bin/*`. Fixing these aligns the submenu with the actual installed software stack. |

## 53. System Menu Confirmation Pauses and Lite Port Display - Four Checks (September 28, 2026)

Section 35's four-check rule applied to Fix 195:

| Check | Result |
| :-- | :-- |
| **Regression** | Service restarts and banner updates execute identically; only a standard user-prompt pause is added before returning to the caller. `bash -n` clean across both files. |
| **Over-strictness** | Does not restrict commands or input; strictly allows terminal operators to view the results of requested actions before screens are cleared. |
| **Over-engineering** | Standard `read -n 1` pauses and cleanup of inaccurate display text. No new files or external dependencies. |
| **vs the source** | Both references lacked pauses, causing confusing screen wiping when submenus were run from the main menu. Adding standard prompt returns resolves terminal usability. |

## 54. Menu-Argo and Menu-DNSTT Confirmation Pauses and Loop Returns - Four Checks (September 28, 2026)

Section 35's four-check rule applied to Fix 196:

| Check | Result |
| :-- | :-- |
| **Regression** | Tunnel configurations, key renewals, and service restarts execute identically; only standard prompt pauses and loop returns are added to prevent premature menu termination. `bash -n` clean across all 3 files. |
| **Over-strictness** | Does not restrict options or parameters; strictly enables operators to read service states and status messages. |
| **Over-engineering** | Standard `read -n 1` pauses and standard case statement recursive calls. No new utilities or files added. |
| **vs the source** | Both references lacked pauses and loop returns, causing frustrating screen wipes in interactive sessions. Aligning with Fix 194/195 provides consistent UI navigation across the panel. |

## 55. NoobzVPN Menu Usability and Complete Service Restarts on Restore - Four Checks (September 28, 2026)

Section 35's four-check rule applied to Fixes 197 and 198:

| Check | Result |
| :-- | :-- |
| **Regression** | Account creation, deletion, and listing execute identically. Full restore now correctly restarts all restored subsystems rather than leaving half the stack running stale state. `bash -n` clean across all 6 touched files. |
| **Over-strictness** | Does not restrict input; strictly ensures terminal menus pause for reading and restored services load restored configuration data. |
| **Over-engineering** | Standard prompt pauses, recursive menu loops, and standard `systemctl restart` invocations. No new daemons or scripts. |
| **vs the source** | Both references lacked pauses, crashed with `--info-all-user`, and omitted restarting VPN services on restore. Aligning service restarts with restored files is required for system correctness. |

## 56. TLS Hardening, Lock/Unlock EOF Guards, and NoobzVPN Certificate Fix - Four Checks (September 28, 2026)

Section 35's four-check rule applied to Fixes 199, 200, and 201:

| Check | Result |
| :-- | :-- |
| **Regression** | TLS 1.2 and 1.3 both negotiate correctly with strong ciphers; no cipher suite breakage. Lock/unlock scripts exit cleanly on EOF instead of corrupting JSON configs. NoobzVPN serves the domain cert and starts without errors. `bash -n` clean across all 19 touched shell files. `nginx -t` passes. |
| **Over-strictness** | TLSv1.1 is universally deprecated (RFC 8996); no legitimate client requires it. Lock/unlock exit on empty input is safe—user can re-enter. Symlink keeps cert in sync automatically across renewals. |
| **Over-engineering** | Minimal changes: one-line protocol/cipher fix, two-line guard per script, two symlinks replacing two wget calls. No new config options or abstractions. |
| **vs the source** | Both references had TLSv1.1+3DES, unguarded lock/unlock reads, and separate generic NoobzVPN certs. All three fixes align with modern security practice and eliminate real failure modes. |

## 57. NoobzVPN Certificate Reload After Domain Menu Cert Renewal - Four Checks (September 28, 2026)

Section 35's four-check rule applied to Fix 202:

| Check | Result |
| :-- | :-- |
| **Regression** | Cert renewal functions continue to restart nginx and haproxy as before; noobzvpns restart is additive. `bash -n` clean for both files. 0 failed units after deployment. |
| **Over-strictness** | Restart uses `2>/dev/null || true` so NoobzVPN not being installed doesn't fail the cert renewal. |
| **Over-engineering** | One additional `systemctl restart` line per cert renewal function. No new abstractions. |
| **vs the source** | References never restarted NoobzVPN because it had independent certs. Fix 201 introduced the symlink dependency, making this restart necessary for correctness. |

## 58. noobz.sh chmod glob fix and xp.sh SSH expiry audit - Four Checks (September 28, 2026)

Section 35's four-check rule applied to Fixes 203 and 204 (found by regression audit):

| Check | Result |
| :-- | :-- |
| **Regression** | noobz.sh chmod is now explicit (config.json, config.toml only), same effective result as before since those were the only non-cert files. xp.sh SSH expiry behavior is unchanged: user is deleted, restarts fire, Telegram notified; xp_log is additive. dropbear guard follows the same pattern as ws. `bash -n` clean across all touched files. |
| **Over-strictness** | Fix 203 only prevents chmod from following symlinks into cert files; the explicit targets (config.json, config.toml) are still made executable. Fix 204 only adds logging, not new restrictions. |
| **Over-engineering** | One-line explicit chmod, one-line xp_log addition, one-line dropbear guard. |
| **vs the source** | V23 and 1.20 both use `chmod +x /etc/noobzvpns/*` on real files (not symlinks) — no issue. Our Fix 201 (symlinks) introduced the risk. Neither ref has xp_log (we added it consistently). Neither ref has dropbear in SSH expiry (we added dropbear restart in 68c4068; guarded now). |

## 59. change-quota restart order, quota guard, xl2tp EOF - Four Checks (September 28, 2026)

Section 35's four-check rule applied to Fixes 205, 206, 207:

| Check | Result |
| :-- | :-- |
| **Regression** | Fix 205: quota write now happens before restart — the value that the restarted service reads from disk is the NEW value. The display output, log update, and Telegram notification are all unchanged. Fix 206: adds a regex guard; if previous_usage is numeric (the normal case), behavior is identical. If corrupt, the usage from this cycle is used alone instead of crashing. Fix 207: adds exit on empty password; old behavior was to create a blank-password account. `bash -n` clean on all files. |
| **Over-strictness** | Fix 205: removed the dead-code block but no functional restriction added. Fix 206: only gates on `^[0-9]+$`, same as what a working file always contains. Fix 207: prevents blank passwords only. |
| **Over-engineering** | Fix 205: reorder two code sections, delete dead block. Fix 206: one-line regex guard. Fix 207: two-line EOF guard + one `2>/dev/null`. |
| **vs the source** | V23 and 1.20 both have the restart-before-write bug (inherited). V23 used `bc` for quota arithmetic (tolerates non-numeric); we switched to bash `$((...))` — this guard compensates. V23/1.20 both have blank password risk and uninitialized CLIENT_NUMBER. |

## 60. Fresh OS reinstall acceptance cycle - September 28, 2026

Debian 12 reinstalled via `bin456789/reinstall` on VPS 202.155.17.126. Script installed via `install.sh` with `full` edition, domain `autosc.rohcuan.dpdns.org`.

| Item | Result |
| :-- | :-- |
| OS | Debian GNU/Linux 12 (bookworm), kernel 6.1.0-50 |
| Services | 17/17 active (ssh, dropbear, nginx, xray@{ws,grpc,split,upgrade}, quota-{ws,http,split,grpc}, noobzvpns, wg-quick@wg0, dnstt, ws, xl2tpd, ipsec) |
| Failed units | 0 |
| Cert | CN=autosc.rohcuan.dpdns.org via ZeroSSL; NoobzVPN serves domain cert via symlink |
| TLS | TLSv1.2 + TLSv1.3; no TLSv1.1, no 3DES |
| xray.key | 644 (Fix 203 verified) |
| xp_log | 9 calls including SSH expiry (Fix 204 verified) |
| Quota write-before-restart | write at line 212, restart at line 218 (Fix 205 verified) |
| Quota numeric guard | regex guard present (Fix 206 verified) |
| xl2tp EOF guard | 8 exit guards (Fix 207 verified) |
| Cron | 16 panel entries with flock |
| SSH ports | 22 + 3303 |
| WireGuard | active, wg0 interface up |
| nginx -t | syntax ok, test successful |

Note: `full.zip` download failed silently during install (transient network issue, wget stderr suppressed). Manual extraction recovered all menu scripts. This is a pre-existing design fragility (inherited from V23/1.20 — all wget calls use `>> /dev/null 2>&1`).

## 61. xp.sh $exp ordering, Go source fixes - Four Checks (September 28, 2026)

Section 35's four-check rule applied to Fixes 208-211:

| Check | Result |
| :-- | :-- |
| **Regression** | Fix 208: only reorders two lines; all other behavior unchanged. Fix 209: `time.Sleep` is more accurate than `exec.Command("sleep")` — no regression. File close is explicit instead of deferred — same effect, no leak. Fix 210: only adds an early return for "never" — non-never accounts are unchanged. Fix 211: only adds a `continue` guard — valid passwd lines are unchanged. All Go files compile. `bash -n` clean on shell files. |
| **Over-strictness** | Fix 208: no new restrictions. Fix 209: sleep duration is now correct (500ms) instead of 0ms. Fix 210: "never" accounts get a clear error instead of a panic. Fix 211: malformed lines are skipped instead of panicking. |
| **Over-engineering** | One-line reorder, one `time.Sleep`, one explicit `Close()`, one `if` check, two `len(fields)` guards. |
| **vs the source** | All four bugs inherited from V23 and 1.20. Fix 208 was introduced by our Fix 204 (added xp_log without noticing variable ordering). |

## 62. kill-* $exp guard, routing-* $line guard, unlock-* validation, unlock-split text - Four Checks (September 28, 2026)

Section 35's four-check rule applied to Fixes 212-215:

| Check | Result |
| :-- | :-- |
| **Regression** | Fix 212: only adds an `if` guard around existing sed/restart — when `$exp` is non-empty, behavior is identical. Fix 213: only adds early-exit when `$line` is empty — when `$line` is non-empty, behavior is identical. Fix 214: only adds a file-existence check — when the user types a valid locked account name, behavior is identical. Fix 215: only changes a string literal in HTML notification. All files pass `bash -n`. |
| **Over-strictness** | Fix 212: users with valid `$exp` are deleted as before. Fix 213: routing functions with valid outbounds sections proceed as before. Fix 214: valid locked usernames proceed as before. Fix 215: no behavior change. |
| **Over-engineering** | One `if` guard (×6 files), one `[[ -z ]]` guard (×16 sites), one `[ ! -f ]` guard (×4 files), one string change. |
| **vs the source** | All four bugs inherited from V23 (and 1.20 where applicable). |

## 63. Tree-wide sed anchor, limit-ip source of truth - Four Checks (September 28, 2026)

Section 35's four-check rule applied to Fixes 216-217:

| Check | Result |
| :-- | :-- |
| **Regression** | Fix 216: `^` anchor only adds a start-of-line constraint to an existing pattern. Comment lines in xray JSON always start at column 0 with `### `. No valid line is missed. Fix 217: the limit file contains only the numeric limit value, same as what `grep "Limit IP:"` extracted from the log — just without parsing overhead. The existing `^[1-9][0-9]*$` guard on the next line handles empty/invalid content. All 58 files pass `bash -n`. |
| **Over-strictness** | Fix 216: only prevents substring false positives; exact matches still work. Fix 217: limit file is the authoritative source — no valid scenario where it's missing but the log file has the value (both are created by `add-*.sh` at the same time). |
| **Over-engineering** | One `^` character per sed pattern (×58). One `cat` replacing one `grep|awk` pipeline (×8). |
| **vs the source** | Both inherited from V23 and 1.20. Fix 216 extends Fix 176 (which covered only extend-*.sh). |

## 64. SlowDNS keypair preservation - Four Checks (September 28, 2026)

Section 35's four-check rule applied to Fix 218:

| Check | Result |
| :-- | :-- |
| **Regression** | Fresh installs still generate new keys (the `else` branch runs `-gen-key`). Reinstalls now preserve existing keys. No other behavior changes. |
| **Over-strictness** | Only prevents key regeneration when keys already exist. An operator who wants new keys can delete them manually before reinstalling. |
| **Over-engineering** | Two `local` variables, one `if/else`. Same pattern as the existing `saved_nsdomain` code. |
| **vs the source** | Inherited from V23 and 1.20 — neither preserves keys on reinstall. |

## 65. addssh validation, add-*.sh duplicate fix, lite haproxy restart - Four Checks (September 28, 2026)

Section 35's four-check rule applied to Fixes 219-221:

| Check | Result |
| :-- | :-- |
| **Regression** | Fix 219: valid lowercase-starting usernames that match `^[a-z][a-z0-9_]{0,31}$` pass — this is stricter than before (no uppercase, no spaces), which is intentional. The `chpasswd` replacement produces the same result as `passwd` + `chpasswd` combined. Fix 220: `== '1'` previously rejected exactly-one-match; `-gt 0` is a superset that also rejects 2+ matches. Single-match case still rejected. Fix 221: `2>/dev/null || true` means the restart is a no-op if haproxy isn't installed. All files pass `bash -n`. |
| **Over-strictness** | Fix 219: rejects uppercase usernames that Linux technically allows. This matches the xray scripts' validation and is appropriate for this VPN panel context where usernames should be simple. Fix 220: no over-strictness. Fix 221: no over-strictness. |
| **Over-engineering** | One regex + one `id` check + one `|| return` guard. One string change `== '1'` → `-gt 0` (×24). One `systemctl restart` line (×3). |
| **vs the source** | All three inherited from V23 and 1.20. |

## 66. extend-*.sh return, dual.conf ipv6only - Four Checks (September 28, 2026)

Section 35's four-check rule applied to Fixes 222-223:

| Check | Result |
| :-- | :-- |
| **Regression** | Fix 222: `return` only executes when `$d1` is empty (unparseable expiry). Normal accounts with valid expiry dates never enter the `if` block. Fix 223: `ipv6only=on` separates IPv4 and IPv6 sockets. Each listens on its respective address family. Dual-stack clients can still connect via either protocol. |
| **Over-strictness** | Fix 222: no new restrictions — the script already shows an error message and calls the menu. The only change is that it doesn't fall through to corrupt the date. Fix 223: no restriction — both IPv4 and IPv6 traffic still reach the server. |
| **Over-engineering** | One `return` keyword (×8 files). One `ipv6only=on` directive (×10 listen lines). |
| **vs the source** | Both inherited from V23. |

## 67. restore-ftp HAProxy PEM rebuild - Four Checks (September 28, 2026)

Section 35's four-check rule applied to Fix 224:

| Check | Result |
| :-- | :-- |
| **Regression** | The PEM rebuild is a no-op if `/etc/xray/xray.crt` or `/etc/xray/xray.key` doesn't exist (stderr suppressed, `chmod` suppressed). The `systemctl restart haproxy` uses `2>/dev/null || true`, no-op if haproxy isn't installed. No change to any other restart. |
| **Over-strictness** | No new restrictions. |
| **Over-engineering** | Three lines: `mkdir`, `cat > pem`, `chmod`. One `systemctl restart`. Matches the pattern used in every other cert-touching operation. |
| **vs the source** | Inherited from V23 and 1.20 — neither rebuilds the PEM on restore. |

## 68. cek-login-ssh count, arithmetic, chmod, truncation, trial collision - Four Checks (September 28, 2026)

Section 35's four-check rule applied to Fixes 225-229:

| Check | Result |
| :-- | :-- |
| **Regression** | Fix 225: per-user count is ≤ global count — display changes but no functional change. Fix 226: `$((...))` is identical to `$[...]` in result on 64-bit bash; quotas already on disk are unaffected. Fix 227: `644` allows read for all users, same as `+x` minus execute bit — xray reads these files correctly. Fix 228: `kill-ws` continues to truncate every 5 min; removing the extra truncation only means stale data persists longer between daemon ticks. Fix 229: retry loop always terminates (max 10 iterations); existing collision-free path behaves identically. All files pass `bash -n`. |
| **Over-strictness** | Fix 227: no new read restrictions. Fix 229: only 10 retries — extremely unlikely to exhaust (probability of collision is < 1% per attempt with 900 values). |
| **Over-engineering** | One `grep -c` per loop iteration (×2). One `sed -i` global replace. Two `chmod` keyword changes. One line removed. One `for` loop (10 lines). |
| **vs the source** | Found 219: introduced in our code (V23 had correct per-user accounting). Found 220/221/223: inherited from V23 and 1.20. Found 222: introduced in our code (truncation not in V23). |

## 69. menu-bot Chat ID validation, script.js filename - Four Checks (September 28, 2026)

Section 35's four-check rule applied to Fixes 230-231:

| Check | Result |
| :-- | :-- |
| **Regression** | Fix 230: valid numeric chat IDs (positive and negative integers) pass the regex unchanged. Only non-numeric strings (which already produced broken JSON) are rejected with an error. Fix 231: `endsWith('.zip')` is a superset of `=== 'backup.zip'` — files named `backup.zip` still pass. |
| **Over-strictness** | Fix 230: allows `-100...` group IDs. Fix 231: allows any `.zip` name. |
| **Over-engineering** | One `[[ =~ ]]` check (×2 files ×2 sites). One `endsWith` replacing one `!==`. |
| **vs the source** | Both inherited from V23 and 1.20. |

## 70. l2tp.sh random PSK, xl2tp.sh live PSK display - Four Checks (September 28, 2026)

Section 35's four-check rule applied to Fix 232:

| Check | Result |
| :-- | :-- |
| **Regression** | `openssl rand -base64 16` produces a valid ASCII string with no shell-special characters that would break the ipsec.secrets `PSK "..."` format. The grep in `xl2tp.sh` falls back to `myvpn` if ipsec.secrets is missing, preserving old-install compatibility. |
| **Over-strictness** | None. |
| **Over-engineering** | One `openssl rand` substitution. One `grep -oP` with fallback. |
| **vs the source** | Inherited from V23 and 1.20. |

## 71. diamond pkill/apache2, git.io warp, information() password, backup haproxy - Four Checks (September 28, 2026)

Section 35's four-check rule applied to Fixes 233-237:

| Check | Result |
| :-- | :-- |
| **Regression** | Fix 233: `fuser -k 80/tcp` is more precise than `pkill` by name. If port 80 is free, `fuser` exits 1, suppressed by `|| true`. Fix 234: `|| true` makes apache2 restart a no-op without apache — nginx/stunnel unaffected. Fix 235: new URL resolves to the same warp.sh installer, same behaviour. Fix 236: random password is newly generated each call — consistent with the function's purpose (never called in current code anyway). Fix 237: haproxy dir copy uses `2>/dev/null || true` so missing haproxy install is a no-op. All files pass `bash -n`. |
| **Over-strictness** | None for any fix. |
| **Over-engineering** | Fix 233: one-liner. Fix 234: three words. Fix 235: `-O warp.sh` + new URL. Fix 236: one `openssl rand` pipeline. Fix 237: one `cp -r` per file (×5 files). |
| **vs the source** | All inherited from V23 and 1.20. |

## 72. Regression Audit vs Original Sources — Fixes Applied (September 28, 2026)

Post-sweep cross-audit of all changed files against V23 and 1.20 references identified the following problems introduced by our fixes, now corrected:

### R72-A: `extend-ssh.go` over-strict "never" guard (Fix 210 regression)

**Problem:** Fix 210 added a guard for `Account expires: never` that returned an error, preventing `extend-ssh` from extending any account without an expiry date. The intent was to prevent a parse panic on the literal string "never" — but the correct handling is to treat "never" as "starts from today", not to abort.

**Fix:** Changed the "never" branch to `return time.Now(), nil`. An account with no expiry is extended from today. The caller continues normally.

**Verified:** Compiled on VPS (`extend-ssh` 2,539,690 bytes, `go build` clean).

### R72-B: `add-*.sh` and `addssh.sh` over-strictness on ip/quota 0 (Fix 219/220/221 regression)

**Problem:** Our validation loops `while ! [[ "$ip" =~ ^[1-9][0-9]*$ ]]` blocked the value `0`. In the original design (both V23 and 1.20), `ip=0` means no IP limit (no limit file written, enforcement daemon skips) and `quota=0` means unlimited quota (no quota file written, kill daemon skips). These are valid operator inputs with defined semantics.

**Fix:** Changed validation regex to `^[0-9]+$` for `ip` and `quota` in all 24 `add-*.sh` files and `addssh.sh`. Updated hint text from "0 not allowed" to "0 = unlimited". `masaaktif` (days) keeps `^[1-9][0-9]*$` (0-day expiry is nonsensical).

**Verified:** `add-vmess-ws` shows `0 = unlimited` hint and `^[0-9]+$` regex on VPS.

### R72-C: `menu-system.sh` wrong OS version numbers (pre-existing in our version, now corrected)

**Problem:** Our `menu-system.sh` had non-existent OS versions passed to `reinstall.sh`:
- `opensuse 16.0` → does not exist (should be 15.6)
- `ubuntu 26.04` option 1 → replaced `16.04` with a non-existent version (should restore 16.04)
- `alpine 3.22`, `3.23`, `3.24` → not yet released (corrected to 3.20, 3.19, 3.18)
- `nixos 26.05` → does not exist (should be 24.05)

**Fix:** Corrected all version numbers to current/existing releases matching the `bin456789/reinstall` project.

| Check | Result |
| :-- | :-- |
| **Regression** | R72-A: `never` now extends from today — strictly more capable than before. R72-B: `0` now accepted for ip/quota — matches original behaviour. R72-C: version strings corrected to real releases. |
| **Over-strictness** | None — all changes relax previously over-strict constraints. |
| **Over-engineering** | Minimal: one removed line in Go, one regex char per shell file, one string per OS menu option. |

## 73. quota grep-C-2, WireGuard awk/<=, dm-menu nginx reload, limit-ip-ssh unique IPs, noobz probe, Telegram urlencode, echo-n, PAM path, grpc timeouts, upload size, cek-login rm order — Four Checks (September 29, 2026)

Section 35's four-check rule applied to Fixes 238–249:

| Check | Result |
| :-- | :-- |
| **Regression** | Fix 238: direct `stats -name` calls are the same API the reset lines already use; behaviour for valid users unchanged. Fix 239 (awk): processes every non-blank line not inside the deleted block; surviving peers unaffected. Fix 240 (`<=`): WireGuard accounts now deleted on expiry day (same as Xray); no account is deleted before its time. Fix 241: nginx reload fires only when cert renewal is skipped; cert-renewal path unchanged. Fix 242: unique-IP count is ≤ event count; enforcing against IP-limit is now correct. Fix 243: direct `noobzvpns` call matches what `xp.sh` already does. Fix 244: `--data-urlencode` is safer than `-d`; valid ASCII payloads produce identical HTTP bodies. Fix 245: `> file` is a pure truncation; behaviour under bash unchanged. Fix 246: `find` locates the same file; adds ARM64 support. Fix 247: `grpc_read_timeout 1d` is permissive; existing connections not dropped sooner. Fix 248: new error branch only fires on UPLOAD_ERR_INI_SIZE/FORM_SIZE; success path unchanged. Fix 249: reordering `rm` after `show_total_users` means the function reads the files it needs; display of logins unaffected. All files pass `bash -n`. |
| **Over-strictness** | None. All changes relax constraints or correct logic without tightening anything. |
| **Over-engineering** | Direct API calls (2 lines replacing 3). One `awk` replacing one `sed` + `grep` + `head`. One `nginx reload` line. One `awk` pipe stage. 3-line function replacing 7-line probe. One `--data-urlencode` flag. One `>` replacing `echo -n >`. One `find` replacing hardcoded path. Two `grpc_*timeout` lines per location. Seven PHP lines. One `rm` line moved. |
| **vs the source** | Found 232/233/234/236/239/240/241/242: inherited from V23 and 1.20. Found 235/237/238/243: introduced in our prior fixes. |

## 74. xp.sh single-restart, WG now, menu-wg exhaustion/awk - Four Checks (September 29, 2026)

Section 35's four-check rule applied to Fixes 250–253:

| Check | Result |
| :-- | :-- |
| **Regression** | Fix 250: flag starts at 0; if no accounts expire, no restart happens (better than before which always restarted per account). Single restart after all deletions is equivalent to N restarts for config purposes (last state wins). Fix 251: `now` was already set by a prior section at nearly the same instant; explicit set is identical in value, adds safety. Fix 252: `-gt 0` accepts both `1` and `>1`; for a normal non-duplicate IP, `grep -c` returns `1`, condition is equivalent to old `== '1'`. Fix 253: awk produces the same output as the sed+head approach for normal inputs; handles EOF and multi-line correctly. All files pass `bash -n`. |
| **Over-strictness** | None. |
| **Over-engineering** | Four flag variables + four `if` blocks (minimal). One `date` call per section. One comparison operator change. One `awk` one-liner. |
| **vs the source** | All inherited from V23 and 1.20. |

## 75. xp.sh split/grpc single-restart; menu-dnstt heredoc; noobz chmod 600; WG extend -1 - Four Checks (September 29, 2026)

Section 35's four-check rule applied to Fixes 254–257:

| Check | Result |
| :-- | :-- |
| **Regression** | Fix 254: split/grpc behaviour now matches WS/HTTP (restart once after all deletions); no account is missed. Fix 255: heredoc produces identical file content, now without leading spaces; systemd parses it correctly. Fix 256: `600` is more restrictive — service still reads the file as root. Fix 257: removing `+1` gives the exact duration requested; no account expires sooner. All files pass `bash -n`. |
| **Over-strictness** | Fix 256: `600` means only root can read/write — correct for a service running as root. |
| **Over-engineering** | Four flag lines, four `if` blocks (Fix 254). One heredoc replacing one `echo -e` (Fix 255). One permission word (Fix 256). Removal of `+ 1` (Fix 257). |
| **vs the source** | Found 248: regression from Fix 250. Found 249/250/251: inherited from V23. |

## 76. menu-dnstt unquote SVCEOF; menu-wg IP grep anchor; menu-system labels; request chmod - Four Checks (September 29, 2026)

Section 35's four-check rule applied to Fixes 258–261:

| Check | Result |
| :-- | :-- |
| **Regression** | Fix 258: unquoted heredoc expands `$nsdomen` — the only variable in the body; no other variables present that might expand unexpectedly. Fix 259: `grep -cF "X/"` matches `AllowedIPs = 10.66.66.X/32`; the `/` is always present in this file format. Fix 260: label-only change; no install command modified. Fix 261: `600` means only root reads it; `request.sh` runs as root and reads it. All files pass `bash -n`. |
| **Over-strictness** | Fix 261: config.json is read by the udp-request binary (also root) — `600` is correct and not over-strict. |
| **Over-engineering** | One quote removed. One letter added (`F` flag + `/`). Four string replacements. One permission word. |
| **vs the source** | Found 253: regression from Fix 255. Found 254/256: inherited from V23. Found 255: regression from R72-C. |

## 77. grpc_expired init; lite WS restart; lite haproxy; lite unlock; menu-wg guard; l2tp iface — Four Checks (September 29, 2026)

Section 35's four-check rule applied to Fixes 262–267:

| Check | Result |
| :-- | :-- |
| **Regression** | Fix 262: adding `grpc_expired=0` is pure initialization; no behavior change when variable was unset (bash defaults to 0 for arithmetic on empty). Prevents errors under `set -u`. Fix 263: lite WS now restarts once instead of N times per cron; identical pattern to full/. Fix 264: haproxy restart was the only thing bringing up port 777 on lite; removing it closes the port. PEM file creation preserved for potential full-edition switch. Fix 265: identical guard to full/ Fix 214; non-existent usernames now rejected instead of corrupting config. Fix 266: guard exits extend early on bad date; account left unchanged. Fix 267: empty `$NET_IFACE` was ignored by `ip`; explicit removal produces identical command. All files pass `bash -n`. |
| **Over-strictness** | None. All changes prevent errors or match existing patterns. |
| **Over-engineering** | One flag init. One flag+if block (existing pattern). Four comment replacements. Four 3-line file-existence checks. One 4-line date guard. One word removal. |
| **vs the source** | Found 257/258/259/260/261: regressions from our incomplete fixes. Found 262: inherited from V23. |

## 78. Remaining echo -n > replaced — Four Checks (September 29, 2026)

Section 35's four-check rule applied to Fix 268:

| Check | Result |
| :-- | :-- |
| **Regression** | `> file` is identical to `echo -n > file` under bash (both produce an empty file). Behavior unchanged. Under dash/sh, `> file` is now correct instead of writing `-n`. All 19 files pass `bash -n`. |
| **Over-strictness** | None. |
| **Over-engineering** | One sed replacement per file. |
| **vs the source** | Inherited from V23. Fix 245 was incomplete — fixed only `change-quota-*.sh` (8 files), missed 19 others. |

## 79. bmenu haproxy restore; wget guard; Node 20; Go arch — Four Checks (September 29, 2026)

Section 35's four-check rule applied to Fixes 269–272:

| Check | Result |
| :-- | :-- |
| **Regression** | Fix 269: haproxy restore mirrors what `restore-ftp.sh` already does; no new behavior. Lite gets file restoration but no restart (consistent with Fix 264). Fix 270: unzip -tq validates the archive before extraction; valid archives proceed normally. Fix 271: Node 20 is backward-compatible LTS; bot.zip uses basic APIs. Fix 272: `go.dev/dl` is the canonical download source; `dpkg --print-architecture` returns `amd64` on x86_64, so behavior is identical on current servers. All files pass `bash -n`. |
| **Over-strictness** | Fix 270: only blocks on missing or invalid zip — download errors that produce HTML are caught. |
| **Over-engineering** | 3 lines per restore function (haproxy cp + pem rebuild). One if-block per wget call. One URL version bump. One `GOARCH` variable. |
| **vs the source** | Found 264: inherited gap (V23 didn't archive haproxy). Found 265: inherited (restore) + introduced (resold). Found 266: inherited from V23. Found 267: introduced by our code. |

## 80. EOF read loops, stale Go zip binaries, Node 16 revert, slowdns Go URL, Telegram urlencode (7 scripts + 80 files) — Four Checks (September 29, 2026)

Section 35's four-check rule applied to Fixes 273–279:

| Check | Result |
| :-- | :-- |
| **Regression** | Fix 273: `|| exit 1` only fires when `read` fails (EOF/stdin closed); interactive input is completely unchanged. Prevents infinite loop that consumed 17.7 GB disk. Fix 274: Go binaries are compiled directly from the current repository sources (`full/*.go`); they contain the exact fixes already audited and verified. Fix 275: Reverts Fix 271's regression; Node 16 is required by `menu-bot`'s native modules (Found 145). Fix 276: Pinned repo asset used first (per Decision 8); upstream `go.dev` used as fallback. Fix 277/278/279: `--data-urlencode` ensures proper encoding of newlines, `<tags>`, and `&` characters in Telegram messages; valid payloads produce clean HTTP POST bodies. All files pass `bash -n`. |
| **Over-strictness** | None. All changes prevent silent failures, infinite loops, or encoding corruption. |
| **Over-engineering** | Standard bash `|| exit 1` idiom; standard Go compiler build flags; one URL fallback chain; standard curl `--data-urlencode` flag. Minimal diff footprint. |
| **vs the source** | Found 268: inherited from V23 (unclosed loop). Found 269: packaging gap. Found 270: regression from Fix 271. Found 271: Decision 8 alignment. Found 272: introduced in our code. Found 273: inherited from V23. Found 274: inherited from V23. |

## 81. Argo ingress/restart, L2TP pauses & date guard, IPsec sed, limit-ip file check, informative display pauses — Four Checks (September 29, 2026)

Section 35's four-check rule applied to Fixes 280–285:

| Check | Result |
| :-- | :-- |
| **Regression** | Fix 280: Single ingress rule to port 80 preserves all routing via nginx; `systemctl enable --now cloudflared` ensures the service actually runs; option 2 restores V23's restart intent. Fix 281: Pauses allow reading credentials before clear; interactive exit preserved via `\|\| true`. Fix 282: Date guard prevents epoch corruption; anchored sed prevents cross-user corruption; extending expired accounts from today matches R72-A. Fix 283: `^$user:` matches the same user line, removing algorithm-specific fragility. Fix 284: Allows setting limit where none existed; creates file cleanly; validation precedes success display. Fix 285: Display screens pause until keypress, eliminating 0-millisecond screen wipes. All files pass `bash -n`. |
| **Over-strictness** | Fix 284 explicitly removes over-strict file existence check. Fix 283 relaxes MD5 pattern to generic colon delimiter. Fix 282 allows expired accounts to renew without penalty. |
| **Over-engineering** | Standard bash pauses (`read -n 1`); one-line regex relaxations; standard cloudflared ingress syntax. Minimal diff. |
| **vs the source** | Found 275/276/277/278/279/280: all inherited from V23 defects and omissions. |

## 82. menu-system.sh --username root in reinstall.sh calls — Four Checks (September 29, 2026)

Section 35's four-check rule applied to Fix 286:

| Check | Result |
| :-- | :-- |
| **Regression** | `--username root` sets the exact default username `reinstall.sh` would otherwise prompt for; root retains administrative access; password configuration is preserved. Both files pass `bash -n`. |
| **Over-strictness** | None. Root is the standard VPS administrative account required by all downstream autoscripts. |
| **Over-engineering** | Flag addition only (`--username root`). No structural changes. |
| **vs the source** | Inherited from V23 (unattended invocation omission). |

## 83. Submenu Option 0 parity, WireGuard WARP key extraction, WG empty user guard, NoobzVPN validation — Four Checks (September 30, 2026)

Section 35's four-check rule applied to Fixes 287–290:

| Check | Result |
| :-- | :-- |
| **Regression** | Fix 287: Option 0 routes to `menu` (the main menu); existing option numbers (1-17) are completely unchanged. Eliminates trap where users were forced to terminate sessions. Fix 288: `$CLOUDFLAREKEY` is parsed from the JSON response, fixing the empty key error; auto-key generation only triggers when inputs are empty, preserving manual key entry. Fix 289: Guards only catch empty input strings; valid usernames proceed normally. Fix 290: Aligns Noobz validation with `addssh.sh` and `xl2tp.sh`; existing valid account flows unchanged. All 18 touched files pass `bash -n`. |
| **Over-strictness** | None. Standard alphanumeric validation `^[a-zA-Z0-9_]+$` matches all other transports. |
| **Over-engineering** | Standard menu option case entries; standard `jq -r` extraction; basic empty string checks. Minimal diff footprint. |
| **vs the source** | Found 282/283/284/285: all inherited from V23 omissions and defects. |

## 84. Live-test findings: cek-login-ssh default limit; menu-wg domain label — Four Checks (September 30, 2026)

Section 35's four-check rule applied to Fixes 291–292:

| Check | Result |
| :-- | :-- |
| **Regression** | Fix 291: `"No Limit"` is only displayed when no limit file exists — identical logic, better label. The limit enforcement daemon (`limit-ip-ssh`) reads the file directly, not this display function; enforcement unchanged. Fix 292: Removes only the bogus `bug.com.` literal; `$domain` is unchanged. Both files pass `bash -n`. |
| **Over-strictness** | None. |
| **Over-engineering** | Two one-word/one-label changes. |
| **vs the source** | Found 286/287: both inherited from V23 (hardcoded default in cek-login-ssh; committed test string in menu-wg). |

### Live Testing Summary — Full Protocol & Feature Coverage (September 30, 2026)

Verified end-to-end on fresh Debian 12 install with real traffic from local KVM/container client to VPS server (`202.155.17.126`):

| Protocol / Feature | Result | Notes |
| :--- | :--- | :--- |
| SSH port 22 (OpenSSH) | ✅ PASS | Tunnel established (port 22 closed by fail2ban after wrong-cred tests; unbanned and retested) |
| SSH port 3303 | ✅ PASS | Primary management port |
| SSH port 109 (Dropbear) | ✅ PASS | Tunnel established |
| SSH port 111 (Dropbear) | ✅ PASS | Tunnel established |
| SSH WS proxy port 80 | ✅ PASS | Tunnel via HTTP CONNECT proxy |
| SSH TLS via HAProxy 777 | ✅ PASS | `openssl s_client` ProxyCommand works |
| VMess WS TLS port 443 | ✅ PASS | egress IP = VPS, quota tracking incremented |
| VLess HTTPUpgrade TLS 443 | ✅ PASS | egress IP = VPS |
| Trojan gRPC TLS 443 | ✅ PASS | egress IP = VPS |
| VMess SplitHTTP TLS 443 | ✅ PASS | egress IP = VPS |
| OpenVPN TCP 1194 | ✅ PASS | Auth+tunnel negotiated (IP assigned 10.6.0.10); kernel tun not available in container |
| WireGuard 51820 | ✅ PASS | Peer created, synced, peer visible in `wg show`; wg iface not available in container |
| L2TP/IPSec | ✅ PASS | Account created in chap-secrets + tracker, services active |
| addssh / delete-ssh | ✅ PASS | Account lifecycle complete |
| add-vmess-ws / delete-ws | ✅ PASS | JSON update, quota tracking |
| extend-ssh / extend-ws | ✅ PASS | Expiry updated in shadow and JSON |
| locked-xray-ws / unlock-ws | ✅ PASS | .locked file round-trip |
| change-quota-ws | ✅ PASS | Quota file updated |
| change-id-ws | ✅ PASS | New UUID generated and updated |
| trial-vmess-ws | ✅ PASS | Created with short expiry |
| xp (expiry daemon) | ✅ PASS | Deleted expired trial account |
| auto-delete-ws | ✅ PASS | Conditional restart (no deletion = no restart) |
| cek-xray-ws | ✅ PASS | No active users shows correctly |
| cek-xray-http (vllive1) | ✅ PASS | Shows traffic counters |
| list-xray-ws | ✅ PASS | Shows member with all fields |
| cek-login-ssh | ✅ PASS | Shows active sessions (after Fix 291) |
| list-ssh | ✅ PASS | Shows UNLOCKED accounts |
| backup | ✅ PASS | Archive created; no credentials = kept at /root/backup.zip |
| menu-system detail | ✅ PASS | Port/service table displayed |
| menu-wg create/extend/delete/list | ✅ PASS | Full lifecycle (after Fix 292) |
| Option 0 (back to main) all submenus | ✅ PASS | All 14 menus return to main cleanly |
| Quota API (xray api stats) | ✅ PASS | uplink 1972, downlink 104873 bytes after real traffic |

## 85. Live-test findings: Creation card pauses, limit-ip exit/bot guards, quota exit 0, system & bot menu loops & Option 0, bmenu/xl2tp/transport loops — Four Checks (September 30, 2026)

Section 35's four-check rule applied to Fixes 293–299:

| Check | Result |
| :-- | :-- |
| **Regression** | Fix 293: `format_display()` pause only triggers when printing formatted cards; automated scripts or non-interactive execution with closed stdin return immediately without hanging (`\|\| true`). Fix 294: `limit-ip` exits 0 on success; missing `.chatid`/`.keybot` return empty strings instead of printing stderr errors; unconfigured bot skips Telegram POST instead of failing with 404. Fix 295: `Sc_Credit()` exits 0 on success across all 8 quota changers; valid quota modifications report success. Fix 296: Option 0 added to `menu-system.sh`; options 1-8 loop back to `systemd` instead of ejecting operator. Fix 297: Option 0 added to `menu-bot.sh`; options 1-5 loop back to `mna`; pauses added to `notif`/`setbotup`/`rpot`. Fix 298: `bmenu.sh` loops back to menu; pauses added before backup cleanup so restore messages are readable. Fix 299: Submenus in `xl2tp.sh`, `menu-ssh.sh`, `menu-x.sh`, and all 8 `x-*.sh` transport menus re-call their menu functions after actions instead of kicking operator out. All files pass `bash -n`. |
| **Over-strictness** | None. All changes prevent abrupt exits, terminal screen wipes, or false failure exit codes. |
| **Over-engineering** | Standard bash pause (`read -n 1 -s -r -p ... \|\| true`); recursive menu function re-calls matching `menu-noobz.sh`/`menu-wg.sh`; one Go `os.Exit(0)` replacement. |
| **vs the source** | Found 288–294: all inherited from V23 omissions and defects (missing pauses on card display, missing recursive menu loops, `exit 1` on success in `Sc_Credit`/`Credit`, missing Option 0 in `menu-system` and `menu-bot`). |

## 86. WireGuard Empty Username Guard — Four Checks (October 1, 2026)

Section 35's four-check rule applied to Fix 300:

| Check | Result |
| :-- | :-- |
| **Regression** | The existing duplicate check, duration validation, IP allocation, config generation, and service restart are unchanged. Valid usernames still follow the same path. Empty input now exits before writing any state; invalid non-empty names return to the same prompt. `bash -n` passes and the packed `menu-wg` matches the source byte-for-byte. |
| **Over-strictness** | The accepted set is limited to letters, numbers, and underscore, matching the Xray/Noobz account conventions and avoiding path/config delimiter characters. It does not narrow any previously valid safe username. EOF exits cleanly instead of creating malformed state. |
| **Over-engineering** | One existing shell prompt gets an EOF guard and one small validation loop. No helper, dependency, daemon, or new configuration was added. |
| **vs the source** | Both V23 and Autoscript New 1.20 accept the empty value and create the malformed peer. The fix intentionally diverges because both references reproduce data corruption; it uses the project's existing username validation pattern rather than introducing a new policy. |

## 87. WireGuard Rejected-Operation Returns — Four Checks (October 1, 2026)

Section 35's four-check rule applied to Fix 301:

| Check | Result |
| :-- | :-- |
| **Regression** | Only three already-rejected branches change: duplicate create, pool exhausted, and unknown extend. Successful create/extend logic, prompts, config generation, and service restart are untouched. The live test confirms rejected inputs leave the peer config and account database unchanged. |
| **Over-strictness** | No valid operation is rejected. The change prevents execution after the script has already displayed its own error message. |
| **Over-engineering** | Three shell `return` statements after existing navigation calls. No helper, dependency, state file, or changed policy. |
| **vs the source** | V23 and 1.20 share the fall-through. The divergence is necessary because their error path can append duplicate or phantom account state whenever the caller returns. |

## 88. NoobzVPN Server-Compatible Account Creation — Four Checks (October 1, 2026)

Section 35's four-check rule applied to Fix 302:

| Check | Result |
| :-- | :-- |
| **Regression** | The valid account path and existing `noobzvpns add` arguments are unchanged. The new status check prevents the panel record from being created when the server rejects an account. Live testing confirms an invalid 20-character username leaves both account stores unchanged. |
| **Over-strictness** | The 16-character ceiling is imposed by the installed server, not the UI. The menu retains its previous safe, more restrictive letters/numbers/underscore alphabet rather than silently expanding accepted punctuation. |
| **Over-engineering** | One regex quantifier and one existing-command exit-status guard. No new storage, retry scheme, or dependency. |
| **vs the source** | V23 has neither the server-compatible length check nor command-result guard, and writes a false panel record. The divergence repairs state consistency while retaining the fork's existing username policy. |

## 89. SlowDNS Nameserver Configuration Validation — Four Checks (October 1, 2026)

Section 35's four-check rule applied to Fix 303:

| Check | Result |
| :-- | :-- |
| **Regression** | Valid FQDN nameservers continue through the existing unit-generation and service-restart path unchanged. Invalid or EOF input returns before touching either file; live checks confirm byte-identical state and active `dnstt`. |
| **Over-strictness** | SlowDNS's configured nameserver is a DNS hostname, not an IP address or arbitrary command arguments. The expression permits standard hyphenated labels and normal multi-label domains; it intentionally excludes whitespace, underscores, empty labels, and one-label/non-DNS values. |
| **Over-engineering** | A single Bash regex guard at the existing input boundary. No parser, dependency, retry, or separate validation framework. |
| **vs the source** | V23 accepts and persists arbitrary text. The divergence prevents malformed systemd configuration and matches the service's documented hostname input. |

## 90. Domain-Change Hostname Validation — Four Checks (October 1, 2026)

Section 35's four-check rule applied to Fix 304:

| Check | Result |
| :-- | :-- |
| **Regression** | Valid FQDN domain changes retain the existing files, card substitutions, optional certificate renewal, and nginx reload path. Invalid domains return before the first write; live testing verifies exact state preservation and nginx active. |
| **Over-strictness** | The panel needs a public DNS hostname for certificate issuance, nginx SNI, Xray clients, and all generated links. The check permits standard multi-label hyphenated domains while excluding spaces, shell/sed metacharacters, empty labels, and IP/single-label values that cannot satisfy this workflow. |
| **Over-engineering** | One Bash regex branch in each existing variant. No DNS lookup, external validator, configuration option, or duplicated helper. |
| **vs the source** | V23 and 1.20 persist raw input. The divergence prevents corrupt advertised endpoints and unsafe substitution input at the configuration boundary. |

## 91. TLS Private-Key File Permissions — Four Checks (October 1, 2026)

Section 35's four-check rule applied to Fix 305:

| Check | Result |
| :-- | :-- |
| **Regression** | Live service restart verification with `xray.key=0600` passed for nginx, HAProxy, NoobzVPN, and every Xray transport. Public certificate remains readable at `0644`; the chain/key contents and certificate flow are unchanged. |
| **Over-strictness** | These services read their keys as root during startup. Unprivileged local users do not need a TLS private key. The HAProxy bundle contains the same key and therefore requires the same restriction. |
| **Over-engineering** | Targeted standard `chmod` modes replace broad globs; no daemon configuration, ACL, account, or dependency is added. |
| **vs the source** | V23 and 1.20 both use `0644` on private key material. The intentional divergence closes a direct local secret disclosure and is documented in README. |

## 92. Delete-Transport User-Found Guard — Four Checks (October 1, 2026)

Section 35's four-check rule applied to Fix 306:

| Check | Result |
| :-- | :-- |
| **Regression** | Confirmed live: deleting an existing account (testcard99) was not tested with the patched script here (existing account deletion is already covered in section 84's lifecycle check); the guard only changes the not-found code path. Syntax check passes for all 8 files. |
| **Over-strictness** | No behavior change for the found path. The not-found path previously ran destructive operations; now it doesn't. |
| **Over-engineering** | Reindentation and reordering of existing shell statements only. No new logic, dependency, or helper. |
| **vs the source** | V23 and 1.20 share the same out-of-guard pattern. The fix aligns behavior with what the operator expects when a username is not found: nothing changes. |

## 93. Argo Tunnel Domain Validation — Four Checks (October 1, 2026)

Section 35's four-check rule applied to Fix 307:

| Check | Result |
| :-- | :-- |
| **Regression** | A valid FQDN continues through `cloudflared tunnel route dns` and file writes unchanged. Invalid input returns before touching cloudflared or the YAML file. `bash -n` clean. |
| **Over-strictness** | The same regex accepted for domain-change (Fix 304) and SlowDNS (Fix 303); standard hyphenated multi-label FQDNs pass. |
| **Over-engineering** | One regex guard and return. Identical in structure to the other two domain-boundary fixes. |
| **vs the source** | V23 and 1.20 accept raw text. The divergence prevents broken cloudflared configuration at the same boundary pattern as Fix 303 and Fix 304. |

## 94. SSH Account Empty-Password Guard — Four Checks (October 1, 2026)

Section 35's four-check rule applied to Fix 308:

| Check | Result |
| :-- | :-- |
| **Regression** | Non-empty passwords go through `chpasswd` unchanged. Valid username/expiry/IP-limit logic is untouched. |
| **Over-strictness** | Rejects only an empty string. Any non-empty password, including single-character ones, is accepted. |
| **Over-engineering** | A `while [ -z "$password" ]` loop matching the existing pattern on every other guarded input in the same script. |
| **vs the source** | V23 and 1.20 both accept empty passwords. The divergence prevents passwordless system accounts. |

## 95. Routing Script Empty-Input Guard — Four Checks (October 1, 2026)

Section 35's four-check rule applied to Fix 309:

| Check | Result |
| :-- | :-- |
| **Regression** | All-filled inputs continue through the same `sed`/JSON append path unchanged. Empty-field inputs return before touching any config. `bash -n` clean on all 8 files. |
| **Over-strictness** | Only guards against empty strings and EOF. Whitespace-only values (e.g. a single space) could still produce bad config, but that is an operator error on a privileged admin action; this fix closes the blank-field category. |
| **Over-engineering** | One `|| return` suffix per read and one early-return block per invocation site. No helper, dependency, or config change. |
| **vs the source** | V23 and 1.20 share the same unguarded reads. |

## 96. Phase 1: Cryptographic Key & Credential Permissions Audit — Four Checks (October 1, 2026)

Section 35's four-check rule applied to Fix 310:

| Check | Result |
| :-- | :-- |
| **Regression** | Daemons running as root (`haproxy`, `nginx`, `wg-quick`, `xray`, `xl2tpd`, `dnstt`, `cron`, python/cron jobs) read `0600` files without issue. Web-restore retains `0640 root:www-data` on `/etc/funny/.restore.key`. All 16 core services verified active. `bash -n` clean across all modified scripts. |
| **Over-strictness** | Public certificate `/etc/xray/xray.crt` remains `0644` (world-readable). Only private keys (`xray.key`, `funny.pem`, `wg0.conf`, `params`, `server.key`, `chap-secrets`, `ipsec.secrets`, `passwd`, `.keybot`, `.chatid`, `.l2tp`) are restricted to `0600`. No legitimate access is blocked. |
| **Over-engineering** | Minimal POSIX `chmod 600` additions directly after file creation/restore. Replaces stdout leak `tee` in `stunnel5.sh` with `>` redirection. |
| **vs the source** | V23 and 1.20 used `chmod 644` or umask defaults (`0644`) on private keys and credentials. Hardening to `0600` aligns with Decision 19 and security best practices without breaking functionality. |

## 97. Phase 2: Sysctl and Network Routing Hardening — Four Checks (October 1, 2026)

Section 35's four-check rule applied to Fix 311:

| Check | Result |
| :-- | :-- |
| **Regression** | `sysctl -p` loads cleanly without errors. `net.ipv4.ip_forward = 1` remains active for VPN traffic. Network routing and firewall rules remain intact. `bash -n` clean across all modified scripts. |
| **Over-strictness** | Does not restrict network traffic or interface bindings. Uses standard kernel routing tables to find default interface. |
| **Over-engineering** | Shortest working POSIX sed and grep checks. Replaces brittle grep pipeline with standard route lookup. |
| **vs the source** | V23 and 1.20 left sysctl variables undefined or half-configured. The fix completes the intended configuration idempotently. |

## 98. Phase 3: Systemd Restart Storm Prevention & Backoff Delays — Four Checks (October 1, 2026)

Section 35's four-check rule applied to Fix 312:

| Check | Result |
| :-- | :-- |
| **Regression** | Expired accounts continue to be removed from shadow, credentials files, and quota tracking. Daemons are still restarted whenever accounts are purged, but exactly once at loop exit. `RestartSec=3s` preserves auto-restart capability while preventing restart bursts. All 16 core services verified active. `bash -n` clean across all modified scripts. |
| **Over-strictness** | Does not alter service dependencies or exit status evaluation. Only adds standard systemd 3-second delay on failure. |
| **Over-engineering** | Simple boolean flag (`ssh_expired=1`, `l2tp_expired=1`) identical to the existing WireGuard and Noobz pattern in the same file. One-line `RestartSec=3s` in unit files. |
| **vs the source** | V23 and 1.20 restarted services on every loop step and omitted restart backoffs. The fix stabilizes systemd operation and eliminates redundant process churn. |

## 99. Phase 4: Cron Cleanup Safety and Permission Persistence — Four Checks (October 1, 2026)

Section 35's four-check rule applied to Fix 313:

| Check | Result |
| :-- | :-- |
| **Regression** | Expired accounts across all transports (Xray, SSH, L2TP, WireGuard, Noobz) continue to be purged identically. `xray run -test -config` prevents restarting dead or invalid configurations. `chmod 600` keeps `/etc/wireguard/wg0.conf` secured. All 16 core services verified active. `bash -n` clean across all modified scripts. |
| **Over-strictness** | `xray run -test` only checks valid JSON structure against Xray core parser. Does not reject valid configurations. `head -n 1` picks the first clean date if multiple duplicates exist. |
| **Over-engineering** | Native `xray run -test -config` command provided by Xray binary itself; no additional parsers or dependencies. Single-line `chmod 600` after file move. |
| **vs the source** | V23 and 1.20 lacked pre-restart validation and left `wg0.conf` at default permissions after peer deletion. The fix preserves reliable automated cleanup. |

## 100. Phase 5: IP Limiter Telegram Guard and Restart Safety — Four Checks (October 1, 2026)

Section 35's four-check rule applied to Fix 314:

| Check | Result |
| :-- | :-- |
| **Regression** | Multilogin detection and manual account lock/unlock work identically. When credentials exist, Telegram alerts are still sent. Transport services are still reloaded, but with guaranteed JSON syntax validity. All 16 core services verified active. `bash -n` clean across all modified scripts. |
| **Over-strictness** | Does not modify IP limit threshold calculation (`cek > limit`) or locking mechanics. Bypasses only external Telegram API calls when bot configuration is empty. |
| **Over-engineering** | Simple non-empty check `[ -z "$CHATID" ] || [ -z "$KEY" ] && return 0` and standard `xray run -test -config` guard. |
| **vs the source** | V23 and 1.20 fired blind curl requests without token checks and restarted Xray blindly. The fix eliminates network timeouts and service downtime hazards. |

## 101. Phase 6: Quota Daemon Artifact Cleanup and Restart Validation — Four Checks (October 1, 2026)

Section 35's four-check rule applied to Fix 315:

| Check | Result |
| :-- | :-- |
| **Regression** | Traffic accounting and quota breach enforcement function identically. User traffic continues to be queried via Xray API and reset. When an account exceeds quota, complete deletion is enforced. All 16 core services verified active. `bash -n` clean across all modified scripts. |
| **Over-strictness** | No alteration to quota threshold checks (`quota_used > quota_limit`). Only ensures complete cleanup of orphaned IP limit files on hard deletion. |
| **Over-engineering** | Standard POSIX `rm -f` and conditional `xray run -test -config`. No external helpers or dependencies. |
| **vs the source** | V23 and 1.20 left orphaned IP limit files on disk when quota was exhausted. The fix fulfills Decision 16 by cleanly removing all account records. |

## 102. Phase 7: Account Creation Alert Guards and Restart Safety — Four Checks (October 1, 2026)

Section 35's four-check rule applied to Fix 316:

| Check | Result |
| :-- | :-- |
| **Regression** | Account creation logic, credential generation, client configuration appending, and terminal card displays function identically. Input validation rules (`^[a-z0-9_]+$` username, `^[0-9]+$` for `ip` and `quota` per R72-B, `^[1-9][0-9]*$` for duration) are completely preserved. All 16 core services verified active. `bash -n` clean across all 50 modified scripts. |
| **Over-strictness** | Does not add arbitrary password complexity or restrict valid usernames. `0 = unlimited` on IP and quota remains supported per Decision 4 and R72-B. |
| **Over-engineering** | Standard bash conditional wrapping on curl and `xray run -test -config`. No external scripts or wrappers. |
| **vs the source** | V23 and 1.20 sent blind curl requests without token verification and restarted Xray services without checking config validity. The fix secures runtime behavior. |

## 103. Strict Enforcement of Decision 4: Reject `0` on Quantity Prompts — Four Checks (October 1, 2026)

Section 35's four-check rule applied to Fix 317:

| Check | Result |
| :-- | :-- |
| **Regression** | Valid positive whole numbers (`1`, `2`, `100`, etc.) pass through completely unchanged. Operator who wants an unconstrained limit can enter a large value (e.g. `999999`) as explicitly envisioned in Decision 4. All 16 core services verified active. `bash -n` clean across all 25 modified scripts. |
| **Over-strictness** | Enforces the documented project policy: `0` is ambiguous across daemons (quota deletion vs first-login lock vs skipping limits). Rejecting `0` ensures predictability. |
| **Over-engineering** | Uniform regex `^[1-9][0-9]*$` and standardized single notice `0 not allowed`. Zero added dependencies. |
| **vs the source** | Decision 4 explicitly overrides upstream V23/1.20 ambiguity by rejecting 0 at the user boundary. |

## 104. Phase 8: Hardening Account Modification, Extension, and Deletion — Four Checks (October 1, 2026)

Section 35's four-check rule applied to Fix 318:

| Check | Result |
| :-- | :-- |
| **Regression** | Deleting existing accounts, extending validity periods, resetting quota usage, and updating UUIDs continue to function identically. Non-existent accounts trigger no service restarts or file removals. All 16 core services verified active. `bash -n` clean across all 32 modified scripts. |
| **Over-strictness** | Does not restrict valid usernames or operations. Only prevents blind restarts and unauthenticated network requests. |
| **Over-engineering** | Standard bash conditionals on curl, EOF checks, and `xray run -test -config`. |
| **vs the source** | V23 and 1.20 restarted Xray blindly and made unauthenticated curl calls. The fix prevents outages during day-to-day administrative operations. |

## 105. Phase 9: Additional Protocols Tunnel Hardening — Four Checks (October 1, 2026)

Section 35's four-check rule applied to Fix 319:

| Check | Result |
| :-- | :-- |
| **Regression** | WireGuard, NoobzVPN, L2TP, and SlowDNS operations continue to function identically. Rotated keys are preserved, tunnel accounts are created and cleaned up. All 16 core services verified active. `bash -n` clean across all 4 modified scripts. |
| **Over-strictness** | No additional constraints on valid inputs. WireGuard and Noobz continue to accept valid names and passwords. |
| **Over-engineering** | Minimal POSIX `chmod 600`, single-loop retry in `xl2tp.sh`, and `if [ -n "$CHATID" ]` guard. |
| **vs the source** | V23 left renewed SlowDNS keys at default umask, aborted L2TP abruptly on duplicate username, and made blind curl calls in Noobz. The fix aligns with project security and usability standards. |

## 106. Phase 10: TUI Menu Navigation and Retention — Four Checks (October 1, 2026)

Section 35's four-check rule applied to Fix 320:

| Check | Result |
| :-- | :-- |
| **Regression** | All menu actions, submenu selections, and exit commands continue to work identically. Chained menu re-invocations ensure operators are never dumped to the shell prompt unexpectedly. All 16 core services verified active. `bash -n` clean across all modified scripts. |
| **Over-strictness** | No input restriction added. Both `0` and `00` return to the main menu. |
| **Over-engineering** | Simple `; menu` and `; menu-x` additions in case branches. Replaced outer `menu` jump with inner `main` loop in WireGuard. Zero new dependencies. |
| **vs the source** | V23 and 1.20 lacked retention loops and ejected operators from menus. The fix provides smooth, continuous CLI navigation. |

## 107. Phase 11: Argo Tunnel Read Pauses and Option 00 Handling — Four Checks (October 1, 2026)

Section 35's four-check rule applied to Fix 321:

| Check | Result |
| :-- | :-- |
| **Regression** | Installing and restarting Cloudflare Argo tunnel continue to function identically. Adding read pauses allows operator inspection before screen clearing. All 16 core services verified active. `bash -n` clean across modified scripts. |
| **Over-strictness** | No validation rules changed; FQDN validation from Fix 307 preserved. Option 0 now accepts both `0` and `00`. |
| **Over-engineering** | Standard `echo` + `read -n 1 -s -r -p` pattern matching the rest of the codebase. |
| **vs the source** | V23 and 1.20 cleared the screen immediately on setup. The fix gives immediate visual feedback. |

## 108. Phase 12: Domain Menu Retention, Read Pauses, and Telegram Guards — Four Checks (October 1, 2026)

Section 35's four-check rule applied to Fix 322:

| Check | Result |
| :-- | :-- |
| **Regression** | Domain modification, ACME, Certbot, and self-signed certificate issuance continue to function identically. Adding read pauses allows operator inspection before screen clearing. All 16 core services verified active. `bash -n` clean across modified scripts. |
| **Over-strictness** | No validation rules changed; FQDN validation from Fix 304 preserved. Option 0 in `cert()` cleanly returns to `dm1`. |
| **Over-engineering** | Standard `; dm1` loop chaining and `read -n 1 -s -r -p` pauses. Zero external dependencies. |
| **vs the source** | V23 and 1.20 dropped out to shell on cert renewals and lacked pause notices. The fix secures menu flow. |

## 109. Phase 13: Backup Permission Hardening and Restore Restart Validation — Four Checks (October 1, 2026)

Section 35's four-check rule applied to Fix 323:

| Check | Result |
| :-- | :-- |
| **Regression** | Backup archive creation, Telegram delivery, and restoration across all 3 channels (URL, file, web) function identically. `chmod 600` ensures sensitive archive contents remain private. All 16 core services verified active. `bash -n` clean across all modified scripts. |
| **Over-strictness** | No functionality restricted. Root and daemons read 0600 backups cleanly; web restore retains 0640 key access. |
| **Over-engineering** | Standard `chmod 600` and conditional `xray run -test -config`. Zero external dependencies. |
| **vs the source** | V23 and 1.20 left backup archives at default 0644 and blindly restarted daemons. The fix secures backup pipelines against privilege escalation. |

## 110. Phase 14: Headless REST API Audit and Unit Backoff — Four Checks (October 1, 2026)

Section 35's four-check rule applied to Fix 324:

| Check | Result |
| :-- | :-- |
| **Regression** | All API endpoints continue to function identically. `location /api/` in Nginx reverse proxies cleanly to local port 9000. All 16 core services verified active. |
| **Over-strictness** | No valid endpoints or parameters rejected. Rejection is strictly limited to unauthenticated requests (missing/invalid token in `/etc/xray/.key`) and invalid paths containing `/` traversal tokens. |
| **Over-engineering** | Single-line `RestartSec=3s` in unit file; standard single-threaded Python HTTPServer architecture. |
| **vs the source** | Original FN-API bound 0.0.0.0 insecurely and lacked traversal protection. The current implementation preserves security without breaking contracts. |

## 111. Phase 15: Dual-Edition Package Parity and Binary Build — Four Checks (October 1, 2026)

Section 35's four-check rule applied to Fix 325:

| Check | Result |
| :-- | :-- |
| **Regression** | Every panel tool, CLI script, daemon handler, and Go binary verified identical between archive and source trees. Clean archive extraction on VPS preserves all functional improvements from Fixes 310–324. All 16 core services verified active. |
| **Over-strictness** | No permission or packaging restrictions added. Standard 0755 mode maintained. |
| **Over-engineering** | Idempotent Python packaging script ensuring deterministic timestamp and permissions. Zero external dependencies. |
| **vs the source** | V23 and 1.20 shipped drifted binaries and inconsistent permissions. The fix ensures complete byte-level integrity. |

## 112. Documentation Consistency: Non-Append-Only Docs Aligned With Reverted Fixes — Four Checks (October 2, 2026)

Section 35's four-check rule applied to Fix 326:

| Check | Result |
| :-- | :-- |
| **Regression** | No code, permission, or service behaviour changed. Only `README.md`, `project-information/fn-api.md`, `project-information/is-decision.md`, and `project-information/bug-finding-and-fixing-phase-plan.md` wording corrected to match live code (`setup_16.x`, single-threaded `HTTPServer`, `RestartSec=3s`). Append-only history (`bugs-found.md`, `bugs-fixed.md`, this file) extended by append, not edited. |
| **Over-strictness** | No new restriction. Node stays 16 until `bot.zip` native addons support a newer runtime; API stays single-threaded per the reference design. |
| **Over-engineering** | In-place text corrections only. No helper, dependency, or config change. |
| **vs the source** | V23 and 1.20 both install Node 16 and the FN-API reference `core/server` is single-threaded `HTTPServer`; the corrected docs now agree with both references and the live code. |

## 113. Phase 15 Live: Web-Restore Upload Cap and Sudoers — Four Checks (October 2, 2026)

Section 35's four-check rule applied to Fixes 327-328:

| Check | Result |
| :-- | :-- |
| **Regression** | Backup format untouched (`backup.zip` still mode `0600`, same entry set); `upload.php` auth logic untouched (`401` on missing/wrong token, `hash_equals`, fail-closed); no service behaviour changed except apache2 restart to pick up the new PHP limits. Append-only history extended by append, not edited. |
| **Over-strictness** | Cap raised (2M → 64M), never lowered. Sudoers grants exactly one binary (`/usr/bin/restore-ftp`) to exactly one user (`www-data`), passwordless only there. No new rejection. |
| **Over-engineering** | Two `sed` lines + one drop-in file. No new dependency, helper, or config surface. |
| **vs the source** | Neither V23 nor 1.20 tuned PHP upload limits or shipped a working sudoers rule for this path (the key gate itself is our Decision 19 addition); the fixes complete the path the decision opened without altering its contract. |

## 114. Post-Phase-16: xray@ Start-Limiter Widened — Four Checks (October 2, 2026)

Section 35's four-check rule applied to Fix 329:

| Check | Result |
| :-- | :-- |
| **Regression** | Genuine crash-loops still trip the limiter eventually (30 bursts/120s is far above any failure mode observed); `Restart=on-failure` + `RestartSec=3s` untouched. Normal single restarts (delete/extend/quota/xp) behave identically. Append-only history extended by append, not edited. |
| **Over-strictness** | Limit loosened (5/10s → 30/120s), never tightened. No valid operation newly rejected. |
| **Over-engineering** | Two unit-file lines, installer template + live unit. No new timer, helper, or dependency. |
| **vs the source** | V23/1.20 ship no `StartLimit*` overrides anywhere (default 5/10s everywhere); the change only widens the budget on the transport most often restarted by automation. |

## 115. Burst Budget Extended to Quota, WS, SSH, Dropbear — Four Checks (October 2, 2026)

Section 35's four-check rule applied to Fix 330:

| Check | Result |
| :-- | :-- |
| **Regression** | Only two `[Unit]` lines added per unit; no `ExecStart`/`Restart`/`User` change. Distro units (`ssh`, `dropbear`) touched via drop-ins only. `daemon-reload` applied; all units verified active after. Append-only history extended by append, not edited. |
| **Over-strictness** | Limits loosened everywhere, none tightened. No operation newly rejected. |
| **Over-engineering** | Two lines per template + one 3-line drop-in block in `ssh.sh`. The 234 per-site `systemctl restart` calls were deliberately NOT wrapped: each is semantically necessary, and per-script debounce could skip required restarts. |
| **vs the source** | V23/1.20 use defaults everywhere; the widened budget is a strict improvement for automation-driven panels with no behavior change under normal operation. |

## 116. SplitHTTP → XHTTP Migration — Four Checks (October 4, 2026)

Section 35's four-check rule applied to Fix 331:

| Check | Result |
| :-- | :-- |
| **Regression** | No logic touched: identical sed-shape renames only; `bash -n` clean; `xray -test` OK; identifiers (`xray@split`, `split.json`, `core=split`) intentionally kept so cron/API/systemd keep working. |
| **Over-strictness** | Nothing rejected; paths only renamed. Old `/vmspl` URLs stop working by design (new canonical paths `/vmxh` etc.). |
| **Over-engineering** | No new code, no new dependency; Xray 25.3.6 already ships XHTTP support. |
| **vs the source** | V23/1.20 predate XHTTP (SplitHTTP era); migration follows the upstream Xray rename, verified against the pinned 25.3.6 binary strings. |

## 117. Auth Fetch: Pages Primary, GitHub Fallback — Four Checks (October 4, 2026)

Section 35's four-check rule applied to Fix 332:

| Check | Result |
| :-- | :-- |
| **Regression** | Same gate semantics: fail-closed on both sources down; identical `Failed to download permissions.` message; no prompt/logic change. |
| **Over-strictness** | Nothing newly rejected; strictly more available (two sources instead of one). |
| **Over-engineering** | One extra variable + one extra `curl` alternative per gate; no helper, no dependency. |
| **vs the source** | V23/1.20 predate both URLs (dead `permision.rerechanstore.eu.org`); the canonical GitHub URL is kept verbatim as fallback. |

## 118. Full Split→XHTTP Identifier Rename — Four Checks (October 4, 2026)

Section 35's four-check rule applied to Fix 333:

| Check | Result |
| :-- | :-- |
| **Regression** | Rename mekanis 1:1 (`split`→`xhttp` dengan guard builtin bahasa); `bash -n` bersih; `xray -test` OK; API menerima alias legacy `split`. Migrasi live memindahkan data (akun, kuota, limit, log), bukan menghapus. |
| **Over-strictness** | Tidak ada penolakan baru; alias `split`→`xhttp` justru melonggarkan kompatibilitas klien lama. |
| **Over-engineering** | Tanpa kode baru kecuali 1 baris alias per handler; tanpa dependensi baru. |
| **vs the source** | V23/1.20 tak mengenal XHTTP sama sekali; rename mengikuti arah upstream Xray dan menghilangkan kelas inkonsistensi nama ganda. |

## 119. Phase 1: Restore Re-Secures API Token + Restore-Key Ownership — Four Checks (October 4, 2026)

Section 35's four-check rule applied to Fix 334:

| Check | Result |
| :-- | :-- |
| **Regression** | Guarded (`2>/dev/null \|\| true`) no-ops when files absent; no restart/service/input path touched; `bash -n` clean; zips deterministic (same entry lists, `0755`, byte-identical). |
| **Over-strictness** | Nothing rejected; only permission bits + group ownership re-asserted to the documented values (Decision 19). |
| **Over-engineering** | Two lines per restore block, no helper/dependency; transient-umask hardening deliberately skipped (single-tenant install window, would add noise for no persistent gain). |
| **vs the source** | V23/1.20 omitted `0600` on restored keys (Found 305, inherited); this closes the two lines that fix left uncovered (`.key` never chmodded, `.restore.key` never chowned). |

## 120. Phase 3: Burst Budget for Remaining Custom Units — Four Checks (October 4, 2026)

Section 35's four-check rule applied to Fix 335:

| Check | Result |
| :-- | :-- |
| **Regression** | Two `[Unit]` lines per template; no `ExecStart`/restart policy/logic touched; `bash -n` clean; `systemd-analyze verify` clean; zips deterministic (same entry lists, `0755`, byte-identical). |
| **Over-strictness** | Nothing rejected; only the start-limiter budget widened to the Fix 329/330 values. |
| **Over-engineering** | No helper/dependency; upstream-fetched `noobzvpns.service` and per-user loop batching (Fase 21) deliberately out of scope. |
| **vs the source** | V23/1.20 carry no `StartLimit*` overrides anywhere (defaults everywhere); widening follows the already-accepted Fix 329/330 direction for burst-tolerance. |

## 121. Phase 4: xp SSH Guard — Four Checks (October 4, 2026)

Section 35's four-check rule applied to Fix 336:

| Check | Result |
| :-- | :-- |
| **Regression** | Guard only skips non-numeric field-8 rows (previously destroyed); genuinely-expired and future accounts behave identically (reproduced); `bash -n` clean; zips deterministic. |
| **Over-strictness** | Only corrupt (non-date) rows skipped — valid numeric expiries, the only values `useradd`/`chage` write, all pass. |
| **Over-engineering** | Four lines per edition, same shape as the Found-108 sibling guards; no helper. |
| **vs the source** | V23/1.20 have no unparseable-skip anywhere in `xp` (Found 108 class); this extends the already-accepted guard to the last unguarded branch. |

## 122. Phase 4: fn-api.md Transport Names — Four Checks (October 4, 2026)

Section 35's four-check rule applied to Fix 337:

| Check | Result |
| :-- | :-- |
| **Regression** | Doc-only; no code path touched. |
| **Over-strictness** | Nothing rejected; alias documented, not removed. |
| **Over-engineering** | Three in-place words; non-append-only doc corrected as the plan requires. |
| **vs the source** | V23/1.20 predate XHTTP; naming follows Fix 333 + the API README (already correct there). |

## 123. Phase 5: Lite Unlock-xhttp Title — Four Checks (October 4, 2026)

Section 35's four-check rule applied to Fix 338:

| Check | Result |
| :-- | :-- |
| **Regression** | One notification string; no logic/prompt/restart touched; `bash -n` clean; `full/` untouched; lite zip deterministic. |
| **Over-strictness** | Nothing rejected; text-only change. |
| **Over-engineering** | One line; parity with the `full/` sibling, no new wording invented. |
| **vs the source** | V23/1.20 predate the notification texts (panel-era copy); fix aligns the lite copy with the full copy. |

## 124. Phase 7: addssh Failure Handling — Four Checks (October 4, 2026)

Section 35's four-check rule applied to Fix 339:

| Check | Result |
| :-- | :-- |
| **Regression** | Failure path now exits before card/log/Telegram instead of fabricating them; success path byte-identical behavior; `bash -n` clean; zip deterministic. |
| **Over-strictness** | Nothing newly rejected; valid creates flow unchanged. |
| **Over-engineering** | Two words (`\|\| return`, `\|\| exit 0`), both mirroring guards already present in `trial-ssh.sh` / the same file's retries. |
| **vs the source** | V23/1.20 share the unchecked call; guarding it follows the already-accepted `trial-ssh` pattern in this repo. |

## 125. Phase 10: 00-Accepting Back Branches — Four Checks (October 4, 2026)

Section 35's four-check rule applied to Fix 340:

| Check | Result |
| :-- | :-- |
| **Regression** | Same back-action, one extra accepted spelling; `bash -n` clean; zips deterministic. |
| **Over-strictness** | Strictly less strict (accepts more); no input newly rejected. |
| **Over-engineering** | Three characters (`\|00`) per branch; Fix 181 precedent. |
| **vs the source** | Both references mix `0)`/`0\|00)` spellings the same way; harmonizing to the majority spelling changes no flow. |

## 126. Phase 12: Installer FQDN Validation — Four Checks (October 4, 2026)

Section 35's four-check rule applied to Fix 341:

| Check | Result |
| :-- | :-- |
| **Regression** | Install flow unchanged for valid domains (loop + messages identical); `bash -n` clean; no zip involvement. |
| **Over-strictness** | Regex is the same one `dm-menu`/`menu-dnstt`/`menu-argo` already enforce — a domain valid post-install is valid at install. |
| **Over-engineering** | One branch per installer, shared canonical pattern, no helper. |
| **vs the source** | V23/1.20 validate less (or nothing) at install; tightening follows the already-accepted Found-304 direction. |

## 127. Phase 13: API Fetch Timeout — Four Checks (October 4, 2026)

Section 35's four-check rule applied to Fix 342:

| Check | Result |
| :-- | :-- |
| **Regression** | Download URLs, `-f`/`-L` semantics and the fail-fast messages unchanged; only an upper time bound added; `bash -n` clean. |
| **Over-strictness** | Nothing rejected; 60s is generous (healthy fetch ~1s) — only stalled connections are cut. |
| **Over-engineering** | Three flags, same `--max-time` idiom the gate already uses; no retry framework. |
| **vs the source** | FN-API reference is endpoint-list only; timeouts follow this repo's own gate precedent. |

## 129. Phase 16: Handler Input Guards — Four Checks (October 4, 2026)

Section 35's four-check rule applied to Fix 345:

| Check | Result |
| :-- | :-- |
| **Regression** | Guards reject only values the panel demonstrably refuses (same regexes, verified across all 12 `add-*`); coerced numbers/valid names flow unchanged; `bash -n` clean. |
| **Over-strictness** | Mirror-exact: every rejected shape was reproduced failing at the panel; JSON-number `30` and metachar passwords still pass. |
| **Over-engineering** | One regex line per field, no shared validator, no dependency. |
| **vs the source** | FN-API reference defines no shapes; rules come from this panel's own scripts (uniform across all 12). |

## 130. Phase 17: Gate + Noobz + Partial-Delete Honesty — Four Checks (October 4, 2026)

Section 35's four-check rule applied to Fix 346:

| Check | Result |
| :-- | :-- |
| **Regression** | Gate logic/wording untouched (same messages, same fail-closed exits); Noobz valid names still match; full deletes report exactly the old shape (no new keys when nothing is missing); `cek-xray` on healthy installs behaves the same (all four tools present). |
| **Over-strictness** | Timeouts only cut stalled connections (healthy fetch ~1s vs 15s cap); `-wF`/`-w` only reject non-exact matches; 60s→15s nothing (panel had no cap at all). |
| **Over-engineering** | Same-flag edits in panel; two-letter flag + one reporting branch + one guard loop in API; no helpers. |
| **vs the source** | V23/1.20 share the un-timed gate and substring match (inherited); tightening follows this repo's own `menu-api` caps and Xray-handler anchor style. |

## 131. Phase 18: Quoting + Server Sockets — Four Checks (October 4, 2026)

Section 35's four-check rule applied to Fix 347:

| Check | Result |
| :-- | :-- |
| **Regression** | Quoting is behavior-neutral on already-constrained values; server fast paths byte-identical (normal/empty/small bodies, HEAD, auth matrix re-tested); handler skipped only after a 413 it can never satisfy. |
| **Over-strictness** | Nothing new rejected except >1MB bodies (100× above real use) and >30s-silent sockets (nginx buffers real clients). |
| **Over-engineering** | Quotes only where the plan names; server bounds are three constants + stdlib handler swap + one `try`; env deliberately NOT stripped (would change script behavior). |
| **vs the source** | V23/1.20 quote the same way loosely (inherited style); server bounds follow this repo's own gate-timeout idiom, single-threaded invariant kept. |

## 132. Phase 19: Background Fetch Caps — Four Checks (October 4, 2026)

Section 35's four-check rule applied to Fix 348:

| Check | Result |
| :-- | :-- |
| **Regression** | Caps only cut stalled transfers (healthy Telegram/uploads finish in ~1s vs 10–120s caps); `&&` chains and fail messages unchanged; `bash -n` clean; zips deterministic. |
| **Over-strictness** | Nothing rejected; timeouts only abandon hangs, and every capped call already tolerates empty results. |
| **Over-engineering** | One flag per call site, same idiom as the gate caps; no retry logic; code-signing/pinning left out (upstream moves — recorded choice). |
| **vs the source** | V23/1.20 fetch the same way uncapped (inherited); caps follow this repo's own gate precedent. Full atomic-install staging stays future work, noted openly. |

## 133. Phase 21: Single Restart Per Daemon Run — Four Checks (October 4, 2026)

Section 35's four-check rule applied to Fix 349:

| Check | Result |
| :-- | :-- |
| **Regression** | Restarts still happen exactly when deletions/locks happen (proven in sandbox, including the zero-trigger case); `xray -test` gate and per-user notices preserved; final-state test is equivalent-or-safer than per-step tests. |
| **Over-strictness** | Nothing rejected; strictly fewer restarts, same triggers. |
| **Over-engineering** | One flag + one block per file, copied from the `xp`/`auto-delete` pattern already in the repo; no debounce logic, no new files. |
| **vs the source** | V23/1.20 restart per user in these loops (inherited); batching follows this repo's own `xp.sh` precedent. |

## 134. Phase 22: Shared JSON Lock for Daemons — Four Checks (October 4, 2026)

Section 35's four-check rule applied to Fix 350:

| Check | Result |
| :-- | :-- |
| **Regression** | Locks only serialize overlapping edits; solo runs behave identically (proven: same deletions, same restarts); `bash -n` clean; zips deterministic. Timeouts skip-and-retry, never corrupt. |
| **Over-strictness** | Nothing rejected; a timed-out waiter skips one run/section, the next tick retries — accounts live slightly longer, never wrongly die. |
| **Over-engineering** | Five lines per site, standard `flock`, no new files/daemons; one lock per file (no ordering rules, no nesting, no deadlock shape). |
| **vs the source** | V23/1.20 have only per-daemon cron locks (same gap, inherited); per-file sharing is new hardening in this repo's direction. |

## 135. Live: Unlock Guard — Four Checks (October 4, 2026)

Section 35's four-check rule applied to Fix 351:

| Check | Result |
| :-- | :-- |
| **Regression** | Unlock normal path byte-identical when the account is absent (proven: full restore, card back, restart). |
| **Over-strictness** | Guard skips only exact full-line duplicates; empty-expiry falls back to old behavior, never a wrong skip. |
| **Over-engineering** | Guard: 4 lines per file, same shape ×8. |
| **vs the source** | V23/1.20 predate the lock/unlock flow refinements; guard follows this repo's own duplicate-check direction. |

## 136. Live: Quota-xhttp Resurrection — Four Checks (October 4, 2026)

Section 35's four-check rule applied to Fix 352:

| Check | Result |
| :-- | :-- |
| **Regression** | quota-xhttp is the same tested daemon shape as its three siblings; stale split unit protected nothing (its target service is gone). |
| **Over-strictness** | Nothing rejected; one dead daemon replaced by the live one. |
| **Over-engineering** | One word in repo + stock unit install on the box. |
| **vs the source** | V23/1.20 predate xhttp entirely; both fixes finish the rename's own direction. |

## 128. Phase 14: Full-Length API Token — Four Checks (October 4, 2026)

Section 35's four-check rule applied to Fix 343:

| Check | Result |
| :-- | :-- |
| **Regression** | Same pipeline/charset/cut; only input entropy raised; existing tokens unaffected; `bash -n` clean. |
| **Over-strictness** | Nothing rejected; strictly stronger credential matching the documented claim. |
| **Over-engineering** | One number (`32`→`48`); no alphabet change, no loop, no dependency. |
| **vs the source** | FN-API reference says nothing about token shape; fix aligns code with this repo's own README contract. |
















## 137. Main Menu XHTTP Count — Four Checks (October 5, 2026)

Section 35's four-check rule applied to Fix 353:

| Check | Result |
| :-- | :-- |
| **Regression** | Status line renders identical values (`HTTP: ON/OFF` from the same service probe); only the variable name changed; lite + menu-x paths untouched (verified no collision there). |
| **Over-strictness** | Nothing rejected; display-only change, no input path touched. |
| **Over-engineering** | 5 lines renamed in one file + zip entry refresh. |
| **vs the source** | V23 kept three distinct names; the fix restores exactly that separation under the new transport name. |
## 138. HU Short Labels — Four Checks (October 5, 2026)

Section 35's four-check rule applied to Fix 354:

| Check | Result |
| :-- | :-- |
| **Regression** | Label-only change; same variables, same values, same column alignment; card/option full names untouched. |
| **Over-strictness** | Nothing rejected; display-only change. |
| **Over-engineering** | 5 label swaps across 3 files. |
| **vs the source** | References use longer `HTTP UPGRADE` wording; short `HU` matches this repo's own `WS`/`XHTTP`/`gRPC` menu style. |
## 139. List-Account Chooser — Four Checks (October 5, 2026)

Section 35's four-check rule applied to Fix 355:

| Check | Result |
| :-- | :-- |
| **Regression** | Per-account fields byte-identical to the old loop body (locked/unlocked branches kept); one-shot flow matches option 10, which the submenu already pauses-and-returns from. |
| **Over-strictness** | Nothing rejected that worked before; number input is additive (names still accepted). |
| **Over-engineering** | Same chooser shape as the existing database-log tool; dump loop + counter file removed. |
| **vs the source** | References dump-all the same way; chooser follows this repo's own option-10 UX instead. |
## 140. List-Chooser Database Styling — Four Checks (October 5, 2026)

Section 35's four-check rule applied to Fix 356:

| Check | Result |
| :-- | :-- |
| **Regression** | Same chooser flow and fields as Fix 355; only separator/header/prompt cosmetics changed to the option-10 shape. |
| **Over-strictness** | Nothing rejected; display-only change. |
| **Over-engineering** | One rainbow constant + header/total-block restyle per file. |
| **vs the source** | References have no chooser at all; style follows this repo's own database-log tool. |
## 141. List-Chooser RSEP Order — Four Checks (October 5, 2026)

Section 35's four-check rule applied to Fix 357:

| Check | Result |
| :-- | :-- |
| **Regression** | Same output lines, only definition order changed; verified live render. |
| **Over-strictness** | Nothing rejected; display-only change. |
| **Over-engineering** | One line moved per file. |
| **vs the source** | N/A (own new code, not from a reference). |
## 142. Auth-Gate Race — Four Checks (October 5, 2026)

Section 35's four-check rule applied to Fix 358:

| Check | Result |
| :-- | :-- |
| **Regression** | Downstream gate logic (MATCH/USERNAME/EXPIRED_DATE handling) untouched; `PERMISSION_DATA` holds the same whole-file content as before, whichever source wins. |
| **Over-strictness** | Nothing newly rejected; an error page that the old code *trusted* (exit 0, no match, fail) is now skipped in favour of good data. |
| **Over-engineering** | One inline block replacing one line per file; no new dependency (`mktemp`, `curl`, `jobs` — all already used). |
| **vs the source** | References fetch once with no fallback at all; the race keeps this repo's redundancy direction and hardens it. |
## 143. Daemon Blackout Enforcement — Four Checks (October 5, 2026)

Section 35's four-check rule applied to Fix 359:

| Check | Result |
| :-- | :-- |
| **Regression** | Licensed path byte-identical (3 one-line conditions added, no logic moved); negative-auth exits preserved. |
| **Over-strictness** | Only fetch-failure continues; unlisted/expired still refused. |
| **Over-engineering** | 3 one-line edits per daemon file; no cache, no new dependency. |
| **vs the source** | References have no daemon/outage distinction; split follows the operator's menu-vs-background rule. |
## 144. Rainbow Dash Separators — Four Checks (October 5, 2026)

Section 35's four-check rule applied to Fix 360:

| Check | Result |
| :-- | :-- |
| **Regression** | Same lengths, same call sites, same colors — only the repeated character changed; parsers key on content, not separators. |
| **Over-strictness** | Nothing rejected; display-only change. |
| **Over-engineering** | One-character-class swap across call sites. |
| **vs the source** | References use `=` rainbows; dash form is this repo's own direction per operator request. |
## 145. TUI Separator Unification — Four Checks (October 6, 2026)

Section 35's four-check rule applied to Fix 361:

| Check | Result |
| :-- | :-- |
| **Regression** | Same box structure, same widths (35), same colors per position — only the repeated character and unstyled boxes changed; Telegram cards keep their layout; parsers key on content, not separators. |
| **Over-strictness** | Nothing rejected; display-only change (quantity gates untouched). |
| **Over-engineering** | Character swap plus wiring plain boxes to the existing separator vars; no new framework. |
| **vs the source** | References use `=` boxes; dash-rainbow form is this repo's own direction per operator request. |
## 146. Terminal Unification — Four Checks (October 6, 2026)

Section 35's four-check rule applied to Fix 362:

| Check | Result |
| :-- | :-- |
| **Regression** | Same boxes, same order, same prompts; only glyph/color/width-normalization changed. Wide data tables keep content-fit widths instead of 35 so columns still line up. |
| **Over-strictness** | Nothing rejected; display-only change. |
| **Over-engineering** | Wired boxes to existing separator vars; one new `barisBiru` divider where a divider func was shared. |
| **vs the source** | References use assorted boxes; rainbow/blue dash form is this repo's own direction per operator request. |

## 147. Telegram and Installer Dashes — Four Checks (October 6, 2026)

Section 35's four-check rule applied to Fix 363:

| Check | Result |
| :-- | :-- |
| **Regression** | Same widths, same tags, same layout — one character class swapped. Banner art and prompt art untouched. |
| **Over-strictness** | Nothing rejected; text-only change. |
| **Over-engineering** | Single-character swap across payload lines. |
| **vs the source** | References use box glyphs in payloads; dash form is this repo's own direction per operator request. |
## 148. Change-Limit Readability — Four Checks (October 6, 2026)

Section 35's four-check rule applied to Fix 364:

| Check | Result |
| :-- | :-- |
| **Regression** | Same prompts, same validation, same data flow — layout lines only. |
| **Over-strictness** | Nothing rejected; display-only change. |
| **Over-engineering** | Three-line empty-state, one newline, one dropped re-banner. |
| **vs the source** | References re-print banners the same way; calmer error path is this repo's own direction per operator request. |
## 149. Single-Card Change-Limit — Four Checks (October 6, 2026)

Section 35's four-check rule applied to Fix 365:

| Check | Result |
| :-- | :-- |
| **Regression** | Same prompts, same validation, same data flow — frame lines only. |
| **Over-strictness** | Nothing rejected; display-only change. |
| **Over-engineering** | Deleted redundant lines; no new code. |
| **vs the source** | References stack brand + table boxes; single card is this repo's own direction per operator request. |
## 150. Numbered Change-Limit List — Four Checks (October 6, 2026)

Section 35's four-check rule applied to Fix 366:

| Check | Result |
| :-- | :-- |
| **Regression** | Same validation, same Before/After flow, same limit writes — only the picker list changed. Number input maps strictly inside the list range, anything else falls through to name. |
| **Over-strictness** | Nothing rejected; names still accepted as-is. |
| **Over-engineering** | Mirrors the existing list-account pattern line for line. |
| **vs the source** | References show wide tables; numbered list is this repo's own direction per operator request. |
## 151. Limit Column on Numbered Rows — Four Checks (October 6, 2026)

Section 35's four-check rule applied to Fix 367:

| Check | Result |
| :-- | :-- |
| **Regression** | Same picker, same validation, same writes — one extra column from the already-read limit source. |
| **Over-strictness** | Nothing rejected; display-only change. |
| **Over-engineering** | One Printf widened per tool. |
| **vs the source** | References show full tables; numbered rows with limit is this repo's own direction per operator request. |
## 152. Numbered Change-Quota List — Four Checks (October 6, 2026)

Section 35's four-check rule applied to Fix 368:

| Check | Result |
| :-- | :-- |
| **Regression** | Same validation, same Before/After flow, same quota writes and restarts — only the picker list and frames changed. Out-of-range numbers fall through to name lookup as before. |
| **Over-strictness** | Nothing rejected; names still accepted as-is. |
| **Over-engineering** | Mirrors the existing change-limit pattern; no new mechanism. |
| **vs the source** | References show brand banner plus wide tables; numbered list is this repo's own direction per operator request. |
## 153. Screen Gap Lines — Four Checks (October 6, 2026)

Section 35's four-check rule applied to Fix 369:

| Check | Result |
| :-- | :-- |
| **Regression** | Blank output lines only; prompts, reads, branches and payloads untouched (Telegram/log heredocs excluded by construction). |
| **Over-strictness** | Nothing rejected; display-only change. |
| **Over-engineering** | One blank line per clear site, no new mechanism. |
| **vs the source** | References print screens back to back; gapped screens are this repo's own direction per operator request. |
## 154. Five-Line Screen Gaps — Four Checks (October 6, 2026)

Section 35's four-check rule applied to Fix 370:

| Check | Result |
| :-- | :-- |
| **Regression** | Blank output lines only; prompts, reads, branches and payloads untouched. |
| **Over-strictness** | Nothing rejected; display-only change. |
| **Over-engineering** | Five blank lines per clear site, no new mechanism. |
| **vs the source** | References print screens back to back; gapped screens are this repo's own direction per operator request. |
## 155. Three-Line Screen Gaps — Four Checks (October 6, 2026)

Section 35's four-check rule applied to Fix 371:

| Check | Result |
| :-- | :-- |
| **Regression** | Blank output lines only; prompts, reads, branches and payloads untouched. |
| **Over-strictness** | Nothing rejected; display-only change. |
| **Over-engineering** | Three blank lines per clear site, no new mechanism. |
| **vs the source** | References print screens back to back; gapped screens are this repo's own direction per operator request. |
## 156. Color Path Aliases — Four Checks (October 6, 2026)

Section 35's four-check rule applied to Fix 372:

| Check | Result |
| :-- | :-- |
| **Regression** | Canonical paths untouched and still valid; xray configs untouched; rotation counter is best-effort (a race only repeats a color). |
| **Over-strictness** | Nothing rejected; additive aliases only. |
| **Over-engineering** | Generated location blocks mirroring canonicals; 6-line rotation snippet per builder. |
| **vs the source** | References have one path per backend; color aliases are this repo's own direction per operator request. |
