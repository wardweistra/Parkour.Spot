import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/utils/add_spot_gps_fix_guard.dart';

void main() {
  group('AddSpotGpsFixGuard', () {
    test('applies automatic GPS when the user has not chosen a pin', () {
      final guard = AddSpotGpsFixGuard();
      final generation = guard.beginRequest();

      expect(
        guard.shouldApplyResult(
          requestGeneration: generation,
          requestedByUser: false,
        ),
        isTrue,
      );
    });

    test('does not apply a late automatic GPS after an explicit pin', () {
      final guard = AddSpotGpsFixGuard();
      final generation = guard.beginRequest();

      guard.markExplicit();

      expect(
        guard.shouldApplyResult(
          requestGeneration: generation,
          requestedByUser: false,
        ),
        isFalse,
      );
      expect(guard.ownsInFlightRequest(generation), isFalse);
    });

    test(
      'does not apply automatic GPS when opened with an initial location',
      () {
        final guard = AddSpotGpsFixGuard();
        guard.markExplicit();
        final generation = guard.beginRequest();

        expect(
          guard.shouldApplyResult(
            requestGeneration: generation,
            requestedByUser: false,
          ),
          isFalse,
        );
      },
    );

    test('applies a user-requested GPS after an explicit pin', () {
      final guard = AddSpotGpsFixGuard();
      guard.markExplicit();
      final generation = guard.beginRequest();

      expect(
        guard.shouldApplyResult(
          requestGeneration: generation,
          requestedByUser: true,
        ),
        isTrue,
      );

      guard.recordApplied(requestedByUser: true);
      expect(guard.hasExplicitLocation, isTrue);
    });

    test('ignores a stale automatic GPS after a newer user request', () {
      final guard = AddSpotGpsFixGuard();
      final autoGeneration = guard.beginRequest();
      final userGeneration = guard.beginRequest();

      expect(
        guard.shouldApplyResult(
          requestGeneration: autoGeneration,
          requestedByUser: false,
        ),
        isFalse,
      );
      expect(
        guard.shouldApplyResult(
          requestGeneration: userGeneration,
          requestedByUser: true,
        ),
        isTrue,
      );
    });

    test('ignores in-flight GPS after the user picks a pin later', () {
      final guard = AddSpotGpsFixGuard();
      final userGeneration = guard.beginRequest();

      guard.markExplicit();

      expect(
        guard.shouldApplyResult(
          requestGeneration: userGeneration,
          requestedByUser: true,
        ),
        isFalse,
      );
    });

    test('automatic GPS does not mark the pin as explicit', () {
      final guard = AddSpotGpsFixGuard();
      final generation = guard.beginRequest();

      expect(
        guard.shouldApplyResult(
          requestGeneration: generation,
          requestedByUser: false,
        ),
        isTrue,
      );
      guard.recordApplied(requestedByUser: false);

      expect(guard.hasExplicitLocation, isFalse);
    });
  });
}
