/// Mô hình dữ liệu nhận từ backend. Không có trường đáp án – backend không bao giờ gửi.
class ProblemBrief {
  final int id;
  final String text;
  const ProblemBrief(this.id, this.text);

  factory ProblemBrief.fromJson(Map<String, dynamic> j) =>
      ProblemBrief((j['id'] as num).toInt(), j['text'] as String? ?? '');
}

class OwlLine {
  final String say;
  final String mood;
  const OwlLine(this.say, this.mood);

  factory OwlLine.fromJson(Map<String, dynamic>? j) =>
      OwlLine((j?['say'] as String?) ?? '', (j?['mood'] as String?) ?? 'asking');
}

class StartResult {
  final String? sessionId;
  final bool readable;
  final String problemDisplay;
  final List<ProblemBrief> problems;
  final bool needsSelection;
  final String subject;
  final String mode;
  final OwlLine owl;
  final String state;

  const StartResult({
    required this.sessionId,
    required this.readable,
    required this.problemDisplay,
    required this.problems,
    required this.needsSelection,
    required this.subject,
    required this.mode,
    required this.owl,
    required this.state,
  });

  factory StartResult.fromJson(Map<String, dynamic> j) => StartResult(
        sessionId: j['session_id'] as String?,
        readable: j['readable'] as bool? ?? false,
        problemDisplay: j['problem_display'] as String? ?? '',
        problems: ((j['problems'] as List?) ?? [])
            .map((e) => ProblemBrief.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        needsSelection: j['needs_selection'] as bool? ?? false,
        subject: j['subject'] as String? ?? 'math',
        mode: j['mode'] as String? ?? 'exercise',
        owl: OwlLine.fromJson(j['owl'] == null ? null : Map<String, dynamic>.from(j['owl'] as Map)),
        state: j['state'] as String? ?? 'confirming',
      );
}

class TurnResult {
  final OwlLine owl;
  final int hintLevel;
  final String state;
  final int starsEarned;
  final List<Map<String, dynamic>> uiActions;
  final String funQuestion;

  const TurnResult({
    required this.owl,
    required this.hintLevel,
    required this.state,
    required this.starsEarned,
    required this.uiActions,
    required this.funQuestion,
  });

  factory TurnResult.fromJson(Map<String, dynamic> j) => TurnResult(
        owl: OwlLine.fromJson(j['owl'] == null ? null : Map<String, dynamic>.from(j['owl'] as Map)),
        hintLevel: (j['hint_level'] as num?)?.toInt() ?? 0,
        state: j['state'] as String? ?? 'tutoring',
        starsEarned: (j['stars_earned'] as num?)?.toInt() ?? 0,
        uiActions: ((j['ui_actions'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList(),
        funQuestion: j['fun_question'] as String? ?? '',
      );
}

/// Công cụ trực quan do backend yêu cầu mở (ui_action show_manipulative). Chỉ chứa số trong đề.
class ManipulativeSpec {
  final String tool; // sticks | dots | base10 | clock | ruler | fraction
  final num a;
  final num b;
  final String op; // + - × :
  const ManipulativeSpec(this.tool, this.a, this.b, this.op);

  factory ManipulativeSpec.fromAction(Map<String, dynamic> a) => ManipulativeSpec(
        a['tool'] as String? ?? 'sticks',
        (a['a'] as num?) ?? 0,
        (a['b'] as num?) ?? 0,
        a['op'] as String? ?? '+',
      );
}

/// Cách mở màn gia sư.
class TutorLaunch {
  final List<int>? jpeg; // ảnh đã nén
  final String questionText;
  final String subject;
  final bool fromMysteryBox;
  const TutorLaunch({this.jpeg, this.questionText = '', this.subject = 'math', this.fromMysteryBox = false});
}

class ParentReport {
  final int minutes;
  final int problemsTotal;
  final int solvedSelf;
  final int parked;
  final int stars;
  final int safetyAlerts;
  final List<Map<String, dynamic>> hardTypes;
  final List<Map<String, dynamic>> parkedItems;
  final List<Map<String, dynamic>> recent;
  final List<Map<String, dynamic>> byDay;
  final int friendTurns; // 💛 Góc tâm sự: số lượt bé trò chuyện (không có nội dung)
  final int friendDays;
  final List<String> friendAlerts; // self_harm | abuse | danger

  const ParentReport({
    required this.minutes,
    required this.problemsTotal,
    required this.solvedSelf,
    required this.parked,
    required this.stars,
    required this.safetyAlerts,
    required this.hardTypes,
    required this.parkedItems,
    required this.recent,
    required this.byDay,
    this.friendTurns = 0,
    this.friendDays = 0,
    this.friendAlerts = const [],
  });

  static List<Map<String, dynamic>> _list(dynamic v) =>
      ((v as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

  factory ParentReport.fromJson(Map<String, dynamic> j) => ParentReport(
        minutes: (j['minutes'] as num?)?.toInt() ?? 0,
        problemsTotal: (j['problems_total'] as num?)?.toInt() ?? 0,
        solvedSelf: (j['solved_self'] as num?)?.toInt() ?? 0,
        parked: (j['parked'] as num?)?.toInt() ?? 0,
        stars: (j['stars'] as num?)?.toInt() ?? 0,
        safetyAlerts: (j['safety_alerts'] as num?)?.toInt() ?? 0,
        hardTypes: _list(j['hard_types']),
        parkedItems: _list(j['parked_items']),
        recent: _list(j['recent']),
        byDay: _list(j['by_day']),
        friendTurns: (j['friend_turns'] as num?)?.toInt() ?? 0,
        friendDays: (j['friend_days'] as num?)?.toInt() ?? 0,
        friendAlerts: ((j['friend_alerts'] as List?) ?? []).map((e) => '$e').toList(),
      );
}

/// Câu trả lời của Cú trong Góc tâm sự.
class FriendReply {
  final String say;
  final String owlMood;
  final bool suggestBreathing;
  final String crisis; // self_harm | abuse | ''
  final String hotline;
  const FriendReply(this.say, this.owlMood, this.suggestBreathing, this.crisis, this.hotline);

  factory FriendReply.fromJson(Map<String, dynamic> j) => FriendReply(
        '${j['say'] ?? ''}',
        '${j['owl_mood'] ?? 'listening'}',
        j['suggest_breathing'] == true,
        '${j['crisis'] ?? ''}',
        '${j['hotline'] ?? ''}',
      );
}
