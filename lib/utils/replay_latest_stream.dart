import 'dart:async';

/// Forwards [source] to a broadcast stream and replays the latest event to late
/// subscribers (Firestore snapshot streams do not replay by default).
Stream<T> replayLatest<T>(
  Stream<T> source, {
  void Function(T value)? onValue,
}) {
  T? lastValue;
  Object? lastError;
  StackTrace? lastStackTrace;
  var hasEvent = false;
  StreamSubscription<T>? subscription;
  late final StreamController<T> controller;

  controller = StreamController<T>.broadcast(
    onListen: () {
      subscription ??= source.listen(
        (value) {
          lastValue = value;
          lastError = null;
          hasEvent = true;
          onValue?.call(value);
          if (!controller.isClosed) {
            controller.add(value);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          lastError = error;
          lastStackTrace = stackTrace;
          hasEvent = true;
          if (!controller.isClosed) {
            controller.addError(error, stackTrace);
          }
        },
      );
      if (hasEvent) {
        if (lastError != null) {
          controller.addError(lastError!, lastStackTrace);
        } else {
          controller.add(lastValue as T);
        }
      }
    },
  );

  return controller.stream;
}
