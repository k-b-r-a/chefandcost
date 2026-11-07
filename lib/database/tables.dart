import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

const uuid = Uuid();

const int nameLimit = 250;
const int noteLimit = 500;
const int colourLimit = 50;

@DataClassName('Group')
class Groups extends Table {
  TextColumn get id => text().clientDefault(() => uuid.v4())();
  TextColumn get name => text().withLength(max: 50)();
  TextColumn get iconName => text().named('icon_name').nullable()();
  TextColumn get colorHex => text().named('color_hex').nullable()();
  BoolColumn get isActive =>
      boolean().named('is_active').withDefault(const Constant(true))();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').clientDefault(() => DateTime.now())();
  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').clientDefault(() => DateTime.now())();
  BoolColumn get isDeleted =>
      boolean().named('is_deleted').withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Category')
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(max: 50)();
  TextColumn get iconName => text().named('icon_name').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('Recipe')
class Recipes extends Table {
  TextColumn get recipePk => text().clientDefault(() => uuid.v4())();
  TextColumn get name => text().withLength(max: nameLimit)();
  TextColumn get description => text().withLength(max: noteLimit).nullable()();

  RealColumn get defaultYield => real()();
  TextColumn get yieldName => text().withLength(max: colourLimit)();

  RealColumn get targetProfitMargin =>
      real().withDefault(const Constant(0.0))();
  RealColumn get targetPricePerPortion =>
      real().withDefault(const Constant(0.0))();
  RealColumn get fixedOverheadCost => real().withDefault(const Constant(0.0))();

  TextColumn get colour => text().withLength(max: colourLimit).nullable()();

  DateTimeColumn get dateCreated =>
      dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get dateTimeModified =>
      dateTime().withDefault(Constant(DateTime.now())).nullable()();

  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  TextColumn get groupId =>
      text().named('group_id').nullable().references(Groups, #id)();
  TextColumn get category => text()
      .withLength(max: 50)
      .withDefault(const Constant('cocina'))
      .nullable()();

  @override
  Set<Column> get primaryKey => {recipePk};
}

@DataClassName('RecipeSpace')
class RecipeSpaces extends Table {
  TextColumn get recipeId => text()
      .named('recipe_id')
      .references(Recipes, #recipePk, onDelete: KeyAction.cascade)();
  TextColumn get spaceId => text()
      .named('space_id')
      .references(Groups, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get createdAt =>
      dateTime().named('created_at').withDefault(currentDateAndTime)();
  BoolColumn get isDeleted =>
      boolean().named('is_deleted').withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {recipeId, spaceId};
}

@DataClassName('Unit')
class Units extends Table {
  TextColumn get unitPk => text().clientDefault(() => uuid.v4())();
  TextColumn get name => text().withLength(max: nameLimit)();
  TextColumn get symbol => text().withLength(max: colourLimit)();

  // Category to group units (e.g., 'mass', 'volume', 'count')
  TextColumn get category => text().nullable()();
  // Factor to convert to the base unit of the category (e.g., 1000 for kg if g is base)
  RealColumn get factorToBase => real().withDefault(const Constant(1.0))();

  BoolColumn get isMutable => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {unitPk};
}

@DataClassName('Ingredient')
class Ingredients extends Table {
  TextColumn get ingredientPk => text().clientDefault(() => uuid.v4())();
  TextColumn get name => text().withLength(max: nameLimit)();

  RealColumn get cost => real()();
  RealColumn get quantityForCost => real()();
  TextColumn get unitFk => text().references(Units, #unitPk)();

  DateTimeColumn get dateCreated =>
      dateTime().clientDefault(() => DateTime.now())();
  DateTimeColumn get dateTimeModified =>
      dateTime().withDefault(Constant(DateTime.now())).nullable()();

  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  TextColumn get groupId =>
      text().named('group_id').nullable().references(Groups, #id)();
  TextColumn get category => text().withLength(max: 50).nullable()();

  RealColumn get currentStock => real()
      .named('current_stock')
      .withDefault(const Constant(0.0))
      .nullable()();
  RealColumn get minimumStock => real().named('minimum_stock').nullable()();
  TextColumn get stockUnit => text().named('stock_unit').nullable()();
  RealColumn get costPerStockUnit =>
      real().named('cost_per_stock_unit').nullable()();
  DateTimeColumn get lastStockUpdate =>
      dateTime().named('last_stock_update').nullable()();

  @override
  Set<Column> get primaryKey => {ingredientPk};
}

@DataClassName('RecipeIngredient')
class RecipeIngredients extends Table {
  TextColumn get recipeIngredientPk => text().clientDefault(() => uuid.v4())();

  TextColumn get recipeFk => text().references(Recipes, #recipePk)();
  TextColumn get ingredientFk =>
      text().references(Ingredients, #ingredientPk)();

  RealColumn get amountNeeded => real()();

  DateTimeColumn get dateTimeModified =>
      dateTime().withDefault(Constant(DateTime.now())).nullable()();

  @override
  Set<Column> get primaryKey => {recipeIngredientPk};
}

@DataClassName('RecipeStep')
class RecipeSteps extends Table {
  TextColumn get stepPk => text().clientDefault(() => uuid.v4())();
  TextColumn get recipeFk => text().references(Recipes, #recipePk)();

  IntColumn get stepNumber => integer()();
  TextColumn get instruction => text().withLength(max: noteLimit)();

  DateTimeColumn get dateTimeModified =>
      dateTime().withDefault(Constant(DateTime.now())).nullable()();

  @override
  Set<Column> get primaryKey => {stepPk};
}

@DataClassName('DeletedRecord')
class DeletedRecords extends Table {
  TextColumn get recordPk => text().named('record_pk')();
  TextColumn get entityType => text().named('entity_type')();
  DateTimeColumn get deletedAt => dateTime().named('deleted_at')();

  @override
  Set<Column> get primaryKey => {recordPk, entityType};
}

