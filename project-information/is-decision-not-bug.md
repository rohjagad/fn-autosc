# Architectural Decisions (Not Bugs)

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
