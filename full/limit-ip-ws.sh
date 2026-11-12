#!/bin/bash
# Found 545: CGNAT-aware simultaneous-IP sampling (see limit-ip-common).
if [ ! -t 1 ] && [ "${LIMIT_VERBOSE:-0}" != "1" ]; then exec >/dev/null 2>&1; fi

TRANSPORT=ws
TRANSPORT_LABEL=WS
SERVICE=ws
JSON=/etc/xray/json/ws.json
STATS_PORT=10080
JSON_LOCK=/tmp/xray-json-ws.lock
CARD_DIR=/var/log/create/xray/ws
AUTO_DIR=/etc/xray/autounlock/ws
STATE_DIR=/var/lib/fn-autosc/limit-ip/ws
UNLOCK_BIN=/usr/bin/unlock-ws-auto

export TRANSPORT TRANSPORT_LABEL SERVICE JSON STATS_PORT JSON_LOCK \
    CARD_DIR AUTO_DIR STATE_DIR UNLOCK_BIN
exec "${LIMIT_IP_COMMON:-/usr/bin/limit-ip-common}"
