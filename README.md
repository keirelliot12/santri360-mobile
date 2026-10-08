# Santri360 Mobile

App Flutter (Android/iOS) untuk wali santri & pengurus, terhubung ke backend `manajemen-santri-360-be`.
Rancangan: `docs/plans/2026-10-08-mobile-app-design.md` di repo backend. Kontrak API: `docs/openapi.yaml` (repo backend).

## White-label per pesantren
Satu codebase, satu konfigurasi per tenant di `tenants/<slug>/config.json`
(`TENANT_CODE`, `APP_NAME`, `APP_ID`, `API_BASE_URL`, `PRIMARY_COLOR`, `SENTRY_DSN`).

```bash
flutter pub get
flutter run --dart-define-from-file=tenants/demo/config.json
flutter test && flutter analyze
```
Header `X-Pesantren-Code` dikirim otomatis; login ditolak bila akun bukan milik pesantren app tsb.

## Struktur
- `lib/core/` — config tenant, dio + interceptor (auth, tenant, idempotency), router (go_router), tema
- `lib/features/<fitur>/` — model, provider (Riverpod), halaman
- `lib/shared/` — util

## Status F0
- [x] Auth (login/me/logout, cek tenant), gate versi/maintenance (G14), bootstrap modul + kontak WA (G12)
- [x] Beranda: switcher multi-anak, menu cepat sesuai entitlement, hubungi pengurus (WA)
- [x] Akun: logout, ajukan hapus akun (G20)
- [ ] applicationId/ikon per tenant (gradle flavor dari `APP_ID`), CI build per tenant
- [ ] F1: layar Nilai, Rapor, Tahfidz, Izin, Pelanggaran, Kesehatan, Pengumuman, Tabungan; push FCM (G1)
