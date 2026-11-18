import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/owl_view.dart';
import '../../widgets/sky_background.dart';
import 'english_content.dart';
import 'english_progress.dart';

/// 🏝️ Đảo Tiếng Anh: chọn chủ đề (chào hỏi, màu sắc, số đếm, con vật…) → học từ, nghe, ghép chữ, nói.
/// Bé cũng chụp bài / hỏi Cú bằng môn Tiếng Anh từ đây.
class EnglishIslandScreen extends ConsumerStatefulWidget {
  const EnglishIslandScreen({super.key});

  @override
  ConsumerState<EnglishIslandScreen> createState() => _EnglishIslandScreenState();
}

class _EnglishIslandScreenState extends ConsumerState<EnglishIslandScreen> {
  static const _cardColors = [
    [Color(0xFFFF8FB1), Color(0xFFFFB547)],
    [Color(0xFF5EB8FF), Color(0xFF6BD49A)],
    [Color(0xFFB08CFF), Color(0xFF5EB8FF)],
    [Color(0xFFFFB547), Color(0xFFFF7A6B)],
    [Color(0xFF4FD1C5), Color(0xFF5EB8FF)],
    [Color(0xFF6BD49A), Color(0xFFFFD23F)],
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final tts = ref.read(ttsProvider);
      await tts.sayEnglish('Hello! Welcome to English Island!');
      await tts.say('Chào mừng bạn đến đảo Tiếng Anh! Chọn một chủ đề để học nhé.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final child = ref.watch(activeChildProvider);
    final store = ref.read(localStoreProvider);
    final compact = isCompact(context);
    final grade = child?.grade ?? 1;
    return Scaffold(
      body: SkyBackground(
        theme: SkyTheme.ocean,
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(compact ? 14 : 22, 8, compact ? 14 : 22, 10),
            child: Column(children: [
              Row(children: [
                PressBounce(
                  child: OutlinedButton(
                    onPressed: () => context.go('/home'),
                    style: OutlinedButton.styleFrom(backgroundColor: Colors.white),
                    child: const Text('← Về nhà'),
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text('🏝️ Đảo Tiếng Anh',
                      overflow: TextOverflow.ellipsis, style: titleStyle(compact ? 30 : 38, const Color(0xFF1E6FB8))),
                ),
                const Spacer(),
                if (child != null) StarBadge(stars: child.stars),
              ]),
              const SizedBox(height: 8),
              Expanded(
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(
                    width: compact ? 210 : 280,
                    child: Column(children: [
                      Bobbing(child: OwlView(mood: 'celebrating', size: compact ? 120 : 160)),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
                        child: Column(children: [
                          Text('Hello! 👋', style: titleStyle(compact ? 26 : 30, const Color(0xFF1E6FB8))),
                          Text('Chọn chủ đề để học từ, nghe, ghép chữ và nói tiếng Anh nhé!',
                              textAlign: TextAlign.center, style: bodyStyle(compact ? 16 : 19)),
                        ]),
                      ),
                      const Spacer(),
                      _sideButton('📸', 'Chụp bài Tiếng Anh', AppColors.orange,
                          () => context.push('/capture', extra: 'english')),
                      const SizedBox(height: 10),
                      _sideButton(
                          '🎤', 'Hỏi Cú Tiếng Anh', AppColors.sky, () => context.push('/ask', extra: 'english')),
                    ]),
                  ),
                  SizedBox(width: compact ? 12 : 20),
                  Expanded(
                    child: LayoutBuilder(builder: (context, box) {
                      final cols = box.maxWidth > 900 ? 4 : 3;
                      return GridView.builder(
                        padding: const EdgeInsets.only(bottom: 30),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.15,
                        ),
                        itemCount: enTopics.length,
                        itemBuilder: (_, i) {
                          final t = enTopics[i];
                          final p = child == null ? const EnProgress() : EnProgress.load(store, child.id, t.id);
                          return PopIn(
                            delay: 60 * i,
                            child: _TopicCard(
                              topic: t,
                              colors: _cardColors[i % _cardColors.length],
                              stars: p.stars(t.words.length),
                              harder: t.minGrade > grade,
                              phase: i * 0.17,
                              onTap: () async {
                                ref.read(soundProvider).pop();
                                await context.push('/english/topic', extra: t.id);
                                if (mounted) setState(() {}); // cập nhật ⭐ sau khi học
                              },
                            ),
                          );
                        },
                      );
                    }),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _sideButton(String emoji, String label, Color color, VoidCallback onTap) => PressBounce(
        child: Material(
          color: color,
          borderRadius: BorderRadius.circular(22),
          elevation: 3,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () {
              ref.read(soundProvider).pop();
              onTap();
            },
            child: SizedBox(
              width: double.infinity,
              height: 64,
              child: Center(
                child: Text('$emoji $label', style: bodyStyle(18, Colors.white, FontWeight.w800)),
              ),
            ),
          ),
        ),
      );
}

class _TopicCard extends StatelessWidget {
  const _TopicCard({
    required this.topic,
    required this.colors,
    required this.stars,
    required this.harder,
    required this.phase,
    required this.onTap,
  });
  final EnTopic topic;
  final List<Color> colors;
  final int stars;
  final bool harder;
  final double phase;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressBounce(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        elevation: 4,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors),
            ),
            child: Stack(children: [
              // vệt bóng sáng
              Positioned(
                left: 12,
                top: 8,
                child: Container(
                  width: 60,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Bobbing(phase: phase, amplitude: 4, child: Text(topic.emoji, style: const TextStyle(fontSize: 54))),
                    Text(topic.en, style: titleStyle(26, Colors.white)),
                    Text(topic.vi, style: bodyStyle(17, Colors.white, FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('${'⭐' * stars}${'☆' * (4 - stars)}',
                        style: const TextStyle(fontSize: 18, color: Colors.white)),
                  ]),
                ),
              ),
              if (harder)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: Text('Khó hơn', style: bodyStyle(12, colors.first, FontWeight.w800)),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }
}
