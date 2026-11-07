# CBT Ulangan SD - Android Mobile App (Flutter)

Aplikasi Computer-Based Test (CBT) berbasis Flutter yang dirancang khusus:
1. **Super Ringan & Cepat**: Menggunakan paket minimalis, memory footprint sangat rendah, cocok untuk perangkat Android low-end / lama (RAM 1–2 GB).
2. **Support Android Lama**: `minSdkVersion 21` (Mendukung Android 5.0 Lollipop ke atas).
3. **1 File APK Universal**: Siswa dan guru tidak perlu bingung memilih arsitektur prosesor (semua arsitektur `armv7`, `arm64`, dan `x86_64` digabung dalam satu file APK).
4. **Anti-Cheat Terintegrasi**:
   - `FLAG_SECURE`: Anti screenshot & anti screen-recording.
   - Deteksi keluar aplikasi (`AppLifecycleState` `paused`/`inactive`) yang otomatis dilaporkan ke endpoint `/api/v1/student/exam-sessions/{token}/violation`.
   - Pencegahan tombol back hardware (`PopScope`).
   - Dukungan Kiosk Screen Pinning (`startLockTask`).
5. **Offline-First Autosave**: Jawaban langsung tersimpan secara instan di storage lokal sebelum disinkronkan ke server melalui background request, menjamin tidak ada jawaban yang hilang jika koneksi Wi-Fi lab sekolah mengalami gangguan.

---

## Struktur Folder

```text
mobile/
├── android/                  # Native Android configuration (minSdk 21, cleartext LAN permitted)
│   └── app/src/main/
│       ├── AndroidManifest.xml
│       └── kotlin/.../MainActivity.kt  # MethodChannel native security (Kiosk Lock, FLAG_SECURE)
├── lib/
│   ├── main.dart             # Entry point & routing
│   ├── core/
│   │   ├── api/              # HTTP Client & REST API endpoints
│   │   ├── constants/        # Server base URL & storage keys
│   │   ├── security/         # Anti-cheat bridge
│   │   └── storage/          # Local answer autosave
│   ├── models/               # User, Exam, Question, Option models
│   └── screens/
│       ├── login_screen.dart        # Login NIS/Email + konfigurasi IP Server
│       ├── exam_list_screen.dart    # Daftar ujian aktif siswa
│       ├── exam_token_dialog.dart   # Input token ujian pengawas
│       ├── exam_taking_screen.dart  # Layar ujian CBT (Timer, Grid Soal, Navigasi)
│       └── exam_result_screen.dart  # Konfirmasi selesai ujian
└── pubspec.yaml
```

---

## Persiapan & Setup SDK di Laptop

Untuk menginstal Flutter SDK, JDK 21, dan Android SDK secara otomatis tanpa perlu root/sudo, jalankan:

```bash
./scripts/setup_mobile_sdk.sh
```

Script di atas akan:
- Mengunduh & memasang OpenJDK 21 (Adoptium Temurin) di `~/.jdk/temurin-21`.
- Mengunduh & mengekstrak Flutter SDK Stable di `~/flutter`.
- Mengunduh Android Command-line Tools, Platform-tools, dan SDK Platform 34 di `~/Android/Sdk`.
- Memperbarui `~/.bashrc` dengan environment variable yang dibutuhkan.

Setelah selesai, jalankan:
```bash
source ~/.bashrc
flutter doctor
```

---

## Menjalankan di Mode Development

```bash
cd mobile
flutter pub get
flutter run
```

---

## Membuat 1 File APK Universal

Untuk menghasilkan 1 file installer APK universal yang kompatibel dengan semua tipe HP/tablet:

```bash
cd mobile
flutter build apk --release
```

Hasil file APK siap pakai akan berada di:
```text
mobile/build/app/outputs/flutter-apk/app-release.apk
```
File ini dapat langsung dibagikan ke siswa melalui flashdisk, Google Drive, atau WhatsApp tanpa perlu memilih tipe HP.
