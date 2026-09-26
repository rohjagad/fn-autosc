# FN-API Integration - what it is, the live test, and how to enable it

`https://github.com/rohjagad/FN-API` (a fork of the now-deleted `DindaPutriFN/FN-API`) is the
**HTTP API** for this autoscript. It is what the `location /api/` block in every `config/*.conf`
expects on `127.0.0.1:9000`. Neither this repository nor either reference archive installs it -
the nginx location existed in V23 and 1.20 exactly as it does here, pointing at a service the
operator supplies.

This note records a live test of the API done on 2026-09-26 so a future web UI can be built on it
with confidence.

## What the package contains

| Path | What it is |
| :-- | :-- |
| `core/server` | The API server - Python 3, stdlib only; listens on `:9000`; logs to `/etc/xray/api.log` |
| `core/http` | A small Go **TLS reverse proxy** (`-listen` default `:8888`, `-pem`/`-key` default `xray.crt`/`xray.key`, `-proto http\|https`) - not the API itself |
| `core/config.yaml` | `wsEpro` config (SSH WS on `:2080`, OpenVPN WS on `:512`) |
| `core/quota.sh`, `core/status`, `ohp`, `config/dropbear`, `config/sshd_config`, `script/codespaches.sh` | ancillary files (Codespaces setup, dropbear/sshd configs, the OHP proxy) |
| `bot.zip` | the Telegram shell bot fetched by `menu-bot.sh` |

## How it works

`core/server` reads one or more API tokens (one per line) from `/etc/xray/.key`. Every request to
`/<path>` executes `/usr/bin/rere/<path>` with the request body on stdin and returns the script's
**stdout** as the response, declared `Content-Type: application/json`. Authentication is the raw
`Authorization` header value - there is no `Bearer` prefix.

Endpoints named in the FN-API README:

- `POST /api/addssh`, `/add-vmess`, `/add-vless`, `/add-trojan`, `/add-ss`, `/add-socks`, `/add-noobz`
- `GET /api/list-ssh`, `/list-xray`, `/list-noobz`
- `GET /api/cek-ssh`, `/cek-xray`
- `DELETE /api/delete-ssh`, `/delete-xray`, `/delete-noobz`

## What is missing from the repository

The **handler scripts** (`/usr/bin/rere/<endpoint>`) and the `menu-api` command the README refers to
are not in the repository. The original `rere` bundle was fetched from
`https://scvps.rerechanstore.eu.org/rere`, which no longer resolves - that dead download is why the
`wget ... -O rere` line was removed from `install.sh` here - and the upstream parent repository
returns 404. Each endpoint therefore has to be provided as a small executable wrapper under
`/usr/bin/rere/`.

## Live test (2026-09-26) - VPS as server, `/dev/kvm` guest as client

`core/server` was installed as `/usr/bin/api-server`, five handlers were written under
`/usr/bin/rere/` (`ping`; `add-vmess` -> `add-vmess-ws`; `list-xray` -> `list-xray-ws`;
`cek-xray` -> `cek-xray-ws`; `delete-xray` -> `delete-ws`) and a token placed in `/etc/xray/.key`.

- **Direct on `127.0.0.1:9000`:** no token `401`, wrong token `401`, correct token returns the
  handler's JSON.
- **Through nginx, from the KVM client (external):** no token `401`, wrong token `401`, correct
  token returns the handler's JSON, `OPTIONS` answered by the server, unknown path `404`.
- **Full panel cycle through the API:** `POST /api/add-vmess` with the body `apiuser` + limit/quota/
  days created the account (returned the card with its generated UUID), `GET /api/list-xray` listed
  it, `DELETE /api/delete-xray` removed it, and `/etc/xray/api.log` recorded each call.

**Conclusion: the API mechanism works, and our panel is compatible with it.** The transport-path
rename, the V2Ray -> Xray migration, the credential randomisation and the lifecycle fixes do not
affect it: the handlers call the panel's scripts by their unchanged names (`add-vmess-ws`,
`cek-xray-ws`, `delete-ws`, ...), and those scripts read their inputs from stdin exactly as before.

## Notes for a future web UI

- **The response body is the handler's raw stdout.** The panel scripts print ANSI-decorated cards,
  so a handler should format them (or the client must strip ANSI); a handler meant for a UI should
  emit clean JSON itself.
- **`core/server` binds `('', 9000)` - all interfaces.** Combined with the public `/api/` nginx
  location and a single shared token, a leaked token lets anyone create or delete accounts. Bind it
  to `127.0.0.1` (it only needs to be reachable by nginx), use a long random token, and consider
  restricting the `/api/` location by IP.
- The handler runs **as root** (`/usr/bin/rere/<path>`), so it can do anything the panel can.
- `/usr/bin/rere/` already exists on the reference layout as the directory the API looks in; do not
  confuse it with the `/rere` PATH entry that `slowdns.sh` used to append (removed - see the
  observation in `bugs-found.md`).

## Enabling it

1. `install -m755 core/server /usr/bin/api-server`
2. `printf '<long-random-token>\n' > /etc/xray/.key`
3. create the `/usr/bin/rere/` handlers (executable) that wrap the panel scripts
4. run it as a service, e.g. `ExecStart=/usr/bin/python3 /usr/bin/api-server`, ideally bound to
   loopback
5. it is then reachable as `https://<domain>/api/<path>`

## Rebuilt in `rohjagad/fn-autosc-api`

The handler layer and an installer now live in a dedicated repository,
[`rohjagad/fn-autosc-api`](https://github.com/rohjagad/fn-autosc-api), so the API no longer depends
on the dead upstream bundle and `rohjagad/FN-API` stays untouched (it is still read, read-only, for
`core/server`):

| Path | What it does |
| :-- | :-- |
| `menu-api` | install / uninstall / status / regenerate-token, plus an interactive menu. Fetches the server from the FN-API repo, patches it to bind `127.0.0.1`, writes `/etc/xray/.key`, installs the handlers and creates `api.service` |
| `lib.sh` | shared helpers, installed to `/usr/local/lib/fn-api/lib.sh` - reads a JSON body on stdin, writes JSON on stdout |
| `handlers/` | one executable per endpoint, each wrapping the panel's own scripts |

`menu-api install` fetches `core/server` from `rohjagad/FN-API`, applies
`s/('', port)/('127.0.0.1', port)/` so the API is reachable only through nginx, installs `lib.sh` and the handlers,
and starts `api.service`.

```
wget -O /usr/bin/menu-api https://raw.githubusercontent.com/rohjagad/fn-autosc-api/main/menu-api
chmod +x /usr/bin/menu-api
menu-api install
```

### Endpoint contract

Request body is a JSON object on stdin; the response is a JSON object on stdout. `jq` is used
throughout (already installed by the panel).

| Endpoint | Method | Body fields | Backend |
| :-- | :-- | :-- | :-- |
| `ping` | any | - | health check |
| `add-vmess` / `add-vless` / `add-trojan` | POST | `username`, `core` (ws/http/split/grpc, default ws), `expired` (days), `limit-ip`, `quota` | `add-<proto>-<core>` |
| `addssh` | POST | `username`, `password`, `expired`, `limit-ip` | `addssh` |
| `add-noobz` | POST | `username`, `password`, `expired` | `noobzvpns` |
| `list-xray` | GET | - | the four `json/*.json` (username, expiry, transport) |
| `list-ssh` / `cek-ssh` | GET | - | `list-ssh` / `cek-login-ssh` (text body) |
| `cek-xray` | GET | - | the four `cek-xray-*` (text body) |
| `list-noobz` | GET | - | `noobzvpns print-all` (text body) |
| `delete-xray` | DELETE | `username` | `delete-ws/http/split/grpc` for every transport that holds it |
| `delete-ssh` | DELETE | `username` | `delete-ssh` |
| `delete-noobz` | DELETE | `username` | `noobzvpns remove` |
| `add-ss`, `add-socks` | - | - | `501`-style JSON: no Shadowsocks/Socks5 backend exists (nor in either reference) |

Example:

```
curl -sk -H 'Authorization: <token>' -H 'Content-Type: application/json' \
     -d '{"username":"alice","core":"ws","expired":30,"limit-ip":2,"quota":5}' \
     https://<domain>/api/add-vmess
```

Response:

```json
{"status":"success","username":"alice","protocol":"vmess","core":"ws","expired":"26-10-26","links":["vmess://..."]}
```

**Rebuilding the upstream handler bundle is therefore complete and now shipped in `rohjagad/fn-autosc-api` for every endpoint this panel can
serve**; the only endpoints that cannot work are `add-ss` and `add-socks`, because the panel - and
both reference versions - have no Shadowsocks or Socks5 account type at all.
