import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'src/core/bootstrap.dart';
import 'src/core/theme.dart';
import 'src/core/services/push_notification_service.dart';
import 'src/core/services/notification_watcher_service.dart';
import 'src/core/services/incoming_order_service.dart';
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

  // ── Crash and error reporting ───────────────────────────────────────────
  // Sentry hooks FlutterError.onError / PlatformDispatcher.onError itself;
  // we then chain our console logging on top of those handlers so nothing
  // is lost. Never sends personal data, screenshots or performance traces.
  // A Sentry DSN only lets clients send events (it is not a secret); a build
  // can override it with --dart-define=SENTRY_DSN=....
  try {
    await SentryFlutter.init((o) {
      const fromBuild = String.fromEnvironment('SENTRY_DSN');
      o.dsn = fromBuild.isNotEmpty
          ? fromBuild
          : 'https://140b851a0b9901e6a9674273921fa5e5@o4512316675588096.ingest.de.sentry.io/4512317082566736';
      o.environment =
          const String.fromEnvironment('APP_ENV', defaultValue: 'production');
      o.sendDefaultPii = false;
      o.attachScreenshot = false;
      o.tracesSampleRate = 0;
    });
    Sentry.configureScope((scope) => scope.setTag('app', 'vendor'));
  } catch (e) {
    debugPrint('[Sentry] Init failed (non-fatal): $e');
  }

  final sentryFlutterHandler = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('🔴 Uncaught Flutter error: ${details.exceptionAsString()}');
    if (sentryFlutterHandler != null) {
      sentryFlutterHandler(details);
    } else {
      FlutterError.presentError(details);
    }
  };
  final sentryAsyncHandler = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('🔴 Uncaught async error: $error\n$stack');
    sentryAsyncHandler?.call(error, stack);
    return true;
  };

  // Lock to portrait by default; remove if landscape is needed
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
  ));

  await bootstrap();

  // If the vendor is already logged in from a previous session, start
  // listening for notifications right away rather than waiting for them
  // to hit the Notifications screen. On a fresh login, this is instead
  // kicked off from login_screen.dart once a token is issued.
  final existingToken = await LocalStorage.getToken();
  if (existingToken != null) {
    NotificationWatcherService.instance.start();
    IncomingOrderService.instance.start();
    // The token was previously only sent at a fresh login, so after an app
    // restart (or a token change) the server had no/old token and pushes
    // never reached a sleeping phone.
    PushNotificationService.registerTokenWithBackend();
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
      // Respect the user's font-size setting, but cap it so layouts stay
      // usable at the extremes (and never shrink below a readable size).
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: mq.textScaler
                .clamp(minScaleFactor: 0.9, maxScaleFactor: 1.4),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}