/// Envelope kanonik backend: `{success, message, data, meta}`.
class Paginated<T> {
  const Paginated({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    this.meta = const {},
  });

  factory Paginated.fromEnvelope(
    Map<String, dynamic> body,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final meta = (body['meta'] as Map<String, dynamic>?) ?? const {};
    final data = (body['data'] as List<dynamic>?) ?? const [];
    return Paginated(
      items: data.cast<Map<String, dynamic>>().map(fromJson).toList(),
      currentPage: (meta['current_page'] as num?)?.toInt() ?? 1,
      lastPage: (meta['last_page'] as num?)?.toInt() ?? 1,
      total: (meta['total'] as num?)?.toInt() ?? data.length,
      meta: meta,
    );
  }

  final List<T> items;
  final int currentPage;
  final int lastPage;
  final int total;

  /// `meta` mentah dari envelope (mis. `total_outstanding`).
  final Map<String, dynamic> meta;

  bool get hasMore => currentPage < lastPage;
}

/// Ambil `data` dari envelope sebagai Map.
Map<String, dynamic> envelopeData(dynamic body) {
  final data = (body as Map<String, dynamic>)['data'];
  return (data as Map<String, dynamic>?) ?? const {};
}
