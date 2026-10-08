import 'dart:math';

/// Returns a shuffled copy without mutating the source list.
///
/// Quiz data files intentionally keep deterministic option arrays so source
/// diffs stay reviewable. Learner-facing screens must not preserve those
/// positions across repetitions, otherwise users can memorize "the third
/// button" instead of the Japanese answer. A [Random] can be supplied by
/// tests; production uses Dart's normal runtime RNG.
List<T> shuffledCopy<T>(Iterable<T> values, {Random? random}) {
  final copy = List<T>.of(values);
  copy.shuffle(random);
  return copy;
}
