import 'dart:convert';

import 'package:flutter/foundation.dart';

void appendAgentDebugLogEntry(Map<String, dynamic> payload) {
  try {
    debugPrint(jsonEncode(payload));
  } catch (_) {}
}
