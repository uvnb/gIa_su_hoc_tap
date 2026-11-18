import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/providers.dart';
import 'features/ask/ask_screen.dart';
import 'features/break_time/break_time_screen.dart';
import 'features/break_time/sleep_screen.dart';
import 'features/capture/capture_screen.dart';
import 'features/capture/crop_screen.dart';
import 'features/games/balloon/balloon_game_screen.dart';
import 'features/games/memory/memory_game_screen.dart';
import 'features/games/blocks/block_game_screen.dart';
import 'features/games/games_hub_screen.dart';
import 'features/games/runner/word_runner_screen.dart';
import 'features/games/wish_screen.dart';
import 'features/home/home_screen.dart';
import 'features/mystery/mystery_box_screen.dart';
import 'features/offline/offline_practice_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/onboarding/profile_form_screen.dart';
import 'features/parent/parent_gate_screen.dart';
import 'features/parent/parent_home_screen.dart';
import 'features/tutor/tutor_screen.dart';
import 'models/child_profile.dart';
import 'models/tutor_models.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final store = ref.read(localStoreProvider);
  return GoRouter(
    initialLocation: store.onboardingDone && store.profiles().isNotEmpty ? '/home' : '/onboarding',
    routes: [
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(
        path: '/capture',
        builder: (_, s) => CaptureScreen(subject: (s.extra as String?) ?? 'math'),
      ),
      GoRoute(
        path: '/crop',
        builder: (_, s) {
          final args = s.extra as (Uint8List, String);
          return CropScreen(bytes: args.$1, subject: args.$2);
        },
      ),
      GoRoute(path: '/ask', builder: (_, s) => AskScreen(subject: (s.extra as String?) ?? 'math')),
      GoRoute(path: '/tutor', builder: (_, s) => TutorScreen(launch: s.extra as TutorLaunch)),
      GoRoute(path: '/mystery', builder: (_, __) => const MysteryBoxScreen()),
      GoRoute(path: '/practice', builder: (_, s) => OfflinePracticeScreen(subject: (s.extra as String?) ?? 'math')),
      GoRoute(path: '/break', builder: (_, __) => const BreakTimeScreen()),
      GoRoute(path: '/games', builder: (_, __) => const GamesHubScreen()),
      GoRoute(path: '/games/blocks', builder: (_, __) => const BlockGameScreen()),
      GoRoute(path: '/games/runner', builder: (_, __) => const WordRunnerScreen()),
      GoRoute(path: '/games/balloon', builder: (_, __) => const BalloonGameScreen()),
      GoRoute(path: '/games/memory', builder: (_, __) => const MemoryGameScreen()),
      GoRoute(path: '/wish', builder: (_, __) => const WishScreen()),
      GoRoute(path: '/sleep', builder: (_, s) => SleepScreen(reason: (s.extra as String?) ?? 'limit')),
      GoRoute(path: '/parent', builder: (_, s) => ParentGateScreen(next: (s.extra as String?) ?? '/parent/home')),
      GoRoute(path: '/parent/home', builder: (_, __) => const ParentHomeScreen()),
      GoRoute(
        path: '/profile',
        builder: (_, s) => ProfileFormScreen(existing: s.extra as ChildProfile?),
      ),
    ],
  );
});
