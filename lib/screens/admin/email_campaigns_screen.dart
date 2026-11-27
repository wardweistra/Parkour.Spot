import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../services/admin_email_campaigns_service.dart';
import 'admin_tool_widgets.dart';

/// Admin: queue the yearly review email, send yourself a test, and watch
/// campaigns go out. Sending happens in Cloud Functions
/// (`processEmailCampaignsScheduled`, every 10 minutes, within the daily cap).
class EmailCampaignsScreen extends StatefulWidget {
  const EmailCampaignsScreen({super.key});

  @override
  State<EmailCampaignsScreen> createState() => _EmailCampaignsScreenState();
}

class _EmailCampaignsScreenState extends State<EmailCampaignsScreen> {
  final AdminEmailCampaignsService _service = AdminEmailCampaignsService();
  late final TextEditingController _yearController = TextEditingController(
    text: '${DateTime.now().year}',
  );
  final TextEditingController _dailyLimitController = TextEditingController(
    text: '300',
  );
  final TextEditingController _previewUserController = TextEditingController();
  late DateTime _sendAt = _defaultSendAt();
  bool _busy = false;

  static final DateFormat _dateTime = DateFormat('EEE d MMM yyyy, HH:mm');

  /// Next 10:00 local, at least an hour away: time to send a test first.
  static DateTime _defaultSendAt() {
    final now = DateTime.now();
    var candidate = DateTime(now.year, now.month, now.day, 10);
    while (candidate.isBefore(now.add(const Duration(hours: 1)))) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  @override
  void dispose() {
    _yearController.dispose();
    _dailyLimitController.dispose();
    _previewUserController.dispose();
    super.dispose();
  }

  int? get _year => int.tryParse(_yearController.text.trim());

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _errorText(Object error) {
    if (error is FirebaseFunctionsException) {
      return error.message ?? error.code;
    }
    return '$error';
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      _toast(_errorText(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickSendAt() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _sendAt,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 400)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_sendAt),
    );
    if (time == null) return;
    setState(() {
      _sendAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _sendTest() => _run(() async {
    final year = _year;
    if (year == null) throw 'Enter a year';
    final outcome = await _service.sendYearReviewTest(
      year: year,
      previewUserId: _previewUserController.text.trim(),
    );
    _toast(outcome);
  });

  Future<void> _queue() async {
    final year = _year;
    final dailyLimit = int.tryParse(_dailyLimitController.text.trim());
    if (year == null || dailyLimit == null || dailyLimit <= 0) {
      _toast('Enter a year and a daily limit above 0');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Queue the $year yearly review?'),
        content: Text(
          'Everyone with contributions in $year gets it, starting '
          '${_dateTime.format(_sendAt)}, at most $dailyLimit emails a day. '
          'People who opted out, have no verified email, or have nothing to '
          'show at send time are skipped.\n\nSend yourself a test first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Queue'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() async {
      final result = await _service.createYearReviewCampaign(
        year: year,
        sendAt: _sendAt,
        dailyLimit: dailyLimit,
      );
      _toast('Queued for ${result.total} people');
    });
  }

  Future<void> _cancel(EmailCampaign campaign) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this campaign?'),
        content: Text(
          '${campaign.pending} pending emails will not be sent. '
          'This cannot be resumed; you can queue a new campaign for the year.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep sending'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel campaign'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() => _service.cancelCampaign(campaign.id));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Email campaigns')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const AdminSectionHeader(title: 'Yearly review ("Wrapped")'),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _yearController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(labelText: 'Year'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _dailyLimitController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Emails per day',
                            helperText: 'Brevo free plan: 300',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule),
                    title: const Text('Start sending'),
                    subtitle: Text(_dateTime.format(_sendAt)),
                    trailing: const Icon(Icons.edit_calendar_outlined),
                    onTap: _busy ? null : _pickSendAt,
                  ),
                  const Divider(height: 24),
                  TextField(
                    controller: _previewUserController,
                    decoration: const InputDecoration(
                      labelText: 'Preview as user ID (optional)',
                      helperText:
                          'Sends that person’s review to your own address. '
                          'Empty: your own review.',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _sendTest,
                        icon: const Icon(Icons.outgoing_mail),
                        label: const Text('Send test to me'),
                      ),
                      FilledButton.icon(
                        onPressed: _busy ? null : _queue,
                        icon: const Icon(Icons.schedule_send_outlined),
                        label: const Text('Queue campaign'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const AdminSectionHeader(title: 'Campaigns'),
          StreamBuilder<List<EmailCampaign>>(
            stream: _service.watchCampaigns(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(
                  'Could not load campaigns: ${snapshot.error}',
                  style: TextStyle(color: theme.colorScheme.error),
                );
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final campaigns = snapshot.data!;
              if (campaigns.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'No campaigns yet.',
                    style: theme.textTheme.bodyMedium,
                  ),
                );
              }
              return Column(
                children: [
                  for (final campaign in campaigns)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CampaignCard(
                        campaign: campaign,
                        service: _service,
                        dateFormat: _dateTime,
                        onCancel: _busy || !campaign.isActive
                            ? null
                            : () => _cancel(campaign),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  const _CampaignCard({
    required this.campaign,
    required this.service,
    required this.dateFormat,
    required this.onCancel,
  });

  final EmailCampaign campaign;
  final AdminEmailCampaignsService service;
  final DateFormat dateFormat;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sendAt = campaign.sendAt;
    final lastRun = campaign.lastRunAt;
    final title = campaign.kind == 'yearReview'
        ? 'Yearly review ${campaign.year}'
        : campaign.kind;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
                Chip(label: Text(campaign.status)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [
                if (sendAt != null) 'Starts ${dateFormat.format(sendAt)}',
                '${campaign.dailyLimit}/day',
                if (lastRun != null) 'last run ${dateFormat.format(lastRun)}',
              ].join(' · '),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: campaign.progress),
            const SizedBox(height: 8),
            Text(
              '${campaign.sent} sent · ${campaign.skipped} skipped · '
              '${campaign.failed} failed · ${campaign.pending} pending '
              'of ${campaign.total}',
            ),
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Details'),
                children: [
                  _CampaignDetails(campaign: campaign, service: service),
                ],
              ),
            ),
            if (onCancel != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onCancel,
                  child: const Text('Cancel campaign'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CampaignDetails extends StatelessWidget {
  const _CampaignDetails({required this.campaign, required this.service});

  final EmailCampaign campaign;
  final AdminEmailCampaignsService service;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<(Map<String, int>, List<EmailCampaignRecipientIssue>)>(
      future: () async {
        final reasons = await service.fetchSkipReasons(campaign.id);
        final issues = await service.fetchIssues(campaign.id);
        return (reasons, issues);
      }(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Could not load details: ${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: LinearProgressIndicator(),
          );
        }
        final (reasons, issues) = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Skipped', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(
              reasons.isEmpty
                  ? 'None'
                  : reasons.entries
                        .map((e) => '${e.key}: ${e.value}')
                        .join(' · '),
            ),
            const SizedBox(height: 12),
            Text(
              'Failed or stuck in sending',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 4),
            if (issues.isEmpty) const Text('None'),
            for (final issue in issues)
              SelectableText(
                '${issue.userId} · ${issue.status}'
                '${issue.reason == null ? '' : ' · ${issue.reason}'}',
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}
