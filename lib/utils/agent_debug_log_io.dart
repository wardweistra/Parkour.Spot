import 'dart:convert';
import 'dart:io';

void appendAgentDebugLogEntry(Map<String, dynamic> payload) {
  try {
    final line = jsonEncode(payload);
    File(
      '/opt/cursor/logs/debug.log',
    ).writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
  } catch (_) {}
}
