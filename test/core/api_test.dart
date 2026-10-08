import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:santri360/core/network/api_client.dart';
import 'package:santri360/core/network/api_exception.dart';
import 'package:santri360/core/network/api_response.dart';
import 'package:santri360/features/auth/app_user.dart';
import 'package:santri360/features/children/child.dart';

DioException _err(int status, Object body) {
  final req = RequestOptions(path: '/x');
  return DioException(
    requestOptions: req,
    response: Response(requestOptions: req, statusCode: status, data: body),
  );
}

void main() {
  test('Paginated membaca envelope + meta', () {
    final p = Paginated.fromEnvelope({
      'success': true,
      'data': [
        {
          'id': 1,
          'nama_lengkap': 'Ahmad Fauzi',
          'kelas': {'nama': '7A'},
        },
      ],
      'meta': {'current_page': 1, 'last_page': 2, 'per_page': 15, 'total': 16},
    }, Child.fromJson);
    expect(p.items.single.kelas, '7A');
    expect(p.items.single.initials, 'AF');
    expect(p.hasMore, isTrue);
  });

  test('ApiException memetakan kode entitlement & error field', () {
    final e = ApiException.fromDio(
      _err(403, {
        'success': false,
        'message': 'Modul tidak aktif',
        'meta': {'code': 'MODULE_NOT_ENTITLED'},
      }),
    );
    expect(e.isNotEntitled, isTrue);

    final v = ApiException.fromDio(
      _err(422, {
        'message': 'invalid',
        'errors': {
          'email': ['wajib'],
        },
      }),
    );
    expect(v.fieldErrors['email'], ['wajib']);
  });

  test('ApiException tanpa response = pesan koneksi', () {
    final e = ApiException.fromDio(
      DioException(requestOptions: RequestOptions()),
    );
    expect(e.statusCode, isNull);
    expect(e.message, contains('koneksi'));
  });

  test('AppUser: role staf & wali', () {
    final u = AppUser.fromJson({
      'id': 1,
      'name': 'A',
      'email': 'a@x',
      'pesantren_id': 3,
      'roles': ['wali', 'ustadz'],
    });
    expect(u.isWali, isTrue);
    expect(u.isStaff, isTrue);
    final legacy = AppUser.fromJson({
      'id': 2,
      'role': 'wali',
      'pesantren_id': null,
    });
    expect(legacy.roles, ['wali']);
  });

  test('Idempotency key format UUID v4', () {
    expect(
      newIdempotencyKey(),
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
  });
}
