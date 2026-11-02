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
- **SUPERSEDED 2026-09-25 (commit `73ace38`, engine swap; note added 2026-10-09):** V2Ray was removed — Xray now serves WS (`xray@ws` on `/etc/xray/json/ws.json`, same ports, nginx untouched) precisely because Xray exposes the per-user online stat. The probe guard above stays as harmless safety (fail-closed to skip), but its V2Ray rationale no longer applies: WS enforcement is now expected to work, limited only by source-IP visibility behind nginx (Found 489 — all inbounds see 127.0.0.1 without PROXY protocol).

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

Every protocol/transport pair carries one short path, `{proto}{transport}`: `vmws`/`vlws`/`trws` for WebSocket, `vmhu`/`vlhu`/`trhu` for HTTPUpgrade, `vmxh`/`vlxh`/`trxh` for XHTTP, and `vmgr`/`vlgr`/`trgr` as the gRPC service names. The same path string is used for the TLS and the NoneTLS form of a transport - Xray does not terminate TLS here, nginx does, so the port decides which listener is reached.

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
  `/etc/xray/api.log` - but binds `127.0.0.1` by default, accepts a single path segment only, stays
  single-threaded like the reference (a threaded build was tried and reverted), and reports a failing handler's stdout alongside the error;
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

### Addendum to section 8 - the miscellaneous repository's rclone assets are gone

Section 8's list of raw configs in `rohjagad/fn-autosc-miscellaneous` included `rclone.conf` and
`rclone-install.sh`. Decision 11 removed the Google Drive backup path and states that the committed
remote must not survive, so both files were deleted from that repository (misc `4dd9424`); the panel
has referenced rclone nowhere since decision 11. The pinned release assets listed alongside them are
unchanged.

### Addendum to section 18 - the bot bundle is vendored here

Section 18 says nothing fetches or modifies `rohjagad/FN-API`. `menu-bot` still fetched
`main/bot.zip` from it. The bundle is now committed as `other/bot.zip` in this repository and both
editions fetch it from there (fix 155), so the section holds without exception. The rule for future
changes is the same one section 14 uses for credentials: nothing the panel installs at runtime may
depend on a repository kept only as a reference.

## 24. The IP Limit Trusts the Address Chain; Forging It Is Out of Scope

The per-account IP limit counts the address the panel hands the upstreams, and that value is the
panel's own `$clientRealIp` map: the **last** address the request chain carries, falling back to the
connection peer. Behind Cloudflare that is the real client - Cloudflare appends it after anything the
client sent - and for a direct connection it is the peer. The map's two fallbacks (`""` and `default`)
both yield `$remote_addr`, so it can never come out empty and nginx can never drop the header.

An earlier hardening replaced this with `set_real_ip_from <Cloudflare ranges>` plus
`real_ip_header CF-Connecting-IP`, so that a client could not choose the counted address by sending
its own `X-Forwarded-For`. **That was reverted, deliberately.** The owner's rule is the deciding one:
the limit has to work for a **regular user**, and a regular user does not forge headers. The hardened
form made the everyday case depend on a list of Cloudflare ranges that has to be kept current - a
range Cloudflare adds after an install would not be trusted, the new edge address would be counted
instead, and accounts would be locked for no reason. The map has no such list: a brand-new Cloudflare
range changes nothing, because Cloudflare's chaining rule is what it relies on.

So the trade is: a determined client can still send a header that changes what the limit counts, and
that is accepted; the limiter failing for ordinary traffic is not. Verified live after the revert -
one client through Cloudflare with a junk `X-Forwarded-For` and the same client connected directly
with a junk header were both recorded as `from 157.15.139.236`, and `xray api statsonline` counted
the two real addresses (value 2).

**Rule for future changes:** do not put a trusted-proxy range list on the IP-limit path, and keep both
fallbacks in the `$clientRealIp` map. The nginx config carries a short note pointing here.

### Correction to section 24 - the mechanism is the references' own, not our map

Section 24 described the counted address as coming from the panel's `$clientRealIp` map. Checked
against the archives, that is not what the tree does, and it should not: **both references already
handle this.** They set `X-Real-IP $remote_addr` and `X-Forwarded-For $proxy_add_x_forwarded_for` in
every Xray location (the same with `grpc_set_header`), and Xray takes the **first** entry of that
chain - the real client behind Cloudflare, the peer for a direct connection. Their
`map $http_x_forwarded_for $clientRealIp` exists only for the access log, not for the headers.

Our `$clientRealIp` header substitution (fix 153) and the `set_real_ip_from` range list (fix 154,
refresher 156/157) were both inventions and are reverted; the configs and the live host carry the
references' lines unchanged and the map is log-only again. So section 24's rule stands - do not
harden the IP-limit path - with its other half now explicit: **if the reference already solves it,
keep the reference's solution.**

Verified live with the references' form: a client through Cloudflare is recorded as
`from 202.155.17.126` (the real address, not the edge) and `statsonline` counts it. A brand-new
Cloudflare range changes nothing, because no range list is involved.

## 25. The Panel's Default Dropbear Is 2019.78, Not the Distribution's Build

**The owner's decision is that Dropbear 2019.78 is the default**, and it is a divergence from both
references on purpose: their `installer/ssh.sh` runs `apt install dropbear -y` and takes whatever the
distribution ships - 2022.83 on Debian 12, 2020.81 on Debian 11, 2022.83 on Ubuntu 22.04 - so the
serving binary changed with the base image. The panel now pins one version on every base.

**How the pin is applied.** apt is still what installs Dropbear, because the service plumbing - the
`/etc/init.d/dropbear` script, the `dropbear.service` unit, the `dropbear` user and the host keys -
comes from the distribution and the panel's own tooling assumes it. `installer/ssh.sh` then builds the
2019.78 binaries from the upstream source tarball and installs them over the package's
(`/usr/sbin/dropbear`, `/usr/bin/dropbearkey`, `/usr/bin/dropbearconvert`). The tarball is vendored in
`rohjagad/fn-autosc-miscellaneous` (`main` and the `v1.23` release) and is checked against
`sha256 525965971272270995364a0eb01f35180d793182e63dd0b0c3eb0292291644a4` before it is compiled, with
`matt.ucc.asn.au` as the last fallback. The build is skipped when `dropbear -V` already reports
`v2019.78`, so re-running the installer is idempotent. `dropbear-bin` is set on `apt-mark hold`, so a
later `apt upgrade` cannot quietly put 2022.83 back; the `dropbear` package itself (the plumbing) is
not held. `zlib1g-dev` is installed for the build (`package.sh` and, defensively, `ssh.sh`).

**What to expect from the older build.** 2019.78 predates ed25519 host keys and the RSA-SHA2
signatures, but it still negotiates with current clients over its **ECDSA** host key, so password
authentication is unaffected. The Debian package generates no DSS host key, so 2019.78 logs one
harmless `Failed loading .../dropbear_dss_host_key` warning on start; no DSS key is fabricated, because
DSA is weak and current clients do not need it. It is also built **without PAM**, exactly like the
Debian package (which is why `expire-ssh.sh` writes to the shadow file directly, bug 72), so account
ageing behaves the same. The panel's SSH tooling reads the journal for
`Password auth succeeded for '<user>'` lines, and 2019.78 emits the identical line - `limit-ip-ssh.sh`
and `cek-login-ssh.sh` need no change.

**Verified live** on the Debian 12 test VPS: the installer's Dropbear section built and installed the
binary (`Dropbear v2019.78`, `dropbear-bin` shown as held), the service came up `active` on 111, 109
and 69, the ident changed to `SSH-2.0-dropbear_2019.78`, a real password login through 2019.78 on port
109 succeeded (journal `Password auth succeeded for 'dbtest'`), and the same account with a wrong
password was refused with exit 5. The test VPS now runs 2019.78.

**Scope:** the full edition only. Lite never runs `installer/ssh.sh` and disables the Dropbear service
(fix 149), so its binary version is irrelevant.

**Rule for future changes:** the Dropbear version is one value, held by this pin - do not let one base
image's apt version decide it, and if the pin is ever raised, change the tarball, its sha256 and this
section together.

## 26. Version Strings Live in Their Own Submenus, Not the Main Menu

**The owner's decision is that the main menu is too crowded for version lines**: the XTLS/Xray
version belongs in the XTLS menu and the Dropbear version in the SSH menu. Both references put
`VERSION XTLS : $xver` on the main menu (their `full/menu.sh` computes `xver` from `xray version` at
the top and prints it near the header), so dropping it is a deliberate divergence, not an oversight.

**What moved.** The XTLS version is now `XTLS Version :` inside `full/menu-x.sh`, and the main menu no
longer computes or prints `xver` at all. The Dropbear version is a new `Dropbear Ver :` line in
`full/menu-ssh.sh`, read as `dropbear -V` (so it shows the pinned `v2019.78`, decision 25). Both are
read with a `2>/dev/null` guard and fall back to `unknown` when the binary is missing, so neither
menu can fail on a host where the daemon was not installed.

**Lite.** Lite has no SSH menu (it ships no SSH tooling), so there is nothing to add there. Its main
screen *is* the XTLS menu - `lite/menu.sh` defines `menu-x()` and shows it directly - so the XTLS
version was added to it, which also gives lite a version display it never had: the references and the
old lite build showed none anywhere.

**Verified live** on the Debian 12 test VPS after repacking and deploying: the full main menu no
longer prints a version line, the XTLS menu shows `XTLS Version : 25.3.6`, the SSH menu shows
`Dropbear Ver : v2019.78`, and the lite menu shows `XTLS Version : 25.3.6` on its XTLS screen.

**Rule for future changes:** status/version strings belong on the menu they describe; keep the main
menu to server identity, counts, service state and the menu list.

## 27. The SSH Menu Lists the Version of Every Service an SSH Account Uses

**The owner asked that the SSH menu show all the SSH-associated services, not only Dropbear** -
OpenSSH and OpenVPN being the examples - because the account card advertises a whole stack and the
menu should reflect it. Neither reference shows any service version (their menus print only the
main-menu XTLS line), so this is a new, owner-requested display, not inherited behaviour. It replaces
the single `Dropbear Ver` line added in decision 26.

Each value comes from the tool's own `--version`-style output and falls back to `n/a` when the binary
is absent, so the menu still renders on a partial install:

| Menu label | Account-card line | Command |
| :-- | :-- | :-- |
| `OpenSSH` | `OpenSSH : 22, 3303` | `ssh -V` (prefix trimmed) |
| `Dropbear` | `Dropbear : 111, 109` | `dropbear -V` |
| `WS ePro` | NonTLS/TLS ports | `ws version` |
| `Stunnel5` | `STUNNEL5 : 777` | `stunnel -version` |
| `HAProxy` | `STUNNEL5 : 777` | `haproxy -v` |
| `Squid` | `HTTP Proxy : 3128` | `squid -v` |
| `OHP` | `OHP : 9088` | `fnohp --version` |
| `OpenVPN` | `OVPN TCP/UDP : 1194 / 2200` | `openvpn --version` |
| `BadVPN` | `BadVpn/Udpgw : 7300` | `badvpn-udpgw --version` |

**Deliberately not listed:** SlowDNS/DNSTT, because it has its own menu (`menu-dnstt`); and UDP Custom
and UDP Request, which are advertised on the card but report no version at all - `udp-request` has no
`--version` flag and treats an unknown one as a start command, so it is never invoked from a menu.

**Verified live** on the Debian 12 test VPS: the header renders `OpenSSH 9.2p1`, `Dropbear v2019.78`,
`WS ePro v1.2.3`, `Stunnel5 5.68`, `HAProxy 2.6.12`, `Squid 5.7`, `OHP 0.1 beta`, `OpenVPN 2.6.14`,
`BadVPN 1.999.130`, in two columns inside the SSH menu.

**Rule:** this block mirrors the account card's service list - when a service is added to the card,
add its version here too - and a menu must never invoke a daemon merely to read a version (only a flag
that prints and exits).

### Correction to section 27 - the block is the four SSH front-ends, not the whole stack

Section 27 listed nine services. The owner narrowed it to **the services a client actually connects
through** - the SSH front-ends the account card shows as connection methods: **OpenSSH, Dropbear,
WS ePro (the SSH WebSocket) and Stunnel5 (777)**. HAProxy (the implementation behind 777), Squid, OHP,
OpenVPN and BadVPN are associated with SSH but are not SSH front-ends, so they are no longer shown.
The block is four lines in a single column, which also removes the two-column `printf`.

Verified live after the change: `OpenSSH 9.2p1`, `Dropbear v2019.78`, `WS ePro v1.2.3`, `Stunnel5 5.68`,
in the SSH menu's existing layout.

## 28. A "lifetime" Auth Entry Means Auth Is Off, and Date-Licensed Machines May Not Use WARP

**The owner's two rules, both driven by what is written in `fn-autosc-auth`'s `izin.txt`:**

1. **If the entry's date field is `lifetime` instead of a date, auth is off.** Every copy of the
   licence gate (192 files across `full/`, `lite/` and `installer/`) now checks
   `EXPIRED_DATE = "lifetime"` first and skips the expiry validation, printing `Expired: lifetime`.
   The membership check (the machine must still be listed) is unchanged. Because the installer
   scripts carry the same gate, a lifetime machine is detected **at installation** - it installs
   without a date instead of dying in `calculate_remaining_days` with "Invalid expiration date".
   No `fn-autosc-auth` entry uses `lifetime` yet; the code is ready for the first one.

2. **If the entry has an expiry date, the panel must not enable WARP.** WARP moves egress through
   Cloudflare, the licence gate then sees an unlisted IP, and the whole panel locks the operator
   out (Found 168) - so on a date-licensed machine WARP would break the very license it runs
   under. `install()`, `enable()` and `restart()` in the Cloudflare WARP submenu (both editions)
   now refuse unless `$EXPIRED_DATE` is `lifetime`, telling the operator why. `install()` and
   `restart()` are guarded too, not just `enable()`: installing brings `wgcf` up de facto, and
   `systemctl restart` would start an inactive `wgcf` - same hazard, same guard. `disable()`,
   `status()`, the Teams token and the account creation do not change routing and are untouched.
   The WireGuard menu's "Add Cloudflare WARP" only adds a peer route to `wg0` (`172.16.0.0/24`),
   never moves egress, so it is not guarded.

**Verified live** on the dated test VPS (`vps-audit`, 2027-12-31): Install, Enable and Restart all
print the refusal and leave `wgcf` down with egress unchanged. The lifetime path was executed
from the deployed `enable()` with a stubbed `lifetime` date: `Done Enable Warp`, `wgcf` up,
egress moved to a WARP address, then restored with a direct `systemctl` (not the menu, per
Found 168). A unit harness confirmed the patched gate: `lifetime` exits 0, a future date exits
0, a past date exits 1, and garbage/empty inputs behave byte-for-byte as the original code did
(the `exit 1` inside `calculate_remaining_days` never escaped its command substitution, before
or after - a pre-existing quirk, out of scope).

**Rule for future changes:** where the licence gate remains, it stays one shape - any new
exemption goes in the same `if`, and any new feature that moves egress must take the same WARP
guard. Section 43 narrows where the gate runs: the WARP guard is now called only inside the WARP
install/enable/restart/add actions, not at menu entry, and most maintenance scripts no longer
carry a gate at all. The "192 files" count above is historical. `fn-autosc-auth` itself is only
ever read, never written, by this panel.

## 29. The Licence Gate Races Both Sources; First Valid Reply Wins

- **Component:** all permission gates (`PERMISSION_CFPAGES` / `PERMISSION_GITHUB`) across `full/`, `lite/`, `installer/`, plus `menu-api`.
- **Decision:** every gate fetches `https://fn-autosc-auth.pages.dev/izin.txt` and `https://raw.githubusercontent.com/rohjagad/fn-autosc-auth/main/izin.txt` **at the same time** and takes the first *complete, valid* reply (OR logic instead of sequential fallback). A reply counts only when its download finished (`.done` marker, so no truncated reads) and it contains `###` — a fast error page is skipped, not trusted. Overall bound 15s (each fetch capped at 12s). Both sources carry byte-identical content, so whichever wins changes nothing semantically — and when both fail the gate still fails closed with `Failed to download permissions.` before any mutation. This supersedes the earlier Pages-first/sequential-fallback form: the race is faster on slow runs (measured 5.3s Pages vs 0.6s GitHub once — the race takes the fast one), immune to a slow-primary stall, and additionally hardened against trusting an error page (the old `curl -s ... || curl ...` never fell through on HTTP errors since `curl -s` exits 0).
- **Reason:** sequential fallback waits out the primary's full timeout before trying the backup, and never tries the backup at all on HTTP-error-with-exit-0. Racing costs one extra parallel request per gate run and removes both weaknesses.
- **Verified live:** race takes ~1s on the VPS with 7 `###` entries; temp dir removed; fail-closed on double failure.
- **Blackout behavior (verified live, both sources blocked):** established connections are never interrupted — a live tunnel carried clean rounds straight through blackouts with 0 failed units, 0 spurious restarts and 0 config changes. **Superseded in part by section 43:** the fail-closed set is now only create/extend/install; menus, deletes, and maintenance do not contact auth at all. The dual-source race and the fail-closed behavior for the remaining gated actions are unchanged.

## 30. The SplitHTTP Transport Is Fully Renamed to XHTTP

- **Component:** every `split` identifier — `*-split.sh` → `*-xhttp.sh`, `split.json` → `xhttp.json`, service `xray@split` → `xray@xhttp`, data dirs, function/var names, menus, cron entries, and API `core=split` → `core=xhttp`.
- **Decision:** Xray 25.x renamed SplitHTTP to XHTTP, so the panel follows completely rather than keeping a dual vocabulary that would confuse every future change. Wire strings (`network: xhttp`, `xhttpSettings`, paths `/vmxh`, `/vlxh`, `/trxh`, link `type=xhttp`) and all identifiers move together. The single exception is a one-line legacy alias in the API handlers (`split` → `xhttp`) so old API clients keep working; language builtins (`strings.Split`, awk `split()`) are untouched.
- **Reason:** a half-rename (wire-only, as first done) leaves two names for one thing across scripts, units, JSON, cron and API — precisely the kind of drift that causes future bugs. One name everywhere costs a data-preserving migration once and ends the ambiguity permanently.
- **Verified live:** migrated account intact, new account card shows `/vmxh` + `XHTTP`, 5 MB traffic checksum-identical, `xray@xhttp` active, 0 failed units.

### Addendum to section 24 - gRPC is the exception (Found 502, Fix 504)

The correction above says the references' header form suffices everywhere. Live-proven
2026-10-10 it does not for gRPC: xray 25.3.6's grpc transport reads ONLY the `x-real-ip`
metadata (`transport/internet/grpc/encoding/hunkconn.go`) and ignores `X-Forwarded-For`,
so with the reference form (`X-Real-IP $remote_addr`) gRPC via CDN still logs the edge
(`from 104.23.232.44`, never the client). The owner's accuracy rule (1 = 1) wins here:
all three configs add a `$grpcRealIp` map (`CF-Connecting-IP`, falling back to
`$remote_addr` for direct traffic) and the 12 `grpc_set_header X-Real-IP` lines use it.
No proxy range list is involved; a direct client forging the header is the same accepted
trade as the XFF rule above. WS/HTTPUpgrade/XHTTP keep the references' form untouched.

### Addendum 2 to section 24 - operator chose uniformity (Fix 505)

Fix 504's `$grpcRealIp` (`CF-Connecting-IP`) map is replaced by `$xffFirst` (first XFF
entry, peer fallback): same honest-traffic accuracy (re-proven live: single, dual-source,
and direct all log real IPs; limiter stays quiet), with forged first entries now counted
as-is on gRPC exactly as on WS/HTTPUpgrade/XHTTP. One trust rule on all four transports,
no Cloudflare-only header anywhere, zero `grpcRealIp` remnants in tree or test box.

## 31. 777 TLS Clients Are Mapped via HAProxy Start-of-Session Logs

- **Component:** `installer/stunnel5.sh`, `update.sh`, `full/ssh-online.sh`, `full/menu-ssh.sh`.
- **Decision:** the `777` front-end keeps HAProxy as the TLS terminator but enables `option logasap` plus a `local0` log target. HAProxy then emits the client address and accept timestamp as soon as the backend connection is established, not when the SSH session closes. `ssh-online` reads `/var/log/haproxy.log`, its `.1` rotation, and `journalctl -u haproxy`, then matches each `127.0.0.1` Dropbear child to a distinct accept line (accept <= child, 5 s tolerance, 6 s scan padding, 100 ms clock skew). The match is one-to-one, so two simultaneous 777 clients do not share one evidence line.
- **Reason:** Dropbear cannot see the real client behind HAProxy; without start-of-session evidence, every 777 client collapses to `127.0.0.1`, bypassing the SSH IP limit and showing a false single IP in the menu. Enabling logging only on close would leave active sessions unmapped.
- **Safety:** the updater validates the patched config with `haproxy -c` and restores the original on failure. It checks `log /dev/log` inside `global` and `logasap`/`log global` inside the `ssh-ssl` frontend, so a directive in another frontend cannot mask a missing 777 log. If no evidence matches, the session stays `127.0.0.1` and the menu warns; the helper never invents an IP. The patch is full-edition only because lite ships no SSH menu/limiter.

## 32. SSH IP-Lock Enforcement Is Per-Account, Not a Global Restart

- **Component:** `full/limit-ip-ssh.sh`, `full/ssh-online.sh`, `full/cek-login-ssh.sh`.
- **Decision:** when the stable over-limit IP set is confirmed, the limiter runs `passwd -l` and then `pkill -KILL -u <user>` for that account only. It does not restart `ssh`, `sshd`, or `ws`. The 15-minute auto-unlock sweeper runs before the `ssh-online` availability check, keeps its due file until `passwd -u` succeeds and the account is no longer `L`, and falls back to the due file mtime (or now + 900) when the content is corrupt.
- **Reason:** `passwd -l` only blocks new authentications; existing over-limit sessions would keep running. The old global restart did terminate them, but it also dropped every other SSH/WS user. A targeted kill enforces the lock without collateral damage. Moving the sweeper ahead of the helper check prevents a missing/broken `ssh-online` from freezing every lock forever.
- **Trade-off:** the offending account loses all its current sessions (including any allowed one) for the lock period. That is the intended meaning of an over-limit lock; manual locks still have no due file and remain indefinite.

## 33. `/usr/bin/restore-ftp` Belongs to the Website Restore Path

- **Component:** `update.sh`, `website/install.sh`, `website/upload.php`, `full/bmenu.sh`, `full/restore-ftp.sh`.
- **Decision:** `/usr/bin/restore-ftp` is always the non-interactive `website/restore-ftp.sh` variant that reads `/var/www/uploads/*.zip`; `update.sh` downloads it from `website/` and keeps the interactive full/lite restore scripts out of that path. Interactive restore remains available through `bmenu`.
- **Reason:** `website/upload.php` calls `sudo /usr/bin/restore-ftp`; replacing it with the license-gated TUI script breaks the web restore endpoint (the old updater did exactly that). The website variant also carries the Found 511 version-marker/formatter guard.
- **Safety:** the updater backs up the current command and aborts before installing anything if the website script fails its syntax/marker check.

## 34. Expired SSH Accounts Are Removed Without Restarting Shared Daemons

- **Component:** `full/xp.sh`, `lite/xp.sh`.
- **Decision:** the Auto Remove SSH branch kills only the expired account (`pkill -KILL -u <user>`) before `userdel --force`, then removes that account's limit/card files. It does not run `daemon-reload` or restart `ssh`, `sshd`, `ws`, or `dropbear`.
- **Reason:** `passwd`/`userdel` do not terminate live sessions, so the old code restarted every daemon to kick one expired user. That dropped every other OpenSSH, SSH-over-WS, and Dropbear session, and on Dropbear it left the old child processes in the cgroup anyway. A targeted kill enforces the expiry without collateral damage; the daemons see the deleted account on the next authentication attempt.
- **Trade-off:** all processes of the expired account are killed, including any non-SSH process it owns. The account is being deleted, so that is intended. The Xray expiry branches still restart their per-transport unit because Xray 25.3.6 has no per-user remove CLI; that remains a separate follow-up.

## 35. The Payload Manifest Owns the Web Restore Command

- **Component:** `menu/full.manifest`, `menu/lite.manifest`, `installer/payload.sh`, `tools/verify-payload.sh`.
- **Decision:** `restore-ftp` is a `web` manifest entry sourced from `website/restore-ftp.sh`; the payload helper downloads, syntax-checks, and installs that variant to `/usr/bin`. The interactive `full/restore-ftp.sh` and `lite/restore-ftp.sh` are not payload targets; interactive restore remains in `bmenu`.
- **Reason:** Fix 514 fixed the updater but left the installer/standalone payload path able to overwrite the web command with the license-gated TUI script, breaking `website/upload.php`. One manifest kind makes fresh install, repair, and update agree. The same change raises every payload download timeout to 600 seconds.
- **Safety:** a missing or invalid `website/restore-ftp.sh` aborts the whole payload before any destination file is replaced; the updater keeps its separate `WEB_FILES` verification.

## 36. The Updater Starts From the Live Version Marker

- **Component:** `update.sh`.
- **Decision:** the starting version is read at runtime from `/etc/funny/.update-commit` (last applied update), then `/etc/funny/.install-commit` (fresh install). Empty and `Unknown` markers are skipped, and the documented `6b967af` live v1.23 value is only a fallback when neither marker is usable. The target stays pinned at the latest deployable commit (currently `aa75243d5230512f24c7ea84eeef0211eebc64f2`, Fix 528).
- **Reason:** the full-file updater does not need a Git ancestry walk, but the header, startup line, and `UPDATE SUCCESS` message must report the actual live version. A hardcoded `5c48741` became stale once the live box moved to the v1.23 marker.
- **Safety:** `FROM` is display/history only; it is never used to fetch files. A malformed marker cannot change which files are downloaded, verified, or installed, and the existing `Already at $TARGET` check still compares only `TARGET`.

## 37. Domain Names Separate the Installer Domain From Rotated Domains

- **Component:** `installer/full.sh`, `installer/lite.sh`, `installer/diamond.sh`, `full/dm-menu.sh`, `lite/dm-menu.sh`, all `add-*`/`trial-*` scripts, `menu-wg.sh`, `xl2tp.sh`, `menu-noobz.sh`, backup/restore, `update.sh`, `full/limit-ip.go`.
- **Decision:** `/etc/xray/installer-domain` is the single installer domain; `/etc/xray/rotated-domains` is the independent rotation list; `/etc/xray/.rotated-domainseq` is the round-robin counter. Account cards show `Installer Domain` and the assigned `Rotated Domain`; L2TP/NoobzVPN show the rotated list because they have no per-account link. The domain list computes counts from account cards/configs per domain and protocol. (Decision 38 refines the installer domain's membership: it is seeded on fresh install but remains removable from the rotated list.)
- **Reason:** the old `domain`/`domains` names, `domain`/`rdomain`/`alldom` variables, and `Domains :` card row mixed the installer value, the full set, and the assigned value. The list screen repeated global totals under every domain, which looked like every domain owned every account.
- **Safety:** `update.sh` copies legacy files to the new names before installing, keeps them until the install succeeds, and backs them up; restore normalizes old backups. The rotation algorithm, link hosts, certificate handling, and account lifecycle are unchanged. Counts fall back to link/`Endpoint` parsing for existing cards, and missing data becomes 0/unknown rather than an error. Decision 38 makes the rotated list independent and adds a blocking notice when it is empty.

## 38. The Installer Domain Is an Anchor, Not an Implicit Rotated Entry

- **Component:** `installer/full.sh`, `installer/lite.sh`, `full/dm-menu.sh`, `lite/dm-menu.sh`, all `add-*`/`trial-*` scripts, `full/menu-wg.sh`, `full/xl2tp.sh`, `full/menu-noobz.sh`, restore paths, `update.sh`, `README.md`.
- **Decision:** `/etc/xray/installer-domain` remains mandatory for Nginx and certificates. `/etc/xray/rotated-domains` is a separate list that controls account-link hosts. A fresh install seeds the installer domain as the first rotated entry, but that entry is removable from the list and the file itself is never removed. New account links use only the rotated list. If the list is empty, Xray/SSH/WireGuard account creation stops with a notice; L2TP/NoobzVPN continue because they have no per-account domain.
- **Reason:** the previous implicit prepend made the installer domain permanently unremovable and made an empty rotated list impossible, so the UI could not express “no rotated domain configured.” Removing the implicit prepend without a guard would instead index an empty array and emit empty-domain links.
- **Safety:** `update.sh` and restore seed the installer domain only when converting a legacy layout; an existing new-format list, including an empty one, is left untouched. `server_name` and certificate selection still include the installer domain even when it is not in the rotated list, and duplicate `server_name` entries are removed. Account scripts show a blocking notice before any account is created, and no sequence counter is advanced on the empty path.

## 39. Version Markers Are Resolved, Validated, and Displayed Explicitly

- **Component:** `installer/full.sh`, `installer/lite.sh`, `full/menu.sh`, `lite/menu.sh`, `update.sh`, `README.md`.
- **Decision:** a fresh install records the current `main` SHA from the GitHub API `/repos/rohjagad/fn-autosc/commits/main`, with `git ls-remote` as a fallback. The main menu shows the first seven characters of `.install-commit` and `.update-commit`; if a marker is missing or invalid it shows `not recorded` / `not updated` instead of `Unknown`. When the install marker is invalid and an update actually changes the version (`FROM` differs from `TARGET`), `update.sh` records the detected live version in `.install-commit` as the baseline.
- **Reason:** the old API URL omitted `/repos`, returned 404 on every fresh install, and wrote `Unknown`; the menu then echoed `Unknown` for both markers, making a healthy fresh install look broken. A missing update marker also means “never updated”, not “unknown”.
- **Safety:** API and git failures are non-fatal and still write a marker (`Unknown`) so installation continues; the menu degrades to `not recorded`. Backfill only runs when the install marker is missing/invalid, only uses a 40-character hex `FROM`, and only when `FROM` differs from `TARGET`. It records the last live version as a baseline; a same-target rerun does not overwrite the marker. A valid install marker is never changed.

## 40. The xHTTP JSON Lock Covers Mutation, Not Network I/O

- **Component:** `full/quota-xhttp.sh`, `full/kill-xhttp.sh`, `full/limit-ip-xhttp.sh`, `full/xp.sh` and their lite copies.
- **Decision:** `/tmp/xray-json-xhttp.lock` is held only while re-checking and mutating `xhttp.json`, moving/removing account files, or running the fast `xray run -test`. Xray API calls, Telegram `curl`, and `systemctl restart` happen outside the lock. `quota-xhttp` also writes `_usage` files outside the lock because that daemon is their only writer.
- **Reason:** a slow stats call, Telegram timeout, or service restart held the shared lock long enough for `xp`, `kill-xhttp`, and `limit-ip-xhttp` to report `xhttp.json busy, skipping`. The Xray API is the fragile part; it must not serialize unrelated maintenance.
- **Safety:** every candidate is re-checked inside the lock, so two jobs cannot delete the same account twice. `limit-ip-xhttp` keeps its stable-IP state until a deletion succeeds; a busy lock retries next run. Notifications run after the mutation, preserving the Found 500 rule that file state is consistent before a blocking Telegram call.

## 41. The WS Client/Open Pair May Arrive in Either Order

- **Component:** `full/ssh-online.sh`.
- **Decision:** when resolving a Dropbear child behind `ws:2080`, match the nearest `client:` line to the nearest `opened` line by absolute timestamp, within the existing 50 ms window. Do not assume `client:` always precedes `opened`.
- **Reason:** live journald showed `opened` at `.599321` and `client: 140.213.65.123` at `.601549` for the same session (2.2 ms later). The old one-way check skipped the client line and left the session as `127.0.0.1`, so the menu warned and the limiter counted loopback as one IP.
- **Safety:** the 50 ms window and nearest-timestamp choice keep the pair distinct from the next connection; HAProxy matching remains one-way (accept <= child) because HAProxy must connect to the backend before Dropbear starts.

## 42. Every Live Update Goes Through the Updater

- **Component:** `update.sh`, `README.md`, `project-information/`.
- **Decision:** installed files change only through `update.sh`. A fix is committed, `TARGET` is advanced to that commit, and the updater downloads, verifies, backs up, and installs the whole payload. Copying scripts to a live box or editing installed files in place is not an update path.
- **Reason:** a direct copy leaves `.update-commit` pointing at the old content, so the live box silently drifts and the next updater run reverts the copy. Fix 524 had to be installed by hand only because the updater target was deliberately held at `2833d8d`; that gap is now closed by adding `quota-xhttp` and `kill-xhttp` to the payload and advancing the target to `2c2b3f7`. The updater has since been run on all three live boxes, which now record `2c2b3f7`.
- **Safety:** the updater verifies every download before touching the live files and aborts without changes on any mismatch. Break-glass recovery that cannot wait for an updater run is not an update; it must be followed by an updater run so the code and `.update-commit` converge again.

## 43. The Licence Gate Only Guards Create, Extend, and Install

- **Component:** `full/`, `lite/`, `install.sh`, `installer/*`, `update.sh`, `README.md`.
- **Decision:** the authorization sources are contacted only for (a) installation (`install.sh` and every `installer/*` script), (b) creating a new account (`add-*`, `trial-*` including `trial-ssh`, `addssh`, the WireGuard/L2TP/NoobzVPN create actions, and Cloudflare WARP account creation), and (c) extending an account (`extend-*` and the WireGuard/L2TP extend actions). Every other command — the main/XTLS/SSH/domain/system/backup menus, delete/change/change-quota, quota/kill/limit-ip/auto-delete/expiry daemons, routing, list/locked/unlock, backup/restore, and service management — runs without any auth fetch.
- **Reason:** the old all-script gate made operational work depend on a remote list. A dual-source outage made every menu and maintenance command fail closed even though the data plane (systemd, cron, Xray) was healthy. The owner wants both permission sources to be able to disappear without changing the VPS's running state; only billable actions should wait for authorization.
- **Implementation:** dedicated create/extend commands keep the top-level race gate. Menus that mix create/extend with management (`menu-wg`, `xl2tp`, `menu-noobz`, `menu-system`) define a `license_gate()` helper and call it only in the create/extend actions (including WARP install/enable/restart/add), so delete/list/status/service actions remain usable offline. The WARP guard from section 28 remains: it runs inside those WARP actions after a successful gate, and a date-licensed machine is still refused. The WireGuard menu's WARP peer add is gated as account creation even though it does not move egress.
- **Safety:** the gate still runs before any mutation in every gated action; on double failure it returns/exits before `useradd`, config writes, or package installation. `install.sh` now races both sources like the sub-installers. The updater ships every changed maintenance script and every `extend-*`; `full`/`lite` `restore-ftp.sh` remain source-only because the live web restore command is `website/restore-ftp.sh`.
- **Verified live (2026-11-02):** all three boxes moved from `2c2b3f7` to `a726c4a` through the updater. Installed maintenance scripts have no auth fetch; `menu` and `menu-system` option 5 completed with zero auth calls; installed `add-vmess-ws`, `extend-ws`, and `trial-ssh` exited 1 with `Failed to download permissions.` when both sources were stubbed unreachable; the installed `license_gate()` returned 0 for a stubbed lifetime entry and 1 for a double failure; all quota/Xray/Nginx/HAProxy/SSH units stayed active and no failed units or new lock/expiry errors appeared.
- **Superseded in part by section 45:** the main menu now reads the authorization list to display the licence username, VPS IP, and expiry. That read is bounded and display-only — it never gates the menu and falls back to a cache — so the operational-access rule in this section still holds. All other non-gated commands still make no auth fetch.

## 44. The Backup Telegram Message Always Carries a Validated IPv4

- **Component:** `full/backup.sh`, `lite/backup.sh`, `update.sh`, `README.md`.
- **Decision:** the public IPv4 in the backup message is resolved by trying `ifconfig.me`, `ipv4.icanhazip.com`, `api.ipify.org`, and `ipinfo.io/ip` with an 8-second bound each, validating every reply as a dotted-quad IPv4, and falling back to `/etc/.ip` (written at install) only when all probes fail. If no valid address is available, the message says `unknown` instead of leaving the field blank.
- **Reason:** live rohserver3's `/etc/funny/backup.log` had three empty `IP     :` entries (12-Oct-2026, 20-Oct-2026, 01-Nov-2026 15:00) while rohserver6 and rohserver1 had none. The old one-shot `curl -4 -s ifconfig.me` had no timeout, no validation, and no fallback, so a transient resolver or endpoint failure produced a permanently blank field in the Telegram caption and log.
- **Safety:** the probes are read-only and bounded; a failure changes only the displayed address, never the archive or the backup contents. `/etc/.ip` is root-owned and installer-written, is used only after every live probe fails, and is validated before use. `update.sh` marker-checks `backup` with `Found 526`.
- **Verified live (2026-11-02):** the updater moved all three boxes to `cc1bf90`; the installed `backup` carries `Found 526`. On each box the installed helper returned the correct live IPv4, returned the same address from `/etc/.ip` when every probe was stubbed to fail, and still returned it when the probes returned an invalid HTML body. The generated message line was `IP     : 64.120.94.62` / `103.210.69.33` / `157.10.253.95`; no test Telegram backup was sent, so the next scheduled backup will be the first production message using the new path.

## 45. The Main Menu Shows the Licence Identity Without Gating

- **Component:** `full/menu.sh`, `lite/menu.sh`, `update.sh`, `README.md`.
- **Decision:** the main menu restores the three licence identity lines — `Username`, `IPv4`, and `Expired` — that Fix 525 removed together with the gate. `output()` calls `license_display()`: it races `fn-autosc-auth.pages.dev/izin.txt` and the GitHub copy for up to four seconds, accepts only a payload containing a four-field `###` line, matches the live IPv4 (falling back to `/etc/.ip`), and prints the old `lifetime` or `date (N days)` expiry format. A successful match is cached at `/var/lib/fn-autosc/license-info`; if both sources are unreachable, the cached line is shown with `(cached)`, otherwise `unavailable` / `not checked`. The menu never exits or blocks on auth.
- **Reason:** Fix 525 correctly removed the gate from operational menus, but the gate and the licence display shared one block, so the identity disappeared as collateral damage. The operator expects the main menu to show the licence username, VPS IP, and script expiry. This restores the information without restoring the fail-closed behaviour.
- **Safety:** the auth read is display-only and bounded; no mutation or gate depends on it. The cache is root-only (`0600`), lives outside the backup staging paths, and is accepted only when its IP matches the live IPv4 or `/etc/.ip`, so a stale entry from another address is ignored. A reachable list that does not contain the IP clears the cache and shows `unlicensed`; a source outage keeps the last good match. The main menu remains fully usable when both sources fail. `update.sh` marker-checks `menu` with `Found 527`.
- **Verified locally:** a 14-case harness covered a live lifetime entry, a dated entry with the computed day count, Pages failing while GitHub succeeds, a slow Pages probe losing to a fast GitHub reply, offline cache for both lifetime and dated entries, a cache from a different IP, no cache, invalid HTML bodies, a reachable list without the IP (cache cleared), a malformed `###` line, and IPv6 display falling back to `/etc/.ip`. `output()` integration printed the three licence lines plus both version lines for live, cached, and unavailable states. `bash -n` passes for both menus and `update.sh`; the updater marker harness passes at 100 full / 89 lite scripts.
- **Verified live (2026-11-02):** updater `19906ff` (target `d2d61da78afdf784241192c436c8a37b4bff0655`) moved all three boxes from `cc1bf90` to `d2d61da`; each reported `UPDATE SUCCESS` and `.update-commit` matches. The rendered menu showed `Username : SG1/ID1/ID2`, `IPv4 : 64.120.94.62 / 103.210.69.33 / 157.10.253.95`, `Expired : lifetime`, and versions `6b967af` / `d2d61da`. The cache was `-rw------- root root` with the matching `###` line. With a fake `curl` failing every request, the full menu still rendered on all three with the `(cached)` identity and returned 0; no authorization gate ran. All 12 checked services stayed active and `systemctl --failed` was empty. Backups: `/root/fn-update-backup-20261102-115104` (rohserver6), `-035104` (rohserver1), `-115104` (rohserver3).

## 46. The Licence Block Uses a Section Heading

- **Component:** `full/menu.sh`, `lite/menu.sh`, `update.sh`, `README.md`.
- **Decision:** the licence identity and version lines are grouped under a purple `LICENSE` heading, matching the `TOTAL ACCOUNTS` and `MENU` headings, instead of appearing as unlabelled text at the bottom of the dashboard. The heading is emitted by the menu template immediately above the captured `output()`/`rerechan` block, so the five lines stay together: `Username`, `IPv4`, `Expired`, `Installed version`, `Updated version`.
- **Reason:** operator request. The five lines are one section and should be visually separated and labelled like the other dashboard sections.
- **Safety:** display-only. No auth, cache, gate, or mutation behavior changed. `update.sh` marker-checks `menu` with `Found 528`.
- **Verified locally:** `bash -n` passes for both menus and `update.sh`; the rendered template places `${purple}LICENSE${NC}` immediately above the licence/version block in both editions; the updater marker harness passes at 100 full / 89 lite scripts.
- **Verified live (2026-11-02):** updater `b505a19` (target `aa75243d5230512f24c7ea84eeef0211eebc64f2`) moved all three boxes from `d2d61da` to `aa75243`; each reported `UPDATE SUCCESS` and `.update-commit` matches. The rendered menu showed `LICENSE` immediately above `Username`, `IPv4`, `Expired`, `Installed version`, and `Updated version` on all three. With a fake `curl` failing every request, the same block rendered from cache with `(cached)` values and returned 0. All 12 checked services stayed active and `systemctl --failed` was empty. Backups: `/root/fn-update-backup-20261102-121208` (rohserver6), `-041208` (rohserver1), `-121208` (rohserver3).

## 47. Backup IPv4 Validation Rejects Non-Numeric Octets

- **Component:** `full/backup.sh`, `lite/backup.sh`, `update.sh`.
- **Decision:** the backup IP helper accepts only four octets that are entirely digits and each at most 255. `get_public_ipv4()` applies that check to every probe reply and to the `/etc/.ip` fallback; malformed replies are skipped and the next source is tried.
- **Reason:** Fix 526 used `awk -F. 'NF==4 && $1<=255 && ...'`, which accepted a body such as `1.2.3.-4` because awk compared `-4` numerically. That contradicted Decision 44's requirement for a validated dotted-quad and could put a malformed value into the Telegram caption.
- **Safety:** valid IPv4 addresses behave exactly as before; the four bounded probes and `/etc/.ip` fallback are unchanged. A malformed probe now costs one skipped source, not a display failure. `update.sh` marker-checks `backup` with `Found 529`.
- **Verified locally:** a 16-case harness covered valid, boundary, negative, alphabetic, over-255, wrong-octet-count, empty, live-probe, fallback, and cache cases; all passed. `bash -n` passes for both backup scripts and `update.sh`; the updater marker harness and payload verification pass.
