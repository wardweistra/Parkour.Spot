import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_svg/flutter_svg.dart';

/// Combined Explore bottom-sheet chrome: brand mark, spots/events pill toggle
/// with live counts, and expand/collapse control.
class ExploreBottomSheetHeader extends StatelessWidget {
  static const String modeSpots = 'spots';
  static const String modeEvents = 'events';

  final String mode;
  final String spotsLabel;
  final String eventsLabel;
  /// Shown inside the spots segment (e.g. ranked "best shown" hint).
  final String? spotsDetailSuffix;
  /// Shown inside the events segment when not all pins are listed.
  final String? eventsDetailSuffix;
  final bool isSheetOpen;
  final ValueChanged<String> onModeChanged;
  final VoidCallback onToggleSheet;

  const ExploreBottomSheetHeader({
    super.key,
    required this.mode,
    required this.spotsLabel,
    required this.eventsLabel,
    this.spotsDetailSuffix,
    this.eventsDetailSuffix,
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
            child: SvgPicture.asset(
              logoAsset,
              width: 28,
              height: 28,
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Center(
            child: _ModePillToggle(
              mode: mode,
              spotsLabel: spotsLabel,
              eventsLabel: eventsLabel,
              spotsDetailSuffix: spotsDetailSuffix,
              eventsDetailSuffix: eventsDetailSuffix,
              onSegmentTap: _onSegmentTap,
            ),
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
  final String spotsLabel;
  final String eventsLabel;
  final String? spotsDetailSuffix;
  final String? eventsDetailSuffix;
  final ValueChanged<String> onSegmentTap;

  const _ModePillToggle({
    required this.mode,
    required this.spotsLabel,
    required this.eventsLabel,
    this.spotsDetailSuffix,
    this.eventsDetailSuffix,
    required this.onSegmentTap,
  });

  @override
  State<_ModePillToggle> createState() => _ModePillToggleState();
}

class _ModePillToggleState extends State<_ModePillToggle> {
  final GlobalKey _spotsKey = GlobalKey();
  final GlobalKey _eventsKey = GlobalKey();
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
    WidgetsBinding.instance.addPostFrameCallback(_updateIndicator);
  }

  void _updateIndicator(_) {
    if (!mounted) return;
    final stackBox =
        _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final segmentKey = widget.mode == ExploreBottomSheetHeader.modeSpots
        ? _spotsKey
        : _eventsKey;
    final segmentBox =
        segmentKey.currentContext?.findRenderObject() as RenderBox?;
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
    final isSpots = widget.mode == ExploreBottomSheetHeader.modeSpots;

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
                  icon: Icons.place_outlined,
                  selectedIcon: Icons.place,
                  label: widget.spotsLabel,
                  detailSuffix: widget.spotsDetailSuffix,
                  onTap: () => widget.onSegmentTap(
                    ExploreBottomSheetHeader.modeSpots,
                  ),
                ),
                _ModeSegment(
                  key: _eventsKey,
                  selected: !isSpots,
                  icon: Icons.event_outlined,
                  selectedIcon: Icons.event,
                  label: widget.eventsLabel,
                  detailSuffix: widget.eventsDetailSuffix,
                  onTap: () => widget.onSegmentTap(
                    ExploreBottomSheetHeader.modeEvents,
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
  final bool selected;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String? detailSuffix;
  final VoidCallback onTap;

  const _ModeSegment({
    super.key,
    required this.selected,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.detailSuffix,
    required this.onTap,
  });

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

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  selected ? selectedIcon : icon,
                  size: 16,
                  color: foreground,
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelLarge!.copyWith(
                          color: foreground,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (detailSuffix != null && detailSuffix!.isNotEmpty)
                        Text(
                          detailSuffix!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: suffixColor,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
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
