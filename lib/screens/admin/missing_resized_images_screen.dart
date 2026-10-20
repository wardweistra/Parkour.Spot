import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/app_localizations.dart';
import '../../services/auth_service.dart';
import '../../services/mobile_detection_service.dart';
import '../../services/spot_service.dart'
    show
        ResizedImageClassificationReport,
        ResizedImageEntityRow,
        ResizedImageStatusCounts,
        SpotService;
import '../../services/url_service.dart';

class MissingResizedImagesScreen extends StatefulWidget {
  const MissingResizedImagesScreen({super.key});

  @override
  State<MissingResizedImagesScreen> createState() =>
      _MissingResizedImagesScreenState();
}

class _MissingResizedImagesScreenState extends State<MissingResizedImagesScreen>
    with SingleTickerProviderStateMixin {
  ResizedImageClassificationReport? _report;
  bool _isLoading = false;
  String? _error;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runCheck();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _runCheck() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final spotService = Provider.of<SpotService>(context, listen: false);
      final report = await spotService.classifyResizedImages();
      if (mounted) {
        setState(() {
          _report = report;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        setState(() {
          _error = l10n.adminResizedImagesCheckFailed(e.toString());
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openSpot(String spotId, {String? countryCode, String? city}) async {
    if (MobileDetectionService.isRunningInBrowser) {
      final url = UrlService.generateSpotUrl(
        spotId,
        countryCode: countryCode,
        city: city,
      );
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else {
      context.push('/spot/$spotId');
    }
  }

  Future<void> _openEvent(String eventId) async {
    context.push('/event/$eventId');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final authService = context.watch<AuthService>();
    if (authService.isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.adminResizedImagesTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (!authService.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.adminResizedImagesTitle)),
        body: Center(child: Text(l10n.adminResizedImagesAccessDenied)),
      );
    }

    final report = _report;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.adminResizedImagesTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go('/admin');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _runCheck,
            tooltip: l10n.adminResizedImagesRefresh,
          ),
        ],
        bottom: report == null
            ? null
            : TabBar(
                controller: _tabController,
                tabs: [
                  Tab(
                    text:
                        '${l10n.adminResizedImagesTabNone} (${report.totals.none.entities})',
                  ),
                  Tab(
                    text:
                        '${l10n.adminResizedImagesTabOnly630} (${report.totals.only630.entities})',
                  ),
                  Tab(
                    text:
                        '${l10n.adminResizedImagesTabHas1200} (${report.totals.has1200.entities})',
                  ),
                ],
              ),
      ),
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() => _error = null);
                _runCheck();
              },
              child: Text(l10n.adminResizedImagesRetry),
            ),
          ],
        ),
      );
    }

    if (_isLoading && _report == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              l10n.adminResizedImagesLoading,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    if (_report == null) {
      return const SizedBox.shrink();
    }

    final report = _report!;
    return Column(
      children: [
        if (_isLoading) const LinearProgressIndicator(),
        _SummaryHeader(report: report, l10n: l10n),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _EntityListTab(
                rows: report.none,
                emptyMessage: l10n.adminResizedImagesEmptyNone,
                l10n: l10n,
                accent: Colors.orange,
                countLabel: (count) => l10n.adminResizedImagesMissingCount(count),
                showImageUrls: true,
                onOpenSpot: _openSpot,
                onOpenEvent: _openEvent,
              ),
              _EntityListTab(
                rows: report.only630,
                emptyMessage: l10n.adminResizedImagesEmptyOnly630,
                l10n: l10n,
                accent: Colors.amber.shade800,
                countLabel: (count) =>
                    l10n.adminResizedImagesOnly630Count(count),
                showImageUrls: false,
                onOpenSpot: _openSpot,
                onOpenEvent: _openEvent,
              ),
              _OkTab(report: report, l10n: l10n),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.report, required this.l10n});

  final ResizedImageClassificationReport report;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final totals = report.totals;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.adminResizedImagesSummaryNone(
            totals.none.images,
            totals.none.entities,
          )),
          const SizedBox(height: 4),
          Text(l10n.adminResizedImagesSummaryOnly630(
            totals.only630.images,
            totals.only630.entities,
          )),
          const SizedBox(height: 4),
          Text(l10n.adminResizedImagesSummaryHas1200(
            totals.has1200.images,
            totals.has1200.entities,
          )),
        ],
      ),
    );
  }
}

class _OkTab extends StatelessWidget {
  const _OkTab({required this.report, required this.l10n});

  final ResizedImageClassificationReport report;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.adminResizedImagesOkTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(l10n.adminResizedImagesOkBody),
        const SizedBox(height: 24),
        _StatusBreakdownCard(
          title: l10n.adminResizedImagesTabHas1200,
          totals: report.totals.has1200,
          spots: report.spots.has1200,
          events: report.events.has1200,
          l10n: l10n,
        ),
      ],
    );
  }
}

class _StatusBreakdownCard extends StatelessWidget {
  const _StatusBreakdownCard({
    required this.title,
    required this.totals,
    required this.spots,
    required this.events,
    required this.l10n,
  });

  final String title;
  final ResizedImageStatusCounts totals;
  final ResizedImageStatusCounts spots;
  final ResizedImageStatusCounts events;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(
              l10n.adminResizedImagesSummaryHas1200(
                totals.images,
                totals.entities,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.adminResizedImagesBreakdownSpots(
                spots.images,
                spots.entities,
              ),
            ),
            Text(
              l10n.adminResizedImagesBreakdownEvents(
                events.images,
                events.entities,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntityListTab extends StatelessWidget {
  const _EntityListTab({
    required this.rows,
    required this.emptyMessage,
    required this.l10n,
    required this.accent,
    required this.countLabel,
    required this.showImageUrls,
    required this.onOpenSpot,
    required this.onOpenEvent,
  });

  final List<ResizedImageEntityRow> rows;
  final String emptyMessage;
  final AppLocalizations l10n;
  final Color accent;
  final String Function(int count) countLabel;
  final bool showImageUrls;
  final Future<void> Function(
    String spotId, {
    String? countryCode,
    String? city,
  }) onOpenSpot;
  final Future<void> Function(String eventId) onOpenEvent;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, size: 64, color: Colors.green[600]),
              const SizedBox(height: 16),
              Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[700], fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: InkWell(
            onTap: () {
              if (row.isSpot) {
                onOpenSpot(
                  row.id,
                  countryCode: row.countryCode,
                  city: row.city,
                );
              } else {
                onOpenEvent(row.id);
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Chip(
                        label: Text(
                          row.isSpot
                              ? l10n.adminResizedImagesKindSpot
                              : l10n.adminResizedImagesKindEvent,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          row.name.isEmpty ? row.id : row.name,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      if (row.isSpot)
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => context.push('/spot/${row.id}/edit'),
                          tooltip: l10n.adminResizedImagesEditSpot,
                        ),
                    ],
                  ),
                  if (row.city.isNotEmpty || row.countryCode.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (row.city.isNotEmpty) row.city,
                        if (row.countryCode.isNotEmpty) row.countryCode,
                      ].join(', '),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () {
                      if (row.isSpot) {
                        onOpenSpot(
                          row.id,
                          countryCode: row.countryCode,
                          city: row.city,
                        );
                      } else {
                        onOpenEvent(row.id);
                      }
                    },
                    child: Row(
                      children: [
                        Icon(Icons.link,
                            size: 16, color: Theme.of(context).primaryColor),
                        const SizedBox(width: 4),
                        Text(
                          row.isSpot
                              ? l10n.adminResizedImagesViewSpot
                              : l10n.adminResizedImagesViewEvent,
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontSize: 12,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: accent.withValues(alpha: 0.35)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          countLabel(row.count),
                          style: TextStyle(color: accent),
                        ),
                        if (showImageUrls && row.imageUrls.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ...row.imageUrls.take(3).map(
                                (url) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    url,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: accent,
                                      fontFamily: 'monospace',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                          if (row.imageUrls.length > 3)
                            Text(
                              l10n.adminResizedImagesAndMore(
                                row.imageUrls.length - 3,
                              ),
                              style: TextStyle(
                                fontSize: 10,
                                color: accent,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                  if (showImageUrls && row.imageUrls.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: row.imageUrls.length,
                        itemBuilder: (context, imgIndex) {
                          final url = row.imageUrls[imgIndex];
                          return Container(
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: accent, width: 2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                url,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 80,
                                    height: 80,
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.image_not_supported),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
