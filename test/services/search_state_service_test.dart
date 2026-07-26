import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/services/search_state_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('has-images filter defaults to disabled', () {
    final service = SearchStateService();

    expect(service.hasImagesOnly, isFalse);
  });

  test('has-images filter persists across service instances', () async {
    final service = SearchStateService();
    await service.setHasImagesOnly(true);

    final restoredService = SearchStateService();
    await restoredService.loadFromStorage();

    expect(restoredService.hasImagesOnly, isTrue);
  });

  test('switching filter area preserves the has-images filter', () async {
    final service = SearchStateService();
    await service.setHasImagesOnly(true);

    await service.setFilterArea('source');
    expect(service.hasImagesOnly, isTrue);

    await service.setFilterArea('amenities');
    expect(service.hasImagesOnly, isTrue);
  });

  test(
    'clearing all filters disables and persists has-images filter',
    () async {
      final service = SearchStateService();
      await service.setHasImagesOnly(true);

      await service.clearAllFilters();

      expect(service.hasImagesOnly, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('search_has_images_only'), isFalse);
    },
  );
}
