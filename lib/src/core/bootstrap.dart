import 'package:hive_flutter/hive_flutter.dart';
import 'router.dart';
import 'services/local_storage.dart';

// FIX: removed 'late final AppTheme theme = AppTheme()' — AppTheme is now
// fully static so no instance is needed. main.dart accesses AppTheme.light
// and AppTheme.dark directly.

/// Global router instance used by MaterialApp.router
late final appRouter = createRouter();

Future<void> bootstrap() async {
  await Hive.initFlutter();
  await LocalStorage.init();
}
