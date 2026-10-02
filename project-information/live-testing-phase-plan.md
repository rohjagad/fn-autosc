# Live-Testing Phase Plan

Dokumen ini memecah alur pengujian live sistem `fn-autosc` ke dalam 16 fase pengujian bertahap dari client KVM lokal Debian 12 (`/dev/kvm`) ke server target VPS `202.155.17.126` (domain: `autosc.rohcuan.dpdns.org`, port SSH: `3303`).

---

## 1. Topologi & Protokol Keselamatan

```
┌───────────────────────────────┐                  ┌───────────────────────────────┐
│     Client KVM Debian 12      │                  │       Target VPS Server       │
│          (/dev/kvm)           ├─(IPv4 Publik /)──►        202.155.17.126         │
│  Real Traffic: curl, xray,    │  (Port 3303,  )  │   Nginx, HAProxy, Xray Core,  │
│  ssh, wg-quick, noobz, dnstt  │  (80, 443, dll)  │   Daemons, Services, Systemd  │
└───────────────────────────────┘                  └───────────────────────────────┘
```

1. **Aturan Penamaan Akun Uji:**
   - Seluruh akun pengujian wajib menggunakan awalan `testcard*` atau `livetest*`.
   - Dilarang memodifikasi akun operasional persisten (`wgtest1`, `wglive1`).

2. **Snapshot Sebelum Pengujian:**
   - Sebelum menjalankan pengujian mutasi, buat snapshot file target:
     ```bash
     cp -a /etc/xray/json /tmp/snap-xray-json
     cp -a /etc/funny /tmp/snap-funny
     cp -a /etc/wireguard /tmp/snap-wireguard
     ```

3. **Pembersihan Pasca Pengujian:**
   - Hapus akun uji melalui skrip panel atau restore snapshot.
   - Bersihkan berkas log sementara di `/var/log/create/` dan berkas `.locked`.
   - Pastikan konfigurasi Xray valid: `xray run -test -config /etc/xray/json/ws.json`.

---

## 2. Dokumen & Sumber Referensi Wajib (Mandatory References)

Setiap pengujian pada seluruh fase **WAJIB** merujuk dan mencocokkan hasil aktual dengan 7 sumber referensi utama proyek:

| # | Sumber Referensi | Lokasi / Sumber | Peran dalam Pengujian Live |
| :- | :--- | :--- | :--- |
| 1 | **Bugs Fixed** | `project-information/bugs-fixed.md` | Verifikasi bahwa pengujian menguji fungsionalitas yang telah diperbaiki tanpa menyebabkan regresi pada perilaku lama. |
| 2 | **Original Sources (Both Versions)** | - **Arsip Resmi di Repo:**<br>  • `original-source-do-not-edit/V23 Linux Ubuntu, Debian, Kali.zip`<br>  • `original-source-do-not-edit/Autoscript New 1.20.zip`<br>- **Ekstraksi Kerja (Transient):**<br>  • V23: `/tmp/opencode/original-v23`<br>  • 1.20: `/tmp/opencode/original-120`<br>*(Portabel: ekstrak dari zip repo di atas bila `/tmp` tidak ada)* | Tolok ukur perilaku asli (upstream). Membedakan antara anomali yang disengaja dari upstream vs bug nyata. |
| 3 | **Git Commit History** | `git log --stat` / `git log -p` | Menelusuri riwayat mengapa suatu konfigurasi atau batasan dipasang pada commit sebelumnya. |
| 4 | **Bug Fixes Regression** | `project-information/bug-fixes-regression.md` | Memvalidasi kriteria Section 35: memastikan pengujian tidak menganggap penolakan input tidak valid sebagai over-strictness atau regresi. |
| 5 | **Bugs Found** | `project-information/bugs-found.md` | Memastikan skenario uji mencakup kasus reproduksi kegagalan yang pernah terjadi sebelumnya (contoh: bug 300 s.d. 309). |
| 6 | **FN-API Specification** | `project-information/fn-api.md` | Rujukan kontrak request, body JSON, header token, dan kode status pada pengujian API di Fase 16. |
| 7 | **Architectural Decisions** | `project-information/is-decision.md` | **Kunci Validasi:** Dilarang menganggap tes "gagal" jika perilaku sesuai dengan 28 keputusan arsitektur (misal: Xray 25.3.6, Dropbear 2019.78, akun SSH tanpa shell/home `-s /bin/false -M`, kuota habis = hapus total, quantity `0` ditolak). |

---

## 3. Struktur 16 Fase Pengujian Live

```
Fase 1: Baseline Sistem Operasi, Izin Kriptografi & Kernel Sysctl
   │
Fase 2: Reverse Proxy Utama Nginx, HAProxy & Inbound TLS
   │
Fase 3: Layanan Native SSH, Dropbear 2019.78, SSH-WS & OHP
   │
Fase 4: Suite Transport Xray WebSocket (VMess, VLESS, Trojan)
   │
Fase 5: Suite Transport Xray gRPC Streaming (vmgr, vlgr, trgr)
   │
Fase 6: Suite Transport Xray HTTPUpgrade & SplitHTTP
   │
Fase 7: Suite Tunnel VPN (WireGuard, NoobzVPN, SlowDNS, L2TP, OpenVPN)
   │
Fase 8: Siklus Pembuatan Akun & Pencegahan Duplikasi
   │
Fase 9: Penegakan Konkurensi IP & Penguncian Akun (.locked)
   │
Fase 10: Pemutusan Kuota Otomatis & Pembersihan Total Akun
   │
Fase 11: Perpanjangan Akun, Ganti Password & Penghapusan Aman
   │
Fase 12: Pembersihan Akun Kadaluarsa Otomatis (xp.sh & Cron)
   │
Fase 13: Uji TUI Menu Interaktif & Fault Injection Input Operator
   │
Fase 14: Migrasi Domain Server & Mekanisme Fallback Sertifikat ACME
   │
Fase 15: Pengujian Backup Telegram & Web-Restore Berotentikasi Token
   │
Fase 16: Pengujian Suite REST API Headless (FN-API & Concurrency Lock)
```

---

### Fase 1: Baseline Sistem Operasi, Izin Kriptografi & Kernel Sysctl
- **Tujuan:** Verifikasi kesehatan awal host VPS, status seluruh unit systemd, dan izin berkas sensitif sebelum pengujian trafik.
- **Langkah Pengujian:**
  1. Cek status aktif 16 layanan inti: `nginx`, `haproxy`, `xray@ws`, `xray@grpc`, `xray@upgrade`, `xray@split`, `noobzvpns`, `dnstt`, `wg-quick@wg0`, `openvpn`, `xl2tpd`, `dropbear`, `ws`, `fn-ohp`, `udp-custom`, `udp-request`.
  2. Pastikan `systemctl --failed` bernilai `0`.
  3. Verifikasi izin berkas: `/etc/xray/xray.key` (mode `0600`), `/etc/haproxy/funny.pem` (mode `0600`), `/etc/xray/xray.crt` (mode `0644`), `/etc/xray/.key` (mode `0600`), `/etc/funny/.restore.key` (mode `0640`).
  4. Verifikasi nilai sysctl: `fs.file-max = 1000000`, `net.netfilter.nf_conntrack_max = 262144`.

### Fase 2: Reverse Proxy Utama Nginx, HAProxy & Inbound TLS
- **Tujuan:** Memvalidasi listener TLS dan routing multiplexing port 443 dan 80.
- **Langkah Pengujian:**
  1. Uji koneksi TLS HTTPS ke `autosc.rohcuan.dpdns.org:443` dari client KVM menggunakan `curl -vI`.
  2. Pastikan sertifikat SSL valid dan handshake TLS 1.3 berhasil.
  3. Uji koneksi HTTP port 80; pastikan diarahkan atau dilayani dengan benar tanpa loop redirect.
  4. Verifikasi HAProxy hanya fronting port 777 ke backend Dropbear (`127.0.0.1:109`) mode TCP — sesuai `installer/stunnel5.sh` dan V23 upstream; Nginx menerminasi 443 langsung (tidak ada listener `10443`).

### Fase 3: Layanan Native SSH, Dropbear 2019.78, SSH-WS & OHP
- **Tujuan:** Memvalidasi seluruh front-end koneksi SSH dari client KVM.
- **Langkah Pengujian:**
  1. OpenSSH: autentikasi password pada port 22 dan 3303. Pastikan port forwarding `-L` berhasil dan shell interaktif ditolak (`/bin/false`).
  2. Dropbear: autentikasi password pada port 111 dan 109. Pastikan banner identitas `SSH-2.0-dropbear_2019.78` (Decision 25).
  3. SSH WebSocket: kirim request HTTP Upgrade pada `location /` port 80/443; pastikan mencapai backend `wsEpro` (port 2080).
  4. OHP: uji proksi OpenVPN/SSH via port 9088.

### Fase 4: Suite Transport Xray WebSocket (VMess, VLESS, Trojan)
- **Tujuan:** Verifikasi pengiriman payload trafik data nyata melalui WebSocket.
- **Langkah Pengujian:**
  1. Buat akun uji untuk VMess-WS, VLESS-WS, Trojan-WS.
  2. Eksekusi client `xray-core` pada client KVM menggunakan config JSON yang diarahkan ke path `/vmws`, `/vlws`, `/trws`.
  3. Unduh payload uji (file 5MB) melalui tunnel; pastikan checksum payload identik dan koneksi stabil.
  4. Uji konektivitas jalur NonTLS pada port 80.

### Fase 5: Suite Transport Xray gRPC Streaming (vmgr, vlgr, trgr)
- **Tujuan:** Memvalidasi komunikasi dua arah multiplex gRPC di balik Nginx.
- **Langkah Pengujian:**
  1. Buat akun uji VMess-gRPC, VLESS-gRPC, Trojan-gRPC.
  2. Jalankan client Xray dari KVM dengan konfigurasi gRPC service name `vmgr`, `vlgr`, `trgr`.
  3. Uji streaming data dua arah dan transfer file besar (>3MB) untuk memastikan tidak terbentur `client_max_body_size`.

### Fase 6: Suite Transport Xray HTTPUpgrade & SplitHTTP
- **Tujuan:** Memvalidasi transport HTTP modern Xray v25.3.6.
- **Langkah Pengujian:**
  1. HTTPUpgrade: uji koneksi VMess, VLESS, Trojan melalui path `/vmhu`, `/vlhu`, `/trhu`.
  2. SplitHTTP: uji koneksi upload dan download terpisah pada `/vmspl`.
  3. Pastikan upload file besar tidak terputus timeout Nginx 12 detik (`client_body_timeout 300s`, Fix 29).

### Fase 7: Suite Tunnel VPN (WireGuard, NoobzVPN, SlowDNS, L2TP, OpenVPN)
- **Tujuan:** Menguji konektivitas seluruh transport VPN kernel dan userspace.
- **Langkah Pengujian:**
  1. WireGuard: pasang file config client di KVM, jalankan `wg-quick up`, lakukan ping ke `10.66.66.1`.
  2. NoobzVPN: jalankan client noobzvpns ke port 8080/8443, pastikan autentikasi payload berhasil.
  3. SlowDNS: jalankan `dnstt-client` via UDP port 53 ke domain nameserver; pastikan port forwarding SSH berhasil.
  4. L2TP/IPsec: hubungkan client L2TP ke port 500/4500/1701; pastikan SA IPsec terbentuk dan IP virtual diberikan.
  5. OpenVPN: koneksi TCP port 1194 dan UDP port 2200; verifikasi negosiasi cipher TLS.

### Fase 8: Siklus Pembuatan Akun & Pencegahan Duplikasi
- **Tujuan:** Memvalidasi integritas pembuatan akun baru di semua protokol.
- **Langkah Pengujian:**
  1. Jalankan skrip pembuatan akun (`add-*`, `trial-*`, `addssh`).
  2. Verifikasi kartu akun dicetak lengkap dan terminal tidak langsung dibersihkan (pause aktif).
  3. Pastikan atribut `"level": 0` tercantum di dalam konfigurasi JSON Xray (Decision 23).
  4. Masukkan username yang sama untuk kedua kalinya; pastikan sistem menolak dengan pesan duplikasi yang jelas.

### Fase 9: Penegakan Konkurensi IP & Penguncian Akun (.locked)
- **Tujuan:** Menguji akurasi pemantauan multi-IP dan proses penguncian akun.
- **Langkah Pengujian:**
  1. Buat akun dengan limit IP = 1.
  2. Sambungkan dua koneksi bersamaan dari dua alamat IP berbeda ke akun tersebut.
  3. Picu eksekusi daemon `limit-ip-*`.
  4. Pastikan akun dipindahkan ke `<user>.locked`, dihapus dari konfigurasi aktif, dan koneksi diputus.
  5. Jalankan `unlock-*`; verifikasi akun dipulihkan kembali ke konfigurasi aktif dengan kredensial yang sama.

### Fase 10: Pemutusan Kuota Otomatis & Pembersihan Total Akun
- **Tujuan:** Memvalidasi penegakan kuota habis sesuai Decision 16.
- **Langkah Pengujian:**
  1. Buat akun dengan batas kuota kecil (misal 10 MB).
  2. Alirkan trafik melalui client KVM hingga melewati batas kuota.
  3. Jalankan `quota-*` atau `kill-*`.
  4. Pastikan akun dihapus secara total: entri JSON dihapus, file kuota dan file usage dihapus, dan log akun dibersihkan.
  5. Pastikan layanan Xray direstart bersih tanpa error JSON.

### Fase 11: Perpanjangan Akun, Ganti Password & Penghapusan Aman
- **Tujuan:** Memvalidasi modifikasi akun aktif dan keamanan penghapusan.
- **Langkah Pengujian:**
  1. Perpanjang akun (`extend-*`): verifikasi tanggal kadaluarsa bertambah dan format `YY-MM-DD` tetap valid.
  2. Ganti password SSH (`pwd-ssh`): verifikasi hash shadow diperbarui dan login menggunakan password baru berhasil.
  3. Hapus akun yang ada (`delete-*`): pastikan konfigurasi dan file terkait terhapus bersih.
  4. Hapus akun yang TIDAK ada (`delete-* notarealuser999`): pastikan tidak ada layanan yang direstart, tidak ada file yang terhapus, dan mencetak "User not found" (Fix 306).

### Fase 12: Pembersihan Akun Kadaluarsa Otomatis (xp.sh & Cron)
- **Tujuan:** Menguji pembersihan akun kadaluarsa berkala.
- **Langkah Pengujian:**
  1. Tanam akun uji dengan tanggal kadaluarsa kemarin pada file konfigurasi JSON dan database panel.
  2. Eksekusi `/usr/bin/xp`.
  3. Verifikasi akun kadaluarsa dihapus dari JSON dan database sistem.
  4. Pastikan daemon hanya merekapitulasi satu kali restart per transport (pencegahan restart storm).

### Fase 13: Uji TUI Menu Interaktif & Fault Injection Input Operator
- **Tujuan:** Memvalidasi ketahanan seluruh menu TUI terhadap input salah, kosong, atau jebakan navigasi.
- **Langkah Pengujian:**
  1. Masuk ke seluruh submenu: `menu`, `menu-x`, `menu-ssh`, `menu-wg`, `menu-noobz`, `menu-dnstt`, `menu-system`, `menu-bot`, `menu-argo`, `bmenu`, `dm-menu`.
  2. Uji Opsi `0`: pastikan seluruh submenu kembali ke menu induk tanpa keluar ke shell prompt (Fix 287–299).
  3. Uji input kosong (`Enter` kosong): pastikan prompt tidak mengalami crash atau loop tak terbatas.
  4. Uji EOF (`Ctrl+D`): pastikan skrip keluar secara anggun (`exit 0`).
  5. Uji input `0` pada durasi/kuota: pastikan ditolak dengan pesan `0 not allowed` (Decision 4).
  6. Uji karakter khusus/metakarakter: pastikan input metakarakter ditolak tanpa dievaluasi oleh shell.

### Fase 14: Migrasi Domain Server & Mekanisme Fallback Sertifikat ACME
- **Tujuan:** Memvalidasi penggantian nama domain dan sertifikat SSL.
- **Langkah Pengujian:**
  1. Masukkan input domain salah pada `dm-menu` (contoh: `bad domain`, `invalid_host`): pastikan ditolak tanpa mengubah file (Fix 304).
  2. Uji pergantian ke domain valid: pastikan file domain, konfigurasi Nginx, dan kartu akun diperbarui secara konsisten.
  3. Uji simulasi kegagalan Let's Encrypt (rate limit 429): pastikan sistem otomatis fallback ke ZeroSSL atau self-signed cert tanpa merusak startup Nginx/HAProxy (Fix 140).

### Fase 15: Pengujian Backup Telegram & Web-Restore Berotentikasi Token
- **Tujuan:** Menguji pencadangan sistem dan pemulihan darurat tanpa celah keamanan.
- **Langkah Pengujian:**
  1. Jalankan `backup`: verifikasi file arsip `.zip` terkirim sebagai dokumen ke bot Telegram (Decision 12).
  2. Pastikan tidak ada kredensial terbuka atau link publik pihak ketiga yang kadaluarsa.
  3. Uji endpoint web restore `http://<domain>:855/upload.php` (plain HTTP sesuai `website/install.sh`; PHP `upload_max_filesize/post_max_size = 64M` per Fix 327):
     - Upload tanpa token: wajib ditolak HTTP `401 Unauthorized`.
     - Upload dengan token salah: wajib ditolak HTTP `401 Unauthorized`.
     - Upload dengan token valid dari `/etc/funny/.restore.key`: file diterima dan diekstrak dengan benar (Decision 19; butuh aturan sudoers `/etc/sudoers.d/restore-ftp` per Fix 328).
  4. Pastikan seluruh kunci privat yang dipulihkan disetel kembali ke izin `0600` (Fix 305).

### Fase 16: Pengujian Suite REST API Headless (FN-API & Concurrency Lock)
- **Tujuan:** Menguji seluruh endpoint REST API dan keamanan eksekusi konkruen.
- **Langkah Pengujian:**
  1. Uji autentikasi: request tanpa header `Authorization` atau token salah wajib menghasilkan HTTP `401`.
  2. Uji path traversal: request `GET /api/..%2f..%2fetc/passwd` wajib menghasilkan HTTP `404`.
  3. Uji CRUD endpoint: jalankan `ping`, `add-vmess`, `list-xray`, `renew-xray`, `delete-xray`.
  4. Uji penolakan endpoint tak didukung: `add-ss` dan `add-socks` wajib menghasilkan respon error eksplisit.
  5. Uji konkruensi: kirim 5 request `POST /api/add-vmess` secara simultan; pastikan kelima akun terbuat sempurna tanpa korupsi file konfigurasi berkat desain single-threaded (upaya threading+lock sudah direvert, Fix 326).
