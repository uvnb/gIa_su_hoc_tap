import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_router.dart';
import 'core/local_store.dart';
import 'core/providers.dart';
import 'core/sound_service.dart';
import 'core/tts_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Bố cục ngang là chính (màn 1280×800, trẻ cầm ngang).
  await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final store = LocalStore();
  await store.init();
  final settings = store.settings();

  final tts = TtsService();
  final sound = SoundService()..enabled = settings.soundEffects;
  // Không chờ TTS/âm thanh để mở app nhanh (NFR-01 < 3 giây).
  tts.init(rate: settings.ttsRate, pitch: settings.ttsPitch);
  sound.init();

  runApp(ProviderScope(
    overrides: [
      localStoreProvider.overrideWithValue(store),
      ttsProvider.overrideWithValue(tts),
      soundProvider.overrideWithValue(sound),
    ],
    child: const CuToMoApp(),
  ));
}

class CuToMoApp extends ConsumerWidget {
  const CuToMoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Cú Tò Mò',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: router,
      // Chữ to sẵn; không cho cỡ chữ hệ thống phóng quá lớn làm vỡ bố cục.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 1.0, maxScaleFactor: 1.15)),
          child: child!,
        );
      },
    );
  }
}
