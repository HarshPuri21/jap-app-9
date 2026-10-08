import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/vocab_entry.dart';
import '../models/kanji_entry.dart';
import '../models/item_progress.dart';
import '../services/data_service.dart';
import '../services/progress_service.dart';
import '../services/audio_service.dart';
import '../services/activity_service.dart';
import '../theming/theme_scope.dart';
import '../theming/theme_tokens.dart';
import '../widgets/app_background.dart';
import '../widgets/themed/themed_controls.dart';
import '../widgets/themed/themed_shell.dart';
import '../widgets/themed/themed_surface.dart';

enum _CardKind { vocab, kanji }

class _Card {
  final _CardKind kind;
  final VocabEntry? vocab;
  final KanjiEntry? kanji;
  _Card.vocab(this.vocab)
      : kind = _CardKind.vocab,
        kanji = null;
  _Card.kanji(this.kanji)
      : kind = _CardKind.kanji,
        vocab = null;

  /// Stable ID used to key this card's SRS progress record.
  String get itemId => kind == _CardKind.vocab
      ? vocabItemId(vocab!.jp)
      : kanjiItemId(kanji!.kanji);
}

class FlashcardScreen extends StatefulWidget {
  const FlashcardScreen({super.key});

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  late List<_Card> _deck;
  final PageController _controller = PageController();
  final Set<int> _flipped = {};
  String _filter = 'mixed'; // 'mixed' | 'vocab' | 'kanji'
  int _known = 0;
  int _seen = 0;

  @override
  void initState() {
    super.initState();
    _buildDeck();
    context.read<AudioService>().stopMenuMusic();
  }

  void _buildDeck() {
    final vocabCards =
        DataService.instance.vocab.map((v) => _Card.vocab(v)).toList();
    final kanjiCards =
        DataService.instance.kanjiEntries.map((k) => _Card.kanji(k)).toList();
    switch (_filter) {
      case 'vocab':
        _deck = vocabCards;
        break;
      case 'kanji':
        _deck = kanjiCards;
        break;
      default:
        _deck = [...vocabCards, ...kanjiCards];
    }
    _deck.shuffle();
    _flipped.clear();
    _known = 0;
    _seen = 0;
    _advancing = false;
  }

  void _setFilter(String f) {
    context.read<AudioService>().playLessonClick();
    setState(() {
      _filter = f;
      _buildDeck();
    });
    if (_controller.hasClients) _controller.jumpToPage(0);
  }

  void _toggleFlip(int index) {
    context.read<AudioService>().playLessonClick();
    setState(() {
      if (_flipped.contains(index)) {
        _flipped.remove(index);
      } else {
        _flipped.add(index);
      }
    });
  }

  bool _advancing = false; // guards a fast double-swipe from counting twice

  void _markAndAdvance(int index, bool known) {
    if (_advancing) return;
    _advancing = true;
    context.read<AudioService>().playLessonClick();
    setState(() {
      _seen += 1;
      if (known) _known += 1;
    });
    // Flashcards are unrestricted practice, not a second back door into the
    // 20-new-items/day SRS intake. Existing SRS items can still be rated here
    // (preserving the established behaviour for learned cards), but an
    // unseen card stays practice-only until Daily Review introduces it.
    final progress = context.read<ProgressService>();
    final itemId = _deck[index].itemId;
    progress.rateIfStudied(itemId, known ? Rating.good : Rating.again);
    context.read<ActivityService>().recordActivity();

    final next = (_controller.page ?? 0).round() + 1;
    if (next < _deck.length) {
      _controller
          .nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      )
          .then((_) {
        if (mounted) _advancing = false;
      });
    } else {
      _advancing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              _buildFilterChips(context),
              SizedBox(height: t.spacing.xs),
              Expanded(
                child: _deck.isEmpty
                    ? Center(child: Text('No cards', style: t.text.secondary))
                    : PageView.builder(
                        controller: _controller,
                        itemCount: _deck.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: t.spacing.lg,
                              vertical: t.spacing.xs,
                            ),
                            child: GestureDetector(
                              onTap: () => _toggleFlip(index),
                              onVerticalDragEnd: (d) {
                                if ((d.primaryVelocity ?? 0) < -250) {
                                  _markAndAdvance(
                                      index, true); // swipe up = know it
                                } else if ((d.primaryVelocity ?? 0) > 250) {
                                  _markAndAdvance(index,
                                      false); // swipe down = still learning
                                }
                              },
                              child: _buildCardShell(
                                context,
                                _deck[index],
                                _flipped.contains(index),
                                index,
                              ),
                            ),
                          );
                        },
                      ),
              ),
              _buildHint(context),
              SizedBox(height: t.spacing.md),
            ],
          ),
        ),
      ),
    );
  }

  /// One stable surface; only the face *inside* cross-fades when flipped, so
  /// an expensive themed surface is never rebuilt mid-animation.
  Widget _buildCardShell(
    BuildContext context,
    _Card card,
    bool flipped,
    int index,
  ) {
    final t = context.tokens;
    return ThemedSurface(
      level: SurfaceLevel.elevated,
      radius: t.radii.xl,
      padding: EdgeInsets.all(t.spacing.xl),
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: SingleChildScrollView(
          child: AnimatedSwitcher(
            duration: t.motion.base,
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: KeyedSubtree(
              key: ValueKey('$index-$flipped'),
              child: card.kind == _CardKind.vocab
                  ? _vocabFace(context, card.vocab!, flipped)
                  : _kanjiFace(context, card.kanji!, flipped),
            ),
          ),
        ),
      ),
    );
  }

  Widget _vocabFace(BuildContext context, VocabEntry v, bool flipped) {
    final t = context.tokens;
    if (!flipped) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              v.jp,
              textAlign: TextAlign.center,
              style: t.text.jp(52, weight: FontWeight.w700),
            ),
          ),
          SizedBox(height: t.spacing.sm),
          Text(
            v.kana,
            textAlign: TextAlign.center,
            style: t.text.jp(20, color: t.colors.textSecondary),
          ),
          SizedBox(height: t.spacing.lg),
          Text('Tap to reveal meaning', style: t.text.caption),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          v.meaning,
          textAlign: TextAlign.center,
          style: t.text.display.copyWith(
            color: t.colors.accent,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        ),
        SizedBox(height: t.spacing.sm),
        Text(v.romaji, style: t.text.secondary),
        SizedBox(height: t.spacing.xxs),
        Text(v.category, style: t.text.caption),
      ],
    );
  }

  Widget _kanjiFace(BuildContext context, KanjiEntry k, bool flipped) {
    final t = context.tokens;
    if (!flipped) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(k.kanji, style: t.text.jp(92, weight: FontWeight.w700)),
          ),
          SizedBox(height: t.spacing.lg),
          Text('Tap to reveal meaning', style: t.text.caption),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          k.meaning,
          textAlign: TextAlign.center,
          style: t.text.display.copyWith(
            color: t.colors.accent,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1.3,
          ),
        ),
        SizedBox(height: t.spacing.sm),
        if (k.onyomi.isNotEmpty)
          Text(
            'On: ${k.onyomi.join("、")}',
            textAlign: TextAlign.center,
            style: t.text.jp(15),
          ),
        if (k.kunyomi.isNotEmpty)
          Text(
            'Kun: ${k.kunyomi.join("、")}',
            textAlign: TextAlign.center,
            style: t.text.jp(15),
          ),
      ],
    );
  }

  Widget _buildHint(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: t.spacing.lg),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const _HintChip(
                  icon: Icons.touch_app_outlined, label: 'Tap to flip'),
              SizedBox(width: t.spacing.xs),
              _HintChip(
                icon: Icons.arrow_upward_rounded,
                label: 'Know it',
                color: t.colors.good,
              ),
              SizedBox(width: t.spacing.xs),
              _HintChip(
                icon: Icons.arrow_downward_rounded,
                label: 'Learning',
                color: t.colors.warn,
              ),
            ],
          ),
          SizedBox(height: t.spacing.xs),
          Text('$_known / $_seen known this session', style: t.text.caption),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return ThemedAppBar(
      title: 'Flashcards',
      subtitle: '単語カード',
      onLeadingTap: () {
        context.read<AudioService>().playLessonClick();
        Navigator.of(context).pop();
      },
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    final t = context.tokens;
    const options = [
      ('mixed', 'Mixed'),
      ('vocab', 'Vocab'),
      ('kanji', 'Kanji'),
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
                selected: o.$1 == _filter,
                onTap: () => _setFilter(o.$1),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _HintChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _HintChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = color ?? t.colors.textSecondary;
    return ThemedSurface(
      level: SurfaceLevel.subtle,
      radius: ThemeRadii.pill,
      allowHeavyEffects: false,
      showShadow: false,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: c),
          const SizedBox(width: 5),
          Text(
            label,
            style: t.text.caption.copyWith(
              color: c,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
