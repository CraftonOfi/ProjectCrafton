import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'src/config/app_config.dart';
import 'src/config/router_config.dart';
import 'src/config/theme_config.dart';
import 'src/services/storage_service.dart';
// Firebase is optional; on web without proper setup it can fail, so we keep this guarded.
// import 'package:firebase_core/firebase_core.dart';
// import 'firebase_options.dart'; // If using FlutterFire CLI

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase (guarded). If not configured, it won't crash in dev.
  // Firebase.initializeApp is disabled by default to avoid web build issues.
  // When you add Firebase configs (and target mobile), you can re-enable this.
  // try {
  //   await Firebase.initializeApp(
  //       // options: DefaultFirebaseOptions.currentPlatform,
  //       );
  // } catch (e) {
  //   if (kDebugMode) {
  //     debugPrint('Firebase init skipped or failed: $e');
  //   }
  // }

  // Configurar orientación
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Inicializar Hive para almacenamiento local
  await Hive.initFlutter();
  await StorageService.init();

  // Inicializar localización por defecto (es-ES) para intl
  Intl.defaultLocale =
      const String.fromEnvironment('APP_LOCALE', defaultValue: 'es_ES');
  try {
    await initializeDateFormatting(Intl.defaultLocale);
  } catch (_) {
    // fallback para evitar crash si el browser no soporta el locale exacto
    await initializeDateFormatting('es');
  }

  await SentryFlutter.init(
    (o) {
      o.dsn = const String.fromEnvironment('SENTRY_DSN', defaultValue: '');
      o.tracesSampleRate = 0.2;
      o.enableAutoPerformanceTracing = true;
      o.sendDefaultPii = false;
    },
    appRunner: () => runApp(
      const ProviderScope(
        observers: [SentryRiverpodObserver()],
        child: MyApp(),
      ),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ScreenUtilInit(
      designSize: const Size(375, 812), // iPhone 12 Pro
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MaterialApp.router(
          title: AppConfig.appName,
          debugShowCheckedModeBanner: false,
          theme: ThemeConfig.lightTheme,
          darkTheme: ThemeConfig.darkTheme,
          themeMode: ThemeMode.system,
          routerConfig: AppRouterConfig.router,
          // MaterialApp.router no acepta navigatorObservers directamente; Sentry observa GoRouter internamente
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            // Accesibilidad: respetar escalado de texto con límites suaves
            final clamped =
                mq.textScaler.clamp(minScaleFactor: 1.0, maxScaleFactor: 1.3);
            // Reducir animaciones si el usuario lo solicita
            final disableAnims = mq.disableAnimations;
            return MediaQuery(
              data: mq.copyWith(textScaler: clamped),
              child: Theme(
                data: Theme.of(context).copyWith(
                  pageTransitionsTheme: disableAnims
                      ? const PageTransitionsTheme(builders: {
                          TargetPlatform.android: NoTransitionsBuilder(),
                          TargetPlatform.iOS: NoTransitionsBuilder(),
                          TargetPlatform.macOS: NoTransitionsBuilder(),
                          TargetPlatform.windows: NoTransitionsBuilder(),
                          TargetPlatform.linux: NoTransitionsBuilder(),
                          TargetPlatform.fuchsia: NoTransitionsBuilder(),
                        })
                      : Theme.of(context).pageTransitionsTheme,
                ),
                child: child!,
              ),
            );
          },
        );
      },
    );
  }
}

class NoTransitionsBuilder extends PageTransitionsBuilder {
  const NoTransitionsBuilder();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

class SentryRiverpodObserver extends ProviderObserver {
  const SentryRiverpodObserver();
}
