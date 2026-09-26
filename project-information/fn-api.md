# The panel HTTP API — FN-API and `rohjagad/fn-autosc-api`

Reference for the HTTP API that the panel's `location /api/` block serves, how it is put together,
how to install it, what it can do, and how it was verified. Written for the planned web UI.

---

## 1. Summary

| Item | Value |
| :-- | :-- |
| Reachable at | `https://<domain>/api/<endpoint>` (nginx `location /api/` → `127.0.0.1:9000`, present in `config/4.conf`, `6.conf`, `dual.conf`) |
| Implementation | [`rohjagad/fn-autosc-api`](https://github.com/rohjagad/fn-autosc-api) — server + handlers + installer, self-contained |
| Reference | [`rohjagad/FN-API`](https://github.com/rohjagad/FN-API) — the original package; **reference only, never fetched or modified** |
| Auth | the raw `Authorization` header must equal a token in `/etc/xray/.key` (no `Bearer` prefix) |
| Transport | JSON body in, JSON body out, for every handler here |
| Runs as | root (`api.service`), bound to `127.0.0.1:9000` |
| Status on the test VPS | installed and verified end-to-end from the `/dev/kvm` client on 2026-09-26 |

Neither this repository nor either reference archive (`V23`, `Autoscript 1.20`) installs the API:
the nginx location existed in V23 and 1.20 exactly as it does here, pointing at a service the
operator supplies. The API is optional; the panel works without it.

---

## 2. Background — why there was work to do

The panel's `config/*.conf` has always proxied `/api/` to `127.0.0.1:9000`, and FN-API is the package
meant to answer there. By the time of this audit its pieces were gone or incomplete:

- The **handler scripts** the API dispatches to (`/usr/bin/rere/<endpoint>`) and the `menu-api`
  command were missing. The original `rere` bundle was fetched from
  `https://scvps.rerechanstore.eu.org/rere` — Rerechan's infrastructure, now dead. (That dead URL is
  also why `wget ... -O rere` was removed from `install.sh` in this fork.)
- The upstream parent repository `DindaPutriFN/FN-API` returns **404**.

So the server existed (`core/server`) but nothing for it to run. `rohjagad/fn-autosc-api` restores the
missing layer, and goes one step further by shipping its own server so the API no longer depends on
FN-API at all.

---

## 3. FN-API (reference only)

`rohjagad/FN-API` — *"This is API FN Project Autoscript"*, a fork of the now-deleted
`DindaPutriFN/FN-API`. Its contents:

| Path | What it is |
| :-- | :-- |
| `core/server` | the original API server: Python 3, stdlib only, listens `:9000`, logs `/etc/xray/api.log` |
| `core/http` | a small **Go TLS reverse proxy** (`-listen` default `:8888`, `-pem`/`-key` default `xray.crt`/`xray.key`, `-proto http\|https`) — **not** the API |
| `core/config.yaml` | `wsEpro` config (SSH WS on `:2080`, OpenVPN WS on `:512`) |
| `core/quota.sh`, `core/status` | ancillary (`status` is the six bytes `200 OK`) |
| `ohp` | OHP proxy binary |
| `config/dropbear`, `config/sshd_config` | SSH daemons' configs |
| `script/codespaches.sh` | GitHub-Codespaces bootstrap |
| `bot.zip` | the Telegram shell bot that `menu-bot.sh` installs |

How the original server behaves (this is the contract we kept):

- reads one token per line from `/etc/xray/.key`;
- authenticates with the raw `Authorization` header value;
- for **any** method, `/<path>` runs `/usr/bin/rere/<path>` with the request body on stdin and returns
  its **stdout**, declared `Content-Type: application/json`;
- logs each call to `/etc/xray/api.log`;
- binds `('', 9000)` — **all interfaces** (see §11).

Endpoints the FN-API README names (the shapes a web UI would use):

- **Create** — `POST /api/addssh`, `add-vmess`, `add-vless`, `add-trojan`, `add-ss`, `add-socks`, `add-noobz`
- **List** — `GET /api/list-ssh`, `list-xray`, `list-noobz`
- **Online/IP** — `GET /api/cek-ssh`, `cek-xray`
- **Delete** — `DELETE /api/delete-ssh`, `delete-xray`, `delete-noobz`

---

## 4. `rohjagad/fn-autosc-api` — the complete API

Self-contained: server, handlers and installer. `rohjagad/FN-API` is not fetched.

| Path | What it does |
| :-- | :-- |
| `server` | the API server (Python 3, stdlib only) — see §5 |
| `lib.sh` | shared handler helpers, installed to `/usr/local/lib/fn-api/lib.sh` — see §6 |
| `handlers/` | one executable per endpoint, installed to `/usr/bin/rere/` — see §7 |
| `menu-api` | installer / menu — see §8 |
| `README.md` | install and contract summary |

Commit history: `b8e5bb3` (restore the handler layer), `f255116` (ship our own server; FN-API becomes
reference-only), `8631cc9` (the raw-CDN note).

---

## 5. The server (`fn-autosc-api/server`)

A Python 3 HTTP server, standard library only — no packages to install beyond `python3` (and `jq`,
which the panel already has, for the handlers).

**Behaviour**

- **Auth** — `Authorization` must equal one of the lines in `/etc/xray/.key`; otherwise `401` with
  `{"message": "Unauthorized: Missing or invalid Authorization header"}`. No `Bearer` prefix.
- **Dispatch** — `<METHOD> /<name>` → run `/usr/bin/rere/<name>`, request body on stdin, return its
  stdout. Works for `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `HEAD`, `CONNECT`, `TRACE`; `OPTIONS`
  answers `{"message": "OPTIONS request received"}`.
- **Errors** — an unknown handler returns `404 Script not found`; a handler that exits non-zero
  returns `500` with `{"error": "...", "stdout": "..."}` (the original returned only `error` — the
  stdout is included here because it is what makes a failing panel script diagnosable).
- **Logging** — `/etc/xray/api.log` (client IP, User-Agent, path, outcome).
- **Timeout** — a handler is killed after 180 s.

**Hardening versus the original**

| Original | Here |
| :-- | :-- |
| binds `('', 9000)` — all interfaces | binds **`127.0.0.1`** by default (`--bind` to change) |
| `f'/usr/bin/rere/{path}'` with no checks | one path segment only — `/../etc/passwd` → `404`, so a handler outside `/usr/bin/rere/` cannot be reached |
| single-threaded `HTTPServer` | `ThreadingHTTPServer` (a slow handler no longer blocks every other call) |
| 500 hides the handler's output | 500 includes the handler's stdout |

**Flags**

```
server [--bind 127.0.0.1] [--port 9000]
       [--handlers /usr/bin/rere] [--tokens /etc/xray/.key] [--log /etc/xray/api.log]
```

---

## 6. `lib.sh` — handler helpers

Sourced by every handler; installed to `/usr/local/lib/fn-api/lib.sh`. It reads the JSON request body
on stdin once, and provides:

| Helper | Purpose |
| :-- | :-- |
| `j <key>` | raw value of a field (`jq -r`) |
| `field <key> <default>` | value or a default |
| `need <key>` | value or `{"status":"error","message":"missing required field: …"}` |
| `fail <msg>` / `ok <msg>` | emit an error / success JSON object and stop |
| `strip_ansi` | strip the panel cards' colour escapes |
| `json_array <text>` | newline-separated text → JSON array |

Response convention: **`{"status":"success", …}` or `{"status":"error","message":"…"}`**. Handlers
exit `0` even on a handled error, so the HTTP status stays `200` and the client reads `status` — a
non-zero exit is reserved for a genuine failure and surfaces as HTTP `500`.

---

## 7. Endpoint reference

| Endpoint | Method | Body fields | Backend it drives | Response highlights |
| :-- | :-- | :-- | :-- | :-- |
| `ping` | any | — | — | `status`, `message`, `host` |
| `add-vmess` / `add-vless` / `add-trojan` | POST | `username`, `core` (`ws`\|`http`\|`split`\|`grpc`, default `ws`), `expired` (days, default 30), `limit-ip` (default 1), `quota` GB (default 1) | `add-<proto>-<core>` | `status`, `username`, `protocol`, `core`, `expired`, `links[]` |
| `addssh` | POST | `username`, `password`, `expired`, `limit-ip` | `addssh` | `status`, `username`, `password`, `expired`, `text` |
| `add-noobz` | POST | `username`, `password`, `expired` | `noobzvpns add` | `status`, `username`, `password`, `expired` |
| `list-xray` | GET | — | the four `json/*.json` | `status`, `count`, `accounts[{username,expired,transport}]` |
| `list-ssh` | GET | — | `list-ssh` | `status`, `text` |
| `cek-xray` | GET | — | the four `cek-xray-*` | `status`, `text` |
| `cek-ssh` | GET | — | `cek-login-ssh` | `status`, `text` |
| `list-noobz` | GET | — | `noobzvpns print-all` | `status`, `text` |
| `delete-xray` | DELETE | `username` | `delete-ws`/`-http`/`-split`/`-grpc` for every transport that holds it | `status`, `username`, `deleted_from[]` |
| `delete-ssh` | DELETE | `username` | `delete-ssh` | `status`, `message` |
| `delete-noobz` | DELETE | `username` | `noobzvpns remove` | `status`, `message` |
| `renew-xray` | PUT/POST | `username`, `days`, `core` (default `ws`) | `extend-<core>` (keeps the account's usage) | `status`, `username`, `core`, `previous_expired`, `expired` |
| `renew-ssh` | PUT/POST | `username`, `days` | `extend-ssh` | `status`, `username`, `previous_expired`, `expired` |
| `password-ssh` | PUT/POST | `username`, `password` | `pwd-ssh` (also rewrites the account card) | `status`, `message` |
| `add-ss`, `add-socks` | any | — | — | `{"status":"error","message":"unsupported endpoint …"}` |

`add-vmess` / `add-vless` / `add-trojan` are three tiny wrappers over one `add-xray` handler; the
protocol comes from the handler name and `core` selects the transport, so `{core:"grpc"}` builds a
`add-vmess-grpc` account and `{core:"http"}` (HTTPUpgrade) one in `upgrade.json`.

The transport is named the same everywhere: `core` accepts `ws`, `http`, `split` or `grpc`, and
`list-xray` / `delete-xray` / `renew-xray` report it back under those names. The panel's internal name
for the HTTPUpgrade config, `upgrade`, is not exposed.

Every mutating handler **verifies** the panel did the work and answers `{"status":"error",...}` when
it did not, so a `success` means the change is in the config; a handler whose panel tool is absent
(the lite edition ships no SSH tooling and no NoobzVPN) says
`this panel edition does not ship '<tool>'` instead of returning the shell's error text as success.
The username is validated before the panel script runs, and when the panel itself refuses, its own
explanation is appended to the error.

**Example**

```
curl -sk -H 'Authorization: <token>' -H 'Content-Type: application/json' \
     -d '{"username":"alice","core":"ws","expired":30,"limit-ip":2,"quota":5}' \
     https://<domain>/api/add-vmess
```

```json
{"status":"success","username":"alice","protocol":"vmess","core":"ws",
 "expired":"26-10-26","links":["vmess://...","vmess://..."]}
```

**Why handlers rather than a new data model.** Each handler feeds the panel's own script the exact
stdin sequence it already prompts for (for the Xray add scripts: username, limit-IP, quota, days,
empty UUID) and parses the card it prints. The panel stays the single source of truth — the same
`add-vmess-ws`, `delete-ws`, `xp` and `quota-ws` run whether the request came from the menu or from
the API. That is also why the transport-path rename, the V2Ray → Xray migration, the credential
randomisation and the lifecycle fixes do not affect the API: those scripts keep their names and their
stdin contract.

---

## 8. Install and operate (`menu-api`)

```
wget -O /usr/bin/menu-api https://raw.githubusercontent.com/rohjagad/fn-autosc-api/main/menu-api
chmod +x /usr/bin/menu-api
menu-api install          # or: menu-api uninstall | status | token
```

With no argument it opens a menu (1 install · 2 uninstall · 3 status · 4 regenerate token · 0 exit).
It applies the same `izin.txt` authorisation gate as the panel menus.

`install` does the following:

| Step | Result |
| :-- | :-- |
| ensure `python3`, `jq`, `curl` | installed if missing |
| fetch `server` | `/usr/bin/api-server` (executable) |
| fetch `lib.sh` | `/usr/local/lib/fn-api/lib.sh` |
| fetch the handlers | `/usr/bin/rere/<name>`, all executable |
| alias the unsupported endpoints | `add-ss`, `add-socks` → `unsupported` |
| token | generated (40 random chars, mode `0600`) in `/etc/xray/.key` if absent |
| unit | `/etc/systemd/system/api.service` — `ExecStart=/usr/bin/python3 /usr/bin/api-server`, `Restart=always`, `User=root` |
| start | `systemctl enable --now api` |

Installed footprint: `/usr/bin/api-server`, `/usr/local/lib/fn-api/lib.sh`, `/usr/bin/rere/*`,
`/etc/xray/.key`, `/etc/systemd/system/api.service`, log at `/etc/xray/api.log`.
`menu-api uninstall` removes all of them except the token. The service is deliberately **not** added
to the panel installer: the API is optional and the panel works without it.

---

## 9. Verification history

### 9.1 First live test — is the mechanism sound? (2026-09-26)

The original `core/server` was installed with five hand-written handlers (`ping`, `add-vmess` →
`add-vmess-ws`, `list-xray` → `list-xray-ws`, `cek-xray` → `cek-xray-ws`, `delete-xray` → `delete-ws`).

- direct on `127.0.0.1:9000`: no token `401`, wrong token `401`, correct token returns the handler JSON;
- through nginx from the **KVM client**: `401` without/with a bad token, handler JSON with a good one,
  `OPTIONS` answered, unknown path `404`;
- **full cycle through the API**: `POST /api/add-vmess` created an account (returned its card and
  UUID), `GET /api/list-xray` listed it, `DELETE /api/delete-xray` removed it, and `/etc/xray/api.log`
  recorded every call.

Conclusion: the mechanism works and the panel is compatible with it.

### 9.2 The handler layer rebuilt (commit `b8e5bb3`)

All documented endpoints were implemented in `rohjagad/fn-autosc-api` (§7), plus `menu-api` (§8).

### 9.3 Self-contained server and final acceptance (commits `f255116`, `8631cc9`)

The server became ours, `menu-api` was corrected to fetch `server`, `lib.sh` and `handlers/` from
`fn-autosc-api` (the earlier layout change had left it requesting `api/lib.sh`), and the whole thing
was reinstalled on the VPS from a commit-pinned fetch. The service came up on **our** server, bound to
`127.0.0.1:9000`, and the final acceptance ran from the `/dev/kvm` client:

| Call | Result |
| :-- | :-- |
| `GET /ping` without a token | `401` |
| `GET /ping` | success |
| `POST /add-vmess {core:"ws"}` | success, 2 links |
| `POST /add-vless {core:"grpc"}` | success, 1 link |
| `GET /list-xray` | `count: 2` |
| `GET /cek-xray` | success |
| `POST /addssh`, then `GET /list-ssh` | created and listed |
| `POST /add-ss` | `{"status":"error"}` as designed |
| `DELETE /delete-xray` for both accounts | `deleted_from: ["ws"]`, then `["grpc"]` |
| `DELETE /delete-ssh` | success |
| `GET /list-xray` afterwards | `count: 0` |
| `--path-as-is /../etc/passwd` | `404` |

Test accounts were removed and the token rotated afterwards; the panel itself was untouched (all
services active, `Configuration OK.`).

---

## 10. Coverage and limitations

Every endpoint the panel can serve is implemented - including the reference's `renew-ssh`,
`renew-xray` and `password-ssh`, which the restored layer initially missed. The only endpoints that
cannot work are **`add-ss`** and **`add-socks`**: the panel - and both reference versions - have no
Shadowsocks or Socks5 account type at all, so those return a clear error rather than pretending.

Two limitations are the panel's own, and the endpoints report them rather than hiding them:

- `renew-ssh` and `password-ssh` drive tools the lite edition does not ship; on lite they answer
  `this panel edition does not ship 'extend-ssh'`.
- `password-ssh` uses the panel's `pwd-ssh`, which reads the new password with Go's `Scanln` and so
  stops at the first space; a password containing whitespace is rejected instead of silently
  truncated.

The panel's account types and the API surface they map to: SSH/OpenVPN (`addssh`, `list-ssh`,
`cek-ssh`, `delete-ssh`), Xray VMess/VLESS/Trojan over WebSocket, HTTPUpgrade, SplitHTTP and gRPC
(`add-vmess`/`add-vless`/`add-trojan`, `list-xray`, `cek-xray`, `delete-xray`), NoobzVPN
(`add-noobz`, `list-noobz`, `delete-noobz`). WireGuard and L2TP are menu-only and have no endpoint.

---

## 11. Security

- **Bound to loopback.** The server listens on `127.0.0.1:9000`, so only nginx reaches it. The
  original bound all interfaces; if you ever run it elsewhere pass `--bind` deliberately.
- **The token is a root credential.** Handlers run as root and can create or delete accounts. It is
  40 random characters, stored `0600`; treat it like the panel's own root password. Rotate with
  `menu-api token`.
- **`/api/` is public.** nginx exposes it on every TLS/HTTP port with only the token in the way.
  Consider restricting the `location /api/` block by source IP if only your web UI should reach it.
- **One path segment only**, so a request cannot reach another file as a handler.

---

## 12. Operational notes

- **`raw.githubusercontent.com` can serve a stale copy** of a file that was pushed moments ago, and a
  query string does **not** bust it. If `menu-api install` reports `FAILED to fetch ...` right after a
  push, use the commit-pinned URL
  (`https://raw.githubusercontent.com/rohjagad/fn-autosc-api/<commit>/menu-api`) or the jsDelivr mirror
  `https://cdn.jsdelivr.net/gh/rohjagad/fn-autosc-api@main/menu-api`. In normal use the plain `main`
  URL is correct.
- **Do not confuse `/usr/bin/rere/`** (the handler directory the API looks in) with the `/rere` PATH
  entry `slowdns.sh` used to append — that entry was vestigial and has been removed (see the
  observation in `bugs-found.md`).
- **Uninstall** with `menu-api uninstall` (or `systemctl disable --now api`); the token in
  `/etc/xray/.key` is kept.

---

## 13. Decisions recorded

- The API is **optional** and stays out of the panel installer; the panel works without it.
- The restored layer lives in its **own repository**, `rohjagad/fn-autosc-api`, so `rohjagad/FN-API`
  is left untouched and is **reference-only** — nothing fetches or modifies it.
- The API ships **its own server** rather than FN-API's, keeping the original contract (token,
  handler dispatch, JSON bodies) while fixing the bind address, the path handling and the error
  reporting.
- Only endpoints the panel can actually serve are implemented; `add-ss` / `add-socks` return an
  explicit "no backend" error instead of failing obscurely.

---

## 14. Revision - Four-Repository Scan (September 26, 2026)

The whole layer was re-audited against the panel and the reference README, and the defects found are
recorded as Found 119-126 / fixes 121-126 in `bugs-found.md` and `bugs-fixed.md`. In summary:

- `need` was called as `user="$(need username)"`, so its `fail` ran in a subshell and the handler
  continued with the error JSON as the username; replaced by `require <field> <var>`, which assigns
  in the caller's shell.
- `list-xray`/`delete-xray` reported the internal name `upgrade` where `core` accepts `http`.
- `delete-xray`/`delete-noobz` did not verify the removal; handlers whose panel tool is absent
  reported the shell error as success; `delete-ssh` reported success for a name that never existed.
- The reference's `renew-ssh`, `renew-xray` and `password-ssh` were missing; added, each verifying
  the expiry or the shadow hash changed.
- The server passed `None` as stdin, so a GET handler inherited the server's stdin; and the
  reference's `WWW-Authenticate` and `Allow` headers were missing. Both restored.
- `menu-api install` now aborts when the server, `lib.sh` or a handler fails to fetch, instead of
  reporting a partial install as success.

The whole layer was then re-verified on a **freshly reinstalled Debian 12 host** from the pushed
repositories, and end-to-end from the KVM client: 8/8 transport links carried real traffic, the two
gRPC accounts also uploaded 3 MB (which needed the panel's `client_max_body_size` fix), and every new
endpoint behaved. The token and the web-restore key were rotated afterwards.
