import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipetools/widgets/app_logo.dart';

void main() {
  testWidgets('AppIcon renders cleanly without errors', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppIcon(size: 44),
        ),
      ),
    );

    expect(find.byType(AppIcon), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AppIconThemePalette resolves correctly for all 8 preset accent colors and modes',
      (WidgetTester tester) async {
    final presets = <Color, (AppIconThemePalette, AppIconThemePalette)>{
      Colors.deepPurple: (AppIconThemePalette.deepPurpleLight, AppIconThemePalette.deepPurpleDark),
      Colors.blue: (AppIconThemePalette.blueLight, AppIconThemePalette.blueDark),
      Colors.teal: (AppIconThemePalette.tealLight, AppIconThemePalette.tealDark),
      Colors.green: (AppIconThemePalette.greenLight, AppIconThemePalette.greenDark),
      Colors.amber: (AppIconThemePalette.amberLight, AppIconThemePalette.amberDark),
      Colors.orange: (AppIconThemePalette.orangeLight, AppIconThemePalette.orangeDark),
      Colors.red: (AppIconThemePalette.redLight, AppIconThemePalette.redDark),
      Colors.pink: (AppIconThemePalette.pinkLight, AppIconThemePalette.pinkDark),
    };

    for (final entry in presets.entries) {
      final color = entry.key;
      final (expectedLight, expectedDark) = entry.value;

      final lightTheme = ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: color, brightness: Brightness.light),
      );
      final darkTheme = ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: color, brightness: Brightness.dark),
      );

      final resolvedLight = AppIconThemePalette.fromTheme(lightTheme);
      final resolvedDark = AppIconThemePalette.fromTheme(darkTheme);

      expect(resolvedLight.baseColor, expectedLight.baseColor,
          reason: 'Light baseColor mismatch for $color');
      expect(resolvedLight.midColor, expectedLight.midColor,
          reason: 'Light midColor mismatch for $color');
      expect(resolvedLight.highlightColor, expectedLight.highlightColor,
          reason: 'Light highlightColor mismatch for $color');

      expect(resolvedDark.baseColor, expectedDark.baseColor,
          reason: 'Dark baseColor mismatch for $color');
      expect(resolvedDark.midColor, expectedDark.midColor,
          reason: 'Dark midColor mismatch for $color');
      expect(resolvedDark.highlightColor, expectedDark.highlightColor,
          reason: 'Dark highlightColor mismatch for $color');
    }
  });

  testWidgets('AppIcon dynamically adapts rendered SVG colors to theme',
      (WidgetTester tester) async {
    // 1. Blue Light Theme
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.light),
        ),
        home: const Scaffold(
          body: AppIcon(size: 48),
        ),
      ),
    );

    var svgPicture = tester.widget<SvgPicture>(find.descendant(
      of: find.byType(AppIcon),
      matching: find.byType(SvgPicture),
    ));
    var stringLoader = svgPicture.bytesLoader as SvgStringLoader;
    expect(stringLoader.provideSvg(null).contains('#0F3261'), isTrue,
        reason: 'SVG should contain blueLight baseColor #0F3261');

    // 2. Red Dark Theme
    await tester.pumpWidget(
      MaterialApp(
        home: Theme(
          data: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.red, brightness: Brightness.dark),
          ),
          child: const Scaffold(
            body: AppIcon(size: 48),
          ),
        ),
      ),
    );

    svgPicture = tester.widget<SvgPicture>(find.descendant(
      of: find.byType(AppIcon),
      matching: find.byType(SvgPicture),
    ));
    stringLoader = svgPicture.bytesLoader as SvgStringLoader;
    final svg2 = stringLoader.provideSvg(null);
    expect(svg2.contains('#3D070D'), isTrue,
        reason: 'SVG should contain redDark baseColor #3D070D');

    // 3. Original brand colors when adaptToTheme is false
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.light),
        ),
        home: const Scaffold(
          body: AppIcon(size: 48, adaptToTheme: false),
        ),
      ),
    );

    svgPicture = tester.widget<SvgPicture>(find.descendant(
      of: find.byType(AppIcon),
      matching: find.byType(SvgPicture),
    ));
    stringLoader = svgPicture.bytesLoader as SvgStringLoader;
    expect(stringLoader.provideSvg(null).contains('#6B3208'), isTrue,
        reason: 'SVG should contain original baseColor #6B3208 when adaptToTheme is false');
  });

  testWidgets('ChefAndCostText renders "Chef", "&", and "Cost" on a single fitted line',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 72,
            child: ChefAndCostText(),
          ),
        ),
      ),
    );

    expect(find.textContaining('Chef', findRichText: true), findsOneWidget);
    expect(find.textContaining('&', findRichText: true), findsOneWidget);
    expect(find.textContaining('Cost', findRichText: true), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ChefAndCostBadge renders at custom size without errors',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ChefAndCostBadge(size: 46),
        ),
      ),
    );

    expect(find.byType(ChefAndCostBadge), findsOneWidget);
    expect(find.byType(AppIcon), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ChefAndCostBrand in compact mode renders and triggers onTap',
      (WidgetTester tester) async {
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 80,
              child: ChefAndCostBrand(
                onTap: () {
                  tapped = true;
                },
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(ChefAndCostBrand), findsOneWidget);
    expect(find.byType(AppIcon), findsOneWidget);

    await tester.tap(find.byType(ChefAndCostBrand));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('ChefAndCostBrand in extended mode renders horizontally with tagline',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: ChefAndCostBrand(
              isExtended: true,
              showTagline: true,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(ChefAndCostBrand), findsOneWidget);
    expect(find.text('KITCHEN & RECIPES'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
