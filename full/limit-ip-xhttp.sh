#!/bin/bash
# Found 545: CGNAT-aware simultaneous-IP sampling (see limit-ip-common).
if [ ! -t 1 ] && [ "${LIMIT_VERBOSE:-0}" != "1" ]; then exec >/dev/null 2>&1; fi

TRANSPORT=xhttp
TRANSPORT_LABEL=XHTTP
SERVICE=xhttp
JSON=/etc/xray/json/xhttp.json
STATS_PORT=10082
JSON_LOCK=/tmp/xray-json-xhttp.lock
CARD_DIR=/var/log/create/xray/xhttp
AUTO_DIR=/etc/xray/autounlock/xhttp
STATE_DIR=/var/lib/fn-autosc/limit-ip/xhttp
UNLOCK_BIN=/usr/bin/unlock-xhttp-auto

export TRANSPORT TRANSPORT_LABEL SERVICE JSON STATS_PORT JSON_LOCK \
    CARD_DIR AUTO_DIR STATE_DIR UNLOCK_BIN
exec "${LIMIT_IP_COMMON:-/usr/bin/limit-ip-common}"
