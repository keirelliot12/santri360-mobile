DateTime? _d(Object? v) => v is String ? DateTime.tryParse(v) : null;

/// Perizinan (`PerizinanResource`).
class Permission {
  const Permission({
    required this.id,
    this.jenis,
    this.alasan,
    this.mulai,
    this.selesai,
    this.kembaliAktual,
    this.status = '',
    this.catatan,
    this.alasanPenolakan,
  });

  /// [status] memakai `status_portal` bila ada, jika tidak `status`.
  factory Permission.fromJson(Map<String, dynamic> j) => Permission(
    id: (j['id'] as num).toInt(),
    jenis: j['jenis_izin'] as String?,
    alasan: j['alasan'] as String?,
    mulai: _d(j['waktu_mulai']),
    selesai: _d(j['waktu_selesai']),
    kembaliAktual: _d(j['waktu_kembali_aktual']),
    status: ((j['status_portal'] ?? j['status']) as String? ?? '')
        .toLowerCase(),
    catatan: j['catatan_pengurus'] as String?,
    alasanPenolakan: j['alasan_penolakan'] as String?,
  );

  final int id;
  final String? jenis;
  final String? alasan;
  final DateTime? mulai;
  final DateTime? selesai;
  final DateTime? kembaliAktual;
  final String status;
  final String? catatan;
  final String? alasanPenolakan;
}

/// Pelanggaran (`PelanggaranResource`).
class Violation {
  const Violation({
    required this.id,
    this.kategori,
    this.deskripsi,
    this.poin = 0,
    this.tindakan,
    this.tanggal,
    this.status = '',
  });

  factory Violation.fromJson(Map<String, dynamic> j) => Violation(
    id: (j['id'] as num).toInt(),
    kategori: j['kategori'] as String?,
    deskripsi: j['deskripsi'] as String?,
    poin: (j['poin_takzir'] as num?)?.toInt() ?? 0,
    tindakan: j['tindakan'] as String?,
    tanggal: _d(j['tanggal_pelanggaran']),
    status: ((j['status_portal'] ?? j['status']) as String? ?? '')
        .toLowerCase(),
  );

  final int id;
  final String? kategori;
  final String? deskripsi;
  final int poin;
  final String? tindakan;
  final DateTime? tanggal;
  final String status;
}

/// Riwayat kesehatan. Data sensitif: jangan di-log.
class HealthRecord {
  const HealthRecord({
    required this.id,
    this.keluhan,
    this.diagnosa,
    this.tindakanMedis,
    this.obat,
    this.tanggal,
    this.perluDirujuk = false,
    this.status,
  });

  factory HealthRecord.fromJson(Map<String, dynamic> j) => HealthRecord(
    id: (j['id'] as num).toInt(),
    keluhan: j['keluhan'] as String?,
    diagnosa: j['diagnosa'] as String?,
    tindakanMedis: j['tindakan_medis'] as String?,
    obat: j['obat_diberikan'] as String?,
    tanggal: _d(j['tanggal_periksa']),
    perluDirujuk: j['perlu_dirujuk'] == true,
    status: j['status'] as String?,
  );

  final int id;
  final String? keluhan;
  final String? diagnosa;
  final String? tindakanMedis;
  final String? obat;
  final DateTime? tanggal;
  final bool perluDirujuk;
  final String? status;

  // Tanpa toString/log: data kesehatan sensitif.
}
