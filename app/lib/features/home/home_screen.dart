import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/local_store.dart';
import '../../core/providers.dart';
import '../../models/child_profile.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/owl_view.dart';
import '../../widgets/sky_background.dart';
import '../../widgets/web_help.dart';
import '../vietnam/vietnam_content.dart';

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
      // Máy chủ Cloud Run tự tắt khi không ai dùng → gọi trước để "đánh thức", lúc bé chụp bài khỏi chờ lâu.
      ref.read(apiProvider).health().catchError((_) => false);
      ref.read(deviceServiceProvider).ensureRegistered();
      final child = ref.read(activeChildProvider);
      if (!_greetedThisLaunch && child != null) {
        _greetedThisLaunch = true;
        _greet(child);
      }
    });
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _waving = false);
    });
  }

  /// Lời chào: lần mở app đầu tiên trong ngày phát lời chào bố mẹ ghi âm (nếu có), còn lại Cú chào.
  Future<void> _greet(ChildProfile child) async {
    final store = ref.read(localStoreProvider);
    final key = 'greet|${child.id}|${LocalStore.dayKey(DateTime.now())}';
    if (store.metaString(key) == null) {
      await store.setMeta(key, '1');
      final played = await ref.read(parentVoiceProvider).play('greeting', childId: child.id, cooldown: Duration.zero);
      if (played) return;
    }
    ref.read(ttsProvider).say('Chào ${child.nickname}! Hôm nay mình học gì nào?');
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
      body: SkyBackground(
        child: SafeArea(
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
                                Bobbing(
                                  amplitude: 7,
                                  period: 2600,
                                  child: OwlView(mood: _waving ? 'celebrating' : 'idle', size: 230, waving: _waving),
                                ),
                                const SizedBox(height: 8),
                                const OwlSpeech(text: 'Hôm nay mình học gì nào?', maxWidth: 460),
                                const SizedBox(height: 8),
                                _factChip(),
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
                // 4 nút chia đều bề ngang (màn tablet chỉ 960 đơn vị logic)
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 7),
                        child: BigButton(
                          width: double.infinity,
                          height: 150,
                          emoji: '📸',
                          label: 'Chụp bài',
                          color: AppColors.orange,
                          onTap: () {
                            if (_guard()) context.push('/capture', extra: subject);
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 7),
                        child: BigButton(
                          width: double.infinity,
                          height: 150,
                          emoji: '🎤',
                          label: 'Hỏi Cú',
                          color: AppColors.sky,
                          onTap: () {
                            if (_guard()) context.push('/ask', extra: subject);
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 7),
                        child: BigButton(
                          width: double.infinity,
                          height: 150,
                          emoji: '🎁',
                          label: 'Hộp bí ẩn',
                          color: AppColors.think,
                          onTap: () {
                            if (_guard()) context.push('/mystery');
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 7),
                        child: BigButton(
                          width: double.infinity,
                          height: 150,
                          emoji: '🎮',
                          label: 'Trò chơi',
                          color: AppColors.success,
                          onTap: () => context.push('/games'),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _islands(subject),
              ],
            ),
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
          Stack(clipBehavior: Clip.none, children: [
            IconButton(
              tooltip: 'Góc phụ huynh',
              onPressed: () => context.push('/parent'),
              icon: const Text('⚙️', style: TextStyle(fontSize: 34)),
            ),
            // bé gửi điều ước mà bố mẹ chưa xem
            if (ref.watch(pendingWishCountProvider) > 0)
              const Positioned(
                  right: -2, top: -4, child: IgnorePointer(child: Text('💌', style: TextStyle(fontSize: 26)))),
          ]),
        ],
      );

  /// 💡 "Bạn có biết?" – một điều về lịch sử, địa lý, văn hóa Việt Nam, đổi mỗi ngày.
  Widget _factChip() {
    final f = factOfTheDay();
    return PressBounce(
      child: GestureDetector(
        onTap: () {
          ref.read(ttsProvider).say('Bạn có biết? ${f.fact}');
          context.push('/vietnam', extra: topicOf(f).id);
        },
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFFFF3C4), Color(0xFFFFE0EC)]),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.sun, width: 2),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(f.emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 8),
            Flexible(
              child: Text('💡 Bạn có biết? ${f.fact}',
                  maxLines: 2, overflow: TextOverflow.ellipsis, style: bodyStyle(17, AppColors.ink, FontWeight.w700)),
            ),
          ]),
        ),
      ),
    );
  }

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
    void open(String key, String label) {
      ref.read(currentSubjectProvider.notifier).state = key;
      ref.read(soundProvider).pop();
      if (key == 'english') {
        context.push('/english');
      } else if (key == 'vietnam') {
        context.push('/vietnam');
      } else if (key == 'friend') {
        context.push('/friend');
      } else {
        ref.read(ttsProvider).say('Đảo $label');
      }
    }

    final practice = subject == 'english'
        ? ('🇬🇧 Học từ, nghe, nói Tiếng Anh', () => context.push('/english'))
        : (
            '🧩 Luyện tập',
            () {
              if (_guard()) context.push('/practice', extra: 'math');
            }
          );
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Island(emoji: '🔢', label: 'Toán', selected: subject == 'math', phase: 0, onTap: () => open('math', 'Toán')),
          const SizedBox(width: 12),
          _Island(
              emoji: '📖',
              label: 'Tiếng Việt',
              selected: subject == 'vietnamese',
              phase: 0.33,
              onTap: () => open('vietnamese', 'Tiếng Việt')),
          const SizedBox(width: 12),
          _Island(
              emoji: '🔤',
              label: 'Tiếng Anh',
              selected: subject == 'english',
              phase: 0.66,
              onTap: () => open('english', 'Tiếng Anh')),
          const SizedBox(width: 12),
          _Island(
              emoji: '🇻🇳',
              label: 'Việt Nam',
              selected: false,
              phase: 0.2,
              isNew: true,
              onTap: () => open('vietnam', 'Việt Nam')),
          const SizedBox(width: 12),
          _Island(
              emoji: '💛',
              label: 'Tâm sự',
              selected: false,
              phase: 0.5,
              isNew: true,
              onTap: () => open('friend', 'Tâm sự')),
          const SizedBox(width: 18),
          PressBounce(
            child: TextButton(
              onPressed: practice.$2,
              style: TextButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.75)),
              child: Text(practice.$1, style: bodyStyle(20, AppColors.sky, FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hòn đảo môn học: nhún nhẹ trên sóng; đảo đang chọn nổi lên, có viền sáng.
class _Island extends StatelessWidget {
  const _Island({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.phase,
    required this.onTap,
    this.isNew = false,
  });
  final String emoji, label;
  final bool selected, isNew;
  final double phase;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressBounce(
      child: GestureDetector(
        onTap: onTap,
        child: Bobbing(
          phase: phase,
          amplitude: selected ? 4 : 2,
          period: 2400,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            padding: const EdgeInsets.fromLTRB(14, 6, 18, 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors:
                    selected ? const [Color(0xFF8BE3A9), AppColors.success] : const [Colors.white, Color(0xFFEAF6FF)],
              ),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(color: selected ? Colors.white : const Color(0xFFBFE3FF), width: 3),
              boxShadow: [
                BoxShadow(
                  color: (selected ? AppColors.success : AppColors.sky).withValues(alpha: selected ? 0.45 : 0.15),
                  blurRadius: selected ? 14 : 6,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Text('🏝️', style: TextStyle(fontSize: 26)),
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 6),
              Text(label, style: bodyStyle(20, selected ? Colors.white : AppColors.ink, FontWeight.w800)),
              if (isNew && !selected) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: const Color(0xFFFF8FB1), borderRadius: BorderRadius.circular(10)),
                  child: Text('MỚI', style: bodyStyle(12, Colors.white, FontWeight.w900)),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
