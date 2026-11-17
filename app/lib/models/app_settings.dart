/// Cài đặt do phụ huynh chỉnh trong Góc phụ huynh (FR-62, FR-63, FR-50..52).
class AppSettings {
  final double ttsRate; // tốc độ đọc (thang 0..1 của Android) ⚠️ VERIFY nghe thử trên máy
  final double ttsPitch;
  final int breakMinutes; // FR-50: nghỉ giải lao sau N phút
  final int dailyLimitMinutes; // FR-51: 0 = không giới hạn
  final String bedtime; // FR-52: "HH:mm" hoặc "" = tắt
  final String wakeTime; // giờ được dùng lại buổi sáng
  final bool soundEffects;
  final String provider; // "" = theo server | anthropic | openai
  final String tier; // tiet_kiem | can_bang | thong_minh
  final String serverUrl; // "" = dùng API_BASE_URL lúc build
  final String voiceName; // giọng TTS tiếng Việt trên máy ("" = mặc định)
  final String voicePreset; // kiểu giọng: cu_con | co_giao | ban_nho | ong_cu | "" (tự chỉnh)

  const AppSettings({
    this.ttsRate = 0.42,
    this.ttsPitch = 1.35,
    this.breakMinutes = 20,
    this.dailyLimitMinutes = 45,
    this.bedtime = '21:00',
    this.wakeTime = '06:00',
    this.soundEffects = true,
    this.provider = '',
    this.tier = 'can_bang',
    this.serverUrl = '',
    this.voiceName = '',
    this.voicePreset = 'cu_con',
  });

  AppSettings copyWith({
    double? ttsRate,
    double? ttsPitch,
    int? breakMinutes,
    int? dailyLimitMinutes,
    String? bedtime,
    String? wakeTime,
    bool? soundEffects,
    String? provider,
    String? tier,
    String? serverUrl,
    String? voiceName,
    String? voicePreset,
  }) =>
      AppSettings(
        ttsRate: ttsRate ?? this.ttsRate,
        ttsPitch: ttsPitch ?? this.ttsPitch,
        breakMinutes: breakMinutes ?? this.breakMinutes,
        dailyLimitMinutes: dailyLimitMinutes ?? this.dailyLimitMinutes,
        bedtime: bedtime ?? this.bedtime,
        wakeTime: wakeTime ?? this.wakeTime,
        soundEffects: soundEffects ?? this.soundEffects,
        provider: provider ?? this.provider,
        tier: tier ?? this.tier,
        serverUrl: serverUrl ?? this.serverUrl,
        voiceName: voiceName ?? this.voiceName,
        voicePreset: voicePreset ?? this.voicePreset,
      );

  Map<String, dynamic> toMap() => {
        'ttsRate': ttsRate,
        'ttsPitch': ttsPitch,
        'breakMinutes': breakMinutes,
        'dailyLimitMinutes': dailyLimitMinutes,
        'bedtime': bedtime,
        'wakeTime': wakeTime,
        'soundEffects': soundEffects,
        'provider': provider,
        'tier': tier,
        'serverUrl': serverUrl,
        'voiceName': voiceName,
        'voicePreset': voicePreset,
      };

  factory AppSettings.fromMap(Map<dynamic, dynamic>? m) {
    if (m == null) return const AppSettings();
    const d = AppSettings();
    return AppSettings(
      ttsRate: (m['ttsRate'] as num?)?.toDouble() ?? d.ttsRate,
      ttsPitch: (m['ttsPitch'] as num?)?.toDouble() ?? d.ttsPitch,
      breakMinutes: (m['breakMinutes'] as int?) ?? d.breakMinutes,
      dailyLimitMinutes: (m['dailyLimitMinutes'] as int?) ?? d.dailyLimitMinutes,
      bedtime: (m['bedtime'] as String?) ?? d.bedtime,
      wakeTime: (m['wakeTime'] as String?) ?? d.wakeTime,
      soundEffects: (m['soundEffects'] as bool?) ?? d.soundEffects,
      provider: (m['provider'] as String?) ?? d.provider,
      tier: (m['tier'] as String?) ?? d.tier,
      serverUrl: (m['serverUrl'] as String?) ?? d.serverUrl,
      voiceName: (m['voiceName'] as String?) ?? d.voiceName,
      voicePreset: (m['voicePreset'] as String?) ?? '',
    );
  }

  /// FR-52: có đang trong giờ ngủ không.
  bool isBedtime(DateTime now) {
    final bed = _parse(bedtime), wake = _parse(wakeTime);
    if (bed == null) return false;
    final minutes = now.hour * 60 + now.minute;
    final w = wake ?? 6 * 60;
    if (bed > w) return minutes >= bed || minutes < w; // ví dụ 21:00 → 06:00
    return minutes >= bed && minutes < w;
  }

  static int? _parse(String hhmm) {
    final p = hhmm.split(':');
    if (p.length != 2) return null;
    final h = int.tryParse(p[0]), m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }
}

/// Kiểu giọng dễ thương cho trẻ nhỏ: chỉnh cao độ + tốc độ của giọng TTS (miễn phí, chạy trên máy).
class VoicePreset {
  final String id;
  final String emoji;
  final String label;
  final double rate;
  final double pitch;
  const VoicePreset(this.id, this.emoji, this.label, this.rate, this.pitch);
}

const voicePresets = [
  VoicePreset('cu_con', '🐣', 'Cú con dễ thương', 0.42, 1.35),
  VoicePreset('co_giao', '🌸', 'Cô giáo dịu dàng', 0.44, 1.12),
  VoicePreset('ban_nho', '🎈', 'Bạn nhỏ vui vẻ', 0.5, 1.55),
  VoicePreset('ong_cu', '🦉', 'Ông Cú hiền từ', 0.4, 0.88),
];
