import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_svg/flutter_svg.dart';

import '../utils/marker_icon_utils.dart';

/// Combined Explore bottom-sheet chrome: brand mark, spots/events/community
/// pill toggle with live counts, and expand/collapse control.
class ExploreBottomSheetHeader extends StatelessWidget {
  static const String modeSpots = 'spots';
  static const String modeEvents = 'events';
  static const String modeCommunity = 'community';

  /// Icon used for the community segment (no map pin exists for it).
  static const IconData communityIcon = Icons.groups_2_outlined;

  /// Below this pill width, unselected segments collapse to [compactLabel]s
  /// (just the count) so three segments fit on narrow phones.
  @visibleForTesting
  static const double compactPillBreakpoint = 340;

  final String mode;
  final String spotsLabel;
  final String eventsLabel;

  /// Omit to hide the community segment (two-segment legacy layout).
  final String? communityLabel;

  /// Short labels (typically just the count) shown on unselected segments
  /// when the pill has little horizontal room. Fall back to the full labels.
  final String? spotsCompactLabel;
  final String? eventsCompactLabel;
  final String? communityCompactLabel;

  /// Shown inside the spots segment (e.g. ranked "best shown" hint).
  final String? spotsDetailSuffix;

  /// Shown inside the events segment when not all pins are listed.
  final String? eventsDetailSuffix;

  /// Swap the segment's pin for a spinner while its data loads.
  final bool spotsLoading;
  final bool eventsLoading;
  final bool communityLoading;
  final bool isSheetOpen;
  final ValueChanged<String> onModeChanged;
  final VoidCallback onToggleSheet;

  const ExploreBottomSheetHeader({
    super.key,
    required this.mode,
    required this.spotsLabel,
    required this.eventsLabel,
    this.communityLabel,
    this.spotsCompactLabel,
    this.eventsCompactLabel,
    this.communityCompactLabel,
    this.spotsDetailSuffix,
    this.eventsDetailSuffix,
    this.spotsLoading = false,
    this.eventsLoading = false,
    this.communityLoading = false,
    required this.isSheetOpen,
    required this.onModeChanged,
    required this.onToggleSheet,
  });

  void _onSegmentTap(String next) {
    if (next != mode) {
      if (!kIsWeb) {
        HapticFeedback.selectionClick();
      }
      onModeChanged(next);
    }
    if (!isSheetOpen) {
      onToggleSheet();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final logoAsset = isDark
        ? 'assets/images/logo-square-dark.svg'
        : 'assets/images/logo-square.svg';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        InkWell(
          onTap: onToggleSheet,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: RepaintBoundary(
              child: SvgPicture.asset(
                logoAsset,
                width: 28,
                height: 28,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact =
                  communityLabel != null &&
                  constraints.maxWidth < compactPillBreakpoint;
              return Center(
                child: _ModePillToggle(
                  mode: mode,
                  compact: compact,
                  spotsLabel: spotsLabel,
                  eventsLabel: eventsLabel,
                  communityLabel: communityLabel,
                  spotsCompactLabel: spotsCompactLabel,
                  eventsCompactLabel: eventsCompactLabel,
                  communityCompactLabel: communityCompactLabel,
                  spotsDetailSuffix: spotsDetailSuffix,
                  eventsDetailSuffix: eventsDetailSuffix,
                  spotsLoading: spotsLoading,
                  eventsLoading: eventsLoading,
                  communityLoading: communityLoading,
                  onSegmentTap: _onSegmentTap,
                ),
              );
            },
          ),
        ),
        IconButton(
          onPressed: onToggleSheet,
          visualDensity: VisualDensity.compact,
          icon: Icon(
            isSheetOpen ? Icons.expand_more : Icons.expand_less,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ModePillToggle extends StatefulWidget {
  final String mode;
  final bool compact;
  final String spotsLabel;
  final String eventsLabel;
  final String? communityLabel;
  final String? spotsCompactLabel;
  final String? eventsCompactLabel;
  final String? communityCompactLabel;
  final String? spotsDetailSuffix;
  final String? eventsDetailSuffix;
  final bool spotsLoading;
  final bool eventsLoading;
  final bool communityLoading;
  final ValueChanged<String> onSegmentTap;

  const _ModePillToggle({
    required this.mode,
    required this.compact,
    required this.spotsLabel,
    required this.eventsLabel,
    this.communityLabel,
    this.spotsCompactLabel,
    this.eventsCompactLabel,
    this.communityCompactLabel,
    this.spotsDetailSuffix,
    this.eventsDetailSuffix,
    this.spotsLoading = false,
    this.eventsLoading = false,
    this.communityLoading = false,
    required this.onSegmentTap,
  });

  @override
  State<_ModePillToggle> createState() => _ModePillToggleState();
}

class _ModePillToggleState extends State<_ModePillToggle> {
  final GlobalKey _spotsKey = GlobalKey();
  final GlobalKey _eventsKey = GlobalKey();
  final GlobalKey _communityKey = GlobalKey();
  final GlobalKey _stackKey = GlobalKey();

  double _indicatorLeft = 0;
  double _indicatorWidth = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(_updateIndicator);
  }

  @override
  void didUpdateWidget(covariant _ModePillToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode ||
        oldWidget.compact != widget.compact ||
        oldWidget.spotsLabel != widget.spotsLabel ||
        oldWidget.eventsLabel != widget.eventsLabel ||
        oldWidget.communityLabel != widget.communityLabel ||
        oldWidget.spotsCompactLabel != widget.spotsCompactLabel ||
        oldWidget.eventsCompactLabel != widget.eventsCompactLabel ||
        oldWidget.communityCompactLabel != widget.communityCompactLabel ||
        oldWidget.spotsDetailSuffix != widget.spotsDetailSuffix ||
        oldWidget.eventsDetailSuffix != widget.eventsDetailSuffix) {
      WidgetsBinding.instance.addPostFrameCallback(_updateIndicator);
    }
  }

  GlobalKey get _selectedSegmentKey {
    switch (widget.mode) {
      case ExploreBottomSheetHeader.modeEvents:
        return _eventsKey;
      case ExploreBottomSheetHeader.modeCommunity:
        return widget.communityLabel != null ? _communityKey : _spotsKey;
      default:
        return _spotsKey;
    }
  }

  void _updateIndicator(_) {
    if (!mounted) return;
    final stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final segmentBox =
        _selectedSegmentKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null || segmentBox == null || !segmentBox.hasSize) {
      return;
    }
    final offset = segmentBox.localToGlobal(Offset.zero, ancestor: stackBox);
    final nextLeft = offset.dx;
    final nextWidth = segmentBox.size.width;
    if (nextLeft != _indicatorLeft || nextWidth != _indicatorWidth) {
      setState(() {
        _indicatorLeft = nextLeft;
        _indicatorWidth = nextWidth;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 220);
    final curve = Curves.easeOutCubic;
    final hasCommunity = widget.communityLabel != null;
    final isCommunity =
        hasCommunity && widget.mode == ExploreBottomSheetHeader.modeCommunity;
    final isEvents = widget.mode == ExploreBottomSheetHeader.modeEvents;
    final isSpots = !isEvents && !isCommunity;

    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Stack(
          key: _stackKey,
          clipBehavior: Clip.none,
          children: [
            AnimatedPositioned(
              duration: duration,
              curve: curve,
              left: _indicatorLeft,
              top: 0,
              bottom: 0,
              width: _indicatorWidth,
              child: Opacity(
                opacity: _indicatorWidth > 0 ? 1 : 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.12),
                        blurRadius: 6,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ModeSegment(
                  key: _spotsKey,
                  selected: isSpots,
                  compact: widget.compact,
                  pinAsset: MarkerIconUtils.mapPinSpotLegendAsset,
                  label: widget.spotsLabel,
                  compactLabel: widget.spotsCompactLabel,
                  detailSuffix: widget.spotsDetailSuffix,
                  isLoading: widget.spotsLoading,
                  onTap: () =>
                      widget.onSegmentTap(ExploreBottomSheetHeader.modeSpots),
                ),
                _ModeSegment(
                  key: _eventsKey,
                  selected: isEvents,
                  compact: widget.compact,
                  pinAsset: MarkerIconUtils.mapPinEventLegendAsset,
                  label: widget.eventsLabel,
                  compactLabel: widget.eventsCompactLabel,
                  detailSuffix: widget.eventsDetailSuffix,
                  isLoading: widget.eventsLoading,
                  onTap: () =>
                      widget.onSegmentTap(ExploreBottomSheetHeader.modeEvents),
                ),
                if (hasCommunity)
                  _ModeSegment(
                    key: _communityKey,
                    selected: isCommunity,
                    compact: widget.compact,
                    icon: ExploreBottomSheetHeader.communityIcon,
                    label: widget.communityLabel!,
                    compactLabel: widget.communityCompactLabel,
                    isLoading: widget.communityLoading,
                    onTap: () => widget.onSegmentTap(
                      ExploreBottomSheetHeader.modeCommunity,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeSegment extends StatelessWidget {
  static const double _pinLogicalHeight = 16;

  final bool selected;
  final bool compact;

  /// Legend pin asset; mutually exclusive with [icon].
  final String? pinAsset;
  final IconData? icon;
  final String label;
  final String? compactLabel;
  final String? detailSuffix;
  final bool isLoading;
  final VoidCallback onTap;

  const _ModeSegment({
    super.key,
    required this.selected,
    required this.compact,
    this.pinAsset,
    this.icon,
    required this.label,
    this.compactLabel,
    this.detailSuffix,
    this.isLoading = false,
    required this.onTap,
  }) : assert(pinAsset != null || icon != null);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final foreground = selected
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;
    final suffixColor = selected
        ? colorScheme.onPrimaryContainer.withValues(alpha: 0.72)
        : colorScheme.onSurfaceVariant.withValues(alpha: 0.72);
    // Unselected segments shrink to their count when the pill is cramped;
    // the selected one always keeps its full label so the mode stays readable.
    final useCompact = compact && !selected && compactLabel != null;
    final shownLabel = useCompact ? compactLabel! : label;
    final hasDetailSuffix =
        !useCompact && detailSuffix != null && detailSuffix!.isNotEmpty;
    final labelStyle = theme.textTheme.labelLarge!.copyWith(
      color: foreground,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      height: 1.2,
    );
    final suffixStyle = theme.textTheme.labelSmall?.copyWith(
      color: suffixColor,
      height: 1.2,
    );
    // Reserve two text lines so pill height is stable; center when only
    // the primary label is shown.
    final labelLineHeight =
        (labelStyle.fontSize ?? 14) * (labelStyle.height ?? 1.2);
    final suffixLineHeight =
        (suffixStyle?.fontSize ?? 11) * (suffixStyle?.height ?? 1.2);
    final glyphWidth = MarkerIconUtils.mapPinLogicalWidthForHeight(
      _pinLogicalHeight,
    );

    Widget glyph;
    if (isLoading) {
      glyph = Center(
        child: SizedBox.square(
          dimension: 12,
          child: CircularProgressIndicator(strokeWidth: 1.5, color: foreground),
        ),
      );
    } else if (pinAsset != null) {
      glyph = RepaintBoundary(
        child: SvgPicture.asset(pinAsset!, fit: BoxFit.contain),
      );
    } else {
      glyph = Icon(icon, size: _pinLogicalHeight, color: foreground);
    }

    return Semantics(
      button: true,
      selected: selected,
      label: useCompact ? label : null,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 10,
              vertical: 7,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  height: _pinLogicalHeight,
                  // Same box for pin, icon, and spinner so the pill does not shift.
                  width: icon != null ? _pinLogicalHeight : glyphWidth,
                  child: glyph,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: SizedBox(
                    height: labelLineHeight + suffixLineHeight,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          shownLabel,
                          textAlign: TextAlign.center,
                          style: labelStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (hasDetailSuffix)
                          Text(
                            detailSuffix!,
                            textAlign: TextAlign.center,
                            style: suffixStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
