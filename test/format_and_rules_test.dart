import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipetools/utils/recipe_utils.dart';
import 'package:recipetools/screens/unit_converter_screen.dart';
import 'package:recipetools/database/database.dart';
import 'package:recipetools/provider/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recipetools/l10n/app_localizations.dart';

void main() {
  group('RecipeUtils.parseFormattedNumber tests', () {
    test('parses decimal dots correctly', () {
      expect(RecipeUtils.parseFormattedNumber('1.5'), 1.5);
      expect(RecipeUtils.parseFormattedNumber('0.5'), 0.5);
      expect(RecipeUtils.parseFormattedNumber('2.5'), 2.5);
      expect(RecipeUtils.parseFormattedNumber('.5'), 0.5);
    });

    test('parses decimal commas correctly', () {
      expect(RecipeUtils.parseFormattedNumber('1,5'), 1.5);
      expect(RecipeUtils.parseFormattedNumber('0,5'), 0.5);
      expect(RecipeUtils.parseFormattedNumber(',5'), 0.5);
    });

    test('parses numbers with units and text correctly', () {
      expect(RecipeUtils.parseFormattedNumber('100g'), 100.0);
      expect(RecipeUtils.parseFormattedNumber('100 g'), 100.0);
      expect(RecipeUtils.parseFormattedNumber('2.5 kg'), 2.5);
      expect(RecipeUtils.parseFormattedNumber('250ml'), 250.0);
      expect(RecipeUtils.parseFormattedNumber('50 %'), 50.0);
    });

    test('parses thousands separators properly', () {
      expect(RecipeUtils.parseFormattedNumber('1.000,50'), 1000.5);
      expect(RecipeUtils.parseFormattedNumber('1,000.50'), 1000.5);
      expect(RecipeUtils.parseFormattedNumber('1.000.000'), 1000000.0);
      expect(RecipeUtils.parseFormattedNumber('1,000,000'), 1000000.0);
    });

    test('handles empty or non-numeric gracefully', () {
      expect(RecipeUtils.parseFormattedNumber(''), 0.0);
      expect(RecipeUtils.parseFormattedNumber('   '), 0.0);
      expect(RecipeUtils.parseFormattedNumber('abc'), 0.0);
    });
  });

  group('RecipeUtils.formatNumber tests', () {
    test('default formatting preserves 2 decimals', () {
      expect(RecipeUtils.formatNumber(100), '100,00');
      expect(RecipeUtils.formatNumber(1.5), '1,50');
    });

    test('trimTrailingZeros removes unnecessary decimal zeros', () {
      expect(RecipeUtils.formatNumber(1000, decimalDigits: 4, trimTrailingZeros: true), '1.000');
      expect(RecipeUtils.formatNumber(1, decimalDigits: 4, trimTrailingZeros: true), '1');
      expect(RecipeUtils.formatNumber(1.5, decimalDigits: 4, trimTrailingZeros: true), '1,5');
      expect(RecipeUtils.formatNumber(1.25, decimalDigits: 4, trimTrailingZeros: true), '1,25');
      expect(RecipeUtils.formatNumber(0.5, decimalDigits: 4, trimTrailingZeros: true), '0,5');
      expect(RecipeUtils.formatNumber(0.1234, decimalDigits: 4, trimTrailingZeros: true), '0,1234');
      expect(RecipeUtils.formatNumber(0, trimTrailingZeros: true), '0');
    });
  });

  group('UnitConverterScreen widget tests', () {
    final List<Unit> testUnits = [
      const Unit(
        unitPk: 'u_kg',
        name: 'Kilogram',
        symbol: 'kg',
        category: 'mass',
        factorToBase: 1000.0,
        isMutable: false,
      ),
      const Unit(
        unitPk: 'u_g',
        name: 'Gram',
        symbol: 'g',
        category: 'mass',
        factorToBase: 1.0,
        isMutable: false,
      ),
    ];

    Widget buildTestApp(Widget child) {
      return ProviderScope(
        overrides: [
          unitsProvider.overrideWith((ref) => Future.value(testUnits)),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('es'),
          home: child,
        ),
      );
    }

    testWidgets('displays conversion result without excess decimals (no trailing zeros)', (tester) async {
      await tester.pumpWidget(buildTestApp(const UnitConverterScreen()));
      await tester.pumpAndSettle();

      // 1 kg should convert to 1.000 g (NOT 1.000,0000 g)
      expect(find.text('1.000'), findsOneWidget);
      expect(find.text('1.000,0000'), findsNothing);

      // Check summary card does not contain excess zeros
      expect(find.text('1 kg = 1.000 g'), findsOneWidget);
      expect(find.textContaining(',0000'), findsNothing);
    });
  });
}
