enum EventResolvedLocationSource { venue, spot, list }

/// Main location derived by Cloud Functions: the venue when the event has
/// coordinates, otherwise the first eligible linked spot. Read-only on clients.
class EventResolvedLocation {
  final EventResolvedLocationSource source;
  final double latitude;
  final double longitude;
  final String? city;
  final String? countryCode;
  final String? spotId;
  final String? spotName;
  final String? spotListId;
  final String? spotListName;

  const EventResolvedLocation({
    required this.source,
    required this.latitude,
    required this.longitude,
    this.city,
    this.countryCode,
    this.spotId,
    this.spotName,
    this.spotListId,
    this.spotListName,
  });

  static EventResolvedLocation? fromMap(dynamic value) {
    if (value is! Map) return null;
    final latitude = value['latitude'];
    final longitude = value['longitude'];
    if (latitude is! num || longitude is! num) return null;

    String? readString(String key) {
      final raw = value[key];
      if (raw is! String) return null;
      final trimmed = raw.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    final source = switch (value['source']) {
      'spot' => EventResolvedLocationSource.spot,
      'list' => EventResolvedLocationSource.list,
      _ => EventResolvedLocationSource.venue,
    };

    return EventResolvedLocation(
      source: source,
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      city: readString('city'),
      countryCode: readString('countryCode')?.toUpperCase(),
      spotId: readString('spotId'),
      spotName: readString('spotName'),
      spotListId: readString('spotListId'),
      spotListName: readString('spotListName'),
    );
  }
}
