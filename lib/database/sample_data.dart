import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'database.dart';
import 'initialize_default_database.dart';

/// Loads a rich sample dataset with realistic ingredients and recipes
/// into the database for testing and demonstration purposes.
Future<({int recipesAdded, int ingredientsAdded})> loadSampleData(
  AppDatabase db, {
  bool clearFirst = false,
}) async {
  const uuid = Uuid();

  // 1. Ensure all default culinary units exist
  await initializeDefaultDatabase(db);
  final units = await db.getAllUnits();
  final unitMap = {for (var u in units) u.symbol: u};

  // Helper to resolve unit PK by symbol or fallback
  String getUnitPk(String symbol) {
    if (unitMap.containsKey(symbol)) {
      return unitMap[symbol]!.unitPk;
    }
    return units.isNotEmpty ? units.first.unitPk : uuid.v4();
  }

  final gPk = getUnitPk('g');
  final mlPk = getUnitPk('ml');
  final pcsPk = getUnitPk('pcs');

  if (clearFirst) {
    await db.customStatement('DELETE FROM recipe_steps;');
    await db.customStatement('DELETE FROM recipe_ingredients;');
    await db.customStatement('DELETE FROM recipes;');
    await db.customStatement('DELETE FROM ingredients;');
  }

  // 2. Sample Ingredients definition
  final sampleIngredientsDef = [
    (name: 'Harina de Trigo 0000', cost: 1.20, qty: 1000.0, unitPk: gPk),
    (name: 'Azúcar Blanca Refinada', cost: 1.50, qty: 1000.0, unitPk: gPk),
    (name: 'Huevos Frescos', cost: 3.00, qty: 12.0, unitPk: pcsPk),
    (name: 'Mantequilla sin Sal', cost: 2.80, qty: 250.0, unitPk: gPk),
    (name: 'Leche Entera', cost: 1.10, qty: 1000.0, unitPk: mlPk),
    (name: 'Cacao Amargo en Polvo', cost: 3.50, qty: 250.0, unitPk: gPk),
    (name: 'Chocolate de Cobertura 70%', cost: 5.80, qty: 500.0, unitPk: gPk),
    (name: 'Polvo de Hornear', cost: 0.95, qty: 100.0, unitPk: gPk),
    (name: 'Esencia de Vainilla', cost: 2.10, qty: 100.0, unitPk: mlPk),
    (name: 'Sal Fina', cost: 0.60, qty: 1000.0, unitPk: gPk),
    (name: 'Crema de Leche (Nata)', cost: 2.40, qty: 500.0, unitPk: mlPk),
    (name: 'Levadura Seca Activa', cost: 1.25, qty: 50.0, unitPk: gPk),
    (name: 'Aceite de Girasol', cost: 2.00, qty: 1000.0, unitPk: mlPk),
    (name: 'Chispas de Chocolate Semiamargo', cost: 4.20, qty: 350.0, unitPk: gPk),
  ];

  final existingIngredients = await db.getAllIngredients();
  final existingIngMap = {
    for (var i in existingIngredients) i.name.toLowerCase().trim(): i
  };

  final Map<String, String> ingredientPkByName = {};
  int ingredientsAddedCount = 0;

  for (final ingDef in sampleIngredientsDef) {
    final key = ingDef.name.toLowerCase().trim();
    if (existingIngMap.containsKey(key)) {
      ingredientPkByName[ingDef.name] = existingIngMap[key]!.ingredientPk;
    } else {
      final newPk = uuid.v4();
      await db.insertIngredient(
        IngredientsCompanion(
          ingredientPk: Value(newPk),
          name: Value(ingDef.name),
          cost: Value(ingDef.cost),
          quantityForCost: Value(ingDef.qty),
          unitFk: Value(ingDef.unitPk),
          dateCreated: Value(DateTime.now()),
        ),
      );
      ingredientPkByName[ingDef.name] = newPk;
      ingredientsAddedCount++;
    }
  }

  // 3. Sample Recipes definition
  final existingRecipes = await db.getAllRecipes();
  final existingRecipeNames = {
    for (var r in existingRecipes) r.name.toLowerCase().trim()
  };

  int recipesAddedCount = 0;

  final sampleRecipes = [
    (
      name: 'Torta Húmeda de Chocolate',
      description: 'Deliciosa torta de chocolate esponjosa con ganache, ideal para cumpleaños y eventos.',
      yieldVal: 8.0,
      yieldName: 'porciones',
      margin: 45.0,
      price: 4.50,
      colour: 'amber',
      ingredients: [
        ('Harina de Trigo 0000', 250.0),
        ('Azúcar Blanca Refinada', 200.0),
        ('Huevos Frescos', 3.0),
        ('Cacao Amargo en Polvo', 60.0),
        ('Leche Entera', 150.0),
        ('Mantequilla sin Sal', 100.0),
        ('Polvo de Hornear', 10.0),
        ('Esencia de Vainilla', 10.0),
        ('Chocolate de Cobertura 70%', 150.0),
      ],
      steps: [
        'Precalentar el horno a 180°C y engrasar un molde redondo de 22 cm.',
        'Tamizar la harina de trigo junto con el cacao amargo y el polvo de hornear.',
        'Batir los huevos con el azúcar hasta que la mezcla blanquee y esté espumosa. Añadir la mantequilla derretida y la esencia de vainilla.',
        'Integrar los ingredientes secos alternando con la leche tibia con movimientos envolventes.',
        'Verter en el molde y hornear durante 35 minutos hasta que un palillo salga seco. [timer:Horneado a 180°C|2100]',
      ],
    ),
    (
      name: 'Galletas con Chispas de Chocolate',
      description: 'Galletas americanas clásicas, crujientes en los bordes y suaves en el centro.',
      yieldVal: 24.0,
      yieldName: 'galletas',
      margin: 50.0,
      price: 1.20,
      colour: 'deepOrange',
      ingredients: [
        ('Harina de Trigo 0000', 280.0),
        ('Azúcar Blanca Refinada', 150.0),
        ('Mantequilla sin Sal', 170.0),
        ('Huevos Frescos', 2.0),
        ('Chispas de Chocolate Semiamargo', 200.0),
        ('Esencia de Vainilla', 5.0),
        ('Polvo de Hornear', 5.0),
        ('Sal Fina', 3.0),
      ],
      steps: [
        'Batir la mantequilla pomada con el azúcar hasta lograr una textura cremosa.',
        'Añadir los huevos uno a uno junto con la vainilla, batiendo bien tras cada adición.',
        'Tamizar e incorporar la harina, polvo de hornear y sal. Agregar las chispas de chocolate de forma uniforme.',
        'Formar bolitas de masa de 35 g y colocarlas en una bandeja con papel manteca. Llevar al refrigerador por 15 minutos. [timer:Reposo en Frío|900]',
        'Hornear a 190°C durante 12 minutos hasta que los bordes adquieran un tono dorado. [timer:Horneado de Galletas|720]',
      ],
    ),
    (
      name: 'Pan Casero de Campo',
      description: 'Pan rústico tradicional de corteza crujiente y miga tierna, con fermentación lenta.',
      yieldVal: 2.0,
      yieldName: 'hogazas',
      margin: 60.0,
      price: 3.50,
      colour: 'brown',
      ingredients: [
        ('Harina de Trigo 0000', 500.0),
        ('Levadura Seca Activa', 7.0),
        ('Sal Fina', 10.0),
        ('Aceite de Girasol', 20.0),
      ],
      steps: [
        'Disolver la levadura en 320 ml de agua tibia y dejar activar durante 10 minutos. [timer:Activación de Levadura|600]',
        'Colocar la harina en forma de corona con la sal por fuera y los líquidos en el centro.',
        'Amasar enérgicamente de 10 a 12 minutos hasta lograr un bollo elástico y suave.',
        'Colocar en un recipiente aceitado, tapar con paño húmedo y dejar leudar por 60 minutos. [timer:Primer Leudado|3600]',
        'Dividir en 2 porciones, dar forma a las hogazas y dejar reposar 30 minutos más. [timer:Segundo Leudado|1800]',
        'Realizar cortes en la superficie y hornear a 220°C con vapor durante 35 minutos. [timer:Horneado con Vapor|2100]',
      ],
    ),
    (
      name: 'Crema Pastelera de Vainilla',
      description: 'Crema clásica de repostería francesa para rellenar facturas, tartas y medialunas.',
      yieldVal: 4.0,
      yieldName: 'porciones',
      margin: 45.0,
      price: 2.20,
      colour: 'yellow',
      ingredients: [
        ('Leche Entera', 500.0),
        ('Huevos Frescos', 4.0),
        ('Azúcar Blanca Refinada', 120.0),
        ('Harina de Trigo 0000', 45.0),
        ('Esencia de Vainilla', 10.0),
      ],
      steps: [
        'Calentar la leche con la mitad del azúcar y la esencia de vainilla hasta casi hervir.',
        'Batir las yemas de huevo con el resto del azúcar y la harina hasta disolver todo grumo.',
        'Templar vertiendo un tercio de la leche caliente sobre las yemas sin dejar de remover.',
        'Volver todo al fuego medio y cocinar batiendo constantemente hasta que espese y rompa hervor. [timer:Cocción a Fuego Medio|300]',
        'Retirar del fuego, tapar con film al contacto y dejar enfriar en la heladera durante 30 minutos. [timer:Enfriado en Heladera|1800]',
      ],
    ),
  ];

  for (final recipeDef in sampleRecipes) {
    if (existingRecipeNames.contains(recipeDef.name.toLowerCase().trim())) {
      continue;
    }

    final recipePk = uuid.v4();
    await db.transaction(() async {
      await db.insertRecipe(
        RecipesCompanion(
          recipePk: Value(recipePk),
          name: Value(recipeDef.name),
          description: Value(recipeDef.description),
          defaultYield: Value(recipeDef.yieldVal),
          yieldName: Value(recipeDef.yieldName),
          targetProfitMargin: Value(recipeDef.margin),
          targetPricePerPortion: Value(recipeDef.price),
          colour: Value(recipeDef.colour),
          dateCreated: Value(DateTime.now()),
          dateTimeModified: Value(DateTime.now()),
        ),
      );

      for (final ing in recipeDef.ingredients) {
        final ingPk = ingredientPkByName[ing.$1];
        if (ingPk != null) {
          await db.into(db.recipeIngredients).insert(
            RecipeIngredientsCompanion.insert(
              recipeFk: recipePk,
              ingredientFk: ingPk,
              amountNeeded: ing.$2,
            ),
          );
        }
      }

      for (int i = 0; i < recipeDef.steps.length; i++) {
        await db.into(db.recipeSteps).insert(
          RecipeStepsCompanion.insert(
            recipeFk: recipePk,
            stepNumber: i + 1,
            instruction: recipeDef.steps[i],
          ),
        );
      }
    });

    recipesAddedCount++;
  }

  return (
    recipesAdded: recipesAddedCount,
    ingredientsAdded: ingredientsAddedCount,
  );
}
