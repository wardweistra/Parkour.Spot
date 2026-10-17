import 'package:flutter_test/flutter_test.dart';
import 'package:parkour_spot/services/user_map_feed_service.dart';

void main() {
  const feed = 'https://parkour.spot/map/psm_abc.kml';

  test('toGoogleMyMapsUrl opens Google My Maps', () {
    final url = UserMapFeedService.toGoogleMyMapsUrl();
    final uri = Uri.parse(url);
    expect(uri.host, 'www.google.com');
    expect(uri.path, '/maps/d/');
  });

  test('feed URL uses https KML path', () {
    expect(feed, startsWith('https://parkour.spot/map/'));
    expect(feed, endsWith('.kml'));
  });
}
