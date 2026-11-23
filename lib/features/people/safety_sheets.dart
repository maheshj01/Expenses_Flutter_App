import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/social_providers.dart';
import '../../app/theme.dart';
import '../../core/ids.dart';
import '../../domain/social/account.dart';
import '../../domain/social/safety.dart';
import '../../shared/widgets/app_card.dart';
import 'people_widgets.dart';

/// Report, block and (when [onRemove] is given) remove, for someone you
/// share with or who asked to connect. [onBlocked] runs once they're
/// blocked, from the menu or the report sheet.
class SafetyMenuButton extends ConsumerWidget {
  const SafetyMenuButton({
    super.key,
    required this.person,
    this.onRemove,
    this.onBlocked,
    this.icon,
  });

  final Profile person;
  final VoidCallback? onRemove;
  final VoidCallback? onBlocked;
  final IconData? icon;

  Future<void> _report(BuildContext context) async {
    final result = await showReportSheet(context, person);
    if (result.blocked) onBlocked?.call();
  }

  Future<void> _block(BuildContext context, WidgetRef ref) async {
    if (await confirmBlock(context, ref, person)) onBlocked?.call();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return PopupMenuButton<String>(
      tooltip: 'More for ${person.displayName}',
      icon: Icon(icon ?? Icons.more_vert_rounded),
      onSelected: (action) => switch (action) {
        'report' => _report(context),
        'block' => _block(context, ref),
        _ => onRemove?.call(),
      },
      itemBuilder: (_) => [
        if (onRemove != null)
          PopupMenuItem(value: 'remove', child: Text('Remove ${person.displayName}')),
        PopupMenuItem(value: 'report', child: Text('Report ${person.displayName}')),
        PopupMenuItem(
          value: 'block',
          child: Text('Block ${person.displayName}', style: TextStyle(color: c.warn)),
        ),
      ],
    );
  }
}

/// Asks before blocking [person]. Returns true once they're blocked.
Future<bool> confirmBlock(BuildContext context, WidgetRef ref, Profile person) async {
  final name = person.displayName;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Block $name?'),
      content: Text(
        '$name won’t be able to find you, ask to connect, or share new bills with you, '
        'and you’ll be disconnected. Bills you already share stay as they are. '
        'You can unblock them in Settings.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          style: TextButton.styleFrom(foregroundColor: context.colors.warn),
          child: const Text('Block'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return false;
  await ref.read(socialBackendProvider)!.block(person);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Blocked $name')));
  }
  return true;
}

/// Reports [person] to the app's moderators, optionally about one bill.
/// Says whether a report was sent and whether they were blocked too.
Future<({bool sent, bool blocked})> showReportSheet(
  BuildContext context,
  Profile person, {
  String? billId,
}) async {
  final blocked = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ReportSheet(person: person, billId: billId),
  );
  return (sent: blocked != null, blocked: blocked ?? false);
}

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({required this.person, this.billId});

  final Profile person;
  final String? billId;

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  ReportReason? _reason;
  bool _block = true;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final reason = _reason;
    if (reason == null) return;
    final backend = ref.read(socialBackendProvider)!;
    final messenger = ScaffoldMessenger.of(context);
    await backend.report(
      Report(
        id: newId(),
        reported: widget.person,
        reason: reason,
        note: _note.text.trim(),
        billId: widget.billId,
        at: DateTime.now(),
      ),
    );
    if (_block) await backend.block(widget.person);
    if (mounted) Navigator.of(context).pop(_block);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          _block
              ? 'Thanks. We’ll review your report, and ${widget.person.displayName} is blocked.'
              : 'Thanks. We’ll review your report.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final name = widget.person.displayName;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.billId == null ? 'Report $name' : 'Report this bill',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Reports go to the Three Bucks team, not to $name.',
              style: TextStyle(color: c.muted, fontSize: 13.5, height: 1.35),
            ),
            const SizedBox(height: 12),
            RadioGroup<ReportReason>(
              groupValue: _reason,
              onChanged: (r) => setState(() => _reason = r),
              child: Column(
                children: [
                  for (final r in ReportReason.values)
                    RadioListTile<ReportReason>(
                      value: r,
                      contentPadding: EdgeInsets.zero,
                      title: Text(r.label),
                    ),
                ],
              ),
            ),
            TextField(
              controller: _note,
              maxLength: Report.maxNote,
              maxLines: 3,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'What happened? (optional)'),
            ),
            CheckboxListTile(
              value: _block,
              onChanged: (v) => setState(() => _block = v ?? _block),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text('Also block $name'),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: c.warn),
              onPressed: _reason == null ? null : _send,
              icon: const Icon(Icons.outlined_flag_rounded, size: 18),
              label: const Text('Send report'),
            ),
          ],
        ),
      ),
    );
  }
}

/// People you blocked, with a way to unblock each.
class BlockedPeopleScreen extends ConsumerWidget {
  const BlockedPeopleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final blocked = ref.watch(blockedProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Blocked people')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 40),
        children: [
          if (blocked.isEmpty)
            const AppCard(
              child: EmptyState(
                emoji: '🛡️',
                title: 'No one blocked',
                message: 'Block someone from their page or a request, and they’ll show up here.',
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
              child: Text(
                'They can’t find you, ask to connect, or share new bills with you.',
                style: TextStyle(color: c.muted, fontSize: 13.5),
              ),
            ),
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              child: Column(
                children: [
                  for (final (i, b) in blocked.indexed) ...[
                    if (i > 0) const Divider(indent: 52),
                    ListTile(
                      key: ValueKey(b.profile.uid),
                      contentPadding: EdgeInsets.zero,
                      leading: PersonAvatar(b.profile),
                      title: Text(b.profile.displayName),
                      subtitle: Text('@${b.profile.handle}'),
                      trailing: TextButton(
                        onPressed: () => ref.read(socialBackendProvider)!.unblock(b.profile.uid),
                        child: const Text('Unblock'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
