import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/spot_list.dart';
import '../models/spot_list_invite.dart';
import '../services/auth_service.dart';
import '../services/spot_list_service.dart';
import '../services/user_profile_service.dart';
import 'custom_button.dart';
import 'custom_text_field.dart';

Future<void> showSpotListAccessSheet(
  BuildContext context, {
  required SpotList list,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: SpotListAccessSheet(list: list),
      );
    },
  );
}

class SpotListAccessSheet extends StatefulWidget {
  const SpotListAccessSheet({super.key, required this.list});

  final SpotList list;

  @override
  State<SpotListAccessSheet> createState() => _SpotListAccessSheetState();
}

class _SpotListAccessSheetState extends State<SpotListAccessSheet> {
  final _inviteeController = TextEditingController();
  SpotListInviteRole _inviteRole = SpotListInviteRole.edit;
  bool _isInviting = false;
  final Map<String, String> _nameCache = {};

  @override
  void dispose() {
    _inviteeController.dispose();
    super.dispose();
  }

  Future<String> _displayNameFor(String uid) async {
    final cached = _nameCache[uid];
    if (cached != null) return cached;
    try {
      final profile = await context.read<UserProfileService>().getUserProfile(
        uid,
      );
      final name = profile?.displayName?.trim();
      final username = profile?.username?.trim();
      final label = (name != null && name.isNotEmpty)
          ? name
          : (username != null && username.isNotEmpty)
          ? username
          : uid;
      _nameCache[uid] = label;
      return label;
    } catch (_) {
      _nameCache[uid] = uid;
      return uid;
    }
  }

  Future<void> _sendInvite() async {
    final l10n = AppLocalizations.of(context)!;
    final invitee = _inviteeController.text.trim();
    if (invitee.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.spotListAccessInviteeRequired)),
      );
      return;
    }
    final listId = widget.list.id;
    if (listId == null) return;

    setState(() => _isInviting = true);
    final service = context.read<SpotListService>();
    final ok = await service.inviteToSpotList(
      listId: listId,
      invitee: invitee,
      role: _inviteRole,
    );
    if (!mounted) return;
    setState(() => _isInviting = false);
    if (ok) {
      _inviteeController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.spotListAccessInviteSent)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(service.error ?? l10n.spotListAccessInviteFailed),
        ),
      );
    }
  }

  Future<void> _changeRole(
    SpotListInvite invite,
    SpotListInviteRole role,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final service = context.read<SpotListService>();
    final ok = await service.updateSpotListMemberRole(
      inviteId: invite.id,
      role: role,
    );
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(service.error ?? l10n.spotListAccessUpdateFailed),
        ),
      );
    }
  }

  Future<void> _remove(SpotListInvite invite, {required bool isSelf}) async {
    final l10n = AppLocalizations.of(context)!;
    final service = context.read<SpotListService>();
    final ok = await service.removeSpotListMember(inviteId: invite.id);
    if (!mounted) return;
    if (ok) {
      if (isSelf && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isSelf
                ? l10n.spotListAccessLeftList
                : l10n.spotListAccessRemovedMember,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(service.error ?? l10n.spotListAccessUpdateFailed),
        ),
      );
    }
  }

  Future<void> _respond(SpotListInvite invite, {required bool accept}) async {
    final l10n = AppLocalizations.of(context)!;
    final service = context.read<SpotListService>();
    final ok = await service.respondToSpotListInvite(
      inviteId: invite.id,
      accept: accept,
    );
    if (!mounted) return;
    if (ok && !accept && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? (accept
                    ? l10n.spotListAccessAccepted
                    : l10n.spotListAccessDeclined)
              : (service.error ?? l10n.spotListAccessUpdateFailed),
        ),
      ),
    );
  }

  String _roleLabel(AppLocalizations l10n, SpotListInviteRole role) {
    return role == SpotListInviteRole.edit
        ? l10n.spotListAccessRoleEdit
        : l10n.spotListAccessRoleView;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final listId = widget.list.id;
    final uid = context.watch<AuthService>().currentUser?.uid;
    final isOwner = widget.list.isOwner(uid);

    if (listId == null) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.spotListAccessTitle, style: textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                l10n.spotListAccessSubtitle,
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 16),
              if (isOwner) ...[
                CustomTextField(
                  controller: _inviteeController,
                  labelText: l10n.spotListAccessInviteeLabel,
                  hintText: l10n.spotListAccessInviteeHint,
                ),
                const SizedBox(height: 12),
                SegmentedButton<SpotListInviteRole>(
                  segments: [
                    ButtonSegment(
                      value: SpotListInviteRole.edit,
                      label: Text(l10n.spotListAccessRoleEdit),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    ButtonSegment(
                      value: SpotListInviteRole.view,
                      label: Text(l10n.spotListAccessRoleView),
                      icon: const Icon(Icons.visibility_outlined),
                    ),
                  ],
                  selected: {_inviteRole},
                  onSelectionChanged: (value) {
                    if (value.isEmpty) return;
                    setState(() => _inviteRole = value.first);
                  },
                ),
                const SizedBox(height: 12),
                CustomButton(
                  onPressed: _isInviting ? null : _sendInvite,
                  text: l10n.spotListAccessSendInvite,
                  width: double.infinity,
                  isLoading: _isInviting,
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.spotListAccessPeopleTitle,
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: StreamBuilder<List<SpotListInvite>>(
                    stream: context.read<SpotListService>().watchListInvites(
                      listId,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final invites = snapshot.data ?? const <SpotListInvite>[];
                      if (invites.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            l10n.spotListAccessNobodyYet,
                            style: textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        );
                      }
                      return ListView.separated(
                        itemCount: invites.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 4),
                        itemBuilder: (context, index) {
                          final invite = invites[index];
                          return _MemberTile(
                            invite: invite,
                            roleLabel: _roleLabel(l10n, invite.role),
                            statusLabel:
                                invite.status == SpotListInviteStatus.pending
                                ? l10n.spotListAccessStatusPending
                                : l10n.spotListAccessStatusAccepted,
                            displayNameFuture: _displayNameFor(
                              invite.inviteeUid,
                            ),
                            onRoleSelected:
                                invite.status == SpotListInviteStatus.accepted
                                ? (role) => _changeRole(invite, role)
                                : null,
                            onRemove: () => _remove(invite, isSelf: false),
                            removeLabel:
                                invite.status == SpotListInviteStatus.pending
                                ? l10n.spotListAccessCancelInvite
                                : l10n.spotListAccessRemoveAccess,
                          );
                        },
                      );
                    },
                  ),
                ),
              ] else
                Expanded(
                  child: StreamBuilder<SpotListInvite?>(
                    stream: context.read<SpotListService>().watchMyInviteForList(
                      listId,
                    ),
                    builder: (context, snapshot) {
                      final invite = snapshot.data;
                      if (invite == null) {
                        return Text(
                          l10n.spotListAccessNoAccess,
                          style: textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurface.withValues(alpha: 0.6),
                          ),
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            invite.status == SpotListInviteStatus.pending
                                ? l10n.spotListAccessYourPendingInvite
                                : l10n.spotListAccessYourAccess(
                                    _roleLabel(l10n, invite.role),
                                  ),
                            style: textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 16),
                          if (invite.status == SpotListInviteStatus.pending) ...[
                            CustomButton(
                              onPressed: () =>
                                  _respond(invite, accept: true),
                              text: l10n.spotListAccessAccept,
                              width: double.infinity,
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: () =>
                                  _respond(invite, accept: false),
                              child: Text(l10n.spotListAccessDecline),
                            ),
                          ] else
                            OutlinedButton(
                              onPressed: () =>
                                  _remove(invite, isSelf: true),
                              child: Text(l10n.spotListAccessLeave),
                            ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.invite,
    required this.roleLabel,
    required this.statusLabel,
    required this.displayNameFuture,
    required this.onRemove,
    required this.removeLabel,
    this.onRoleSelected,
  });

  final SpotListInvite invite;
  final String roleLabel;
  final String statusLabel;
  final Future<String> displayNameFuture;
  final VoidCallback onRemove;
  final String removeLabel;
  final ValueChanged<SpotListInviteRole>? onRoleSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return FutureBuilder<String>(
      future: displayNameFuture,
      builder: (context, snapshot) {
        final name = snapshot.data ?? '…';
        return Material(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        '$roleLabel · $statusLabel',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
                if (onRoleSelected != null)
                  PopupMenuButton<SpotListInviteRole>(
                    tooltip: roleLabel,
                    onSelected: onRoleSelected,
                    itemBuilder: (context) {
                      final l10n = AppLocalizations.of(context)!;
                      return [
                        PopupMenuItem(
                          value: SpotListInviteRole.edit,
                          child: Text(l10n.spotListAccessRoleEdit),
                        ),
                        PopupMenuItem(
                          value: SpotListInviteRole.view,
                          child: Text(l10n.spotListAccessRoleView),
                        ),
                      ];
                    },
                    child: const Icon(Icons.swap_horiz),
                  ),
                IconButton(
                  tooltip: removeLabel,
                  onPressed: onRemove,
                  icon: Icon(Icons.close, color: scheme.error),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
