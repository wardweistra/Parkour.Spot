import 'agent_debug_log_stub.dart'
    if (dart.library.io) 'agent_debug_log_io.dart'
    if (dart.library.html) 'agent_debug_log_web.dart' as impl;

void appendAgentDebugLogEntry(Map<String, dynamic> payload) {
  impl.appendAgentDebugLogEntry(payload);
}
