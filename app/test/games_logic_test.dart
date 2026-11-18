import 'dart:math';

import 'package:cu_to_mo/features/games/blocks/block_logic.dart';
import 'package:cu_to_mo/features/games/blocks/block_math.dart';
import 'package:cu_to_mo/features/games/runner/word_bank.dart';
import 'package:cu_to_mo/models/app_settings.dart';
import 'package:cu_to_mo/models/game_models.dart';
import 'package:flutter_test/flutter_test.dart';

Shape shape(String id) => allShapes.firstWhere((s) => s.id == id);

void main() {
  group('Xếp Khối Toán – bảng', () {
    test('đặt khối trong bảng, không chồng, không ra ngoài', () {
      final b = BlockBoard();
      expect(b.canPlace(shape('i3h'), 0, 0), isTrue);
      expect(b.canPlace(shape('i3h'), 0, 6), isFalse); // tràn phải
      expect(b.canPlace(shape('i3v'), 6, 0), isFalse); // tràn dưới
      b.place(shape('o4'), 0, 0, 1);
      expect(b.canPlace(shape('o1'), 1, 1), isFalse);
      expect(b.canPlace(shape('o1'), 2, 2), isTrue);
    });

    test('đầy hàng ngang thì nổ, điểm = số ô + 10', () {
      final b = BlockBoard();
      b.place(shape('i4h'), 0, 0, 1);
      final out = b.place(shape('i4h'), 0, 4, 2);
      expect(out.rows, [0]);
      expect(out.cols, isEmpty);
      expect(out.points, 4 + 10);
      expect(b.isEmpty, isTrue);
    });

    test('nổ hàng ngang + dọc cùng lúc: 2 hàng × 20 = 40', () {
      final b = BlockBoard();
      // hàng 0 thiếu ô (0,0); cột 0 thiếu ô (0,0)
      for (var c = 1; c < 8; c++) {
        b.set(0, c, const BCell(1));
      }
      for (var r = 1; r < 8; r++) {
        b.set(r, 0, const BCell(2));
      }
      final out = b.place(shape('o1'), 0, 0, 3);
      expect(out.lines, 2);
      expect(out.points, 1 + 40);
      expect(out.expression, '2 hàng × 20 = 40');
      expect(out.cleared.length, 15);
      expect(b.isEmpty, isTrue);
    });

    test('ô sao trong hàng nổ → nhân đôi', () {
      final b = BlockBoard();
      for (var c = 0; c < 7; c++) {
        b.set(3, c, const BCell(1));
      }
      final out = b.place(shape('o1'), 3, 7, 1, star: true);
      expect(out.starBonus, isTrue);
      expect(out.points, 1 + 20);
    });

    test('đá cản không tạo sẵn hàng gần đầy', () {
      for (var seed = 0; seed < 30; seed++) {
        final b = BlockBoard()..addRocks(10, Random(seed));
        expect(b.filled, 10);
        for (var r = 0; r < 8; r++) {
          final n = List.generate(8, (c) => b.at(r, c)).where((e) => e != null).length;
          expect(n, lessThan(7));
        }
      }
    });

    test('lineScore', () {
      expect(lineScore(0).$1, 0);
      expect(lineScore(1).$1, 10);
      expect(lineScore(3).$1, 90);
      expect(lineScore(2, star: true).$1, 80);
    });

    test('chu vi hình ghép từ ô vuông', () {
      expect(shape('o1').perimeter, 4);
      expect(shape('o4').perimeter, 8);
      expect(shape('i3h').perimeter, 8);
      expect(shape('r23').perimeter, 10);
      expect(shape('t1').perimeter, 10);
    });
  });

  group('Xếp Khối Toán – ván chơi', () {
    test('độ khó tăng dần theo cấp', () {
      for (var n = 1; n < 12; n++) {
        final a = BlockLevel(n), b = BlockLevel(n + 1);
        expect(b.target, greaterThan(a.target));
        expect(b.tier, greaterThanOrEqualTo(a.tier));
        expect(b.rocks, greaterThanOrEqualTo(a.rocks));
      }
      expect(const BlockLevel(1).rocks, 0);
      expect(const BlockLevel(1).tier, 1);
    });

    test('khay luôn có khối bí ẩn kèm câu đố, khối chỉ thuộc cấp hiện tại', () {
      for (var seed = 0; seed < 40; seed++) {
        final g = BlockGame(grade: 1 + seed % 5, level: 1 + seed % 7, rnd: Random(seed));
        final pieces = g.tray.whereType<TrayPiece>().toList();
        expect(pieces.length, 3);
        expect(pieces.where((p) => p.locked).length, g.cfg.lockedPerTray);
        for (final p in pieces) {
          expect(p.shape.tier, lessThanOrEqualTo(g.cfg.tier));
          if (p.locked) expect(p.question, isNotNull);
        }
      }
    });

    test('khối bị khóa không đặt được cho tới khi giải đố', () {
      final g = BlockGame(grade: 2, level: 1, rnd: Random(3));
      final i = g.tray.indexWhere((p) => p!.locked);
      final s = g.tray[i]!.shape;
      expect(g.place(i, 0, 0), isNull);
      g.tray[i]!.tries = 1;
      g.unlock(i);
      expect(g.runScore, 10);
      expect(g.board.canPlace(s, 0, 0) || g.board.fitsAnywhere(s), isTrue);
    });

    test('chơi tự động nhiều lượt: điểm khớp, khay tự đầy lại, tới lúc hết chỗ hoặc lên cấp', () {
      for (var seed = 0; seed < 20; seed++) {
        final g = BlockGame(grade: 3, level: 2, rnd: Random(seed));
        var expected = 0;
        for (var step = 0; step < 400; step++) {
          if (g.levelDone || g.gameOver) break;
          var moved = false;
          for (var i = 0; i < 3 && !moved; i++) {
            final p = g.tray[i];
            if (p == null) continue;
            if (p.locked) {
              p.tries = 1;
              g.unlock(i);
              expected += 10;
            }
            for (var r = 0; r < 8 && !moved; r++) {
              for (var c = 0; c < 8 && !moved; c++) {
                final out = g.place(i, r, c);
                if (out != null) {
                  expected += out.points;
                  moved = true;
                }
              }
            }
          }
          expect(g.runScore, expected);
          expect(g.tray.whereType<TrayPiece>(), isNotEmpty); // hết 3 khối là phát khay mới
          if (!moved) break;
        }
        expect(g.levelDone || g.gameOver, isTrue);
      }
    });
  });

  group('Câu đố toán', () {
    test('đáp án luôn nằm trong lựa chọn, lựa chọn không trùng, không âm', () {
      final rnd = Random(1);
      for (var grade = 1; grade <= 5; grade++) {
        for (var level = 1; level <= 10; level++) {
          for (final s in allShapes) {
            final q = makeQuestion(grade: grade, level: level, shape: s, rnd: rnd);
            expect(q.options, contains(q.answer));
            expect(q.options.toSet().length, q.options.length);
            expect(q.options.length, grade <= 2 ? 3 : 4);
            for (final o in q.options) {
              final v = int.tryParse(o);
              if (v != null) expect(v, greaterThanOrEqualTo(0));
            }
          }
        }
      }
    });

    test('đáp án tính đúng', () {
      final rnd = Random(7);
      for (var i = 0; i < 2000; i++) {
        final s = allShapes[i % allShapes.length];
        final q = makeQuestion(grade: 1 + i % 5, level: 1 + i % 9, shape: s, rnd: rnd);
        final ans = int.tryParse(q.answer);
        switch (q.kind) {
          case 'count' || 'area':
            expect(ans, s.size);
          case 'perimeter':
            expect(ans, s.perimeter);
          case 'shape':
            expect(q.answer, s.geometry == 'square' ? 'Hình vuông' : 'Hình chữ nhật');
          case 'add' || 'sub' || 'mul' || 'div':
            final m = RegExp(r'^(\d+) (.) (\d+) = \?$').firstMatch(q.text)!;
            final a = int.parse(m[1]!), b = int.parse(m[3]!);
            final v = switch (m[2]) { '+' => a + b, '−' => a - b, '×' => a * b, _ => a ~/ b };
            if (m[2] == ':') expect(a % b, 0);
            expect(ans, v);
        }
      }
    });

    test('không vượt chương trình: lớp 1 không có nhân chia', () {
      final rnd = Random(2);
      for (var level = 1; level <= 20; level++) {
        for (var k = 0; k < 30; k++) {
          final q = makeQuestion(grade: 1, level: level, shape: allShapes[k % allShapes.length], rnd: rnd);
          expect(['mul', 'div', 'perimeter', 'area'], isNot(contains(q.kind)));
          final n = int.tryParse(q.answer);
          if (n != null) expect(n, lessThanOrEqualTo(100));
        }
      }
    });
  });

  group('Cú Từ Ngữ', () {
    test('bảng bỏ dấu đầy đủ', () {
      expect(stripDiacritics('đường'), 'duong');
      expect(stripDiacritics('nguệch ngoạc'), 'nguech ngoac');
      expect(stripDiacritics('ưỡn ẹo ỷ'), 'uon eo y');
    });

    test('so khớp giọng nói', () {
      expect(matchSpeech('Con mèo!', 'con mèo'), SpeechMatch.exact);
      expect(matchSpeech('à con mèo đấy', 'con mèo'), SpeechMatch.exact);
      expect(matchSpeech('con meo', 'con mèo'), SpeechMatch.close);
      expect(matchSpeech('con chó', 'con mèo'), SpeechMatch.none);
      expect(matchSpeech('', 'mèo'), SpeechMatch.none);
      expect(matchSpeech('cá', 'cà'), SpeechMatch.close);
      expect(matchSpeech('mèo', 'mẹ'), SpeechMatch.none);
      // không nhận nhầm khi chỉ là một phần của tiếng khác
      expect(matchSpeech('hoang', 'hoa'), SpeechMatch.none);
      expect(matchSpeech('em yêu trường', 'Em yêu trường em'), SpeechMatch.none);
      expect(matchSpeech('em yêu trường em', 'Em yêu trường em'), SpeechMatch.exact);
      expect(matchSpeech('mẹ đi chợ về rồi', 'Mẹ đi chợ về'), SpeechMatch.exact);
    });

    test('thử thách hợp lệ ở mọi lớp/cấp', () {
      final rnd = Random(5);
      for (var grade = 1; grade <= 5; grade++) {
        for (var level = 1; level <= 8; level++) {
          for (var k = 0; k < 40; k++) {
            final c = nextChallenge(grade: grade, level: level, rnd: rnd);
            expect(c.options, contains(c.answer));
            expect(c.options.toSet().length, c.options.length);
            if (c.isRead) {
              expect(c.prompt, c.answer);
            } else {
              expect(c.prompt, contains('___'));
              expect(c.full, isNot(contains('___')));
              expect(c.full, contains(c.answer));
            }
          }
        }
      }
    });

    test('lớp 1 cấp đầu chỉ đọc từ một tiếng, chưa có thành ngữ', () {
      final rnd = Random(9);
      for (var k = 0; k < 100; k++) {
        final c = nextChallenge(grade: 1, level: 1, rnd: rnd);
        expect(c.isRead, isTrue);
        expect(c.prompt.contains(' '), isFalse);
      }
    });

    test('mỗi thành ngữ có đúng một chỗ trống, đáp án khác các lựa chọn sai', () {
      for (final p in proverbs) {
        expect('___'.allMatches(p.text).length, 1, reason: p.text);
        expect(p.wrong, isNot(contains(p.answer)));
        expect(p.wrong.length, 2);
      }
    });
  });

  group('Dữ liệu', () {
    test('điều ước lưu/đọc lại', () {
      const w = Wish(id: 'a', childId: 'c', day: '2026-11-18', emoji: '🍦', text: 'Con muốn ăn kem', createdAt: 5);
      final back = Wish.fromMap(w.toMap());
      expect(back.text, w.text);
      expect(back.pending, isTrue);
      final ok = back.copyWith(status: 'approved', reply: 'Ừ con');
      expect(Wish.fromMap(ok.toMap()).reply, 'Ừ con');
    });

    test('lời bố mẹ lưu/đọc lại + đoán mục đích từ chú thích', () {
      const v = ParentVoice(id: 'v', purpose: 'encourage', caption: 'Cố lên con', path: '/x.m4a', createdAt: 1);
      expect(ParentVoice.fromMap(v.toMap()).caption, 'Cố lên con');
      expect(guessPurpose('Mẹ khen con giỏi quá'), 'praise');
      expect(guessPurpose('Con cố lên nhé'), 'encourage');
      expect(guessPurpose('Hết giờ rồi con nghỉ mắt nhé'), 'time_up');
      expect(guessPurpose('Chào con yêu'), 'greeting');
      expect(guessPurpose('abc'), isNull);
    });

    test('cài đặt trò chơi lưu/đọc lại, mặc định 60 phút', () {
      const d = AppSettings();
      expect(d.gameMinutes, 60);
      expect(d.gamesEnabled, isTrue);
      final s = d.copyWith(gameMinutes: 30, gameNeedStudyMinutes: 10, gameDailyGoal: 500, gameMusic: false);
      final back = AppSettings.fromMap(s.toMap());
      expect(back.gameMinutes, 30);
      expect(back.gameNeedStudyMinutes, 10);
      expect(back.gameDailyGoal, 500);
      expect(back.gameMusic, isFalse);
      expect(AppSettings.fromMap({'ttsRate': 0.4}).gameMinutes, 60); // bản cũ chưa có trường mới
    });
  });
}
