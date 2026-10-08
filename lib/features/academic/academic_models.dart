num _n(Object? v) => v is num ? v : num.tryParse('$v') ?? 0;

int? _i(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');

String? _s(Object? v) => v == null ? null : '$v';

/// Tanggal ISO -> dd-MM-yyyy; tampilkan apa adanya bila bukan ISO.
String? shortDate(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  final l = d.toLocal();
  String p(int x) => x.toString().padLeft(2, '0');
  return '${p(l.day)}-${p(l.month)}-${l.year}';
}

class ScoreComponent {
  const ScoreComponent({
    this.komponen,
    required this.nilai,
    required this.bobot,
  });

  factory ScoreComponent.fromJson(Map<String, dynamic> j) => ScoreComponent(
    komponen: _s(j['komponen']),
    nilai: _n(j['nilai']),
    bobot: _n(j['bobot']),
  );

  final String? komponen;
  final num nilai;
  final num bobot;
}

/// Dari `WaliScore` (`/akademik/portal-wali/scores`): nilai akhir per mapel.
class WaliScore {
  const WaliScore({
    required this.santriId,
    required this.mapelId,
    required this.namaMapel,
    required this.nilaiAkhir,
    this.komponen = const [],
  });

  factory WaliScore.fromJson(Map<String, dynamic> j) => WaliScore(
    santriId: _i(j['santri_id']) ?? 0,
    mapelId: _i(j['mata_pelajaran_id']) ?? 0,
    namaMapel: j['nama_mapel'] as String? ?? '-',
    nilaiAkhir: _n(j['nilai_akhir']),
    komponen: ((j['komponen'] as List<dynamic>?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(ScoreComponent.fromJson)
        .toList(),
  );

  final int santriId;
  final int mapelId;
  final String namaMapel;
  final num nilaiAkhir;
  final List<ScoreComponent> komponen;
}

class Rapor {
  const Rapor({
    required this.id,
    this.nomor,
    this.semester,
    this.tahunAjaran,
    this.publishedAt,
    this.catatan,
    this.bisaUnduh = false,
  });

  factory Rapor.fromJson(Map<String, dynamic> j) => Rapor(
    id: _i(j['id']) ?? 0,
    nomor: _s(j['nomor']),
    semester: _s(j['semester']),
    tahunAjaran:
        (j['tahun_ajaran'] as Map<String, dynamic>?)?['nama'] as String?,
    publishedAt: _s(j['published_at']),
    catatan: _s(j['catatan_walikelas']),
    bisaUnduh: j['download_url'] != null,
  );

  final int id;
  final String? nomor;
  final String? semester;
  final String? tahunAjaran;
  final String? publishedAt;
  final String? catatan;

  /// `download_url` null berarti PDF belum tersedia. URL-nya tidak dipakai:
  /// unduh lewat endpoint ber-Bearer agar token tidak ada di URL.
  final bool bisaUnduh;
}

class Setoran {
  const Setoran({
    required this.id,
    this.tanggal,
    this.dariSurah,
    this.dariAyat,
    this.sampaiSurah,
    this.sampaiAyat,
    this.jumlahBaris,
    this.kelancaran,
    this.catatan,
  });

  factory Setoran.fromJson(Map<String, dynamic> j) => Setoran(
    id: _i(j['id']) ?? 0,
    tanggal: _s(j['tanggal']),
    dariSurah: _s(j['dari_surah']),
    dariAyat: _i(j['dari_ayat']),
    sampaiSurah: _s(j['sampai_surah']),
    sampaiAyat: _i(j['sampai_ayat']),
    jumlahBaris: _i(j['jumlah_baris']),
    kelancaran: _s(j['kelancaran']),
    catatan: _s(j['catatan']),
  );

  final int id;
  final String? tanggal;
  final String? dariSurah;
  final int? dariAyat;
  final String? sampaiSurah;
  final int? sampaiAyat;
  final int? jumlahBaris;
  final String? kelancaran;
  final String? catatan;

  /// Mis. "Al-Baqarah 1 - Al-Baqarah 20".
  String get rentang {
    String sisi(String? surah, int? ayat) =>
        [?surah, ?(ayat == null ? null : '$ayat')].join(' ');
    final a = sisi(dariSurah, dariAyat);
    final b = sisi(sampaiSurah, sampaiAyat);
    if (a.isEmpty && b.isEmpty) return '-';
    return b.isEmpty || a == b ? a : '$a - $b';
  }
}

class Tahfidz {
  const Tahfidz({
    required this.santriId,
    required this.nama,
    required this.totalSetoran,
    required this.totalBaris,
    this.riwayat = const [],
  });

  factory Tahfidz.fromJson(Map<String, dynamic> j) => Tahfidz(
    santriId: _i(j['santri_id']) ?? 0,
    nama: j['nama'] as String? ?? '',
    totalSetoran: _i(j['total_setoran']) ?? 0,
    totalBaris: _i(j['total_baris']) ?? 0,
    riwayat: ((j['riwayat'] as List<dynamic>?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(Setoran.fromJson)
        .toList(),
  );

  final int santriId;
  final String nama;
  final int totalSetoran;
  final int totalBaris;
  final List<Setoran> riwayat;

  /// Perkiraan kasar (15 baris/halaman, 20 halaman/juz). Indikatif saja karena
  /// API belum mengirim progres juz resmi.
  double get perkiraanJuz => (totalBaris / 300).clamp(0, 30).toDouble();
}

class Sertifikat {
  const Sertifikat({
    required this.id,
    this.nomor,
    this.jenis,
    this.juzKe,
    this.issuedAt,
    this.verifyUrl,
  });

  factory Sertifikat.fromJson(Map<String, dynamic> j) => Sertifikat(
    id: _i(j['id']) ?? 0,
    nomor: _s(j['nomor']),
    jenis: _s(j['jenis']),
    juzKe: _i(j['juz_ke']),
    issuedAt: _s(j['issued_at']) ?? _s(j['published_at']),
    verifyUrl: _s(j['verify_url']),
  );

  final int id;
  final String? nomor;
  final String? jenis;
  final int? juzKe;
  final String? issuedAt;
  final String? verifyUrl;
}
