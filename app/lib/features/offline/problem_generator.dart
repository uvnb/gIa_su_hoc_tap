import 'dart:math';

/// Bài luyện tập offline (FR-70): sinh ngẫu nhiên theo lớp, chấm cục bộ.
/// Đây là ngoại lệ duy nhất app tự biết kết quả – và vẫn KHÔNG bao giờ hiển thị/đọc kết quả cho bé.
class OfflineProblem {
  final String text;
  final int a;
  final int b;
  final String op; // + - × :
  final num answer;
  final String tool; // sticks | dots | base10

  const OfflineProblem(this.text, this.a, this.b, this.op, this.answer, this.tool);

  bool check(num value) => (value - answer).abs() < 1e-9;
}

class ProblemGenerator {
  ProblemGenerator(this.grade, [Random? rng]) : _r = rng ?? Random();
  final int grade;
  final Random _r;

  static const _names = ['Lan', 'Minh', 'An', 'Bình', 'Hoa', 'Nam', 'Mai', 'Tú'];
  static const _things = ['cái kẹo', 'quả cam', 'viên bi', 'cái bút chì', 'bông hoa', 'con gà', 'quyển vở'];

  int _rand(int lo, int hi) => lo + _r.nextInt(hi - lo + 1);
  String _pick(List<String> l) => l[_r.nextInt(l.length)];

  OfflineProblem next() {
    final word = grade <= 3 && _r.nextBool();
    switch (grade) {
      case 1:
        return _r.nextBool() ? _add(1, 9, 1, 9, word, max: 20) : _sub(5, 20, word);
      case 2:
        final k = _r.nextInt(3);
        if (k == 0) return _add(10, 60, 5, 39, word, max: 100);
        if (k == 1) return _sub(20, 99, word);
        return _mul(2, 5, 1, 10, word);
      case 3:
        final k = _r.nextInt(4);
        if (k == 0) return _mul(2, 9, 2, 9, word);
        if (k == 1) return _div(2, 9, 2, 9, word);
        if (k == 2) return _add(100, 600, 50, 399, false, max: 1000);
        return _sub(200, 999, false);
      case 4:
        final k = _r.nextInt(3);
        if (k == 0) return _mul(12, 99, 2, 9, false);
        if (k == 1) return _div(2, 9, 11, 40, false);
        return _add(1000, 5000, 100, 4999, false, max: 10000);
      default:
        final k = _r.nextInt(3);
        if (k == 0) return _mul(21, 99, 11, 30, false);
        if (k == 1) return _div(11, 25, 11, 40, false);
        return _sub(1000, 99999, false);
    }
  }

  OfflineProblem _add(int aLo, int aHi, int bLo, int bHi, bool word, {required int max}) {
    var a = _rand(aLo, aHi), b = _rand(bLo, bHi);
    while (a + b > max) {
      b = _rand(bLo, bHi);
      a = _rand(aLo, aHi);
    }
    final t = word
        ? '${_pick(_names)} có $a ${_thing()}, được cho thêm $b. Hỏi có tất cả bao nhiêu?'
        : '$a + $b = ?';
    return OfflineProblem(t, a, b, '+', a + b, a + b <= 20 ? 'sticks' : 'base10');
  }

  String _thing() => _pick(_things);

  OfflineProblem _sub(int aLo, int aHi, bool word) {
    final a = _rand(aLo, aHi);
    final b = _rand(1, a - 1 < 1 ? 1 : a - 1);
    final t = word
        ? '${_pick(_names)} có $a ${_thing()}, cho bạn $b. Hỏi còn lại bao nhiêu?'
        : '$a − $b = ?';
    return OfflineProblem(t, a, b, '-', a - b, a <= 20 ? 'sticks' : 'base10');
  }

  OfflineProblem _mul(int aLo, int aHi, int bLo, int bHi, bool word) {
    final a = _rand(aLo, aHi), b = _rand(bLo, bHi);
    final t = word ? 'Có $a hộp, mỗi hộp có $b cái bút. Hỏi có tất cả bao nhiêu cái bút?' : '$a × $b = ?';
    return OfflineProblem(t, a, b, '×', a * b, a * b <= 40 ? 'dots' : 'base10');
  }

  OfflineProblem _div(int bLo, int bHi, int qLo, int qHi, bool word) {
    final b = _rand(bLo, bHi), q = _rand(qLo, qHi);
    final a = b * q;
    final t = word ? 'Có $a cái kẹo chia đều cho $b bạn. Hỏi mỗi bạn được mấy cái kẹo?' : '$a : $b = ?';
    return OfflineProblem(t, a, b, ':', q, a <= 40 ? 'dots' : 'base10');
  }
}

/// Đổi câu trả lời của bé (gõ hoặc nói) thành số: "12", "mười hai", "hai mươi lăm", "2,5".
num? parseChildNumber(String input) {
  final s = input.toLowerCase().trim();
  final m = RegExp(r'-?\d+(?:[.,]\d+)?').allMatches(s).toList();
  if (m.isNotEmpty) return num.tryParse(m.last.group(0)!.replaceAll(',', '.'));
  const units = {
    'không': 0, 'một': 1, 'mốt': 1, 'hai': 2, 'ba': 3, 'bốn': 4, 'tư': 4, 'năm': 5, 'lăm': 5,
    'sáu': 6, 'bảy': 7, 'bẩy': 7, 'tám': 8, 'chín': 9,
  };
  final words = s.split(RegExp(r'[\s,.!?]+')).where((w) => w.isNotEmpty).toList();
  int? total;
  var seg = 0;
  int? last;
  var seen = false;
  for (final w in words) {
    if (units.containsKey(w)) {
      final d = units[w]!;
      if (last != null && seg < 10 && (w == 'mốt' || w == 'lăm' || w == 'tư')) {
        seg = last * 10 + d; // "hai lăm" = 25
        last = null;
      } else {
        seg += d;
        last = d;
      }
      seen = true;
    } else if (w == 'mười') {
      seg += 10;
      last = null;
      seen = true;
    } else if (w == 'mươi' || w == 'chục') {
      if (last != null) seg = seg - last + last * 10;
      last = null;
    } else if (w == 'trăm') {
      if (last != null) seg = seg - last + last * 100;
      last = null;
      seen = true;
    } else if (w == 'nghìn' || w == 'ngàn') {
      total = (total ?? 0) + (seg == 0 ? 1 : seg) * 1000;
      seg = 0;
      last = null;
      seen = true;
    }
  }
  if (!seen) return null;
  return (total ?? 0) + seg;
}
