import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/parkour_event.dart';
import '../../models/spot.dart';
import '../../services/spot_service.dart';
import '../../widgets/page_scaffold.dart';

class EventDetailScreen extends StatelessWidget {
  const EventDetailScreen({super.key, required this.event});

  final ParkourEvent event;

  @override
  Widget build(BuildContext context) {
    final websiteUrl = event.websiteUrl?.trim();
    final hasWebsite = websiteUrl != null && websiteUrl.isNotEmpty;
    final hasLocation = event.latitude != null && event.longitude != null;
    final hasAddress = event.address?.trim().isNotEmpty == true;

    return PageScaffold(
      title: event.title,
      onBack: () {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          context.go('/explore');
        }
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (event.description?.trim().isNotEmpty == true) ...[
            Text(
              event.description!,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Chip(
                avatar: const Icon(Icons.schedule, size: 16),
                label: Text(_formatUtc(event.startAt)),
              ),
              if (event.endAt != null)
                Chip(
                  avatar: const Icon(Icons.hourglass_bottom, size: 16),
                  label: Text(_formatUtc(event.endAt!)),
                ),
              Chip(
                avatar: const Icon(Icons.place_outlined, size: 16),
                label: Text('${event.spotIds.length} linked spot(s)'),
              ),
            ],
          ),
          if (event.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Images', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 190,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: event.imageUrls.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      event.imageUrls[index],
                      width: 280,
                      height: 190,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 280,
                        height: 190,
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          if (hasWebsite) ...[
            const SizedBox(height: 16),
            Text('Website', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _openExternal(websiteUrl!),
              child: Text(
                websiteUrl!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
          if (hasLocation || hasAddress) ...[
            const SizedBox(height: 16),
            Text('Location', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              hasAddress
                  ? event.address!.trim()
                  : '${event.latitude!.toStringAsFixed(5)}, ${event.longitude!.toStringAsFixed(5)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (hasLocation)
              TextButton.icon(
                onPressed: () => _openMap(event.latitude!, event.longitude!),
                icon: const Icon(Icons.map_outlined),
                label: const Text('Open in maps'),
              ),
          ],
          const SizedBox(height: 16),
          Text('Linked spots', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _LinkedSpotsSection(spotIds: event.spotIds),
          const SizedBox(height: 8),
          SelectableText(
            'Event ID: ${event.id ?? '(pending)'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  String _formatUtc(DateTime value) {
    return '${DateFormat.yMMMd().add_Hm().format(value.toUtc())} UTC';
  }

  Future<void> _openExternal(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openMap(double lat, double lng) async {
    final mapsUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    await launchUrl(mapsUri, mode: LaunchMode.externalApplication);
  }
}

class _LinkedSpotsSection extends StatefulWidget {
  const _LinkedSpotsSection({required this.spotIds});

  final List<String> spotIds;

  @override
  State<_LinkedSpotsSection> createState() => _LinkedSpotsSectionState();
}

class _LinkedSpotsSectionState extends State<_LinkedSpotsSection> {
  Future<List<Spot>>? _spotsFuture;

  @override
  void initState() {
    super.initState();
    _spotsFuture = _loadSpots();
  }

  @override
  void didUpdateWidget(covariant _LinkedSpotsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spotIds.join(',') != widget.spotIds.join(',')) {
      _spotsFuture = _loadSpots();
    }
  }

  Future<List<Spot>> _loadSpots() async {
    final spotService = context.read<SpotService>();
    final spots = await Future.wait(
      widget.spotIds.map(spotService.getSpotById),
    );
    return spots.whereType<Spot>().toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Spot>>(
      future: _spotsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }
        final spots = snapshot.data ?? const <Spot>[];
        if (spots.isEmpty) {
          return const Text('No linked spots found.');
        }
        return Column(
          children: spots
              .map(
                (spot) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(spot.name),
                    subtitle: Text(spot.address ?? spot.city ?? spot.id ?? ''),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: spot.id == null
                        ? null
                        : () => context.push('/spot/${spot.id}'),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}
