#!/bin/bash

# Detail Hosting File
hosting="https://raw.githubusercontent.com/rohjagad/fn-autosc/main/website"

# Menginstall Package
apt install apache2 php libapache2-mod-php -y

# Melakukan Konfigurasi
wget -O /etc/apache2/sites-available/upload.conf "${hosting}/upload.conf"

# Membuat Folder
mkdir -p /var/www/upload
chown -R www-data:www-data /var/www/upload
mkdir -p /var/www/uploads
chown -R www-data:www-data /var/www/uploads

# Memasang File Website
cd /var/www/upload
wget --no-check-certificate ${hosting}/index.html >> /dev/null 2>&1
wget --no-check-certificate ${hosting}/style.css >> /dev/null 2>&1
wget --no-check-certificate ${hosting}/script.js >> /dev/null 2>&1
wget --no-check-certificate ${hosting}/upload.php >> /dev/null 2>&1
chmod +x *
cd
wget --no-check-certificate ${hosting}/restore-ftp.sh -O /usr/bin/restore-ftp >> /dev/null 2>&1
chmod +x /usr/bin/restore-ftp

# Mengkonfigurasi Port HTTP
echo -e "Listen 855" > /etc/apache2/ports.conf

# Periksa apakah baris sudah ada
if ! sudo grep -q "^www-data ALL=(ALL) NOPASSWD: /usr/bin/restore-ftp" /etc/sudoers; then
  # Tambahkan baris ke sudoers menggunakan visudo
  echo "www-data ALL=(ALL) NOPASSWD: /usr/bin/restore-ftp" | sudo EDITOR='tee -a' visudo
fi

# The restore endpoint authenticates with a dedicated key so that the web
# server user can read it without exposing the 0600 API token in /etc/xray/.key.
# Only root and www-data can read it.
mkdir -p /etc/funny
[ -s /etc/funny/.restore.key ] || head -c 32 /dev/urandom | base64 | tr -d '/+=\n' | head -c 40 > /etc/funny/.restore.key
chown root:www-data /etc/funny/.restore.key 2>/dev/null || true
chmod 640 /etc/funny/.restore.key

# Mengaktifkan semuanya
a2dissite 000-default
a2ensite upload
systemctl daemon-reload
systemctl restart apache2

echo "  restore page (http://<ip>:855) requires the key in /etc/funny/.restore.key (read it as root)"

# Menghapus File Installasi
rm -f /root/website.sh