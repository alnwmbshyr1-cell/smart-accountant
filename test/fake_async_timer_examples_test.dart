import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('advances the five-second command deadline instantly', () {
    fakeAsync((async) {
      var finished = false;
      Timer(const Duration(seconds: 5), () => finished = true);

      async.elapse(const Duration(seconds: 4, milliseconds: 999));
      expect(finished, isFalse);

      async.elapse(const Duration(milliseconds: 1));
      expect(finished, isTrue);
    });
  });

  test('cancels a pending capture timer before it fires', () {
    fakeAsync((async) {
      var finished = false;
      final timer = Timer(const Duration(seconds: 5), () => finished = true);

      timer.cancel();
      async.elapse(const Duration(seconds: 10));

      expect(finished, isFalse);
      expect(timer.isActive, isFalse);
    });
  });
}
