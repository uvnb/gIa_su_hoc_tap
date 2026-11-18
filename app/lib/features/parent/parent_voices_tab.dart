import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../../core/parent_voice_service.dart';
import '../../core/permissions.dart';
import '../../core/providers.dart';
import '../../models/child_profile.dart';
import '../../models/game_models.dart';
import '../../theme/app_theme.dart';

/// Góc phụ huynh → 🎙️ Lời bố mẹ: ghi âm lời khen / động viên kèm chú thích.
/// App tự phát đúng lúc: bé làm xong bài, bé gặp khó, hết giờ chơi, mở app đầu ngày.
class ParentVoicesTab extends ConsumerStatefulWidget {
  const ParentVoicesTab({super.key});

  @override
  ConsumerState<ParentVoicesTab> createState() => _ParentVoicesTabState();
}

class _ParentVoicesTabState extends ConsumerState<ParentVoicesTab> {
  List<ParentVoice> _list = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() => setState(() => _list = ref.read(localStoreProvider).voices());

  Future<void> _new([String? purpose]) async {
    final v = await showDialog<ParentVoice>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RecordVoiceDialog(initialPurpose: purpose ?? 'praise'),
    );
    if (v == null) return;
    await ref.read(parentVoiceProvider).save(v);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(profilesProvider).list;
    String who(String id) {
      if (id.isEmpty) return 'Tất cả các bé';
      for (final p in profiles) {
        if (p.id == id) return '${p.avatar} ${p.nickname}';
      }
      return 'Bé đã xóa';
    }

    if (!ParentVoiceService.supported) {
      return Center(child: Text('Ghi âm chỉ dùng được trong ứng dụng trên máy tính bảng.', style: titleStyle(26)));
    }
    final service = ref.read(parentVoiceProvider);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFFFE0EC), Color(0xFFFFF3C4)]),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(children: [
            const Text('🎙️', style: TextStyle(fontSize: 56)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Giọng của bố mẹ là phần thưởng lớn nhất!', style: titleStyle(26)),
                Text(
                    'Ghi lại lời khen, lời động viên kèm chú thích. Cú sẽ phát đúng lúc: khi bé tự làm xong bài, '
                    'khi bé gặp bài khó, khi hết giờ chơi, khi bé mở app đầu ngày. Mỗi đoạn tối đa 30 giây.',
                    style: bodyStyle(17)),
              ]),
            ),
            const SizedBox(width: 12),
            ElevatedButton(onPressed: _new, child: const Text('🎙️ Ghi âm lời mới')),
          ]),
        ),
        for (final p in voicePurposes) ...[
          const SizedBox(height: 18),
          Row(children: [
            Text('${p.emoji} ${p.label}', style: titleStyle(26)),
            const SizedBox(width: 12),
            Expanded(child: Text('Phát: ${p.when}', style: bodyStyle(16, Colors.grey.shade700))),
            TextButton(onPressed: () => _new(p.id), child: const Text('+ Thêm')),
          ]),
          if (_list.where((v) => v.purpose == p.id).isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 4),
              child: Text('Chưa có – Cú sẽ tự nói.', style: bodyStyle(17, Colors.grey.shade600)),
            ),
          for (final v in _list.where((v) => v.purpose == p.id))
            Card(
              child: ListTile(
                leading: IconButton(
                  onPressed: () => service.playOne(v),
                  icon: const Text('▶️', style: TextStyle(fontSize: 30)),
                ),
                title: Text(v.caption.isEmpty ? '(không có chú thích)' : v.caption, style: bodyStyle(20)),
                subtitle: Text('${who(v.childId)} · ${(v.durationMs / 1000).toStringAsFixed(0)} giây', style: bodyStyle(16)),
                trailing: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
                  Text(v.enabled ? 'Đang dùng' : 'Tạm tắt', style: bodyStyle(15)),
                  Switch(
                    value: v.enabled,
                    onChanged: (on) async {
                      await service.save(v.copyWith(enabled: on));
                      _reload();
                    },
                  ),
                  IconButton(
                    tooltip: 'Xóa',
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('Xóa đoạn ghi âm này?', style: titleStyle(24)),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Thôi')),
                            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xóa')),
                          ],
                        ),
                      );
                      if (ok == true) {
                        await service.delete(v);
                        _reload();
                      }
                    },
                    icon: const Text('🗑️', style: TextStyle(fontSize: 24)),
                  ),
                ]),
              ),
            ),
        ],
      ],
    );
  }
}

/// Hộp ghi âm: chọn mục đích → chọn bé → chú thích → bấm ghi / dừng → nghe lại → lưu.
class RecordVoiceDialog extends ConsumerStatefulWidget {
  const RecordVoiceDialog({super.key, this.initialPurpose = 'praise'});
  final String initialPurpose;

  @override
  ConsumerState<RecordVoiceDialog> createState() => _RecordVoiceDialogState();
}

class _RecordVoiceDialogState extends ConsumerState<RecordVoiceDialog> {
  final _rec = VoiceRecorder();
  final _caption = TextEditingController();
  final _id = const Uuid().v4();
  late String _purpose = widget.initialPurpose;
  bool _purposeTouched = false;
  String _childId = '';
  String? _path;
  int _ms = 0;
  bool _recording = false;
  String _error = '';

  @override
  void dispose() {
    _rec.dispose();
    _caption.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_recording) {
      await _stop();
      return;
    }
    setState(() => _error = '');
    if (!await ensurePermission(Permission.microphone)) {
      setState(() => _error = 'Cần cho phép dùng micro (Cài đặt → Ứng dụng → Cú Tò Mò → Quyền).');
      return;
    }
    await ref.read(ttsProvider).stop();
    await ref.read(parentVoiceProvider).stop();
    final path = await ParentVoiceService.newPath(_id);
    final ok = await _rec.start(path, onAutoStop: _stop);
    if (!mounted) return;
    setState(() {
      _recording = ok;
      if (!ok) _error = 'Không ghi âm được. Thử lại nhé.';
    });
  }

  Future<void> _stop() async {
    final r = await _rec.stop();
    if (!mounted) return;
    setState(() {
      _recording = false;
      if (r != null) {
        _path = r.$1;
        _ms = r.$2;
      }
    });
  }

  ParentVoice _voice() => ParentVoice(
        id: _id,
        purpose: _purpose,
        caption: _caption.text.trim().isEmpty ? purposeById(_purpose).label : _caption.text.trim(),
        path: _path ?? '',
        childId: _childId,
        durationMs: _ms,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );

  Future<void> _cancel() async {
    if (_recording) await _rec.stop();
    if (_path != null) await ParentVoiceService.deleteFile(_path!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(profilesProvider).list;
    final p = purposeById(_purpose);
    final has = _path != null && !_recording;
    return AlertDialog(
      backgroundColor: AppColors.cream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Text('🎙️ Ghi âm lời của bố mẹ', style: titleStyle(28)),
      content: SizedBox(
        width: 820,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('1. Lời này để làm gì?', style: bodyStyle(20, AppColors.ink, FontWeight.w800)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final vp in voicePurposes)
                ChoiceChip(
                  label: Text('${vp.emoji} ${vp.label}', style: bodyStyle(18)),
                  selected: vp.id == _purpose,
                  onSelected: (_) => setState(() {
                    _purpose = vp.id;
                    _purposeTouched = true;
                  }),
                ),
            ]),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('App sẽ phát: ${p.when}', style: bodyStyle(16, Colors.grey.shade700)),
            ),
            const SizedBox(height: 14),
            Text('2. Dành cho bé nào?', style: bodyStyle(20, AppColors.ink, FontWeight.w800)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              ChoiceChip(
                label: Text('👨‍👩‍👧 Tất cả các bé', style: bodyStyle(18)),
                selected: _childId.isEmpty,
                onSelected: (_) => setState(() => _childId = ''),
              ),
              for (final ChildProfile c in profiles)
                ChoiceChip(
                  label: Text('${c.avatar} ${c.nickname}', style: bodyStyle(18)),
                  selected: _childId == c.id,
                  onSelected: (_) => setState(() => _childId = c.id),
                ),
            ]),
            const SizedBox(height: 14),
            Text('3. Chú thích (đoạn ghi âm này nói gì, để làm gì)', style: bodyStyle(20, AppColors.ink, FontWeight.w800)),
            const SizedBox(height: 6),
            TextField(
              controller: _caption,
              maxLength: 80,
              style: bodyStyle(19),
              decoration: InputDecoration(hintText: 'VD: ${p.examples.first}'),
              onChanged: (t) {
                if (_purposeTouched) return;
                final g = guessPurpose(t);
                if (g != null && g != _purpose) setState(() => _purpose = g);
              },
            ),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final ex in p.examples)
                ActionChip(
                  label: Text(ex, style: bodyStyle(15)),
                  onPressed: () => setState(() => _caption.text = ex),
                ),
            ]),
            const SizedBox(height: 14),
            Text('4. Ghi âm (tối đa ${VoiceRecorder.maxSeconds} giây)', style: bodyStyle(20, AppColors.ink, FontWeight.w800)),
            const SizedBox(height: 8),
            Row(children: [
              GestureDetector(
                onTap: _toggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 110,
                  height: 110,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _recording ? const Color(0xFFE0457B) : AppColors.sky,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 8)],
                  ),
                  child: Text(_recording ? '⏹️' : '🎙️', style: const TextStyle(fontSize: 48)),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: _recording
                    ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        ValueListenableBuilder<int>(
                          valueListenable: _rec.elapsed,
                          builder: (_, s, __) => Text('Đang ghi… 0:${s.toString().padLeft(2, '0')} / 0:30 – bấm ⏹️ để dừng',
                              style: titleStyle(22, const Color(0xFFE0457B))),
                        ),
                        const SizedBox(height: 8),
                        ValueListenableBuilder<double>(
                          valueListenable: _rec.level,
                          builder: (_, l, __) => ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: l,
                              minHeight: 16,
                              color: AppColors.success,
                              backgroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ])
                    : has
                        ? Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                            Text('Đã ghi ${(_ms / 1000).toStringAsFixed(1)} giây', style: titleStyle(22, AppColors.success)),
                            OutlinedButton(
                              onPressed: () => ref.read(parentVoiceProvider).playOne(_voice()),
                              child: const Text('▶️ Nghe lại'),
                            ),
                            TextButton(onPressed: _toggle, child: const Text('🔁 Ghi lại')),
                          ])
                        : Text('Bấm nút 🎙️ rồi nói, bấm lần nữa để dừng.', style: bodyStyle(19)),
              ),
            ]),
            if (_error.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error, style: bodyStyle(17, const Color(0xFFE0457B))),
              ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: _cancel, child: const Text('Hủy')),
        ElevatedButton(
          onPressed: has && _ms >= 500 ? () => Navigator.pop(context, _voice()) : null,
          child: const Text('💾 Lưu'),
        ),
      ],
    );
  }
}
