import 'dart:math';

/// Luật "Lật Thẻ Trí Nhớ": lật 2 thẻ, tìm cặp hình ↔ chữ (tiếng Việt / tiếng Anh) hoặc phép tính ↔ kết quả.

class Vocab {
  final String emoji;
  final String vi;
  final String en;
  const Vocab(this.emoji, this.vi, this.en);
}

const vocab = [
  Vocab('🐱', 'con mèo', 'cat'),
  Vocab('🐶', 'con chó', 'dog'),
  Vocab('🐟', 'con cá', 'fish'),
  Vocab('🐔', 'con gà', 'chicken'),
  Vocab('🐮', 'con bò', 'cow'),
  Vocab('🐰', 'con thỏ', 'rabbit'),
  Vocab('🐘', 'con voi', 'elephant'),
  Vocab('🦆', 'con vịt', 'duck'),
  Vocab('🐝', 'con ong', 'bee'),
  Vocab('🦋', 'con bướm', 'butterfly'),
  Vocab('🐢', 'con rùa', 'turtle'),
  Vocab('🍎', 'quả táo', 'apple'),
  Vocab('🍌', 'quả chuối', 'banana'),
  Vocab('🍊', 'quả cam', 'orange'),
  Vocab('🍉', 'dưa hấu', 'watermelon'),
  Vocab('☀️', 'mặt trời', 'sun'),
  Vocab('🌙', 'mặt trăng', 'moon'),
  Vocab('⭐', 'ngôi sao', 'star'),
  Vocab('🌸', 'bông hoa', 'flower'),
  Vocab('🌳', 'cái cây', 'tree'),
  Vocab('🏠', 'ngôi nhà', 'house'),
  Vocab('🚗', 'ô tô', 'car'),
  Vocab('🚲', 'xe đạp', 'bicycle'),
  Vocab('✈️', 'máy bay', 'plane'),
  Vocab('📚', 'quyển sách', 'book'),
  Vocab('✏️', 'bút chì', 'pencil'),
  Vocab('⚽', 'quả bóng', 'ball'),
  Vocab('🌈', 'cầu vồng', 'rainbow'),
  Vocab('🍦', 'cây kem', 'ice cream'),
  Vocab('🎈', 'bóng bay', 'balloon'),
];

class MemCard {
  final int pair;
  final String face; // emoji, chữ hoặc phép tính
  final bool picture; // mặt là hình (emoji)
  final String speak; // Cú đọc khi lật ('' = im lặng)
  bool open = false;
  bool matched = false;
  MemCard(this.pair, this.face, {this.picture = false, this.speak = ''});
}

/// Số cặp & số cột theo cấp: 3 → 4 → 6 → 8 → 10 cặp.
int pairsForLevel(int level) => const [3, 4, 6, 8, 10][min(max(level, 1), 5) - 1];
int columnsFor(int pairs) => pairs <= 3 ? 3 : (pairs <= 8 ? 4 : 5);

/// Chủ đề theo lớp & cấp: lớp 1–2 xen kẽ chữ Việt / phép tính; lớp 3+ thêm tiếng Anh.
String themeFor(int grade, int level) {
  final cycle = grade >= 3 ? const ['vi', 'en', 'math'] : const ['vi', 'math'];
  return cycle[(level - 1) % cycle.length];
}

String themeTitle(String theme) => switch (theme) {
      'en' => 'Hình ↔ Tiếng Anh',
      'math' => 'Phép tính ↔ Kết quả',
      _ => 'Hình ↔ Chữ',
    };

List<MemCard> makeBoard({required int grade, required int level, required Random rnd}) {
  final n = pairsForLevel(level);
  final theme = themeFor(grade, level);
  final cards = <MemCard>[];
  if (theme == 'math') {
    final used = <int>{};
    var guard = 0;
    while (used.length < n && guard++ < 500) {
      final (expr, v) = _mathPair(grade, level, rnd);
      if (used.contains(v)) continue;
      used.add(v);
      final id = used.length - 1;
      cards
        ..add(MemCard(id, expr))
        ..add(MemCard(id, '$v'));
    }
  } else {
    final words = [...vocab]..shuffle(rnd);
    for (var i = 0; i < n; i++) {
      final w = words[i];
      cards
        ..add(MemCard(i, w.emoji, picture: true, speak: w.vi))
        ..add(MemCard(i, theme == 'en' ? w.en : w.vi, speak: theme == 'en' ? '' : w.vi));
    }
  }
  cards.shuffle(rnd);
  return cards;
}

(String, int) _mathPair(int grade, int level, Random rnd) {
  if (grade >= 3 && rnd.nextBool()) {
    final a = 2 + rnd.nextInt(8), b = 2 + rnd.nextInt(8);
    return ('$a × $b', a * b);
  }
  final limit = grade <= 1 ? (level <= 2 ? 10 : 20) : 100;
  if (rnd.nextBool()) {
    final a = 1 + rnd.nextInt(limit - 1);
    final b = 1 + rnd.nextInt(max(1, limit - a));
    return ('$a + $b', a + b);
  }
  final a = 2 + rnd.nextInt(limit - 1);
  final b = 1 + rnd.nextInt(a - 1);
  return ('$a − $b', a - b);
}

/// Số sao khi xong bàn: lật ít lượt → nhiều sao.
int starsFor(int pairs, int moves) {
  if (moves <= pairs + 2) return 3;
  if (moves <= pairs * 2) return 2;
  return 1;
}
