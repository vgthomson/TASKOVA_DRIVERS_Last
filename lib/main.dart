import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:taskova_drivers/Controller/Theme/theme.dart';
import 'package:taskova_drivers/Model/Notifications/notification_helper.dart';
import 'package:taskova_drivers/View/Language/language_provider.dart';
import 'package:taskova_drivers/View/splashscreen.dart';

void main() async {
  await runZonedGuarded(() async {
    // ✅ Now it's in the same zone as runApp()
    WidgetsFlutterBinding.ensureInitialized();

    try {
      // Load .env
      await dotenv.load(fileName: ".env").catchError((error) {
        debugPrint("⚠️ Error loading .env: $error");
        dotenv.env['BASE_URL'] ??= 'https://default-fallback-url.com';
      });

      // Firebase
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          // options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      final app = Firebase.app();
      print("🔥 Firebase App name: ${app.name}");

      // Notifications
      await NotificationHelper.initialize();

      // Run App
      runApp(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => AppLanguage()),
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ],
          child: const MyApp(),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint("🔥 App initialization failed: $e\n$stackTrace");
      runApp(
        const CupertinoApp(
          home: Scaffold(
            body: Center(child: Text('Initialization Error')),
          ),
        ),
      );
    }
  }, (error, stackTrace) {
    debugPrint("🔥 Uncaught Zone error: $error\n$stackTrace");
  });
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final brightness = MediaQuery.platformBrightnessOf(context);

        return CupertinoApp(
          debugShowCheckedModeBanner: false,
          theme: CupertinoThemeData(
            brightness: themeProvider.followSystemTheme
                ? brightness
                : (themeProvider.isDarkMode ? Brightness.dark : Brightness.light),
          ),
          home: const SplashScreen(),
        );
      },
    );
  }
}
