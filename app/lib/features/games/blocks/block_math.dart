import 'dart:math';

import 'block_logic.dart';

/// Câu đố toán trên "khối bí ẩn" – độ khó theo lớp của bé và cấp trò chơi.
/// Bé chọn trong 3–4 đáp án; chọn sai thì thử lại (Cú không nói đáp án).
class MathQ {
  final String kind;
  final String text; // hiển thị
  final String spoken; // Cú đọc
  final List<String> options;
  final String answer;
  final bool showShape; // câu hỏi về chính hình khối → vẽ khối to trong hộp đố
  final String note; // ghi chú nhỏ (vd "Mỗi ô dài 1 cm")

  const MathQ({
    required this.kind,
    required this.text,
    required this.spoken,
    required this.options,
    required this.answer,
    this.showShape = false,
    this.note = '',
  });
}

/// Thứ tự độ khó: 0 đếm ô · 1 gọi tên hình · 2 cộng/trừ trong 10 · 3 trong 20 · 4 trong 100
/// · 5 bảng nhân/chia 2, 5 · 6 bảng nhân/chia 2–9 · 7 chu vi/diện tích · 8 số lớn.
int maxKindForGrade(int grade) => switch (grade) {
      <= 1 => 4,
      2 => 5,
      3 => 7,
      _ => 8,
    };

/// Khoảng độ khó cho (lớp, cấp): tăng dần theo cấp nhưng không vượt chương trình của lớp.
(int, int) kindRange(int grade, int level) {
  final hi = min(maxKindForGrade(grade), (level - 1) + grade);
  final lo = max(0, hi - 3);
  return (lo, hi);
}

MathQ makeQuestion({required int grade, required int level, required Shape shape, required Random rnd}) {
  final (lo, hi) = kindRange(grade, level);
  final kind = lo + rnd.nextInt(hi - lo + 1);
  final nOptions = grade <= 2 ? 3 : 4;
  return _build(kind, grade, shape, rnd, nOptions);
}

MathQ _build(int kind, int grade, Shape shape, Random rnd, int nOpt) {
  switch (kind) {
    case 0:
      return _numeric('count', 'Khối này có mấy ô vuông?', 'Khối này có mấy ô vuông?', shape.size, rnd, nOpt,
          showShape: true);
    case 1:
      if (shape.geometry.isEmpty) {
        return _numeric('count', 'Khối này có mấy ô vuông?', 'Khối này có mấy ô vuông?', shape.size, rnd, nOpt,
            showShape: true);
      }
      final ans = shape.geometry == 'square' ? 'Hình vuông' : 'Hình chữ nhật';
      final opts = ['Hình vuông', 'Hình chữ nhật', 'Hình tam giác', if (nOpt > 3) 'Hình tròn']..shuffle(rnd);
      return MathQ(
        kind: 'shape',
        text: 'Khối này là hình gì?',
        spoken: 'Khối này là hình gì?',
        options: opts,
        answer: ans,
        showShape: true,
      );
    case 2:
      return _addSub(10, rnd, nOpt);
    case 3:
      return _addSub(20, rnd, nOpt);
    case 4:
      return grade <= 1 ? _tensNoCarry(rnd, nOpt) : _addSub(100, rnd, nOpt);
    case 5:
      return _mulDiv([2, 5], rnd, nOpt);
    case 6:
      return _mulDiv([2, 3, 4, 5, 6, 7, 8, 9], rnd, nOpt);
    case 7:
      if (shape.geometry.isNotEmpty && rnd.nextBool()) {
        return _numeric('perimeter', 'Chu vi hình này là bao nhiêu xăng-ti-mét?',
            'Mỗi ô dài 1 xăng-ti-mét. Chu vi hình này là bao nhiêu xăng-ti-mét?', shape.perimeter, rnd, nOpt,
            showShape: true, note: 'Mỗi ô dài 1 cm');
      }
      return _numeric('area', 'Diện tích hình này là bao nhiêu xăng-ti-mét vuông?',
          'Mỗi ô là 1 xăng-ti-mét vuông. Diện tích hình này là bao nhiêu xăng-ti-mét vuông?', shape.size, rnd, nOpt,
          showShape: true, note: 'Mỗi ô là 1 cm²');
    default:
      return rnd.nextBool() ? _addSub(1000, rnd, nOpt) : _mul2x1(rnd, nOpt);
  }
}

MathQ _addSub(int limit, Random rnd, int nOpt) {
  final add = rnd.nextBool();
  if (add) {
    final a = 1 + rnd.nextInt(limit - 1);
    final b = 1 + rnd.nextInt(max(1, limit - a));
    return _numeric('add', '$a + $b = ?', '$a cộng $b bằng mấy?', a + b, rnd, nOpt);
  }
  final a = 2 + rnd.nextInt(limit - 1);
  final b = 1 + rnd.nextInt(a - 1);
  return _numeric('sub', '$a − $b = ?', '$a trừ $b bằng mấy?', a - b, rnd, nOpt);
}

/// Lớp 1: cộng/trừ số tròn chục hoặc không nhớ trong phạm vi 100.
MathQ _tensNoCarry(Random rnd, int nOpt) {
  final a1 = 1 + rnd.nextInt(8), a0 = rnd.nextInt(9);
  final b1 = rnd.nextInt(9 - a1) + 1, b0 = rnd.nextInt(10 - a0);
  final a = a1 * 10 + a0, b = b1 * 10 + b0;
  if (rnd.nextBool() && a + b < 100) {
    return _numeric('add', '$a + $b = ?', '$a cộng $b bằng mấy?', a + b, rnd, nOpt);
  }
  final big = a + b, small = b;
  return _numeric('sub', '$big − $small = ?', '$big trừ $small bằng mấy?', big - small, rnd, nOpt);
}

MathQ _mulDiv(List<int> tables, Random rnd, int nOpt) {
  final t = tables[rnd.nextInt(tables.length)];
  final k = 1 + rnd.nextInt(10);
  if (rnd.nextInt(3) < 2) {
    return _numeric('mul', '$t × $k = ?', '$t nhân $k bằng mấy?', t * k, rnd, nOpt);
  }
  return _numeric('div', '${t * k} : $t = ?', '${t * k} chia $t bằng mấy?', k, rnd, nOpt);
}

MathQ _mul2x1(Random rnd, int nOpt) {
  final a = 11 + rnd.nextInt(39), b = 2 + rnd.nextInt(4);
  return _numeric('mul', '$a × $b = ?', '$a nhân $b bằng mấy?', a * b, rnd, nOpt);
}

MathQ _numeric(String kind, String text, String spoken, int ans, Random rnd, int nOpt,
    {bool showShape = false, String note = ''}) {
  final pool = <int>{ans + 1, ans - 1, ans + 2, ans - 2, if (ans >= 10) ans + 10, if (ans >= 10) ans - 10, ans + 3}
    ..removeWhere((v) => v < 0 || v == ans);
  final distract = pool.toList()..shuffle(rnd);
  final opts = <int>[ans, ...distract.take(nOpt - 1)];
  var extra = ans + 4;
  while (opts.length < nOpt) {
    if (!opts.contains(extra)) opts.add(extra);
    extra++;
  }
  opts.shuffle(rnd);
  return MathQ(
    kind: kind,
    text: text,
    spoken: spoken,
    options: [for (final o in opts) '$o'],
    answer: '$ans',
    showShape: showShape,
    note: note,
  );
}
