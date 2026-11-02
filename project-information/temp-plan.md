# Temporary plan - Fix 533-538 (2026-11-02)

## Scope

Six approved follow-ups after the Fix 531/532 deployment:

1. **Fix 533** - remove the `quota-xhttp` startup `TERM` noise and the HAProxy backend `option tcplog` warning.
2. **Fix 534** - synchronize the live `dnstt.service` nameserver with `/etc/slowdns/nsdomain`.
3. **Fix 535** - restore `ws/simpang32` quota (100 GB) and IP limit (2) on rohserver6.
4. **Fix 536** - neutralize the published default Xray credentials on existing live boxes.
5. **Fix 537** - archive and clear the accumulated root cron mail.
6. **Fix 538** - remove the stale `rohcuan` SSH limit file on rohserver1.

**Excluded:** L2TP on rohserver6 and rohserver3. The running kernels have no `ppp_generic`, `pppox`, or `l2tp_ppp`, and no matching `linux-modules-extra-$(uname -r)` candidate exists. That needs a kernel upgrade/reboot or provider action, not an `update.sh` payload change.

## Delivery model

Every live change goes through `update.sh`; no live file is edited directly.

- **Commit A (payload):** script and installer changes, with per-fix markers.
- **Commit B (updater):** `update.sh` target changed to A, marker checks updated, and one-time migration functions added.
- **Deploy:** run the committed `update.sh` on rohserver6 first, verify, then rohserver1 and rohserver3.
- **Commit C (docs):** live-testing log and permanent fix records after verification.

One-time migrations use marker files under `/etc/funny/` and must be safe to re-run:

- `/etc/funny/.fix533-quota-clear`
- `/etc/funny/.fix534-dnstt-synced`
- `/etc/funny/.fix535-simpang32`
- `/etc/funny/.fix536-default-creds`
- `/etc/funny/.fix537-mail-cleared`
- `/etc/funny/.fix538-rohcuan-limit`

Every migration:

- checks its preconditions and skips silently when not applicable;
- backs up any file it replaces under the updater backup directory and a fix-specific path;
- logs one line to `/etc/xray/.quota.logs` or the updater output;
- never aborts the whole update on a missing optional file;
- preserves ownership and modes by editing in place or using `install`.

Baseline before this batch:

- repository: `75fb379`
- live target: `7a56d8dda91f3f90a5fc65fef456b4d11f1b842a`
- hosts: rohserver6 `64.120.94.62`, rohserver1 `103.210.69.33`, rohserver3 `157.10.253.95`

## Answer to the `nsdomain` question

Yes. The current installer asks for the SlowDNS nameserver in the same first-run loop as the installer domain:

- `installer/full.sh:99` asks `Your SlowDNS Nameserver:`;
- `installer/full.sh:141` saves it to `/etc/slowdns/nsdomain`;
- `installer/slowdns.sh:102-122` preserves `/etc/slowdns/nsdomain` across the `rm -rf /etc/slowdns`;
- `installer/slowdns.sh:141-167` reads it and writes `dnstt.service` with that exact value.

So current installs are consistent. The live mismatch is legacy drift: the live `dnstt.service` files were written before the saved nsdomain (unit mtimes are about 30 minutes earlier than `/etc/slowdns/nsdomain`), which points to an older install flow or a restore. Fix 534 is therefore a **migration for existing boxes**, not an installer change.

Important: syncing the unit does not create DNS delegation. After the unit is consistent, the operator still needs the chosen SlowDNS name delegated to the server. If the name has no NS/glue record, SlowDNS will not work even with a matching unit.

## Fix 533 - quota TERM and HAProxy warning

### Files

- `full/quota-ws.sh`, `full/quota-http.sh`, `full/quota-grpc.sh`, `full/quota-xhttp.sh`
- matching `lite/` files
- `update.sh` (restart all four quota services; HAProxy warning cleanup)

### Change

1. Replace the startup `clear` in each quota script with:
   ```bash
   [ -t 1 ] && clear || true
   ```
   This preserves the clear on a terminal and suppresses the `TERM environment variable not set.` line under systemd.
2. Add a `Found 533` marker to each changed quota script.
3. `update.sh`:
   - marker-check `quota-*` with `Found 533`;
   - after installing the scripts, restart all four quota services, not only `quota-xhttp` (current code at `update.sh:379-381` restarts only xhttp).
4. HAProxy:
   - in `patch_haproxy_logging()`, remove the ignored `option tcplog` line from `backend ssh-backend` if present;
   - back up the config;
   - run `haproxy -c -f /etc/haproxy/haproxy.cfg`;
   - reload HAProxy (prefer `systemctl reload haproxy`; fall back to restart only if reload is unavailable);
   - restore the backup if validation fails.

### Acceptance

- No new `TERM environment variable not set.` line in `journalctl -u quota-*` after restart.
- `quota-ws`, `quota-http`, `quota-grpc`, `quota-xhttp` active.
- `haproxy -c` valid with no `option tcplog` warning.
- SSH/HAProxy sessions remain healthy.

### Rollback

- Updater backup contains the old quota scripts.
- HAProxy backup is `/root/fn-update-backup-<date>/haproxy.cfg`.
- Restart the old quota units and restore the HAProxy config if needed.

## Fix 534 - synchronize the dnstt nameserver

### Files

- `update.sh` (migration)
- no change needed to `installer/full.sh` or `installer/slowdns.sh`; they are already correct

### Current live values

| Host | Unit domain | `/etc/slowdns/nsdomain` |
| :-- | :-- | :-- |
| rohserver6 | `ns.kainmurah.us.ci` | `ns.jalanlancar7.my.id` |
| rohserver1 | `ns.mierebus.cc.cd` | `ns.lancarjaya1.my.id` |
| rohserver3 | `ns.basrengkita.us.ci` | `ns.haribaik4.my.id` |

### Migration

1. Run only when:
   - `/etc/systemd/system/dnstt.service` exists;
   - `/etc/slowdns/nsdomain` is non-empty;
   - the value matches the same FQDN validation used by `menu-dnstt`.
2. Read the current `ExecStart` domain from the unit.
3. If it already matches, touch the marker and return.
4. Back up the unit to the updater backup and to `/root/fn-dnstt-backup-<date>.service`.
5. Rewrite the unit using the same template as `installer/slowdns.sh` and `menu-dnstt`, with:
   ```text
   ExecStart=/etc/slowdns/dns-server -udp :5300 -privkey-file /etc/slowdns/server.key <nsdomain> 127.0.0.1:22
   ```
6. `systemctl daemon-reload`.
7. If `dnstt` is active or enabled, restart it and verify `ActiveState=active`.
8. Write the marker and log the old/new names.

### DNS check

After the unit is consistent, check the chosen name:

```bash
dig +short NS <nsdomain>
dig +short A <nsdomain>
dig +short AAAA <nsdomain>
```

The exact record type depends on the operator's DNS setup. If the name is not delegated, report it; do not invent DNS records from the updater.

### Acceptance

- `systemctl show dnstt -p ExecStart` contains the same domain as `/etc/slowdns/nsdomain` on all three.
- `dnstt` remains active.
- No other unit or port changes.

### Rollback

- Restore the saved unit, `daemon-reload`, restart `dnstt`.

## Fix 535 - restore `ws/simpang32` limits

### Current state

- rohserver6 only.
- `/var/log/create/xray/ws/simpang32.log` exists and says `Limit IP: 2`, `Quota: 100 GB`.
- `/etc/xray/quota/ws/simpang32_usage` exists (~95 MiB used).
- `/etc/xray/quota/ws/simpang32` and `/etc/xray/limit/ip/xray/ws/simpang32` are missing.

### Migration

1. Run only on rohserver6 when:
   - the card exists;
   - the quota file does not exist;
   - the IP-limit file does not exist;
   - the card values parse as `2` and `100`.
2. Back up the card and usage files if present.
3. Write:
   ```bash
   printf '%s\n' 107374182400 > /etc/xray/quota/ws/simpang32
   printf '%s\n' 2 > /etc/xray/limit/ip/xray/ws/simpang32
   ```
4. Leave the existing usage file untouched.
5. Append a line to `/etc/xray/.quota.logs`:
   `fix535: restored simpang32 quota=107374182400 limit=2`.
6. Do not restart `quota-ws`; it reads the files on its next pass.

### Acceptance

- Both files exist with numeric values.
- `cek-xray-ws` shows `100 GB` and `IP 2` for `simpang32`.
- Usage remains below the restored quota.
- No other account files change.

### Rollback

- Remove the two restored files if the operator decides the account should be unlimited; the usage file is untouched.

## Fix 536 - neutralize published default credentials

### Current state

The JSON templates still ship public default credentials. The current installer already randomizes them for **new** installs (`installer/xray.sh:133-150`), but the live boxes were installed before that code and still use the published values.

Defaults to replace (the exact list is already in `installer/xray.sh`):

- `ws.json`: the old vmess/trojan password and the old vless/vmess UUID.
- `grpc.json`: the old vless/vmess/trojan UUID.
- `xhttp.json`: the old vmess UUID, vless UUID, and trojan password.
- `upgrade.json`: the old placeholder vmess/vless/trojan value.

### Why not remove the client objects

The add/trial scripts use the comment marker inside each default client object as the JSON insertion anchor. Removing the seed object would require rewriting every add/trial insertion path and retesting all four protocols. That is a separate refactor, not part of this batch.

The safe fix is to make the published credentials useless while keeping the seed objects:

### Migration

1. Run once per box; marker `.fix536-default-creds`.
2. For each default credential value:
   - verify it exists in the live JSON;
   - replace every occurrence with a fresh `xray uuid` (also valid as a trojan password);
   - do not replace an operator-created account unless it reused the old published value; if an old value is used outside a default client, log a warning and skip that value.
3. Back up the four JSON files to the updater backup.
4. Run `xray run -test -config` on all four files.
5. If all four pass, restart `xray@ws`, `xray@grpc`, `xray@upgrade`, and `xray@xhttp` once each.
6. If any test fails, restore all four files and do not restart.

### Acceptance

- None of the old published values remains in live JSON.
- All four `xray run -test` calls pass.
- The four Xray units are active.
- New installs continue to randomize through `installer/xray.sh`.

### Rollback

- Restore the four JSON files from the updater backup, test, restart.

## Fix 537 - archive and clear root cron mail

### Current state

- `/var/mail/mail` is 120,179,204 / 85,681,773 / 99,616,713 bytes on rohserver6 / rohserver1 / rohserver3.
- Growth stopped after Fix 532; the old file remains.

### Migration

1. Run once per box; marker `.fix537-mail-cleared`.
2. Only when `/var/mail/mail` exists and is larger than 1 MiB.
3. Preserve the existing mode and ownership.
4. Compress the current mailbox:
   ```bash
   gzip -c /var/mail/mail > /root/fn-mail-backup-<date>.gz
   ```
5. Truncate in place so the inode, owner, and mode stay intact:
   ```bash
   : > /var/mail/mail
   ```
6. If `/var/spool/mail/mail` is a separate file, apply the same handling.
7. Log the archive path and the final size.

### Acceptance

- Mailbox size 0 (or near 0).
- Archive exists under `/root/` and is readable.
- No new mail after the next cron tick.

### Rollback

- `gzip -dc /root/fn-mail-backup-<date>.gz > /var/mail/mail` and restore ownership/mode if needed.

## Fix 538 - remove the stale `rohcuan` SSH limit

### Current state

- rohserver1 has `/etc/xray/limit/ip/ssh/rohcuan` with value `2`.
- `getent passwd rohcuan` shows an existing OS user (`/home/rohcuan`, `/bin/bash`).
- There is no `/var/log/create/ssh/rohcuan.log`, so the panel has no account card for it.

### Migration

1. Run only on rohserver1; marker `.fix538-rohcuan-limit`.
2. Skip if `/var/log/create/ssh/rohcuan.log` exists or a panel card exists.
3. Back up the limit file to the updater backup and a fix-specific path.
4. Remove `/etc/xray/limit/ip/ssh/rohcuan`.
5. Log the removal.
6. Do not touch the OS user, home directory, shell, or password.

### Acceptance

- Limit file absent.
- `rohcuan` OS user still exists.
- `limit-ip-ssh` active; no other SSH limits changed.

### Rollback

- Restore the saved limit file.

## `update.sh` integration

Add migration functions after the payload install and before the final service-restart section. Suggested order:

1. `randomize_live_defaults` (Fix 536) - JSON must be valid before Xray restarts.
2. `repair_simpang32` (Fix 535) - no restart.
3. `sync_dnstt_unit` (Fix 534) - restart `dnstt` after rewrite.
4. `remove_rohcuan_limit` (Fix 538) - no restart.
5. `cleanup_root_mail` (Fix 537) - no restart.
6. Restart all four quota services (Fix 533).
7. `patch_haproxy_logging` with the `option tcplog` removal (Fix 533).
8. Restart the Xray units changed by Fix 536.

Each function returns 0 on skip/failure and logs a warning; a failure in an optional data migration must not roll back an otherwise successful payload install.

## Local verification before deployment

- `bash -n` for every changed script and `update.sh`.
- `tools/verify-payload.sh` passes.
- Marker harness confirms each updated `marker_for` value exists in the target file.
- `xray run -test` on temporary copies after the Fix 536 replacement.
- Fixture tests for the `simpang32` card parser (`100 GB`, `IP 2`).
- Fixture test for the `dnstt` unit rewrite (old/new `ExecStart`).
- `haproxy -c` on a temporary copy with the `option tcplog` line removed.
- Shell test that non-TTY quota startup produces no `TERM` output.

## Live verification after deployment

For each box:

- `UPDATE SUCCESS`, `.update-commit` = new target.
- Changed script hashes match the code commit.
- `systemctl --failed` empty; all quota/Xray/Nginx/HAProxy/SSH/Dropbear units active.
- `journalctl -u quota-*` has no new `TERM` line.
- `haproxy -c` has no `option tcplog` warning.
- `dnstt` `ExecStart` matches `/etc/slowdns/nsdomain`; service active.
- `simpang32` quota/limit files present; `cek-xray-ws` displays 100 GB / IP 2.
- Old default credentials no longer appear in live JSON; all four Xray configs pass.
- Mailbox size 0 with archive present; no new mail after a cron tick.
- `rohcuan` limit file absent; OS user still present.
- Repeat the existing post-update config audit for regressions.

## Documentation after deployment

- `project-information/bugs-fixed.md`: Fix 533-538 records with live evidence.
- `project-information/bug-fixes-regression.md`: sections 293-298.
- `project-information/is-decision.md`: Decision 50 for legacy migrations and default-credential neutralization.
- `README.md`: update target, quota restart behavior, dnstt sync note, default-credential note, and mail cleanup.
- `project-information/live-testing-log.md`: deployment record and post-checks.
- Remove or archive this temporary plan after the batch is complete.

## Open points

- Fix 534 needs the operator to confirm `/etc/slowdns/nsdomain` is the intended name; the plan uses it as the source of truth.
- Fix 536 neutralizes the public credentials but keeps the default client objects as insertion anchors. Full removal is a separate refactor.
- Fix 537 archives the current mailbox before truncating; the archive is retained under `/root/`.
- Fix 538 removes only the stale limit file, not the `rohcuan` OS user.
