import 'package:cu_to_mo/features/english/english_content.dart';
import 'package:cu_to_mo/features/english/english_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mỗi chủ đề đủ từ để chơi (≥ 6), không trùng từ, có nghĩa tiếng Việt', () {
    for (final t in enTopics) {
      expect(t.words.length, greaterThanOrEqualTo(6), reason: t.id);
      expect(t.words.map((w) => w.en.toLowerCase()).toSet().length, t.words.length, reason: t.id);
      for (final w in t.words) {
        expect(w.vi.trim(), isNotEmpty);
        expect(w.emoji.trim(), isNotEmpty);
        expect(RegExp(r"^[A-Za-z ]+$").hasMatch(w.en), isTrue, reason: '${t.id}: ${w.en}');
      }
    }
  });

  test('nghe chọn luôn có đủ 3 lựa chọn sai khác hình', () {
    for (final t in enTopics) {
      for (final q in t.words) {
        final others = t.words.where((w) => w.en != q.en && w.emoji != q.emoji).length;
        expect(others, greaterThanOrEqualTo(3), reason: '${t.id}: ${q.en}');
      }
    }
  });

  test('chấm phát âm', () {
    expect(matchEnglish('Cat', 'cat'), isTrue);
    expect(matchEnglish('a cat', 'cat'), isTrue);
    expect(matchEnglish('cap', 'cat'), isFalse);
    expect(matchEnglish('2', 'two'), isTrue);
    expect(matchEnglish('to', 'two'), isTrue);
    expect(matchEnglish('for', 'four'), isTrue);
    expect(matchEnglish("what's your name", 'What is your name'), isTrue); // "whats" khác "what" nhưng đủ 3/4
    expect(matchEnglish('how are you', 'How are you'), isTrue);
    expect(matchEnglish('hello', 'How are you'), isFalse);
    expect(matchEnglish('', 'cat'), isFalse);
    expect(matchEnglish('teddy bear', 'teddy bear'), isTrue);
  });

  test('chủ đề theo lớp: lớp 1 có chào hỏi, màu, số, con vật', () {
    final ids = topicsForGrade(1).map((t) => t.id).toList();
    expect(ids, containsAll(['greetings', 'colors', 'numbers', 'animals']));
    expect(topicsForGrade(5).length, enTopics.length);
  });

  test('tiến độ: sao chủ đề', () {
    var p = const EnProgress();
    expect(p.stars(10), 0);
    p = p.withLearned(10).withScore('listen', 0.8).withScore('spell', 0.5).withScore('speak', 1);
    expect(p.stars(10), 3);
    expect(p.withScore('listen', 0.2).best['listen'], 0.8); // giữ điểm cao nhất
  });
}
