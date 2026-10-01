# Bug-Fixing Phase Plan

Dokumen ini memecah rencana perbaikan bug dan audit kode `fn-autosc` ke dalam 15 fase terperinci dan berurutan. Setiap fase memiliki fokus komponen spesifik, batas audit, dan kriteria evaluasi regresi sesuai standar proyek.

---

## 1. Dokumen & Sumber Referensi Wajib (Mandatory References)

Setiap langkah dalam seluruh fase perbaikan bug **WAJIB** membaca dan mengacu pada 7 sumber referensi utama berikut sebelum melakukan analisis, perubahan kode, atau evaluasi regresi:

| # | Sumber Referensi | Lokasi / Perintah | Kegunaan & Batas Kepatuhan |
| :- | :--- | :--- | :--- |
| 1 | **Bugs Fixed** | `project-information/bugs-fixed.md` | Daftar seluruh perbaikan yang telah diverifikasi (Fix 1 s.d. 309). Wajib diperiksa agar perbaikan baru tidak membatalkan atau mengulang perbaikan sebelumnya. |
| 2 | **Original Sources (Both Versions)** | - V23: `/tmp/opencode/original-v23`<br>- 1.20: `/tmp/opencode/original-120` | Sumber rujukan asli (upstream). Wajib dicompare sebelum mengubah logika: jika referensi sudah menyelesaikan masalah, pertahankan solusi referensi. Divergensi hanya diizinkan untuk keamanan & stabilitas yang terbukti. |
| 3 | **Git Commit History** | `git log --stat` / `git log -p` | Catatan riwayat commit atomik repositori. Memahami konteks perubahan sebelumnya, alasan teknis patch masa lalu, dan evolusi setiap script. |
| 4 | **Bug Fixes Regression** | `project-information/bug-fixes-regression.md` | Rekam evaluasi 4-Check Rule (Regression, Over-Strictness, Over-Engineering, Source Alignment). Setiap perubahan baru wajib lulus 4 kriteria ini. |
| 5 | **Bugs Found** | `project-information/bugs-found.md` | Rekam jejak temuan bug historis (append-only, Found 1 s.d. 309). Memastikan akar penyebab terdokumentasi akurat sebelum patch diterapkan. |
| 6 | **FN-API Specification** | `project-information/fn-api.md` | Kontrak spesifikasi headless REST API, arsitektur handler `/usr/bin/rere`, penanganan single path segment, otentikasi token `/etc/xray/.key`, dan serializing lock. |
| 7 | **Architectural Decisions** | `project-information/is-decision.md` | Daftar 28 keputusan desain arsitektural yang disengaja (bukan bug). Wajib dibaca agar tidak "memperbaiki" perilaku yang sengaja dirancang demikian (contoh: Xray 25.3.6 pin, Dropbear 2019.78 pin, auth lifetime vs date, penolakan angka 0, penghapusan total pada kuota habis). |

---

## 2. Prinsip & Standar Teknis

1. **Shortest Working Diff Wins:**
   - Gunakan fitur native shell POSIX dan utility standar Linux.
   - Minimalisir modifikasi; jangan menambah abstraksi atau helper yang tidak diminta.
   - Hapus kode rusak daripada menambal lapis demi lapis (deletion over addition).

2. **Batas Validasi (Anti Over-Strictness):**
   - Username: gunakan `^[a-zA-Z0-9_]+$` (sesuai batas daemon, contoh NoobzVPN maks 16 karakter). Jangan memblokir karakter valid.
   - Domain/Hostname: gunakan regex FQDN standar RFC (`^([[:alnum:]]([[:alnum:]-]{0,61}[[:alnum:]])?\.)+[[:alpha:]]{2,63}$`).
   - Password: wajib tidak kosong (`while [ -z "$password" ]`), tanpa syarat kompleksitas arbitrer yang merusak otomasi.
   - Angka kuota/hari/limit: wajib `^[1-9][0-9]*$` per Decision 4 (`0` dilarang, tidak ada ambigu "unlimited").

3. **Rekonsiliasi Sumber Asli (V23 & Autoscript New 1.20):**
   - Jika sumber asli sudah memiliki solusi yang bekerja (contoh: header proxy nginx), pertahankan solusi referensi.
   - Divergensi hanya diizinkan untuk keamanan (chmod `0600` private key, token web-restore) dan stabilitas (pinning Xray 25.3.6, Dropbear 2019.78).

4. **Gerbang 4 Pengecekan Regresi (Section 35):**
   - Regression (apakah ada alur kerja valid yang rusak?).
   - Over-strictness (apakah memblokir input sah?).
   - Over-engineering (apakah kode terlalu rumit?).
   - Alignment vs Source (apakah konsisten dengan sumber referensi & `is-decision.md`?).

---

## 3. Struktur 15 Fase Bug-Fixing

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
- **Komponen:** `installer/diamond.sh`, `full/dm-menu.sh`, `lite/dm-menu.sh`, `full/bmenu.sh`, `lite/bmenu.sh`, seluruh varian `restore-ftp.sh`.
- **Fokus:**
  - Penegakan izin berkas private key TLS (`/etc/xray/xray.key`) dan bundle HAProxy (`/etc/haproxy/funny.pem`) ke mode `0600` (Fix 305).
  - Sertifikat publik (`xray.crt`) tetap `0644`.
  - Token API (`/etc/xray/.key`) tetap `0600`.
  - Kunci otentikasi web restore (`/etc/funny/.restore.key`) tetap `0640` milik `root:www-data` (Decision 19).

### Fase 2: Konfigurasi Kernel Sysctl & Routing Jaringan
- **Komponen:** `fix/fix.sh`, `installer/ssh.sh`, `installer/vpn.sh`, `udp-custom`, `udp-request`.
- **Fokus:**
  - Penataan parameter kernel (`fs.file-max = 1000000`, `net.netfilter.nf_conntrack_max = 262144`).
  - Pencegahan penguncian sendiri (self-lockout) pada aturan SNAT `udp-request` (penambahan aturan `RETURN` manajemen IP).
  - Pengecekan port collision dan listener binding (OpenSSH 22 & 3303, Dropbear 111 & 109).

### Fase 3: Unit Systemd & Pencegahan Restart Storm
- **Komponen:** `/etc/systemd/system/*.service`, `/etc/systemd/system/*.timer`.
- **Fokus:**
  - Konfigurasi `Restart=always` dan restart rate limiting yang stabil.
  - Memastikan unit background tidak memicu cascade restart pada layanan inti.
  - Pembatasan restart layanan Xray menjadi maksimal satu kali per siklus per transport.

### Fase 4: Daemon Cron Pembersihan Akun Kadaluarsa (xp.sh)
- **Komponen:** `full/xp.sh`, `lite/xp.sh`, `full/expire-ssh.sh`.
- **Fokus:**
  - Konsistensi perbandingan tanggal kadaluarsa (format Unix timestamp vs format string `YY-MM-DD`).
  - Penanganan khusus Dropbear tanpa PAM di Debian 12 (penulisan langsung ke field shadow expire atau lock akun).
  - Penghapusan akun secara atomik tanpa merusak sintaks array JSON Xray.

### Fase 5: Daemon Pembatas IP & Pencegahan Multi-Login (limit-ip)
- **Komponen:** `full/limit-ip-*.sh`, `lite/limit-ip-*.sh`, `full/limit-ip.go`.
- **Fokus:**
  - Pengecekan ketersediaan endpoint Xray StatsService sebelum pemindaian untuk menghindari loop error (Decision 3).
  - Penguncian akun yang melanggar batas ke format `<user>.locked` tanpa menghapus file kuota/log (Decision 16).
  - Kode keluar daemons: pastikan `os.Exit(0)` saat sukses, bukan `1` (Fix 294).

### Fase 6: Daemon Akuntansi Trafik & Pemutus Kuota (quota/kill)
- **Komponen:** `full/quota-*.sh`, `lite/quota-*.sh`, `full/kill-*.sh`, `lite/kill-*.sh`.
- **Fokus:**
  - Pemutusan total akun (hard deletion) saat kuota habis: hapus entri JSON, file kuota, log, dan kartu akun (Decision 16).
  - Pengambilan metrik trafik via `xray api statsquery` dengan flag `-name` yang tepat.
  - Penjaminan keberadaan atribut `"level": 0` pada setiap klien JSON agar core Xray menghasilkan metrik (Decision 23).

### Fase 7: Pembuatan Akun & Sanitasi Kredensial (add/trial)
- **Komponen:** `full/add-*`, `lite/add-*`, `full/trial-*`, `lite/trial-*`, `full/addssh.sh`.
- **Fokus:**
  - Penolakan password kosong pada akun sistem SSH (`full/addssh.sh`, Fix 308).
  - Penolakan input angka `0` atau non-digit pada durasi, kuota, dan limit IP (Decision 4).
  - Pengecekan duplikasi username sebelum menyentuh file konfigurasi.
  - Penghentian hapus layar instan (`format_display` pause) agar kartu akun terbaca operator (Fix 288).

### Fase 8: Modifikasi, Perpanjangan & Penghapusan Akun Aman (extend/delete)
- **Komponen:** `full/delete-*`, `lite/delete-*`, `full/extend-*`, `lite/extend-*`, `full/change-id-*`, `full/change-quota-*`.
- **Fokus:**
  - Penanganan username tidak ditemukan: blokir penghapusan file dan restart layanan jika akun tidak ada (Fix 306).
  - Penanganan input EOF (`Ctrl+D`) atau string kosong pada prompt modifikasi.
  - Pembetulan kode keluar `Sc_Credit()` dari `exit 1` menjadi `exit 0` pada pengubahan kuota (Fix 295).

### Fase 9: Protokol Tambahan & Siklus Hidup Tunnel (WG/Noobz/L2TP/SlowDNS)
- **Komponen:** `full/menu-wg.sh`, `full/menu-noobz.sh`, `full/xl2tp.sh`, `full/menu-dnstt.sh`.
- **Fokus:**
  - WireGuard: tolak nama kosong, cegah fall-through mutasi setelah error `goback` (Fix 300, 301).
  - NoobzVPN: batasi panjang username 1–16 karakter dan verifikasi kode keluar CLI sebelum mencatat ke database panel (Fix 302).
  - SlowDNS: validasi FQDN nameserver sebelum menginjeksi baris `ExecStart` pada service dnstt (Fix 303).
  - L2TP/IPsec: pastikan izin file chap-secrets `0600` dan konversi durasi hari valid.

### Fase 10: TUI Submenu Navigasi, Jebakan Input & Retensi Menu
- **Komponen:** `full/menu.sh`, `lite/menu.sh`, `full/menu-x.sh`, `full/menu-ssh.sh`, `full/x-*.sh`.
- **Fokus:**
  - Ketersediaan Opsi `0` (Kembali ke menu sebelumnya) di semua submenu tanpa exception (Fix 287–292, 296).
  - Retensi submenu: panggil ulang fungsi menu setelah eksekusi aksi agar operator tidak terlempar ke shell (Fix 294, 299).
  - Tampilan versi layanan: letakkan informasi versi pada submenunya masing-masing (Decision 26, 27).

### Fase 11: Menu Sistem, Manajemen Bot & Terowongan Argo
- **Komponen:** `full/menu-system.sh`, `full/menu-bot.sh`, `full/menu-argo.sh`.
- **Fokus:**
  - Menu sistem: penambahan jeda baca sebelum layar dibersihkan dan loop submenu (Fix 296).
  - Menu bot: isolasi konfigurasi token bot Telegram di `/etc/funny/.keybot` dan chat ID di `/etc/funny/.chatid`.
  - Terowongan Argo: validasi FQDN domain terowongan sebelum penulisan ke YAML cloudflared (Fix 307).

### Fase 12: Reverse Proxy Nginx & Otomasi Sertifikat ACME
- **Komponen:** `config/{4,6,dual}.conf`, `installer/diamond.sh`, `full/dm-menu.sh`, `lite/dm-menu.sh`.
- **Fokus:**
  - Penyetelan timeout Nginx pada transport streaming (`/vmspl`, `/vmgr`) untuk mencegah pemutusan koneksi (Fix 29).
  - Fallback sertifikat otomatis: Let's Encrypt -> ZeroSSL -> Self-signed cert untuk mencegah kegagalan boot Nginx/HAProxy (Fix 140).
  - Validasi ketat nama domain baru menggunakan regex FQDN sebelum memperbarui file konfigurasi Nginx dan kartu akun (Fix 304).

### Fase 13: Pipeline Backup Telegram & Web-Restore Berotentikasi
- **Komponen:** `full/backup.sh`, `lite/backup.sh`, `full/bmenu.sh`, `lite/bmenu.sh`, `website/upload.php`, `website/restore-ftp.sh`.
- **Fokus:**
  - Pengiriman backup eksklusif sebagai dokumen Telegram (tanpa file hosting pihak ketiga, Decision 11, 12).
  - Otentikasi upload restore via web: wajib validasi token `/etc/funny/.restore.key` menggunakan `hash_equals` (Decision 19).
  - Pasca-restore: pastikan skrip restore otomatis menyetel izin berkas kunci privat ke `0600`.

### Fase 14: REST API Headless (FN-API & Handlers /usr/bin/rere)
- **Komponen:** `rohjagad/fn-autosc-api` (`server`, `lib.sh`, handlers).
- **Fokus:**
  - Binding server ketat ke loopback `127.0.0.1:9000` (Decision 18, `fn-api.md`).
  - Pembatasan single path segment untuk mencegah path traversal `/../etc/passwd`.
  - Serialisasi eksekusi handler yang memodifikasi file konfigurasi menggunakan lock untuk mencegah race condition (Revision 2 `fn-api.md`).
  - Escaping karakter regex pada username sebelum pencocokan pola penghapusan akun.

### Fase 15: Sinkronisasi Paket Dual-Edition (full.zip & lite.zip)
- **Komponen:** `menu/full.zip`, `menu/lite.zip`, biner Go (`limit-ip`, `delete-ssh`, `extend-ssh`, `pwd-ssh`).
- **Fokus:**
  - Kepastian integritas byte-identical antara skrip di direktori source (`full/`, `lite/`) dengan entri dalam arsip zip.
  - Penegakan izin eksekusi standar POSIX (`0755`) pada seluruh file di dalam arsip zip.
  - Kompilasi biner Go target Linux amd64 dengan flag strip simbol `-ldflags="-s -w"`.
