# RohFN AutoSC

RohFN AutoSC is a menu-driven VPS installer for SSH tunneling and
Xray/V2Ray services. This repository preserves the supplied script behavior,
including its bundled binaries, Xray/V2Ray versions, full/lite variants, and
existing service configuration.

The script is intended for Debian, Ubuntu, and Kali Linux VPS installations.
Run it as `root` on a fresh VPS. A VM test remains pending; use it at your own
risk and do not run it on a server with data you need to keep.

## Included Features

- SSH and WebSocket SSH setup.
- Xray and V2Ray installation with WS, HTTP Upgrade, gRPC, and Split HTTP
  account-management menus.
- VMess, VLESS, and Trojan account actions: create, trial, extend, delete,
  quota, IP limit, lock/unlock, and routing menus.
- Full variant extras: OpenVPN, SlowDNS, L2TP, WireGuard, NoobzVPN, UDP
  Custom/Request, Argo, backup, bot, system, and domain-management menus.
- Lite variant: Xray/V2Ray-focused installation with the included Lite menu.
- Bundled `fix/fix.sh`, executed as the final step of Full and Lite installation.

No Xray/V2Ray upgrades, configuration modernization, or feature changes have
been made as part of this migration.

## Rental Authorization

Installation requires the VPS public IPv4 to exist in the public rental list:

[`rohjagad/rohfn-autosc-auth/izin.txt`](https://github.com/rohjagad/rohfn-autosc-auth/blob/1.23/izin.txt)

The record format is:

```text
### rental-2026-001 203.0.113.10 2026-12-31
```

- Field 2 is a non-identifying rental label.
- Field 3 is the VPS public IPv4.
- Field 4 is the expiry date in `YYYY-MM-DD` format.

The installer downloads this list automatically, compares the VPS public IP,
then continues without further authorization prompts when the record is valid.
An unknown or expired IP stops the script. This is an open, transparent rental
convenience check, not DRM; users who modify the visible source can remove it.

## Installation

1. Create a VPS running Debian, Ubuntu, or Kali Linux.
2. Point a domain to the VPS before installation. The script asks for the
   domain, email address, and IP mode.
3. Ask the operator to add the VPS public IPv4 and expiry date to `izin.txt`.
4. Log in to the VPS as `root`.
5. Run:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/rohjagad/rohfn-autosc/1.23/install.sh)
```

6. Select `full` or `lite` when prompted.
7. Enter the requested values:

```text
Input Domain: example.com
Input Email: admin@example.com
Input Type IP VPS (4/6/dual): 4
```

The script installs the selected variant and runs the bundled Xray/V2Ray fix at
the end. Do not interrupt it while package and service installation is running.

## Using The Menu

After installation, run the command supplied by the installed menu. The Full
menu is installed from `menu/full.zip`; the Lite menu is installed from
`menu/lite.zip`.

The Lite XTLS menu provides:

- WebSocket, HTTP Upgrade, gRPC, and Split HTTP menus.
- System, domain, backup, and bot-server menus.
- Account totals and bandwidth data from `vnstat`.

Full includes the supplied Full menu and its additional protocol/system menus.
Each installed menu checks the same rental IP/expiry list before continuing.

## Telegram Completion Notification

`installer/full.sh` and `installer/lite.sh` send a completion notification to

## Repository Layout

- `install.sh`: entry point; checks rental authorization and selects Full/Lite.
- `installer/`: installers called by the entry point.
- `full/` and `lite/`: menu commands and account-management scripts.
- `menu/`: generated Full/Lite archives installed into `/usr/bin`.
- `config/`, `json/`, `website/`: supplied configuration and website files.
- `other/`, `udp/`, `v2ray/`: supplied binaries and archives.
- `fix/fix.sh`: supplied x86-64 Linux fix executable.

## Important Notes

- Keep `izin.txt` updated before a new rental installation.
- Public repository source means all installer behavior is visible and editable.
- The script downloads several public third-party dependencies during install;
  their URLs and versions are preserved from the supplied source.
- The project has no automatic upgrade path. Do not update Xray/V2Ray through
  this repository unless you explicitly choose to change the supplied script.
