import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../models/tutor_models.dart';
import '../../../theme/app_theme.dart';

/// Công cụ trực quan ở bậc gợi ý L4 (FR-24). Chỉ nhận SỐ TRONG ĐỀ (a, b) – không bao giờ nhận kết quả.
/// Bạn nhỏ tự chạm để đếm; công cụ không tự hiện đáp án.
class ManipulativeView extends StatelessWidget {
  const ManipulativeView({super.key, required this.spec, this.onClose});
  final ManipulativeSpec spec;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final a = spec.a.round(), b = spec.b.round();
    final title = switch (spec.tool) {
      'sticks' => '🧮 Que tính',
      'dots' => '🔵 Chấm tròn',
      'base10' => '🧱 Khối chục – đơn vị',
      'fraction' => '🍕 Phân số',
      'clock' => '🕒 Đồng hồ',
      'ruler' => '📏 Thước kẻ',
      _ => '🧮 Công cụ',
    };
    Widget body;
    switch (spec.tool) {
      case 'fraction':
        body = FractionTool(numerator: a, denominator: math.max(b, 1));
      case 'clock':
        body = ClockTool(hour: a, minute: b);
      case 'ruler':
        body = RulerTool(a: a, b: b, op: spec.op);
      case 'base10':
        body = Base10Tool(a: a, b: b, op: spec.op);
      default:
        final total = spec.op == '×' ? a * b : (spec.op == '-' || spec.op == ':' ? a : a + b);
        body = total > 40
            ? Base10Tool(a: a, b: b, op: spec.op)
            : CountingTool(a: a, b: b, op: spec.op, sticks: spec.tool == 'sticks');
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.think, width: 3),
      ),
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: titleStyle(24)),
              const Spacer(),
              if (onClose != null)
                IconButton(onPressed: onClose, icon: const Text('✖️', style: TextStyle(fontSize: 22))),
            ],
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

// ============================================================================ đếm que / chấm
class _Item {
  final int group;
  int? count;
  bool crossed = false;
  bool bundled = false;
  _Item(this.group);
}

class CountingTool extends ConsumerStatefulWidget {
  const CountingTool({super.key, required this.a, required this.b, required this.op, required this.sticks});
  final int a;
  final int b;
  final String op;
  final bool sticks;

  @override
  ConsumerState<CountingTool> createState() => _CountingToolState();
}

class _CountingToolState extends ConsumerState<CountingTool> {
  late List<_Item> _items;
  late List<List<_Item>> _groups; // phép chia: các nhóm
  int _next = 1;
  int _bundles = 0;
  bool _countMode = true; // phép trừ: bước 1 gạch bớt, bước 2 đếm

  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    final a = widget.a, b = widget.b;
    switch (widget.op) {
      case '×':
        _items = [for (var g = 0; g < a; g++) for (var i = 0; i < b; i++) _Item(g)];
      case '-':
      case ':':
        _items = [for (var i = 0; i < a; i++) _Item(0)];
      default:
        _items = [for (var i = 0; i < a; i++) _Item(0), for (var i = 0; i < b; i++) _Item(1)];
    }
    _groups = [for (var i = 0; i < math.max(1, widget.b); i++) <_Item>[]];
    _next = 1;
    _bundles = 0;
    _countMode = widget.op != '-';
  }

  void _tap(_Item it) {
    final tts = ref.read(ttsProvider);
    ref.read(soundProvider).pop();
    setState(() {
      if (widget.op == ':') {
        if (_groups.any((g) => g.contains(it))) return;
        _groups.reduce((x, y) => x.length <= y.length ? x : y).add(it); // chia lần lượt vào nhóm ít nhất
        return;
      }
      if (!_countMode) {
        it.crossed = !it.crossed;
        return;
      }
      if (it.crossed || it.count != null) return;
      it.count = _next++;
      tts.say('${it.count}');
    });
  }

  void _bundle() {
    final loose = _items.where((e) => e.count != null && !e.bundled).toList();
    if (loose.length < 10) return;
    setState(() {
      for (final e in loose.take(10)) {
        e.bundled = true;
      }
      _bundles++;
    });
    ref.read(ttsProvider).say('Gom 10 que thành 1 bó!');
  }

  Color _color(_Item it) => it.group.isEven ? AppColors.sky : AppColors.orange;

  Widget _piece(_Item it) {
    final faded = it.crossed;
    final child = widget.sticks
        ? Container(
            width: 12,
            height: 58,
            decoration: BoxDecoration(
              color: faded ? Colors.grey.shade300 : _color(it),
              borderRadius: BorderRadius.circular(6),
            ),
          )
        : Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: faded ? Colors.grey.shade300 : _color(it), shape: BoxShape.circle),
          );
    return GestureDetector(
      onTap: () => _tap(it),
      child: SizedBox(
        width: widget.sticks ? 34 : 46,
        height: widget.sticks ? 86 : 64,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Positioned(bottom: 0, child: child),
            if (faded)
              Positioned(
                  bottom: widget.sticks ? 20 : 8,
                  child: Text('✖', style: titleStyle(26, AppColors.think))),
            if (it.count != null)
              Positioned(top: 0, child: Text('${it.count}', style: titleStyle(18, AppColors.ink))),
          ],
        ),
      ),
    );
  }

  Widget _row(List<_Item> items) => Wrap(spacing: 2, runSpacing: 2, children: [for (final it in items) _piece(it)]);

  @override
  Widget build(BuildContext context) {
    final visible = _items.where((e) => !e.bundled).toList();
    final canBundle = widget.sticks && _items.where((e) => e.count != null && !e.bundled).length >= 10;
    String hint;
    switch (widget.op) {
      case '-':
        hint = _countMode ? 'Chạm vào từng que còn lại để đếm.' : 'Chạm để gạch bớt, xong bấm "Đếm".';
      case '×':
        hint = 'Có ${widget.a} nhóm, mỗi nhóm ${widget.b}. Chạm để đếm nhé!';
      case ':':
        hint = 'Chạm từng cái để chia đều vào ${widget.b} nhóm.';
      default:
        hint = 'Chạm vào từng ${widget.sticks ? 'que' : 'chấm'} để đếm cùng Cú!';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(hint, style: bodyStyle(18)),
        const SizedBox(height: 6),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_bundles > 0)
                  Wrap(spacing: 8, children: [
                    for (var i = 0; i < _bundles; i++)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 18),
                        decoration: BoxDecoration(
                          color: AppColors.sky.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.sky, width: 2),
                        ),
                        child: Text('🔗 1 bó', style: bodyStyle(18, AppColors.ink, FontWeight.w800)),
                      ),
                  ]),
                if (widget.op == '×')
                  for (var g = 0; g < widget.a; g++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _row(visible.where((e) => e.group == g).toList()),
                    )
                else if (widget.op == '+')
                  Wrap(
                    spacing: 18,
                    children: [
                      _row(visible.where((e) => e.group == 0).toList()),
                      _row(visible.where((e) => e.group == 1).toList()),
                    ],
                  )
                else if (widget.op == ':')
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _row(visible.where((e) => !_groups.any((g) => g.contains(e))).toList()),
                      const SizedBox(height: 8),
                      Wrap(spacing: 10, runSpacing: 10, children: [
                        for (final g in _groups)
                          Container(
                            constraints: const BoxConstraints(minWidth: 90, minHeight: 70),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.think, width: 3),
                            ),
                            child: Wrap(children: [
                              for (final it in g)
                                Padding(
                                  padding: const EdgeInsets.all(2),
                                  child: Container(
                                    width: 20,
                                    height: widget.sticks ? 36 : 20,
                                    decoration: BoxDecoration(
                                      color: AppColors.sky,
                                      borderRadius: BorderRadius.circular(widget.sticks ? 4 : 10),
                                    ),
                                  ),
                                ),
                            ]),
                          ),
                      ]),
                    ],
                  )
                else
                  _row(visible),
              ],
            ),
          ),
        ),
        Wrap(spacing: 10, children: [
          if (widget.op == '-' && !_countMode)
            ElevatedButton(onPressed: () => setState(() => _countMode = true), child: const Text('🔢 Đếm')),
          if (canBundle)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.sky),
              onPressed: _bundle,
              child: const Text('🔗 Gom 10 que'),
            ),
          OutlinedButton(onPressed: () => setState(_reset), child: const Text('🔁 Làm lại')),
        ]),
      ],
    );
  }
}

// ============================================================================ khối chục – đơn vị
class Base10Tool extends ConsumerStatefulWidget {
  const Base10Tool({super.key, required this.a, required this.b, required this.op});
  final int a;
  final int b;
  final String op;

  @override
  ConsumerState<Base10Tool> createState() => _Base10ToolState();
}

class _Base10ToolState extends ConsumerState<Base10Tool> {
  final _tapped = <String>{};

  Widget _number(int n, Color color, String tag) {
    final tens = (n ~/ 10).clamp(0, 30).toInt(), ones = n % 10;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$n = $tens chục và $ones đơn vị', style: bodyStyle(18, AppColors.ink, FontWeight.w800)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            for (var i = 0; i < tens; i++) _block('$tag-t$i', color, rod: true),
            const SizedBox(width: 10),
            for (var i = 0; i < ones; i++) _block('$tag-o$i', color, rod: false),
          ],
        ),
      ],
    );
  }

  Widget _block(String id, Color color, {required bool rod}) {
    final on = _tapped.contains(id);
    return GestureDetector(
      onTap: () {
        ref.read(soundProvider).pop();
        setState(() => on ? _tapped.remove(id) : _tapped.add(id));
      },
      child: Container(
        width: rod ? 16 : 16,
        height: rod ? 100 : 16,
        decoration: BoxDecoration(
          color: on ? AppColors.sun : color,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: Colors.white, width: 1),
        ),
        child: rod
            ? Column(children: List.generate(10, (_) => Expanded(child: Container(
                margin: const EdgeInsets.symmetric(vertical: 0.5),
                color: Colors.white.withValues(alpha: 0.25)))))
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Chạm vào thanh / khối để đánh dấu khi đếm.', style: bodyStyle(17)),
          const SizedBox(height: 8),
          _number(widget.a, AppColors.sky, 'a'),
          if (widget.b > 0) ...[
            const SizedBox(height: 12),
            Text(widget.op == '-' ? 'Bớt đi:' : 'Thêm:', style: bodyStyle(18, AppColors.think, FontWeight.w800)),
            _number(widget.b, AppColors.orange, 'b'),
          ],
        ],
      ),
    );
  }
}

// ============================================================================ phân số
class FractionTool extends ConsumerStatefulWidget {
  const FractionTool({super.key, required this.numerator, required this.denominator});
  final int numerator;
  final int denominator;

  @override
  ConsumerState<FractionTool> createState() => _FractionToolState();
}

class _FractionToolState extends ConsumerState<FractionTool> {
  final _on = <int>{};

  @override
  Widget build(BuildContext context) {
    final n = widget.denominator.clamp(1, 24).toInt();
    return Row(
      children: [
        LayoutBuilder(builder: (context, box) {
          final size = math.min(box.maxHeight, 240.0);
          return GestureDetector(
            onTapDown: (d) {
              final c = Offset(size / 2, size / 2);
              final v = d.localPosition - c;
              if (v.distance > size / 2) return;
              var ang = math.atan2(v.dy, v.dx) + math.pi / 2;
              if (ang < 0) ang += 2 * math.pi;
              final idx = (ang / (2 * math.pi / n)).floor() % n;
              ref.read(soundProvider).pop();
              setState(() => _on.contains(idx) ? _on.remove(idx) : _on.add(idx));
            },
            child: CustomPaint(size: Size(size, size), painter: _PiePainter(n, _on)),
          );
        }),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Cái bánh chia thành $n phần bằng nhau.', style: bodyStyle(19)),
              const SizedBox(height: 8),
              Text('Bạn đã tô ${_on.length} phần.', style: titleStyle(24, AppColors.sky)),
              const SizedBox(height: 8),
              OutlinedButton(onPressed: () => setState(_on.clear), child: const Text('🔁 Xóa màu')),
            ],
          ),
        ),
      ],
    );
  }
}

class _PiePainter extends CustomPainter {
  _PiePainter(this.n, this.on);
  final int n;
  final Set<int> on;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final sweep = 2 * math.pi / n;
    for (var i = 0; i < n; i++) {
      canvas.drawArc(rect, -math.pi / 2 + i * sweep, sweep, true,
          Paint()..color = on.contains(i) ? AppColors.orange : AppColors.owlBelly);
      canvas.drawArc(
          rect,
          -math.pi / 2 + i * sweep,
          sweep,
          true,
          Paint()
            ..color = AppColors.ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3);
    }
  }

  @override
  bool shouldRepaint(_PiePainter old) => true;
}

// ============================================================================ đồng hồ
class ClockTool extends StatefulWidget {
  const ClockTool({super.key, required this.hour, required this.minute});
  final int hour;
  final int minute;

  @override
  State<ClockTool> createState() => _ClockToolState();
}

class _ClockToolState extends State<ClockTool> {
  late int _minutes = (widget.hour % 24) * 60 + widget.minute.clamp(0, 59).toInt();

  void _add(int m) => setState(() => _minutes = (_minutes + m) % (24 * 60));

  @override
  Widget build(BuildContext context) {
    final h = _minutes ~/ 60, m = _minutes % 60;
    return Row(
      children: [
        LayoutBuilder(builder: (context, box) {
          final size = math.min(box.maxHeight, 230.0);
          return CustomPaint(size: Size(size, size), painter: _ClockPainter(h, m));
        }),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${h.toString().padLeft(2, '0')} giờ ${m.toString().padLeft(2, '0')} phút',
                  style: titleStyle(26)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                OutlinedButton(onPressed: () => _add(-5), child: const Text('− 5 phút')),
                OutlinedButton(onPressed: () => _add(5), child: const Text('+ 5 phút')),
                OutlinedButton(onPressed: () => _add(60), child: const Text('+ 1 giờ')),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}

class _ClockPainter extends CustomPainter {
  _ClockPainter(this.h, this.m);
  final int h;
  final int m;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    canvas.drawCircle(c, r, Paint()..color = Colors.white);
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = AppColors.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5);
    for (var i = 1; i <= 12; i++) {
      final a = i * math.pi / 6 - math.pi / 2;
      final tp = TextPainter(
        text: TextSpan(text: '$i', style: titleStyle(r * 0.18)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c + Offset(math.cos(a), math.sin(a)) * r * 0.78 - Offset(tp.width / 2, tp.height / 2));
    }
    final hourA = ((h % 12) + m / 60) * math.pi / 6 - math.pi / 2;
    final minA = m * math.pi / 30 - math.pi / 2;
    canvas.drawLine(c, c + Offset(math.cos(hourA), math.sin(hourA)) * r * 0.5,
        Paint()..color = AppColors.ink..strokeWidth = 8..strokeCap = StrokeCap.round);
    canvas.drawLine(c, c + Offset(math.cos(minA), math.sin(minA)) * r * 0.75,
        Paint()..color = AppColors.orange..strokeWidth = 5..strokeCap = StrokeCap.round);
    canvas.drawCircle(c, 7, Paint()..color = AppColors.ink);
  }

  @override
  bool shouldRepaint(_ClockPainter old) => old.h != h || old.m != m;
}

// ============================================================================ thước kẻ
class RulerTool extends StatefulWidget {
  const RulerTool({super.key, required this.a, required this.b, required this.op});
  final int a;
  final int b;
  final String op;

  @override
  State<RulerTool> createState() => _RulerToolState();
}

class _RulerToolState extends State<RulerTool> {
  double? _mark;

  @override
  Widget build(BuildContext context) {
    final maxCm = (math.max(widget.a, widget.b) + (widget.op == '+' ? math.min(widget.a, widget.b) : 0) + 2)
        .clamp(10, 100)
        .toInt();
    return LayoutBuilder(builder: (context, box) {
      final unit = (box.maxWidth - 20) / maxCm;
      return GestureDetector(
        onTapDown: (d) => setState(() => _mark = ((d.localPosition.dx - 10) / unit).roundToDouble().clamp(0, maxCm.toDouble()).toDouble()),
        child: CustomPaint(
          size: Size(box.maxWidth, math.min(box.maxHeight, 170)),
          painter: _RulerPainter(maxCm, unit, widget.a, widget.b, widget.op, _mark),
        ),
      );
    });
  }
}

class _RulerPainter extends CustomPainter {
  _RulerPainter(this.maxCm, this.unit, this.a, this.b, this.op, this.mark);
  final int maxCm;
  final double unit;
  final int a;
  final int b;
  final String op;
  final double? mark;

  @override
  void paint(Canvas canvas, Size size) {
    const x0 = 10.0, y0 = 70.0;
    canvas.drawRect(Rect.fromLTWH(x0 - 6, y0, maxCm * unit + 12, 60), Paint()..color = AppColors.owlBelly);
    for (var i = 0; i <= maxCm; i++) {
      final x = x0 + i * unit;
      final big = i % 5 == 0;
      canvas.drawLine(Offset(x, y0), Offset(x, y0 + (big ? 26 : 14)), Paint()..color = AppColors.ink..strokeWidth = 2);
      if (big || maxCm <= 20) {
        final tp = TextPainter(text: TextSpan(text: '$i', style: bodyStyle(13)), textDirection: TextDirection.ltr)
          ..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, y0 + 30));
      }
    }
    // thanh độ dài a (xanh) và b (cam) – đều là số có trong đề
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x0, y0 - 26, a * unit, 16), const Radius.circular(6)),
        Paint()..color = AppColors.sky);
    if (b > 0) {
      final start = op == '+' ? x0 + a * unit : x0;
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(start, y0 - 50, b * unit, 16), const Radius.circular(6)),
          Paint()..color = AppColors.orange);
    }
    if (mark != null) {
      final x = x0 + mark! * unit;
      canvas.drawLine(Offset(x, 6), Offset(x, y0 + 60), Paint()..color = AppColors.think..strokeWidth = 4);
    }
  }

  @override
  bool shouldRepaint(_RulerPainter old) => true;
}
