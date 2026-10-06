import 'package:flutter/material.dart';
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
