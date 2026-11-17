import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../models/child_profile.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/owl_view.dart';
import '../../widgets/web_help.dart';

/// Môn đang chọn (đảo trên màn chính).
final currentSubjectProvider = StateProvider<String>((ref) => 'math');

bool _greetedThisLaunch = false;

/// Màn chính (mục 6.4): Cú chào → [Chụp bài] [Hỏi Cú] [Hộp bí ẩn] + các hòn đảo môn học.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _waving = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(studyTimerProvider.notifier).refresh();
      ref.read(deviceServiceProvider).ensureRegistered();
      final child = ref.read(activeChildProvider);
      if (!_greetedThisLaunch && child != null) {
        _greetedThisLaunch = true;
        ref.read(ttsProvider).say('Chào ${child.nickname}! Hôm nay mình học gì nào?');
      }
    });
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _waving = false);
    });
  }

  /// Hết giờ học / giờ ngủ → Cú đi ngủ, khóa phiên mới (FR-51, FR-52).
  bool _guard() {
    final st = ref.read(studyTimerProvider);
    if (st.bedtime) {
      context.push('/sleep', extra: 'bedtime');
      return false;
    }
    if (st.limitReached) {
      context.push('/sleep', extra: 'limit');
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final child = ref.watch(activeChildProvider);
    final profiles = ref.watch(profilesProvider).list;
    final subject = ref.watch(currentSubjectProvider);
    ref.watch(studyTimerProvider);
    if (child == null) {
      return Scaffold(
        body: Center(
          child: ElevatedButton(onPressed: () => context.go('/onboarding'), child: const Text('Tạo hồ sơ bé')),
        ),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
          child: Column(
            children: [
              _topBar(child, profiles),
              Expanded(
                child: Row(
                  children: [
                    // FittedBox: màn thấp (trình duyệt có thanh địa chỉ) thì thu nhỏ, không đè lên các nút lớn.
                    Expanded(
                      flex: 5,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              OwlView(mood: _waving ? 'celebrating' : 'idle', size: 230, waving: _waving),
                              const SizedBox(height: 8),
                              const OwlSpeech(text: 'Hôm nay mình học gì nào?', maxWidth: 460),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: FittedBox(fit: BoxFit.scaleDown, child: _growthCard(child)),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  BigButton(
                    emoji: '📸',
                    label: 'Chụp bài',
                    color: AppColors.orange,
                    onTap: () {
                      if (_guard()) context.push('/capture', extra: subject);
                    },
                  ),
                  BigButton(
                    emoji: '🎤',
                    label: 'Hỏi Cú',
                    color: AppColors.sky,
                    onTap: () {
                      if (_guard()) context.push('/ask', extra: subject);
                    },
                  ),
                  BigButton(
                    emoji: '🎁',
                    label: 'Hộp bí ẩn',
                    color: AppColors.think,
                    onTap: () {
                      if (_guard()) context.push('/mystery');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _islands(subject),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(ChildProfile child, List<ChildProfile> profiles) => Row(
        children: [
          Text('🦉 Chào ${child.nickname}!', style: titleStyle(34)),
          const SizedBox(width: 16),
          const WebPermissionBanner(),
          const Spacer(),
          StarBadge(stars: child.stars),
          const SizedBox(width: 16),
          // FR-03: chuyển hồ sơ bằng chạm avatar
          for (final p in profiles)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: GestureDetector(
                onTap: () {
                  ref.read(profilesProvider.notifier).setActive(p.id);
                  ref.read(studyTimerProvider.notifier).refresh();
                  ref.read(ttsProvider).say('Chào ${p.nickname}!');
                },
                child: Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p.id == child.id ? AppColors.sun : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: p.id == child.id ? AppColors.orange : Colors.grey.shade300, width: 3),
                  ),
                  child: Text(p.avatar, style: const TextStyle(fontSize: 34)),
                ),
              ),
            ),
          const SizedBox(width: 10),
          IconButton(
            tooltip: 'Góc phụ huynh',
            onPressed: () => context.push('/parent'),
            icon: const Text('⚙️', style: TextStyle(fontSize: 34)),
          ),
        ],
      );

  Widget _growthCard(ChildProfile child) {
    final stage = child.owlStage;
    final next = stage < 3 ? ChildProfile.stageThresholds[stage + 1] : null;
    return Container(
      width: 360,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Cú của ${child.nickname}', style: titleStyle(24)),
          OwlView(mood: 'idle', size: 130, stage: stage),
          Text(ChildProfile.stageNames[stage], style: titleStyle(26, AppColors.sky)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: child.stageProgress,
              minHeight: 16,
              backgroundColor: AppColors.softSky,
              color: AppColors.success,
            ),
          ),
          const SizedBox(height: 6),
          Text(next == null ? 'Cú đã thông thái rồi! 🎓' : 'Còn ${next - child.stars} ⭐ nữa Cú sẽ lớn!',
              style: bodyStyle(18)),
        ],
      ),
    );
  }

  Widget _islands(String subject) {
    Widget island(String key, String label, {bool soon = false}) {
      final selected = subject == key && !soon;
      return GestureDetector(
        onTap: soon
            ? () => ref.read(ttsProvider).say('Đảo $label sắp mở rồi, bạn chờ nhé!')
            : () {
                ref.read(currentSubjectProvider.notifier).state = key;
                ref.read(soundProvider).pop();
                ref.read(ttsProvider).say('Đảo $label');
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: soon ? Colors.grey.shade200 : (selected ? AppColors.success : Colors.white),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: selected ? AppColors.success : AppColors.softSky, width: 3),
          ),
          child: Text('🏝️ $label${soon ? ' (sắp mở)' : ''}',
              style: bodyStyle(20, selected ? Colors.white : AppColors.ink, FontWeight.w800)),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        island('math', 'Toán'),
        const SizedBox(width: 14),
        island('vietnamese', 'Tiếng Việt'),
        const SizedBox(width: 14),
        island('english', 'Tiếng Anh', soon: true),
        const SizedBox(width: 30),
        TextButton(
          onPressed: () {
            if (_guard()) context.push('/practice', extra: 'math');
          },
          child: Text('🧩 Luyện tập (không cần mạng)', style: bodyStyle(20, AppColors.sky, FontWeight.w800)),
        ),
      ],
    );
  }
}
