/// Snack bar summary for spot/event search-term backfill callables.
String formatSearchIndexBackfillMessage({
  required String entityLabel,
  required dynamic totalProcessed,
  required dynamic searchTermsWritten,
  required dynamic searchTermsDeleted,
  required bool purged,
}) {
  final parts = <String>[
    'Backfill completed',
    '$entityLabel: $totalProcessed',
  ];
  if (purged && searchTermsDeleted != null) {
    parts.add('deleted: $searchTermsDeleted');
  }
  parts.add('terms written: $searchTermsWritten');
  return '${parts.join(', ')}.';
}
