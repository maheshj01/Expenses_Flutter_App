import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/social_providers.dart';
import '../../app/theme.dart';
import '../../domain/social/account.dart';
import '../../domain/social/social_backend.dart';
import '../../shared/animations/fade_slide_in.dart';
import '../../shared/animations/motion.dart';
import 'people_widgets.dart';

/// Shown on the People tab before signing in. Personal tracking never needs
/// an account; this is only for splitting bills with people.
class SignInView extends ConsumerStatefulWidget {
  const SignInView({super.key});

  @override
  ConsumerState<SignInView> createState() => _SignInViewState();
}

class _SignInViewState extends ConsumerState<SignInView> {
  SignInMethod? _busy;
  String? _error;

  Future<void> _signIn(SignInMethod method) async {
    setState(() {
      _busy = method;
      _error = null;
    });
    try {
      await ref.read(socialBackendProvider)!.signIn(method);
    } on SignInCancelled {
      // Nothing to say.
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final methods = ref.watch(socialBackendProvider)?.signInMethods ?? const [];
    const points = [
      ('🧾', 'Split a bill in the same sheet you log it in'),
      ('⚖️', 'See who owes whom, and settle up'),
      ('🚩', 'Flag a share that looks wrong'),
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 120),
      children: [
        const FadeSlideIn(child: _PeopleArt()),
        const SizedBox(height: 24),
        const FadeSlideIn(
          index: 1,
          child: Text(
            'Split bills with people',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.6),
          ),
        ),
        const SizedBox(height: 8),
        FadeSlideIn(
          index: 2,
          child: Text(
            'Your own tracking stays as it is. Sign in only to share bills with friends on Three Bucks.',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.muted, fontSize: 15, height: 1.4),
          ),
        ),
        const SizedBox(height: 24),
        for (final (i, (emoji, text)) in points.indexed)
          FadeSlideIn(
            index: 3 + i,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
                ],
              ),
            ),
          ),
        const SizedBox(height: 24),
        for (final (i, method) in methods.indexed)
          FadeSlideIn(
            index: 6 + i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: method == SignInMethod.apple
                  ? FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: c.ink,
                        foregroundColor: c.background,
                      ),
                      onPressed: _busy == null ? () => _signIn(method) : null,
                      icon: _busy == method ? const _Spinner() : const Icon(Icons.apple),
                      label: Text('Continue with ${method.label}'),
                    )
                  : OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                      onPressed: _busy == null ? () => _signIn(method) : null,
                      icon: _busy == method
                          ? const _Spinner()
                          : const Text(
                              'G',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                            ),
                      label: Text('Continue with ${method.label}'),
                    ),
            ),
          ),
        AnimatedSize(
          duration: Motion.of(context, Motion.fast),
          child: _error == null
              ? const SizedBox(width: double.infinity)
              : Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.warn),
                ),
        ),
        const SizedBox(height: 8),
        Text(
          'Nothing you track is shared unless you add it to a split.',
          textAlign: TextAlign.center,
          style: TextStyle(color: c.muted, fontSize: 12.5),
        ),
      ],
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) =>
      const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2));
}

/// Three overlapping avatars that drift into place.
class _PeopleArt extends StatelessWidget {
  const _PeopleArt();

  @override
  Widget build(BuildContext context) {
    const people = [
      Profile(uid: 'a', handle: 'a', name: 'Sam'),
      Profile(uid: 'bb', handle: 'b', name: 'You'),
      Profile(uid: 'ccc', handle: 'c', name: 'Ana'),
    ];
    return SizedBox(
      height: 76,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final (i, p) in people.indexed)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Motion.of(context, Motion.slow),
              curve: Motion.emphasized,
              builder: (context, t, child) =>
                  Transform.translate(offset: Offset((i - 1) * 46.0 * t, 0), child: child),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: context.colors.background, width: 3),
                ),
                child: PersonAvatar(p, size: i == 1 ? 70 : 58),
              ),
            ),
        ],
      ),
    );
  }
}

/// Picks a username and display name once, after signing in.
class ClaimHandleView extends ConsumerStatefulWidget {
  const ClaimHandleView({super.key});

  @override
  ConsumerState<ClaimHandleView> createState() => _ClaimHandleViewState();
}

class _ClaimHandleViewState extends ConsumerState<ClaimHandleView> {
  late final TextEditingController _name;
  late final TextEditingController _handle;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final account = ref.read(accountProvider).value;
    final settingsName = ref.read(settingsProvider).name;
    final name = settingsName.isNotEmpty ? settingsName : account?.suggestedName ?? '';
    _name = TextEditingController(text: name);
    _handle = TextEditingController(text: Handle.suggest(name));
  }

  @override
  void dispose() {
    _name.dispose();
    _handle.dispose();
    super.dispose();
  }

  String get _normalized => Handle.normalize(_handle.text);

  Future<void> _claim() async {
    final handle = _normalized;
    final invalid = Handle.validate(handle);
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(socialBackendProvider)!.claimHandle(handle, _name.text.trim());
    } on HandleTaken {
      if (mounted) setState(() => _error = '@$handle is taken. Try another.');
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final preview = Profile(uid: 'me', handle: _normalized, name: _name.text.trim());
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 120),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        const FadeSlideIn(
          child: Text(
            'Pick a username',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.8),
          ),
        ),
        const SizedBox(height: 8),
        FadeSlideIn(
          index: 1,
          child: Text(
            'Friends add you by your exact username. Nobody can browse or search for you.',
            style: TextStyle(color: c.muted, fontSize: 15, height: 1.4),
          ),
        ),
        const SizedBox(height: 24),
        FadeSlideIn(
          index: 2,
          child: Row(
            children: [
              AnimatedSwitcher(
                duration: Motion.of(context, Motion.fast),
                child: PersonAvatar(preview, key: ValueKey(preview.initials), size: 52),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Your name'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FadeSlideIn(
          index: 3,
          child: TextField(
            key: const ValueKey('handle'),
            controller: _handle,
            autocorrect: false,
            enableSuggestions: false,
            onChanged: (_) => setState(() => _error = null),
            onSubmitted: (_) => _claim(),
            decoration: InputDecoration(
              labelText: 'Username',
              prefixText: '@',
              errorText: _error,
              helperText: 'Letters, numbers, _ and . · 3–20 characters',
            ),
          ),
        ),
        const SizedBox(height: 24),
        FadeSlideIn(
          index: 4,
          child: FilledButton(
            onPressed: _busy || _normalized.isEmpty ? null : _claim,
            child: Text(_busy ? 'Saving…' : 'Continue as @$_normalized'),
          ),
        ),
      ],
    );
  }
}
