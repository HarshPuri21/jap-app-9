import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nihongo_trainer/utils/quiz_options.dart';

void main() {
  test('shuffledCopy never mutates the source options', () {
    final source = ['a', 'b', 'c', 'd'];
    final shuffled = shuffledCopy(source, random: Random(42));

    expect(source, ['a', 'b', 'c', 'd']);
    expect(shuffled.toSet(), source.toSet());
    expect(identical(source, shuffled), isFalse);
  });
}
