/// Mô hình dữ liệu cho Góc trò chơi: điều ước gửi bố mẹ + lời ghi âm của bố mẹ.
library;

/// "Phần thưởng đặc biệt" mỗi ngày: bé đạt đủ điểm trò chơi → tự viết điều ước gửi bố mẹ.
class Wish {
  final String id;
  final String childId;
  final String day; // yyyy-MM-dd
  final String emoji; // nhãn dán bé chọn
  final String text; // điều bé tự viết / nói
  final String status; // pending | approved | later
  final String reply; // lời nhắn bố mẹ trả lời
  final bool replySeen; // Cú đã đọc lời trả lời cho bé chưa
  final int createdAt; // millisecondsSinceEpoch

  const Wish({
    required this.id,
    required this.childId,
    required this.day,
    required this.emoji,
    required this.text,
    this.status = 'pending',
    this.reply = '',
    this.replySeen = false,
    required this.createdAt,
  });

  bool get pending => status == 'pending';

  Wish copyWith({String? status, String? reply, bool? replySeen}) => Wish(
        id: id,
        childId: childId,
        day: day,
        emoji: emoji,
        text: text,
        status: status ?? this.status,
        reply: reply ?? this.reply,
        replySeen: replySeen ?? this.replySeen,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'childId': childId,
        'day': day,
        'emoji': emoji,
        'text': text,
        'status': status,
        'reply': reply,
        'replySeen': replySeen,
        'createdAt': createdAt,
      };

  factory Wish.fromMap(Map<dynamic, dynamic> m) => Wish(
        id: '${m['id']}',
        childId: '${m['childId']}',
        day: '${m['day']}',
        emoji: (m['emoji'] as String?) ?? '🎁',
        text: (m['text'] as String?) ?? '',
        status: (m['status'] as String?) ?? 'pending',
        reply: (m['reply'] as String?) ?? '',
        replySeen: (m['replySeen'] as bool?) ?? false,
        createdAt: (m['createdAt'] as int?) ?? 0,
      );
}

/// Nhãn dán gợi ý cho điều ước (bé lớp 1 chưa viết giỏi vẫn chọn được).
class WishSticker {
  final String emoji;
  final String label;
  const WishSticker(this.emoji, this.label);
}

const wishStickers = [
  WishSticker('🍦', 'Con muốn được ăn kem'),
  WishSticker('🎠', 'Con muốn đi công viên'),
  WishSticker('📖', 'Con muốn mẹ đọc truyện cho con'),
  WishSticker('🚲', 'Con muốn đạp xe cùng bố'),
  WishSticker('🧸', 'Con muốn một món đồ chơi nhỏ'),
  WishSticker('🍕', 'Con muốn ăn món con thích'),
  WishSticker('🎮', 'Con muốn thêm 15 phút chơi'),
  WishSticker('🤗', 'Con muốn được ôm thật chặt'),
];

/// Điều ước "thêm giờ chơi": bố mẹ đồng ý → tự cộng 15 phút chơi hôm nay.
const extraTimeWishEmoji = '🎮';

/// Lời ghi âm của bố mẹ (khen, động viên…) – app phát đúng lúc cho bé nghe.
class ParentVoice {
  final String id;
  final String purpose; // praise | encourage | time_up | greeting
  final String caption; // chú thích bố mẹ viết: đoạn ghi âm này để làm gì
  final String path; // file .m4a trong thư mục ứng dụng
  final String childId; // '' = dùng cho mọi bé
  final int durationMs;
  final bool enabled;
  final int createdAt;

  const ParentVoice({
    required this.id,
    required this.purpose,
    required this.caption,
    required this.path,
    this.childId = '',
    this.durationMs = 0,
    this.enabled = true,
    required this.createdAt,
  });

  ParentVoice copyWith({bool? enabled, String? caption, String? purpose, String? childId}) => ParentVoice(
        id: id,
        purpose: purpose ?? this.purpose,
        caption: caption ?? this.caption,
        path: path,
        childId: childId ?? this.childId,
        durationMs: durationMs,
        enabled: enabled ?? this.enabled,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'purpose': purpose,
        'caption': caption,
        'path': path,
        'childId': childId,
        'durationMs': durationMs,
        'enabled': enabled,
        'createdAt': createdAt,
      };

  factory ParentVoice.fromMap(Map<dynamic, dynamic> m) => ParentVoice(
        id: '${m['id']}',
        purpose: (m['purpose'] as String?) ?? 'praise',
        caption: (m['caption'] as String?) ?? '',
        path: (m['path'] as String?) ?? '',
        childId: (m['childId'] as String?) ?? '',
        durationMs: (m['durationMs'] as int?) ?? 0,
        enabled: (m['enabled'] as bool?) ?? true,
        createdAt: (m['createdAt'] as int?) ?? 0,
      );
}

/// Các thời điểm app phát lời của bố mẹ.
class VoicePurpose {
  final String id;
  final String emoji;
  final String label; // hiện cho bố mẹ
  final String when; // giải thích khi nào phát
  final List<String> examples; // gợi ý chú thích
  const VoicePurpose(this.id, this.emoji, this.label, this.when, this.examples);
}

const voicePurposes = [
  VoicePurpose('praise', '🎉', 'Khen con', 'Khi bé tự làm xong bài, đạt mục tiêu trò chơi',
      ['Mẹ khen con làm bài giỏi', 'Bố tự hào về con', 'Con giỏi quá, mẹ thưởng một cái ôm']),
  VoicePurpose('encourage', '💪', 'Động viên con', 'Khi bé gặp bài khó, bấm "Khó quá", hoặc thua trò chơi',
      ['Con cố lên, bố mẹ tin con', 'Không sao đâu, mình thử lại nhé', 'Bình tĩnh suy nghĩ nhé con']),
  VoicePurpose('time_up', '⏰', 'Nhắc nghỉ', 'Khi hết giờ chơi trong ngày',
      ['Hết giờ chơi rồi, con nghỉ mắt nhé', 'Con cất máy đi chơi với em nhé']),
  VoicePurpose('greeting', '👋', 'Lời chào', 'Khi bé mở ứng dụng lần đầu trong ngày',
      ['Chào con yêu, hôm nay học vui nhé', 'Mẹ chúc con học giỏi']),
];

VoicePurpose purposeById(String id) => voicePurposes.firstWhere((p) => p.id == id, orElse: () => voicePurposes.first);

/// Đoán mục đích từ chú thích bố mẹ gõ (bố mẹ vẫn chọn lại được).
String? guessPurpose(String caption) {
  final c = caption.toLowerCase();
  bool has(List<String> ws) => ws.any(c.contains);
  if (has(['hết giờ', 'nghỉ mắt', 'đi ngủ', 'cất máy', 'nghỉ ngơi'])) return 'time_up';
  if (has(['cố lên', 'động viên', 'không sao', 'bình tĩnh', 'thử lại', 'đừng buồn', 'khó'])) return 'encourage';
  if (has(['chào', 'buổi sáng', 'chúc con'])) return 'greeting';
  if (has(['khen', 'giỏi', 'tuyệt', 'xuất sắc', 'tự hào', 'thưởng', 'hay quá'])) return 'praise';
  return null;
}
