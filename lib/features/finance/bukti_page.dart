import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../shared/async_views.dart';
import '../app_config/bootstrap.dart';
import 'finance_models.dart';
import 'finance_repository.dart';

final imagePickerProvider = Provider<ImagePicker>((_) => ImagePicker());

/// Memformat input angka jadi Rupiah bertitik ("1500000" -> "1.500.000").
class RupiahInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final text = NumberFormat.decimalPattern(
      'id_ID',
    ).format(int.parse(digits.length > 12 ? digits.substring(0, 12) : digits));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

int parseRupiah(String s) => int.tryParse(s.replaceAll(RegExp(r'\D'), '')) ?? 0;

class BuktiTransferPage extends ConsumerWidget {
  const BuktiTransferPage({super.key, required this.billId});

  final String billId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(billDetailProvider(billId));
    final accounts =
        ref.watch(bootstrapProvider).value?.paymentAccounts ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Kirim Bukti Transfer')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(billDetailProvider(billId)),
        ),
        data: (b) => b.outstandingAmount <= 0
            ? const EmptyView(
                message: 'Tagihan ini sudah lunas.',
                icon: Icons.check_circle,
              )
            : BuktiForm(bill: b, accounts: accounts),
      ),
    );
  }
}

class BuktiForm extends ConsumerStatefulWidget {
  const BuktiForm({super.key, required this.bill, required this.accounts});

  final BillDetail bill;
  final List<PaymentAccount> accounts;

  @override
  ConsumerState<BuktiForm> createState() => _BuktiFormState();
}

class _BuktiFormState extends ConsumerState<BuktiForm> {
  final _formKey = GlobalKey<FormState>();
  late final _amount = TextEditingController(
    text: NumberFormat.decimalPattern('id_ID')
        .format(widget.bill.outstandingAmount),
  );
  final _sender = TextEditingController();
  final _bank = TextEditingController();
  final _note = TextEditingController();
  late DateTime _date = _today;
  String? _accountId;
  String? _proofPath;

  /// Dibuat SEKALI saat form dibuka; dipakai ulang untuk setiap retry.
  String _idemKey = newIdempotencyKey();

  bool _submitting = false;
  bool _done = false;
  double? _progress;
  String? _banner;
  String? _proofLocalError;
  Map<String, List<String>> _server = {};

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    if (widget.accounts.length == 1) _accountId = widget.accounts.first.id;
  }

  @override
  void dispose() {
    _amount.dispose();
    _sender.dispose();
    _bank.dispose();
    _note.dispose();
    super.dispose();
  }

  String? _err(String key) => _server[key]?.firstOrNull;

  void _clear(String key) {
    if (_server.containsKey(key)) {
      setState(() => _server = {..._server}..remove(key));
    }
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final f = await ref
          .read(imagePickerProvider)
          .pickImage(source: source, maxWidth: 1600, imageQuality: 80);
      if (f == null) return;
      setState(() {
        _proofPath = f.path;
        _proofLocalError = null;
      });
      _clear('proof');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tidak bisa membuka kamera/galeri. Periksa izin aplikasi.',
          ),
        ),
      );
    }
  }

  Future<void> _pickDate() async {
    final issued = widget.bill.issuedAt;
    final first = issued != null && issued.isBefore(_today)
        ? DateTime(issued.year, issued.month, issued.day)
        : _today.subtract(const Duration(days: 365));
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: first,
      lastDate: _today,
      locale: const Locale('id', 'ID'),
    );
    if (d != null) {
      setState(() => _date = d);
      _clear('transferred_at');
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final valid = _formKey.currentState!.validate();
    if (_proofPath == null) {
      setState(() => _proofLocalError = 'Pilih foto bukti transfer.');
      return;
    }
    if (!valid) return;
    setState(() {
      _submitting = true;
      _progress = null;
      _banner = null;
      _server = {};
    });
    try {
      await ref
          .read(financeRepositoryProvider)
          .submitProof(
            widget.bill.id,
            ProofSubmission(
              amount: parseRupiah(_amount.text),
              transferredAt: _date,
              senderName: _sender.text.trim(),
              senderBank: _bank.text.trim(),
              destinationAccountId: _accountId,
              note: _note.text.trim(),
              proofPath: _proofPath!,
            ),
            idempotencyKey: _idemKey,
            onSendProgress: (sent, total) {
              if (mounted && total > 0) {
                setState(() => _progress = sent / total);
              }
            },
          );
      if (mounted) setState(() => _done = true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.statusCode == 422) {
          // Tidak ada pembayaran yang dibuat; isian akan diubah → permintaan baru.
          _idemKey = newIdempotencyKey();
          _server = e.fieldErrors;
          if (e.fieldErrors.isEmpty) _banner = e.message;
        } else if (e.statusCode == 503) {
          _banner = 'Layanan keuangan sedang gangguan, coba lagi';
        } else {
          _banner = friendlyError(e);
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() => _banner = 'Terjadi kesalahan. Silakan coba lagi.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return const _SuccessView();
    final bill = widget.bill;
    final accounts = widget.accounts;
    return AbsorbPointer(
      absorbing: _submitting,
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              bill.title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              'Sisa tagihan ${formatRupiah(bill.outstandingAmount)}',
              style: const TextStyle(fontSize: 17),
            ),
            if (_banner != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _banner!,
                  style: TextStyle(fontSize: 16, color: Colors.red.shade900),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (accounts.isNotEmpty) ...[
              const Text(
                'Transfer ke rekening berikut',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              for (final a in accounts) _AccountCard(account: a),
              const SizedBox(height: 8),
            ],
            if (accounts.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: DropdownButtonFormField<String>(
                  initialValue: _accountId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Rekening tujuan',
                    border: const OutlineInputBorder(),
                    errorText: _err('destination_account_id'),
                  ),
                  items: [
                    for (final a in accounts)
                      DropdownMenuItem(
                        value: a.id,
                        child: Text('${a.bank} · ${a.accountNumber}'),
                      ),
                  ],
                  validator: (v) => v == null ? 'Pilih rekening tujuan' : null,
                  onChanged: (v) {
                    setState(() => _accountId = v);
                    _clear('destination_account_id');
                  },
                ),
              ),
            TextFormField(
              controller: _amount,
              keyboardType: TextInputType.number,
              inputFormatters: [RupiahInputFormatter()],
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(
                labelText: 'Nominal transfer',
                prefixText: 'Rp ',
                border: const OutlineInputBorder(),
                errorText: _err('amount'),
              ),
              validator: (v) {
                final n = parseRupiah(v ?? '');
                if (n < 1) return 'Isi nominal transfer';
                if (n > bill.outstandingAmount) {
                  return 'Nominal melebihi sisa tagihan '
                      '(${formatRupiah(bill.outstandingAmount)})';
                }
                return null;
              },
              onChanged: (_) => _clear('amount'),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Tanggal transfer',
                  border: const OutlineInputBorder(),
                  suffixIcon: const Icon(Icons.calendar_today),
                  errorText: _err('transferred_at'),
                ),
                child: Text(
                  DateFormat('d MMMM y', 'id_ID').format(_date),
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _sender,
              maxLength: 100,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(
                labelText: 'Nama pengirim',
                border: const OutlineInputBorder(),
                errorText: _err('sender_name'),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Isi nama pengirim' : null,
              onChanged: (_) => _clear('sender_name'),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _bank,
              maxLength: 50,
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(
                labelText: 'Bank pengirim (opsional)',
                border: const OutlineInputBorder(),
                errorText: _err('sender_bank'),
              ),
              onChanged: (_) => _clear('sender_bank'),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _note,
              maxLength: 255,
              maxLines: 2,
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(
                labelText: 'Catatan (opsional)',
                border: const OutlineInputBorder(),
                errorText: _err('note'),
              ),
              onChanged: (_) => _clear('note'),
            ),
            const SizedBox(height: 8),
            const Text(
              'Foto bukti transfer',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (_proofPath != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(_proofPath!),
                  height: 220,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox(
                    height: 80,
                    child: Center(child: Text('Foto dipilih')),
                  ),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(ImageSource.camera),
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('Kamera'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Galeri'),
                  ),
                ),
              ],
            ),
            if ((_proofLocalError ?? _err('proof')) != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  (_proofLocalError ?? _err('proof'))!,
                  style: TextStyle(fontSize: 15, color: Colors.red.shade800),
                ),
              ),
            const SizedBox(height: 24),
            if (_submitting) ...[
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 8),
              Text(
                _progress == null
                    ? 'Mengunggah…'
                    : 'Mengunggah… ${(_progress! * 100).round()}%',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                textStyle: const TextStyle(fontSize: 18),
              ),
              onPressed: _submitting ? null : _submit,
              child: const Text('Kirim Bukti'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.account});

  final PaymentAccount account;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 8),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.bank,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  account.accountNumber,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'a.n. ${account.accountName}',
                  style: const TextStyle(fontSize: 16),
                ),
                if (account.note != null && account.note!.isNotEmpty)
                  Text(account.note!, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Salin nomor rekening',
            icon: const Icon(Icons.copy),
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: account.accountNumber),
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Nomor rekening disalin')),
              );
            },
          ),
        ],
      ),
    ),
  );
}

class _SuccessView extends StatelessWidget {
  const _SuccessView();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 80, color: Colors.green.shade700),
          const SizedBox(height: 16),
          const Text(
            'Bukti terkirim, menunggu verifikasi bendahara',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(220, 52),
              textStyle: const TextStyle(fontSize: 18),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Kembali ke tagihan'),
          ),
        ],
      ),
    ),
  );
}
