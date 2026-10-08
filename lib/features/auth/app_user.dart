class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.pesantrenId,
    this.roles = const [],
    this.permissions = const [],
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: (json['id'] as num).toInt(),
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    pesantrenId: (json['pesantren_id'] as num?)?.toInt(),
    roles:
        _strings(json['roles']) ??
        [if (json['role'] is String) json['role'] as String],
    permissions: _strings(json['permissions']) ?? const [],
  );

  final int id;
  final String name;
  final String email;
  final int? pesantrenId;
  final List<String> roles;
  final List<String> permissions;

  bool hasRole(String role) => roles.contains(role);
  bool get isWali => hasRole('wali');

  /// Staf yang mendapat "Mode Pengurus" di app.
  bool get isStaff => roles.any(
    const {
      'ustadz',
      'keamanan',
      'pengasuh',
      'bendahara',
      'kesehatan',
      'admin',
      'tenant_owner',
    }.contains,
  );

  static List<String>? _strings(dynamic v) =>
      v is List ? v.map((e) => '$e').toList() : null;
}
