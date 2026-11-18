import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../../models/tutor_models.dart';

enum TutorPhase { loading, unreadable, offline, error, picking, confirming, tutoring, solved, explaining, parked }

class Bubble {
  final bool fromOwl;
  final String text;
  const Bubble(this.fromOwl, this.text);
}

class TutorState {
  final TutorPhase phase;
  final String? sessionId;
  final String problem;
  final List<ProblemBrief> problems;
  final Set<int> doneIds;
  final int? currentId;
  final String subject;
  final String mode;
  final List<Bubble> bubbles;
  final int hintLevel;
  final String mood;
  final bool busy;
  final int starsThisSession;
  final ManipulativeSpec? tool;
  final bool numberPad;
  final List<String> choices;
  final String funQuestion;
  final int celebrateTick;
  final int scratchTick;
  final bool breakSuggested;
  final String message;

  const TutorState({
    this.phase = TutorPhase.loading,
    this.sessionId,
    this.problem = '',
    this.problems = const [],
    this.doneIds = const {},
    this.currentId,
    this.subject = 'math',
    this.mode = 'exercise',
    this.bubbles = const [],
    this.hintLevel = 0,
    this.mood = 'thinking',
    this.busy = false,
    this.starsThisSession = 0,
    this.tool,
    this.numberPad = false,
    this.choices = const [],
    this.funQuestion = '',
    this.celebrateTick = 0,
    this.scratchTick = 0,
    this.breakSuggested = false,
    this.message = '',
  });

  TutorState copyWith({
    TutorPhase? phase,
    String? sessionId,
    String? problem,
    List<ProblemBrief>? problems,
    Set<int>? doneIds,
    int? currentId,
    String? subject,
    String? mode,
    List<Bubble>? bubbles,
    int? hintLevel,
    String? mood,
    bool? busy,
    int? starsThisSession,
    ManipulativeSpec? tool,
    bool clearTool = false,
    bool? numberPad,
    List<String>? choices,
    String? funQuestion,
    int? celebrateTick,
    int? scratchTick,
    bool? breakSuggested,
    String? message,
  }) =>
      TutorState(
        phase: phase ?? this.phase,
        sessionId: sessionId ?? this.sessionId,
        problem: problem ?? this.problem,
        problems: problems ?? this.problems,
        doneIds: doneIds ?? this.doneIds,
        currentId: currentId ?? this.currentId,
        subject: subject ?? this.subject,
        mode: mode ?? this.mode,
        bubbles: bubbles ?? this.bubbles,
        hintLevel: hintLevel ?? this.hintLevel,
        mood: mood ?? this.mood,
        busy: busy ?? this.busy,
        starsThisSession: starsThisSession ?? this.starsThisSession,
        tool: clearTool ? null : (tool ?? this.tool),
        numberPad: numberPad ?? this.numberPad,
        choices: choices ?? this.choices,
        funQuestion: funQuestion ?? this.funQuestion,
        celebrateTick: celebrateTick ?? this.celebrateTick,
        scratchTick: scratchTick ?? this.scratchTick,
        breakSuggested: breakSuggested ?? this.breakSuggested,
        message: message ?? this.message,
      );

  bool get hasMoreProblems => problems.any((p) => !doneIds.contains(p.id) && p.id != currentId);

  /// Số thứ tự câu hiện tại (hiển thị "Câu N").
  int get problemNumber {
    final i = problems.indexWhere((p) => p.id == currentId);
    return i >= 0 ? i + 1 : 1;
  }
}

/// Điều phối phiên gia sư phía app. Mọi quyết định sư phạm & đáp án nằm ở backend.
class TutorController extends StateNotifier<TutorState> {
  TutorController(this._ref) : super(const TutorState());
  final Ref _ref;
  bool _funShown = false; // FR-45: tối đa 1 lần/phiên

  ApiClient get _api => _ref.read(apiProvider);

  Future<void> _say(String text) => _ref.read(ttsProvider).say(text);

  void _owl(String text, String mood, {TutorPhase? phase}) {
    state = state.copyWith(bubbles: [...state.bubbles, Bubble(true, text)], mood: mood, phase: phase, busy: false);
  }

  // ------------------------------------------------------------------ bắt đầu
  Future<void> launch(TutorLaunch l) async {
    final child = _ref.read(activeChildProvider);
    final settings = _ref.read(settingsProvider);
    state = TutorState(subject: l.subject, mood: 'thinking', busy: true, phase: TutorPhase.loading);
    final deviceId = await _ref.read(deviceServiceProvider).ensureRegistered() ?? '';
    try {
      final r = await _api.startSession(
        jpeg: l.jpeg == null ? null : Uint8List.fromList(l.jpeg!),
        questionText: l.questionText,
        grade: child?.grade ?? 1,
        subject: l.subject,
        nickname: child?.nickname ?? 'bạn',
        deviceId: deviceId,
        childId: child?.id ?? '',
        provider: settings.provider,
        tier: settings.tier,
      );
      _applyStart(r);
    } on ApiOffline {
      _offline();
    } on ApiError catch (e) {
      final msg = e.status == 429 ? e.message : 'Cú đang bận một chút. Mình thử lại sau nhé!';
      _owl(msg, 'encouraging', phase: TutorPhase.error);
      _say(msg);
    }
  }

  void _offline() {
    const msg = 'Ối, mạng đang nghỉ mất rồi! Mình luyện tập với Cú không cần mạng nhé?';
    _owl(msg, 'encouraging', phase: TutorPhase.offline);
    _say(msg);
  }

  void _applyStart(StartResult r) {
    if (!r.readable || r.sessionId == null) {
      _owl(r.owl.say, 'encouraging', phase: TutorPhase.unreadable);
      _say(r.owl.say);
      return;
    }
    final phase = switch (r.state) {
      'selecting' => TutorPhase.picking,
      'tutoring' => TutorPhase.tutoring,
      _ => TutorPhase.confirming,
    };
    state = state.copyWith(
      sessionId: r.sessionId,
      problem: r.problemDisplay,
      problems: r.problems,
      currentId: r.problems.length == 1 ? r.problems.first.id : null,
      subject: r.subject,
      mode: r.mode,
      hintLevel: 0,
      clearTool: true,
      choices: const [],
      bubbles: [Bubble(true, r.owl.say)],
      mood: r.owl.mood,
      phase: phase,
      busy: false,
    );
    _say(r.owl.say);
  }

  /// FR-12: bé chạm chọn câu.
  Future<void> pickProblem(int id) async {
    final sid = state.sessionId;
    if (sid == null || state.busy) return;
    state = state.copyWith(busy: true, mood: 'thinking');
    try {
      final r = await _api.selectProblem(sid, id);
      state = state.copyWith(
        problem: r.problemDisplay,
        currentId: id,
        mode: r.mode,
        hintLevel: 0,
        clearTool: true,
        choices: const [],
        numberPad: false,
        bubbles: [Bubble(true, r.owl.say)],
        mood: 'asking',
        phase: TutorPhase.confirming,
        busy: false,
      );
      _say(r.owl.say);
    } on ApiOffline {
      _offline();
    } on ApiError {
      _owl('Cú chưa mở được câu này, bạn chọn lại nhé!', 'encouraging');
    }
  }

  /// FR-15: "Đúng rồi" → Cú bắt đầu hỏi gợi mở.
  Future<void> confirmProblem() async {
    final sid = state.sessionId;
    if (sid == null || state.busy) return;
    state = state.copyWith(busy: true, mood: 'thinking');
    try {
      _applyTurn(await _api.confirm(sid));
    } on ApiOffline {
      _offline();
    } on ApiError {
      _owl('Cú hơi chậm một chút. Bạn bấm lại nhé!', 'encouraging', phase: TutorPhase.confirming);
    }
  }

  /// "Chưa đúng" → chụp lại hoặc nói lại đề.
  void rejectProblem() {
    const msg = 'Không sao! Mình chụp lại hoặc đọc đề cho Cú nghe nhé.';
    _owl(msg, 'encouraging', phase: TutorPhase.unreadable);
    _say(msg);
  }

  // ------------------------------------------------------------------ vòng gia sư
  Future<void> childSays(String text, {String mode = 'voice', String? display}) async {
    final sid = state.sessionId;
    final t = text.trim();
    if (sid == null || state.busy) return;
    if (t.isEmpty && mode != 'too_hard') return;
    state = state.copyWith(
      bubbles: [...state.bubbles, Bubble(false, display ?? t)],
      busy: true,
      mood: 'thinking',
      choices: const [],
      numberPad: false,
    );
    try {
      _applyTurn(await _api.turn(sid, t, mode));
    } on ApiOffline {
      const msg = 'Ối, mạng hơi chậm. Bạn nói lại giúp Cú nhé!';
      _owl(msg, 'encouraging');
      _say(msg);
    } on ApiError {
      const msg = 'Cú nghe chưa rõ. Bạn nói lại giúp Cú nhé!';
      _owl(msg, 'encouraging');
      _say(msg);
    }
  }

  /// FR-28: nút "Khó quá" → backend hạ độ khó (L3/L4).
  Future<void> tooHard() => childSays('', mode: 'too_hard', display: '😵 Khó quá!');

  /// FR-23: gửi ảnh bảng nháp để Cú nhận xét cách làm.
  Future<void> sendScratch(Uint8List png) async {
    final sid = state.sessionId;
    if (sid == null || state.busy) return;
    state = state.copyWith(bubbles: [...state.bubbles, const Bubble(false, '✏️ (Bạn gửi bảng nháp)')],
        busy: true, mood: 'thinking');
    try {
      _applyTurn(await _api.scratch(sid, png));
    } on ApiOffline {
      _offline();
    } on ApiError {
      _owl('Cú chưa xem được nháp. Bạn kể Cú nghe cách làm nhé?', 'encouraging');
    }
  }

  void _applyTurn(TurnResult r) {
    final prevHint = state.hintLevel;
    final phase = switch (r.state) {
      'solved' => TutorPhase.solved,
      'explaining' => TutorPhase.explaining,
      'parked' => TutorPhase.parked,
      _ => TutorPhase.tutoring,
    };
    var next = state.copyWith(
      bubbles: [...state.bubbles, Bubble(true, r.owl.say)],
      hintLevel: r.hintLevel,
      mood: r.owl.mood,
      phase: phase,
      busy: false,
      starsThisSession: state.starsThisSession + r.starsEarned,
      breakSuggested: r.state == 'break_suggested',
    );
    for (final a in r.uiActions) {
      switch (a['type']) {
        case 'celebrate':
          next = next.copyWith(celebrateTick: next.celebrateTick + 1);
        case 'show_manipulative':
          next = next.copyWith(tool: ManipulativeSpec.fromAction(a));
        case 'open_number_pad':
          next = next.copyWith(numberPad: true);
        case 'open_scratch_pad':
          next = next.copyWith(scratchTick: next.scratchTick + 1);
        case 'offer_choices':
          next = next.copyWith(choices: ((a['choices'] as List?) ?? []).map((e) => e.toString()).toList());
        case 'suggest_break':
          next = next.copyWith(breakSuggested: true);
      }
    }
    if (phase == TutorPhase.solved || phase == TutorPhase.parked) {
      next = next.copyWith(doneIds: {...next.doneIds, if (next.currentId != null) next.currentId!});
    }
    if (r.funQuestion.isNotEmpty && !_funShown) {
      _funShown = true;
      next = next.copyWith(funQuestion: r.funQuestion);
    }
    state = next;
    if (r.starsEarned > 0) {
      _ref.read(profilesProvider.notifier).addStars(r.starsEarned);
      _ref.read(soundProvider).ting();
    }
    if (phase == TutorPhase.solved) _ref.read(soundProvider).tada();
    final spoken = _say(r.owl.say);
    // Lời ghi âm của bố mẹ (nếu có): khen khi bé tự giải xong, động viên khi bé gặp khó.
    final childId = _ref.read(activeChildProvider)?.id;
    final voice = _ref.read(parentVoiceProvider);
    if (phase == TutorPhase.solved) {
      spoken.then((_) => voice.play('praise', childId: childId));
    } else if (phase == TutorPhase.parked || (r.hintLevel >= 3 && prevHint < 3)) {
      spoken.then((_) => voice.play('encourage', childId: childId));
    }
  }

  // ------------------------------------------------------------------ sau khi làm xong
  /// FR-30: thử thách tương tự.
  Future<void> challenge() async {
    final sid = state.sessionId;
    if (sid == null || state.busy) return;
    state = state.copyWith(busy: true, mood: 'thinking', funQuestion: '');
    try {
      final r = await _api.challenge(sid);
      _applyStart(r);
      state = state.copyWith(problems: r.problems, doneIds: const {}, currentId: r.problems.isNotEmpty ? r.problems.first.id : null);
    } on ApiOffline {
      _offline();
    } on ApiError {
      _owl('Cú chưa nghĩ ra thử thách. Mình làm câu khác nhé!', 'encouraging');
    }
  }

  /// Câu tiếp theo trên cùng trang. Trả false nếu đã hết câu.
  Future<bool> nextProblem() async {
    final remaining = state.problems.where((p) => !state.doneIds.contains(p.id) && p.id != state.currentId).toList();
    if (remaining.isEmpty) return false;
    if (remaining.length == 1) {
      await pickProblem(remaining.first.id);
    } else {
      state = state.copyWith(phase: TutorPhase.picking, funQuestion: '', clearTool: true, mood: 'asking');
      _say('Bạn muốn làm câu nào tiếp theo?');
    }
    return true;
  }

  void closeTool() => state = state.copyWith(clearTool: true);
  void setNumberPad(bool open) => state = state.copyWith(numberPad: open);
  void dismissFun() => state = state.copyWith(funQuestion: '');
  void breakHandled() => state = state.copyWith(breakSuggested: false);
}

final tutorControllerProvider =
    StateNotifierProvider.autoDispose<TutorController, TutorState>((ref) => TutorController(ref));
