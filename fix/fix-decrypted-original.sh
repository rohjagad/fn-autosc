#!/bin/bash
clear
# URL izin
IZIN="https://raw.githubusercontent.com/rohmatsb-biz/cobaizin/main/izin.txt"

# Fungsi untuk mendapatkan IP VPS
get_ip() {
  # Coba dengan curl
  IP_VPS=$(curl -s https://api.ipify.org)

  # Jika gagal, coba dengan wget
  if [ -z "$IP_VPS" ]; then
    IP_VPS=$(wget -qO- ifconfig.me)
  fi
}

# Mendapatkan IP VPS
get_ip

# Memeriksa apakah IP berhasil diambil
if [ -z "$IP_VPS" ]; then
  echo "Gagal mendapatkan IP VPS. Tidak dapat melanjutkan."
  exit 1
fi

# Mendownload daftar IP izin
IZIN_LIST=$(curl -s "$IZIN")

# Memeriksa apakah IP VPS ada dalam daftar izin
if echo "$IZIN_LIST" | grep -q "$IP_VPS"; then
  echo "IP $IP_VPS terdaftar. Melanjutkan tugas Perbaikan By Newbie..."
  fix_sc
  # Tambahkan tugas Anda di sini
else
  echo "IP $IP_VPS tidak terdaftar. Perbaikan Tidak Dizinkan Server akan dimatikan."
  sleep 5
  reboot
fi

fix_sc(){
SYSCTL_CONF="/etc/sysctl.conf"

# Ambil nilai fs.file-max saat ini
CURRENT_FILE_MAX=$(grep "^fs.file-max" "$SYSCTL_CONF" | awk '{print $3}' 2>/dev/null)

# Cek apakah nilai fs.file-max sudah sesuai
if [ "$CURRENT_FILE_MAX" != "$NEW_FILE_MAX" ]; then
    # Cek apakah fs.file-max sudah ada di file
    if grep -q "^fs.file-max" "$SYSCTL_CONF"; then
        # Jika ada, ubah nilainya
        sed -i "s/^fs.file-max.*/fs.file-max = $NEW_FILE_MAX/" "$SYSCTL_CONF" >/dev/null 2>&1
    else
        # Jika tidak ada, tambahkan baris baru
        echo "fs.file-max = $NEW_FILE_MAX" >> "$SYSCTL_CONF" 2>/dev/null
    fi
fi

# Cek apakah net.netfilter.nf_conntrack_max sudah ada
if ! grep -q "^net.netfilter.nf_conntrack_max" "$SYSCTL_CONF"; then
    echo "$NF_CONNTRACK_MAX" >> "$SYSCTL_CONF" 2>/dev/null
fi

# Cek apakah net.netfilter.nf_conntrack_tcp_timeout_time_wait sudah ada
if ! grep -q "^net.netfilter.nf_conntrack_tcp_timeout_time_wait" "$SYSCTL_CONF"; then
    echo "$NF_CONNTRACK_TIMEOUT" >> "$SYSCTL_CONF" 2>/dev/null
fi

# Terapkan perubahan
sysctl -p >/dev/null 2>&1
echo "Script successfully repaired...."
}
