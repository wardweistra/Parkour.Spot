import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Yields so the framework can paint (e.g. show a spinner) before heavy work.
Future<void> yieldToUi() async {
  await SchedulerBinding.instance.endOfFrame;
  if (kIsWeb) {
    // Give the browser an extra frame; helps web spinners start animating.
    await Future<void>.delayed(const Duration(milliseconds: 32));
    await SchedulerBinding.instance.endOfFrame;
  }
}
