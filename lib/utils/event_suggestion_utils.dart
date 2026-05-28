import '../models/parkour_event.dart';

/// Returns a localization key for why suggestions are blocked, or null if allowed.
///
/// Keys map to [AppLocalizations] getters:
/// - `eventDetailCannotSuggestForDuplicate`
/// - `eventDetailUnableSuggestNow`
String? eventSuggestionBlockedReasonKey(ParkourEvent event) {
  final duplicateOf = event.duplicateOf?.trim();
  if (duplicateOf != null && duplicateOf.isNotEmpty) {
    return 'eventDetailCannotSuggestForDuplicate';
  }
  if (event.id == null || event.id!.trim().isEmpty) {
    return 'eventDetailUnableSuggestNow';
  }
  return null;
}

/// Whether an event document can receive approved suggestions.
bool isNativeEventData(Map<String, dynamic> eventData) {
  final rawSourceId = eventData['eventSourceId'];
  if (rawSourceId == null) return true;
  if (rawSourceId is! String) return false;
  return rawSourceId.trim().isEmpty;
}
