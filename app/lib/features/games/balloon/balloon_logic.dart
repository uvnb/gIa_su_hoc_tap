import 'dart:math';

/// Luật "Bóng Bay Phép Tính": mỗi lượt có một MỤC TIÊU (vd "bằng 10", "số chẵn"),
/// bóng bay lên mang phép tính / con số – bé chạm đúng những quả hợp mục tiêu.

class BalloonItem {
  final String label; // chữ trên bóng, vd "3 + 7"
  final int value; // giá trị của phép tính
  final bool good; // hợp mục tiêu?
  const BalloonItem(this.label, this.value, this.good);
}

class BalloonGoal {
  final String kind; // equal | even | odd | greater | less | div
  final String title; // hiện cho bé, vd "Bằng 10"
  final String spoken; // Cú đọc
  final int target;
  const BalloonGoal(this.kind, this.title, this.spoken, this.target);

  bool test(int v) => switch (kind) {
        'even' => v.isEven,
        'odd' => v.isOdd,
        'greater' => v > target,
        'less' => v < target,
        'div' => v % target == 0,
        _ => v == target,
      };
}

/// Phép tính bé được dùng theo lớp & cấp.
class BalloonSkill {
  final int limit; // phạm vi số
  final bool sub;
  final bool mul;
  final bool div;
  const BalloonSkill(this.limit, {this.sub = true, this.mul = false, this.div = false});
}

BalloonSkill skillFor(int grade, int level) {
  if (grade <= 1) return BalloonSkill(level <= 2 ? 10 : 20);
  if (grade == 2) return BalloonSkill(level <= 2 ? 20 : 100, mul: level >= 2);
  if (grade == 3) return BalloonSkill(100, mul: true, div: level >= 2);
  return const BalloonSkill(1000, mul: true, div: true);
}

/// Cấu hình theo cấp: bóng bay nhanh hơn, ra dày hơn.
class BalloonLevel {
  final int n;
  const BalloonLevel(this.n);
  double get riseSpeed => min(170, 70 + 12.0 * (n - 1)); // điểm ảnh / giây
  double get spawnEvery => max(0.55, 1.15 - 0.07 * (n - 1)); // giây
  int get roundSeconds => 60;
  int get passScore => 90 + 20 * (n - 1); // đủ điểm trong một ván → lên cấp
}

const goodPerGoal = 5; // bắn đủ 5 bóng đúng → đổi mục tiêu

BalloonGoal makeGoal({required int grade, required int level, required Random rnd}) {
  final sk = skillFor(grade, level);
  // lớp 2+ thỉnh thoảng có mục tiêu kiểu "số chẵn / lẻ / lớn hơn"; lớp 4+ thêm "chia hết"
  final r = rnd.nextDouble();
  if (grade >= 4 && r < 0.2) {
    final d = [2, 3, 5, 9][rnd.nextInt(4)];
    return BalloonGoal('div', 'Chia hết cho $d', 'Chạm bóng có số chia hết cho $d', d);
  }
  if (grade >= 2 && r < 0.3) {
    final even = rnd.nextBool();
    return even
        ? const BalloonGoal('even', 'Số chẵn', 'Chạm bóng có kết quả là số chẵn', 0)
        : const BalloonGoal('odd', 'Số lẻ', 'Chạm bóng có kết quả là số lẻ', 0);
  }
  if (grade >= 2 && r < 0.4) {
    final t = (sk.limit ~/ 2) + rnd.nextInt(max(1, sk.limit ~/ 4));
    return rnd.nextBool()
        ? BalloonGoal('greater', 'Lớn hơn $t', 'Chạm bóng có kết quả lớn hơn $t', t)
        : BalloonGoal('less', 'Nhỏ hơn $t', 'Chạm bóng có kết quả nhỏ hơn $t', t);
  }
  int t;
  if (sk.mul && rnd.nextBool()) {
    final a = 2 + rnd.nextInt(8), b = 2 + rnd.nextInt(8);
    t = a * b; // mục tiêu có nhiều cách tách thành phép nhân
  } else {
    t = 4 + rnd.nextInt(max(1, min(sk.limit, 100) - 4));
  }
  return BalloonGoal('equal', 'Bằng $t', 'Chạm bóng có kết quả bằng $t', t);
}

/// Phép tính có giá trị [v] (dùng phép bé đã học). Không tìm được thì ghi số trơn.
String exprFor(int v, BalloonSkill sk, Random rnd) {
  final opts = <String>[];
  if (v >= 2) {
    final a = 1 + rnd.nextInt(v - 1);
    opts.add('$a + ${v - a}');
  }
  if (sk.sub) {
    final b = 1 + rnd.nextInt(max(1, min(9, sk.limit - v)));
    if (v + b <= max(sk.limit, 20)) opts.add('${v + b} − $b');
  }
  if (sk.mul) {
    for (var a = 2; a <= 9; a++) {
      if (v % a == 0 && v ~/ a >= 2 && v ~/ a <= 10) opts.add('$a × ${v ~/ a}');
    }
  }
  if (sk.div && v >= 1 && v <= 10) {
    final b = 2 + rnd.nextInt(8);
    opts.add('${v * b} : $b');
  }
  if (opts.isEmpty) return '$v';
  return opts[rnd.nextInt(opts.length)];
}

int evalExpr(String label) {
  final m = RegExp(r'^(\d+) (.) (\d+)$').firstMatch(label);
  if (m == null) return int.parse(label);
  final a = int.parse(m[1]!), b = int.parse(m[3]!);
  return switch (m[2]) { '+' => a + b, '−' => a - b, '×' => a * b, _ => a ~/ b };
}

/// Tạo một quả bóng: [good] = có hợp mục tiêu không.
BalloonItem makeBalloon(BalloonGoal goal,
    {required bool good, required int grade, required int level, required Random rnd}) {
  final sk = skillFor(grade, level);
  final v = _valueFor(goal, good, sk, rnd);
  // mục tiêu "chẵn/lẻ/lớn/nhỏ/chia hết": nửa số bóng ghi số trơn cho bé nhìn dấu hiệu
  final plain = goal.kind != 'equal' && rnd.nextBool();
  final label = plain ? '$v' : exprFor(v, sk, rnd);
  return BalloonItem(label, evalExpr(label), goal.test(evalExpr(label)));
}

/// Chọn giá trị đúng / sai theo từng loại mục tiêu (không phó mặc may rủi).
int _valueFor(BalloonGoal goal, bool good, BalloonSkill sk, Random rnd) {
  final t = goal.target;
  final top = max(20, min(sk.limit, 100));
  switch (goal.kind) {
    case 'equal':
      if (good) return t;
      final d = [-3, -2, -1, 1, 2, 3, 10, -10].where((d) => t + d >= 0).toList();
      return t + d[rnd.nextInt(d.length)];
    case 'greater':
      final span = max(10, t ~/ 4);
      return good ? t + 1 + rnd.nextInt(span) : max(0, t - rnd.nextInt(span));
    case 'less':
      final span = max(10, t ~/ 4);
      return good ? max(0, t - 1 - rnd.nextInt(min(span, t))) : t + rnd.nextInt(span);
    case 'div':
      final k = 1 + rnd.nextInt(max(1, top ~/ t));
      return good ? t * k : t * k + 1 + rnd.nextInt(t - 1);
    default: // even | odd
      var v = 1 + rnd.nextInt(top);
      final wantEven = (goal.kind == 'even') == good;
      if (v.isEven != wantEven) v++;
      return v;
  }
}
