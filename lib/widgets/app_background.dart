import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/settings_service.dart';
import '../theming/theme_definition.dart';
import '../theming/theme_scope.dart';

/// The bridge between the user's background preference and the active theme.
///
/// This widget is *app* code, not theme code: it is the only place that reads
/// `SettingsService` for background purposes. It turns the preference into a
/// plain [BackgroundRequest] -- "here is a widget painting the user's photo,
/// dim it by 0.55" -- and hands that to the theme, which decides how its own
/// backdrop treatment combines with it.
///
/// That split is what lets the background picker and a theme's signature
/// backdrop coexist: the user owns *what* is behind the UI, the theme owns
/// *how* the UI sits on top of it.
class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();

    return context.appTheme.buildBackground(
      context,
      BackgroundRequest(
        userBackground: _buildUserLayer(settings),
        userDimOpacity: settings.overlayOpacity,
      ),
      child,
    );
  }

  /// Returns null for "app default", which tells the theme to paint its own
  /// signature backdrop instead.
  Widget? _buildUserLayer(SettingsService settings) {
    switch (settings.backgroundType) {
      case BackgroundType.photo:
        final path = settings.backgroundPhotoPath;
        if (path != null && File(path).existsSync()) {
          return Image.file(File(path), fit: BoxFit.cover);
        }
        // The saved photo vanished from disk -- fall back to the theme's own
        // backdrop rather than showing a broken image.
        return null;
      case BackgroundType.color:
        return ColoredBox(color: settings.backgroundColor);
      case BackgroundType.appDefault:
        return null;
    }
  }
}
