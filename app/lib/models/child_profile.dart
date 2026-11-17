/// Hồ sơ bé (FR-02): chỉ biệt danh, lớp, avatar. KHÔNG có tên thật, ngày sinh, ảnh mặt, địa chỉ.
class ChildProfile {
  final String id;
  final String nickname;
  final int grade; // 1..5
  final String avatar; // emoji
  final int stars;

  const ChildProfile({
    required this.id,
    required this.nickname,
    required this.grade,
    required this.avatar,
    this.stars = 0,
  });

  ChildProfile copyWith({String? nickname, int? grade, String? avatar, int? stars}) => ChildProfile(
        id: id,
        nickname: nickname ?? this.nickname,
        grade: grade ?? this.grade,
        avatar: avatar ?? this.avatar,
        stars: stars ?? this.stars,
      );

  Map<String, dynamic> toMap() =>
      {'id': id, 'nickname': nickname, 'grade': grade, 'avatar': avatar, 'stars': stars};

  factory ChildProfile.fromMap(Map<dynamic, dynamic> m) => ChildProfile(
        id: m['id'] as String,
        nickname: (m['nickname'] as String?) ?? 'bạn',
        grade: (m['grade'] as int?) ?? 1,
        avatar: (m['avatar'] as String?) ?? '🐱',
        stars: (m['stars'] as int?) ?? 0,
      );

  /// FR-41: Cú lớn lên theo số sao – trứng → cú con → cú biết bay → cú thông thái.
  int get owlStage {
    if (stars >= 300) return 3;
    if (stars >= 120) return 2;
    if (stars >= 30) return 1;
    return 0;
  }

  static const stageThresholds = [0, 30, 120, 300];
  static const stageNames = ['Trứng Cú', 'Cú con', 'Cú biết bay', 'Cú thông thái'];

  /// Tiến độ tới giai đoạn kế tiếp (0..1).
  double get stageProgress {
    final s = owlStage;
    if (s >= 3) return 1;
    final lo = stageThresholds[s], hi = stageThresholds[s + 1];
    return ((stars - lo) / (hi - lo)).clamp(0, 1).toDouble();
  }
}

const avatarChoices = ['🐱', '🐶', '🐰', '🦊', '🐼', '🐸', '🐯', '🐵', '🐨', '🦁', '🐧', '🦄'];
