import 'package:intl/intl.dart';

String formatRupiah(num v) => NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
).format(v);

String formatTanggal(DateTime? d) =>
    d == null ? '' : DateFormat('d MMM y', 'id_ID').format(d);

int _int(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

DateTime? _date(dynamic v) {
  final d = DateTime.tryParse(v as String? ?? '');
  if (d == null) return null;
  return d.isUtc ? d.toLocal() : d;
}

class WalletSummary {
  const WalletSummary({
    required this.santriId,
    required this.saldo,
    this.nomorVa,
    this.status = '',
    this.masukHariIni = 0,
    this.keluarHariIni = 0,
    this.updatedAt,
  });

  factory WalletSummary.fromJson(Map<String, dynamic> j) {
    final h = (j['hari_ini'] as Map<String, dynamic>?) ?? const {};
    return WalletSummary(
      santriId: _int(j['santri_id']),
      nomorVa: j['nomor_va'] as String?,
      saldo: _int(j['saldo']),
      status: j['status'] as String? ?? '',
      masukHariIni: _int(h['masuk']),
      keluarHariIni: _int(h['keluar']),
      updatedAt: _date(j['updated_at']),
    );
  }

  final int santriId;
  final String? nomorVa;
  final int saldo;
  final String status;
  final int masukHariIni;
  final int keluarHariIni;
  final DateTime? updatedAt;
}

class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.jenis,
    required this.nominal,
    required this.waktu,
    this.keterangan,
    this.referensi,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> j) =>
      WalletTransaction(
        id: _int(j['id']),
        jenis: j['jenis'] as String? ?? 'masuk',
        nominal: _int(j['nominal']),
        keterangan: j['keterangan'] as String?,
        referensi: j['referensi'] as String?,
        waktu: _date(j['waktu']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      );

  final int id;

  /// `masuk` | `keluar`.
  final String jenis;
  final int nominal;
  final String? keterangan;
  final String? referensi;
  final DateTime waktu;

  bool get keluar => jenis == 'keluar';
}

class Bill {
  const Bill({
    required this.id,
    required this.invoiceNumber,
    required this.title,
    required this.totalAmount,
    required this.paidAmount,
    required this.outstandingAmount,
    required this.status,
    this.type = '',
    this.periodKey,
    this.issuedAt,
    this.dueAt,
    this.isOverdue = false,
    this.pendingPayments = 0,
  });

  factory Bill.fromJson(Map<String, dynamic> j) => Bill(
    id: '${j['id']}',
    invoiceNumber: j['invoice_number'] as String? ?? '',
    type: j['type'] as String? ?? '',
    title: j['title'] as String? ?? '',
    periodKey: j['period_key'] as String?,
    issuedAt: _date(j['issued_at']),
    dueAt: _date(j['due_at']),
    totalAmount: _int(j['total_amount']),
    paidAmount: _int(j['paid_amount']),
    outstandingAmount: _int(j['outstanding_amount']),
    status: j['status'] as String? ?? 'pending',
    isOverdue: j['is_overdue'] == true,
    pendingPayments: _int(j['pending_payments']),
  );

  final String id;
  final String invoiceNumber;
  final String type;
  final String title;
  final String? periodKey;
  final DateTime? issuedAt;
  final DateTime? dueAt;
  final int totalAmount;
  final int paidAmount;
  final int outstandingAmount;

  /// `pending` | `partial` | `paid` | `cancelled`.
  final String status;
  final bool isOverdue;
  final int pendingPayments;
}

class BillLine {
  const BillLine({required this.description, required this.amount});

  factory BillLine.fromJson(Map<String, dynamic> j) => BillLine(
    description: j['description'] as String? ?? '',
    amount: _int(j['amount']),
  );

  final String description;
  final int amount;
}

class BillPayment {
  const BillPayment({
    required this.id,
    required this.paymentNumber,
    required this.amount,
    required this.status,
    this.billId,
    this.invoiceNumber,
    this.method = '',
    this.rejectionReason,
    this.submittedAt,
    this.paidAt,
    this.hasProof = false,
  });

  factory BillPayment.fromJson(Map<String, dynamic> j) => BillPayment(
    id: '${j['id']}',
    paymentNumber: j['payment_number'] as String? ?? '',
    billId: j['bill_id'] as String?,
    invoiceNumber: j['invoice_number'] as String?,
    amount: _int(j['amount']),
    method: j['method'] as String? ?? '',
    status: j['status'] as String? ?? 'pending',
    rejectionReason: j['rejection_reason'] as String?,
    submittedAt: _date(j['submitted_at']),
    paidAt: _date(j['paid_at']),
    hasProof: j['has_proof'] == true,
  );

  final String id;
  final String paymentNumber;
  final String? billId;
  final String? invoiceNumber;
  final int amount;
  final String method;

  /// `pending` | `confirmed` | `rejected`.
  final String status;
  final String? rejectionReason;
  final DateTime? submittedAt;
  final DateTime? paidAt;
  final bool hasProof;
}

class BillDetail extends Bill {
  const BillDetail({
    required super.id,
    required super.invoiceNumber,
    required super.title,
    required super.totalAmount,
    required super.paidAmount,
    required super.outstandingAmount,
    required super.status,
    super.type,
    super.periodKey,
    super.issuedAt,
    super.dueAt,
    super.isOverdue,
    super.pendingPayments,
    this.santriId,
    this.lines = const [],
    this.payments = const [],
  });

  factory BillDetail.fromJson(Map<String, dynamic> j) {
    final b = Bill.fromJson(j);
    return BillDetail(
      id: b.id,
      invoiceNumber: b.invoiceNumber,
      type: b.type,
      title: b.title,
      periodKey: b.periodKey,
      issuedAt: b.issuedAt,
      dueAt: b.dueAt,
      totalAmount: b.totalAmount,
      paidAmount: b.paidAmount,
      outstandingAmount: b.outstandingAmount,
      status: b.status,
      isOverdue: b.isOverdue,
      pendingPayments: b.pendingPayments,
      santriId: j['santri_id'] == null ? null : _int(j['santri_id']),
      lines: ((j['lines'] as List<dynamic>?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(BillLine.fromJson)
          .toList(),
      payments: ((j['payments'] as List<dynamic>?) ?? const [])
          .cast<Map<String, dynamic>>()
          .map(BillPayment.fromJson)
          .toList(),
    );
  }

  final int? santriId;
  final List<BillLine> lines;
  final List<BillPayment> payments;
}

/// Isian form bukti transfer.
class ProofSubmission {
  const ProofSubmission({
    required this.amount,
    required this.transferredAt,
    required this.senderName,
    required this.proofPath,
    this.senderBank,
    this.destinationAccountId,
    this.note,
  });

  final int amount;
  final DateTime transferredAt;
  final String senderName;
  final String proofPath;
  final String? senderBank;
  final String? destinationAccountId;
  final String? note;
}
