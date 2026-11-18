import 'dart:math';

/// Kho từ cho trò "Cú Từ Ngữ": đọc to từ hiện trên màn hình, hoặc điền từ còn thiếu
/// trong thành ngữ / tục ngữ. Độ khó tăng theo cấp và lớp của bé.
class WordChallenge {
  final String type; // read | fill
  final String prompt; // read: từ cần đọc · fill: câu có chỗ trống "___"
  final String answer; // từ đúng
  final List<String> options; // các lựa chọn để chạm (luôn có đáp án)
  final String full; // câu đầy đủ (fill) – hiện sau khi chơi để bé học
  const WordChallenge({
    required this.type,
    required this.prompt,
    required this.answer,
    required this.options,
    this.full = '',
  });

  bool get isRead => type == 'read';

  /// Câu Cú đọc cho bé nghe (chỗ trống đọc là "gì").
  String get spokenPrompt => isRead ? prompt : '${prompt.replaceAll('___', 'gì')}?';
}

/// Từ đọc to theo bậc: 0 một tiếng · 1 hai tiếng · 2 vần khó · 3 câu ngắn.
const readTiers = <List<String>>[
  [
    'mèo', 'cá', 'gà', 'bò', 'hoa', 'lá', 'mẹ', 'bố', 'sao', 'mưa', 'nhà', 'xe', 'bé', 'cây', 'quả',
    'trăng', 'nắng', 'gió', 'vở', 'bút', 'thỏ', 'voi', 'cua', 'nho', 'khế', 'bàn', 'ghế', 'mây', 'biển', 'núi',
  ],
  [
    'con mèo', 'quả cam', 'cái bàn', 'ông trăng', 'bông hoa', 'cầu vồng', 'trường học', 'cô giáo', 'bạn bè',
    'cái cặp', 'quyển vở', 'con voi', 'mặt trời', 'đám mây', 'con thỏ', 'chăm chỉ', 'máy bay', 'xe đạp',
    'búp bê', 'quả bóng', 'cây bút', 'bầu trời', 'hạt mưa', 'gia đình', 'ông bà', 'sân trường', 'con cá',
  ],
  [
    'nghỉ ngơi', 'khúc khích', 'rực rỡ', 'lấp lánh', 'xinh xắn', 'nguệch ngoạc', 'quả chuối', 'nghiêng ngả',
    'luyện tập', 'thướt tha', 'líu lo', 'véo von', 'ríu rít', 'chim sơn ca', 'cánh đồng lúa', 'khăn quàng đỏ',
    'chiếc thuyền', 'quyển truyện', 'giọt sương', 'ngoan ngoãn', 'thong thả', 'khuôn mặt', 'huơ tay',
  ],
  [
    'Em yêu trường em', 'Mẹ đi chợ về', 'Bé học bài chăm chỉ', 'Trời hôm nay rất đẹp', 'Cú Tò Mò rất thông minh',
    'Em giúp mẹ quét nhà', 'Chú mèo nằm sưởi nắng', 'Hoa phượng nở đỏ rực', 'Bầu trời xanh trong vắt',
    'Em yêu bố mẹ nhiều lắm', 'Chim hót líu lo trên cành', 'Bạn bè cùng nhau học tập',
  ],
];

class Proverb {
  final String text; // có "___"
  final String answer;
  final List<String> wrong;
  final bool easy;
  const Proverb(this.text, this.answer, this.wrong, {this.easy = false});
  String get full => text.replaceAll('___', answer);
}

/// Thành ngữ, tục ngữ, ca dao quen thuộc ở tiểu học.
const proverbs = <Proverb>[
  Proverb('Uống nước nhớ ___', 'nguồn', ['sông', 'mưa'], easy: true),
  Proverb('Lá lành đùm lá ___', 'rách', ['xanh', 'vàng'], easy: true),
  Proverb('Chị ngã em ___', 'nâng', ['cười', 'chạy'], easy: true),
  Proverb('Nước chảy đá ___', 'mòn', ['vỡ', 'trôi'], easy: true),
  Proverb('Ở hiền gặp ___', 'lành', ['mưa', 'xa'], easy: true),
  Proverb('Có chí thì ___', 'nên', ['giàu', 'mệt'], easy: true),
  Proverb('Tre già măng ___', 'mọc', ['non', 'gãy'], easy: true),
  Proverb('Ăn chậm nhai ___', 'kĩ', ['nhanh', 'to'], easy: true),
  Proverb('Chậm mà ___', 'chắc', ['nhanh', 'vui'], easy: true),
  Proverb('Kiến tha lâu cũng đầy ___', 'tổ', ['nhà', 'hang'], easy: true),
  Proverb('Ăn quả nhớ kẻ ___ cây', 'trồng', ['hái', 'chặt'], easy: true),
  Proverb('Anh em như thể tay ___', 'chân', ['mắt', 'vai'], easy: true),
  Proverb('Trâu chậm uống nước ___', 'đục', ['trong', 'sạch'], easy: true),
  Proverb('Ăn vóc học ___', 'hay', ['giỏi', 'nhiều'], easy: true),
  Proverb('Có công mài sắt, có ngày nên ___', 'kim', ['dao', 'búa']),
  Proverb('Một cây làm chẳng nên non, ba cây chụm lại nên hòn núi ___', 'cao', ['to', 'xanh']),
  Proverb('Tốt gỗ hơn tốt ___ sơn', 'nước', ['màu', 'lớp']),
  Proverb('Gần mực thì đen, gần đèn thì ___', 'rạng', ['tối', 'nóng']),
  Proverb('Học ăn, học nói, học gói, học ___', 'mở', ['buộc', 'cắt']),
  Proverb('Thương người như thể thương ___', 'thân', ['nhà', 'cây']),
  Proverb('Không thầy đố mày làm ___', 'nên', ['giàu', 'vui']),
  Proverb('Đi một ngày đàng, học một sàng ___', 'khôn', ['gạo', 'ngô']),
  Proverb('Muốn biết phải hỏi, muốn giỏi phải ___', 'học', ['chơi', 'ngủ']),
  Proverb('Một con ngựa đau, cả tàu bỏ ___', 'cỏ', ['cơm', 'chạy']),
  Proverb('Tiên học lễ, hậu học ___', 'văn', ['vẽ', 'hát']),
  Proverb('Lời chào cao hơn mâm ___', 'cỗ', ['bàn', 'gạo']),
  Proverb('Thất bại là mẹ thành ___', 'công', ['tích', 'phố']),
  Proverb('Chim có tổ, người có ___', 'tông', ['nhà', 'quê']),
  Proverb('Đói cho sạch, rách cho ___', 'thơm', ['đẹp', 'mới']),
  Proverb('Bán anh em xa, mua láng giềng ___', 'gần', ['xa', 'mới']),
  Proverb('Một miếng khi đói bằng một gói khi ___', 'no', ['khát', 'buồn']),
  Proverb('Công cha như núi Thái Sơn, nghĩa mẹ như nước trong ___ chảy ra', 'nguồn', ['sông', 'suối']),
  Proverb('Cái nết đánh chết cái ___', 'đẹp', ['xấu', 'hay']),
  Proverb('Mưa dầm thấm ___', 'lâu', ['nhanh', 'xa']),
];

/// Bậc từ đọc to theo cấp + lớp.
int readTierFor(int grade, int level) => min(3, max(0, level - 1 + (grade >= 3 ? 1 : 0) + (grade >= 5 ? 1 : 0)));

/// Tỉ lệ câu "điền từ" (thành ngữ, tục ngữ) theo lớp và cấp.
double proverbChance(int grade, int level) {
  if (grade <= 1) return level >= 3 ? 0.25 : 0;
  if (grade == 2) return level >= 2 ? 0.35 : 0.2;
  return 0.45;
}

/// Tạo thử thách tiếp theo, tránh lặp các mục trong [recent].
WordChallenge nextChallenge({required int grade, required int level, required Random rnd, Set<String> recent = const {}}) {
  if (rnd.nextDouble() < proverbChance(grade, level)) {
    final pool = proverbs.where((p) => (grade >= 3 || level >= 4 || p.easy) && !recent.contains(p.text)).toList();
    if (pool.isNotEmpty) {
      final p = pool[rnd.nextInt(pool.length)];
      final opts = [p.answer, ...p.wrong]..shuffle(rnd);
      return WordChallenge(type: 'fill', prompt: p.text, answer: p.answer, options: opts, full: p.full);
    }
  }
  final tier = readTierFor(grade, level);
  final words = readTiers[tier];
  var pool = words.where((w) => !recent.contains(w)).toList();
  if (pool.isEmpty) pool = words;
  final w = pool[rnd.nextInt(pool.length)];
  final others = (words.where((x) => x != w).toList()..shuffle(rnd)).take(2);
  final opts = [w, ...others]..shuffle(rnd);
  return WordChallenge(type: 'read', prompt: w, answer: w, options: opts);
}

// ---------------------------------------------------------------- so khớp giọng nói
const _from = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
const _to = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';

String normalizeVi(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String stripDiacritics(String s) {
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = _from.indexOf(ch);
    b.write(i >= 0 ? _to[i] : ch);
  }
  return b.toString();
}

enum SpeechMatch { none, close, exact }

/// So khớp điều bé nói với từ cần đọc. exact = đúng cả dấu; close = đúng âm, lệch dấu
/// (máy nghe trẻ nhỏ hay nhầm dấu – vẫn cho qua để bé không nản).
SpeechMatch matchSpeech(String heard, String target) {
  final h = normalizeVi(heard), t = normalizeVi(target);
  if (h.isEmpty || t.isEmpty) return SpeechMatch.none;
  if (' $h '.contains(' $t ')) return SpeechMatch.exact;
  final hs = stripDiacritics(h).split(' '), ts = stripDiacritics(t).split(' ');
  if (' ${hs.join(' ')} '.contains(' ${ts.join(' ')} ')) return SpeechMatch.close;
  // câu dài: đủ ≥ 80% số tiếng theo đúng thứ tự là được
  if (ts.length >= 4) {
    var i = 0;
    for (final w in hs) {
      if (i < ts.length && w == ts[i]) i++;
    }
    if (i / ts.length >= 0.8) return SpeechMatch.close;
  }
  return SpeechMatch.none;
}
