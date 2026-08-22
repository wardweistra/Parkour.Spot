import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../widgets/page_scaffold.dart';
import 'admin_tool_widgets.dart';
import 'event_backfill_actions.dart';

class EventDataScreen extends StatelessWidget {
  const EventDataScreen({super.key});

  void _handleBack(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      context.go('/admin');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.select<AuthService, bool>((s) => s.isAdmin);
    if (!isAdmin) {
      return PageScaffold(
        title: 'Event data',
        onBack: () => _handleBack(context),
        body: const Center(child: Text('Administrator access required')),
        scrollable: false,
        padding: const EdgeInsets.all(24.0),
      );
    }

    return PageScaffold(
      title: 'Event data',
      onBack: () => _handleBack(context),
      scrollable: false,
      body: ListView(
        children: [
          AdminSectionCard(
            children: [
              AdminToolTile(
                icon: Icons.search,
                title: 'Backfill event name search',
                subtitle: 'Populate eventSearchTerms for Explore autocomplete',
                showChevron: false,
                onTap: () =>
                    EventBackfillActions.backfillEventSearchTerms(context),
              ),
              AdminToolTile(
                icon: Icons.map_outlined,
                title: 'Backfill event map pins',
                subtitle:
                    'Materialize eventMapPins from linked spots and spot lists',
                showChevron: false,
                onTap: () =>
                    EventBackfillActions.showBackfillEventMapPinsDialog(
                      context,
                    ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
