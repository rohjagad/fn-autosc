#!/bin/bash
# Traffic shaping only.
#
# The Google Drive backup (rclone + a committed remote config) and the email
# notification (msmtp/bsd-mailx with a committed Gmail app password) were
# removed: Telegram is the only backup delivery channel now. See the decisions
# document, section 11.
hosting="https://raw.githubusercontent.com/rohjagad/fn-autosc/main"
git clone  https://github.com/rohjagad/wondershaper.git
cd wondershaper
make install
rm -rf wondershaper
echo > /home/limit
cd /usr/bin
rm -f /root/set-br.sh
