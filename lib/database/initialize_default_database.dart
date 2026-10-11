import 'package:drift/drift.dart';
import 'database.dart';

/// Initializes the database with default values and updates existing unit equivalences.
/// Called during the launch of the application.
Future<void> initializeDefaultDatabase(AppDatabase db) async {
  // 1. Deduplicate any duplicate units currently in the database (e.g. from cloud sync)
  final rawUnits = await db.getAllUnits();
  final unitsByName = <String, List<Unit>>{};
  for (final u in rawUnits) {
    unitsByName.putIfAbsent(u.name, () => []).add(u);
  }

  for (final entry in unitsByName.entries) {
    final list = entry.value;
    if (list.length > 1) {
      // Pick canonical: prefer immutable unit
      final canonical = list.firstWhere((u) => !u.isMutable, orElse: () => list.first);
      for (final dup in list) {
        if (dup.unitPk == canonical.unitPk) continue;
        // Re-point any ingredients using duplicate unit to canonical unit
        await (db.update(db.ingredients)..where((t) => t.unitFk.equals(dup.unitPk)))
            .write(IngredientsCompanion(unitFk: Value(canonical.unitPk)));
        // Delete the duplicate unit
        await (db.delete(db.units)..where((t) => t.unitPk.equals(dup.unitPk))).go();
      }
    }
  }

  // 2. Merge legacy unit_spoonfuls (cuch, 15ml) into standard unit_tablespoons (tbsp, 15ml)
  final cleanUnits = await db.getAllUnits();
  final tbspUnit = cleanUnits.where((u) => u.name == 'unit_tablespoons').firstOrNull;
  final spoonfulsUnit = cleanUnits.where((u) => u.name == 'unit_spoonfuls').firstOrNull;
  if (tbspUnit != null && spoonfulsUnit != null) {
    await (db.update(db.ingredients)..where((t) => t.unitFk.equals(spoonfulsUnit.unitPk)))
        .write(IngredientsCompanion(unitFk: Value(tbspUnit.unitPk)));
    await (db.delete(db.units)..where((t) => t.unitPk.equals(spoonfulsUnit.unitPk))).go();
  }

  final existingUnits = await db.getAllUnits();
  final existingMap = {for (var u in existingUnits) u.name: u};

  // Categories: 'mass', 'volume', 'count'
  // Base Mass: Grams (g) -> 1.0
  // Base Volume: Milliliters (ml) -> 1.0
  // Base Count: Pieces (pcs) -> 1.0
  //
  // Real Culinary Equivalences:
  // 1 Tablespoon (tbsp / cucharada) = 15.0 ml = 15.0 g (water)
  // 1 Teaspoon (tsp / cucharadita) = 5.0 ml = 5.0 g (water)
  // 1 Cup (cup / taza) = 240.0 ml
  // 1 Ounce (oz weight) = 28.3495 g
  // 1 Kilogram (kg) = 1000.0 g
  // 1 Liter (l) = 1000.0 ml

  final defaultUnits = [
    // --- MASS ---
    UnitsCompanion(
      unitPk: const Value('unit_def_grams'),
      name: const Value('unit_grams'),
      symbol: const Value('g'),
      category: const Value('mass'),
      factorToBase: const Value(1.0),
      isMutable: const Value(false),
    ),
    UnitsCompanion(
      unitPk: const Value('unit_def_kilograms'),
      name: const Value('unit_kilograms'),
      symbol: const Value('kg'),
      category: const Value('mass'),
      factorToBase: const Value(1000.0),
      isMutable: const Value(false),
    ),
    UnitsCompanion(
      unitPk: const Value('unit_def_ounces'),
      name: const Value('unit_ounces'),
      symbol: const Value('oz'),
      category: const Value('mass'),
      factorToBase: const Value(28.3495),
      isMutable: const Value(false),
    ),

    // --- VOLUME ---
    UnitsCompanion(
      unitPk: const Value('unit_def_milliliters'),
      name: const Value('unit_milliliters'),
      symbol: const Value('ml'),
      category: const Value('volume'),
      factorToBase: const Value(1.0),
      isMutable: const Value(false),
    ),
    UnitsCompanion(
      unitPk: const Value('unit_def_liters'),
      name: const Value('unit_liters'),
      symbol: const Value('l'),
      category: const Value('volume'),
      factorToBase: const Value(1000.0),
      isMutable: const Value(false),
    ),
    UnitsCompanion(
      unitPk: const Value('unit_def_cups'),
      name: const Value('unit_cups'),
      symbol: const Value('cup'),
      category: const Value('volume'),
      factorToBase: const Value(240.0), // Standard US Cup
      isMutable: const Value(false),
    ),
    UnitsCompanion(
      unitPk: const Value('unit_def_tablespoons'),
      name: const Value('unit_tablespoons'),
      symbol: const Value('tbsp'),
      category: const Value('volume'),
      factorToBase: const Value(15.0), // 1 tbsp = 15 ml = 15 g
      isMutable: const Value(false),
    ),
    UnitsCompanion(
      unitPk: const Value('unit_def_teaspoons'),
      name: const Value('unit_teaspoons'),
      symbol: const Value('tsp'),
      category: const Value('volume'),
      factorToBase: const Value(5.0), // 1 tsp = 5 ml = 5 g
      isMutable: const Value(false),
    ),

    // --- COUNT ---
    UnitsCompanion(
      unitPk: const Value('unit_def_pieces'),
      name: const Value('unit_pieces'),
      symbol: const Value('pcs'),
      category: const Value('count'),
      factorToBase: const Value(1.0),
      isMutable: const Value(false),
    ),
  ];

  for (final unit in defaultUnits) {
    final existing = existingMap[unit.name.value];
    if (existing == null) {
      await db.insertUnit(unit);
    } else if (existing.category != unit.category.value ||
        existing.factorToBase != unit.factorToBase.value) {
      await db.updateUnit(
        existing.copyWith(
          category: Value(unit.category.value),
          factorToBase: unit.factorToBase.value,
          symbol: unit.symbol.value,
        ),
      );
    }
  }
}
