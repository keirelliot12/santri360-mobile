import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:santri360/core/network/api_exception.dart';
import 'package:santri360/features/app_config/bootstrap.dart';
import 'package:santri360/features/finance/finance_models.dart';
import 'package:santri360/features/finance/finance_repository.dart';

class _MockDio extends Mock implements Dio {}

Response<Map<String, dynamic>> _res(Map<String, dynamic> data, [int? code]) =>
    Response(requestOptions: RequestOptions(), data: data, statusCode: code);

const _paymentJson = {
  'id': 'p-1',
  'payment_number': 'PAY-1',
  'bill_id': 'b-1',
  'invoice_number': 'INV-1',
  'amount': 50000,
  'method': 'manual_transfer',
  'status': 'pending',
  'rejection_reason': null,
  'submitted_at': '2026-10-08T03:00:00Z',
  'paid_at': null,
  'has_proof': true,
};

void main() {
  setUpAll(() {
    registerFallbackValue(Options());
    registerFallbackValue(FormData());
  });

  group('model', () {
    test('Bill.fromJson lengkap + field null + angka string', () {
      final b = Bill.fromJson({
        'id': 'uuid-1',
        'invoice_number': 'INV-9',
        'type': 'spp',
        'title': 'SPP Oktober 2026',
        'period_key': null,
        'issued_at': '2026-10-01',
        'due_at': null,
        'total_amount': '500000',
        'paid_amount': 100000,
        'outstanding_amount': 400000,
        'status': 'partial',
        'is_overdue': true,
        'pending_payments': 2,
      });
      expect(b.id, 'uuid-1');
      expect(b.dueAt, isNull);
      expect(b.periodKey, isNull);
      expect(b.issuedAt, DateTime(2026, 10, 1));
      expect(b.totalAmount, 500000);
      expect(b.outstandingAmount, 400000);
      expect(b.isOverdue, isTrue);
      expect(b.pendingPayments, 2);
    });

    test('Bill.fromJson minimal tidak crash', () {
      final b = Bill.fromJson({'id': 'x'});
      expect(b.title, '');
      expect(b.outstandingAmount, 0);
      expect(b.isOverdue, isFalse);
    });

    test('BillDetail memuat lines + payments (rejection_reason null/isi)', () {
      final d = BillDetail.fromJson({
        'id': 'b-1',
        'title': 'SPP',
        'outstanding_amount': 1000,
        'santri_id': 7,
        'lines': [
          {'description': 'SPP', 'amount': 1000},
        ],
        'payments': [
          _paymentJson,
          {..._paymentJson, 'status': 'rejected', 'rejection_reason': 'Buram'},
        ],
      });
      expect(d.santriId, 7);
      expect(d.lines.single.description, 'SPP');
      expect(d.payments, hasLength(2));
      expect(d.payments.first.rejectionReason, isNull);
      expect(d.payments.last.rejectionReason, 'Buram');
      expect(d.payments.first.hasProof, isTrue);
    });

    test('BillDetail tanpa lines/payments/santri_id', () {
      final d = BillDetail.fromJson({'id': 'b'});
      expect(d.lines, isEmpty);
      expect(d.payments, isEmpty);
      expect(d.santriId, isNull);
    });

    test('BillPayment null: bill_id, invoice, paid_at', () {
      final p = BillPayment.fromJson({
        ..._paymentJson,
        'bill_id': null,
        'invoice_number': null,
      });
      expect(p.billId, isNull);
      expect(p.invoiceNumber, isNull);
      expect(p.paidAt, isNull);
      expect(p.submittedAt, isNotNull);
    });

    test('WalletSummary + hari_ini + null', () {
      final w = WalletSummary.fromJson({
        'santri_id': 7,
        'nomor_va': null,
        'saldo': 250000,
        'status': 'aktif',
        'hari_ini': {'masuk': 1000, 'keluar': 2000},
        'updated_at': null,
      });
      expect(w.nomorVa, isNull);
      expect(w.saldo, 250000);
      expect(w.masukHariIni, 1000);
      expect(w.keluarHariIni, 2000);
      expect(w.updatedAt, isNull);
      expect(WalletSummary.fromJson({'santri_id': 1}).keluarHariIni, 0);
    });

    test('WalletTransaction masuk/keluar + null keterangan', () {
      final t = WalletTransaction.fromJson({
        'id': 1,
        'jenis': 'keluar',
        'nominal': 5000,
        'keterangan': null,
        'referensi': null,
        'waktu': '2026-10-08T03:00:00Z',
      });
      expect(t.keluar, isTrue);
      expect(t.keterangan, isNull);
      expect(
        WalletTransaction.fromJson({'id': 2, 'jenis': 'masuk'}).keluar,
        isFalse,
      );
    });

    test('Bootstrap.payment_accounts (ada & tidak ada)', () {
      final b = AppBootstrap.fromJson({
        'payment_accounts': [
          {
            'id': 'a1',
            'bank': 'BSI',
            'account_number': '7001',
            'account_name': 'Pesantren X',
            'note': null,
          },
        ],
      });
      expect(b.paymentAccounts.single.accountNumber, '7001');
      expect(b.paymentAccounts.single.note, isNull);
      expect(AppBootstrap.fromJson({}).paymentAccounts, isEmpty);
    });

    test('formatRupiah', () {
      expect(formatRupiah(1500000).replaceAll(' ', ' '), 'Rp 1.500.000');
    });
  });

  group('repository', () {
    late _MockDio dio;
    late FinanceRepository repo;
    setUp(() {
      dio = _MockDio();
      repo = FinanceRepository(dio);
    });

    test('bills: path/query + meta.total_outstanding', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          '/children/7/bills',
          queryParameters: {'status': 'unpaid', 'page': 1, 'per_page': 15},
        ),
      ).thenAnswer(
        (_) async => _res({
          'data': [
            {'id': 'b-1', 'title': 'SPP', 'outstanding_amount': 100},
          ],
          'meta': {
            'current_page': 1,
            'last_page': 2,
            'total': 20,
            'total_outstanding': 750000,
          },
        }),
      );
      final p = await repo.bills(7);
      expect(p.items.single.id, 'b-1');
      expect(p.hasMore, isTrue);
      expect(p.meta['total_outstanding'], 750000);
    });

    test('bill detail: GET /bills/{uuid}', () async {
      when(() => dio.get<Map<String, dynamic>>('/bills/b-1')).thenAnswer(
        (_) async => _res({
          'data': {'id': 'b-1', 'title': 'SPP'},
        }),
      );
      expect((await repo.bill('b-1')).title, 'SPP');
    });

    test('payments: path/query', () async {
      when(
        () => dio.get<Map<String, dynamic>>(
          '/children/7/payments',
          queryParameters: {'page': 2, 'per_page': 15},
        ),
      ).thenAnswer(
        (_) async => _res({
          'data': [_paymentJson],
          'meta': {'current_page': 2, 'last_page': 2, 'total': 16},
        }),
      );
      final p = await repo.payments(7, page: 2);
      expect(p.items.single.paymentNumber, 'PAY-1');
      expect(p.hasMore, isFalse);
    });

    test('wallet + transactions: path/query month', () async {
      when(() => dio.get<Map<String, dynamic>>('/children/7/wallet'))
          .thenAnswer(
            (_) async => _res({
              'data': {'santri_id': 7, 'saldo': 1000},
            }),
          );
      expect((await repo.wallet(7)).saldo, 1000);

      when(
        () => dio.get<Map<String, dynamic>>(
          '/children/7/wallet/transactions',
          queryParameters: {'month': '2026-09', 'page': 1, 'per_page': 20},
        ),
      ).thenAnswer(
        (_) async => _res({
          'data': [
            {'id': 1, 'jenis': 'masuk', 'nominal': 1000},
          ],
          'meta': {
            'current_page': 1,
            'last_page': 1,
            'total': 1,
            'month': '2026-09',
            'total_masuk': 1000,
            'total_keluar': 0,
          },
        }),
      );
      final p = await repo.walletTransactions(7, month: '2026-09');
      expect(p.items.single.nominal, 1000);
      expect(p.meta['total_masuk'], 1000);
    });

    test('error 503 → ApiException', () async {
      final req = RequestOptions();
      when(() => dio.get<Map<String, dynamic>>(any())).thenThrow(
        DioException(
          requestOptions: req,
          response: Response(
            requestOptions: req,
            statusCode: 503,
            data: {'message': 'down'},
          ),
        ),
      );
      expect(
        repo.bill('x'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'code', 503)),
      );
    });

    group('submitProof', () {
      late File file;
      setUp(() {
        file = File('${Directory.systemTemp.path}/f2a_proof_test.jpg')
          ..writeAsBytesSync([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3]);
      });
      tearDown(() {
        if (file.existsSync()) file.deleteSync();
      });

      ProofSubmission sub({String? bank, String? note}) => ProofSubmission(
        amount: 50000,
        transferredAt: DateTime(2026, 10, 8),
        senderName: 'Budi',
        senderBank: bank,
        destinationAccountId: 'a1',
        note: note,
        proofPath: file.path,
      );

      void stubPost(List<Object?> data, List<Options> opts, {Object? err}) {
        when(
          () => dio.post<Map<String, dynamic>>(
            '/bills/b-1/payment-proofs',
            data: any(named: 'data'),
            options: any(named: 'options'),
            onSendProgress: any(named: 'onSendProgress'),
          ),
        ).thenAnswer((i) async {
          data.add(i.namedArguments[#data]);
          opts.add(i.namedArguments[#options] as Options);
          if (err != null && data.length == 1) throw err;
          return _res({'data': _paymentJson}, 201);
        });
      }

      test('multipart field + header Idempotency-Key', () async {
        final data = <Object?>[];
        final opts = <Options>[];
        stubPost(data, opts);
        final p = await repo.submitProof(
          'b-1',
          sub(bank: 'BCA', note: ''),
          idempotencyKey: 'key-1',
        );
        expect(p.status, 'pending');
        final form = data.single! as FormData;
        final fields = Map.fromEntries(form.fields);
        expect(fields['amount'], '50000');
        expect(fields['transferred_at'], '2026-10-08');
        expect(fields['sender_name'], 'Budi');
        expect(fields['sender_bank'], 'BCA');
        expect(fields['destination_account_id'], 'a1');
        expect(
          fields.containsKey('note'),
          isFalse,
          reason: 'kosong tak dikirim',
        );
        expect(form.files.single.key, 'proof');
        expect(form.files.single.value.filename, 'f2a_proof_test.jpg');
        expect(opts.single.headers!['Idempotency-Key'], 'key-1');
      });

      test('retry memakai Idempotency-Key sama + FormData baru', () async {
        final data = <Object?>[];
        final opts = <Options>[];
        stubPost(
          data,
          opts,
          err: DioException(
            requestOptions: RequestOptions(),
            type: DioExceptionType.connectionTimeout,
          ),
        );
        await expectLater(
          repo.submitProof('b-1', sub(), idempotencyKey: 'key-retry'),
          throwsA(isA<ApiException>()),
        );
        await repo.submitProof('b-1', sub(), idempotencyKey: 'key-retry');
        expect(opts, hasLength(2));
        expect(opts[0].headers!['Idempotency-Key'], 'key-retry');
        expect(opts[1].headers!['Idempotency-Key'], 'key-retry');
        expect(identical(data[0], data[1]), isFalse);
      });
    });
  });
}
