# Bug-Finding & Fixing Phase Plan

Dokumen ini menetapkan rencana kerja sistematis untuk **penemuan bug (Finding)** dan **perbaikan bug (Fixing)** di seluruh repositori `fn-autosc`. Setiap fase mencakup metodologi audit statis, teknik pemindaian pola cacat, verifikasi komparatif terhadap sumber asli, serta standar perbaikan minimalis tanpa regresi.

---

## 1. Dokumen & Sumber Referensi Wajib (Mandatory References)

Setiap langkah dalam seluruh fase **WAJIB** membaca dan mengacu pada 7 sumber referensi utama berikut sebelum melakukan analisis, perubahan kode, atau evaluasi regresi:

| # | Sumber Referensi | Lokasi / Perintah | Kegunaan & Batas Kepatuhan |
| :- | :--- | :--- | :--- |
| 1 | **Bugs Fixed** | `project-information/bugs-fixed.md` | Daftar seluruh perbaikan yang telah diverifikasi (Fix 1 s.d. 309). Wajib diperiksa agar perbaikan baru tidak membatalkan atau mengulang perbaikan sebelumnya. |
| 2 | **Original Sources (Both Versions)** | - **Arsip Resmi di Repo:**<br>  • `original-source-do-not-edit/V23 Linux Ubuntu, Debian, Kali.zip`<br>  • `original-source-do-not-edit/Autoscript New 1.20.zip`<br>- **Ekstraksi Kerja (Transient):**<br>  • V23: `/tmp/opencode/original-v23`<br>  • 1.20: `/tmp/opencode/original-120`<br>*(Jika direktori `/tmp` belum diekstrak, ekstrak dari arsip zip repo di atas atau gunakan `unzip -p <zip> <path>`)* | Sumber rujukan asli (upstream). Wajib dicompare sebelum mengubah logika: jika referensi sudah menyelesaikan masalah, pertahankan solusi referensi. Divergensi hanya diizinkan untuk keamanan & stabilitas yang terbukti. |
| 3 | **Git Commit History** | `git log --stat` / `git log -p` | Catatan riwayat commit atomik repositori. Memahami konteks perubahan sebelumnya, alasan teknis patch masa lalu, dan evolusi setiap script. |
| 4 | **Bug Fixes Regression** | `project-information/bug-fixes-regression.md` | Rekam evaluasi 4-Check Rule (Regression, Over-Strictness, Over-Engineering, Source Alignment). Setiap perubahan baru wajib lulus 4 kriteria ini. |
| 5 | **Bugs Found** | `project-information/bugs-found.md` | Rekam jejak temuan bug historis (append-only, Found 1 s.d. 309). Memastikan akar penyebab terdokumentasi akurat sebelum patch diterapkan. |
| 6 | **FN-API Specification** | `project-information/fn-api.md` | Kontrak spesifikasi headless REST API, arsitektur handler `/usr/bin/rere`, penanganan single path segment, otentikasi token `/etc/xray/.key`, dan serializing lock. |
| 7 | **Architectural Decisions** | `project-information/is-decision.md` | Daftar 28 keputusan desain arsitektural yang disengaja (bukan bug). Wajib dibaca agar tidak "memperbaiki" perilaku yang sengaja dirancang demikian (contoh: Xray 25.3.6 pin, Dropbear 2019.78 pin, auth lifetime vs date, penolakan angka 0, penghapusan total pada kuota habis). |

---

## 2. Prinsip Kerja: Finding & Fixing

### 2.1 Metodologi Finding (Penemuan Bug)
1. **Pemindaian Pola Rawan (Grep/Pattern Hunting):** Audit baris-baris perintah berisiko tinggi seperti `read -p`, `sed -i`, `rm -rf`, `systemctl restart`, `chmod`, ekspresi interpolasi tanpa tanda petik, dan loop tanpa penanganan EOF.
2. **Audit Komparatif Diferensial:** Membandingkan implementasi skrip `fn-autosc` dengan kedua arsip sumber rujukan (`original-source-do-not-edit/*.zip`). Mengidentifikasi apakah anomali berasal dari upstream atau hasil modifikasi yang rusak.
3. **Injeksi Kegagalan Batas (Boundary Fault Injection):** Menguji skrip terhadap masukan ekstrem:
   - String kosong (`""` / `Enter` langsung).
   - EOF (`Ctrl+D` / stream tertutup).
   - Karakter khusus & spasi (`" "`, `"user name"`, metakarakter regex/shell).
   - Nilai angka `0`, bilangan negatif, atau desimal pada field kuota/durasi.
   - Nama akun atau target yang tidak eksis di konfigurasi/database.
4. **Verifikasi Terhadap `is-decision.md`:** Memastikan perilaku anomali yang ditemukan bukan salah satu dari 28 keputusan arsitektur resmi sebelum menandainya sebagai bug.

### 2.2 Metodologi Fixing (Perbaikan Bug)
1. **Shortest Working Diff Wins:** Terapkan perubahan paling minimal yang menyelesaikan masalah secara tepat. Hindari abstraksi berlebih, wrapper yang tidak perlu, atau dependency tambahan.
2. **Batas Validasi Proporsional (Anti Over-Strictness):**
   - Username: `^[a-zA-Z0-9_]+$` (sesuai batasan panjang masing-masing protokol, tanpa melarang karakter sah).
   - FQDN / Hostname: Gunakan regex FQDN RFC (`^([[:alnum:]]([[:alnum:]-]{0,61}[[:alnum:]])?\.)+[[:alpha:]]{2,63}$`).
   - Password: Cukup validasi tidak kosong (`while [ -z "$password" ]`), tanpa syarat kompleksitas arbitrer.
   - Kuantitas: `^[1-9][0-9]*$` per Decision 4 (`0 not allowed`).
3. **Penyekatan Gerbang Mutasi:** Operasi destruktif (`rm`, `sed`, `systemctl restart`, Telegram notifikasi) wajib disekap di dalam blok kondisional keberhasilan, bukan di luar blok (contoh: Fix 306).
4. **Pencegahan Fall-Through:** Setiap branch kegagalan atau pemanggilan kembali menu navigasi (`goback`, `menu`) wajib diiringi `return` atau `exit` eksplisit (contoh: Fix 301).
5. **Evaluasi 4 Kriteria Regresi (Section 35):**
   - *Regression:* Tidak merusak fungsi yang sudah berjalan.
   - *Over-Strictness:* Tidak menolak input yang sah.
   - *Over-Engineering:* Kode seringkas mungkin.
   - *Source Alignment:* Reconcile terhadap V23, 1.20, dan `is-decision.md`.
6. **Sinkronisasi Dual-Edition & Kemasan:** Setiap perbaikan pada edisi `full/` harus diterapkan ke `lite/` jika relevan, lalu dikemas ke `menu/full.zip` dan `menu/lite.zip` dengan izin berkas `0755`.

---

## 3. Struktur 15 Fase Bug-Finding & Fixing

```
Fase 1: Keamanan Izin Berkas & Kriptografi
   │
Fase 2: Konfigurasi Kernel Sysctl & Routing Jaringan
   │
Fase 3: Unit Systemd & Pencegahan Restart Storm
   │
Fase 4: Daemon Cron Pembersihan Akun Kadaluarsa (xp.sh)
   │
Fase 5: Daemon Pembatas IP & Pencegahan Multi-Login (limit-ip)
   │
Fase 6: Daemon Akuntansi Trafik & Pemutus Kuota (quota/kill)
   │
Fase 7: Pembuatan Akun & Sanitasi Kredensial (add/trial)
   │
Fase 8: Modifikasi, Perpanjangan & Penghapusan Akun Aman (extend/delete)
   │
Fase 9: Protokol Tambahan & Siklus Hidup Tunnel (WG/Noobz/L2TP/SlowDNS)
   │
Fase 10: TUI Submenu Navigasi, Jebakan Input & Retensi Menu
   │
Fase 11: Menu Sistem, Manajemen Bot & Terowongan Argo
   │
Fase 12: Reverse Proxy Nginx & Otomasi Sertifikat ACME
   │
Fase 13: Pipeline Backup Telegram & Web-Restore Berotentikasi
   │
Fase 14: REST API Headless (FN-API & Handlers /usr/bin/rere)
   │
Fase 15: Sinkronisasi Paket Dual-Edition (full.zip & lite.zip)
```

---

### Fase 1: Keamanan Izin Berkas & Kriptografi

- **Komponen Target:** `installer/diamond.sh`, `full/dm-menu.sh`, `lite/dm-menu.sh`, `full/bmenu.sh`, `lite/bmenu.sh`, seluruh skrip `restore-ftp.sh`, direktori `/etc/xray/`, `/etc/haproxy/`, `/etc/funny/`.
- **Finding (Metodologi Penemuan):**
  - Pemindaian audit izin: cari seluruh instruksi `chmod` pada berkas sertifikat dan kunci di seluruh kode sumber (`grep -RInE 'chmod .*(xray\.key|funny\.pem|\.key|\.restore\.key)' .`).
  - Verifikasi apakah ada jalur instalasi atau restore yang masih menerapkan izin global `0644` pada kunci privat.
  - Periksa kepemilikan user:group pada berkas kunci web-restore (`/etc/funny/.restore.key`) apakah terbuka ke pengguna publik selain `root:www-data`.
  - Bandingkan dengan V23 dan 1.20 (keduanya memakai `0644` yang tidak aman) dan pastikan divergensi keamanan Fix 305 konsisten di semua skrip.
- **Fixing (Standar Perbaikan):**
  - Terapkan `chmod 600 /etc/xray/xray.key /etc/haproxy/funny.pem` pada semua alur penerbitan ACME, sertifikat self-signed, dan ekstraksi backup/restore.
  - Setel sertifikat publik `/etc/xray/xray.crt` ke `0644`.
  - Setel `/etc/xray/.key` (token API) ke `0600 root:root`.
  - Setel `/etc/funny/.restore.key` ke `0640 root:www-data`.

---

### Fase 2: Konfigurasi Kernel Sysctl & Routing Jaringan

- **Komponen Target:** `fix/fix.sh`, `installer/ssh.sh`, `installer/vpn.sh`, `udp-custom`, `udp-request`, aturan iptables/nftables.
- **Finding (Metodologi Penemuan):**
  - Audit script `fix/fix.sh` terhadap variabel sysctl yang tidak terdefinisi atau kosong (`grep -n 'NEW_FILE_MAX\|NF_CONNTRACK' fix/fix.sh`).
  - Analisis aturan iptables `udp-request`: periksa apakah aturan `SNAT 10.0.0.0/8` dieksekusi sebelum ada pengecualian IP manajemen VPS, yang berisiko memutus koneksi SSH operator (self-lockout).
  - Pengecekan listener port collision antara OpenSSH (22, 3303), Dropbear (111, 109), dan wsEpro (2080).
- **Fixing (Standar Perbaikan):**
  - Tetapkan nilai sysctl terdefinisi (`fs.file-max = 1000000`, `net.netfilter.nf_conntrack_max = 262144`).
  - Tambahkan aturan prioritas tinggi `RETURN` untuk IP manajemen sebelum aturan SNAT broad `10.0.0.0/8`.
  - Pastikan script `installer/ssh.sh` menetapkan konfigurasi port secara idempoten tanpa duplikasi baris `Port`.

---

### Fase 3: Unit Systemd & Pencegahan Restart Storm

- **Komponen Target:** Seluruh unit di `/etc/systemd/system/*.service` dan `*.timer`, pemanggilan `systemctl restart` di seluruh skrip operasional.
- **Finding (Metodologi Penemuan):**
  - Audit pemanggilan restart layanan Xray: cari apakah skrip batch melakukan restart berulang kali dalam loop (`grep -n 'systemctl restart xray' full/*.sh`).
  - Periksa pengaturan `RestartSec=` dan `StartLimitIntervalSec=` pada unit custom (`udp-custom`, `udp-request`, `dnstt`, `api.service`) untuk mencegah CPU spin saat terjadi kegagalan startup.
  - Periksa apakah ada unit dependensi yang mati diam-diam tanpa dicatat di journal.
- **Fixing (Standar Perbaikan):**
  - Rekapitulasi restart: kumpulkan daftar layanan yang terpengaruh dan lakukan satu kali `systemctl restart` di akhir pemrosesan batch.
  - Lengkapi unit service dengan `Restart=always` dan jeda wajar (`RestartSec=3s`).
  - Pastikan `systemctl daemon-reload` dipanggil setelah setiap penulisan unit systemd baru.

---

### Fase 4: Daemon Cron Pembersihan Akun Kadaluarsa (xp.sh)

- **Komponen Target:** `full/xp.sh`, `lite/xp.sh`, `full/expire-ssh.sh`, penjadwalan crontab.
- **Finding (Metodologi Penemuan):**
  - Audit logika parsing tanggal kadaluarsa: periksa perbedaan format tanggal (`YY-MM-DD` vs Unix epoch seconds).
  - Injeksi tanggal kadaluarsa rusak (string kosong, format tidak valid, tanggal masa lalu) ke dalam file JSON konfigurasi untuk melihat apakah `xp.sh` memotong file secara tidak benar.
  - Periksa perilaku Dropbear di Debian 12 (dibangun tanpa PAM): uji apakah akun kadaluarsa tetap bisa login via Dropbear jika field shadow tidak dikunci via `passwd -l`.
- **Fixing (Standar Perbaikan):**
  - Pastikan `xp.sh` membersihkan akun menggunakan pola `/### $user $exp/ {N;d}` yang presisi, diiringi pembersihan trailing comma array JSON.
  - Tambahkan penguncian shadow (`passwd -l`) pada `expire-ssh.sh` agar Dropbear non-PAM menolak login segera setelah akun kadaluarsa.
  - Batasi restart daemon Xray hanya satu kali per transport yang akunnya benar-benar terhapus.

---

### Fase 5: Daemon Pembatas IP & Pencegahan Multi-Login (limit-ip)

- **Komponen Target:** `full/limit-ip-*.sh`, `lite/limit-ip-*.sh`, `full/limit-ip.go`, `full/unlock-*.sh`.
- **Finding (Metodologi Penemuan):**
  - Uji ketersediaan API Stats: periksa respons `xray api statsonline --server=127.0.0.1:<port>`. Pastikan jika stats unavailable, script tidak menghasilkan loop error integer expression (Decision 3).
  - Audit kode biner Go `full/limit-ip.go`: cari fungsi yang memanggil `os.Exit(1)` pada alur sukses (`Credit()`).
  - Periksa pengiriman notifikasi Telegram: cari apakah terjadi unauthenticated HTTP request saat token bot kosong.
  - Uji alur penguncian: pastikan saat IP melebihi limit, akun dipindahkan ke `.locked` dan tidak dihapus total (Decision 16).
- **Fixing (Standar Perbaikan):**
  - Tambahkan guard probe API online stats; lewati eksekusi jika endpoint tidak merespons StatsService.
  - Ganti `os.Exit(1)` dengan `os.Exit(0)` pada penyelesaian normal di `limit-ip.go`.
  - Guard pengiriman notifikasi Telegram: lewati jika `/etc/funny/.chatid` atau `.keybot` tidak ada atau kosong.
  - Pastikan `unlock-*` membaca kredensial dari file `.locked` dan meregenerasi baris klien ke file JSON terkait.

---

### Fase 6: Daemon Akuntansi Trafik & Pemutus Kuota (quota/kill)

- **Komponen Target:** `full/quota-*.sh`, `lite/quota-*.sh`, `full/kill-*.sh`, `lite/kill-*.sh`, JSON template.
- **Finding (Metodologi Penemuan):**
  - Periksa apakah template JSON klien menyertakan atribut `"level": 0`. Tanpa level eksplisit, Xray tidak memproduksi counter uplink/downlink per pengguna (Decision 23).
  - Audit kueri trafik: bandingkan penggunaan perintah `xray api stats` vs `xray api statsquery -name`.
  - Injeksi pemutusan kuota: simulasikan kuota terlampaui dan verifikasi apakah akun benar-benar dihapus total (client JSON, kartu log, file quota, file usage) atau meninggalkan file phantom (Decision 16, Found 117).
- **Fixing (Standar Perbaikan):**
  - Pastikan seluruh pembuatan akun menyertakan `"level": 0` dalam objek klien JSON.
  - Gunakan `statsquery` dengan filter nama yang tepat untuk membaca konsumsi byte secara akurat.
  - Terapkan pembersihan total seketika saat kuota habis dan catat status "Deleted" (bukan "Locked").

---

### Fase 7: Pembuatan Akun & Sanitasi Kredensial (add/trial)

- **Komponen Target:** `full/add-*`, `lite/add-*`, `full/trial-*`, `lite/trial-*`, `full/addssh.sh`, `config/format.sh`.
- **Finding (Metodologi Penemuan):**
  - Pemindaian input tanpa guard: periksa seluruh baris `read -p` untuk username, password, kuota, IP limit, dan durasi (`grep -RInE 'read -p .*(Username|Password|Limit|Quota|days|masaaktif)' full/add-* full/addssh.sh`).
  - Uji masukan kosong pada password SSH: verifikasi apakah sistem menerima password kosong yang menyebabkan akun bebas login tanpa sandi (Found 308).
  - Uji masukan angka `0`: pastikan ditolak di semua field kuantitas per Decision 4.
  - Uji pembuatan duplikat: periksa apakah nama yang sudah ada ditolak sebelum file konfigurasi dimodifikasi.
  - Uji display terminal: verifikasi apakah kartu akun langsung terhapus akibat tiadanya jeda baca di `format_display` (Found 288).
- **Fixing (Standar Perbaikan):**
  - Terapkan loop validasi `while [ -z "$password" ]` pada pembuatan akun SSH.
  - Terapkan validasi `^[1-9][0-9]*$` dengan pemberitahuan tunggal `\033[38;5;208m0 not allowed\033[0m`.
  - Tambahkan pengecekan duplikasi awal via `grep -w "^### $user"`.
  - Tambahkan jeda baca kartu akun (`read -n 1 -s -r -p "Press any key to return..."`) sebelum skrip pembuat keluar ke menu pemanggil.

---

### Fase 8: Modifikasi, Perpanjangan & Penghapusan Akun Aman (extend/delete)

- **Komponen Target:** `full/delete-*`, `lite/delete-*`, `full/extend-*`, `lite/extend-*`, `full/change-id-*`, `full/change-quota-*`.
- **Finding (Metodologi Penemuan):**
  - Uji penghapusan pengguna fiktif: jalankan `delete-* notarealuser999` dan pantau apakah service direstart, file dihapus, atau notifikasi sukses palsu dikirim (Found 306).
  - Uji input EOF (`Ctrl+D`) pada prompt pemilihan pengguna untuk perpanjangan atau penggantian UUID: periksa apakah terjadi error syntax sed.
  - Audit kode keluar `Sc_Credit()` pada skrip `change-quota-*.sh`: periksa apakah menghasilkan `exit 1` saat berhasil (Found 290).
- **Fixing (Standar Perbaikan):**
  - Sekap seluruh operasi `rm -f`, `systemctl restart`, `send_log`, dan pesan sukses di dalam blok `if [ -n "$exp" ]`.
  - Pada cabang else (user tidak ditemukan), cetak pesan kesalahan dan kembali ke submenu tanpa menyentuh file atau layanan apapun.
  - Ganti `exit 1` dengan `exit 0` pada fungsi penutup `Sc_Credit()`.
  - Tambahkan guard EOF (`|| exit 0` / `|| return`) pada seluruh prompt masukan operator.

---

### Fase 9: Protokol Tambahan & Siklus Hidup Tunnel (WG/Noobz/L2TP/SlowDNS)

- **Komponen Target:** `full/menu-wg.sh`, `full/menu-noobz.sh`, `full/xl2tp.sh`, `full/menu-dnstt.sh`.
- **Finding (Metodologi Penemuan):**
  - WireGuard: uji input username kosong dan uji duplikasi. Periksa apakah setelah fungsi `goback` dipanggil, eksekusi jatuh ke bawah (fall-through) dan tetap menulis ke `/etc/wireguard/wg0.conf` (Found 300, 301).
  - NoobzVPN: uji username panjang (>16 karakter). Periksa apakah saat biner `noobzvpns add` gagal, skrip menu tetap menulis akun ke `/etc/funny/.noob` (Found 302).
  - SlowDNS: uji masukan nama server SlowDNS dengan string sembarang (misal: `"bad name"`, karakter spasi, atau newline). Periksa apakah masukan langsung diinjeksi ke baris `ExecStart` service systemd tanpa validasi FQDN (Found 303).
  - L2TP/IPsec: audit penulisan `/etc/ppp/chap-secrets` dan `/etc/ipsec.d/passwd` terhadap izin berkas dan sanitasi masukan.
- **Fixing (Standar Perbaikan):**
  - Tambahkan `return` eksplisit segera setelah pemanggilan `goback` pada alur error WireGuard.
  - Batasi username NoobzVPN ke 1–16 karakter (`^[a-zA-Z0-9_]{1,16}$`) dan cek kode keluar perintah `noobzvpns add` sebelum mencatat ke database panel.
  - Terapkan regex validasi FQDN DNS sebelum memperbarui `/etc/slowdns/nsdomain` dan meregenerasi unit `dnstt.service`.
  - Amankan izin berkas chap-secrets dan IPsec passwd ke `0600`.

---

### Fase 10: TUI Submenu Navigasi, Jebakan Input & Retensi Menu

- **Komponen Target:** `full/menu.sh`, `lite/menu.sh`, `full/menu-x.sh`, `full/menu-ssh.sh`, `full/x-*.sh`, `lite/x-*.sh`.
- **Finding (Metodologi Penemuan):**
  - Audit ketersediaan Opsi `0`: periksa setiap blok `case $aws in` di seluruh submenu untuk memastikan opsi `0` terdefinisi dan kembali ke menu induk (`grep -n 'read -p "Input option' full/menu-*.sh full/x-*.sh`).
  - Uji retensi submenu: eksekusi opsi di dalam submenu transport (misal: list, create, check), periksa apakah setelah aksi selesai operator tetap berada di submenu atau terlempar keluar ke shell prompt (Found 294, 299).
  - Periksa lokasi tampilan versi: pastikan versi XTLS dan Dropbear tidak memadati menu utama melainkan tampil di submenunya masing-masing (Decision 26, 27).
- **Fixing (Standar Perbaikan):**
  - Tambahkan opsi `${green}0${NC}. Back to Main Menu` dan penanganan `0|00) clear ; menu ;;` pada semua dispatcher yang kehilangan opsi 0.
  - Panggil ulang fungsi submenu (misal: `xws`, `xhttp`, `xsplit`, `xgrpc`, `menu-ssh`) di setiap akhir eksekusi case aksi.
  - Pertahankan display versi pada submenunya dengan fallback aman `2>/dev/null || echo "n/a"`.

---

### Fase 11: Menu Sistem, Manajemen Bot & Terowongan Argo

- **Komponen Target:** `full/menu-system.sh`, `lite/menu-system.sh`, `full/menu-bot.sh`, `lite/menu-bot.sh`, `full/menu-argo.sh`, `lite/menu-argo.sh`.
- **Finding (Metodologi Penemuan):**
  - Menu Sistem: uji opsi 1 s.d. 8; periksa apakah operator terjebak di `systemd()` tanpa opsi kembali atau terlempar setelah melihat detail sistem (Found 291).
  - Menu Bot: periksa apakah informasi konfigurasi bot atau laporan bug langsung terhapus tanpa memberi waktu operator membaca (Found 292).
  - Terowongan Argo: audit prompt `read -p "New Domain: " opws` pada fungsi `setup()`. Periksa apakah masukan sembarang langsung ditulis ke `/etc/xray/domargo` dan konfigurasi YAML cloudflared (Found 307).
- **Fixing (Standar Perbaikan):**
  - Tambahkan loop navigasi dan Opsi `0` pada `menu-system.sh` dan `menu-bot.sh`.
  - Sisipkan jeda baca sebelum layar dibersihkan pada laporan bug dan notifikasi bot.
  - Terapkan validasi FQDN DNS hostname pada domain Argo sebelum menjalankan `cloudflared tunnel route dns` atau menulis `config.yml`.

---

### Fase 12: Reverse Proxy Nginx & Otomasi Sertifikat ACME

- **Komponen Target:** `config/{4,6,dual}.conf`, `installer/diamond.sh`, `full/dm-menu.sh`, `lite/dm-menu.sh`.
- **Finding (Metodologi Penemuan):**
  - Audit timeout reverse proxy: periksa direktif timeout pada lokasi streaming Xray (`/vmspl`, `/vmgr`). Pastikan ada perlindungan terhadap body upload besar (Fix 29).
  - Uji penggantian nama domain: masukkan domain tidak valid (misal: `bad domain`, `test..com`) pada `dm-menu`. Periksa apakah string salah disubstitusikan ke konfigurasi Nginx dan seluruh kartu akun (Found 304).
  - Audit fallback sertifikat: periksa penanganan kondisi error saat Let's Encrypt mengembalikan HTTP 429 (rate limit). Pastikan skrip tidak membiarkan berkas sertifikat kosong yang menyebabkan Nginx/HAProxy gagal boot (Found 140).
- **Fixing (Standar Perbaikan):**
  - Terapkan validasi regex FQDN sebelum memperbarui `/etc/xray/domain`, Nginx `server_name`, atau kartu akun.
  - Pertahankan fallback otomatis bertingkat: Let's Encrypt -> ZeroSSL -> Self-signed certificate.
  - Pertahankan konfigurasi timeout memadai (`proxy_read_timeout 300s`, `client_body_timeout 300s`) pada endpoint streaming.

---

### Fase 13: Pipeline Backup Telegram & Web-Restore Berotentikasi

- **Komponen Target:** `full/backup.sh`, `lite/backup.sh`, `full/bmenu.sh`, `lite/bmenu.sh`, `website/upload.php`, `website/restore-ftp.sh`.
- **Finding (Metodologi Penemuan):**
  - Audit saluran backup: pastikan tidak ada URL file hosting publik pihak ketiga (seperti file.io, catbox) atau kredensial Google Drive committed yang tersisa di kode (Decision 11, 12).
  - Audit keamanan upload web restore (`website/upload.php`): periksa apakah endpoint menerima upload file `.zip` tanpa otentikasi token yang sah (Decision 19, Found 138).
  - Periksa izin berkas kunci privat setelah pemulihan (restore): pastikan berkas `/etc/xray/xray.key` dan `funny.pem` tidak tereksploitasi menjadi `0644` setelah unpack zip.
- **Fixing (Standar Perbaikan):**
  - Kirim arsip backup murni sebagai dokumen Telegram attachment dengan informasi caption minimalis (Domain, IP, Date).
  - Wajibkan otentikasi kunci `/etc/funny/.restore.key` menggunakan `hash_equals` sebelum menerima arsip di `upload.php`.
  - Pasang instruksi pengetatan izin `chmod 600` pada seluruh script pemulihan backup.

---

### Fase 14: REST API Headless (FN-API & Handlers /usr/bin/rere)

- **Komponen Target:** `rohjagad/fn-autosc-api` (`server`, `lib.sh`, handlers), `menu-api`.
- **Finding (Metodologi Penemuan):**
  - Audit antarmuka network: periksa alamat bind default server API. Pastikan server terikat ke `127.0.0.1:9000` dan tidak terbuka ke seluruh antarmuka (`0.0.0.0`) (Decision 18, `fn-api.md`).
  - Uji path traversal: uji akses request ke `GET /api/..%2f..%2fetc/passwd` untuk memastikan arsitektur handler hanya mengizinkan single path segment.
  - Uji konkruensi: kirim multiple request modifikasi secara simultan. Periksa apakah terjadi korupsi berkas JSON akibat race condition antar script panel.
  - Uji regex injection pada lookup: kirim request delete dengan nama `".*"` atau karakter wildcard. Pastikan karakter regex diescape sebelum dicocokkan (Revision 2 `fn-api.md`).
- **Fixing (Standar Perbaikan):**
  - Pastikan server Python membungkus handler dengan threading lock untuk menserialisasi eksekusi skrip mutasi.
  - Gunakan `re_escape` sebelum menyematkan nama ke pola regex pencarian JSON.
  - Sediakan respons error eksplisit untuk endpoint yang tidak didukung (`add-ss`, `add-socks`).

---

### Fase 15: Sinkronisasi Paket Dual-Edition (full.zip & lite.zip)

- **Komponen Target:** `menu/full.zip`, `menu/lite.zip`, seluruh file di `full/` dan `lite/`, biner Go (`full/*.go`).
- **Finding (Metodologi Penemuan):**
  - Audit paritas arsip: periksa apakah ada script di `full/` atau `lite/` yang telah dimodifikasi tetapi belum diperbarui ke dalam file zip (`python3 -c "import zipfile..."` komparasi hash byte).
  - Audit izin berkas di dalam zip: verifikasi apakah seluruh entri di dalam arsip memiliki external attribute executable `0755` (`(info.external_attr >> 16) & 0o777 == 0o755`).
  - Audit biner Go: periksa apakah biner `limit-ip`, `delete-ssh`, `extend-ssh`, dan `pwd-ssh` dikompilasi untuk arsitektur yang tepat (Linux amd64) dan bebas error kompilasi.
- **Fixing (Standar Perbaikan):**
  - Gunakan skrip Python zipfile idempoten untuk meregenerasi entri arsip dengan CRC32, timestamp tetap, dan mode `0755`.
  - Kompilasi ulang biner Go dari kode sumber menggunakan `CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -ldflags="-s -w"`.
  - Pastikan setiap perbaikan fungsi bersama diaplikasikan setara pada kedua edisi (`full` dan `lite`).

---

## 4. Alur Kerja Eksekusi & Kriteria Kelulusan

Untuk setiap siklus penemuan dan perbaikan bug:

1. **Tahap Finding:** Lakukan audit pola statis, uji batas masukan (fault injection), dan komparasi terhadap 2 arsip zip referensi di `original-source-do-not-edit/`.
2. **Tahap Verifikasi Awal:** Pastikan perilaku yang ditemukan bukan keputusan arsitektur di `is-decision.md` dan belum tercatat di `bugs-fixed.md`.
3. **Tahap Fixing:** Terapkan shortest working diff. Uji sintaks shell (`bash -n`) atau validasi Go.
4. **Tahap Repack & Deploy:** Perbarui arsip zip terkait, deploy ke `/usr/bin/` pada VPS uji, dan pastikan izin `0755`.
5. **Tahap Regresi:** Terapkan Gerbang 4 Pengecekan Regresi (Section 35).
6. **Tahap Dokumentasi & Commit:** Catat append-only di `bugs-found.md`, `bugs-fixed.md`, dan `bug-fixes-regression.md`. Lakukan commit atomik git.
