import 'dart:math';

import 'package:cu_to_mo/features/offline/problem_generator.dart';
import 'package:cu_to_mo/models/app_settings.dart';
import 'package:cu_to_mo/models/child_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseChildNumber', () {
    test('chữ số', () {
      expect(parseChildNumber('12'), 12);
      expect(parseChildNumber('là 12 cái'), 12);
      expect(parseChildNumber('2,5'), 2.5);
    });
    test('số đọc bằng chữ', () {
      expect(parseChildNumber('mười hai'), 12);
      expect(parseChildNumber('hai mươi lăm'), 25);
      expect(parseChildNumber('hai lăm'), 25);
      expect(parseChildNumber('mười lăm'), 15);
      expect(parseChildNumber('một trăm hai mươi'), 120);
      expect(parseChildNumber('ba nghìn'), 3000);
    });
    test('không có số', () {
      expect(parseChildNumber('con không hiểu'), null);
    });
  });

  group('ProblemGenerator', () {
    for (var g = 1; g <= 5; g++) {
      test('lớp $g sinh bài hợp lệ', () {
        final gen = ProblemGenerator(g, Random(g));
        for (var i = 0; i < 200; i++) {
          final p = gen.next();
          expect(p.answer >= 0, isTrue);
          expect(p.text.isNotEmpty, isTrue);
          final expected = switch (p.op) {
            '+' => p.a + p.b,
            '-' => p.a - p.b,
            '×' => p.a * p.b,
            _ => p.a ~/ p.b,
          };
          expect(p.check(expected), isTrue);
          if (g == 1) expect(p.answer <= 20, isTrue);
        }
      });
    }
  });

  test('giờ ngủ qua nửa đêm', () {
    const s = AppSettings(bedtime: '21:00', wakeTime: '06:00');
    expect(s.isBedtime(DateTime(2026, 1, 1, 22, 0)), isTrue);
    expect(s.isBedtime(DateTime(2026, 1, 1, 5, 59)), isTrue);
    expect(s.isBedtime(DateTime(2026, 1, 1, 6, 0)), isFalse);
    expect(s.isBedtime(DateTime(2026, 1, 1, 15, 0)), isFalse);
    expect(const AppSettings(bedtime: '').isBedtime(DateTime(2026, 1, 1, 23)), isFalse);
  });

  test('Cú lớn lên theo số sao (FR-41)', () {
    ChildProfile p(int stars) => ChildProfile(id: 'x', nickname: 'Bông', grade: 1, avatar: '🐱', stars: stars);
    expect(p(0).owlStage, 0);
    expect(p(30).owlStage, 1);
    expect(p(120).owlStage, 2);
    expect(p(300).owlStage, 3);
    expect(p(75).stageProgress, closeTo(0.5, 1e-9));
  });
}
