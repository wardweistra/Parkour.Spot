/// One external previous-to-current line, with the native value of that same
/// field.
class DuplicateChangeLine {
  const DuplicateChangeLine({
    this.label,
    required this.from,
    required this.to,
    required this.native,
    this.contentsChanged = false,
  });

  /// Sub-field name for a composite group. Null for a single-value group.
  final String? label;
  final String from;
  final String to;
  final String native;

  /// True when a count is unchanged but the underlying list or set differs.
  final bool contentsChanged;
}

/// External and native values for one changed field group.
class DuplicateFieldComparison {
  const DuplicateFieldComparison({
    required this.lines,
    required this.currentSummary,
    this.nativeSummary,
    required this.previousUnavailable,
    required this.nativeUnavailable,
    this.nativeMatchesPrevious,
  });

  /// Previous-to-current lines. Empty when [previousUnavailable] is true.
  final List<DuplicateChangeLine> lines;

  /// Current external value, used when no baseline is stored.
  final String currentSummary;

  /// Current native value, used when no baseline is stored.
  final String? nativeSummary;

  final bool previousUnavailable;
  final bool nativeUnavailable;

  /// Whether the native group equals the previous external group.
  /// Null when either side is missing.
  final bool? nativeMatchesPrevious;
}
