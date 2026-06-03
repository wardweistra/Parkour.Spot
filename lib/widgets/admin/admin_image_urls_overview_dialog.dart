import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

import '../../l10n/app_localizations.dart';
import '../../services/snackbar_service.dart';
import '../../utils/admin_image_url_diagnostics.dart';

/// Shows admin diagnostics for spot/event [imageUrls].
Future<void> showAdminImageUrlsOverviewDialog(
  BuildContext context, {
  required List<String> imageUrls,
  required String entityLabel,
  required bool showSpotsApiUrls,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => AdminImageUrlsOverviewDialog(
      imageUrls: imageUrls,
      entityLabel: entityLabel,
      showSpotsApiUrls: showSpotsApiUrls,
    ),
  );
}

class AdminImageUrlsOverviewDialog extends StatefulWidget {
  const AdminImageUrlsOverviewDialog({
    super.key,
    required this.imageUrls,
    required this.entityLabel,
    required this.showSpotsApiUrls,
  });

  final List<String> imageUrls;
  final String entityLabel;
  final bool showSpotsApiUrls;

  @override
  State<AdminImageUrlsOverviewDialog> createState() =>
      _AdminImageUrlsOverviewDialogState();
}

class _AdminImageUrlsOverviewDialogState
    extends State<AdminImageUrlsOverviewDialog> {
  List<AdminImageUrlDiagnostic>? _diagnostics;
  String? _error;
  bool _loading = true;

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _diagnostics = null;
    });
    try {
      final trimmed = widget.imageUrls
          .map((u) => u.trim())
          .where((u) => u.isNotEmpty)
          .toList();
      final results = await loadAdminImageUrlDiagnostics(trimmed);
      if (!mounted) return;
      setState(() {
        _diagnostics = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _copyText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    SnackbarService.showClipboardCopied(
      _l10n.adminImageUrlsCopiedToClipboard,
    );
  }

  String _buildFullReport() {
    final items = _diagnostics ?? [];
    final buffer = StringBuffer();
    buffer.writeln('${widget.entityLabel} — image URLs');
    buffer.writeln();
    for (final d in items) {
      buffer.writeln('Image ${d.index} of ${items.length}');
      buffer.writeln('Firestore: ${d.originalUrl}');
      if (d.expected1200x1200Url != null) {
        buffer.writeln(
          '1200×1200 (${d.exists1200x1200 ? "exists" : "missing"}): ${d.expected1200x1200Url}',
        );
      }
      if (d.expected1200x630Url != null) {
        buffer.writeln(
          '1200×630 (${d.exists1200x630 ? "exists" : "missing"}): ${d.expected1200x630Url}',
        );
      }
      if (d.actualResizedDownloadUrl != null) {
        buffer.writeln('Actual resized download: ${d.actualResizedDownloadUrl}');
      }
      if (widget.showSpotsApiUrls) {
        buffer.writeln('Spots API: ${d.spotsApiUrl}');
      }
      buffer.writeln();
    }
    return buffer.toString().trim();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxWidth = MediaQuery.sizeOf(context).width > 700 ? 700.0 : null;

    return PointerInterceptor(
      child: Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth ?? double.infinity,
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _l10n.adminImageUrlsDialogTitle(widget.entityLabel),
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _load,
                        child: Text(_l10n.profileRetry),
                      ),
                    ],
                  ),
                )
              else if (_diagnostics == null || _diagnostics!.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_l10n.adminImageUrlsEmpty),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    itemCount: _diagnostics!.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _diagnostics!.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 8),
                          child: Text(
                            widget.showSpotsApiUrls
                                ? _l10n.adminImageUrlsApiFootnote
                                : _l10n.adminImageUrlsEventApiFootnote,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.65,
                              ),
                            ),
                          ),
                        );
                      }
                      final d = _diagnostics![index];
                      return _ImageDiagnosticCard(
                        diagnostic: d,
                        total: _diagnostics!.length,
                        showSpotsApiUrls: widget.showSpotsApiUrls,
                        onCopy: _copyText,
                      );
                    },
                  ),
                ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!_loading &&
                        _diagnostics != null &&
                        _diagnostics!.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => _copyText(_buildFullReport()),
                        icon: const Icon(Icons.copy_all, size: 18),
                        label: Text(_l10n.adminImageUrlsCopyAll),
                      ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(_l10n.spotDetailClose),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageDiagnosticCard extends StatelessWidget {
  const _ImageDiagnosticCard({
    required this.diagnostic,
    required this.total,
    required this.showSpotsApiUrls,
    required this.onCopy,
  });

  final AdminImageUrlDiagnostic diagnostic;
  final int total;
  final bool showSpotsApiUrls;
  final Future<void> Function(String text) onCopy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.adminImageUrlsImageIndex(diagnostic.index, total),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _PreviewRow(diagnostic: diagnostic),
            const SizedBox(height: 12),
            _UrlRow(
              label: l10n.adminImageUrlsLabelFirestore,
              value: diagnostic.originalUrl,
              status: null,
              onCopy: onCopy,
            ),
            if (diagnostic.expected1200x1200Url != null)
              _UrlRow(
                label: l10n.adminImageUrlsLabel1200x1200,
                value: diagnostic.expected1200x1200Url!,
                status: diagnostic.exists1200x1200
                    ? l10n.adminImageUrlsStatusExists
                    : l10n.adminImageUrlsStatusMissing,
                onCopy: onCopy,
              ),
            if (diagnostic.expected1200x630Url != null)
              _UrlRow(
                label: l10n.adminImageUrlsLabel1200x630,
                value: diagnostic.expected1200x630Url!,
                status: diagnostic.exists1200x630
                    ? l10n.adminImageUrlsStatusExists
                    : l10n.adminImageUrlsStatusMissing,
                onCopy: onCopy,
              ),
            if (diagnostic.actualResizedDownloadUrl != null)
              _UrlRow(
                label: l10n.adminImageUrlsLabelActualDownload,
                value: diagnostic.actualResizedDownloadUrl!,
                status: l10n.adminImageUrlsStatusExists,
                onCopy: onCopy,
              ),
            if (!diagnostic.isResizable)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.adminImageUrlsStatusNotApplicable,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            if (showSpotsApiUrls)
              _UrlRow(
                label: l10n.adminImageUrlsLabelSpotsApi,
                value: diagnostic.spotsApiUrl,
                status: null,
                onCopy: onCopy,
              ),
          ],
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.diagnostic});

  final AdminImageUrlDiagnostic diagnostic;

  static const double _size = 72;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Row(
      children: [
        _PreviewTile(
          label: l10n.adminImageUrlsPreviewOriginal,
          url: diagnostic.originalUrl,
        ),
        const SizedBox(width: 8),
        _PreviewTile(
          label: l10n.adminImageUrlsPreview1200,
          url: diagnostic.exists1200x1200
              ? (diagnostic.actualResizedDownloadUrl ??
                  diagnostic.expected1200x1200Url)
              : diagnostic.expected1200x1200Url,
          missing: diagnostic.isResizable && !diagnostic.exists1200x1200,
        ),
        const SizedBox(width: 8),
        _PreviewTile(
          label: l10n.adminImageUrlsPreview630,
          url: diagnostic.exists1200x630
              ? diagnostic.expected1200x630Url
              : diagnostic.expected1200x630Url,
          missing: diagnostic.isResizable && !diagnostic.exists1200x630,
        ),
      ],
    );
  }
}

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({
    required this.label,
    required this.url,
    this.missing = false,
  });

  final String label;
  final String? url;
  final bool missing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: _PreviewRow._size,
              height: _PreviewRow._size,
              child: url == null || url!.isEmpty
                  ? ColoredBox(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                    )
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          url!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => ColoredBox(
                            color: theme.colorScheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                        if (missing)
                          Container(
                            color: Colors.black.withValues(alpha: 0.45),
                            alignment: Alignment.center,
                            child: Text(
                              AppLocalizations.of(context)!
                                  .adminImageUrlsStatusMissing,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontSize: 9,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UrlRow extends StatelessWidget {
  const _UrlRow({
    required this.label,
    required this.value,
    required this.onCopy,
    this.status,
  });

  final String label;
  final String value;
  final String? status;
  final Future<void> Function(String text) onCopy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (status != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: status == l10n.adminImageUrlsStatusExists
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: status == l10n.adminImageUrlsStatusExists
                          ? Colors.green.shade800
                          : Colors.orange.shade900,
                      fontSize: 10,
                    ),
                  ),
                ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.copy, size: 18),
                tooltip: l10n.adminImageUrlsCopyRow,
                onPressed: () => onCopy(value),
              ),
            ],
          ),
          SelectableText(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
