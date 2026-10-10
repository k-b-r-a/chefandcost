import 'dart:ui' as ui;
import 'package:flutter/material.dart' show Locale;
import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'database.dart';
import 'initialize_default_database.dart';
import '../l10n/app_localizations.dart';
import '../services/app_tutorial_service.dart';

/// Identifier for the initial temporary sample manufacturing recipe.
const String kSampleManufacturingRecipePk = 'sample_manufacturing_recipe_v1';

/// SharedPreferences flag indicating the user has dismissed / deleted the sample recipe.
const String kSampleManufacturingRecipeDismissedKey =
    'has_dismissed_sample_manufacturing_recipe_v1';

/// Stable PKs for the 3 manufacturing raw materials.
const String kSampleFlourPk = 'sample_mfg_wheat_flour_v1';
const String kSampleButterPk = 'sample_mfg_butter_v1';
const String kSampleSugarPk = 'sample_mfg_sugar_v1';

/// Returns true if [recipePk] corresponds to the initial sample manufacturing recipe.
bool isSampleManufacturingRecipe(String? recipePk) =>
    recipePk == kSampleManufacturingRecipePk;

/// Resolves appropriate [AppLocalizations] adapting to the device language or user preference.
AppLocalizations getSampleRecipeLocalizations({
  SharedPreferences? prefs,
  Locale? locale,
}) {
  if (locale != null) {
    try {
      return lookupAppLocalizations(locale);
    } catch (_) {
      try {
        return lookupAppLocalizations(Locale(locale.languageCode));
      } catch (_) {}
    }
  }
  final savedCode = prefs?.getString('locale');
  if (savedCode != null && savedCode.isNotEmpty) {
    try {
      return lookupAppLocalizations(Locale(savedCode));
    } catch (_) {}
  }
  try {
    final devLocale = ui.PlatformDispatcher.instance.locale;
    return lookupAppLocalizations(Locale(devLocale.languageCode));
  } catch (_) {}
  return lookupAppLocalizations(const Locale('es'));
}

/// Ensures the initial 3-ingredient manufacturing recipe exists on fresh app start.
/// Adapts ingredient names, recipe title, description, and steps to the device language.
/// Returns true if the recipe was created, false otherwise.
Future<bool> ensureSampleManufacturingRecipe(
  AppDatabase db, {
  SharedPreferences? prefs,
  Locale? locale,
}) async {
  final p = prefs ?? await SharedPreferences.getInstance();
  if (p.getBool(kSampleManufacturingRecipeDismissedKey) == true) {
    return false;
  }

  // If the recipe editor walkthrough has already been completed, do not keep or create the sample recipe
  if (p.getBool(AppTutorialService.kTutorialRecipeEditorCompletedKey) == true) {
    final existingSample = (await (db.select(db.recipes)
          ..where((t) => t.recipePk.equals(kSampleManufacturingRecipePk)))
        .get()).firstOrNull;
    if (existingSample != null) {
      await dismissSampleManufacturingRecipe(db, prefs: p);
    }
    return false;
  }

  final allRecipes = await db.getAllRecipes();
  if (allRecipes.isNotEmpty) {
    return false;
  }

  final l10n = getSampleRecipeLocalizations(prefs: p, locale: locale);

  // 1. Ensure default culinary units exist
  await initializeDefaultDatabase(db);
  final units = await db.getAllUnits();
  final gUnit = units.firstWhere(
    (u) => u.symbol == 'g' || u.name == 'unit_grams',
    orElse: () => units.first,
  );

  // 2. Ensure the 3 raw material ingredients exist
  final existingIngs = await db.getAllIngredients();
  final ingByName = {
    for (var i in existingIngs) i.name.toLowerCase().trim(): i,
  };

  String flourPk = kSampleFlourPk;
  final existingFlour = ingByName[l10n.sample_manufacturing_flour_name.toLowerCase().trim()] ??
      ingByName['harina de trigo 0000'] ??
      ingByName['all-purpose wheat flour'];
  if (existingFlour != null) {
    flourPk = existingFlour.ingredientPk;
  } else {
    await db.insertIngredient(
      IngredientsCompanion(
        ingredientPk: Value(flourPk),
        name: Value(l10n.sample_manufacturing_flour_name),
        cost: const Value(1.20),
        quantityForCost: const Value(1000.0),
        unitFk: Value(gUnit.unitPk),
        dateCreated: Value(DateTime.now()),
        dateTimeModified: Value(DateTime.now()),
      ),
    );
  }

  String butterPk = kSampleButterPk;
  final existingButter = ingByName[l10n.sample_manufacturing_butter_name.toLowerCase().trim()] ??
      ingByName['mantequilla sin sal'] ??
      ingByName['unsalted butter'];
  if (existingButter != null) {
    butterPk = existingButter.ingredientPk;
  } else {
    await db.insertIngredient(
      IngredientsCompanion(
        ingredientPk: Value(butterPk),
        name: Value(l10n.sample_manufacturing_butter_name),
        cost: const Value(2.80),
        quantityForCost: const Value(250.0),
        unitFk: Value(gUnit.unitPk),
        dateCreated: Value(DateTime.now()),
        dateTimeModified: Value(DateTime.now()),
      ),
    );
  }

  String sugarPk = kSampleSugarPk;
  final existingSugar = ingByName[l10n.sample_manufacturing_sugar_name.toLowerCase().trim()] ??
      ingByName['azúcar blanca refinada'] ??
      ingByName['azucar blanca refinada'] ??
      ingByName['refined white sugar'];
  if (existingSugar != null) {
    sugarPk = existingSugar.ingredientPk;
  } else {
    await db.insertIngredient(
      IngredientsCompanion(
        ingredientPk: Value(sugarPk),
        name: Value(l10n.sample_manufacturing_sugar_name),
        cost: const Value(1.50),
        quantityForCost: const Value(1000.0),
        unitFk: Value(gUnit.unitPk),
        dateCreated: Value(DateTime.now()),
        dateTimeModified: Value(DateTime.now()),
      ),
    );
  }

  // 3. Create the 3-ingredient manufacturing recipe
  // Standard 3:2:1 industrial shortbread/cookie manufacturing batch:
  // - 300g Flour ($0.36)
  // - 200g Butter ($2.24)
  // - 100g Sugar ($0.15)
  // Total raw material cost: $2.75 for 24 pieces ($0.1146/piece)
  // 50% target profit margin -> $0.23/piece -> $5.52 total batch value.
  await db.transaction(() async {
    await db.insertRecipe(
      RecipesCompanion(
        recipePk: const Value(kSampleManufacturingRecipePk),
        name: Value(l10n.sample_manufacturing_recipe_title),
        description: Value(l10n.sample_manufacturing_recipe_desc),
        defaultYield: const Value(24.0),
        yieldName: Value(l10n.sample_manufacturing_yield_name),
        targetProfitMargin: const Value(50.0),
        targetPricePerPortion: const Value(0.23),
        fixedOverheadCost: const Value(0.0),
        colour: const Value('amber'),
        dateCreated: Value(DateTime.now()),
        dateTimeModified: Value(DateTime.now()),
      ),
    );

    // 3 Manufacturing ingredients
    await db.into(db.recipeIngredients).insert(
      RecipeIngredientsCompanion.insert(
        recipeFk: kSampleManufacturingRecipePk,
        ingredientFk: flourPk,
        amountNeeded: 300.0,
      ),
    );

    await db.into(db.recipeIngredients).insert(
      RecipeIngredientsCompanion.insert(
        recipeFk: kSampleManufacturingRecipePk,
        ingredientFk: butterPk,
        amountNeeded: 200.0,
      ),
    );

    await db.into(db.recipeIngredients).insert(
      RecipeIngredientsCompanion.insert(
        recipeFk: kSampleManufacturingRecipePk,
        ingredientFk: sugarPk,
        amountNeeded: 100.0,
      ),
    );

    // 3 Manufacturing steps with timers
    final steps = [
      l10n.sample_manufacturing_step1,
      l10n.sample_manufacturing_step2,
      l10n.sample_manufacturing_step3,
    ];

    for (int i = 0; i < steps.length; i++) {
      await db.into(db.recipeSteps).insert(
        RecipeStepsCompanion.insert(
          recipeFk: kSampleManufacturingRecipePk,
          stepNumber: i + 1,
          instruction: steps[i],
        ),
      );
    }
  });

  return true;
}

/// Permanently dismisses / removes the temporary sample manufacturing recipe.
/// If the database was empty of user data (only contained the sample recipe and
/// sample raw materials), the 3 sample ingredients are also deleted.
/// If user data already exists in the database (other recipes or ingredients),
/// the ingredients are preserved.
Future<void> dismissSampleManufacturingRecipe(
  AppDatabase db, {
  SharedPreferences? prefs,
}) async {
  final p = prefs ?? await SharedPreferences.getInstance();
  await p.setBool(kSampleManufacturingRecipeDismissedKey, true);

  await db.transaction(() async {
    const samplePks = {kSampleFlourPk, kSampleButterPk, kSampleSugarPk};

    // Check if the database already has user data
    final otherRecipes = await (db.select(db.recipes)
          ..where((t) => t.recipePk.equals(kSampleManufacturingRecipePk).not()))
        .get();

    final allIngredients = await db.getAllIngredients();
    final otherIngredients = allIngredients
        .where((i) => !samplePks.contains(i.ingredientPk))
        .toList();

    final otherUsages = await (db.select(db.recipeIngredients)
          ..where((t) =>
              t.recipeFk.equals(kSampleManufacturingRecipePk).not() &
              t.ingredientFk.isIn(samplePks)))
        .get();

    final hasOtherData = otherRecipes.isNotEmpty ||
        otherIngredients.isNotEmpty ||
        otherUsages.isNotEmpty;

    await (db.delete(db.recipeSteps)
          ..where((t) => t.recipeFk.equals(kSampleManufacturingRecipePk)))
        .go();
    await (db.delete(db.recipeIngredients)
          ..where((t) => t.recipeFk.equals(kSampleManufacturingRecipePk)))
        .go();
    await (db.delete(db.recipes)
          ..where((t) => t.recipePk.equals(kSampleManufacturingRecipePk)))
        .go();

    if (!hasOtherData) {
      for (final ingPk in samplePks) {
        await (db.delete(db.ingredients)
              ..where((t) => t.ingredientPk.equals(ingPk)))
            .go();
      }
    }
  });
}

/// Converts the temporary sample recipe into a permanent user recipe with a new UUID.
Future<String> convertSampleRecipeToPermanent(
  AppDatabase db, {
  SharedPreferences? prefs,
  String? customName,
}) async {
  final p = prefs ?? await SharedPreferences.getInstance();
  await p.setBool(kSampleManufacturingRecipeDismissedKey, true);

  final detail = await db.getRecipeDetail(kSampleManufacturingRecipePk);
  final newPk = const Uuid().v4();

  await db.transaction(() async {
    await db.insertRecipe(
      RecipesCompanion(
        recipePk: Value(newPk),
        name: Value(customName ?? detail.recipe.name),
        description: Value(detail.recipe.description ?? ''),
        defaultYield: Value(detail.recipe.defaultYield),
        yieldName: Value(detail.recipe.yieldName),
        targetProfitMargin: Value(detail.recipe.targetProfitMargin),
        targetPricePerPortion: Value(detail.recipe.targetPricePerPortion),
        fixedOverheadCost: Value(detail.recipe.fixedOverheadCost),
        colour: Value(detail.recipe.colour),
        dateCreated: Value(DateTime.now()),
        dateTimeModified: Value(DateTime.now()),
      ),
    );

    for (final ing in detail.ingredients) {
      await db.into(db.recipeIngredients).insert(
        RecipeIngredientsCompanion.insert(
          recipeFk: newPk,
          ingredientFk: ing.ingredient.ingredientPk,
          amountNeeded: ing.entry.amountNeeded,
        ),
      );
    }

    for (final step in detail.steps) {
      await db.into(db.recipeSteps).insert(
        RecipeStepsCompanion.insert(
          recipeFk: newPk,
          stepNumber: step.stepNumber,
          instruction: step.instruction,
        ),
      );
    }

    // Remove the temporary sample recipe record
    await (db.delete(db.recipeSteps)
          ..where((t) => t.recipeFk.equals(kSampleManufacturingRecipePk)))
        .go();
    await (db.delete(db.recipeIngredients)
          ..where((t) => t.recipeFk.equals(kSampleManufacturingRecipePk)))
        .go();
    await (db.delete(db.recipes)
          ..where((t) => t.recipePk.equals(kSampleManufacturingRecipePk)))
        .go();
  });

  return newPk;
}
