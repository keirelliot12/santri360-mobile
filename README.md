# Santri360 Mobile

App Flutter (Android/iOS) untuk wali santri & pengurus, terhubung ke backend `manajemen-santri-360-be`.
Rancangan: `docs/plans/2026-10-08-mobile-app-design.md` di repo backend. Kontrak API: `docs/openapi.yaml` (repo backend).

## White-label per pesantren
Satu codebase. Satu folder per tenant, `tenants/<slug>/`:

| File | Wajib | Isi |
|---|---|---|
| `config.json` | ya | `TENANT_CODE`, `APP_NAME` (≤30), `APP_ID` (reverse-domain, unik), `API_BASE_URL` (https), `PRIMARY_COLOR` (`0xAARRGGBB`), `SENTRY_DSN` |
| `icon.png` | tidak | 1024×1024 tanpa transparansi; tanpa file ini dipakai ikon bawaan |
| `icon_foreground.png` | tidak | foreground adaptive icon Android (latar putih) |

```bash
flutter pub get
dart run tool/tenant.dart validate                       # skema + keunikan APP_ID/TENANT_CODE
flutter run --dart-define-from-file=tenants/demo/config.json
flutter test && flutter analyze
```
- **Android**: `applicationId` & label dibaca Gradle dari `--dart-define-from-file` — tidak ada langkah tambahan. Build rilis tanpa config tenant gagal.
- **iOS / ikon**: jalankan `dart run tool/tenant.dart apply <slug>` dulu (menulis `ios/Flutter/Tenant.xcconfig` yang di-gitignore + generate ikon). Ikon hasil generate jangan di-commit kecuali ikon bawaan.
- Header `X-Pesantren-Code` dikirim otomatis; login ditolak bila akun bukan milik pesantren app tsb.

### Tambah tenant baru
1. `tenants/<slug>/config.json` (+ ikon), `dart run tool/tenant.dart validate`.
2. Buat GitHub Environment bernama `<slug>` (Settings → Environments), aktifkan *required reviewers*, isi secret:
   `ANDROID_KEYSTORE_BASE64` (`base64 -w0 upload.jks`), `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`.
   Upload key **per tenant** (tiap app punya listing Play sendiri); aktifkan Play App Signing.
3. Rilis: push tag `vX.Y.Z` (semua tenant) atau *Actions → Release Android → Run workflow* (satu tenant).

## CI/CD
- `ci.yml` (PR & main): format, analyze, validasi tenant, test → smoke build APK `demo` + cek `applicationId`; iOS `--no-codesign` hanya di main.
- `release.yml` (tag/manual): matrix per tenant → AAB rilis ter-sign, `--obfuscate` + simbol & mapping R8 sebagai artifact (90 hari). `versionCode` = `github.run_number` (monoton).
- Belum: upload otomatis ke Play (fastlane/`upload-google-play`), rilis iOS (fastlane match + akun App Store tiap pesantren), Firebase per tenant (bersama G1 push).

## Struktur
- `lib/core/` — config tenant, dio + interceptor (auth, tenant, idempotency), router (go_router), tema
- `lib/features/<fitur>/` — model, provider (Riverpod), halaman
- `lib/shared/` — util

## Status F0
- [x] Auth (login/me/logout, cek tenant), gate versi/maintenance (G14), bootstrap modul + kontak WA (G12)
- [x] Beranda: switcher multi-anak, menu cepat sesuai entitlement, hubungi pengurus (WA)
- [x] Akun: logout, ajukan hapus akun (G20)
- [x] applicationId/nama/ikon per tenant dari `tenants/<slug>/`, CI smoke build + release matrix per tenant
- [ ] F1: layar Nilai, Rapor, Tahfidz, Izin, Pelanggaran, Kesehatan, Pengumuman, Tabungan; push FCM (G1)
