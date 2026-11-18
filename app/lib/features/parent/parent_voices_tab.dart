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
    // Mở thành màn hình riêng (không phải hộp thoại) – vừa màn 960×600, không phải cuộn.
    final v = await Navigator.of(context).push<ParentVoice>(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => RecordVoiceDialog(initialPurpose: purpose ?? 'praise'),
    ));
    if (v == null) return;
    await ref.read(parentVoiceProvider).save(v);
    _reload();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.success,
        content: Text('✅ Đã lưu lời nhắn: “${v.caption}”', style: bodyStyle(20, Colors.white)),
      ));
    }
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
            ElevatedButton(onPressed: () => _new('praise'), child: const Text('🎙️ Ghi âm lời mới')),
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
                subtitle:
                    Text('${who(v.childId)} · ${(v.durationMs / 1000).toStringAsFixed(0)} giây', style: bodyStyle(16)),
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

/// Màn ghi âm 2 cột (thấy hết, không cần cuộn): trái = để làm gì, cho bé nào, chú thích;
/// phải = nút 🎙️ to, đồng hồ, nghe lại, 💾 Lưu.
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
  bool _busy = false;
  String _error = '';
  DateTime? _downAt; // giữ nút ≥ 1 giây rồi thả = dừng (kiểu "giữ để nói")

  @override
  void dispose() {
    _rec.dispose();
    _caption.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_busy) return;
    if (_recording) {
      await _stop();
      return;
    }
    _busy = true;
    setState(() => _error = '');
    try {
      if (!await ensurePermission(Permission.microphone)) {
        setState(() => _error = 'Cần cho phép dùng micro: Cài đặt → Ứng dụng → Cú Tò Mò → Quyền → Micrô.');
        return;
      }
      await ref.read(ttsProvider).stop();
      await ref.read(parentVoiceProvider).stop();
      if (_path != null) await ParentVoiceService.deleteFile(_path!); // ghi lại → bỏ bản cũ
      final ok = await _rec.start(_id, onAutoStop: _stop);
      if (!mounted) return;
      setState(() {
        _recording = ok;
        if (ok) {
          _path = null;
          _ms = 0;
        } else {
          _error = _rec.lastError.isEmpty ? 'Không ghi âm được. Thử lại nhé.' : _rec.lastError;
        }
      });
    } finally {
      _busy = false;
    }
  }

  Future<void> _stop() async {
    if (!_recording) return;
    final r = await _rec.stop();
    if (!mounted) return;
    setState(() {
      _recording = false;
      if (r != null) {
        _path = r.$1;
        _ms = r.$2;
      } else {
        _error = _rec.lastError.isEmpty ? 'Chưa ghi được tiếng. Bấm 🎙️ ghi lại nhé.' : _rec.lastError;
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
    if (_recording) {
      final r = await _rec.stop();
      if (r != null) await ParentVoiceService.deleteFile(r.$1);
    }
    if (_path != null) await ParentVoiceService.deleteFile(_path!);
    if (mounted) Navigator.pop(context);
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(t, style: bodyStyle(19, AppColors.ink, FontWeight.w800)),
      );

  @override
  Widget build(BuildContext context) {
    final profiles = ref.watch(profilesProvider).list;
    final p = purposeById(_purpose);
    final has = _path != null && !_recording;
    final canSave = has && _ms >= 300;
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        leading: IconButton(onPressed: _cancel, icon: const Icon(Icons.close, size: 32)),
        title: Text('🎙️ Ghi âm lời của bố mẹ', style: titleStyle(26)),
      ),
      body: SafeArea(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // ---------------- bên trái: thông tin
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _label('1. Lời này để làm gì?'),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final vp in voicePurposes)
                    ChoiceChip(
                      label: Text('${vp.emoji} ${vp.label}', style: bodyStyle(17)),
                      selected: vp.id == _purpose,
                      onSelected: (_) => setState(() {
                        _purpose = vp.id;
                        _purposeTouched = true;
                      }),
                    ),
                ]),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('App sẽ phát: ${p.when}', style: bodyStyle(15, Colors.grey.shade700)),
                ),
                _label('2. Dành cho bé nào?'),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  ChoiceChip(
                    label: Text('👨‍👩‍👧 Tất cả các bé', style: bodyStyle(17)),
                    selected: _childId.isEmpty,
                    onSelected: (_) => setState(() => _childId = ''),
                  ),
                  for (final ChildProfile c in profiles)
                    ChoiceChip(
                      label: Text('${c.avatar} ${c.nickname}', style: bodyStyle(17)),
                      selected: _childId == c.id,
                      onSelected: (_) => setState(() => _childId = c.id),
                    ),
                ]),
                _label('3. Chú thích (lời này nói gì, để làm gì)'),
                TextField(
                  controller: _caption,
                  maxLength: 80,
                  style: bodyStyle(18),
                  decoration: InputDecoration(hintText: 'VD: ${p.examples.first}', counterText: ''),
                  onChanged: (t) {
                    if (_purposeTouched) return;
                    final g = guessPurpose(t);
                    if (g != null && g != _purpose) setState(() => _purpose = g);
                  },
                ),
                const SizedBox(height: 6),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  for (final ex in p.examples)
                    ActionChip(
                      label: Text(ex, style: bodyStyle(14)),
                      onPressed: () => setState(() => _caption.text = ex),
                    ),
                ]),
              ]),
            ),
          ),
          // ---------------- bên phải: ghi âm
          Container(
            width: 330,
            margin: const EdgeInsets.fromLTRB(0, 8, 16, 16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
            child: SingleChildScrollView(
              child: Column(children: [
                Text('4. Ghi âm (tối đa ${VoiceRecorder.maxSeconds} giây)',
                    style: bodyStyle(18, AppColors.ink, FontWeight.w800)),
                const SizedBox(height: 10),
                // Bấm 1 lần để bắt đầu, bấm lần nữa để dừng – hoặc giữ nút trong lúc nói rồi thả ra.
                Listener(
                  onPointerDown: (_) {
                    _downAt = DateTime.now();
                    _toggle();
                  },
                  onPointerUp: (_) {
                    final held = _downAt != null && DateTime.now().difference(_downAt!) > const Duration(seconds: 1);
                    if (held && _recording) _stop();
                  },
                  child: ValueListenableBuilder<double>(
                    valueListenable: _rec.level,
                    builder: (_, l, __) => AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: 150,
                      height: 150,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _recording ? const Color(0xFFE0457B) : AppColors.sky,
                        boxShadow: [
                          BoxShadow(
                            color: (_recording ? const Color(0xFFE0457B) : Colors.black)
                                .withValues(alpha: _recording ? 0.25 + 0.4 * l : 0.15),
                            blurRadius: _recording ? 10 + 30 * l : 8,
                            spreadRadius: _recording ? 4 + 14 * l : 0,
                          ),
                        ],
                      ),
                      child: Text(_recording ? '⏹️' : '🎙️', style: const TextStyle(fontSize: 64)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_recording)
                  ValueListenableBuilder<int>(
                    valueListenable: _rec.elapsed,
                    builder: (_, sec, __) => Text(
                        '🔴 Đang ghi… 0:${sec.toString().padLeft(2, '0')} / 0:30\nBấm ⏹️ để dừng',
                        textAlign: TextAlign.center,
                        style: titleStyle(22, const Color(0xFFE0457B))),
                  )
                else if (has) ...[
                  Text('✅ Đã ghi ${(_ms / 1000).toStringAsFixed(1)} giây', style: titleStyle(22, AppColors.success)),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    OutlinedButton(
                      onPressed: () => ref.read(parentVoiceProvider).playOne(_voice()),
                      child: const Text('▶️ Nghe lại'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(onPressed: _toggle, child: const Text('🔁 Ghi lại')),
                  ]),
                ] else
                  Text('Bấm 🎙️ rồi nói,\nbấm ⏹️ để dừng.\n(hoặc giữ nút trong lúc nói)',
                      textAlign: TextAlign.center, style: bodyStyle(18)),
                if (_error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_error, textAlign: TextAlign.center, style: bodyStyle(16, const Color(0xFFE0457B))),
                  ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, minimumSize: const Size(0, 64)),
                    onPressed: canSave ? () => Navigator.pop(context, _voice()) : null,
                    child: const Text('💾 Lưu lời này'),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
