import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/kana_entry.dart';
import '../services/data_service.dart';
import '../services/audio_service.dart';
import '../theming/theme_scope.dart';
import '../theming/theme_tokens.dart';
import '../widgets/app_background.dart';
import '../widgets/themed/themed_controls.dart';
import '../widgets/themed/themed_motion.dart';
import '../widgets/themed/themed_shell.dart';
import '../widgets/themed/themed_surface.dart';
import 'kana_detail_screen.dart';

class KanaModeScreen extends StatefulWidget {
  const KanaModeScreen({super.key});

  @override
  State<KanaModeScreen> createState() => _KanaModeScreenState();
}

class _KanaModeScreenState extends State<KanaModeScreen> {
  KanaType _type = KanaType.hiragana;

  @override
  void initState() {
    super.initState();
    context.read<AudioService>().stopMenuMusic();
  }

  void _setType(KanaType type) {
    context.read<AudioService>().playLessonClick();
    setState(() => _type = type);
  }

  void _openDetail(KanaEntry entry) {
    context.read<AudioService>().playLessonClick();
    Navigator.of(context).push(
      themedRoute(context, (_) => KanaDetailScreen(entry: entry)),
    );
  }

  /// Groups for the active type, in learning order. 'special' is merged
  /// into the 'small' bucket here (see [kKanaGroupLabels]); Extended
  /// Katakana only exists for katakana.
  List<MapEntry<KanaGroup, List<KanaEntry>>> _sections(BuildContext context) {
    final ds = DataService.instance;
    final all = ds.kanaByType(_type);
    final sections = <MapEntry<KanaGroup, List<KanaEntry>>>[];
    for (final group in DataService.kanaGroupOrder) {
      if (group == KanaGroup.special) continue; // folded into 'small' below
      var items = all.where((k) => k.group == group).toList();
      if (group == KanaGroup.small) {
        items = [...items, ...all.where((k) => k.group == KanaGroup.special)];
      }
      if (items.isEmpty) continue;
      sections.add(MapEntry(group, items));
    }
    return sections;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final sections = _sections(context);
    final total = DataService.instance.kanaByType(_type).length;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context, total),
              _buildTypeChips(context),
              SizedBox(height: t.spacing.xs),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    t.spacing.gutter,
                    0,
                    t.spacing.gutter,
                    t.spacing.xl,
                  ),
                  itemCount: sections.length,
                  itemBuilder: (context, index) {
                    final section = sections[index];
                    return _buildSection(context, section.key, section.value);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    KanaGroup group,
    List<KanaEntry> items,
  ) {
    final t = context.tokens;
    final label = kKanaGroupLabels[group] ?? group.name;
    return Padding(
      padding: EdgeInsets.only(bottom: t.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ThemedSectionLabel('$label (${items.length})'),
          Wrap(
            spacing: t.spacing.xs,
            runSpacing: t.spacing.xs,
            children: items.map((e) => _kanaTile(context, e)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _kanaTile(BuildContext context, KanaEntry entry) {
    final t = context.tokens;
    return SizedBox(
      width: 76,
      height: 76,
      child: ThemedCard(
        onTap: () => _openDetail(entry),
        level: SurfaceLevel.standard,
        radius: t.radii.sm,
        // Up to 46 of these render in one section -- keep it cheap.
        allowHeavyEffects: false,
        padding: EdgeInsets.zero,
        semanticLabel: '${entry.character}, ${entry.romaji}',
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(entry.character, style: t.text.jp(26, weight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(
                entry.romaji.isEmpty ? '·' : entry.romaji,
                style: t.text.caption.copyWith(color: t.colors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, int total) {
    return ThemedAppBar(
      title: 'Learn Kana',
      subtitle: '仮名',
      onLeadingTap: () {
        context.read<AudioService>().playLessonClick();
        Navigator.of(context).pop();
      },
      trailing: ThemedStatPill(text: '$total', icon: Icons.grid_view),
    );
  }

  Widget _buildTypeChips(BuildContext context) {
    final t = context.tokens;
    const options = [
      (KanaType.hiragana, 'Hiragana'),
      (KanaType.katakana, 'Katakana'),
    ];
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: t.spacing.gutter),
        children: options.map((o) {
          return Padding(
            padding: EdgeInsets.only(right: t.spacing.xs),
            child: Center(
              child: ThemedChip(
                label: o.$2,
                selected: o.$1 == _type,
                onTap: () => _setType(o.$1),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
