import 'package:flutter/material.dart';
import 'package:country_flags/country_flags.dart';

class LocationInfoBox extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String? address;
  final String? countryCode;
  final bool isGeocoding;
  final VoidCallback? onOpenInMaps;
  final VoidCallback? onCopyAddress;

  const LocationInfoBox({
    super.key,
    required this.latitude,
    required this.longitude,
    this.address,
    this.countryCode,
    this.isGeocoding = false,
    this.onOpenInMaps,
    this.onCopyAddress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Address - prominent and copyable with Open in Maps button
          if (address != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Always show flag
                countryCode != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: SizedBox(
                          height: 20,
                          width: 30,
                          child: CountryFlag.fromCountryCode(
                            countryCode!,
                          ),
                        ),
                      )
                    : Container(
                        height: 20,
                        width: 30,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: onCopyAddress,
                    child: SelectableText(
                      address!,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                            height: 1.4,
                          ),
                    ),
                  ),
                ),
                if (onOpenInMaps != null)
                  IconButton(
                    onPressed: onOpenInMaps,
                    icon: Icon(
                      Icons.directions,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    tooltip: 'Directions',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ] else ...[
            // If no address, show flag and button on the right
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Always show flag
                countryCode != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: SizedBox(
                          height: 20,
                          width: 30,
                          child: CountryFlag.fromCountryCode(
                            countryCode!,
                          ),
                        ),
                      )
                    : Container(
                        height: 20,
                        width: 30,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                if (onOpenInMaps != null) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: onOpenInMaps,
                    icon: Icon(
                      Icons.directions,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    tooltip: 'Directions',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ],
            ),
            if (onOpenInMaps != null) const SizedBox(height: 8),
          ],
          // Coordinates
          Row(
            children: [
              Icon(
                Icons.gps_fixed,
                size: 16,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 4),
              SelectableText(
                '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
              ),
            ],
          ),
          // Geocoding indicator
          if (isGeocoding) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Getting address...',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

