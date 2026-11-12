#!/bin/bash
# Found 545: CGNAT-aware simultaneous-IP sampling (see limit-ip-common).
if [ ! -t 1 ] && [ "${LIMIT_VERBOSE:-0}" != "1" ]; then exec >/dev/null 2>&1; fi

TRANSPORT=grpc
TRANSPORT_LABEL=GRPC
SERVICE=grpc
JSON=/etc/xray/json/grpc.json
STATS_PORT=10083
JSON_LOCK=/tmp/xray-json-grpc.lock
CARD_DIR=/var/log/create/xray/grpc
AUTO_DIR=/etc/xray/autounlock/grpc
STATE_DIR=/var/lib/fn-autosc/limit-ip/grpc
UNLOCK_BIN=/usr/bin/unlock-grpc-auto

export TRANSPORT TRANSPORT_LABEL SERVICE JSON STATS_PORT JSON_LOCK \
    CARD_DIR AUTO_DIR STATE_DIR UNLOCK_BIN
exec "${LIMIT_IP_COMMON:-/usr/bin/limit-ip-common}"
