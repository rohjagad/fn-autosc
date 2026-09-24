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
