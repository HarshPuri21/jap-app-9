import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/kana_entry.dart';
import '../services/data_service.dart';
import '../services/audio_service.dart';
import '../theming/theme_definition.dart';
import '../theming/theme_scope.dart';
import '../theming/theme_tokens.dart';
import '../widgets/app_background.dart';
import '../widgets/themed/themed_motion.dart';
import '../widgets/themed/themed_shell.dart';
import '../widgets/themed/themed_surface.dart';

class KanaDetailScreen extends StatelessWidget {
  final KanaEntry entry;
  const KanaDetailScreen({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final paired = _pairedEntry();

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    t.spacing.gutter,
                    t.spacing.xs,
                    t.spacing.gutter,
                    t.spacing.xl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // The character gets the forward surface and the
                      // theme's own reveal -- reusing kanjiReveal since a
                      // single revealed study character is the same moment,
                      // whether it's a kanji or a kana.
                      ThemedReveal(
                        moment: ThemeMoment.kanjiReveal,
                        child: ThemedSurface(
                          level: SurfaceLevel.elevated,
                          radius: t.radii.lg,
                          padding: EdgeInsets.all(t.spacing.lg),
                          child: Column(
                            children: [
                              _GroupBadge(group: entry.group),
                              SizedBox(height: t.spacing.md),
                              Text(
                                entry.character,
                                style: t.text.jp(96, weight: FontWeight.w700),
                              ),
                              SizedBox(height: t.spacing.md),
                              Text(
                                entry.romaji.isEmpty
                                    ? entry.sound
                                    : entry.romaji,
                                textAlign: TextAlign.center,
                                style: t.text.display.copyWith(fontSize: 26),
                              ),
                              if (entry.romaji.isNotEmpty &&
                                  entry.sound != entry.romaji) ...[
                                const SizedBox(height: 6),
                                Text(
                                  entry.sound,
                                  textAlign: TextAlign.center,
                                  style: t.text.secondary,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: t.spacing.md),
                      _infoCard(
                        context,
                        title: entry.isHiragana ? 'HIRAGANA' : 'KATAKANA',
                        child: Text(
                          entry.isHiragana
                              ? 'One of the two phonetic kana alphabets, used for native Japanese words, grammar and okurigana.'
                              : 'One of the two phonetic kana alphabets, used mainly for loanwords, foreign names and emphasis.',
                          style: t.text.body,
                        ),
                      ),
                      if (paired != null) ...[
                        SizedBox(height: t.spacing.sm),
                        _pairedCard(context, paired),
                      ],
                      if (entry.notes != null && entry.notes!.isNotEmpty) ...[
                        SizedBox(height: t.spacing.sm),
                        _infoCard(
                          context,
                          title: 'GOOD TO KNOW',
                          child: Text(entry.notes!, style: t.text.body),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The same character in the other kana system, resolved live from
  /// [DataService] rather than stored on the entry itself.
  KanaEntry? _pairedEntry() {
    if (entry.pairedKana == null) return null;
    final ds = DataService.instance;
    for (final k in ds.kana) {
      if (k.character == entry.pairedKana && k.type != entry.type) return k;
    }
    return null;
  }

  Widget _pairedCard(BuildContext context, KanaEntry paired) {
    final t = context.tokens;
    return ThemedCard(
      onTap: () {
        context.read<AudioService>().playLessonClick();
        Navigator.of(context).pushReplacement(
          themedRoute(context, (_) => KanaDetailScreen(entry: paired)),
        );
      },
      level: SurfaceLevel.standard,
      radius: t.radii.md,
      width: double.infinity,
      padding: EdgeInsets.all(t.spacing.md),
      semanticLabel:
          'View ${paired.character}, the paired ${paired.type.label} kana',
      child: Row(
        children: [
          Text(paired.character, style: t.text.jp(30, weight: FontWeight.w700)),
          SizedBox(width: t.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  paired.isHiragana ? 'Hiragana pair' : 'Katakana pair',
                  style: t.text.overline,
                ),
                const SizedBox(height: 2),
                Text(
                  paired.romaji.isEmpty ? paired.sound : paired.romaji,
                  style: t.text.body,
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: t.colors.textTertiary),
        ],
      ),
    );
  }

  Widget _infoCard(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    final t = context.tokens;
    return ThemedSurface(
      level: SurfaceLevel.standard,
      radius: t.radii.md,
      width: double.infinity,
      padding: EdgeInsets.all(t.spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: t.text.overline),
          SizedBox(height: t.spacing.xs),
          child,
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return ThemedAppBar(
      title: 'Kana Detail',
      subtitle: '仮名',
      onLeadingTap: () {
        context.read<AudioService>().playLessonClick();
        Navigator.of(context).pop();
      },
    );
  }
}

/// Small pill naming the kana's group ('Basic', 'Dakuten', ...). Styled
/// like [DifficultyBadge] but keyed off group rather than difficulty, since
/// kana groups aren't easy/normal/hard.
class _GroupBadge extends StatelessWidget {
  final KanaGroup group;
  const _GroupBadge({required this.group});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final label = kKanaGroupLabels[group] ?? group.name;
    final color = t.colors.accent;

    return ThemedSurface(
      level: SurfaceLevel.subtle,
      radius: ThemeRadii.pill,
      allowHeavyEffects: false,
      showShadow: false,
      tint: color,
      tintStrength: 0.8,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        label.toUpperCase(),
        style: t.text.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}
