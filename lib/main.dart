import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'defines/ly_colors.dart';
import 'defines/ly_constants.dart';
import 'pages/home/home_page.dart';

/// 注释：MacNTFS Pro 应用程序入口
/// 时间：2026/08/16 12:20
/// 作者：郭翰林
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MacNtfsApp());
}

class MacNtfsApp extends StatelessWidget {
  const MacNtfsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(1024, 768),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return GetMaterialApp(
          title: LyConstants.appName,
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.system,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            colorSchemeSeed: LyColors.primary,
            scaffoldBackgroundColor: LyColors.bgLight,
            fontFamily: '-apple-system',
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            colorSchemeSeed: LyColors.primary,
            scaffoldBackgroundColor: LyColors.bgDark,
            fontFamily: '-apple-system',
          ),
          home: const HomePage(),
        );
      },
    );
  }
}
