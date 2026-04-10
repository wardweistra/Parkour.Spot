import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/spot_check_in.dart';
import '../../l10n/app_localizations.dart';
import '../../services/auth_service.dart';
import '../../services/spot_check_in_service.dart';
import '../../widgets/page_scaffold.dart';
import '../../widgets/spot_check_in_dialog.dart';
import '../../widgets/spot_check_in_presence.dart';

String _formatSessionDuration(Duration d, AppLocalizations l10n) {
  if (d.isNegative) d = Duration.zero;
  var totalMinutes = d.inMinutes;
  if (totalMinutes == 0) return l10n.myCheckInsDurationMinutesShort(0);
  final days = totalMinutes ~/ (24 * 60);
  totalMinutes %= (24 * 60);
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  final parts = <String>[];
  if (days > 0) parts.add(l10n.myCheckInsDurationDaysShort(days));
  if (hours > 0) parts.add(l10n.myCheckInsDurationHoursShort(hours));
  if (minutes > 0) parts.add(l10n.myCheckInsDurationMinutesShort(minutes));
  if (parts.isEmpty) parts.add(l10n.myCheckInsDurationMinutesShort(0));
  return parts.join(' ');
}

/// Time line for a tile when the [start] date is shown in a section header above.
String _formatCheckInTimeLineUnderHeader(
  SpotCheckIn checkIn,
  AppLocalizations l10n,
) {
  final start = checkIn.checkedInAt.toLocal();
  final end = checkIn.expectedEndAt.toLocal();
  final duration = checkIn.expectedEndAt.difference(checkIn.checkedInAt);
  final durStr = _formatSessionDuration(duration, l10n);
  final sameDay =
      start.year == end.year &&
      start.month == end.month &&
      start.day == end.day;
  final timeFmt = DateFormat.jm();

  if (sameDay) {
    return '${timeFmt.format(start)} — ${timeFmt.format(end)} ($durStr)';
  }

  final endFull = DateFormat.yMMMd().add_jm().format(end);
  return '${timeFmt.format(start)} — $endFull ($durStr)';
}

sealed class _CheckInListRow {}

final class _CheckInListIntro extends _CheckInListRow {}

final class _CheckInListDateHeader extends _CheckInListRow {
  _CheckInListDateHeader(this.day);
  final DateTime day;
}

final class _CheckInListTile extends _CheckInListRow {
  _CheckInListTile(this.checkIn);
  final SpotCheckIn checkIn;
}

final class _CheckInListLoadMore extends _CheckInListRow {}

/// Full history of the current user's check-ins (newest first), with delete.
class MyCheckInsScreen extends StatefulWidget {
  const MyCheckInsScreen({super.key});

  @override
  State<MyCheckInsScreen> createState() => _MyCheckInsScreenState();
}

class _MyCheckInsScreenState extends State<MyCheckInsScreen> {
  AppLocalizations get _l10n => AppLocalizations.of(context)!;

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
    final stillHereEligible = await svc.stillHereEligibleForUser(c);
    if (!mounted) return;
    final result = await showSpotCheckInDialog(
      context,
      existingCheckIn: c,
      stillHereEligible: stillHereEligible,
    );
    if (result == null || !mounted) return;

    if (result is SpotCheckInDialogDeleted) {
      final deleted = await svc.deleteCheckIn(c.id);
      if (!mounted) return;
      if (deleted) {
        setState(() {
          _items.removeWhere((x) => x.id == c.id);
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_l10n.spotDetailCheckInRemoved)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(svc.error ?? _l10n.spotDetailCheckInDeleteFailed),
          ),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_l10n.spotDetailCheckInUpdated)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(svc.error ?? _l10n.spotDetailCheckInUpdateFailed),
        ),
      );
    }
  }

  List<_CheckInListRow> _buildCheckInListRows() {
    final rows = <_CheckInListRow>[_CheckInListIntro()];
    DateTime? prevDay;
    for (final c in _items) {
      final local = c.checkedInAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);
      if (prevDay != day) {
        rows.add(_CheckInListDateHeader(day));
        prevDay = day;
      }
      rows.add(_CheckInListTile(c));
    }
    if (_hasMore) {
      rows.add(_CheckInListLoadMore());
    }
    return rows;
  }

  Widget _buildCheckInsListView(BuildContext context) {
    final rows = _buildCheckInListRows();
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final row = rows[i];
        switch (row) {
          case _CheckInListIntro():
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _intro(context),
            );
          case _CheckInListDateHeader(:final day):
            final prevIsIntro = i > 0 && rows[i - 1] is _CheckInListIntro;
            return _CheckInDateHeader(day: day, isFirst: prevIsIntro);
          case _CheckInListTile(:final checkIn):
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CheckInHistoryTile(
                checkIn: checkIn,
                onOpenSpot: () => context.push('/spot/${checkIn.spotId}'),
                onManage: () => _manageCheckIn(checkIn),
              ),
            );
          case _CheckInListLoadMore():
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: _loadingMore
                    ? const CircularProgressIndicator()
                    : TextButton(
                        onPressed: _loadMore,
                        child: Text(_l10n.myCheckInsLoadMore),
                      ),
              ),
            );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, auth, _) {
        if (!auth.isAuthenticated) {
          return PageScaffold(
            title: _l10n.publicProfileMyCheckIns,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.login, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    _l10n.myCheckInsSignInPrompt,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => context.go(
                      '/login?redirectTo=${Uri.encodeComponent('/profile/check-ins')}',
                    ),
                    child: Text(_l10n.profileSignInButton),
                  ),
                ],
              ),
            ),
          );
        }

        if (_loading) {
          return PageScaffold(
            title: _l10n.publicProfileMyCheckIns,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (_error != null && _items.isEmpty) {
          return PageScaffold(
            title: _l10n.publicProfileMyCheckIns,
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
                      child: Text(_l10n.profileRetry),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return PageScaffold(
          title: _l10n.publicProfileMyCheckIns,
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
                              _l10n.myCheckInsEmptyTitle,
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
                              _l10n.myCheckInsEmptyDescription,
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
                : _buildCheckInsListView(context),
          ),
        );
      },
    );
  }

  Widget _intro(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      _l10n.myCheckInsIntro,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
        height: 1.4,
      ),
    );
  }
}

class _CheckInDateHeader extends StatelessWidget {
  const _CheckInDateHeader({required this.day, required this.isFirst});

  final DateTime day;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(top: isFirst ? 0 : 20, bottom: 8),
      child: Text(
        DateFormat.yMMMd().format(day),
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
        ),
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
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final title =
        (checkIn.spotName != null && checkIn.spotName!.trim().isNotEmpty)
        ? checkIn.spotName!.trim()
        : l10n.myCheckInsSpotFallback;
    final timeRangeStr = _formatCheckInTimeLineUnderHeader(checkIn, l10n);
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
                      timeRangeStr,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.65,
                        ),
                      ),
                    ),
                    if (checkIn.isPrivate) ...[
                      const SizedBox(height: 4),
                      Text(
                        l10n.myCheckInsPrivateOnlyYou,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    if (comment != null && comment.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      CheckInCommentBlock(comment: comment),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n.spotDetailCheckInFabTooltipEdit,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
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
