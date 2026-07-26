import 'package:flutter/widgets.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

/// Builder for [showDatePicker] / [showTimePicker] that keeps clicks on the
/// dialog instead of falling through to platform views (e.g. Google Maps on web).
Widget interceptingPickerBuilder(BuildContext context, Widget? child) {
  return PointerInterceptor(child: child ?? const SizedBox.shrink());
}
