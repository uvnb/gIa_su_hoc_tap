import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_router.dart';
import 'core/local_store.dart';
import 'core/music_service.dart';
import 'core/parent_voice_service.dart';
import 'core/providers.dart';
import 'core/sound_service.dart';
import 'core/tts_service.dart';
import 'theme/app_theme.dart';
import 'widgets/parent_voice_banner.dart';

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
  // Không chờ TTS/âm thanh để mở app nhanh (NFR-01 < 3 giây). Lỗi ở đây không được làm dừng app.
  tts
      .init(rate: settings.ttsRate, pitch: settings.ttsPitch, voice: settings.voiceName)
      .catchError((Object e) => debugPrint('TTS: $e'));
  sound.init().catchError((Object e) => debugPrint('Âm thanh: $e'));
  final music = MusicService()..enabled = settings.gameMusic;
  music.init().catchError((Object e) => debugPrint('Nhạc: $e'));
  // Cú nói → nhạc nền nhỏ lại cho bé nghe rõ.
  tts.speaking.addListener(() => music.duck(tts.speaking.value));
  final parentVoice = ParentVoiceService(store, tts, music);

  runApp(ProviderScope(
    overrides: [
      localStoreProvider.overrideWithValue(store),
      ttsProvider.overrideWithValue(tts),
      soundProvider.overrideWithValue(sound),
      musicProvider.overrideWithValue(music),
      parentVoiceProvider.overrideWithValue(parentVoice),
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
          // Băng "💌 Lời nhắn của bố mẹ" nổi trên mọi màn khi đang phát ghi âm của bố mẹ.
          child: Stack(children: [child!, const ParentVoiceBanner()]),
        );
      },
    );
  }
}
