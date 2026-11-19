import 'dart:typed_data';

import 'package:cu_to_mo/core/neural_tts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ký hiệu toán đọc thành chữ', () {
    expect(normalizeVietnamese('15 + 6 = 21'), '15 cộng 6 bằng 21');
    expect(normalizeVietnamese('15 - 6 = ?'), '15 trừ 6 bằng ?');
    expect(normalizeVietnamese('15-6=9'), '15 trừ 6 bằng 9');
    expect(normalizeVietnamese('5 × 3'), '5 nhân 3');
    expect(normalizeVietnamese('5 x 3'), '5 nhân 3');
    expect(normalizeVietnamese('12 : 3 = 4'), '12 chia 3 bằng 4');
    expect(normalizeVietnamese('3/4 cái bánh'), '3 phần 4 cái bánh');
    expect(normalizeVietnamese('1,5 kg'), '1 phẩy 5 ki-lô-gam');
    expect(normalizeVietnamese('1.000.000 đ'), '1000000 đồng');
    expect(normalizeVietnamese('8 > 5'), '8 lớn hơn 5');
    expect(normalizeVietnamese('dài 12 cm'), 'dài 12 xăng-ti-mét');
    expect(normalizeVietnamese('50%'), '50 phần trăm');
  });

  test('không đọc nhầm câu thường', () {
    expect(normalizeVietnamese('Câu 1: Mẹ có 5 quả cam'), 'Câu 1: Mẹ có 5 quả cam');
    expect(normalizeVietnamese('lúc 10:30'), 'lúc 10:30');
    expect(normalizeVietnamese('lớp 2-3 tuổi'), 'lớp 2-3 tuổi');
    expect(normalizeVietnamese('5 mét'), '5 mét');
    expect(normalizeVietnamese('**Giỏi lắm!**'), 'Giỏi lắm!');
  });

  test('tách câu để đọc liền mạch', () {
    final parts = splitSentences('Chào bạn nhỏ! Tớ là Cú Tò Mò. Hôm nay mình cùng học nhé.');
    expect(parts, ['Chào bạn nhỏ!', 'Tớ là Cú Tò Mò.', 'Hôm nay mình cùng học nhé.']);
    expect(splitSentences('Giỏi quá!'), ['Giỏi quá!']);
    expect(splitSentences('  ...  '), isEmpty);
    expect(splitSentences('Số 1.5 nhé, rồi bạn nghĩ tiếp.'), ['Số 1.5 nhé, rồi bạn nghĩ tiếp.']);
  });

  test('tên file đệm ổn định, khác nhau cho câu khác nhau', () {
    expect(cacheKey('xin chào'), cacheKey('xin chào'));
    expect(cacheKey('xin chào'), isNot(cacheKey('xin chao')));
  });

  test('WAV đúng định dạng và nâng cao độ rút ngắn âm thanh', () {
    final s = Float32List.fromList(List.generate(22050, (i) => (i % 100) / 100 - 0.5));
    final w = wavBytes(s, 22050);
    expect(String.fromCharCodes(w.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(w.sublist(8, 12)), 'WAVE');
    expect(w.length, 44 + (22050 + 1323) * 2);
    expect(resample(s, 1.1).length, (22050 / 1.1).floor());
    expect(identical(resample(s, 1.0), s), isTrue);
  });
}
