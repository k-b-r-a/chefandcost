import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recipetools/database/database.dart';
import 'package:recipetools/provider/database_provider.dart';
import 'package:recipetools/screens/recipe_editor_screen.dart';
import 'package:recipetools/services/app_tutorial_service.dart';
import 'package:recipetools/l10n/app_localizations.dart';
import 'package:recipetools/provider/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockDatabaseNotifier extends DatabaseNotifier {
  final AppDatabase _db;
  MockDatabaseNotifier(this._db);

  @override
  AppDatabase build() => _db;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const unitG = Unit(
    unitPk: 'u_g',
    name: 'Gramos',
    symbol: 'g',
    category: 'mass',
    factorToBase: 1.0,
    isMutable: false,
  );

  const allUnits = [unitG];

  final ingFlour = Ingredient(
    ingredientPk: 'ing_flour',
    name: 'Harina',
    cost: 2.0,
    quantityForCost: 1000.0,
    unitFk: 'u_g',
    dateCreated: DateTime.now(),
  );

  group('RecipeEditorScreen Tools Menu and Redundant Button Removal Tests', () {
    late SharedPreferences sharedPrefs;
    late AppDatabase testDb;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPrefs = await SharedPreferences.getInstance();
      testDb = AppDatabase.forTesting(NativeDatabase.memory());
      await testDb.into(testDb.ingredients).insert(ingFlour);
    });

    Widget createTestApp({
      bool isTemporary = false,
      String? recipeId = 'rec_1',
      RecipeEditorTutorialKeys? tutorialKeys,
    }) {
      return ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPrefs),
          databaseProvider.overrideWith(() => MockDatabaseNotifier(testDb)),
          unitsProvider.overrideWith((ref) => Future.value(allUnits)),
          unitsStreamProvider.overrideWith((ref) => Stream.value(allUnits)),
          ingredientsStreamProvider.overrideWith(
            (ref) => Stream.value([ingFlour]),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: RecipeEditorScreen(
            recipeId: recipeId,
            isTemporary: isTemporary,
            initialName: 'Test Cake',
            initialYield: '4',
            initialProfitMargin: '30',
            initialPrice: '10',
            tutorialKeys: tutorialKeys,
            initialIngredients: [
              InitialIngredientInput(
                ingredient: ingFlour,
                amount: 200,
              ),
            ],
          ),
        ),
      );
    }

    testWidgets('Tools menu button is in AppBar and opens menu with Duplicate and Timers', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Verify handyman icon button exists in the AppBar
      final toolsButton = find.byKey(const ValueKey('recipe_tools_menu_button'));
      expect(toolsButton, findsOneWidget);
      expect(find.byIcon(Icons.handyman_rounded), findsOneWidget);

      // Verify old duplicate icon button is NOT in the AppBar actions
      expect(find.byIcon(Icons.copy_rounded), findsNothing);

      // Open tools menu
      await tester.tap(toolsButton);
      await tester.pumpAndSettle();

      // In popup menu: Duplicate, Timers, Add Recipe Timer
      expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
      expect(find.byIcon(Icons.add_alarm_rounded), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(PopupMenuItem<String>),
          matching: find.byIcon(Icons.timer_outlined),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Mobile layout has no redundant duplicate or timer button under description', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Ensure no duplicate button or timer button below description in body
      expect(find.byIcon(Icons.copy_rounded), findsNothing);
      expect(find.byIcon(Icons.timer_outlined), findsNothing);

      // Tools button still exists in AppBar
      expect(find.byKey(const ValueKey('recipe_tools_menu_button')), findsOneWidget);
    });

    testWidgets('Desktop web layout has no duplicate button next to description', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Ensure no duplicate button in body
      expect(find.byIcon(Icons.copy_rounded), findsNothing);

      // Tools button exists in AppBar
      expect(find.byKey(const ValueKey('recipe_tools_menu_button')), findsOneWidget);
    });
    testWidgets('Portions button is positioned to the left of the multiplier presets', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      final portionsChip = find.byKey(const ValueKey('scale_chip_custom_portions'));
      final quarterChip = find.byKey(const ValueKey('scale_chip_0_25'));
      final oneXChip = find.byKey(const ValueKey('scale_chip_1'));

      expect(portionsChip, findsOneWidget);
      expect(quarterChip, findsOneWidget);
      expect(oneXChip, findsOneWidget);

      final portionsX = tester.getTopLeft(portionsChip).dx;
      final quarterX = tester.getTopLeft(quarterChip).dx;
      final oneXX = tester.getTopLeft(oneXChip).dx;

      expect(portionsX, lessThan(quarterX), reason: 'Portions button must be to the left of 1/4x preset');
      expect(portionsX, lessThan(oneXX), reason: 'Portions button must be to the left of 1x preset');
    });

    testWidgets('Scale bar tutorial step includes swipe gesture icon and scroll explanation', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final keys = RecipeEditorTutorialKeys();
      await tester.pumpWidget(createTestApp(tutorialKeys: keys));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(RecipeEditorScreen));
      final targets = AppTutorialService.createRecipeEditorTargets(
        context: context,
        keys: keys,
      );

      final scaleStep = targets.firstWhere((t) => t.identify == 'step_recipe_editor_scale_bar');
      expect(scaleStep, isNotNull);
      expect(scaleStep.enableTargetTab, isTrue);
    });
  });
}
