import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../widgets/page_scaffold.dart';
import 'admin_tool_widgets.dart';
import 'outgoing_links_admin_actions.dart';

class OutgoingLinksScreen extends StatelessWidget {
  const OutgoingLinksScreen({super.key});

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
        title: 'Outgoing links',
        onBack: () => _handleBack(context),
        body: const Center(child: Text('Administrator access required')),
        scrollable: false,
        padding: const EdgeInsets.all(24.0),
      );
    }

    return PageScaffold(
      title: 'Outgoing links',
      onBack: () => _handleBack(context),
      scrollable: false,
      body: ListView(
        children: [
          AdminSectionCard(
            children: [
              AdminToolTile(
                icon: Icons.link_off_outlined,
                title: 'Find broken outgoing links',
                subtitle:
                    'Current/upcoming event websites and spot list more info '
                    'links (batched HTTP checks)',
                showChevron: false,
                onTap: () =>
                    OutgoingLinksAdminActions.findBrokenOutgoingLinks(context),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
