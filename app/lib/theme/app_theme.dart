import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Bảng màu mục 6.2. KHÔNG dùng màu đỏ cho trạng thái "sai" – dùng tím "suy nghĩ thêm".
class AppColors {
  static const sky = Color(0xFF4FA3FF); // chính
  static const sun = Color(0xFFFFD23F); // phụ
  static const orange = Color(0xFFFF8A3D); // nút hành động
  static const success = Color(0xFF3CCB7F);
  static const think = Color(0xFFB79CFF); // gợi ý / suy nghĩ
  static const cream = Color(0xFFFFF8EC); // nền
  static const ink = Color(0xFF23305A); // chữ
  static const owlBody = Color(0xFFB9824F);
  static const owlBelly = Color(0xFFFFE6C2);
  static const card = Colors.white;
  static const softSky = Color(0xFFE3F0FF);
  static const softThink = Color(0xFFF1EBFF);
}

class AppSizes {
  static const minButton = 64.0; // NFR-10: nút ≥ 64dp
  static const bigButton = 96.0;
  static const body = 22.0; // chữ thân ≥ 20sp
  static const title = 36.0;
  static const radius = 24.0;
}

/// Màn nhỏ (Masstel Tab 10 Edu: 960×600 đơn vị logic) → thu gọn bố cục trò chơi.
bool isCompact(BuildContext context) => MediaQuery.sizeOf(context).width < 1100;

TextStyle titleStyle([double size = AppSizes.title, Color color = AppColors.ink]) =>
    GoogleFonts.baloo2(fontSize: size, fontWeight: FontWeight.w700, color: color, height: 1.15);

TextStyle bodyStyle([double size = AppSizes.body, Color color = AppColors.ink, FontWeight w = FontWeight.w600]) =>
    GoogleFonts.nunito(fontSize: size, fontWeight: w, color: color, height: 1.3);

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.sky,
      primary: AppColors.sky,
      secondary: AppColors.orange,
      surface: AppColors.cream,
      // error dùng tím để không có cảm giác bị phạt
      error: AppColors.think,
    ),
    scaffoldBackgroundColor: AppColors.cream,
  );
  final text = GoogleFonts.nunitoTextTheme(base.textTheme).apply(
    bodyColor: AppColors.ink,
    displayColor: AppColors.ink,
  );
  return base.copyWith(
    textTheme: text.copyWith(
      bodyLarge: bodyStyle(),
      bodyMedium: bodyStyle(20),
      titleLarge: titleStyle(30),
      headlineMedium: titleStyle(36),
      labelLarge: bodyStyle(22, AppColors.ink, FontWeight.w800),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(AppSizes.minButton, AppSizes.minButton),
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
        textStyle: bodyStyle(22, Colors.white, FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radius)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(AppSizes.minButton, AppSizes.minButton),
        foregroundColor: AppColors.ink,
        side: const BorderSide(color: AppColors.sky, width: 3),
        textStyle: bodyStyle(22, AppColors.ink, FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radius)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(AppSizes.minButton, AppSizes.minButton)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    ),
  );
}
