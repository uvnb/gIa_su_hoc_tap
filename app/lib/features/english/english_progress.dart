import 'dart:convert';

import '../../core/local_store.dart';

/// Tiến độ từng chủ đề tiếng Anh của bé: số thẻ đã học, điểm cao nhất (0..1) của từng trò.
class EnProgress {
  final int learned; // số thẻ đã xem trong "Học từ"
  final Map<String, double> best; // listen | spell | speak → tỉ lệ đúng cao nhất
  const EnProgress({this.learned = 0, this.best = const {}});

  /// Số ⭐ của chủ đề (tối đa 4): học hết thẻ + mỗi trò đạt ≥ 70%.
  int stars(int totalWords) => (learned >= totalWords ? 1 : 0) + best.values.where((v) => v >= 0.7).length;

  static String _key(String childId, String topic) => 'en|$childId|$topic';

  static EnProgress load(LocalStore store, String childId, String topic) {
    final raw = store.metaString(_key(childId, topic));
    if (raw == null) return const EnProgress();
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      return EnProgress(
        learned: (m['learned'] as num?)?.toInt() ?? 0,
        best: {for (final e in ((m['best'] as Map?) ?? {}).entries) '${e.key}': (e.value as num).toDouble()},
      );
    } catch (_) {
      return const EnProgress();
    }
  }

  static Future<void> save(LocalStore store, String childId, String topic, EnProgress p) =>
      store.setMeta(_key(childId, topic), jsonEncode({'learned': p.learned, 'best': p.best}));

  EnProgress withLearned(int n) => EnProgress(learned: n > learned ? n : learned, best: best);

  EnProgress withScore(String mode, double score) {
    final b = {...best};
    if (score > (b[mode] ?? 0)) b[mode] = score;
    return EnProgress(learned: learned, best: b);
  }
}
