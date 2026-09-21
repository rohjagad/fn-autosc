#!/bin/bash

# Detail Hosting File
hosting="https://raw.githubusercontent.com/rohjagad/fn-autosc/1.23/website"

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

# Mengkonfigurasi Port HTTP
echo -e "Listen 855" > /etc/apache2/ports.conf

# Periksa apakah baris sudah ada
if ! sudo grep -q "^www-data ALL=(ALL) NOPASSWD: /usr/bin/restore-ftp" /etc/sudoers; then
  # Tambahkan baris ke sudoers menggunakan visudo
  echo "www-data ALL=(ALL) NOPASSWD: /usr/bin/restore-ftp" | sudo EDITOR='tee -a' visudo
fi

# Mengaktifkan semuanya
systemctl daemon-reload
systemctl restart apache2

# Menghapus File Installasi
rm -f /root/website.sh