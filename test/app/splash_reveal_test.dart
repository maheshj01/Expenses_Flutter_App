import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:three_bucks/app/theme.dart';
import 'package:three_bucks/shared/animations/splash_reveal.dart';

Widget _app({bool reduceMotion = false}) => MaterialApp(
  theme: buildTheme(Brightness.light),
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
    child: SplashReveal(child: child!),
  ),
  home: Scaffold(body: TextButton(onPressed: () {}, child: const Text('Home'))),
);

void main() {
  testWidgets('starts on the launch logo, then reveals the app', (tester) async {
    await tester.pumpWidget(_app());

    expect(find.image(splashLogo), findsOneWidget);
    final logo = tester.getSize(find.image(splashLogo));
    expect(logo, const Size(splashLogoSize, splashLogoSize));
    expect(tester.getCenter(find.image(splashLogo)), tester.getCenter(find.byType(Scaffold)));

    await tester.pumpAndSettle();
    expect(find.image(splashLogo), findsNothing);
    await tester.tap(find.text('Home'));
  });

  testWidgets('skips the reveal when motion is reduced', (tester) async {
    await tester.pumpWidget(_app(reduceMotion: true));
    expect(find.image(splashLogo), findsNothing);
    expect(find.text('Home'), findsOneWidget);
  });
}
