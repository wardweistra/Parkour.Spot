import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/services/sync_source_service.dart';

void main() {
  group('SyncSource source types', () {
    test('parses OpenStreetMap, Naver map, and Google Earth types', () {
      final osm = SyncSource.fromMap({
        'id': 'osm-1',
        'name': 'OpenStreetMap',
        'sourceType': 'openstreetmap',
      });
      final naver = SyncSource.fromMap({
        'id': 'naver-1',
        'name': 'Seoul parkour',
        'kmzUrl':
            'https://pages.map.naver.com/save-pages/api/maps-bookmark/v3/shares/3388be4a43592f4a6aef152f4b3f0e29/bookmarks',
        'sourceType': 'navermap',
      });
      final googleEarth = SyncSource.fromMap({
        'id': 'ge-1',
        'name': 'Seattle PK Atlas',
        'sourceType': 'google_earth',
        'kmlStoragePath': 'syncSources/ge-1/import.kml',
        'kmlFileName': 'Seattle PK Atlas.kml',
      });
      final file = SyncSource.fromMap({
        'id': 'file-1',
        'name': 'KMZ',
        'kmzUrl': 'https://example.com/spots.kmz',
      });

      expect(osm.isOpenStreetMap, isTrue);
      expect(osm.sourceTypeLabel, 'OpenStreetMap');
      expect(naver.isNaverMap, isTrue);
      expect(naver.sourceTypeLabel, 'Naver map');
      expect(googleEarth.isGoogleEarth, isTrue);
      expect(googleEarth.hasGoogleEarthUpload, isTrue);
      expect(googleEarth.sourceTypeLabel, 'Google Earth');
      expect(file.sourceType, SyncSource.sourceTypeFile);
      expect(file.sourceTypeLabel, 'File');
    });

    test('unknown source types fall back to file', () {
      final source = SyncSource.fromMap({
        'id': 'x',
        'name': 'Unknown',
        'sourceType': 'other',
      });
      expect(source.sourceType, SyncSource.sourceTypeFile);
      expect(source.isOpenStreetMap, isFalse);
      expect(source.isNaverMap, isFalse);
    });

    test('file and Naver map source types require a URL', () {
      expect(
        SyncSource.sourceTypeRequiresUrl(SyncSource.sourceTypeFile),
        isTrue,
      );
      expect(
        SyncSource.sourceTypeRequiresUrl(SyncSource.sourceTypeNaverMap),
        isTrue,
      );
      expect(
        SyncSource.sourceTypeRequiresUrl(SyncSource.sourceTypeOpenStreetMap),
        isFalse,
      );
      expect(
        SyncSource.sourceTypeRequiresUrl(SyncSource.sourceTypeGoogleEarth),
        isFalse,
      );
    });
  });
}
