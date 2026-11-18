import 'dart:math';

import 'block_math.dart';

/// Luật chơi "Xếp Khối Toán" (thuần Dart, có kiểm thử): bảng 8×8, mỗi lượt 3 khối,
/// xếp đầy một hàng ngang hoặc hàng dọc thì hàng đó nổ và được điểm.
/// Mỗi lượt có "khối bí ẩn" 🔒: giải đúng câu đố toán mới dùng được, và khối đó nhân đôi điểm khi nổ.

/// Một khối hình. [geometry]: 'square' (hình vuông), 'rect' (hình chữ nhật) hoặc '' (hình khác).
class Shape {
  final String id;
  final int tier; // cấp xuất hiện
  final List<(int, int)> cells; // (hàng, cột) tính từ góc trên trái
  final String geometry;

  Shape(this.id, this.tier, List<String> pattern, {this.geometry = ''}) : cells = _parse(pattern);

  static List<(int, int)> _parse(List<String> rows) => [
        for (var r = 0; r < rows.length; r++)
          for (var c = 0; c < rows[r].length; c++)
            if (rows[r][c] == 'X') (r, c),
      ];

  int get rows => cells.map((e) => e.$1).reduce(max) + 1;
  int get cols => cells.map((e) => e.$2).reduce(max) + 1;
  int get size => cells.length;

  /// Chu vi (tính theo cạnh ô, mỗi ô 1 cm) – đúng cho mọi hình ghép từ ô vuông.
  int get perimeter {
    final set = cells.toSet();
    var p = 0;
    for (final (r, c) in cells) {
      for (final d in const [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
        if (!set.contains((r + d.$1, c + d.$2))) p++;
      }
    }
    return p;
  }
}

final List<Shape> allShapes = [
  // cấp 1 – khối nhỏ, hình vuông & hình chữ nhật
  Shape('o1', 1, ['X'], geometry: 'square'),
  Shape('i2h', 1, ['XX'], geometry: 'rect'),
  Shape('i2v', 1, ['X', 'X'], geometry: 'rect'),
  Shape('i3h', 1, ['XXX'], geometry: 'rect'),
  Shape('i3v', 1, ['X', 'X', 'X'], geometry: 'rect'),
  Shape('o4', 1, ['XX', 'XX'], geometry: 'square'),
  // cấp 2 – góc chữ L nhỏ, thanh 4
  Shape('l3a', 2, ['X.', 'XX']),
  Shape('l3b', 2, ['.X', 'XX']),
  Shape('l3c', 2, ['XX', 'X.']),
  Shape('l3d', 2, ['XX', '.X']),
  Shape('i4h', 2, ['XXXX'], geometry: 'rect'),
  Shape('i4v', 2, ['X', 'X', 'X', 'X'], geometry: 'rect'),
  // cấp 3 – chữ T, chữ L, chữ S
  Shape('t1', 3, ['XXX', '.X.']),
  Shape('t2', 3, ['.X.', 'XXX']),
  Shape('t3', 3, ['X.', 'XX', 'X.']),
  Shape('t4', 3, ['.X', 'XX', '.X']),
  Shape('l4a', 3, ['X.', 'X.', 'XX']),
  Shape('l4b', 3, ['.X', '.X', 'XX']),
  Shape('l4c', 3, ['XXX', 'X..']),
  Shape('l4d', 3, ['XXX', '..X']),
  Shape('s1', 3, ['.XX', 'XX.']),
  Shape('z1', 3, ['XX.', '.XX']),
  // cấp 4 – khối lớn
  Shape('o9', 4, ['XXX', 'XXX', 'XXX'], geometry: 'square'),
  Shape('i5h', 4, ['XXXXX'], geometry: 'rect'),
  Shape('i5v', 4, ['X', 'X', 'X', 'X', 'X'], geometry: 'rect'),
  Shape('r23', 4, ['XXX', 'XXX'], geometry: 'rect'),
  Shape('r32', 4, ['XX', 'XX', 'XX'], geometry: 'rect'),
  // cấp 5 – chữ L to, dấu cộng
  Shape('bl1', 5, ['X..', 'X..', 'XXX']),
  Shape('bl2', 5, ['..X', '..X', 'XXX']),
  Shape('bl3', 5, ['XXX', 'X..', 'X..']),
  Shape('bl4', 5, ['XXX', '..X', '..X']),
  Shape('plus', 5, ['.X.', 'XXX', '.X.']),
];

/// Cấu hình từng cấp – độ khó tăng dần: khối to hơn, có đá cản, nhiều khối bí ẩn hơn, đố khó hơn.
class BlockLevel {
  final int n;
  const BlockLevel(this.n);

  int get tier => min(5, n);
  int get target => n <= 4 ? 60 + 40 * (n - 1) : 180 + 50 * (n - 4); // điểm cần đạt để lên cấp
  int get rocks => n < 3 ? 0 : min(10, 2 * (n - 2)); // ô đá có sẵn trên bảng
  int get lockedPerTray => n >= 6 ? 2 : 1;
}

/// Một ô trên bảng: màu khối, có sao (từ khối bí ẩn) hay là đá.
class BCell {
  final int color;
  final bool star;
  final bool rock;
  const BCell(this.color, {this.star = false, this.rock = false});
}

class PlaceOutcome {
  final int placed; // số ô vừa đặt
  final List<int> rows; // hàng nổ
  final List<int> cols; // cột nổ
  final List<(int, int, BCell)> cleared; // các ô đã nổ (để vẽ hiệu ứng)
  final bool starBonus;
  final int points;
  final String expression; // phép tính hiển thị cho bé, vd "2 hàng × 20 = 40"

  const PlaceOutcome({
    required this.placed,
    required this.rows,
    required this.cols,
    required this.cleared,
    required this.starBonus,
    required this.points,
    required this.expression,
  });

  int get lines => rows.length + cols.length;
}

/// Điểm khi nổ [lines] hàng cùng lúc: mỗi hàng 10 điểm × số hàng (nổ nhiều hàng cùng lúc được thưởng),
/// nhân đôi nếu có ô sao. Trả (điểm, phép tính để hiện cho bé).
(int, String) lineScore(int lines, {bool star = false}) {
  if (lines <= 0) return (0, '');
  final per = 10 * lines;
  final base = lines * per;
  var expr = lines == 1 ? '1 hàng = 10' : '$lines hàng × $per = $base';
  if (!star) return (base, expr);
  expr = lines == 1 ? '10 × 2 ⭐ = 20' : '$expr × 2 ⭐ = ${base * 2}';
  return (base * 2, expr);
}

class BlockBoard {
  static const n = 8;
  final List<BCell?> cells = List<BCell?>.filled(n * n, null);

  BCell? at(int r, int c) => cells[r * n + c];
  void set(int r, int c, BCell? v) => cells[r * n + c] = v;

  bool get isEmpty => cells.every((e) => e == null);
  int get filled => cells.where((e) => e != null).length;

  void clear() => cells.fillRange(0, cells.length, null);

  bool canPlace(Shape s, int row, int col) {
    for (final (r, c) in s.cells) {
      final rr = row + r, cc = col + c;
      if (rr < 0 || cc < 0 || rr >= n || cc >= n) return false;
      if (at(rr, cc) != null) return false;
    }
    return true;
  }

  bool fitsAnywhere(Shape s) {
    for (var r = 0; r <= n - s.rows; r++) {
      for (var c = 0; c <= n - s.cols; c++) {
        if (canPlace(s, r, c)) return true;
      }
    }
    return false;
  }

  /// Các hàng/cột sẽ nổ nếu đặt [s] tại (row, col) – để tô sáng trước khi thả tay.
  (List<int>, List<int>) wouldClear(Shape s, int row, int col) {
    final add = {for (final (r, c) in s.cells) (row + r) * n + (col + c)};
    bool full(int idx) => cells[idx] != null || add.contains(idx);
    final rows = [
      for (var r = 0; r < n; r++)
        if (List.generate(n, (c) => r * n + c).every(full)) r
    ];
    final cols = [
      for (var c = 0; c < n; c++)
        if (List.generate(n, (r) => r * n + c).every(full)) c
    ];
    return (rows, cols);
  }

  PlaceOutcome place(Shape s, int row, int col, int color, {bool star = false}) {
    assert(canPlace(s, row, col));
    for (final (r, c) in s.cells) {
      set(row + r, col + c, BCell(color, star: star));
    }
    final (rows, cols) = wouldClear(s, row, col);
    final toClear = <int>{};
    for (final r in rows) {
      for (var c = 0; c < n; c++) {
        toClear.add(r * n + c);
      }
    }
    for (final c in cols) {
      for (var r = 0; r < n; r++) {
        toClear.add(r * n + c);
      }
    }
    final cleared = <(int, int, BCell)>[];
    var starHit = false;
    for (final idx in toClear) {
      final cell = cells[idx];
      if (cell == null) continue;
      if (cell.star) starHit = true;
      cleared.add((idx ~/ n, idx % n, cell));
      cells[idx] = null;
    }
    final (linePts, expr) = lineScore(rows.length + cols.length, star: starHit);
    return PlaceOutcome(
      placed: s.size,
      rows: rows,
      cols: cols,
      cleared: cleared,
      starBonus: starHit,
      points: s.size + linePts,
      expression: expr,
    );
  }

  /// Rải ô đá cản (không tạo sẵn hàng đầy).
  void addRocks(int count, Random rnd) {
    var placed = 0, guard = 0;
    while (placed < count && guard++ < 500) {
      final r = rnd.nextInt(n), c = rnd.nextInt(n);
      if (at(r, c) != null) continue;
      final rowCount = List.generate(n, (i) => at(r, i)).where((e) => e != null).length;
      final colCount = List.generate(n, (i) => at(i, c)).where((e) => e != null).length;
      if (rowCount >= n - 2 || colCount >= n - 2) continue;
      set(r, c, const BCell(-1, rock: true));
      placed++;
    }
  }
}

/// Khối trong khay chờ đặt.
class TrayPiece {
  final Shape shape;
  final int color;
  bool locked;
  final MathQ? question;
  final bool star; // khối bí ẩn đã mở → ô có sao, nhân đôi điểm khi nổ
  int tries = 0;

  TrayPiece(this.shape, this.color, {this.locked = false, this.question}) : star = question != null;
}

class BlockGame {
  BlockGame({required this.grade, int level = 1, Random? rnd})
      : level = max(1, level),
        _rnd = rnd ?? Random() {
    startLevel();
  }

  final int grade;
  int level;
  final Random _rnd;
  final board = BlockBoard();
  final tray = List<TrayPiece?>.filled(3, null);
  int runScore = 0; // điểm cả ván
  int levelScore = 0; // điểm trong cấp hiện tại

  BlockLevel get cfg => BlockLevel(level);
  bool get levelDone => levelScore >= cfg.target;

  void startLevel() {
    board.clear();
    board.addRocks(cfg.rocks, _rnd);
    levelScore = 0;
    refillTray();
  }

  void nextLevel() {
    level++;
    startLevel();
  }

  /// Chơi lại từ đầu cấp hiện tại.
  void restart() {
    runScore = 0;
    startLevel();
  }

  List<Shape> get _pool => allShapes.where((s) => s.tier <= cfg.tier).toList();

  Shape _pick() {
    final pool = _pool;
    // khối của cấp mới xuất hiện nhiều hơn; khối 1 ô ít dần khi lên cấp
    final weights = [
      for (final s in pool) s.tier == cfg.tier ? 2.0 : (s.id == 'o1' && level > 2 ? 0.4 : 1.0),
    ];
    final total = weights.reduce((a, b) => a + b);
    var x = _rnd.nextDouble() * total;
    for (var i = 0; i < pool.length; i++) {
      x -= weights[i];
      if (x <= 0) return pool[i];
    }
    return pool.last;
  }

  /// Phát 3 khối mới; cố chọn bộ có ít nhất một khối đặt vừa bảng.
  void refillTray() {
    var shapes = [_pick(), _pick(), _pick()];
    for (var attempt = 0; attempt < 30 && !shapes.any(board.fitsAnywhere); attempt++) {
      shapes = [_pick(), _pick(), _pick()];
    }
    final lockIdx = <int>{};
    while (lockIdx.length < min(cfg.lockedPerTray, 3)) {
      lockIdx.add(_rnd.nextInt(3));
    }
    for (var i = 0; i < 3; i++) {
      final locked = lockIdx.contains(i);
      tray[i] = TrayPiece(
        shapes[i],
        _rnd.nextInt(8),
        locked: locked,
        question: locked ? makeQuestion(grade: grade, level: level, shape: shapes[i], rnd: _rnd) : null,
      );
    }
  }

  /// Đặt khối thứ [index] tại (row, col). Trả null nếu không đặt được.
  PlaceOutcome? place(int index, int row, int col) {
    final p = tray[index];
    if (p == null || p.locked || !board.canPlace(p.shape, row, col)) return null;
    final out = board.place(p.shape, row, col, p.color, star: p.star);
    tray[index] = null;
    addPoints(out.points);
    if (tray.every((e) => e == null)) refillTray();
    return out;
  }

  /// Thưởng khi giải đúng câu đố: lần 1 +10, lần 2 +5, sau đó +2.
  int unlockBonus(int tries) => tries <= 1 ? 10 : (tries == 2 ? 5 : 2);

  void unlock(int index) {
    final p = tray[index];
    if (p == null || !p.locked) return;
    p.locked = false;
    addPoints(unlockBonus(p.tries));
  }

  void addPoints(int pts) {
    runScore += pts;
    levelScore += pts;
  }

  /// Hết chỗ: không khối nào còn lại (kể cả khối bí ẩn nếu mở) đặt vừa bảng.
  bool get gameOver {
    final left = tray.whereType<TrayPiece>().toList();
    return left.isNotEmpty && !left.any((p) => board.fitsAnywhere(p.shape));
  }
}
