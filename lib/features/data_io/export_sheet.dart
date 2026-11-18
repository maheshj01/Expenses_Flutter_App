import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../app/social_providers.dart';
import '../../app/theme.dart';
import '../../data/export/xlsx_export.dart';
import '../../domain/entities/ledger_entry.dart';
import '../../shared/animations/animated_amount.dart';
import '../../shared/animations/fade_slide_in.dart';
import '../../shared/animations/motion.dart';

const _xlsxType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

/// A finished export, ready to send.
typedef ExportFile = ({String name, Uint8List bytes, String subject, String body});

/// How an export leaves the phone. Overridden in tests.
class ExportDelivery {
  const ExportDelivery();

  /// Opens the mail composer with the file attached. Returns false when
  /// this device can't send mail with attachments.
  Future<bool> email(ExportFile file, {String? to}) async {
    final caps = await FlutterEmailSender.getCapabilities();
    if (!caps.canSend || !caps.supportsAttachments) return false;
    await FlutterEmailSender.send(
      Email(
        subject: file.subject,
        body: file.body,
        recipients: [?to],
        attachments: [EmailAttachment.data(file.bytes, fileName: file.name, mimeType: _xlsxType)],
      ),
    );
    return true;
  }

  /// Opens the share sheet: Mail, Files, Drive, AirDrop and so on.
  Future<void> share(ExportFile file, {Rect? origin}) => SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(file.bytes, name: file.name, mimeType: _xlsxType)],
      fileNameOverrides: [file.name],
      subject: file.subject,
      sharePositionOrigin: origin,
    ),
  );
}

final exportDeliveryProvider = Provider<ExportDelivery>((ref) => const ExportDelivery());

Future<void> showExportSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _ExportSheet(),
  );
}

class _ExportSheet extends ConsumerStatefulWidget {
  const _ExportSheet();

  @override
  ConsumerState<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends ConsumerState<_ExportSheet> {
  /// Null means every year.
  int? _year;
  bool _busy = false;
  String? _message;
  final _shareKey = GlobalKey();

  Future<List<LedgerEntry>> _entries() {
    final repo = ref.read(entryRepositoryProvider);
    final year = _year;
    return year == null
        ? repo.watchBetween(DateTime(1900), DateTime(2200)).first
        : repo.watchBetween(DateTime(year), DateTime(year, 12, 31)).first;
  }

  Future<ExportFile> _build() async {
    final label = _year?.toString() ?? 'All years';
    final entries = await _entries();
    final categories = await ref.read(categoryRepositoryProvider).getAll();
    final bytes = await compute(
      buildExportWorkbook,
      ExportData(entries: entries, categories: categories, label: label),
    );
    final n = entries.length;
    return (
      name: exportFileName(label),
      bytes: bytes,
      subject: 'Three Bucks export · $label',
      body:
          'Your Three Bucks entries (${_year ?? 'all years'}, $n ${n == 1 ? 'entry' : 'entries'}) '
          'are attached as a spreadsheet.\n\n'
          'Open it in Excel, Numbers or Google Sheets. To bring it back into Three Bucks, use '
          'Settings → Import from a spreadsheet.',
    );
  }

  Future<void> _send({required bool email}) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final file = await _build();
      final delivery = ref.read(exportDeliveryProvider);
      if (email) {
        final to = ref.read(accountProvider).value?.email;
        if (await delivery.email(file, to: to)) {
          if (mounted) Navigator.of(context).pop();
          return;
        }
        if (mounted) {
          setState(() => _message = 'Mail isn’t set up on this phone, so pick an app instead.');
        }
      }
      final box = _shareKey.currentContext?.findRenderObject() as RenderBox?;
      await delivery.share(
        file,
        origin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final years = ref.watch(yearsProvider);
    final email = ref.watch(accountProvider).value?.email;
    final count = ref.watch(_countProvider(_year)).value;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Export to a spreadsheet',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'An .xlsx file with every entry, plus a summary of each year by category and '
            'month. Opens in Excel, Numbers and Google Sheets.',
            style: TextStyle(color: c.muted, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (i, y) in <int?>[null, ...years].indexed)
                FadeSlideIn(
                  index: i,
                  child: ChoiceChip(
                    label: Text(y?.toString() ?? 'All years'),
                    selected: _year == y,
                    onSelected: (_) => setState(() => _year = y),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 22,
            child: count == null
                ? null
                : AnimatedAmount(
                    cents: count,
                    duration: Motion.medium,
                    builder: (context, n) => Text(
                      '$n ${n == 1 ? 'entry' : 'entries'}',
                      style: TextStyle(color: c.ink2, fontWeight: FontWeight.w600),
                    ),
                  ),
          ),
          AnimatedSize(
            duration: Motion.of(context, Motion.medium),
            curve: Motion.enter,
            child: _message == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_message!, style: TextStyle(color: c.warn, fontSize: 13)),
                  ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy || count == 0 ? null : () => _send(email: true),
            icon: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.mail_outline_rounded),
            label: Text(
              email == null ? 'Email it' : 'Email it to $email',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: _shareKey,
            onPressed: _busy || count == 0 ? null : () => _send(email: false),
            icon: const Icon(Icons.ios_share_rounded),
            label: const Text('Save or share…'),
          ),
        ],
      ),
    );
  }
}

final _countProvider = FutureProvider.autoDispose.family<int, int?>((ref, year) async {
  final repo = ref.watch(entryRepositoryProvider);
  final entries = year == null
      ? await repo.watchBetween(DateTime(1900), DateTime(2200)).first
      : await repo.watchBetween(DateTime(year), DateTime(year, 12, 31)).first;
  return entries.length;
});
