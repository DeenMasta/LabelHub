import 'package:flutter_test/flutter_test.dart';
import 'package:labelhub/core/utilities/text_utils.dart';

void main() {
  group('TextUtils', () {
    test('does not split short text', () {
      final result = TextUtils.splitToTwoLines('Short item', limit: 18);
      expect(result, ['Short item']);
    });

    test('splits long text at last space', () {
      final result = TextUtils.splitToTwoLines('Delicious Blueberry Muffin', limit: 18);
      expect(result, ['Delicious', 'Blueberry Muffin']);
    });

    test('hard splits long text without space', () {
      final result = TextUtils.splitToTwoLines('Supercalifragilisticexpialidocious', limit: 18);
      expect(result, ['Supercalifragilist', 'icexpialidocious']);
    });

    test('handles exactly 18 characters without splitting', () {
      final result = TextUtils.splitToTwoLines('EighteenCharacters', limit: 18);
      expect(result, ['EighteenCharacters']);
    });
  });
}
