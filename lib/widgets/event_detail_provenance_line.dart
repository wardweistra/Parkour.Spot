import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../constants/spot_detail_ui.dart';
import '../l10n/app_localizations.dart';
import '../models/parkour_event.dart';
import '../services/user_profile_service.dart';
import '../utils/relative_date_localization.dart';
import 'event_source_details_dialog.dart';

/// Provenance attribution for an event detail page (creator, import source, dates).
class EventDetailProvenanceLine extends StatefulWidget {
  const EventDetailProvenanceLine({
    super.key,
    required this.event,
    this.footerStyle = false,
  });

  final ParkourEvent event;

  /// Muted footer text without a leading info icon (avoids stacked metadata rows).
  final bool footerStyle;

  @override
  State<EventDetailProvenanceLine> createState() =>
      _EventDetailProvenanceLineState();
}

class _EventDetailProvenanceLineState extends State<EventDetailProvenanceLine> {
  String? _creatorDisplayName;
  bool _loadingCreator = false;

  ParkourEvent get _event => widget.event;

  @override
  void initState() {
    super.initState();
    _loadCreatorIfNeeded();
  }

  @override
  void didUpdateWidget(covariant EventDetailProvenanceLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event.id != _event.id ||
        oldWidget.event.createdBy != _event.createdBy) {
      _creatorDisplayName = null;
      _loadCreatorIfNeeded();
    }
  }

  Future<void> _loadCreatorIfNeeded() async {
    final createdBy = _event.createdBy?.trim();
    if (!_event.isNativeEvent ||
        _event.createdFromCreateNative ||
        createdBy == null ||
        createdBy.isEmpty) {
      return;
    }
    setState(() => _loadingCreator = true);
    try {
      final profile = await context.read<UserProfileService>().getUserProfile(
        createdBy,
      );
      if (!mounted) return;
      final displayName = profile?.displayName?.trim();
      final username = profile?.username?.trim();
      setState(() {
        _creatorDisplayName = (displayName != null && displayName.isNotEmpty)
            ? displayName
            : (username != null && username.isNotEmpty)
            ? username
            : null;
        _loadingCreator = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingCreator = false);
    }
  }

  void _showEventSourceDetails() {
    final sourceId = _event.eventSourceId?.trim();
    if (sourceId == null || sourceId.isEmpty) return;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => EventSourceDetailsDialog(sourceId: sourceId),
    );
  }

  Future<void> _navigateToUserProfile(String userId) async {
    try {
      final user = await context.read<UserProfileService>().getUserProfile(
        userId,
      );
      if (!mounted) return;
      final identifier = user?.username?.trim().isNotEmpty == true
          ? user!.username!.trim()
          : userId;
      context.push('/user/$identifier');
    } catch (_) {
      if (!mounted) return;
      context.push('/user/$userId');
    }
  }

  bool _shouldShow() {
    final createdBy = _event.createdBy?.trim();
    final hasCreator =
        !_event.createdFromCreateNative &&
        createdBy != null &&
        createdBy.isNotEmpty;
    final hasContributors = _event.contributors.isNotEmpty;
    final hasSource =
        !_event.isNativeEvent &&
        ((_event.eventSourceId?.trim().isNotEmpty ?? false) ||
            (_event.eventSourceName?.trim().isNotEmpty ?? false));
    final hasCreatedDate = _event.createdAt != null;
    final hasUpdatedDate =
        _event.updatedAt != null &&
        (_event.createdAt == null || _event.updatedAt != _event.createdAt);
    return hasCreator ||
        hasContributors ||
        hasSource ||
        hasCreatedDate ||
        hasUpdatedDate ||
        _loadingCreator;
  }

  String _trimLeadingContributorPrefix(String value) {
    final trimmed = value.trimLeft();
    if (trimmed.startsWith(',')) {
      return trimmed.substring(1).trimLeft();
    }
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldShow()) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.4,
    );
    final spans = _buildSpans(context, l10n, theme, textStyle);

    if (spans.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.only(
        top: widget.footerStyle
            ? SpotDetailUi.detailFooterGap
            : SpotDetailUi.detailSectionGap,
      ),
      child: widget.footerStyle
          ? RichText(
              text: TextSpan(style: textStyle, children: spans),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.info_outline,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(style: textStyle, children: spans),
                  ),
                ),
              ],
            ),
    );
  }

  List<TextSpan> _buildSpans(
    BuildContext context,
    AppLocalizations l10n,
    ThemeData theme,
    TextStyle? textStyle,
  ) {
    final spans = <TextSpan>[];
    var hasPreviousContent = false;
    final createdById = _event.createdBy?.trim();
    final willHaveUpdatedDate =
        _event.updatedAt != null &&
        (_event.createdAt == null || _event.updatedAt != _event.createdAt);

    if (_event.isNativeEvent &&
        !_event.createdFromCreateNative &&
        createdById != null) {
      final creatorLabel = _loadingCreator
          ? '…'
          : (_creatorDisplayName ?? createdById);

      if (_event.createdAt != null) {
        final createdDateText = formatRelativeDateInDays(
          _event.createdAt!,
          l10n,
        );
        spans.add(
          TextSpan(
            text: l10n.eventDetailEventCreatedOnDateBy(createdDateText),
            style: textStyle,
          ),
        );
      } else {
        spans.add(
          TextSpan(text: l10n.eventDetailEventCreatedBy, style: textStyle),
        );
      }

      if (!_loadingCreator) {
        spans.add(
          TextSpan(
            text: creatorLabel,
            style: textStyle?.copyWith(color: theme.colorScheme.primary),
            recognizer: TapGestureRecognizer()
              ..onTap = () => _navigateToUserProfile(createdById),
          ),
        );
      } else {
        spans.add(TextSpan(text: creatorLabel, style: textStyle));
      }

      hasPreviousContent = true;
    } else if (_event.isNativeEvent && _event.createdAt != null) {
      final createdDateText = formatRelativeDateInDays(_event.createdAt!, l10n);
      spans.add(
        TextSpan(
          text: l10n.eventDetailEventCreatedOnDate(createdDateText),
          style: textStyle,
        ),
      );
      hasPreviousContent = true;
    }

    if (!_event.isNativeEvent) {
      final sourceName =
          _event.eventSourceName?.trim() ?? l10n.spotDetailUnknownSource;
      final sourceId = _event.eventSourceId?.trim();
      final canOpenSourceDetails = sourceId != null && sourceId.isNotEmpty;

      if (hasPreviousContent) {
        spans.add(TextSpan(text: ' / ', style: textStyle));
      }

      if (!hasPreviousContent && _event.createdAt != null) {
        final createdDateText = formatRelativeDateInDays(
          _event.createdAt!,
          l10n,
        );
        spans.add(
          TextSpan(
            text: l10n.eventDetailEventImportedOnDateFrom(createdDateText),
            style: textStyle,
          ),
        );
      } else {
        spans.add(
          TextSpan(text: l10n.eventDetailEventImportedFrom, style: textStyle),
        );
      }

      spans.add(
        TextSpan(
          text: sourceName,
          style: canOpenSourceDetails
              ? textStyle?.copyWith(color: theme.colorScheme.primary)
              : textStyle,
          recognizer: canOpenSourceDetails
              ? (TapGestureRecognizer()..onTap = _showEventSourceDetails)
              : null,
        ),
      );
      hasPreviousContent = true;
    }

    final filteredContributors = _event.contributors.where((c) {
      final userId = c['userId']?.trim();
      return userId == null || userId != createdById;
    }).toList();
    if (filteredContributors.isNotEmpty) {
      final improvedByPrefix = hasPreviousContent
          ? (willHaveUpdatedDate
                ? l10n.spotDetailImprovedByAfterComma
                : l10n.spotDetailImprovedByAfterAnd)
          : _trimLeadingContributorPrefix(l10n.spotDetailImprovedByAfterComma);
      spans.add(TextSpan(text: improvedByPrefix, style: textStyle));

      for (var i = 0; i < filteredContributors.length; i++) {
        final contributor = filteredContributors[i];
        final userName = contributor['userName']?.trim();
        final userId = contributor['userId']?.trim();
        final label = userName != null && userName.isNotEmpty
            ? userName
            : l10n.spotDetailUnknownUser;

        if (i > 0) {
          spans.add(
            TextSpan(
              text: i == filteredContributors.length - 1
                  ? l10n.spotDetailListJoinAnd
                  : l10n.spotDetailListJoinComma,
              style: textStyle,
            ),
          );
        }

        if (userId != null && userId.isNotEmpty) {
          spans.add(
            TextSpan(
              text: label,
              style: textStyle?.copyWith(color: theme.colorScheme.primary),
              recognizer: TapGestureRecognizer()
                ..onTap = () => _navigateToUserProfile(userId),
            ),
          );
        } else {
          spans.add(TextSpan(text: label, style: textStyle));
        }
      }

      hasPreviousContent = true;
    }

    var hasUpdatedDate = false;
    if (_event.updatedAt != null &&
        _event.createdAt != null &&
        _event.updatedAt != _event.createdAt) {
      final updatedDateText = formatRelativeDateInDays(_event.updatedAt!, l10n);
      spans.add(
        TextSpan(
          text: hasPreviousContent
              ? l10n.spotDetailLastUpdatedAfterCommaAnd(updatedDateText)
              : l10n.spotDetailLastUpdatedAfterAnd(updatedDateText),
          style: textStyle,
        ),
      );
      hasUpdatedDate = true;
    } else if (_event.updatedAt != null && _event.createdAt == null) {
      final updatedDateText = formatRelativeDateInDays(_event.updatedAt!, l10n);
      spans.add(
        TextSpan(
          text: hasPreviousContent
              ? l10n.spotDetailLastUpdatedAfterCommaAnd(updatedDateText)
              : l10n.spotDetailLastUpdatedAfterAnd(updatedDateText),
          style: textStyle,
        ),
      );
      hasUpdatedDate = true;
    }

    if (!hasUpdatedDate && hasPreviousContent) {
      spans.add(TextSpan(text: '.', style: textStyle));
    }

    return spans;
  }
}
