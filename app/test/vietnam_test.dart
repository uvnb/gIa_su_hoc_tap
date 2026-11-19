import 'package:cu_to_mo/features/vietnam/vietnam_content.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('3 chủ đề, mỗi chủ đề 10 thẻ, mã thẻ không trùng', () {
    expect(vnTopics.map((t) => t.id), ['history', 'geography', 'culture']);
    final ids = <String>{};
    for (final t in vnTopics) {
      expect(t.cards.length, 10, reason: t.id);
      for (final c in t.cards) {
        expect(ids.add(c.id), isTrue, reason: 'trùng mã ${c.id}');
      }
    }
  });

  test('mỗi câu đố có đúng 3 lựa chọn, không trùng, có đáp án; truyện ngắn gọn', () {
    for (final t in vnTopics) {
      for (final c in t.cards) {
        expect(c.options.length, 3, reason: c.id);
        expect(c.options.toSet().length, 3, reason: c.id);
        expect(c.options, contains(c.answer));
        expect(c.story.length, lessThan(420), reason: '${c.id}: truyện quá dài cho trẻ');
        expect(c.fact, isNotEmpty);
        expect(c.question.endsWith('?'), isTrue, reason: c.id);
      }
    }
  });

  test('"Bạn có biết?" đổi theo ngày và luôn có thẻ', () {
    final a = factOfTheDay(DateTime(2026, 11, 19));
    final b = factOfTheDay(DateTime(2026, 11, 20));
    expect(a.id, isNot(b.id));
    expect(topicOf(a).cards, contains(a));
  });
}
