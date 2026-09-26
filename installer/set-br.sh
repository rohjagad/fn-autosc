#!/bin/bash
# Traffic shaping only.
#
# The Google Drive backup (rclone + a committed remote config) and the email
# notification (msmtp/bsd-mailx with a committed Gmail app password) were
# removed: Telegram is the only backup delivery channel now. See the decisions
# document, section 11.
hosting="https://raw.githubusercontent.com/rohjagad/fn-autosc/main"
# `rm -rf wondershaper` ran from inside the clone, so it never removed it and a
# re-install hit an existing directory (git clone fails, the stale clone builds).
rm -rf /root/wondershaper
git clone  https://github.com/rohjagad/wondershaper.git
cd wondershaper
make install
cd /root
rm -rf /root/wondershaper
echo > /home/limit
cd /usr/bin
rm -f /root/set-br.sh
