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

## Appendix A - Junior IT walkthrough

This appendix explains the same six plans from the operating-system and application side. It is written for someone who knows Linux basics but has not worked on this panel before.

### A.0 How the updater and the two commits fit together

`update.sh` is the only supported way to change a live box. It does not edit files in place on GitHub and it does not use `git pull` on the VPS. The flow is:

1. The updater has a hardcoded `TARGET` commit SHA.
2. It builds a list of payload file names from `FILES`, `CONFIG_FILES`, `WEB_FILES`, and `BINARIES`.
3. For each file it downloads:
   `https://raw.githubusercontent.com/rohjagad/fn-autosc/<TARGET>/<edition>/<name>.sh`.
4. It writes every download to a temporary staging directory.
5. It runs `bash -n` on every script and checks that the file contains the expected text marker, for example `Found 531` or `Found 532`.
6. Only after every download passes does it create a backup under `/root/fn-update-backup-<date>/` and install the files into `/usr/bin`.
7. It then runs small migration functions for live state that is not stored in the repository, such as systemd units and account files.
8. Finally it restarts the services that need the new code.

Two commits are used because a commit cannot contain its own SHA:

- **Commit A** contains the payload files and their markers.
- **Commit B** contains the updater with `TARGET=A` and the migration functions.
- The live box records `A` in `/etc/funny/.update-commit`; the updater that performed the work is `B`.

This is why the menu shows the payload target, not the updater commit.

### A.1 Fix 533 - quota `TERM` message and HAProxy warning

**What the quota scripts are.** `quota-ws`, `quota-http`, `quota-grpc`, and `quota-xhttp` are long-running systemd services. Each one asks the local Xray API for byte counters, adds the delta to `/etc/xray/quota/<proto>/<user>_usage`, compares that number with `/etc/xray/quota/<proto>/<user>`, and deletes or locks the account when the usage is over the limit.

**Why `TERM` appears.** Each script starts with `clear`. `clear` is a terminfo program: it looks up the `TERM` environment variable to know which escape sequence clears the screen. A systemd service has no terminal and usually no `TERM`, so `clear` writes `TERM environment variable not set.` to stderr. That is harmless to the quota logic, but it pollutes the journal every time the service starts.

**What we change.** The line becomes:

```bash
[ -t 1 ] && clear || true
```

`-t 1` asks the shell whether file descriptor 1 (stdout) is a terminal. In an SSH session it is, so the screen clears as before. Under systemd or cron it is not, so `clear` is skipped and the `|| true` keeps the command's exit status at 0. We add `Found 533` so the updater can prove the new file was downloaded.

Because these are long-running processes, installing the new file is not enough: the old process is still running the old script. The updater will restart all four quota services after the swap. Restarting them briefly pauses quota checks; it does not delete data.

**HAProxy warning.** HAProxy's `option tcplog` tells HAProxy to write a TCP-level log line. It is valid in a `frontend` or `listen` section, but the `ssh-backend` section is a `backend`; HAProxy ignores the directive there and prints a warning during `haproxy -c`. The updater will remove that one line, back up the config, run `haproxy -c`, and reload HAProxy only if validation passes. Removing an ignored directive does not change traffic handling.

**How to verify.** After the update:

```bash
systemctl is-active quota-ws quota-http quota-grpc quota-xhttp
journalctl -u quota-xhttp --since '10 minutes ago' | grep -F 'TERM environment variable not set' || echo clean
haproxy -c -f /etc/haproxy/haproxy.cfg
```

**What can go wrong.** A quota restart can briefly delay a quota pass. If `haproxy -c` rejects the edited config, the updater restores the backup and does not reload. A malformed config is therefore not left live.

### A.2 Fix 534 - making the `dnstt` unit match `/etc/slowdns/nsdomain`

**What SlowDNS/dnstt is.** `dnstt` is a DNS tunnel. The server binary is `/etc/slowdns/dns-server`. Its command line includes a domain name:

```text
/etc/slowdns/dns-server -udp :5300 -privkey-file /etc/slowdns/server.key <domain> 127.0.0.1:22
```

That `<domain>` is the tunnel domain. The client must use the same domain. The server does not create DNS records; the operator must delegate that name at the DNS provider so queries reach this VPS.

**Where the two values come from.** `/etc/slowdns/nsdomain` is the file the menu reads and displays. `menu-dnstt` writes the unit with that value. The current installer also preserves the file and uses it when creating the unit. So for a fresh install the two should match.

**Why the live boxes differ.** The systemd unit files are older than the nsdomain files by roughly 30 minutes. That is consistent with an older install flow, or a restore that copied `/etc/slowdns` without rewriting the unit. It is not what the current installer does. This is why the plan is a one-time migration, not an installer rewrite.

**What the updater will do.** It will:

1. Read `/etc/slowdns/nsdomain`.
2. Reject an empty or syntactically invalid hostname.
3. Read the current `ExecStart` line from `/etc/systemd/system/dnstt.service`.
4. If the domains already match, write the marker and stop.
5. If they differ, save the old unit to the update backup and a separate file, write a new unit with the same template and the nsdomain value, run `systemctl daemon-reload`, and restart `dnstt` if it was active.
6. Check that the service is still active.

`systemctl daemon-reload` is required because systemd caches unit files. Editing the file alone does not change the running service definition.

**What this does not fix.** It does not create an NS or A/AAAA record. If the name is not delegated, the service can be active and still unusable. After the migration, check the actual DNS delegation at the provider.

**How to verify.**

```bash
cat /etc/slowdns/nsdomain
systemctl show dnstt -p ExecStart
systemctl is-active dnstt
```

The domain in `ExecStart` must equal the file. Then test DNS separately.

### A.3 Fix 535 - restoring `simpang32` quota and IP limit

**How quota enforcement stores state.** For each WS account there are normally two quota files:

```text
/etc/xray/quota/ws/<user>          # allowed bytes
/etc/xray/quota/ws/<user>_usage    # bytes already used
```

and one IP-limit file:

```text
/etc/xray/limit/ip/xray/ws/<user>  # maximum concurrent IPs
```

`quota-ws` only enforces a quota when the base quota file exists. In pseudocode:

```bash
if [ -f "$quota_file" ]; then
    compare usage with quota
fi
```

If the base file is missing, the account is treated as unlimited. `limit-ip-ws` behaves similarly: a missing limit file means "unlimited".

**Why `simpang32` is unusual.** The card at `/var/log/create/xray/ws/simpang32.log` says `Quota: 100 GB` and `Limit IP: 2`. The `_usage` file exists and has real traffic, but the base quota and IP-limit files are gone. That is why the account currently is not enforced. This was already documented as a known live inconsistency before Fix 531/532.

**What the updater will do.** It will parse the card, confirm the values are exactly `100` GB and `2`, and write:

```bash
printf '%s\n' 107374182400 > /etc/xray/quota/ws/simpang32
printf '%s\n' 2 > /etc/xray/limit/ip/xray/ws/simpang32
```

The existing `_usage` file is left alone. The account is therefore enforced from the next quota pass onward. No restart is needed because `quota-ws` opens the files on each loop.

**Why the number is 107374182400.** 100 × 1024 × 1024 × 1024. The panel stores bytes, not gigabytes. Writing `100` would mean 100 bytes and would delete the account immediately.

**How to verify.**

```bash
cat /etc/xray/quota/ws/simpang32
cat /etc/xray/limit/ip/xray/ws/simpang32
cat /etc/xray/quota/ws/simpang32_usage
```

Optionally run the installed `cek-xray-ws` viewer; it should show `100 GB` and `IP 2` instead of `Not available`.

**What can go wrong.** If the account was intentionally unlimited, restoring the files changes its behaviour. The operator confirmed 100 GB / IP 2, so this is the intended state. If parsing fails, the migration skips rather than writing a wrong number.

### A.4 Fix 536 - disabling the published default Xray credentials

**Why the JSON files look odd.** The Xray configs are JSON with `#` comment lines used as insertion markers:

```json
"clients": [
  {
    "id": "019e0bf3-...",
    "email": "2019@gmail.com",
    "level": 0
#vmess
  }
]
```

The add/trial scripts do not rewrite the whole file. They use `sed` to find `#vmess`, move to the next line, and replace the closing `}` with `}, <new account>`. The default client object is therefore an **anchor** for the insertion. Removing it would require rewriting every add/trial script for every protocol, which is why the plan does not do that in this batch.

**Why it is a problem.** The repository is public. The default UUIDs and the trojan password are visible in `json/*.json`. If a live box still uses those values, anyone who reads the repository can authenticate with a known credential. The current installer already fixes this for new installs: `installer/xray.sh` replaces the known values with fresh `xray uuid` values after downloading the templates.

**Why live boxes still have them.** The live boxes were installed before that installer code was in place, and `update.sh` does not normally rewrite JSON configs because they contain live accounts. So the old known values survived.

**What the updater will do.** It will apply the same replacement logic the installer already uses:

1. For each known default value, find it in the live JSON files.
2. Replace it with a newly generated `xray uuid`.
3. Back up all four JSON files.
4. Run `xray run -test -config` on each.
5. Only if all four pass, restart the affected Xray units.
6. If any test fails, restore the backups and leave the old files in place.

The default client objects remain, but the published credentials no longer authenticate. The add scripts keep working because the marker and anchor object are untouched.

**How to verify.**

```bash
grep -R '019e0bf3\|af7d5cf8\|diy2020\|nonescript-fn-project\|cfbbaafc\|rerechan-store' /etc/xray/json || echo "old defaults gone"
xray run -test -config /etc/xray/json/xhttp.json
xray run -test -config /etc/xray/json/upgrade.json
xray run -test -config /etc/xray/json/grpc.json
xray run -test -config /etc/xray/json/ws.json
```

**What can go wrong.** If an operator-created account reused one of the published default IDs, replacing that value would change the account. The migration checks where the value occurs and logs a warning instead of blindly rewriting an account. If Xray rejects a file, the backup restore prevents a partial config from going live.

### A.5 Fix 537 - archiving and clearing root mail

**What the mailbox is.** Cron captures the stdout and stderr of a job. If the job prints anything and `MAILTO` is not disabled, a local mail transfer agent (Exim here) delivers a message to root's mailbox at `/var/mail/mail`. The file is an **mbox**: multiple RFC 822 messages concatenated, separated by `From ` lines.

**Why it is large.** The panel cron jobs ran every five minutes. Each run of `limit-ip-*` or `kill-*` called `clear`; with no `TERM`, `clear` printed an error. The mailbox accumulated 82-115 MiB of repeated errors and message headers. Fix 532 stopped new messages by silencing non-TTY output; it did not delete the old mbox.

**What the updater will do.** It will:

1. Check that `/var/mail/mail` exists and is larger than 1 MiB.
2. Compress it to `/root/fn-mail-backup-<date>.gz`.
3. Truncate the original with `: > /var/mail/mail`.

The `: >` form truncates the existing inode instead of deleting and recreating the file. That preserves the owner, group, and permissions. Deleting the file and creating a new one as root could leave the wrong owner, which would break local mail delivery.

**Why archive instead of delete.** The mailbox may contain one or two non-TERM messages, such as security notices. Compressing it keeps the evidence and removes the 100 MiB from the live mail path. The archive is under `/root/`, readable only by root.

**How to verify.**

```bash
stat -c '%s %U:%G %a %n' /var/mail/mail
ls -lh /root/fn-mail-backup-*.gz
```

The mailbox should be 0 bytes and the archive should exist. Wait for one five-minute cron tick and confirm the mailbox does not grow again.

### A.6 Fix 538 - removing the stale `rohcuan` SSH limit

**Panel accounts vs OS users.** SSH panel accounts are real Linux users. The panel also keeps a card at `/var/log/create/ssh/<user>.log` and, optionally, an IP limit at `/etc/xray/limit/ip/ssh/<user>`. `limit-ip-ssh` reads the limit file and counts active sessions. It does not treat an OS user as a panel account by itself.

**Why `rohcuan` is special.** `rohcuan` is an existing OS user with UID 1000, home `/home/rohcuan`, and `/bin/bash`. There is no panel card and no `/var/log/create/ssh/rohcuan.log`, but a limit file from October remains. The file is stale panel state, not part of the Linux account.

**What the updater will do.** It will:

1. Confirm the OS user exists.
2. Confirm no panel card exists.
3. Back up the limit file.
4. Remove only `/etc/xray/limit/ip/ssh/rohcuan`.

It will not run `userdel`, will not touch the home directory, and will not change the shell or password. Removing the file means `limit-ip-ssh` will not enforce an IP limit for that OS user. That is the intended cleanup of stale panel state.

**How to verify.**

```bash
getent passwd rohcuan
test -e /etc/xray/limit/ip/ssh/rohcuan && echo present || echo removed
systemctl is-active limit-ip-ssh 2>/dev/null || true
```

`limit-ip-ssh` is a cron job, not a systemd unit, so `systemctl` may not apply; the important checks are the OS user and the file.

### A.7 Why L2TP is not in this batch

L2TP needs kernel support:

- `ppp_generic` provides the PPP character device `/dev/ppp`.
- `pppox` and `l2tp_ppp` implement PPP-over-L2TP.
- `/etc/xl2tpd/xl2tpd.conf` and `/etc/ppp/options.xl2tpd` are only configuration; they cannot create those kernel interfaces.

On rohserver6 and rohserver3, `modinfo` cannot find `ppp_generic`, `pppox`, or `l2tp_ppp`; `l2tp_core` and `l2tp_netlink` exist, which is why `xl2tpd` starts, but `pppd` fails when it tries to open `/dev/ppp`. The running kernel is older than the kernel package candidate, and the matching `linux-modules-extra-$(uname -r)` package is not available. A safe fix would require upgrading the kernel, installing the matching modules, and rebooting, or asking the provider to enable L2TP/PPP. That is a host maintenance task, not an `update.sh` payload change, so it is excluded.
