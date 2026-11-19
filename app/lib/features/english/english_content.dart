/// Nội dung "Đảo Tiếng Anh" – từ vựng & mẫu câu tiểu học (bám chương trình lớp 1–5:
/// chào hỏi, gia đình, trường lớp, màu sắc, con vật, đồ ăn, cơ thể, thời tiết, đồ chơi, nhà cửa, số đếm).
library;

class EnWord {
  final String emoji;
  final String en; // từ / câu tiếng Anh
  final String vi; // nghĩa tiếng Việt
  final String hint; // gợi ý đọc cho bé Việt (gần đúng)
  const EnWord(this.emoji, this.en, this.vi, [this.hint = '']);

  bool get isPhrase => en.contains(' ');

  /// Chữ cái dùng cho trò ghép chữ (chỉ từ đơn, chữ thường).
  String get spell => en.toLowerCase();
}

class EnTopic {
  final String id;
  final String emoji;
  final String en;
  final String vi;
  final int minGrade; // lớp nhỏ nhất nên học
  final List<EnWord> words;
  const EnTopic(this.id, this.emoji, this.en, this.vi, this.minGrade, this.words);

  bool get phrases => words.every((w) => w.isPhrase);
}

const enTopics = <EnTopic>[
  EnTopic('greetings', '👋', 'Hello!', 'Chào hỏi', 1, [
    EnWord('👋', 'Hello', 'Xin chào', 'hê-lâu'),
    EnWord('👋', 'Goodbye', 'Tạm biệt', 'gúd-bai'),
    EnWord('🙏', 'Thank you', 'Cảm ơn', 'thanh-kiu'),
    EnWord('😔', 'Sorry', 'Xin lỗi', 'so-ri'),
    EnWord('🌅', 'Good morning', 'Chào buổi sáng', 'gúd mo-ninh'),
    EnWord('🌙', 'Good night', 'Chúc ngủ ngon', 'gúd nai'),
    EnWord('🙂', 'How are you', 'Bạn khỏe không?', 'hao a diu'),
    EnWord('😊', 'I am fine', 'Mình khỏe', 'ai em fai'),
    EnWord('🤝', 'Nice to meet you', 'Rất vui được gặp bạn', 'nai tu mít diu'),
    EnWord('🧒', 'What is your name', 'Bạn tên là gì?', 'goát ít do nêm'),
    EnWord('🎂', 'How old are you', 'Bạn bao nhiêu tuổi?', 'hao ôld a diu'),
  ]),
  EnTopic('colors', '🎨', 'Colors', 'Màu sắc', 1, [
    EnWord('🔴', 'red', 'màu đỏ', 'ret'),
    EnWord('🔵', 'blue', 'màu xanh dương', 'blu'),
    EnWord('🟢', 'green', 'màu xanh lá', 'grin'),
    EnWord('🟡', 'yellow', 'màu vàng', 'ye-lâu'),
    EnWord('🟠', 'orange', 'màu cam', 'o-rinh'),
    EnWord('🩷', 'pink', 'màu hồng', 'pinh'),
    EnWord('🟣', 'purple', 'màu tím', 'pơ-pồ'),
    EnWord('⚫', 'black', 'màu đen', 'blách'),
    EnWord('⚪', 'white', 'màu trắng', 'goai'),
    EnWord('🟤', 'brown', 'màu nâu', 'braon'),
  ]),
  EnTopic('numbers', '🔢', 'Numbers', 'Số đếm', 1, [
    EnWord('1️⃣', 'one', 'số một', 'oan'),
    EnWord('2️⃣', 'two', 'số hai', 'tu'),
    EnWord('3️⃣', 'three', 'số ba', 'thri'),
    EnWord('4️⃣', 'four', 'số bốn', 'fo'),
    EnWord('5️⃣', 'five', 'số năm', 'faiv'),
    EnWord('6️⃣', 'six', 'số sáu', 'xích'),
    EnWord('7️⃣', 'seven', 'số bảy', 'xe-vần'),
    EnWord('8️⃣', 'eight', 'số tám', 'êt'),
    EnWord('9️⃣', 'nine', 'số chín', 'nai'),
    EnWord('🔟', 'ten', 'số mười', 'ten'),
    EnWord('🕚', 'eleven', 'số mười một', 'i-le-vần'),
    EnWord('🕛', 'twelve', 'số mười hai', 'tuelv'),
    EnWord('🎈', 'twenty', 'số hai mươi', 'tuen-ti'),
  ]),
  EnTopic('animals', '🐶', 'Animals', 'Con vật', 1, [
    EnWord('🐱', 'cat', 'con mèo', 'két'),
    EnWord('🐶', 'dog', 'con chó', 'đoóc'),
    EnWord('🐟', 'fish', 'con cá', 'phít'),
    EnWord('🐦', 'bird', 'con chim', 'bớt'),
    EnWord('🐰', 'rabbit', 'con thỏ', 'ra-bít'),
    EnWord('🐘', 'elephant', 'con voi', 'e-li-phần'),
    EnWord('🐒', 'monkey', 'con khỉ', 'măng-ki'),
    EnWord('🐯', 'tiger', 'con hổ', 'tai-gơ'),
    EnWord('🦆', 'duck', 'con vịt', 'đắc'),
    EnWord('🐔', 'chicken', 'con gà', 'chi-kần'),
    EnWord('🐮', 'cow', 'con bò', 'cao'),
    EnWord('🐷', 'pig', 'con lợn', 'pích'),
    EnWord('🐴', 'horse', 'con ngựa', 'ho-s'),
    EnWord('🦁', 'lion', 'con sư tử', 'lai-ần'),
    EnWord('🐻', 'bear', 'con gấu', 'be-ơ'),
    EnWord('🐸', 'frog', 'con ếch', 'phrooc'),
  ]),
  EnTopic('food', '🍎', 'Food', 'Đồ ăn & trái cây', 1, [
    EnWord('🍎', 'apple', 'quả táo', 'áp-pồ'),
    EnWord('🍌', 'banana', 'quả chuối', 'bơ-na-nơ'),
    EnWord('🍊', 'orange', 'quả cam', 'o-rinh'),
    EnWord('🍇', 'grapes', 'quả nho', 'grêp'),
    EnWord('🥭', 'mango', 'quả xoài', 'meng-gâu'),
    EnWord('🍉', 'watermelon', 'dưa hấu', 'goa-tơ-me-lần'),
    EnWord('🥛', 'milk', 'sữa', 'miu-k'),
    EnWord('🍞', 'bread', 'bánh mì', 'bret'),
    EnWord('🍚', 'rice', 'cơm', 'rai-s'),
    EnWord('🥚', 'egg', 'quả trứng', 'éc'),
    EnWord('🍰', 'cake', 'bánh ngọt', 'kêc'),
    EnWord('💧', 'water', 'nước', 'goa-tơ'),
  ]),
  EnTopic('family', '👨‍👩‍👧', 'Family', 'Gia đình', 2, [
    EnWord('👩', 'mother', 'mẹ', 'ma-đơ'),
    EnWord('👨', 'father', 'bố', 'pha-đơ'),
    EnWord('👧', 'sister', 'chị / em gái', 'xít-tơ'),
    EnWord('👦', 'brother', 'anh / em trai', 'bra-đơ'),
    EnWord('👵', 'grandmother', 'bà', 'gren-ma-đơ'),
    EnWord('👴', 'grandfather', 'ông', 'gren-pha-đơ'),
    EnWord('👶', 'baby', 'em bé', 'bây-bi'),
    EnWord('👨‍👩‍👧', 'family', 'gia đình', 'phe-mi-li'),
  ]),
  EnTopic('school', '🏫', 'School', 'Trường lớp', 2, [
    EnWord('🖊️', 'pen', 'bút mực', 'pen'),
    EnWord('✏️', 'pencil', 'bút chì', 'pen-xồ'),
    EnWord('📕', 'book', 'quyển sách', 'búc'),
    EnWord('📏', 'ruler', 'thước kẻ', 'ru-lơ'),
    EnWord('🧽', 'eraser', 'cục tẩy', 'i-rây-dơ'),
    EnWord('🎒', 'bag', 'cặp sách', 'béc'),
    EnWord('🪑', 'chair', 'cái ghế', 'che-ơ'),
    EnWord('🏫', 'school', 'trường học', 'xcun'),
    EnWord('👩‍🏫', 'teacher', 'cô / thầy giáo', 'ti-chơ'),
    EnWord('🧑‍🎓', 'student', 'học sinh', 'xchiu-đần'),
  ]),
  EnTopic('body', '🧍', 'My body', 'Cơ thể', 2, [
    EnWord('🗣️', 'head', 'cái đầu', 'het'),
    EnWord('👁️', 'eye', 'con mắt', 'ai'),
    EnWord('👂', 'ear', 'cái tai', 'i-ơ'),
    EnWord('👃', 'nose', 'cái mũi', 'nâu-z'),
    EnWord('👄', 'mouth', 'cái miệng', 'mao-th'),
    EnWord('✋', 'hand', 'bàn tay', 'hen-đ'),
    EnWord('🦵', 'leg', 'cái chân', 'léc'),
    EnWord('🦶', 'foot', 'bàn chân', 'phút'),
    EnWord('💇', 'hair', 'mái tóc', 'he-ơ'),
    EnWord('💪', 'arm', 'cánh tay', 'am'),
  ]),
  EnTopic('weather', '☀️', 'Weather & Nature', 'Thời tiết & thiên nhiên', 3, [
    EnWord('☀️', 'sun', 'mặt trời', 'xăn'),
    EnWord('🌙', 'moon', 'mặt trăng', 'mun'),
    EnWord('⭐', 'star', 'ngôi sao', 'xta'),
    EnWord('🌧️', 'rain', 'mưa', 'rên'),
    EnWord('☁️', 'cloud', 'đám mây', 'clao-đ'),
    EnWord('🌳', 'tree', 'cái cây', 'tri'),
    EnWord('🌸', 'flower', 'bông hoa', 'phla-ơ'),
    EnWord('🌊', 'sea', 'biển', 'xi'),
    EnWord('💨', 'wind', 'gió', 'uyn-đ'),
    EnWord('❄️', 'snow', 'tuyết', 'xnâu'),
  ]),
  EnTopic('toys', '🧸', 'Toys', 'Đồ chơi', 3, [
    EnWord('⚽', 'ball', 'quả bóng', 'bon'),
    EnWord('🪆', 'doll', 'búp bê', 'đon'),
    EnWord('🚗', 'car', 'ô tô', 'ca'),
    EnWord('🪁', 'kite', 'con diều', 'cai-t'),
    EnWord('🤖', 'robot', 'người máy', 'râu-bốt'),
    EnWord('🧸', 'teddy bear', 'gấu bông', 'te-đi be-ơ'),
    EnWord('🧩', 'puzzle', 'trò xếp hình', 'pă-dồ'),
    EnWord('🚲', 'bike', 'xe đạp', 'bai-k'),
  ]),
  EnTopic('house', '🏠', 'My house', 'Nhà của em', 4, [
    EnWord('🏠', 'house', 'ngôi nhà', 'hao-x'),
    EnWord('🛏️', 'bedroom', 'phòng ngủ', 'bét-rum'),
    EnWord('🍳', 'kitchen', 'nhà bếp', 'kít-chần'),
    EnWord('🚪', 'door', 'cửa ra vào', 'đo'),
    EnWord('🪟', 'window', 'cửa sổ', 'uyn-đâu'),
    EnWord('🛋️', 'sofa', 'ghế sô pha', 'xâu-phơ'),
    EnWord('🛁', 'bathroom', 'phòng tắm', 'bát-rum'),
    EnWord('💡', 'lamp', 'cái đèn', 'lemp'),
  ]),
];

/// Chủ đề hợp với lớp của bé (lớp lớn học được cả chủ đề lớp nhỏ).
List<EnTopic> topicsForGrade(int grade) => enTopics.where((t) => t.minGrade <= grade + 1).toList();

EnTopic topicById(String id) => enTopics.firstWhere((t) => t.id == id, orElse: () => enTopics.first);

// ---------------------------------------------------------------- so khớp phát âm
String normalizeEn(String s) => s
    .toLowerCase()
    .replaceAll('’', "'")
    // mở rộng dạng viết tắt: what's → what is, I'm → I am, you're → you are
    .replaceAllMapped(RegExp(r"([a-z])'s\b"), (m) => '${m[1]} is')
    .replaceAll("'m", ' am')
    .replaceAll("'re", ' are')
    .replaceAll("n't", ' not')
    .replaceAll("'", '')
    .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Máy nghe bé nói [heard] có khớp [target] không. Từ đơn: phải có đúng từ đó.
/// Cụm từ / câu: đủ ≥ 70% số từ theo đúng thứ tự là được (trẻ nói chưa tròn vẫn được khen).
bool matchEnglish(String heard, String target) {
  final h = normalizeEn(heard).split(' ').where((w) => w.isNotEmpty).toList();
  final t = normalizeEn(target).split(' ').where((w) => w.isNotEmpty).toList();
  if (h.isEmpty || t.isEmpty) return false;
  // máy hay viết số bằng chữ số, hoặc nghe ra từ đồng âm
  const alike = {
    'one': ['1', 'won'],
    'two': ['2', 'to', 'too'],
    'three': ['3'],
    'four': ['4', 'for'],
    'five': ['5'],
    'six': ['6'],
    'seven': ['7'],
    'eight': ['8', 'ate'],
    'nine': ['9'],
    'ten': ['10'],
    'eleven': ['11'],
    'twelve': ['12'],
    'twenty': ['20'],
    'eye': ['i', 'aye'],
    'sea': ['see'],
    'pear': ['pair'],
    'i': ['eye'],
    'red': ['read'],
    'sun': ['son'],
    'night': ['knight'],
    'hair': ['hare'],
    'flower': ['flour'],
  };
  bool same(String heardW, String targetW) => heardW == targetW || (alike[targetW]?.contains(heardW) ?? false);
  if (t.length == 1) return h.any((w) => same(w, t.first));
  // cụm từ: đếm số từ đích xuất hiện theo đúng thứ tự (bỏ qua từ máy nghe sót)
  var found = 0, pos = 0;
  for (final tw in t) {
    for (var k = pos; k < h.length; k++) {
      if (same(h[k], tw)) {
        found++;
        pos = k + 1;
        break;
      }
    }
  }
  return found / t.length >= 0.7;
}
