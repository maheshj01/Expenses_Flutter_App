import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/social_providers.dart';
import '../../app/theme.dart';
import '../../domain/social/account.dart';
import '../../domain/social/connection.dart';
import '../../shared/animations/fade_slide_in.dart';
import '../../shared/animations/motion.dart';
import 'people_widgets.dart';

/// Add someone by exact username, or share your own invite.
Future<void> showAddPersonSheet(BuildContext context, {String? handle}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => AddPersonSheet(initialHandle: handle),
  );
}

class AddPersonSheet extends ConsumerStatefulWidget {
  const AddPersonSheet({super.key, this.initialHandle});

  final String? initialHandle;

  @override
  ConsumerState<AddPersonSheet> createState() => _AddPersonSheetState();
}

class _AddPersonSheetState extends ConsumerState<AddPersonSheet> {
  late final TextEditingController _query = TextEditingController(text: widget.initialHandle ?? '');
  Profile? _found;
  String? _message;
  bool _searching = false;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialHandle != null) WidgetsBinding.instance.addPostFrameCallback((_) => _find());
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    final handle = Handle.normalize(_query.text);
    final me = ref.read(myProfileProvider).value;
    if (handle.isEmpty) return;
    if (handle == me?.handle) {
      setState(() => _message = 'That’s you 🙂');
      return;
    }
    setState(() {
      _searching = true;
      _message = null;
      _found = null;
      _sent = false;
    });
    try {
      final found = await ref.read(socialBackendProvider)!.findByHandle(handle);
      if (!mounted) return;
      setState(() {
        _found = found;
        _message = found == null ? 'No one has the username @$handle' : null;
      });
    } catch (e) {
      if (mounted) setState(() => _message = '$e');
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _request(Profile other) async {
    final me = ref.read(myProfileProvider).value;
    if (me == null) return;
    await ref.read(socialBackendProvider)!.requestConnection(me, other);
    if (mounted) setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(myProfileProvider).value;
    final connections = ref.watch(connectionsProvider).value ?? const <Connection>[];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add people', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('find-handle'),
                    controller: _query,
                    autofocus: widget.initialHandle == null,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _find(),
                    decoration: const InputDecoration(
                      prefixText: '@',
                      hintText: 'their exact username',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: compactButton,
                  onPressed: _searching ? null : _find,
                  child: const Text('Find'),
                ),
              ],
            ),
            AnimatedSize(
              duration: Motion.of(context, Motion.medium),
              curve: Motion.enter,
              child: AnimatedSwitcher(
                duration: Motion.of(context, Motion.medium),
                child: _buildResult(context, connections),
              ),
            ),
            const SizedBox(height: 22),
            if (me != null) FadeSlideIn(index: 1, child: _InviteCard(me: me)),
          ],
        ),
      ),
    );
  }

  Widget _buildResult(BuildContext context, List<Connection> connections) {
    final c = context.colors;
    if (_searching) {
      return const Padding(
        key: ValueKey('searching'),
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final found = _found;
    if (found == null) {
      return Padding(
        key: ValueKey(_message),
        padding: const EdgeInsets.only(top: 10),
        child: Text(_message ?? '', style: TextStyle(color: c.muted)),
      );
    }
    final existing = connections.where((x) => x.other.uid == found.uid).firstOrNull;
    final (label, enabled) = switch (existing) {
      _ when _sent => ('Request sent', false),
      Connection(isAccepted: true) => ('Already connected', false),
      Connection(isIncomingRequest: true) => ('Accept request', true),
      Connection(isOutgoingRequest: true) => ('Request sent', false),
      _ => ('Send request', true),
    };
    return Container(
      key: ValueKey(found.uid),
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.line),
      ),
      child: Row(
        children: [
          PersonAvatar(found, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(found.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text('@${found.handle}', style: TextStyle(color: c.muted, fontSize: 13)),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: Motion.of(context, Motion.fast),
            child: enabled
                ? FilledButton.tonal(
                    key: ValueKey(label),
                    style: compactButton,
                    onPressed: () => _request(found),
                    child: Text(label),
                  )
                : Row(
                    key: ValueKey(label),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, color: c.lived, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        label,
                        style: TextStyle(color: c.lived, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Your username, a QR code friends can scan with their camera, and a
/// share button.
class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.me});

  final Profile me;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.sunk, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: QrImageView(
              data: inviteLink(me.handle).toString(),
              size: 96,
              padding: EdgeInsets.zero,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: Color(0xFF1C1B19)),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.circle,
                color: Color(0xFF1C1B19),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Your username', style: TextStyle(color: c.muted, fontSize: 12.5)),
                Text(
                  '@${me.handle}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Friends can scan this with their camera.',
                  style: TextStyle(color: c.muted, fontSize: 12.5),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => SharePlus.instance.share(ShareParams(text: inviteMessage(me))),
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: const Text('Share invite'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
