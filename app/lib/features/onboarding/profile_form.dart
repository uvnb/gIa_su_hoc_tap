import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../models/child_profile.dart';
import '../../theme/app_theme.dart';

/// Form hồ sơ bé (FR-02): biệt danh (không bắt buộc tên thật), lớp 1–5, avatar.
class ProfileForm extends StatefulWidget {
  const ProfileForm({super.key, this.existing, required this.onSave, this.saveLabel = 'Xong rồi!'});

  final ChildProfile? existing;
  final ValueChanged<ChildProfile> onSave;
  final String saveLabel;

  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  late final _name = TextEditingController(text: widget.existing?.nickname ?? '');
  late int _grade = widget.existing?.grade ?? 1;
  late String _avatar = widget.existing?.avatar ?? avatarChoices.first;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final nick = _name.text.trim().isEmpty ? 'Bạn nhỏ' : _name.text.trim();
    final p = widget.existing?.copyWith(nickname: nick, grade: _grade, avatar: _avatar) ??
        ChildProfile(id: const Uuid().v4().substring(0, 8), nickname: nick, grade: _grade, avatar: _avatar);
    widget.onSave(p);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Biệt danh của bé', style: titleStyle(26)),
        const SizedBox(height: 6),
        SizedBox(
          width: 420,
          child: TextField(
            controller: _name,
            maxLength: 16,
            style: bodyStyle(26),
            decoration: const InputDecoration(hintText: 'Ví dụ: Bông, Bin, Su…', counterText: ''),
          ),
        ),
        Text('Không cần tên thật.', style: bodyStyle(18, Colors.grey.shade700, FontWeight.w500)),
        const SizedBox(height: 16),
        Text('Bé học lớp mấy?', style: titleStyle(26)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: [
            for (var g = 1; g <= 5; g++)
              ChoiceChip(
                label: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text('Lớp $g', style: titleStyle(24)),
                ),
                selected: _grade == g,
                selectedColor: AppColors.sun,
                onSelected: (_) => setState(() => _grade = g),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Chọn hình đại diện', style: titleStyle(26)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final a in avatarChoices)
              GestureDetector(
                onTap: () => setState(() => _avatar = a),
                child: Container(
                  width: 72,
                  height: 72,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _avatar == a ? AppColors.sun : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: _avatar == a ? AppColors.orange : Colors.grey.shade300, width: 4),
                  ),
                  child: Text(a, style: const TextStyle(fontSize: 38)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 22),
        ElevatedButton(onPressed: _save, child: Text(widget.saveLabel)),
      ],
    );
  }
}
