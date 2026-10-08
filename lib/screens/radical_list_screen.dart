import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/radical_entry.dart';
import '../services/data_service.dart';
import '../services/audio_service.dart';
import '../theming/theme_scope.dart';
import '../theming/theme_tokens.dart';
import '../widgets/app_background.dart';
import '../widgets/difficulty_badge.dart';
import '../widgets/themed/themed_motion.dart';
import '../widgets/themed/themed_shell.dart';
import '../widgets/themed/themed_surface.dart';
import 'radical_detail_screen.dart';

class RadicalListScreen extends StatefulWidget {
  const RadicalListScreen({super.key});

  @override
  State<RadicalListScreen> createState() => _RadicalListScreenState();
}

class _RadicalListScreenState extends State<RadicalListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    context.read<AudioService>().stopMenuMusic();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<RadicalEntry> get _filtered {
    final all = DataService.instance.radicals;
    if (_query.isEmpty) return all;
    return all.where((r) {
      return r.char.contains(_query) ||
          r.meaning.toLowerCase().contains(_query) ||
          r.name.toLowerCase().contains(_query);
    }).toList();
  }

  void _openDetail(RadicalEntry r) {
    context.read<AudioService>().playLessonClick();
    Navigator.of(context).push(
      themedRoute(context, (_) => RadicalDetailScreen(radical: r)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final results = _filtered;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  t.spacing.gutter,
                  0,
                  t.spacing.gutter,
                  t.spacing.sm,
                ),
                child: ThemedTextField(
                  controller: _searchController,
                  hintText: 'Search by name or meaning…',
                  showClear: _query.isNotEmpty,
                  onClear: () => _searchController.clear(),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: t.spacing.gutter),
                child: Row(
                  children: [
                    Text(
                      '${results.length} radical${results.length == 1 ? '' : 's'}',
                      style: t.text.caption,
                    ),
                  ],
                ),
              ),
              SizedBox(height: t.spacing.xs),
              Expanded(
                child: results.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'No radicals match "$_query".',
                            textAlign: TextAlign.center,
                            style: t.text.secondary,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.fromLTRB(
                          t.spacing.gutter,
                          0,
                          t.spacing.gutter,
                          t.spacing.xl,
                        ),
                        itemCount: results.length,
                        itemBuilder: (context, index) =>
                            _radicalTile(context, results[index]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _radicalTile(BuildContext context, RadicalEntry r) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.only(bottom: t.spacing.xs),
      child: ThemedCard(
        onTap: () => _openDetail(r),
        level: SurfaceLevel.standard,
        radius: t.radii.sm,
        // Hundreds of these scroll past, so the theme uses its cheap path.
        allowHeavyEffects: false,
        padding: EdgeInsets.symmetric(
          horizontal: t.spacing.sm + 2,
          vertical: t.spacing.sm,
        ),
        semanticLabel: '${r.char}, ${r.meaning}',
        child: Row(
          children: [
            SizedBox(
              width: 48,
              child: Text(
                r.char,
                textAlign: TextAlign.center,
                style: t.text.jp(28, weight: FontWeight.w700),
              ),
            ),
            SizedBox(width: t.spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    r.meaning,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.text.body.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    r.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.text.jp(12.5, color: t.colors.textSecondary),
                  ),
                ],
              ),
            ),
            SizedBox(width: t.spacing.xs),
            DifficultyBadge(difficulty: r.difficulty),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return ThemedAppBar(
      title: 'Radicals',
      subtitle: '部首',
      onLeadingTap: () {
        context.read<AudioService>().playLessonClick();
        Navigator.of(context).pop();
      },
    );
  }
}
