import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';
import 'package:santri360/core/network/api_exception.dart';
import 'package:santri360/core/network/api_response.dart';
import 'package:santri360/features/app_config/bootstrap.dart';
import 'package:santri360/features/children/child.dart';
import 'package:santri360/features/finance/bukti_page.dart';
import 'package:santri360/features/finance/finance_models.dart';
import 'package:santri360/features/finance/finance_repository.dart';
import 'package:santri360/features/finance/keuangan_page.dart';
import 'package:santri360/features/finance/tagihan_pages.dart';

class _MockRepo extends Mock implements FinanceRepository {}

class _MockPicker extends Mock implements ImagePicker {}

Paginated<T> _page<T>(
  List<T> items, {
  Map<String, dynamic> meta = const {},
  int last = 1,
}) => Paginated(
  items: items,
  currentPage: 1,
  lastPage: last,
  total: items.length,
  meta: meta,
);

const _accounts = [
  PaymentAccount(
    id: 'a1',
    bank: 'BSI',
    accountNumber: '7001234567',
    accountName: 'Pesantren X',
  ),
];

Bill _bill({
  String id = 'b-1',
  String title = 'SPP Oktober 2026',
  int outstanding = 400000,
  bool overdue = false,
  int pending = 0,
}) => Bill(
  id: id,
  invoiceNumber: 'INV-1',
  title: title,
  totalAmount: 500000,
  paidAmount: 500000 - outstanding,
  outstandingAmount: outstanding,
  status: 'partial',
  dueAt: DateTime(2026, 10, 10),
  isOverdue: overdue,
  pendingPayments: pending,
);

BillDetail _detail({
  int outstanding = 400000,
  List<BillPayment> payments = const [],
  DateTime? issuedAt,
}) => BillDetail(
  id: 'b-1',
  invoiceNumber: 'INV-1',
  title: 'SPP Oktober 2026',
  totalAmount: 500000,
  paidAmount: 500000 - outstanding,
  outstandingAmount: outstanding,
  status: 'partial',
  issuedAt: issuedAt,
  lines: const [
    BillLine(description: 'SPP Pokok', amount: 450000),
    BillLine(description: 'Kegiatan', amount: 50000),
  ],
  payments: payments,
);

void main() {
  late _MockRepo repo;
  late _MockPicker picker;

  setUpAll(() {
    initializeDateFormatting('id_ID');
    registerFallbackValue(
      ProofSubmission(
        amount: 1,
        transferredAt: DateTime(2026),
        senderName: '',
        proofPath: '',
      ),
    );
    registerFallbackValue(ImageSource.gallery);
  });

  setUp(() {
    repo = _MockRepo();
    picker = _MockPicker();
  });

  Future<void> pump(
    WidgetTester t,
    Widget page, {
    List<PaymentAccount> accounts = _accounts,
  }) async {
    t.view.physicalSize = const Size(800, 3200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          financeRepositoryProvider.overrideWithValue(repo),
          imagePickerProvider.overrideWithValue(picker),
          childrenProvider.overrideWith(
            (_) async => [const Child(id: 7, nama: 'Ahmad')],
          ),
          bootstrapProvider.overrideWith(
            (_) async => AppBootstrap(
              tenantName: 'X',
              activeModules: const {'keuangan'},
              contacts: const [],
              paymentAccounts: accounts,
            ),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          supportedLocales: const [Locale('id', 'ID'), Locale('en')],
          home: page,
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  void stubBills(List<Bill> items, {Map<String, dynamic>? meta}) {
    when(
      () => repo.bills(
        any(),
        status: any(named: 'status'),
        page: any(named: 'page'),
      ),
    ).thenAnswer((_) async => _page(items, meta: meta ?? const {}));
  }

  group('Tagihan list', () {
    testWidgets('data: kartu total, badge terlambat & menunggu', (t) async {
      stubBills(
        [
          _bill(overdue: true, pending: 1),
          _bill(id: 'b-2', title: 'Seragam', outstanding: 100000),
        ],
        meta: {'total_outstanding': 500000},
      );
      await pump(t, const KeuanganPage());
      expect(find.text('Total sisa tagihan'), findsOneWidget);
      expect(find.textContaining('500.000'), findsOneWidget);
      expect(find.text('SPP Oktober 2026'), findsOneWidget);
      expect(find.textContaining('Sisa Rp'), findsNWidgets(2));
      expect(find.textContaining('Jatuh tempo 10 Okt 2026'), findsWidgets);
      expect(find.text('Terlambat'), findsOneWidget);
      expect(find.text('Menunggu verifikasi'), findsOneWidget);
    });

    testWidgets('toggle Lunas memanggil status=paid', (t) async {
      stubBills([_bill()]);
      await pump(t, const KeuanganPage());
      await t.tap(find.text('Lunas'));
      await t.pumpAndSettle();
      verify(
        () => repo.bills(
          7,
          status: 'paid',
          page: any(named: 'page'),
        ),
      ).called(1);
    });

    testWidgets('kosong', (t) async {
      stubBills([]);
      await pump(t, const KeuanganPage());
      expect(find.text('Tidak ada tagihan yang belum lunas.'), findsOneWidget);
    });

    testWidgets('error 403 modul', (t) async {
      when(
        () => repo.bills(
          any(),
          status: any(named: 'status'),
          page: any(named: 'page'),
        ),
      ).thenThrow(
        const ApiException(message: 'x', code: 'MODULE_NOT_ENTITLED'),
      );
      await pump(t, const KeuanganPage());
      expect(find.textContaining('belum aktif'), findsOneWidget);
    });

    testWidgets('error 503 → pesan gangguan + coba lagi', (t) async {
      when(
        () => repo.bills(
          any(),
          status: any(named: 'status'),
          page: any(named: 'page'),
        ),
      ).thenThrow(const ApiException(message: 'down', statusCode: 503));
      await pump(t, const KeuanganPage());
      expect(
        find.text('Layanan keuangan sedang gangguan, coba lagi'),
        findsOneWidget,
      );
      expect(find.text('Coba lagi'), findsOneWidget);
    });
  });

  group('Detail tagihan', () {
    testWidgets('pending & ditolak + alasan, tombol kirim bukti', (t) async {
      when(() => repo.bill('b-1')).thenAnswer(
        (_) async => _detail(
          payments: [
            const BillPayment(
              id: 'p1',
              paymentNumber: 'PAY-1',
              amount: 100000,
              status: 'pending',
            ),
            const BillPayment(
              id: 'p2',
              paymentNumber: 'PAY-2',
              amount: 50000,
              status: 'rejected',
              rejectionReason: 'Foto buram',
            ),
            const BillPayment(
              id: 'p3',
              paymentNumber: 'PAY-3',
              amount: 25000,
              status: 'confirmed',
            ),
          ],
        ),
      );
      await pump(t, const BillDetailPage(id: 'b-1'));
      expect(find.text('SPP Pokok'), findsOneWidget);
      expect(find.text('Menunggu verifikasi'), findsOneWidget);
      expect(find.text('Ditolak'), findsOneWidget);
      expect(find.text('Diterima'), findsOneWidget);
      expect(find.text('Alasan: Foto buram'), findsOneWidget);
      expect(find.text('Kirim Bukti Transfer'), findsOneWidget);
    });

    testWidgets('lunas: tombol kirim bukti tidak ada', (t) async {
      when(() => repo.bill('b-1'))
          .thenAnswer((_) async => _detail(outstanding: 0));
      await pump(t, const BillDetailPage(id: 'b-1'));
      expect(find.text('Kirim Bukti Transfer'), findsNothing);
      expect(find.text('Belum ada pembayaran.'), findsOneWidget);
    });

    testWidgets('503', (t) async {
      when(() => repo.bill('b-1'))
          .thenThrow(const ApiException(message: 'x', statusCode: 503));
      await pump(t, const BillDetailPage(id: 'b-1'));
      expect(find.textContaining('gangguan'), findsOneWidget);
    });
  });

  group('Form bukti', () {
    BillPayment ok() => const BillPayment(
      id: 'p1',
      paymentNumber: 'PAY-1',
      amount: 400000,
      status: 'pending',
    );

    void stubDetail({DateTime? issuedAt}) =>
        when(() => repo.bill('b-1'))
            .thenAnswer((_) async => _detail(issuedAt: issuedAt));

    Future<void> fillValid(WidgetTester t) async {
      await t.enterText(
        find.widgetWithText(TextFormField, 'Nama pengirim'),
        'Budi',
      );
      when(
        () => picker.pickImage(
          source: any(named: 'source'),
          maxWidth: any(named: 'maxWidth'),
          imageQuality: any(named: 'imageQuality'),
        ),
      ).thenAnswer((_) async => XFile('/tmp/bukti.jpg'));
      await t.tap(find.text('Galeri'));
      await t.pumpAndSettle();
    }

    Future<void> tapSubmit(WidgetTester t) async {
      await t.tap(find.text('Kirim Bukti'));
      await t.pumpAndSettle();
    }

    testWidgets('rekening tujuan + salin → snackbar; nominal default sisa', (
      t,
    ) async {
      stubDetail();
      await pump(t, const BuktiTransferPage(billId: 'b-1'));
      expect(find.text('7001234567'), findsOneWidget);
      expect(find.text('400.000'), findsOneWidget);
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async => null,
      );
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await t.tap(find.byTooltip('Salin nomor rekening'));
      await t.pump();
      await t.pump();
      expect(find.text('Nomor rekening disalin'), findsOneWidget);
    });

    testWidgets('nominal > sisa ditolak', (t) async {
      stubDetail();
      await pump(t, const BuktiTransferPage(billId: 'b-1'));
      await t.enterText(
        find.widgetWithText(TextFormField, 'Nominal transfer'),
        '400001',
      );
      await fillValid(t);
      await tapSubmit(t);
      expect(find.textContaining('melebihi sisa tagihan'), findsOneWidget);
      verifyNever(
        () => repo.submitProof(
          any(),
          any(),
          idempotencyKey: any(named: 'idempotencyKey'),
          onSendProgress: any(named: 'onSendProgress'),
        ),
      );
    });

    testWidgets('input diformat Rupiah titik ribuan', (t) async {
      stubDetail();
      await pump(t, const BuktiTransferPage(billId: 'b-1'));
      await t.enterText(
        find.widgetWithText(TextFormField, 'Nominal transfer'),
        '150000',
      );
      expect(find.text('150.000'), findsOneWidget);
    });

    testWidgets('nama pengirim & foto wajib', (t) async {
      stubDetail();
      await pump(t, const BuktiTransferPage(billId: 'b-1'));
      await tapSubmit(t);
      expect(find.text('Isi nama pengirim'), findsOneWidget);
      expect(find.text('Pilih foto bukti transfer.'), findsOneWidget);
    });

    testWidgets('tanggal masa depan tidak bisa dipilih (lastDate = hari ini)', (
      t,
    ) async {
      stubDetail();
      await pump(t, const BuktiTransferPage(billId: 'b-1'));
      await t.tap(find.byIcon(Icons.calendar_today));
      await t.pumpAndSettle();
      final cal = t.widget<CalendarDatePicker>(find.byType(CalendarDatePicker));
      final n = DateTime.now();
      expect(cal.lastDate, DateTime(n.year, n.month, n.day));
    });

    testWidgets('submit sukses → layar sukses + argumen benar', (t) async {
      stubDetail();
      when(
        () => repo.submitProof(
          any(),
          any(),
          idempotencyKey: any(named: 'idempotencyKey'),
          onSendProgress: any(named: 'onSendProgress'),
        ),
      ).thenAnswer((_) async => ok());
      await pump(t, const BuktiTransferPage(billId: 'b-1'));
      await fillValid(t);
      await tapSubmit(t);
      expect(
        find.text('Bukti terkirim, menunggu verifikasi bendahara'),
        findsOneWidget,
      );
      final s =
          verify(
                () => repo.submitProof(
                  'b-1',
                  captureAny(),
                  idempotencyKey: any(named: 'idempotencyKey'),
                  onSendProgress: any(named: 'onSendProgress'),
                ),
              ).captured.single
              as ProofSubmission;
      expect(s.amount, 400000);
      expect(s.senderName, 'Budi');
      expect(s.destinationAccountId, 'a1');
      expect(s.proofPath, '/tmp/bukti.jpg');
      verify(
        () => picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1600,
          imageQuality: 80,
        ),
      ).called(1);
    });

    testWidgets('503 lalu retry memakai Idempotency-Key sama', (t) async {
      stubDetail();
      final keys = <String>[];
      var n = 0;
      when(
        () => repo.submitProof(
          any(),
          any(),
          idempotencyKey: any(named: 'idempotencyKey'),
          onSendProgress: any(named: 'onSendProgress'),
        ),
      ).thenAnswer((i) async {
        keys.add(i.namedArguments[#idempotencyKey] as String);
        if (n++ == 0) {
          throw const ApiException(message: 'down', statusCode: 503);
        }
        return ok();
      });
      await pump(t, const BuktiTransferPage(billId: 'b-1'));
      await fillValid(t);
      await tapSubmit(t);
      expect(
        find.text('Layanan keuangan sedang gangguan, coba lagi'),
        findsOneWidget,
      );
      await tapSubmit(t);
      expect(keys, hasLength(2));
      expect(keys[0], keys[1]);
      expect(find.textContaining('Bukti terkirim'), findsOneWidget);
    });

    testWidgets('422 → error per field', (t) async {
      stubDetail();
      when(
        () => repo.submitProof(
          any(),
          any(),
          idempotencyKey: any(named: 'idempotencyKey'),
          onSendProgress: any(named: 'onSendProgress'),
        ),
      ).thenThrow(
        const ApiException(
          message: 'Validasi gagal',
          statusCode: 422,
          fieldErrors: {
            'amount': ['Melebihi sisa tagihan.'],
            'sender_name': ['Nama tidak valid.'],
            'proof': ['File harus gambar atau PDF.'],
          },
        ),
      );
      await pump(t, const BuktiTransferPage(billId: 'b-1'));
      await fillValid(t);
      await tapSubmit(t);
      expect(find.text('Melebihi sisa tagihan.'), findsOneWidget);
      expect(find.text('Nama tidak valid.'), findsOneWidget);
      expect(find.text('File harus gambar atau PDF.'), findsOneWidget);
    });

    testWidgets('>1 rekening: dropdown wajib dipilih', (t) async {
      stubDetail();
      await pump(
        t,
        const BuktiTransferPage(billId: 'b-1'),
        accounts: const [
          ..._accounts,
          PaymentAccount(
            id: 'a2',
            bank: 'BCA',
            accountNumber: '222',
            accountName: 'Pesantren X',
          ),
        ],
      );
      await fillValid(t);
      await tapSubmit(t);
      expect(find.text('Pilih rekening tujuan'), findsOneWidget);
    });
  });

  group('Uang Saku', () {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 9, 30);

    WalletTransaction tx(int id, String jenis, int nominal, DateTime w) =>
        WalletTransaction(
          id: id,
          jenis: jenis,
          nominal: nominal,
          waktu: w,
          keterangan: 'Mutasi $id',
        );

    void stubWallet(List<WalletTransaction> items) {
      when(() => repo.wallet(7)).thenAnswer(
        (_) async => const WalletSummary(
          santriId: 7,
          saldo: 250000,
          masukHariIni: 10000,
          keluarHariIni: 5000,
        ),
      );
      when(
        () => repo.walletTransactions(
          7,
          month: any(named: 'month'),
          page: any(named: 'page'),
        ),
      ).thenAnswer(
        (_) async => _page(
          items,
          meta: {'month': '', 'total_masuk': 90000, 'total_keluar': 30000},
        ),
      );
    }

    testWidgets('saldo, hari ini, ringkasan bulan, kelompok per hari', (
      t,
    ) async {
      final yesterday = today.subtract(const Duration(days: 1));
      stubWallet([
        tx(1, 'keluar', 5000, today),
        tx(2, 'keluar', 7000, today.subtract(const Duration(hours: 1))),
        tx(3, 'masuk', 20000, today.subtract(const Duration(hours: 2))),
        tx(4, 'keluar', 3000, yesterday),
      ]);
      await pump(t, const KeuanganPage(initialTab: 1));
      expect(find.textContaining('250.000'), findsOneWidget);
      expect(find.textContaining('Masuk Rp'), findsOneWidget);
      expect(find.textContaining('90.000'), findsOneWidget);
      expect(find.textContaining('30.000'), findsOneWidget);
      final h1 = DateFormat('EEEE, d MMMM y', 'id_ID').format(today);
      final h2 = DateFormat('EEEE, d MMMM y', 'id_ID').format(yesterday);
      // Hanya diuji bila kemarin masih di bulan yang sama tidak diperlukan:
      // grouping tidak bergantung pada bulan.
      expect(find.text(h1), findsOneWidget);
      expect(find.text(h2), findsOneWidget);
      expect(find.text('Keluar Rp 12.000'), findsOneWidget);
      expect(find.text('+Rp 20.000'), findsOneWidget);
      expect(find.text('-Rp 5.000'), findsOneWidget);
    });

    testWidgets('ganti bulan memuat ulang; tidak lewat bulan berjalan', (
      t,
    ) async {
      stubWallet([]);
      await pump(t, const KeuanganPage(initialTab: 1));
      IconButton btn(String tip) => t.widget<IconButton>(
        find.widgetWithIcon(
          IconButton,
          tip == 'n' ? Icons.chevron_right : Icons.chevron_left,
        ),
      );
      expect(btn('n').onPressed, isNull);
      await t.tap(find.byTooltip('Bulan sebelumnya'));
      await t.pumpAndSettle();
      final prev = DateTime(now.year, now.month - 1);
      verify(
        () => repo.walletTransactions(
          7,
          month: DateFormat('yyyy-MM').format(prev),
          page: any(named: 'page'),
        ),
      ).called(1);
      expect(btn('n').onPressed, isNotNull);
      await t.tap(find.byTooltip('Bulan berikutnya'));
      await t.pumpAndSettle();
      expect(btn('n').onPressed, isNull);
      expect(find.text('Belum ada mutasi bulan ini.'), findsOneWidget);
    });

    testWidgets('error 403', (t) async {
      when(() => repo.wallet(7)).thenThrow(
        const ApiException(message: 'x', code: 'MODULE_NOT_ENTITLED'),
      );
      await pump(t, const KeuanganPage(initialTab: 1));
      expect(find.textContaining('belum aktif'), findsOneWidget);
    });
  });

  group('Riwayat', () {
    testWidgets('daftar pembayaran + chip status', (t) async {
      stubBills([]);
      when(() => repo.payments(7, page: any(named: 'page'))).thenAnswer(
        (_) async => _page([
          const BillPayment(
            id: 'p1',
            paymentNumber: 'PAY-1',
            amount: 100000,
            status: 'confirmed',
            billId: 'b-1',
          ),
          const BillPayment(
            id: 'p2',
            paymentNumber: 'PAY-2',
            amount: 50000,
            status: 'rejected',
            rejectionReason: 'Buram',
          ),
        ]),
      );
      await pump(t, const KeuanganPage(initialTab: 2));
      expect(find.text('Diterima'), findsOneWidget);
      expect(find.text('Ditolak'), findsOneWidget);
      expect(find.text('Alasan: Buram'), findsOneWidget);
    });

    testWidgets('kosong', (t) async {
      stubBills([]);
      when(() => repo.payments(7, page: any(named: 'page')))
          .thenAnswer((_) async => _page(<BillPayment>[]));
      await pump(t, const KeuanganPage(initialTab: 2));
      expect(find.text('Belum ada riwayat pembayaran.'), findsOneWidget);
    });
  });
}
