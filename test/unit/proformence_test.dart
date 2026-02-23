import 'package:flutter_test/flutter_test.dart';

void main() {

  test("Performance test", () {

    final stopwatch = Stopwatch()..start();

    for (int i = 0; i < 1000000; i++) {
      var x = i * i;
    }

    stopwatch.stop();

    print(stopwatch.elapsedMilliseconds);

    expect(stopwatch.elapsedMilliseconds < 1000, true);
  });
}

