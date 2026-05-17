import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../l10n/app_localizations.dart';
import '../models/event_map_pin.dart';

/// Compact list row for an event in the Explore bottom sheet.
class ExploreEventListTile extends StatelessWidget {
  final EventMapPin pin;
  final VoidCallback? onLocate;

  const ExploreEventListTile({
    super.key,
    required this.pin,
    this.onLocate,
  });

  String _formatWhen(BuildContext context, DateTime dateTime) {
    final local = dateTime.toLocal();
    final localizations = MaterialLocalizations.of(context);
    final date = localizations.formatMediumDate(local);
    final time = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(local));
    return '$date · $time';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/event/${pin.eventId}'),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                pin.kind == EventMapPinKind.venue
                    ? Icons.event
                    : Icons.place_outlined,
                color: colors.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pin.title,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatWhen(context, pin.startAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              if (onLocate != null)
                TextButton(
                  onPressed: onLocate,
                  child: Text(l10n.exploreEventLocate),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Centers the map on [pin] when [onLocate] is invoked from [ExploreEventListTile].
void locateEventPinOnMap(
  GoogleMapController? controller,
  EventMapPin pin,
) {
  controller?.animateCamera(
    CameraUpdate.newLatLng(LatLng(pin.latitude, pin.longitude)),
  );
}
