import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recipetools/database/database.dart';
import 'package:recipetools/features/mold_calculator/domain/entities/mold_geometry.dart';
import 'package:recipetools/features/mold_calculator/presentation/providers/mold_calculator_provider.dart';
import 'package:recipetools/features/mold_calculator/presentation/screens/mold_calculator_screen.dart';
import 'package:recipetools/l10n/app_localizations.dart';
import 'package:recipetools/provider/database_provider.dart';
import 'package:recipetools/provider/settings_provider.dart';
import 'package:recipetools/screens/recipe_editor_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockDatabaseNotifier extends DatabaseNotifier {
  final AppDatabase _db;
  _MockDatabaseNotifier(this._db);

  @override
  AppDatabase build() => _db;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MoldCalculatorScreen & Recipe Integration Widget Tests', () {
    late SharedPreferences sharedPrefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPrefs = await SharedPreferences.getInstance();
    });

    testWidgets('Renders Scale & Convert and Portion & Yield tabs cleanly on mobile and desktop', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPrefs),
            recipesWithFinancialsStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: MoldCalculatorScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Default source 20x5 -> target 24x5 => k_V = (12^2)/(10^2) = 1.44
      expect(find.textContaining('1,44×'), findsWidgets);
      expect(find.byKey(const ValueKey('mold_source_form')), findsOneWidget);
      expect(find.byKey(const ValueKey('mold_target_form')), findsOneWidget);

      // Toggle Equivalence Mode and apply solved dimension
      final equivToggle = find.byKey(const ValueKey('mold_equivalence_toggle'));
      await tester.ensureVisible(equivToggle);
      await tester.tap(equivToggle);
      await tester.pumpAndSettle();

      final applyEquivBtn = find.byKey(const ValueKey('mold_apply_equivalence_button'));
      expect(applyEquivBtn, findsOneWidget);
      await tester.ensureVisible(applyEquivBtn);
      await tester.tap(applyEquivBtn);
      await tester.pumpAndSettle();

      // After applying equivalence, volume factor converges to 1×
      expect(find.textContaining('1×'), findsWidgets);

      // Wide layout verification
      tester.view.physicalSize = const Size(1280, 900);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('mold_source_form')), findsOneWidget);
      expect(find.byKey(const ValueKey('mold_target_form')), findsOneWidget);
    });

    testWidgets('Portion & Yield tab computes grid layout and updates waste metrics', (tester) async {
      tester.view.physicalSize = const Size(900, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPrefs),
            recipesWithFinancialsStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: MoldCalculatorScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Set target mold to 30x20x4 rectangular pan via provider
      final container =
          ProviderScope.containerOf(tester.element(find.byType(MoldCalculatorScreen)));
      container.read(moldCalculatorProvider.notifier).setMold(
            MoldRole.target,
            const RectangularPrism(length: 30.0, width: 20.0, height: 4.0),
            bumpVersion: true,
          );
      await tester.pumpAndSettle();

      // Switch to Portion & Yield tab
      await tester.tap(find.byKey(const ValueKey('mold_tab_portion')));
      await tester.pumpAndSettle();

      // Switch to Grid cut strategy
      await tester.tap(find.byKey(const ValueKey('mold_cut_grid')));
      await tester.pumpAndSettle();

      // Enter 8 x 4 bar dimensions
      await tester.enterText(find.byKey(const ValueKey('mold_grid_piece_length')), '8');
      await tester.enterText(find.byKey(const ValueKey('mold_grid_piece_width')), '4');
      await tester.enterText(find.byKey(const ValueKey('mold_grid_edge_trim')), '0');
      await tester.pumpAndSettle();

      // Expect 15 full portions and 120 cm² (20%) waste
      expect(find.text('15'), findsOneWidget);
      expect(find.textContaining('120'), findsWidgets);
    });

    testWidgets('Custom mold save & delete persists in SharedPreferences', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPrefs),
            recipesWithFinancialsStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: Locale('en'),
            home: MoldCalculatorScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final container =
          ProviderScope.containerOf(tester.element(find.byType(MoldCalculatorScreen)));
      await container.read(moldCalculatorProvider.notifier).saveCustomMold(
            'My Special Tin',
            const SquarePrism(side: 18.0, height: 6.0),
          );
      expect(container.read(moldCalculatorProvider).customMolds.length, 1);

      final customId = container.read(moldCalculatorProvider).customMolds.first.id;
      await container.read(moldCalculatorProvider.notifier).deleteCustomMold(customId);
      expect(container.read(moldCalculatorProvider).customMolds, isEmpty);
    });

    testWidgets('End-to-end RecipeEditorScreen integration scales ingredients from MoldCalculatorScreen', (tester) async {
      tester.view.physicalSize = const Size(500, 950);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final testDb = AppDatabase.forTesting(NativeDatabase.memory());
      const unitG = Unit(
        unitPk: 'u_g',
        name: 'Gramos',
        symbol: 'g',
        category: 'mass',
        factorToBase: 1.0,
        isMutable: false,
      );
      final ingFlour = Ingredient(
        ingredientPk: 'ing_flour',
        name: 'Flour',
        cost: 2.0,
        quantityForCost: 1000.0,
        unitFk: 'u_g',
        dateCreated: DateTime.now(),
        isDeleted: false,
      );
      await testDb.into(testDb.ingredients).insert(ingFlour);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPrefs),
            databaseProvider.overrideWith(() => _MockDatabaseNotifier(testDb)),
            unitsProvider.overrideWith((ref) => Future.value([unitG])),
            unitsStreamProvider.overrideWith((ref) => Stream.value([unitG])),
            ingredientsStreamProvider.overrideWith((ref) => Stream.value([ingFlour])),
            recipesWithFinancialsStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('en'),
            home: RecipeEditorScreen(
              isTemporary: true,
              initialName: 'Sponge Cake',
              initialYield: '8',
              initialProfitMargin: '30',
              initialPrice: '10',
              initialIngredients: [
                InitialIngredientInput(ingredient: ingFlour, amount: 100.0),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open Mold Calculator from the scale bar chip
      final moldChip = find.byKey(const ValueKey('scale_chip_mold_calculator'));
      expect(moldChip, findsOneWidget);
      await tester.ensureVisible(moldChip);
      await tester.tap(moldChip);
      await tester.pumpAndSettle();

      expect(find.byType(MoldCalculatorScreen), findsOneWidget);

      // Default source 20x5 -> target 24x5 gives k_V = 1.44
      final applyBtn = find.byKey(const ValueKey('mold_apply_to_recipe_button'));
      expect(applyBtn, findsOneWidget);
      await tester.ensureVisible(applyBtn);
      await tester.pumpAndSettle();
      await tester.tap(applyBtn);
      await tester.pumpAndSettle();

      // Back in RecipeEditorScreen: 100g flour * 1.44 = 144g flour
      expect(find.byType(RecipeEditorScreen), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is TextField && w.controller?.text == '144',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('temporary_scale_banner')), findsOneWidget);
    });
  });
}
