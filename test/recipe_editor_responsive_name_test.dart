import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:recipetools/database/database.dart';
import 'package:recipetools/l10n/app_localizations.dart';
import 'package:recipetools/provider/database_provider.dart';
import 'package:recipetools/provider/settings_provider.dart';
import 'package:recipetools/screens/recipe_editor_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences sharedPrefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    sharedPrefs = await SharedPreferences.getInstance();
  });

  Widget buildTestApp({required Widget home}) {
    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPrefs),
        ingredientsStreamProvider.overrideWith((ref) => Stream.value(<Ingredient>[])),
        unitsProvider.overrideWith((ref) => Future.value(<Unit>[])),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('es'),
        home: home,
      ),
    );
  }

  testWidgets('On small horizontal device, recipe name is placed in body under top header and above description', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestApp(home: const RecipeEditorScreen()));
    await tester.pumpAndSettle();

    // Top header AppBar has a clean screen title
    final appBar = find.byType(AppBar);
    expect(appBar, findsOneWidget);
    expect(find.descendant(of: appBar, matching: find.text('Nueva Receta')), findsOneWidget);

    // In the body, recipe name section header and input field are present under header and above description
    expect(find.text('Nombre de la Receta'), findsNWidgets(2)); // Header and hint text
    final nameHeaderWidget = find.text('Nombre de la Receta').first;

    final nameInputField = find.byKey(const ValueKey('recipe_name_input'));
    expect(nameInputField, findsOneWidget);

    final descSectionHeader = find.text('Descripción');
    expect(descSectionHeader, findsOneWidget);

    // Verify ordering: Top Header -> Name Section -> Description Section
    final appBarY = tester.getTopLeft(appBar).dy;
    final nameHeaderY = tester.getTopLeft(nameHeaderWidget).dy;
    final nameFieldY = tester.getTopLeft(nameInputField).dy;
    final descHeaderY = tester.getTopLeft(descSectionHeader).dy;

    expect(appBarY < nameHeaderY, isTrue);
    expect(nameHeaderY < nameFieldY, isTrue);
    expect(nameFieldY < descHeaderY, isTrue);

    // Enter a name in the mobile body field
    await tester.enterText(nameInputField, 'Torta Tres Leches');
    await tester.pump();

    expect(find.text('Torta Tres Leches'), findsOneWidget);
  });

  testWidgets('On wide horizontal device, recipe name is kept in top header and not in body', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(buildTestApp(home: const RecipeEditorScreen()));
    await tester.pumpAndSettle();

    // Top app bar has the name TextField
    final appBarNameField = find.descendant(
      of: find.byType(AppBar),
      matching: find.byType(TextField),
    );
    expect(appBarNameField, findsOneWidget);

    // In the body, there is NO recipe_name_input
    expect(find.byKey(const ValueKey('recipe_name_input')), findsNothing);
  });
}
