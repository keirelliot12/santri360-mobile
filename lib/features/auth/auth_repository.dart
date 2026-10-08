import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import '../../core/network/api_response.dart';
import '../../core/providers.dart';
import '../../core/storage/token_storage.dart';
import 'app_user.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) =>
      AuthRepository(ref.watch(dioProvider), ref.watch(tokenStorageProvider)),
);

class AuthRepository {
  AuthRepository(this._dio, this._tokens);

  final Dio _dio;
  final TokenStorage _tokens;

  Future<bool> hasToken() async => (await _tokens.read()) != null;

  /// Login + pastikan akun milik pesantren app ini (white-label).
  Future<AppUser> login(String email, String password) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': email.trim().toLowerCase(), 'password': password},
      );
      final data = envelopeData(res.data);
      await _tokens.write(data['token'] as String);

      final user = await me();
      final tenantId = await resolveTenantId();
      if (tenantId != null && user.pesantrenId != tenantId) {
        await logout();
        throw const ApiException(
          message: 'Akun ini tidak terdaftar di pesantren ini.',
          statusCode: 403,
        );
      }
      return user;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<AppUser> me() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/me');
      return AppUser.fromJson(envelopeData(res.data));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// ID pesantren dari header `X-Pesantren-Code`. Null bila tidak dapat di-resolve.
  Future<int?> resolveTenantId() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/tenant-resolve');
      final tenant = envelopeData(res.data)['tenant'];
      return tenant is Map<String, dynamic>
          ? (tenant['id'] as num?)?.toInt()
          : null;
    } on DioException {
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post<void>('/auth/logout');
    } on DioException {
      // token mungkin sudah kedaluwarsa; tetap hapus lokal
    } finally {
      await _tokens.clear();
    }
  }

  Future<void> clearLocal() => _tokens.clear();
}
