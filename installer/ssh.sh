#!/bin/bash

[[ -e $(which curl) ]] && grep -q "1.1.1.1" /etc/resolv.conf || { 
    echo "nameserver 1.1.1.1" | cat - /etc/resolv.conf >> /etc/resolv.conf.tmp && mv /etc/resolv.conf.tmp /etc/resolv.conf
}


    # Konfigurasi URL izin
    PERMISSION_URL="https://raw.githubusercontent.com/rohjagad/fn-autosc-auth/main/izin.txt"
    LOCAL_IP=$(curl -4 -s ifconfig.me) # Mendapatkan IP lokal

    # Fungsi menghitung sisa waktu
    calculate_remaining_days() {
        local today=$(date +%s)
        local expired_date
        expired_date=$(date -d "$1" +%s 2>/dev/null)
        if [ $? -ne 0 ]; then
            echo "Invalid expiration date."
            exit 1
        fi
        echo $(( (expired_date - today) / 86400 ))
    }

    # Unduh izin dan validasi
    clear
    PERMISSION_DATA=$(curl -s "$PERMISSION_URL") || { echo "Failed to download permissions."; exit 1; }

    # Mencocokkan data berdasarkan IP lokal
    MATCH=$(echo "$PERMISSION_DATA" | grep "###" | grep "$LOCAL_IP")
    if [ -z "$MATCH" ]; then
        echo "Your IP doesn’t have on database"
        exit 1
    fi

    # Ekstraksi data dari baris yang cocok
    USERNAME=$(echo "$MATCH" | awk '{print $2}')
    PERMISSION_IP=$(echo "$MATCH" | awk '{print $3}')
    EXPIRED_DATE=$(echo "$MATCH" | awk '{print $4}')

    # Validasi masa aktif
    # A "lifetime" entry means auth is off: the expiry check is skipped
    # (is-decision.md 28). This gate also runs during installation, so a
    # lifetime machine installs without a date.
    if [ "$EXPIRED_DATE" = "lifetime" ]; then
        REMAINING_DAYS="lifetime"
    else
    REMAINING_DAYS=$(calculate_remaining_days "$EXPIRED_DATE")
    fi
    if [ "$REMAINING_DAYS" != "lifetime" ] && [ "$REMAINING_DAYS" -lt 0 ]; then
        echo "Permission expired."
        exit 1
    fi

    # Output informasi izin
    output() {
        echo "Username: $USERNAME"
        echo "IPv4: $PERMISSION_IP"
        if [ "$REMAINING_DAYS" = "lifetime" ]; then echo "Expired: lifetime"; else echo "Expired: $EXPIRED_DATE ( $REMAINING_DAYS Days )"; fi
    }

    output

hosting="https://raw.githubusercontent.com/rohjagad/fn-autosc/main"

# Menanbah Port SSH.
#
# sshd listens ONLY on the ports named by active Port directives, and Debian
# ships the default as a commented "#Port 22". Appending "Port 3303" alone
# therefore *closes* 22 - but the SSH cards, the README's port table and dnstt's
# forward target (127.0.0.1:22, the SlowDNS SSH-over-DNS backend) all assume 22
# keeps listening. Whether it did depended on the base image (a netboot image
# leaves #Port 22 commented, an older cloud image left it active), which is not
# something the panel can rely on. Make both explicit and idempotent.
for _port in 22 3303; do
    grep -qE "^[[:space:]]*Port[[:space:]]+${_port}[[:space:]]*$" /etc/ssh/sshd_config || \
        echo "Port ${_port}" >> /etc/ssh/sshd_config
done
unset _port
systemctl daemon-reload
systemctl restart ssh
systemctl restart sshd

# Installasi Dropbear
#
# The panel's default is Dropbear 2019.78, not the distribution's build (Debian
# 12 ships 2022.83). Both references install whatever apt provides; the pin is a
# deliberate choice recorded in project-information/is-decision.md 25. apt still
# supplies the plumbing - the init script, the systemd unit and the host keys -
# then the upstream 2019.78 binaries are built from the vendored tarball and
# installed over the package's. dropbear-bin is held so a later apt upgrade
# cannot put the distribution build back.
apt install dropbear -y
apt install -y zlib1g-dev >/dev/null 2>&1 || true
apt-mark hold dropbear-bin >/dev/null 2>&1 || true
if ! /usr/sbin/dropbear -V 2>&1 | grep -q 'v2019\.78'; then
    echo "Building Dropbear 2019.78 (the pinned default)..."
    (
        set -e
        cd /tmp || exit 1
        db_tbz=dropbear-2019.78.tar.bz2
        db_sha=525965971272270995364a0eb01f35180d793182e63dd0b0c3eb0292291644a4
        wget --no-check-certificate -q -O "$db_tbz" \
            "https://github.com/rohjagad/fn-autosc-miscellaneous/releases/download/v1.23/$db_tbz" || \
        wget --no-check-certificate -q -O "$db_tbz" \
            "https://raw.githubusercontent.com/rohjagad/fn-autosc-miscellaneous/main/$db_tbz" || \
        wget --no-check-certificate -q -O "$db_tbz" \
            "https://matt.ucc.asn.au/dropbear/releases/$db_tbz"
        if [ "$(sha256sum "$db_tbz" | awk '{print $1}')" != "$db_sha" ]; then
            echo "Dropbear source checksum mismatch - keeping the installed build."
        else
            rm -rf dropbear-2019.78
            tar -xjf "$db_tbz"
            cd dropbear-2019.78
            ./configure --prefix=/usr --sysconfdir=/etc >/dev/null 2>&1
            make -j"$(nproc)" >/dev/null 2>&1
            # Rename over the running binary; install(1) would fail with
            # "Text file busy" because dropbear is executing from that path.
            install -m 0755 dropbear /usr/sbin/dropbear.new && \
                mv -f /usr/sbin/dropbear.new /usr/sbin/dropbear
            install -m 0755 dropbearkey /usr/bin/dropbearkey
            install -m 0755 dropbearconvert /usr/bin/dropbearconvert
        fi
        cd /tmp || exit 1
        rm -rf dropbear-2019.78 "$db_tbz"
    ) || echo "Dropbear 2019.78 build failed - keeping the installed build."
    systemctl daemon-reload
fi
rm /etc/default/dropbear
rm /etc/issue.net
cat> /etc/issue.net << END
</strong> <p style="text-align:center"><b> <br><font color="#00FFE2"<br>┏━━━━━━━━━━━━━━━┓<br> RERECHAN STORE<br>┗━━━━━━━━━━━━━━━┛<br></font><br><font color="#00FF00"></strong> <p style="text-align:center"><b> <br><font color="#00FFE2">क═══════क⊹⊱✫⊰⊹क═══════क</font><br><font color='#FFFF00'><b> ★ [ ༆Hʸᵖᵉʳ᭄W̺͆E̺͆L̺͆C̺͆O̺͆M̺͆E̺͆
T̺͆O̺͆ M̺͆Y̺͆ S̺͆E̺͆R̺͆V̺͆E̺͆R̺͆ V͇̿I͇̿P͇̿ ] ★ </b></font><br><font color="#FFF00">ℝ𝕖𝕣𝕖𝕔𝕙𝕒𝕟 𝕊𝕥𝕠𝕣𝕖</font><br> <font color="#FF00FF">❖Ƭʜᴇ No DDOS</font><br> <font color="#FF0000">❖Ƭʜᴇ No Torrent</font><br> <font color="#FFB1C2">❖Ƭʜᴇ No Bokep </font><br> <font color="#FFFFFF">❖Ƭʜᴇ No Hacking</font><br>
<font color="#00FF00">❖Ƭʜᴇ No Mining</font><br> <font color="#00FF00">➳ᴹᴿ᭄ Oder / Trial :
https://wa.me/6289512992313 </font><br>
<font color="#00FFE2">क═══════क⊹⊱✫⊰⊹क═══════क</font><br></font><br><font color="FFFF00">❖Ƭʜᴇ TELEGRAM => https://t.me/rohcuan</font><br>
END
clear
cat>  /etc/default/dropbear << END
# disabled because OpenSSH is installed
# change to NO_START=0 to enable Dropbear
NO_START=0
# the TCP port that Dropbear listens on
DROPBEAR_PORT=111

# any additional arguments for Dropbear
DROPBEAR_EXTRA_ARGS="-p 109 -p 69 "

# specify an optional banner file containing a message to be
# sent to clients before they connect, such as "/etc/issue.net"
DROPBEAR_BANNER="/etc/issue.net"

# RSA hostkey file (default: /etc/dropbear/dropbear_rsa_host_key)
#DROPBEAR_RSAKEY="/etc/dropbear/dropbear_rsa_host_key"

# DSS hostkey file (default: /etc/dropbear/dropbear_dss_host_key)
#DROPBEAR_DSSKEY="/etc/dropbear/dropbear_dss_host_key"

# ECDSA hostkey file (default: /etc/dropbear/dropbear_ecdsa_host_key)
#DROPBEAR_ECDSAKEY="/etc/dropbear/dropbear_ecdsa_host_key"

# Receive window size - this is a tradeoff between memory and
# network performance
DROPBEAR_RECEIVE_WINDOW=65536
END
echo "/bin/false" >> /etc/shells
echo "/usr/sbin/nologin" >> /etc/shells
#dd=$(ps aux | grep dropbear | awk '{print $2}')
#kill $dd
clear
systemctl daemon-reload
/etc/init.d/dropbear restart
clear

# Installasi WebSocket
cd /usr/bin
wget --no-check-certificate ${hosting}/other/ws  >> /dev/null 2>&1
wget --no-check-certificate ${hosting}/config/config.yaml >> /dev/null 2>&1

# Mengaktifkan Permision
chmod +x ws
chmod +x config.yaml

# Membuat Service
cat> /etc/systemd/system/ws.service << END
[Unit]
Description=WebSocket
Documentation=https://github.com/rohjagad/fn-autosc
After=syslog.target network-online.target

[Service]
User=root
NoNewPrivileges=true
ExecStart=/usr/bin/ws -f /usr/bin/config.yaml
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
END

# Mengaktifkan Service WebSocket
systemctl daemon-reload
systemctl enable ws
systemctl start ws


# Installasi BadVPN UDP Gateway (udpgw) - port 7300 pada kartu akun SSH
cd /usr/bin
wget --no-check-certificate ${hosting}/other/badvpn -O /usr/bin/badvpn-udpgw >> /dev/null 2>&1
chmod +x /usr/bin/badvpn-udpgw

cat> /etc/systemd/system/badvpn-udpgw.service << END
[Unit]
Description=BadVPN UDP Gateway (udpgw)
Documentation=https://github.com/rohjagad/fn-autosc
After=syslog.target network-online.target

[Service]
User=root
NoNewPrivileges=true
ExecStart=/usr/bin/badvpn-udpgw --listen-addr 127.0.0.1:7300 --max-clients 1000 --max-connections-for-client 10 --client-socket-sndbuf 100000
Restart=on-failure
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
END

systemctl daemon-reload
systemctl enable --now badvpn-udpgw >> /dev/null 2>&1

# Konfigurasi prompt shell
echo -e "PS1='\033[1;34m\]╭───\[\033[1;31m\]≼\[\033[1;33m\]FN AutoSC\[\033[1;34m\]•\[\033[1;30m\]\w\[\033[1;31m\]≽
\[\033[1;34m\]╰──╼\[\033[1;31m\]✠\[\033[1;32m\] \033[0m'" >> /root/.bashrc

# Menghapus File Tidak Penting
rm -f /root/ssh.sh
