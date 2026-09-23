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
