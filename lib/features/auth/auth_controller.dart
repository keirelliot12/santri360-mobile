import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_exception.dart';
import 'app_user.dart';
import 'auth_repository.dart';

/// Sesi aktif: `null` = belum login.
final authControllerProvider = AsyncNotifierProvider<AuthController, AppUser?>(
  AuthController.new,
);

class AuthController extends AsyncNotifier<AppUser?> {
  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  Future<AppUser?> build() async {
    if (!await _repo.hasToken()) return null;
    try {
      return await _repo.me();
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await _repo.clearLocal();
        return null;
      }
      rethrow;
    }
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.login(email, password));
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AsyncData(null);
  }

  /// Dipanggil interceptor saat 401.
  Future<void> forceLogout() async {
    if (state.value == null) return;
    await _repo.clearLocal();
    state = const AsyncData(null);
  }
}
