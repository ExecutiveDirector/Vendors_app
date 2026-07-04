import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'src/core/bootstrap.dart';
import 'src/core/theme.dart';
import 'src/core/services/push_notification_service.dart';
import 'src/core/services/notification_watcher_service.dart';
import 'src/core/services/local_storage.dart';
// Contains real Android config values extracted from
// android/app/google-services.json. Does NOT cover iOS or web — see the
// comment inside that file for how to add those via `flutterfire configure`
// if/when needed.
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await PushNotificationService.init();

  // ── Global error visibility ─────────────────────────────────────────────
  // Without this, uncaught framework errors and uncaught async errors
  // outside the widget tree are either silently swallowed in release mode
  // or just crash with no record anywhere visible after the fact.
  //
  // This currently only logs to console. Since the Firebase project
  // already exists (used for FCM above), the natural next step is Firebase
  // Crashlytics — add `firebase_crashlytics` to pubspec.yaml, then replace
  // the two debugPrint calls below with
  // FirebaseCrashlytics.instance.recordFlutterFatalError(details) and
  // FirebaseCrashlytics.instance.recordError(error, stack, fatal: true).
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('🔴 Uncaught Flutter error: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('🔴 Uncaught async error: $error\n$stack');
    return true;
  };

  // Lock to portrait by default; remove if landscape is needed
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));

  await bootstrap();

  // If the vendor is already logged in from a previous session, start
  // listening for notifications right away rather than waiting for them
  // to hit the Notifications screen. On a fresh login, this is instead
  // kicked off from login_screen.dart once a token is issued.
  final existingToken = await LocalStorage.getToken();
  if (existingToken != null) {
    NotificationWatcherService.instance.start();
  }

  runApp(const VendorApp());
}

class VendorApp extends StatelessWidget {
  const VendorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'AquaGas Vendor',
      // FIX: AppTheme.light / .dark are now static getters — no instance needed
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
    );
  }
}