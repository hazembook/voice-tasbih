import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dhakir/features/counter/application/counter_notifier.dart';

void main() {
  group('CounterNotifier', () {
    test('initial state is correct', () {
      final container = ProviderContainer();
      final notifier = container.read(counterProvider.notifier);

      expect(notifier.state.count, 0);
      expect(notifier.state.target, 33);
      expect(notifier.state.phrase, 'Subhan Allah');
      expect(notifier.state.isListening, false);
      expect(notifier.state.isTargetReached, false);

      container.dispose();
    });

    test('increment increases count', () {
      final container = ProviderContainer();
      final notifier = container.read(counterProvider.notifier);

      expect(notifier.state.count, 0);

      notifier.increment();
      expect(notifier.state.count, 1);

      notifier.increment();
      expect(notifier.state.count, 2);

      container.dispose();
    });

    test('reset sets count to 0', () {
      final container = ProviderContainer();
      final notifier = container.read(counterProvider.notifier);

      notifier.increment();
      notifier.increment();
      notifier.increment();
      expect(notifier.state.count, 3);

      notifier.reset();
      expect(notifier.state.count, 0);

      container.dispose();
    });

    test('setTarget updates target', () {
      final container = ProviderContainer();
      final notifier = container.read(counterProvider.notifier);

      expect(notifier.state.target, 33);

      notifier.setTarget(100);
      expect(notifier.state.target, 100);

      container.dispose();
    });

    test('isTargetReached returns true when count reaches target', () {
      final container = ProviderContainer();
      final notifier = container.read(counterProvider.notifier);

      notifier.setTarget(3);

      notifier.increment();
      expect(notifier.state.isTargetReached, false);

      notifier.increment();
      expect(notifier.state.isTargetReached, false);

      notifier.increment();
      expect(notifier.state.isTargetReached, true);

      container.dispose();
    });

    test('setListening toggles isListening flag', () {
      final container = ProviderContainer();
      final notifier = container.read(counterProvider.notifier);

      expect(notifier.state.isListening, false);

      notifier.setListening(true);
      expect(notifier.state.isListening, true);

      notifier.setListening(false);
      expect(notifier.state.isListening, false);

      container.dispose();
    });
  });
}
