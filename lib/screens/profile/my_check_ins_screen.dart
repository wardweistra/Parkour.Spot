import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/spot_check_in.dart';
import '../../services/auth_service.dart';
import '../../services/spot_check_in_service.dart';
import '../../widgets/page_scaffold.dart';
import '../../widgets/spot_check_in_dialog.dart';

/// Full history of the current user's check-ins (newest first), with delete.
class MyCheckInsScreen extends StatefulWidget {
  const MyCheckInsScreen({super.key});

  @override
  State<MyCheckInsScreen> createState() => _MyCheckInsScreenState();
}

class _MyCheckInsScreenState extends State<MyCheckInsScreen> {
  final List<SpotCheckIn> _items = [];
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _hasMore = true;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitial());
  }

  Future<void> _loadInitial() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (!auth.isAuthenticated) {
      setState(() {
        _loading = false;
        _items.clear();
        _hasMore = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final svc = Provider.of<SpotCheckInService>(context, listen: false);
    try {
      final page = await svc.fetchMyCheckInsPage();
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(page.items);
        _lastDoc = page.lastDocument;
        _hasMore = page.hasMore;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingMore || _lastDoc == null) return;
    setState(() => _loadingMore = true);
    final svc = Provider.of<SpotCheckInService>(context, listen: false);
    try {
      final page = await svc.fetchMyCheckInsPage(startAfter: _lastDoc);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _lastDoc = page.lastDocument;
        _hasMore = page.hasMore;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loadingMore = false;
      });
    }
  }

  Future<void> _manageCheckIn(SpotCheckIn c) async {
    final svc = Provider.of<SpotCheckInService>(context, listen: false);
    final result = await showSpotCheckInDialog(
      context,
      existingCheckIn: c,
    );
    if (result == null || !mounted) return;

    if (result is SpotCheckInDialogDeleted) {
      final deleted = await svc.deleteCheckIn(c.id);
      if (!mounted) return;
      if (deleted) {
        setState(() {
          _items.removeWhere((x) => x.id == c.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Check-in removed')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(svc.error ?? 'Could not delete')),
        );
      }
      return;
    }

    if (result is! SpotCheckInDialogSaved) return;

    final ok = await svc.updateCheckIn(
      c.id,
      checkedInAt: result.checkedInAt!,
      isPrivate: result.isPrivate,
      expectedEndAt: result.expectedEndAt,
      comment: result.comment,
    );
    if (!mounted) return;
    if (ok) {
      final idx = _items.indexWhere((x) => x.id == c.id);
      if (idx >= 0) {
        setState(() {
          _items[idx] = SpotCheckIn(
            id: c.id,
            userId: c.userId,
            spotId: c.spotId,
            checkedInAt: result.checkedInAt!,
            expectedEndAt: result.expectedEndAt,
            isPrivate: result.isPrivate,
            spotName: c.spotName,
            comment: result.comment,
            displayName: c.displayName,
            photoURL: c.photoURL,
          );
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check-in updated')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(svc.error ?? 'Could not update check-in')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, auth, _) {
        if (!auth.isAuthenticated) {
          return PageScaffold(
            title: 'My check-ins',
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.login, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'Sign in to view your check-ins',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => context.go(
                      '/login?redirectTo=${Uri.encodeComponent('/profile/check-ins')}',
                    ),
                    child: const Text('Sign in'),
                  ),
                ],
              ),
            ),
          );
        }

        if (_loading) {
          return const PageScaffold(
            title: 'My check-ins',
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (_error != null && _items.isEmpty) {
          return PageScaffold(
            title: 'My check-ins',
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _loadInitial,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return PageScaffold(
          title: 'My check-ins',
          scrollable: false,
          body: RefreshIndicator(
            onRefresh: _loadInitial,
            child: _items.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      _intro(context),
                      const SizedBox(height: 32),
                      Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.place_outlined,
                              size: 64,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No check-ins yet',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.7),
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Open a spot and tap Check in to record a visit. '
                              'Until the end time you set, others can see you as “here now” on that spot unless you keep the check-in private.',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.55),
                                  ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: 1 + _items.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _intro(context),
                        );
                      }
                      final idx = i - 1;
                      if (idx < _items.length) {
                        final c = _items[idx];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _CheckInHistoryTile(
                            checkIn: c,
                            onOpenSpot: () => context.push('/spot/${c.spotId}'),
                            onManage: () => _manageCheckIn(c),
                          ),
                        );
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: _loadingMore
                              ? const CircularProgressIndicator()
                              : TextButton(
                                  onPressed: _loadMore,
                                  child: const Text('Load more'),
                                ),
                        ),
                      );
                    },
                  ),
          ),
        );
      },
    );
  }

  Widget _intro(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      'A check-in records that you visited a spot, when you arrived, and until when you expect to be there. '
      'Public check-ins can show you in “who’s here now” on that spot until that end time; '
      'private check-ins stay visible only to you.',
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
        height: 1.4,
      ),
    );
  }
}

class _CheckInHistoryTile extends StatelessWidget {
  const _CheckInHistoryTile({
    required this.checkIn,
    required this.onOpenSpot,
    required this.onManage,
  });

  final SpotCheckIn checkIn;
  final VoidCallback onOpenSpot;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title =
        (checkIn.spotName != null && checkIn.spotName!.trim().isNotEmpty)
        ? checkIn.spotName!.trim()
        : 'Spot';
    final startStr = DateFormat(
      'MMM d, yyyy • h:mm a',
    ).format(checkIn.checkedInAt.toLocal());
    final endStr = DateFormat(
      'MMM d, yyyy • h:mm a',
    ).format(checkIn.expectedEndAt.toLocal());
    final comment = checkIn.comment?.trim();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpenSpot,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.place, color: theme.colorScheme.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$startStr — $endStr',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.65,
                        ),
                      ),
                    ),
                    if (checkIn.isPrivate) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Private — only you can see this',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (comment != null && comment.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        comment,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.85,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit check-in',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
                icon: Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                onPressed: onManage,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
