import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../theme/app_theme.dart';

/// Thông tin từng nhà cung cấp AI cho bố mẹ.
class _AiInfo {
  final String id, emoji, name, getAt, cost, prefix;
  const _AiInfo(this.id, this.emoji, this.name, this.getAt, this.cost, this.prefix);
}

const _ais = [
  _AiInfo('gemini', '✨', 'Gemini (Google)', 'https://aistudio.google.com/apikey', 'Miễn phí (có giới hạn lượt/ngày)',
      'AIza'),
  _AiInfo('openai', '🤖', 'ChatGPT (OpenAI)', 'https://platform.openai.com/api-keys',
      'Trả phí theo lượt – cần nạp tiền trước', 'sk-'),
  _AiInfo('anthropic', '🧠', 'Claude (Anthropic)', 'https://console.anthropic.com/settings/keys',
      'Trả phí theo lượt – cần nạp tiền trước', 'sk-ant-'),
];

/// Góc phụ huynh → Cài đặt → 🤖 Trí tuệ nhân tạo: chọn AI và NHẬP KHÓA API ngay trên máy tính bảng.
/// Khóa lưu mã hóa trên máy, chỉ gửi kèm (HTTPS) khi hỏi Cú; máy chủ dùng trong lượt đó rồi bỏ, không lưu.
class AiSettingsSection extends ConsumerStatefulWidget {
  const AiSettingsSection({super.key});

  @override
  ConsumerState<AiSettingsSection> createState() => _AiSettingsSectionState();
}

class _AiSettingsSectionState extends ConsumerState<AiSettingsSection> {
  final _key = TextEditingController();
  bool _show = false;
  bool _busy = false;
  String _saved = ''; // 4 ký tự cuối của khóa đã lưu
  String _status = '';
  bool _statusOk = false;
  String _loadedFor = '';

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  Future<void> _loadSaved(String provider) async {
    _loadedFor = provider;
    final k = provider.isEmpty ? null : await ref.read(secureStoreProvider).aiKey(provider);
    final m = provider.isEmpty ? null : await ref.read(secureStoreProvider).aiModel(provider);
    if (!mounted) return;
    setState(() {
      _saved = k == null || k.length < 4 ? '' : k.substring(k.length - 4);
      _key.clear();
      _status = k == null ? '' : '✅ Đã có khóa${(m ?? '').isNotEmpty ? ' · model $m' : ''}';
      _statusOk = k != null;
    });
  }

  Future<void> _pick(String provider) async {
    final s = ref.read(settingsProvider);
    await ref.read(settingsProvider.notifier).save(s.copyWith(provider: provider));
    await _loadSaved(provider);
    await ref.read(aiCredProvider.notifier).reload();
  }

  Future<void> _saveAndCheck(String provider) async {
    final key = _key.text.trim();
    if (key.length < 10) {
      setState(() {
        _status = 'Dán đủ khóa API vào ô trước nhé.';
        _statusOk = false;
      });
      return;
    }
    setState(() {
      _busy = true;
      _status = '⏳ Đang kiểm tra khóa với $provider…';
    });
    final (ok, model, err) = await ref.read(apiProvider).checkAiKey(provider, key);
    if (!mounted) return;
    if (ok) {
      await ref.read(secureStoreProvider).setAiKey(provider, key, model: model);
      await ref.read(aiCredProvider.notifier).reload();
    }
    setState(() {
      _busy = false;
      _statusOk = ok;
      _status = ok ? '✅ Khóa dùng được! Cú sẽ dùng AI này${model.isNotEmpty ? ' (model $model)' : ''}.' : '❌ $err';
      if (ok) {
        _saved = key.substring(key.length - 4);
        _key.clear();
      }
    });
  }

  Future<void> _delete(String provider) async {
    await ref.read(secureStoreProvider).deleteAiKey(provider);
    await ref.read(aiCredProvider.notifier).reload();
    setState(() {
      _saved = '';
      _status = 'Đã xóa khóa. Cú dùng AI mặc định của máy chủ.';
      _statusOk = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final provider = s.provider == 'deepseek' ? '' : s.provider;
    if (_loadedFor != provider) {
      _loadedFor = provider;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadSaved(provider));
    }
    final info = _ais.where((a) => a.id == provider).firstOrNull;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('🤖 Trí tuệ nhân tạo', style: titleStyle(26)),
      const SizedBox(height: 4),
      Text(
          'Mặc định Cú dùng AI của máy chủ (Gemini miễn phí). Muốn dùng ChatGPT, Claude hoặc khóa Gemini của riêng '
          'bạn thì chọn bên dưới và dán khóa API.',
          style: bodyStyle(16, Colors.grey.shade700, FontWeight.w500)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        ChoiceChip(
          label: Text('🦉 Mặc định (máy chủ)', style: bodyStyle(18)),
          selected: provider.isEmpty,
          onSelected: (_) => _pick(''),
        ),
        for (final a in _ais)
          ChoiceChip(
            label: Text('${a.emoji} ${a.name}', style: bodyStyle(18)),
            selected: provider == a.id,
            onSelected: (_) => _pick(a.id),
          ),
      ]),
      if (info != null) ...[
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.softSky, width: 3),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('🔑 Khóa API ${info.name}', style: bodyStyle(20, AppColors.ink, FontWeight.w800)),
            const SizedBox(height: 4),
            Row(children: [
              Expanded(
                child:
                    SelectableText('Lấy khóa tại: ${info.getAt}', style: bodyStyle(16, AppColors.sky, FontWeight.w700)),
              ),
              TextButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: info.getAt));
                  ScaffoldMessenger.of(context)
                      .showSnackBar(const SnackBar(content: Text('Đã chép địa chỉ – dán vào trình duyệt nhé.')));
                },
                child: const Text('📋 Chép link'),
              ),
            ]),
            Text('Chi phí: ${info.cost}', style: bodyStyle(15, Colors.grey.shade700, FontWeight.w600)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _key,
                  obscureText: !_show,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: bodyStyle(18),
                  decoration: InputDecoration(
                    hintText: _saved.isNotEmpty
                        ? 'Đã lưu khóa ••••$_saved (dán khóa mới để đổi)'
                        : 'Dán khóa ${info.prefix}… vào đây',
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _show = !_show),
                      icon: Text(_show ? '🙈' : '👁️', style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Dán',
                onPressed: () async {
                  final d = await Clipboard.getData('text/plain');
                  if (d?.text != null) setState(() => _key.text = d!.text!.trim());
                },
                icon: const Text('📥', style: TextStyle(fontSize: 26)),
              ),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                onPressed: _busy ? null : () => _saveAndCheck(provider),
                child: Text(_busy ? '⏳ Đang kiểm tra…' : '💾 Lưu & kiểm tra'),
              ),
              if (_saved.isNotEmpty)
                OutlinedButton(onPressed: () => _delete(provider), child: const Text('🗑️ Xóa khóa')),
            ]),
            if (_status.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_status,
                    style: bodyStyle(17, _statusOk ? AppColors.success : const Color(0xFFE0457B), FontWeight.w800)),
              ),
            const SizedBox(height: 6),
            Text(
                '🔒 Khóa được lưu mã hóa trên máy tính bảng này. Khi bé hỏi Cú, khóa được gửi kèm qua kết nối bảo mật; '
                'máy chủ chỉ dùng cho lượt đó, không lưu lại. Chưa có khóa hợp lệ thì Cú tự dùng AI mặc định.',
                style: bodyStyle(14, Colors.grey.shade600, FontWeight.w500)),
          ]),
        ),
        const SizedBox(height: 10),
        Row(children: [
          SizedBox(width: 160, child: Text('Mức thông minh', style: bodyStyle(18, AppColors.ink, FontWeight.w800))),
          Expanded(
            child: Wrap(spacing: 8, children: [
              for (final e
                  in const {'tiet_kiem': 'Tiết kiệm', 'can_bang': 'Cân bằng', 'thong_minh': 'Thông minh'}.entries)
                ChoiceChip(
                  label: Text(e.value, style: bodyStyle(17)),
                  selected: s.tier == e.key,
                  onSelected: (_) => ref.read(settingsProvider.notifier).save(s.copyWith(tier: e.key)),
                ),
            ]),
          ),
        ]),
        Text('Áp dụng cho ChatGPT và Claude: "Thông minh" giải bài khó tốt hơn nhưng tốn tiền hơn.',
            style: bodyStyle(14, Colors.grey.shade600, FontWeight.w500)),
      ],
    ]);
  }
}
