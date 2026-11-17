import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import '../../models/app_settings.dart';
import '../../models/child_profile.dart';
import '../../models/tutor_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/pin_pad.dart';
import 'parent_gate_screen.dart';
import 'voice_picker.dart';

/// Góc phụ huynh (nhóm F): báo cáo, đáp án tham khảo, cài đặt, hồ sơ bé, an toàn.
class ParentHomeScreen extends ConsumerStatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  ConsumerState<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends ConsumerState<ParentHomeScreen> {
  late final StateController<bool> _unlock;

  @override
  void initState() {
    super.initState();
    _unlock = ref.read(parentUnlockedProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ref.read(parentUnlockedProvider)) context.pushReplacement('/parent');
    });
  }

  @override
  void dispose() {
    final unlock = _unlock;
    Future.microtask(() => unlock.state = false); // rời Góc phụ huynh → khóa lại
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(parentUnlockedProvider)) return const Scaffold();
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.cream,
          title: Text('👨‍👩‍👧 Góc phụ huynh', style: titleStyle(28)),
          bottom: TabBar(
            labelStyle: bodyStyle(20, AppColors.ink, FontWeight.w800),
            tabs: const [
              Tab(text: '📊 Báo cáo'),
              Tab(text: '⚙️ Cài đặt'),
              Tab(text: '👧 Hồ sơ bé'),
              Tab(text: '🛡️ An toàn'),
            ],
          ),
        ),
        body: const TabBarView(children: [_ReportTab(), _SettingsTab(), _ProfilesTab(), _SafetyTab()]),
      ),
    );
  }
}

// ============================================================================ Báo cáo (FR-60, FR-61)
class _ReportTab extends ConsumerStatefulWidget {
  const _ReportTab();

  @override
  ConsumerState<_ReportTab> createState() => _ReportTabState();
}

class _ReportTabState extends ConsumerState<_ReportTab> {
  String _period = 'day';
  String? _childId;
  Future<ParentReport?>? _future;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _childId = ref.read(activeChildProvider)?.id;
    _load();
  }

  void _load() {
    setState(() {
      _error = '';
      _future = _fetch();
    });
  }

  Future<ParentReport?> _fetch() async {
    final sec = ref.read(secureStoreProvider);
    final dev = await ref.read(deviceServiceProvider).ensureRegistered();
    final tok = await sec.parentToken();
    if (dev == null || tok == null || _childId == null) {
      _error = 'Chưa kết nối được máy chủ. Kiểm tra mạng rồi thử lại.';
      return null;
    }
    try {
      return await ref.read(apiProvider).parentReport(dev, _childId!, tok, period: _period);
    } on ApiOffline {
      _error = 'Không có mạng – chỉ xem được thời gian học trên máy.';
    } on ApiError catch (e) {
      _error = 'Lỗi máy chủ (${e.status}).';
    }
    return null;
  }

  Future<void> _showAnswer(String sessionId) async {
    final tok = await ref.read(secureStoreProvider).parentToken();
    if (tok == null) return;
    try {
      final a = await ref.read(apiProvider).parentAnswer(sessionId, tok);
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Đáp án tham khảo', style: titleStyle(28)),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${a['problem']}', style: bodyStyle(20)),
                  const SizedBox(height: 12),
                  Text('Đáp án: ${a['answer']}', style: titleStyle(26, AppColors.success)),
                  const SizedBox(height: 8),
                  for (final s in (a['steps'] as List? ?? [])) Text('• $s', style: bodyStyle(19)),
                  const SizedBox(height: 12),
                  Text('Gợi ý: hãy hỏi gợi mở như Cú, đừng nói ngay đáp án cho bé nhé!',
                      style: bodyStyle(17, Colors.grey.shade700, FontWeight.w600)),
                ],
              ),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Đóng'))],
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không lấy được đáp án.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(profilesProvider).list;
    final store = ref.read(localStoreProvider);
    final localWeek = _childId == null ? <String, int>{} : store.lastWeekMinutes(_childId!);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Wrap(spacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
          for (final p in profiles)
            ChoiceChip(
              label: Text('${p.avatar} ${p.nickname}', style: bodyStyle(20)),
              selected: p.id == _childId,
              onSelected: (_) {
                _childId = p.id;
                _load();
              },
            ),
          const SizedBox(width: 20),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'day', label: Text('Hôm nay')),
              ButtonSegment(value: 'week', label: Text('7 ngày')),
            ],
            selected: {_period},
            onSelectionChanged: (s) {
              _period = s.first;
              _load();
            },
          ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh, size: 32)),
        ]),
        const SizedBox(height: 16),
        _Card(
          title: '⏱️ Thời gian học trên máy (7 ngày)',
          child: SizedBox(
            height: 140,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final e in localWeek.entries)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('${e.value}′', style: bodyStyle(15)),
                        Container(
                          height: (e.value.clamp(0, 90) / 90 * 90).toDouble() + 2,
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          color: AppColors.sky,
                        ),
                        Text(e.key.substring(5), style: bodyStyle(14)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        FutureBuilder<ParentReport?>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()));
            }
            final r = snap.data;
            if (r == null) {
              return Padding(padding: const EdgeInsets.all(16), child: Text(_error, style: bodyStyle(20)));
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(spacing: 14, runSpacing: 14, children: [
                  _Kpi('⏱️', '${r.minutes} phút', 'học cùng Cú'),
                  _Kpi('📝', '${r.problemsTotal}', 'câu đã làm'),
                  _Kpi('🌟', '${r.solvedSelf}', 'câu bé TỰ giải'),
                  _Kpi('👩‍🏫', '${r.parked}', 'để dành hỏi thầy cô'),
                  _Kpi('⭐', '${r.stars}', 'sao nỗ lực'),
                ]),
                if (r.safetyAlerts > 0)
                  _Card(
                    title: '⚠️ Cần bố mẹ lưu ý',
                    child: Text(
                        'Có ${r.safetyAlerts} lần bé nói điều nhạy cảm (ví dụ buồn bã, từ ngữ không phù hợp). '
                        'Bố mẹ nên trò chuyện nhẹ nhàng với bé.',
                        style: bodyStyle(19)),
                  ),
                if (r.hardTypes.isNotEmpty)
                  _Card(
                    title: '🧗 Dạng bài bé thấy khó',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final h in r.hardTypes)
                          Text('• ${_typeName('${h['type']}')} – ${h['count']} câu, gợi ý trung bình bậc ${h['avg_hint']}',
                              style: bodyStyle(19)),
                      ],
                    ),
                  ),
                _Card(
                  title: '👩‍🏫 Câu để dành hỏi thầy cô',
                  child: r.parkedItems.isEmpty
                      ? Text('Không có – bé tự làm hết! 🎉', style: bodyStyle(19))
                      : Column(children: [for (final it in r.parkedItems) _item(it, showAnswer: true)]),
                ),
                _Card(
                  title: '🕘 Gần đây',
                  child: Column(children: [for (final it in r.recent) _item(it, showAnswer: true)]),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _item(Map<String, dynamic> it, {bool showAnswer = false}) {
    final outcome = switch ('${it['outcome']}') {
      'solved' => '✅ Tự giải',
      'parked' => '👩‍🏫 Để dành',
      _ => '⏳ Đang làm',
    };
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text('${it['problem_text']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: bodyStyle(18)),
      subtitle: Text('$outcome · gợi ý bậc ${it['max_hint']} · ${it['turns']} lượt', style: bodyStyle(16)),
      trailing: showAnswer
          ? TextButton(onPressed: () => _showAnswer('${it['session_id']}'), child: const Text('Xem đáp án'))
          : null,
    );
  }
}

String _typeName(String t) => t.replaceAll('_', ' ');

class _Kpi extends StatelessWidget {
  const _Kpi(this.emoji, this.value, this.label);
  final String emoji, value, label;

  @override
  Widget build(BuildContext context) => Container(
        width: 210,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$emoji $value', style: titleStyle(30)),
            Text(label, style: bodyStyle(17)),
          ],
        ),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text(title, style: titleStyle(24)), const SizedBox(height: 8), child],
        ),
      );
}

// ============================================================================ Cài đặt (FR-50..52, FR-62, FR-63)
class _SettingsTab extends ConsumerStatefulWidget {
  const _SettingsTab();

  @override
  ConsumerState<_SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends ConsumerState<_SettingsTab> {
  late final _url = TextEditingController(text: ref.read(settingsProvider).serverUrl);
  String _health = '';

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _save(AppSettings s) => ref.read(settingsProvider.notifier).save(s);

  Future<void> _pickTime(String current, ValueChanged<String> onPicked) async {
    final p = current.split(':');
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.tryParse(p.first) ?? 21, minute: int.tryParse(p.last) ?? 0),
    );
    if (t != null) onPicked('${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
  }

  Future<void> _changePin() async {
    String? first;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(first == null ? 'Mã PIN mới' : 'Nhập lại mã PIN mới', style: titleStyle(26)),
          content: PinPad(onCompleted: (pin) async {
            if (first == null) {
              setD(() => first = pin);
            } else if (first == pin) {
              await ref.read(secureStoreProvider).setPin(pin);
              if (ctx.mounted) Navigator.pop(ctx);
            } else {
              setD(() => first = null);
            }
          }),
        ),
      ),
    );
  }

  Widget _row(String label, Widget control, {String? note}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 320,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: bodyStyle(20, AppColors.ink, FontWeight.w800)),
                  if (note != null) Text(note, style: bodyStyle(15, Colors.grey.shade700, FontWeight.w500)),
                ],
              ),
            ),
            Expanded(child: control),
          ],
        ),
      );

  Widget _choices<T>(T value, Map<T, String> options, ValueChanged<T> onChanged) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final e in options.entries)
            ChoiceChip(
              label: Text(e.value, style: bodyStyle(18)),
              selected: e.key == value,
              onSelected: (_) => onChanged(e.key),
            ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('🔊 Giọng Cú', style: titleStyle(26)),
        const SizedBox(height: 8),
        const VoicePicker(),
        const SizedBox(height: 12),
        Text('Tự chỉnh thêm', style: bodyStyle(20, AppColors.ink, FontWeight.w800)),
        _row(
          'Tốc độ đọc',
          Slider(
            value: s.ttsRate.clamp(0.25, 0.75).toDouble(),
            min: 0.25,
            max: 0.75,
            divisions: 10,
            label: s.ttsRate.toStringAsFixed(2),
            onChanged: (v) => _save(s.copyWith(ttsRate: v, voicePreset: '')),
          ),
          note: 'Trẻ nhỏ nên đọc chậm',
        ),
        _row(
          'Cao độ giọng',
          Slider(
            value: s.ttsPitch.clamp(0.7, 1.8).toDouble(),
            min: 0.7,
            max: 1.8,
            divisions: 22,
            label: s.ttsPitch.toStringAsFixed(2),
            onChanged: (v) => _save(s.copyWith(ttsPitch: v, voicePreset: '')),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: () => ref.read(ttsProvider).say('Xin chào! Tớ là Cú Tò Mò. Mình cùng học nhé!'),
            child: const Text('▶️ Nghe thử'),
          ),
        ),
        _row('Âm thanh hiệu ứng', Switch(value: s.soundEffects, onChanged: (v) => _save(s.copyWith(soundEffects: v)))),
        const Divider(height: 32),
        Text('⏰ Thời gian', style: titleStyle(26)),
        _row('Nghỉ giải lao sau', _choices<int>(s.breakMinutes, {0: 'Tắt', 15: '15 phút', 20: '20 phút', 30: '30 phút'},
            (v) => _save(s.copyWith(breakMinutes: v)))),
        _row('Giới hạn mỗi ngày', _choices<int>(s.dailyLimitMinutes,
            {0: 'Không giới hạn', 30: '30 phút', 45: '45 phút', 60: '60 phút', 90: '90 phút'},
            (v) => _save(s.copyWith(dailyLimitMinutes: v)))),
        _row(
          'Giờ đi ngủ',
          Wrap(spacing: 10, children: [
            OutlinedButton(
              onPressed: () => _pickTime(s.bedtime.isEmpty ? '21:00' : s.bedtime, (v) => _save(s.copyWith(bedtime: v))),
              child: Text(s.bedtime.isEmpty ? 'Tắt' : 'Ngủ lúc ${s.bedtime}'),
            ),
            OutlinedButton(
              onPressed: () => _pickTime(s.wakeTime, (v) => _save(s.copyWith(wakeTime: v))),
              child: Text('Dùng lại lúc ${s.wakeTime}'),
            ),
            if (s.bedtime.isNotEmpty)
              TextButton(onPressed: () => _save(s.copyWith(bedtime: '')), child: const Text('Tắt giờ ngủ')),
          ]),
        ),
        const Divider(height: 32),
        Text('🤖 Trí tuệ nhân tạo', style: titleStyle(26)),
        _row('Nhà cung cấp AI', _choices<String>(s.provider,
            {'': 'Theo máy chủ', 'anthropic': 'Claude', 'openai': 'ChatGPT'}, (v) => _save(s.copyWith(provider: v))),
            note: 'Khóa API chỉ nằm trên máy chủ, không lưu trên máy tính bảng'),
        _row('Mức', _choices<String>(s.tier,
            {'tiet_kiem': 'Tiết kiệm', 'can_bang': 'Cân bằng', 'thong_minh': 'Thông minh'},
            (v) => _save(s.copyWith(tier: v)))),
        _row(
          'Địa chỉ máy chủ',
          Row(children: [
            Expanded(
              child: TextField(
                controller: _url,
                style: bodyStyle(18),
                decoration: const InputDecoration(hintText: 'Để trống = mặc định khi build'),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () async {
                await _save(s.copyWith(serverUrl: _url.text.trim()));
                final ok = await ref.read(apiProvider).health();
                setState(() => _health = ok ? '✅ Kết nối tốt' : '❌ Không kết nối được');
              },
              child: const Text('Lưu & kiểm tra'),
            ),
          ]),
          note: _health.isEmpty ? 'Dành cho bản thử nghiệm trong mạng nhà' : _health,
        ),
        const Divider(height: 32),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(onPressed: _changePin, child: const Text('🔑 Đổi mã PIN')),
        ),
      ],
    );
  }
}

// ============================================================================ Hồ sơ bé (FR-03, FR-64)
class _ProfilesTab extends ConsumerWidget {
  const _ProfilesTab();

  Future<void> _delete(BuildContext context, WidgetRef ref, ChildProfile p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Xóa dữ liệu của ${p.nickname}?', style: titleStyle(26)),
        content: Text('Xóa hồ sơ, sao, thời gian học trên máy và toàn bộ lịch sử học trên máy chủ. Không hoàn tác được.',
            style: bodyStyle(19)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Thôi')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa')),
        ],
      ),
    );
    if (ok != true) return;
    final sec = ref.read(secureStoreProvider);
    final dev = await sec.deviceId();
    final tok = await sec.parentToken();
    var serverOk = dev == null; // chưa từng đăng ký → không có dữ liệu trên máy chủ
    if (dev != null && tok != null) {
      try {
        await ref.read(apiProvider).deleteChild(dev, p.id, tok);
        serverOk = true;
      } catch (_) {}
    }
    if (!serverOk) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Chưa xóa được trên máy chủ (mất mạng?). Hãy thử lại khi có mạng.')));
      }
      return;
    }
    await ref.read(profilesProvider.notifier).remove(p.id);
    if (ref.read(profilesProvider).list.isEmpty) {
      await ref.read(localStoreProvider).setOnboardingDone(false);
      if (context.mounted) context.go('/onboarding');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(profilesProvider).list;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        for (final p in profiles)
          Card(
            child: ListTile(
              leading: Text(p.avatar, style: const TextStyle(fontSize: 40)),
              title: Text('${p.nickname} · Lớp ${p.grade}', style: titleStyle(26)),
              subtitle: Text('⭐ ${p.stars} · ${ChildProfile.stageNames[p.owlStage]}', style: bodyStyle(18)),
              trailing: Wrap(spacing: 8, children: [
                OutlinedButton(onPressed: () => context.push('/profile', extra: p), child: const Text('Sửa')),
                OutlinedButton(onPressed: () => _delete(context, ref, p), child: const Text('🗑️ Xóa dữ liệu')),
              ]),
            ),
          ),
        const SizedBox(height: 12),
        if (profiles.length < 3)
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton(onPressed: () => context.push('/profile'), child: const Text('➕ Thêm bé')),
          ),
      ],
    );
  }
}

// ============================================================================ An toàn & hướng dẫn (mục 15)
class _SafetyTab extends StatelessWidget {
  const _SafetyTab();

  @override
  Widget build(BuildContext context) {
    Widget item(String title, String body) => _Card(
          title: title,
          child: Text(body, style: bodyStyle(19, AppColors.ink, FontWeight.w500)),
        );
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        item('📌 Ghim màn hình',
            'Cài đặt → Bảo mật → Ghim ứng dụng (Screen pinning) → Bật. Mở Cú Tò Mò, vào màn đa nhiệm, chạm biểu tượng ứng dụng → Ghim. '
                'Bé sẽ chỉ dùng được ứng dụng này cho tới khi bố mẹ bỏ ghim. ⚠️ Tên menu có thể khác giữa Android 11 và 13.'),
        item('👪 Google Family Link',
            'Cài Family Link trên điện thoại bố mẹ để giới hạn thời gian dùng máy và chặn ứng dụng khác khi bé học.'),
        item('🔐 Dữ liệu của bé',
            'Ứng dụng chỉ lưu biệt danh, lớp, sao và lịch sử học. Ảnh bài tập không được lưu trên máy chủ. '
                'Giọng nói được nhận dạng ngay trên máy. Bố mẹ có thể xóa dữ liệu của từng bé ở thẻ "Hồ sơ bé".'),
        item('🦉 Vì sao Cú không nói đáp án?',
            'Cú dùng phương pháp hỏi gợi mở: chia nhỏ vấn đề, đưa ví dụ tương tự, dùng que tính… để bé TỰ tìm ra. '
                'Nếu bé bí quá 12 lượt, Cú đề nghị "để dành hỏi thầy cô" và ghi lại trong báo cáo để bố mẹ kèm bé.'),
        item('🗣️ Chuẩn bị giọng nói',
            'Cài đặt → Hệ thống → Ngôn ngữ & nhập liệu → Đầu ra chuyển văn bản thành giọng nói → chọn Google và tải giọng Tiếng Việt. '
                'Cập nhật "Speech Services by Google" và tải gói Tiếng Việt ngoại tuyến nếu có.'),
      ],
    );
  }
}
