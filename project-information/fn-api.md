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
