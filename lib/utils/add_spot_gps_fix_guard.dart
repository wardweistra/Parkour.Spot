/// Guards delayed GPS results on the add-spot form.
///
/// Opening the page starts an automatic location request. The user can pick a
/// pin (or arrive with an initial location) while that request is still in
/// flight. A GPS result must not overwrite an explicit pin unless the user
/// asked for current location again.
class AddSpotGpsFixGuard {
  bool _hasExplicitLocation = false;
  int _generation = 0;

  bool get hasExplicitLocation => _hasExplicitLocation;

  /// Records a user-chosen pin and invalidates in-flight GPS requests.
  void markExplicit() {
    _hasExplicitLocation = true;
    _generation++;
  }

  /// Starts a GPS request and returns the generation to check on completion.
  ///
  /// Each new request invalidates earlier in-flight results.
  int beginRequest() {
    _generation++;
    return _generation;
  }

  /// Whether this GPS result should move the pin and geocode.
  bool shouldApplyResult({
    required int requestGeneration,
    required bool requestedByUser,
  }) {
    if (requestGeneration != _generation) return false;
    return requestedByUser || !_hasExplicitLocation;
  }

  /// Call after a GPS result has been applied to the pin.
  void recordApplied({required bool requestedByUser}) {
    if (requestedByUser) {
      _hasExplicitLocation = true;
    }
  }

  /// Whether this request still owns the "getting location" spinner.
  bool ownsInFlightRequest(int requestGeneration) =>
      requestGeneration == _generation;
}
