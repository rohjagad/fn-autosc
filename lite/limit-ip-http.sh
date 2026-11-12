#!/bin/bash
# Found 545: CGNAT-aware simultaneous-IP sampling (see limit-ip-common).
if [ ! -t 1 ] && [ "${LIMIT_VERBOSE:-0}" != "1" ]; then exec >/dev/null 2>&1; fi

TRANSPORT=http
TRANSPORT_LABEL=HU
SERVICE=upgrade
JSON=/etc/xray/json/upgrade.json
STATS_PORT=10081
JSON_LOCK=/tmp/xray-json-upgrade.lock
CARD_DIR=/var/log/create/xray/http
AUTO_DIR=/etc/xray/autounlock/http
STATE_DIR=/var/lib/fn-autosc/limit-ip/http
UNLOCK_BIN=/usr/bin/unlock-http-auto

export TRANSPORT TRANSPORT_LABEL SERVICE JSON STATS_PORT JSON_LOCK \
    CARD_DIR AUTO_DIR STATE_DIR UNLOCK_BIN
exec "${LIMIT_IP_COMMON:-/usr/bin/limit-ip-common}"
