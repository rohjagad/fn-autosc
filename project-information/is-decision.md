# Architectural Decisions (Not Bugs)

> Renamed from `is-decision-not-bug.md`. References in `bugs-found.md` were
> updated to `is-decision.md` at the same time; the content below is unchanged.

This document tracks intentional design decisions, configurations, and behaviors in `fn-autosc` that may appear anomalous during audits but are deliberate choices rather than bugs.

## 1. Xray Pinned to Version 25.3.6
- **Component:** `installer/xray.sh` / Xray binaries across `fn-autosc`.
- **Decision:** Xray core version is explicitly pinned to `v25.3.6` rather than tracking latest upstream releases.
- **Reason:** Pinned for stability and protocol compatibility. Newer upstream Xray versions (v26+) deprecate or alter behavior for key transports and configurations (such as WebSocket ALPN flags, header structures, and TLS parameters) which are actively used throughout this autoscript. Pinned v25.3.6 ensures consistent and predictable runtime operation.

## 2. V2Ray Using Binary Packaged in Original Script Archive
- **Component:** `installer/v2ray.sh`, `v2ray/v2ray-linux-64.zip`.
- **Decision:** V2Ray uses the specific pre-packaged binary archive bundled with the original script release rather than downloading an arbitrary or newer upstream version from the internet.
- **Reason:** Pinned for stability and tested interoperability with the script's custom V2Ray configuration templates, inbounds, and WebSocket routing definitions.

## 3. WS IP Limit Probes and Skips When Stats Are Unavailable
- **Component:** `full/limit-ip-*.sh`, `lite/limit-ip-*.sh` (transports served by V2Ray, e.g. WS on `127.0.0.1:10080`).
- **Decision:** When the stats endpoint does not expose the Xray StatsService, the limiter prints a single `IP limit check skipped: online statistics unavailable ...` line and exits 0 instead of attempting enforcement.
- **Reason:** V2Ray exposes no per-user online-session metric, so there is no data source to enforce WS IP limits against; pointing the Xray API client at a V2Ray port only produced `Unimplemented ... unknown service xray.app.stats.command.StatsService` responses and integer-expression errors on every 5-minute cron run. Xray-backed transports (gRPC/split/HTTP on ports 10083/10082) still enforce for real behind the same probe guard.

## 4. Quantity Fields Reject 0 Instead of Treating It as "Unlimited"
- **Component:** all quantity input prompts - the IP limit, quota and duration fields throughout `full/` and `lite/`.
- **Decision:** `0` (and non-numeric or empty input) is refused on every quantity field by `^[1-9][0-9]*$`, and the prompt names its unit. `0` is deliberately **not** a sentinel for "unlimited" or "no limit"; an operator who wants a practically unbounded value enters a very large number instead. Because the rule is identical on every field, it is stated **once per screen** - a single `0 not allowed` notice immediately before the first numeric field - rather than repeated in each prompt; the prompt itself carries only what varies, the measurement. The notice is set off by a blank line above it and rendered in the panel's orange (`\033[38;5;208m`) so it reads as a rule rather than as one more prompt in the form. The validation loops and their red error are what actually enforce the decision; the notice is its description.
- **Reason:** each path that received a `0` interpreted it differently - silently unlimited for xray quota and IP limits (no limit file is written, so the Bug-68 guard skips enforcement), account deletion for `change-quota` (0 bytes written, then swept), first-login lock for `limit-ip.go`, and expiry-today for the day fields. The value was therefore ambiguous *and* the outcome was never signalled at the point of entry. Rejecting `0` outright removes the ambiguity and stops a stray keypress from producing any of those four results. "Unlimited" is intentionally not a real mode anywhere in the panel: a large number keeps the stored value a bounded, inspectable integer while being practically impossible to exhaust.

## 5. The Installer Re-Launches Itself Inside `screen`/`tmux`
- **Component:** `install.sh` (the persistent-session block) and the "Install Command" section of `README.md`.
- **Decision:** started outside a terminal multiplexer on an interactive tty, `install.sh` hands off to a session named `fninstall` - `exec screen -S fninstall bash /root/fn-install.sh`, or `tmux new-session -A -s fninstall` - installing `screen` first if neither tool is present. It deliberately does **not** do this when there is no tty (so `ssh host 'bash install.sh'` and other scripted runs are unaffected), and `FN_NO_SESSION=1` disables it outright.
- **Reason:** a full install runs 15-30 minutes and previously died with the SSH connection that started it, leaving a half-installed machine and no way to watch progress afterwards. Moving the work into a detachable session makes the install independent of the client connection at no cost to unattended use - the same trade-off the panel's own OS-reinstall feature already makes. Recorded here because an auditor seeing `install.sh` re-exec itself could otherwise read the hand-off as an unexplained loop or an attempt to hide output; it is neither, and the session name is fixed precisely so that the documented `screen -r fninstall` always finds it.

## 6. The OS-Reinstall Feature Uses the Upstream Reinstaller, Not Our Fork
- **Component:** `full/menu-system.sh`, `lite/menu-system.sh` - all 31 `reinstall.sh` invocations in each file.
- **Decision:** the panel downloads and runs `raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh` - the original, maintained upstream - rather than `rohjagad/reinstall`, which is our fork of it. The fork remains published and is referenced here for the record, but nothing in the panel uses it.
- **Reason:** the fork had silently gone stale and could no longer run at all. Its `SCRIPT_VERSION` is `4BACD833-A585-23BA-6CBB-9AA4E08E0004` while upstream is at `...0005`, and upstream's `trans.sh` - which the script fetches and greps for that GUID - no longer contains the fork's own version, so every run aborted at the initrd stage with `This script is outdated, please download reinstall.sh again`. Because the check compares against upstream's file, no amount of re-downloading the fork can fix it; only rebuilding the fork can, and that is maintenance we do not want to be on the critical path of an OS-recovery feature. Pointing at upstream removes that third party entirely. The trade-off is that the menu's version lists must track upstream (done in fix 94) instead of being pinned alongside a fork we control.

## 7. SSH VPN Accounts Are Created Without a Home Directory and Without a Shell
- **Component:** `full/addssh.sh:88` - `useradd -e "$expiration_date" -s /bin/false -M "$username"` - and `full/trial-ssh.sh:36` - `useradd -s /bin/false -M "$username"`.
- **Decision:** every SSH account the panel issues is created with `-M` (no home directory is made) and `-s /bin/false` (no usable shell). The account is intended to exist purely as a credential for **TCP port forwarding** - `ssh -D` / `-L` / `-R`, the "SSH VPN" use - and for nothing else.
- **Reason:** an account that can log in and own a home directory is an account that can run commands, receive files over `scp`/`sftp`, store data, write its own `~/.ssh/authorized_keys` and profile files, and generally be used as free hosting or a pivot. Removing both the shell and the home closes all of that at once while leaving forwarding untouched, because sshd performs the forwarding itself and needs neither a shell nor a home to do it. The panel layers its own controls on top - an `-e` expiry date and a per-account IP-limit file - so the credential is both time-bounded and concurrency-bounded.
- **Verification (live, fresh Debian 12):** `getent passwd` shows the test account with shell `/bin/false` and no `/home/<user>` on disk (`/home` contains only the panel's own `limit` directory). An interactive `ssh <user>@host id` exits 1 without executing anything and prints only `Could not chdir to home directory /home/<user>: No such file or directory`; a write attempt fails the same way. Forwarding, however, works: `ssh -N -L 18080:127.0.0.1:80 <user>@host` carried a request through to the server's nginx and returned HTTP 101. No script, menu or Go tool in the tree resolves `$HOME`, `os.UserHomeDir()` or `/home/<user>` for these accounts, so nothing depends on a home existing.
- **Note for auditors:** the `Could not chdir to home directory` line is sshd reporting the deliberately absent home on each login, including `-N` forwarding-only sessions. It is cosmetic rather than an error, and it is the visible symptom of this decision - it does **not** mean the account is broken or half-created. Likewise, `AllowTcpForwarding yes` in `sshd_config` is required: it is the capability the whole feature exists to provide.

## 8. Scope Policy - We Fork What Is Stable; Only the Frequently-Changing Reinstaller Is Out of Scope

- **Decision (policy).** A dependency that is a stable release or a pinned version is **forked**, and the fork is then **ours** - a defect in it is ours to fix. The one exception is `bin456789/reinstall`, which is updated very frequently; forking it would put us permanently behind it, so the panel calls upstream live (see decision 6) and **its internals are not ours to fix**.
- **Out of scope (one dependency only):** `bin456789/reinstall` - invoked live by the OS-reinstall menu, never forked. Findings inside it or inside the Alpine netboot environment it installs are recorded and recoverable, but no chase-in-place patch is carried in `fn-autosc`.
- **In scope because we fork/pin them:**
  - `rohjagad/fn-autosc-miscellaneous` - the pinned release assets (`v1.23`: `go1.22.0`, `udp-custom`, `udp-request`, `v2ray-linux-64.zip`, `vnstat-2.6`, `cloudflared`, `libreswan-3.32`) and the raw configs (`acme.sh`, `rclone.conf`, `rclone-install.sh`).
  - `rohjagad/Xray-install` - the installer script, used with Xray pinned to `25.3.6`.
  - `rohjagad/dnstt` - forked tunnel server, cloned at install time.
  - `rohjagad/wondershaper` - forked traffic shaper, cloned at install time.
  - Bundled pins: the V2Ray archive, the Go `1.22.0` toolchain, and Libreswan `3.32` (CentOS path only).
- **Checked in this cycle:** every `fn-autosc-miscellaneous` URL on the Debian path returns 200, and both cloned forks resolve (`dnstt` HEAD `17aa1fed`, `wondershaper` HEAD `98792b55`). The single unresolved `fn-autosc-miscellaneous` URL is `libreswan-$SWAN_VER.tar.gz`, reached only inside the `if [[ ${OS} == "centos" ]]` branch of `installer/l2tp.sh`; the Debian/Ubuntu path uses strongswan, so it is never fetched there.
- **Observed during this cycle (for the record - upstream, not a defect in `fn-autosc`):** the netboot environment fetches its modloop from the preferred (IPv6) address of `dl-cdn.alpinelinux.org`. On the test host, IPv6 was advertised with a default route before it was actually usable, so the fetch failed with `Network unreachable`, the environment exhausted its retries within the first minute after boot, and the machine sat idle in the netboot shell for 22 minutes with zero disk writes. Recovery, applied here and reproducible from the netboot shell, is to pin the download hosts to IPv4 in the environment's `/etc/hosts` - `151.101.66.132` for `dl-cdn.alpinelinux.org` and `deb.debian.org`, `194.71.11.165` for `cdimage.debian.org`, `185.199.109.133` for `raw.githubusercontent.com` and `github.com` - and run `/trans.sh` again. The cloud image then wrote normally (3.2 GB in ~29 s).

## 9. The SSH Banner Carries the Operator's Own Support Contacts

- **Component:** `installer/ssh.sh` (the `issue.net` banner shown on SSH and dropbear sessions), plus the `Documentation=` line of the panel's own systemd units.
- **Decision:** the banner names the operator's own contacts - WhatsApp `https://wa.me/6289512992313` on the order/trial line, and `❖Ƭʜᴇ TELEGRAM => https://t.me/rohcuan` where the previous author's WhatsApp group invite used to be. The panel's units (`dnstt`, the SlowDNS menu's unit template, the OpenVPN unit) also point their `Documentation=` at `https://t.me/rohcuan`.
- **Reason:** the banner is the first thing every connecting customer sees, so these strings are branding rather than a defect - they belong to whoever runs the server. They were changed here from the previous author's personal number and group to the operator's own, which is why the README no longer lists a "hardcoded WhatsApp number" as a known issue. Changing them again is a text edit in `installer/ssh.sh` (and the three installer files for the unit metadata), followed by a menu-zip rebuild because `menu-dnstt` carries one of those lines.
- **Note for auditors:** this is the one place a personal contact is still hardcoded, and it is deliberate. It is not the same class as the Telegram bot token, which was a credential granting control of a bot - that one is now read from the operator's own `/etc/funny/.keybot` and `/etc/funny/.chatid` and is not committed at all.

## 10. The SSH Banner Is a Default That the Menu Can Wholly Replace

- **Component:** `installer/ssh.sh` (writes the default `/etc/issue.net`) and the System menu, `full/menu-system.sh:749` / `lite/menu-system.sh:739`, option 8 "Change SSH Banner" (`bnnr()`).
- **Decision:** the banner is two layers and both are intended. The installer writes a complete **default** banner (box art, welcome text, rules, and the operator's own contacts at `wa.me/6289512992313` and `t.me/rohcuan`), and the operator can **wholly replace** it at runtime from System menu option 8. A default with a total replacement, rather than a default that is edited field by field.
- **Reason:** the default is what a fresh install shows and what every customer sees if the operator never touches it, so it must be complete and correct on its own. The menu option exists for operators who want their own message instead, and replacing the whole file is the simplest thing that can work from a one-line prompt - there is no merge logic to get wrong. The operator confirmed this shape is desired.
- **Accepted consequences (not defects, not to be "fixed"):** the menu entry overwrites the entire banner rather than editing a field, so a custom banner loses the design; and a custom banner is discarded whenever `installer/ssh.sh` runs again (any install or re-run rewrites `/etc/issue.net` from the default). Both follow from "default plus whole replacement" and are the point of the design.
- **Note for auditors:** do not propose making the default empty, do not add merge/parse logic to preserve a menu-set banner across a reinstall, and do not treat either consequence above as a bug. The contacts are recorded separately in section 9.

## 11. Backups Are Telegram-Only; Google Drive and Email Delivery Were Removed

- **Component:** `installer/set-br.sh`, `full/backup-gd.sh`, `lite/backup-gd.sh`, `full/bmenu.sh`, `lite/bmenu.sh`, and the README.
- **Decision:** the only backup delivery channel is the Telegram bot. The Google Drive variant (`backup-gd`, via rclone) is deleted, and the email notification that accompanied it - `msmtp`/`bsd-mailx` configured against a committed Gmail app password - is deleted with it. `backup` still stages the same tree and still falls back across anonymous file hosts to obtain a link, but Telegram now receives **both** the link and the archive itself.
- **Reason:** the Google Drive path rested on two credentials committed to a public repository - an `rclone.conf` remote fetched from the companion repo, and the previous author's Gmail app password - and it duplicated what Telegram already delivered. Telegram is the channel operators actually use. Removing it also closes the Gmail app-password item left open by the regression audit.
- **What changed:** `installer/set-br.sh` now installs wondershaper only (its rclone and msmtp/mail block is gone); `full/backup-gd.sh` and `lite/backup-gd.sh` are deleted; the `backup-gd` entries were removed from `menu/full.zip` (115 -> 114) and `menu/lite.zip` (98 -> 97); the backup menu is renumbered to 1 backup / 2-4 restore; and the README's backup and security sections were updated. `mail` is no longer installed, so nothing on the host can send email. `/etc/funny/.email` is deliberately retained because ACME uses it.
- **Note for auditors:** do not re-add rclone or an email path. If a Google Drive backup is ever wanted again it must arrive as a fresh, operator-owned configuration, not by restoring the committed remote or credential.

## 12. Backups Are Delivered as a Telegram Attachment; There Is No File Host

- **Component:** `full/backup.sh`, `lite/backup.sh`, the backup menu label, and the README.
- **Decision:** `backup` sends the archive to Telegram **as a document attachment**, with the details in its caption. The anonymous file-host upload (file.io, then `tmpfiles.org`, then `litterbox.catbox.moe`) is removed, so no public expiring link is produced any more. This supersedes the "still falls back across anonymous file hosts for a link" wording in section 11.
- **Reason:** the file host existed only to produce a link, and Telegram already receives the archive itself. The link added a third-party copy of the backup, an expiry the panel could not honour, and a dead-host fallback chain to maintain (file.io had already stopped serving anonymous uploads). Sending the document is a single request, needs no external service, and is what the operator actually uses.
- **What changed:** both `backup.sh` scripts lose the upload block, the `Your ID` and `Link Backup` fields and the "AutoDelete After 7 Days" claim, and the commented-out `sendMessage` block; the caption now carries the email, server IP and date/domain only. The menu entry reads "Backup to Telegram", and the README's backup section matches. `jq` is no longer used by the backup path (it stays installed for other uses).
- **Note for auditors:** the absence of a backup link is intended. Do not reinstate a file host; if a downloadable link is ever wanted it should be a deliberate, operator-owned destination rather than an anonymous public one.

### Section 12 revision - caption fields

The Telegram caption was reduced to **Domain / IP / Date**. The `Email` line and the now-unused `email=$(cat /etc/funny/.email)` read were removed from both `backup.sh` scripts, so the backup notification no longer surfaces the ACME address. The decision itself is unchanged, and the README's "Where it goes" was updated to match.

## 13. The WebSocket Transport Is Served by Xray, Not V2Ray

- **Component:** `installer/xray.sh` (which now owns the WS setup), `json/ws.json`, `full/limit-ip-ws.sh`, `full/quota-ws.sh`, and every script that used `/etc/v2ray/config.json`. This **supersedes decision 2** (V2Ray using the packaged archive).
- **Decision:** the WebSocket transport (vless 14016, vmess 977/95/96/23456, trojan 25432, plus the api inbound on 10080) is served by `xray@ws` reading `/etc/xray/json/ws.json`. V2Ray is no longer installed, downloaded or run: the packaged `v2ray-linux-64.zip` is gone from the install path and `/etc/v2ray` no longer exists. The setup lives in `installer/xray.sh` alongside the other three transports, with no separate installer.
- **This restores the pre-1.23 design.** The 1.20 reference archive has **no `v2ray.sh` at all**: `installer/xray.sh` deploys all four json templates, enables and starts `xray@ws` with the others, creates `/var/log/xray/ws.log`, and `full/limit-ip-ws.sh` enforces with `xray api statsonline --server=127.0.0.1:10080`. The V2Ray step was the deviation.
- **Reason:** Xray exposes the per-user **online-session** metric that V2Ray does not (Xray's `StatsService` answers `statsonline`; V2Ray's replies `Unimplemented ... unknown service`). While V2Ray served WS, the IP limiter could only print `IP limit check skipped: online statistics unavailable on 127.0.0.1:10080` on every cron run. Xray was already installed and already served the other three transports, and it runs the existing WS config unchanged (`xray run -test` -> `Configuration OK.`), so this is an engine swap, not a rewrite. Quota enforcement, which had been working through V2Ray's traffic counters, keeps working through the same API under Xray.
- **What changed:** `json/ws.json` logs to `/var/log/xray/ws.log`; every `/etc/v2ray/config.json` reference became `/etc/xray/json/ws.json`; `systemctl ... v2ray` and `service v2ray` became `xray@ws`; `v2ray api stats` became `xray api stats`; backup/restore stopped staging and restoring the retired `/etc/v2ray` tree; `installer/xray.sh` now replaces the WS template's `rerechan-store` placeholder with a real per-install UUID and enables/starts `xray@ws`; the shell-prompt block `v2ray.sh` used to write moved to `installer/ssh.sh`; and its `Port 22` uncomment was dropped, since 1.20 never had it and it contradicted the documented 3303-only SSH behaviour.
- **Consequence:** the WS IP limit is enforced again - the limiter's probe passes and it runs its enforcement path - and one engine serves all four transports. Restoring a *pre-migration* backup does not move its WS accounts into the new path automatically; the legacy restore repairs the config where it now lives.
- **Note for auditors:** do not reintroduce V2Ray. There is no `v2ray` service, no `/etc/v2ray`, and no packaged V2Ray asset; remaining mentions in the tree are historical notes.

### Section 13 addendum - the bundled V2Ray asset is deleted

`v2ray/v2ray-linux-64.zip` (16 MB) has been removed from the repository; nothing has fetched it since this decision. That also retires the "V2Ray archive" entry from the bundled-pin list in section 8. A follow-up sweep (case-insensitive this time, and across every code tree) removed the last references: `website/restore-ftp.sh` still copied the directory on restore and restarted the service, the four `limit-ip-*.sh` scripts carried a stale V2Ray comment, and `xp.sh`, `quota-ws.sh` and `menu-argo.sh` still named it.

### Section 13 addendum 2 - the migration is completed against the 1.20 template

The migration first reused V23's V2Ray-era `json/ws.json` and its WS scripts with a mechanical `v2ray` -> `xray` substitution. That left the WS IP limit inert (`statsUserOnline` was missing from the policy block) and broke WS quota accounting and the `cek-xray-ws` traffic display (`xray api stats` requires `-name`, unlike V2Ray's). The template now matches the 1.20 `Json/ws.json` and the stats reads use `statsquery`, the same pattern as `quota-grpc`/`quota-http`/`quota-split`. Recorded as fixes 100-103; see `bugs-fixed.md` and regression 19.

## 14. No Shipped Credential May Be Usable: The Installer Randomises Every Default

The four Xray templates (`json/ws.json`, `json/grpc.json`, `json/split.json`, `json/upgrade.json`) each ship a template client, and the repository is public. Because the account scripts only ever add clients, a shipped default stays active on every install, so any committed value is effectively a public credential. `installer/xray.sh` therefore replaces **all six** known defaults (`rerechan-store`, `cfbbaafc-8d52-450c-9fb0-145bc8221e6d`, `019e0bf3-dd56-11e9-aa37-5600024c1d6a`, `af7d5cf8-442d-4bb3-8a76-eb367178781d`, `diy2020`, `nonescript-fn-project`) with freshly generated UUIDs, and `bmenu.sh`'s legacy-restore repair applies the same loop to a restored archive.

**Rule for future changes:** if a new template or default client is added, add its committed value to that loop. A template default is acceptable only when its credential is generated per install. The templates' `###` marker lines must stay in place - the account scripts insert new clients after them - so removing the default client outright is not the approach; randomising it is.

Verified end to end on a fresh install: the committed values occur 0 times in `/etc/xray/json`, and from an external client they authenticate 0/11 while the per-install values authenticate 12/12 (fixes 111/116).

## 15. Transport Paths Follow a Fixed Scheme, and Old Paths Are Removed

Every protocol/transport pair carries one short path, `{proto}{transport}`: `vmws`/`vlws`/`trws` for WebSocket, `vmhu`/`vlhu`/`trhu` for HTTPUpgrade, `vmspl`/`vlspl`/`trspl` for SplitHTTP, and `vmgr`/`vlgr`/`trgr` as the gRPC service names. The same path string is used for the TLS and the NoneTLS form of a transport - Xray does not terminate TLS here, nginx does, so the port decides which listener is reached.

**Rule for future changes:** keep the `{vm|vl|tr}{ws|hu|gr|spl}` pattern. When a transport is added, add its path to the four `json/*.json` templates, the three `config/*.conf` nginx configs and the `add-*`/`trial-*` scripts in both editions, then rebuild `menu/*.zip`. Do not keep the previous path as an alias: old links are expected to stop working, which is acceptable because a path is only ever published on the account card at creation time (an existing client keeps working with its stored path only until the operator re-issues it).

VMess-WS is the one transport that previously had two paths (`/vmess` for TLS and `/worryfree` for NoneTLS) backed by two inbounds (`:23456`, `:95`) that every account was written into; it is now the single `/vmws` on `:23456`. The other VMess-WS inbounds (`:977` on `/` and `:96` on `/kuota-habis`) were unreachable - the `:977` catch-all had already been dropped from the nginx upstream in `68c4068` - and were removed together with their locations. gRPC has no NoneTLS form: its locations are only reached over TLS.

## 16. A Quota Breach Deletes the Account; Only an IP-Limit Breach Locks It

The two automatic enforcement paths behave differently, deliberately:

- **IP-limit breach** (`limit-ip-*`): the client is removed from the config, the card is moved to `<user>.locked`, the IP-limit file is kept, and the message says "Locked". `unlock-*` restores the account with the same UUID, expiry and IP limit.
- **Quota breach** (`quota-*` and `kill-*`): the account is deleted outright - client, card, quota and usage files - and the message says "deleted". It is not restorable, because the quota/usage files are gone and `unlock-*` only lists `*.locked`.

This matches the pre-existing `kill-*` behaviour (which already removed the card) and `xp`. The earlier quota wording ("has been locked") and the leftover card were the defects (Found 117 / fix 119). If a quota breach should instead be recoverable, the quota and usage files must be kept and re-armed when the account is unlocked - that is a design change, not a bug fix.

**Rule for future changes:** a daemon that removes a client from a `json/*.json` must (a) delete with `/### <user> <exp>/ {N;d}` plus the trailing-comma cleanup, never a bare range, (b) restart its transport when the config was written by its own process, and (c) leave no file behind that still describes the account unless it is a `.locked` card meant for `unlock-*`.

## 17. `location /` Serves SSH-WebSocket Only; There Is No VMess Catch-All

Both reference versions load-balanced nginx's `location /` across the SSH-WebSocket backend (`127.0.0.1:2080`) and a VMess catch-all (`127.0.0.1:977`), so a client using an arbitrary path landed on the VMess inbound roughly half the time - and, just as importantly, an **SSH-WebSocket** client using `/` landed on the VMess inbound the other half and failed. `68c4068` removed the `:977` line ("incompatible port 977"), and the canonical-path change removed the now-unroutable `:977` inbound, leaving `/` deterministic: it always reaches `wsEpro` (`127.0.0.1:2080`), which forwards to the SSH-WebSocket listener.

Keep it that way. The "arbitrary path" convenience is not worth a nondeterministic SSH-WebSocket endpoint, and the README already tells clients to use the dedicated transport paths (`/vmws`, `/vlws`, `/trws`, ...). Restoring the round-robin would reintroduce a 50% failure rate for SSH-WebSocket users on `/`. Recorded because both upstream versions contain the `:977` line, so a future reviewer comparing against them could otherwise read its absence as an accidental regression.

### Addendum to section 16 - the account card is removed at once, not by the GC

`auto-delete-*` already removes a card whose user is neither in the config nor `.locked` (verified live by planting such a card), so the phantom a quota deletion used to leave was transient - it disappeared within the five-minute cron cycle. Fix 119 still removes the card directly in `quota-*`: it closes that window and keeps the deletion complete even when `auto-delete-*` cannot run (its licence check or cron), and it matches what `kill-*` and `xp` already did. The substantive part of fix 119 remains the wording - the account is deleted, not locked.

## 18. The Panel API Lives in Its Own Repository, and FN-API Is Reference-Only

The panel's nginx config has always proxied `/api/` to `127.0.0.1:9000`, and the service meant to
answer there is FN-API. Its handler bundle (`/usr/bin/rere/<endpoint>`) and the `menu-api` command
were lost - the original `rere` download came from `https://scvps.rerechanstore.eu.org/rere`
(Rerechan's infrastructure, now dead) and the upstream parent repository returns 404 - so the API
could not run at all.

Restoring it inside `rohjagad/FN-API` was ruled out: that repository is the provider's own package and
is left untouched. The restored layer therefore lives in a dedicated public repository,
[`rohjagad/fn-autosc-api`](https://github.com/rohjagad/fn-autosc-api), which carries:

- its **own server** (Python 3, standard library only) rather than FN-API's `core/server`. It keeps
  the original contract - tokens in `/etc/xray/.key`, the raw `Authorization` header,
  `<METHOD> /<name>` running `/usr/bin/rere/<name>` with the body on stdin, JSON bodies, logging to
  `/etc/xray/api.log` - but binds `127.0.0.1` by default, accepts a single path segment only, threads
  the server, and reports a failing handler's stdout alongside the error;
- `lib.sh` and one handler per endpoint (documented in `fn-api.md`), plus `menu-api` to install,
  uninstall, report status and rotate the token.

**Nothing in `fn-autosc` and nothing in the API fetches or modifies `rohjagad/FN-API`; it is kept
purely as a reference** for the original endpoint list. The panel installer does not install the API:
it is an optional add-on, `menu-api install`, and the panel works without it.

**Rule for future changes:** a new account type that should be reachable over the API needs a handler
in `fn-autosc-api/handlers/`, an entry in `menu-api`'s handler list, and a row in the endpoint table
of `fn-api.md`. An endpoint with no backend on this panel must return the explicit unsupported error
rather than failing obscurely.

## 19. The Web-Restore Page Requires a Key; It Was Unauthenticated

`website/upload.php` (apache, port 855, installed by every full and lite install) accepts a `backup.zip`
and runs `sudo /usr/bin/restore-ftp`, which unpacks the archive over `/etc/passwd`, `/etc/shadow`,
`/etc/group`, `/etc/gshadow`, `/etc/crontab`, `/etc/xray`, `/etc/funny`, `/var/log/create`,
`/etc/wireguard`, `/etc/slowdns`, `/etc/noobzvpns`, `/etc/ppp` and `/etc/ipsec.*`. It had no
authentication at all, on a port reachable from the internet, so anyone could overwrite `/etc/shadow`
and take over the host (Found 138).

It now requires a key before it accepts the upload. The key is a dedicated
`/etc/funny/.restore.key`, generated by `website/install.sh`, owned `root:www-data` and mode `0640`,
and it is supplied as the form's `token` field or an `Authorization` header and compared with
`hash_equals`. The endpoint fails closed when the key file is absent or unreadable.

It deliberately does **not** reuse the API token in `/etc/xray/.key`: that file is `0600 root` and
must stay that way, and the web server user has no business reading the panel's root API credential.
A dedicated key readable by `www-data` (which already had the ability to run `restore-ftp` as root
through the sudoers rule) grants it nothing new, and the two secrets can be rotated independently.

## 20. The API's Contract Is `status`/`message`, and Its Transport Names Are the Create-Side Ones

The FN-API reference README documents a response shape of `{"ok":true,...}` /
`{"ok":false,"description":"..."}`. That describes the handler bundle that lived at the now-dead
`scvps.rerechanstore.eu.org`, which is not recoverable, and the reference is kept as a list of
endpoints only. The restored layer answers one consistent shape:
`{"status":"success",...}` or `{"status":"error","message":"..."}`, with HTTP 200 for both, and
HTTP 500 only for a handler that crashed. Adding a second success flag to every hand-built response
would invite the two to drift apart, so the reference's shape is recorded here rather than adopted.

The same reasoning fixes the transport naming: `core` accepts `ws`, `http`, `split` and `grpc`
(decision 15's canonical scheme, and the panel's own `add-*-http` script names), so `list-xray` and
`delete-xray` report those names rather than the panel's internal config-file name `upgrade`, which
`core` does not accept.

## 21. Panel Behaviour That Differs From Both References Is Recorded, Not Changed

Two divergences surfaced in this scan and were left as they are, to keep the fix history clean:

- **`unlock-ws` asks for no confirmation** while `unlock-http`, `unlock-split` and `unlock-grpc` all
  require `y`. This is exactly the state of **both** reference archives, so "fixing" it would be a
  behaviour change, not a repair. Recorded in `bugs-found.md`.
- **The authorization gate's empty-`LOCAL_IP` case** currently fails closed only because the first
  line matching `###` is the `# Format:` comment, whose fourth field is not a date. `install.sh`
  guards the case explicitly; the twelve sub-installers and the 180 panel scripts do not. Adding the
  guard to ~193 files for a path that already blocks, and that is only reachable by running a
  sub-installer directly, is not worth the churn; recorded instead.

## 22. The Installer Keeps Both SSH Ports Explicit, Rather Than Trusting the Base Image

`installer/ssh.sh` appended `Port 3303` to `sshd_config`. Because sshd listens only on the ports
named by active `Port` directives and Debian ships the default as a commented `#Port 22`, whether
port 22 survived depended on the base image - a netboot image closed it, an older cloud image did
not, and the cloud image the panel's own reinstaller now fetches closes it. That silently disabled
**SlowDNS**, whose dnstt service forwards the tunnel to `127.0.0.1:22`, and it contradicted every SSH
card and the README's port table.

The installer now makes both ports explicit and idempotent. Keeping 22 as well as 3303 is the
conservative choice rather than a new exposure: 22 is the base OS default, the panel has always
advertised it, `fail2ban` (installed and active) polices it, and the alternative - moving dnstt's
target to 3303 and removing 22 from the cards - would be a larger change than making the installer
deliver what the panel already promises. An operator who wants 3303 only can edit `sshd_config`; the
panel does not offer that choice.

## 23. Per-User Quota Counters Need an Explicit `level` on the Client

Xray 25.3.6 creates `user>>><email>>>traffic>>>uplink/downlink` only for clients that carry an
explicit `level`; `policy.levels."0".statsUserUplink/Downlink` alone is not enough, while the
`>>>online` counter works without one. Every account the panel created lacked a level, so the quota
daemons had nothing to read. The panel's clients now all carry `"level": 0`. The default level is 0
anyway, so this changes no routing or policy behaviour - it only makes Xray emit the counters the
panel has always assumed it emitted.
