import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../models/child_profile.dart';
import '../../theme/app_theme.dart';
import 'profile_form.dart';

/// Thêm / sửa hồ sơ bé (mở từ Góc phụ huynh).
class ProfileFormScreen extends ConsumerWidget {
  const ProfileFormScreen({super.key, this.existing});
  final ChildProfile? existing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        title: Text(existing == null ? 'Thêm bé' : 'Sửa hồ sơ bé', style: titleStyle(28)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ProfileForm(
          existing: existing,
          saveLabel: 'Lưu',
          onSave: (p) async {
            await ref.read(profilesProvider.notifier).upsert(p, makeActive: existing == null);
            if (context.mounted) context.pop();
          },
        ),
      ),
    );
  }
}
