import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/data_service.dart';
import 'services/settings_service.dart';
import 'services/progress_service.dart';
import 'services/audio_service.dart';
import 'services/activity_service.dart';
import 'services/route_observer.dart';
import 'services/notification_bridge.dart';
import 'notifications/notifications.dart';
import 'theming/theme_definition.dart';
import 'theming/theme_controller.dart';
import 'theming/theme_scope.dart';
import 'theming/theme_tokens.dart';
import 'widgets/themed/themed_surface.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NihongoTrainerApp());
}

class NihongoTrainerApp extends StatelessWidget {
  const NihongoTrainerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsService()),
        ChangeNotifierProvider(create: (_) => ProgressService()),
        ChangeNotifierProvider(create: (_) => AudioService()),
        ChangeNotifierProvider(create: (_) => ActivityService()),
        ChangeNotifierProvider(create: (_) => ThemeController()),
        ChangeNotifierProvider(create: (_) => NotificationSettingsService()),
      ],
      // Only the MaterialApp is rebuilt when the theme changes -- the
      // Navigator and everything in it keeps its state, so switching themes
      // mid-lesson doesn't lose your place, your score or your review queue.
      child: Consumer<ThemeController>(
        builder: (context, themeController, _) {
          final theme = themeController.theme;
          return MaterialApp(
            title: 'Nihongo Trainer',
            debugShowCheckedModeBanner: false,
            navigatorKey: appNavigatorKey,
            theme: theme.buildMaterialTheme(),
            navigatorObservers: [appRouteObserver],
            // builder wraps the Navigator, so every pushed route sees the
            // ThemeScope -- not just the home screen.
            builder: (context, child) => ThemeScope(
              theme: theme,
              effectsEnabled: themeController.effectsEnabled,
              child: child ?? const SizedBox.shrink(),
            ),
            home: const _AppLoader(),
          );
        },
      ),
    );
  }
}

/// Loads the bundled JSON data and saved settings once before showing the
/// home screen, with a small branded splash while that happens (it's fast
/// -- well under a second on-device -- but never assume zero).
class _AppLoader extends StatefulWidget {
  const _AppLoader();

  @override
  State<_AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<_AppLoader> {
  late final Future<void> _ready;

  @override
  void initState() {
    super.initState();
    _ready = _load();
    _startNotifications();
  }

  /// Notifications are strictly optional at startup: this never awaits,
  /// never throws, and never gates the splash screen. NotificationBridge
  /// initializes the service before loading reminder settings (loading
  /// reschedules), and swallows and logs any failure.
  void _startNotifications() {
    try {
      unawaited(
        NotificationBridge.instance
            .start(context.read<NotificationSettingsService>()),
      );
    } catch (e) {
      debugPrint('Notifications could not be started: $e');
    }
    // Once the real content (Home) is on screen, taps can navigate.
    _ready.then((_) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => NotificationBridge.instance.markUiReady(),
      );
      WidgetsBinding.instance.ensureVisualUpdate();
    }, onError: (Object _) {});
  }

  Future<void> _load() async {
    await Future.wait([
      DataService.instance.load(),
      context.read<SettingsService>().load(),
      context.read<ProgressService>().load(),
      context.read<AudioService>().load(),
      context.read<ActivityService>().load(),
      context.read<ThemeController>().load(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _SplashScreen();
        }
        if (snapshot.hasError) {
          return _ErrorScreen(error: snapshot.error.toString());
        }
        return const HomeScreen();
      },
    );
  }
}

/// The launch screen. It runs before preferences have been read, so it shows
/// the default theme's backdrop; a moment later the saved theme takes over.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final t = theme.tokens;

    return Scaffold(
      body: theme.buildBackground(
        context,
        const BackgroundRequest(userBackground: null, userDimOpacity: 0),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ThemedSurface(
                level: SurfaceLevel.elevated,
                radius: t.radii.lg,
                allowHeavyEffects: false,
                padding: EdgeInsets.symmetric(
                  horizontal: t.spacing.xl,
                  vertical: t.spacing.lg,
                ),
                child: Text('文', style: t.text.jp(64, weight: FontWeight.w700)),
              ),
              SizedBox(height: t.spacing.lg),
              Text(
                'NIHONGO TRAINER',
                style: t.text.overline.copyWith(letterSpacing: 4),
              ),
              SizedBox(height: t.spacing.lg),
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: t.colors.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String error;
  const _ErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final t = theme.tokens;

    return Scaffold(
      body: theme.buildBackground(
        context,
        const BackgroundRequest(userBackground: null, userDimOpacity: 0),
        Center(
          child: Padding(
            padding: EdgeInsets.all(t.spacing.lg),
            child: ThemedSurface(
              level: SurfaceLevel.elevated,
              radius: t.radii.lg,
              allowHeavyEffects: false,
              tint: t.colors.bad,
              tintStrength: 0.5,
              padding: EdgeInsets.all(t.spacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline_rounded,
                      color: t.colors.bad, size: 30),
                  SizedBox(height: t.spacing.sm),
                  Text(
                    'Something went wrong loading the app data:\n$error',
                    textAlign: TextAlign.center,
                    style: t.text.body,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
