import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../app/theme.dart';
import 'motion.dart';

/// The launch logo, drawn by Flutter exactly where the native splash draws it.
const splashLogo = AssetImage('assets/brand/splash_logo.png');

/// The logo's size on the native splash screens (a 768px image at 4x).
const splashLogoSize = 192.0;

/// Picks up where the native launch screen leaves off: the first frame repeats
/// it (same background, same logo in the same place), then the logo grows and
/// fades while the app settles in underneath. Without this, the native splash
/// would cut straight to the app.
///
/// Skipped when the user asked the OS to reduce motion.
class SplashReveal extends StatefulWidget {
  const SplashReveal({super.key, required this.child});

  final Widget child;

  @override
  State<SplashReveal> createState() => _SplashRevealState();
}

class _SplashRevealState extends State<SplashReveal> with SingleTickerProviderStateMixin {
  /// The logo holds still this long first. The app's first frames are slow to
  /// draw; moving during them would skip most of the animation.
  static const _hold = Duration(milliseconds: 200);
  static final _start = _hold.inMilliseconds / (_hold + Motion.slow).inMilliseconds;

  late final AnimationController _controller =
      AnimationController(vsync: this, duration: _hold + Motion.slow)..addStatusListener((status) {
        if (status == AnimationStatus.completed) setState(() => _done = true);
      });

  bool _done = false;

  /// [begin] and [end] are fractions of the movement after the hold.
  Animation<double> _phase(double from, double to, double begin, double end, Curve curve) =>
      Tween(begin: from, end: to).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Interval(_start + begin * (1 - _start), _start + end * (1 - _start), curve: curve),
        ),
      );

  // The logo leads, the background follows, and the app eases up to full size.
  late final _logoScale = _phase(1, 1.35, 0, 0.7, Motion.exit);
  late final _logoFade = _phase(1, 0, 0.1, 0.6, Curves.easeIn);
  late final _backdropFade = _phase(1, 0, 0.3, 1, Motion.enter);
  late final _appScale = _phase(0.96, 1, 0.3, 1, Motion.enter);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_done || _controller.isAnimating) return;
    if (Motion.of(context, Motion.slow) == Duration.zero) {
      _done = true;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return widget.child;
    return Stack(
      fit: StackFit.expand,
      children: [
        // Fills the edges while the app is still slightly scaled down.
        ColoredBox(color: context.colors.background),
        ScaleTransition(scale: _appScale, child: widget.child),
        IgnorePointer(
          child: FadeTransition(
            opacity: _backdropFade,
            child: ColoredBox(color: context.colors.background),
          ),
        ),
        IgnorePointer(
          child: Center(
            child: FadeTransition(
              opacity: _logoFade,
              child: ScaleTransition(
                scale: _logoScale,
                child: const Image(
                  image: splashLogo,
                  width: splashLogoSize,
                  height: splashLogoSize,
                  gaplessPlayback: true,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Decodes the logo before the first frame so the hand-off has no blank frame.
/// Gives up quietly after a moment; the app must never wait on a splash.
Future<void> preloadSplashLogo() async {
  final ready = Completer<void>();
  void finish() {
    if (!ready.isCompleted) ready.complete();
  }

  final listener = ImageStreamListener((_, _) => finish(), onError: (_, _) => finish());
  final stream = splashLogo.resolve(ImageConfiguration.empty)..addListener(listener);
  await ready.future.timeout(const Duration(milliseconds: 300), onTimeout: () {});
  stream.removeListener(listener);
}
