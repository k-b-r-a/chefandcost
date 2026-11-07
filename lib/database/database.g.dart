// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $GroupsTable extends Groups with TableInfo<$GroupsTable, Group> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GroupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: () => uuid.v4(),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 50),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconNameMeta = const VerificationMeta(
    'iconName',
  );
  @override
  late final GeneratedColumn<String> iconName = GeneratedColumn<String>(
    'icon_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorHexMeta = const VerificationMeta(
    'colorHex',
  );
  @override
  late final GeneratedColumn<String> colorHex = GeneratedColumn<String>(
    'color_hex',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: () => DateTime.now(),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: () => DateTime.now(),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    iconName,
    colorHex,
    isActive,
    createdAt,
    updatedAt,
    isDeleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<Group> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('icon_name')) {
      context.handle(
        _iconNameMeta,
        iconName.isAcceptableOrUnknown(data['icon_name']!, _iconNameMeta),
      );
    }
    if (data.containsKey('color_hex')) {
      context.handle(
        _colorHexMeta,
        colorHex.isAcceptableOrUnknown(data['color_hex']!, _colorHexMeta),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Group map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Group(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      iconName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_name'],
      ),
      colorHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_hex'],
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
    );
  }

  @override
  $GroupsTable createAlias(String alias) {
    return $GroupsTable(attachedDatabase, alias);
  }
}

class Group extends DataClass implements Insertable<Group> {
  final String id;
  final String name;
  final String? iconName;
  final String? colorHex;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  const Group({
    required this.id,
    required this.name,
    this.iconName,
    this.colorHex,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.isDeleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || iconName != null) {
      map['icon_name'] = Variable<String>(iconName);
    }
    if (!nullToAbsent || colorHex != null) {
      map['color_hex'] = Variable<String>(colorHex);
    }
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['is_deleted'] = Variable<bool>(isDeleted);
    return map;
  }

  GroupsCompanion toCompanion(bool nullToAbsent) {
    return GroupsCompanion(
      id: Value(id),
      name: Value(name),
      iconName: iconName == null && nullToAbsent
          ? const Value.absent()
          : Value(iconName),
      colorHex: colorHex == null && nullToAbsent
          ? const Value.absent()
          : Value(colorHex),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      isDeleted: Value(isDeleted),
    );
  }

  factory Group.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Group(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      iconName: serializer.fromJson<String?>(json['iconName']),
      colorHex: serializer.fromJson<String?>(json['colorHex']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'iconName': serializer.toJson<String?>(iconName),
      'colorHex': serializer.toJson<String?>(colorHex),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
    };
  }

  Group copyWith({
    String? id,
    String? name,
    Value<String?> iconName = const Value.absent(),
    Value<String?> colorHex = const Value.absent(),
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
  }) => Group(
    id: id ?? this.id,
    name: name ?? this.name,
    iconName: iconName.present ? iconName.value : this.iconName,
    colorHex: colorHex.present ? colorHex.value : this.colorHex,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    isDeleted: isDeleted ?? this.isDeleted,
  );
  Group copyWithCompanion(GroupsCompanion data) {
    return Group(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      iconName: data.iconName.present ? data.iconName.value : this.iconName,
      colorHex: data.colorHex.present ? data.colorHex.value : this.colorHex,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Group(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('iconName: $iconName, ')
          ..write('colorHex: $colorHex, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    iconName,
    colorHex,
    isActive,
    createdAt,
    updatedAt,
    isDeleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Group &&
          other.id == this.id &&
          other.name == this.name &&
          other.iconName == this.iconName &&
          other.colorHex == this.colorHex &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.isDeleted == this.isDeleted);
}

class GroupsCompanion extends UpdateCompanion<Group> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> iconName;
  final Value<String?> colorHex;
  final Value<bool> isActive;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<bool> isDeleted;
  final Value<int> rowid;
  const GroupsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.iconName = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GroupsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.iconName = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Group> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? iconName,
    Expression<String>? colorHex,
    Expression<bool>? isActive,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<bool>? isDeleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (iconName != null) 'icon_name': iconName,
      if (colorHex != null) 'color_hex': colorHex,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GroupsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? iconName,
    Value<String?>? colorHex,
    Value<bool>? isActive,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<bool>? isDeleted,
    Value<int>? rowid,
  }) {
    return GroupsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      iconName: iconName ?? this.iconName,
      colorHex: colorHex ?? this.colorHex,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (iconName.present) {
      map['icon_name'] = Variable<String>(iconName.value);
    }
    if (colorHex.present) {
      map['color_hex'] = Variable<String>(colorHex.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GroupsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('iconName: $iconName, ')
          ..write('colorHex: $colorHex, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecipesTable extends Recipes with TableInfo<$RecipesTable, Recipe> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecipesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _recipePkMeta = const VerificationMeta(
    'recipePk',
  );
  @override
  late final GeneratedColumn<String> recipePk = GeneratedColumn<String>(
    'recipe_pk',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: () => uuid.v4(),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _defaultYieldMeta = const VerificationMeta(
    'defaultYield',
  );
  @override
  late final GeneratedColumn<double> defaultYield = GeneratedColumn<double>(
    'default_yield',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _yieldNameMeta = const VerificationMeta(
    'yieldName',
  );
  @override
  late final GeneratedColumn<String> yieldName = GeneratedColumn<String>(
    'yield_name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetProfitMarginMeta =
      const VerificationMeta('targetProfitMargin');
  @override
  late final GeneratedColumn<double> targetProfitMargin =
      GeneratedColumn<double>(
        'target_profit_margin',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(0.0),
      );
  static const VerificationMeta _targetPricePerPortionMeta =
      const VerificationMeta('targetPricePerPortion');
  @override
  late final GeneratedColumn<double> targetPricePerPortion =
      GeneratedColumn<double>(
        'target_price_per_portion',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(0.0),
      );
  static const VerificationMeta _fixedOverheadCostMeta = const VerificationMeta(
    'fixedOverheadCost',
  );
  @override
  late final GeneratedColumn<double> fixedOverheadCost =
      GeneratedColumn<double>(
        'fixed_overhead_cost',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
        defaultValue: const Constant(0.0),
      );
  static const VerificationMeta _colourMeta = const VerificationMeta('colour');
  @override
  late final GeneratedColumn<String> colour = GeneratedColumn<String>(
    'colour',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dateCreatedMeta = const VerificationMeta(
    'dateCreated',
  );
  @override
  late final GeneratedColumn<DateTime> dateCreated = GeneratedColumn<DateTime>(
    'date_created',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: () => DateTime.now(),
  );
  static const VerificationMeta _dateTimeModifiedMeta = const VerificationMeta(
    'dateTimeModified',
  );
  @override
  late final GeneratedColumn<DateTime> dateTimeModified =
      GeneratedColumn<DateTime>(
        'date_time_modified',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
        defaultValue: Constant(DateTime.now()),
      );
  static const VerificationMeta _archivedMeta = const VerificationMeta(
    'archived',
  );
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("archived" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES "groups" (id)',
    ),
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 50),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('cocina'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    recipePk,
    name,
    description,
    defaultYield,
    yieldName,
    targetProfitMargin,
    targetPricePerPortion,
    fixedOverheadCost,
    colour,
    dateCreated,
    dateTimeModified,
    archived,
    groupId,
    category,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recipes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Recipe> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('recipe_pk')) {
      context.handle(
        _recipePkMeta,
        recipePk.isAcceptableOrUnknown(data['recipe_pk']!, _recipePkMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('default_yield')) {
      context.handle(
        _defaultYieldMeta,
        defaultYield.isAcceptableOrUnknown(
          data['default_yield']!,
          _defaultYieldMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_defaultYieldMeta);
    }
    if (data.containsKey('yield_name')) {
      context.handle(
        _yieldNameMeta,
        yieldName.isAcceptableOrUnknown(data['yield_name']!, _yieldNameMeta),
      );
    } else if (isInserting) {
      context.missing(_yieldNameMeta);
    }
    if (data.containsKey('target_profit_margin')) {
      context.handle(
        _targetProfitMarginMeta,
        targetProfitMargin.isAcceptableOrUnknown(
          data['target_profit_margin']!,
          _targetProfitMarginMeta,
        ),
      );
    }
    if (data.containsKey('target_price_per_portion')) {
      context.handle(
        _targetPricePerPortionMeta,
        targetPricePerPortion.isAcceptableOrUnknown(
          data['target_price_per_portion']!,
          _targetPricePerPortionMeta,
        ),
      );
    }
    if (data.containsKey('fixed_overhead_cost')) {
      context.handle(
        _fixedOverheadCostMeta,
        fixedOverheadCost.isAcceptableOrUnknown(
          data['fixed_overhead_cost']!,
          _fixedOverheadCostMeta,
        ),
      );
    }
    if (data.containsKey('colour')) {
      context.handle(
        _colourMeta,
        colour.isAcceptableOrUnknown(data['colour']!, _colourMeta),
      );
    }
    if (data.containsKey('date_created')) {
      context.handle(
        _dateCreatedMeta,
        dateCreated.isAcceptableOrUnknown(
          data['date_created']!,
          _dateCreatedMeta,
        ),
      );
    }
    if (data.containsKey('date_time_modified')) {
      context.handle(
        _dateTimeModifiedMeta,
        dateTimeModified.isAcceptableOrUnknown(
          data['date_time_modified']!,
          _dateTimeModifiedMeta,
        ),
      );
    }
    if (data.containsKey('archived')) {
      context.handle(
        _archivedMeta,
        archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta),
      );
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {recipePk};
  @override
  Recipe map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Recipe(
      recipePk: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recipe_pk'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      defaultYield: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}default_yield'],
      )!,
      yieldName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}yield_name'],
      )!,
      targetProfitMargin: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}target_profit_margin'],
      )!,
      targetPricePerPortion: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}target_price_per_portion'],
      )!,
      fixedOverheadCost: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}fixed_overhead_cost'],
      )!,
      colour: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}colour'],
      ),
      dateCreated: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date_created'],
      )!,
      dateTimeModified: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date_time_modified'],
      ),
      archived: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}archived'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      ),
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
    );
  }

  @override
  $RecipesTable createAlias(String alias) {
    return $RecipesTable(attachedDatabase, alias);
  }
}

class Recipe extends DataClass implements Insertable<Recipe> {
  final String recipePk;
  final String name;
  final String? description;
  final double defaultYield;
  final String yieldName;
  final double targetProfitMargin;
  final double targetPricePerPortion;
  final double fixedOverheadCost;
  final String? colour;
  final DateTime dateCreated;
  final DateTime? dateTimeModified;
  final bool archived;
  final String? groupId;
  final String? category;
  const Recipe({
    required this.recipePk,
    required this.name,
    this.description,
    required this.defaultYield,
    required this.yieldName,
    required this.targetProfitMargin,
    required this.targetPricePerPortion,
    required this.fixedOverheadCost,
    this.colour,
    required this.dateCreated,
    this.dateTimeModified,
    required this.archived,
    this.groupId,
    this.category,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['recipe_pk'] = Variable<String>(recipePk);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['default_yield'] = Variable<double>(defaultYield);
    map['yield_name'] = Variable<String>(yieldName);
    map['target_profit_margin'] = Variable<double>(targetProfitMargin);
    map['target_price_per_portion'] = Variable<double>(targetPricePerPortion);
    map['fixed_overhead_cost'] = Variable<double>(fixedOverheadCost);
    if (!nullToAbsent || colour != null) {
      map['colour'] = Variable<String>(colour);
    }
    map['date_created'] = Variable<DateTime>(dateCreated);
    if (!nullToAbsent || dateTimeModified != null) {
      map['date_time_modified'] = Variable<DateTime>(dateTimeModified);
    }
    map['archived'] = Variable<bool>(archived);
    if (!nullToAbsent || groupId != null) {
      map['group_id'] = Variable<String>(groupId);
    }
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    return map;
  }

  RecipesCompanion toCompanion(bool nullToAbsent) {
    return RecipesCompanion(
      recipePk: Value(recipePk),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      defaultYield: Value(defaultYield),
      yieldName: Value(yieldName),
      targetProfitMargin: Value(targetProfitMargin),
      targetPricePerPortion: Value(targetPricePerPortion),
      fixedOverheadCost: Value(fixedOverheadCost),
      colour: colour == null && nullToAbsent
          ? const Value.absent()
          : Value(colour),
      dateCreated: Value(dateCreated),
      dateTimeModified: dateTimeModified == null && nullToAbsent
          ? const Value.absent()
          : Value(dateTimeModified),
      archived: Value(archived),
      groupId: groupId == null && nullToAbsent
          ? const Value.absent()
          : Value(groupId),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
    );
  }

  factory Recipe.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Recipe(
      recipePk: serializer.fromJson<String>(json['recipePk']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      defaultYield: serializer.fromJson<double>(json['defaultYield']),
      yieldName: serializer.fromJson<String>(json['yieldName']),
      targetProfitMargin: serializer.fromJson<double>(
        json['targetProfitMargin'],
      ),
      targetPricePerPortion: serializer.fromJson<double>(
        json['targetPricePerPortion'],
      ),
      fixedOverheadCost: serializer.fromJson<double>(json['fixedOverheadCost']),
      colour: serializer.fromJson<String?>(json['colour']),
      dateCreated: serializer.fromJson<DateTime>(json['dateCreated']),
      dateTimeModified: serializer.fromJson<DateTime?>(
        json['dateTimeModified'],
      ),
      archived: serializer.fromJson<bool>(json['archived']),
      groupId: serializer.fromJson<String?>(json['groupId']),
      category: serializer.fromJson<String?>(json['category']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'recipePk': serializer.toJson<String>(recipePk),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'defaultYield': serializer.toJson<double>(defaultYield),
      'yieldName': serializer.toJson<String>(yieldName),
      'targetProfitMargin': serializer.toJson<double>(targetProfitMargin),
      'targetPricePerPortion': serializer.toJson<double>(targetPricePerPortion),
      'fixedOverheadCost': serializer.toJson<double>(fixedOverheadCost),
      'colour': serializer.toJson<String?>(colour),
      'dateCreated': serializer.toJson<DateTime>(dateCreated),
      'dateTimeModified': serializer.toJson<DateTime?>(dateTimeModified),
      'archived': serializer.toJson<bool>(archived),
      'groupId': serializer.toJson<String?>(groupId),
      'category': serializer.toJson<String?>(category),
    };
  }

  Recipe copyWith({
    String? recipePk,
    String? name,
    Value<String?> description = const Value.absent(),
    double? defaultYield,
    String? yieldName,
    double? targetProfitMargin,
    double? targetPricePerPortion,
    double? fixedOverheadCost,
    Value<String?> colour = const Value.absent(),
    DateTime? dateCreated,
    Value<DateTime?> dateTimeModified = const Value.absent(),
    bool? archived,
    Value<String?> groupId = const Value.absent(),
    Value<String?> category = const Value.absent(),
  }) => Recipe(
    recipePk: recipePk ?? this.recipePk,
    name: name ?? this.name,
    description: description.present ? description.value : this.description,
    defaultYield: defaultYield ?? this.defaultYield,
    yieldName: yieldName ?? this.yieldName,
    targetProfitMargin: targetProfitMargin ?? this.targetProfitMargin,
    targetPricePerPortion: targetPricePerPortion ?? this.targetPricePerPortion,
    fixedOverheadCost: fixedOverheadCost ?? this.fixedOverheadCost,
    colour: colour.present ? colour.value : this.colour,
    dateCreated: dateCreated ?? this.dateCreated,
    dateTimeModified: dateTimeModified.present
        ? dateTimeModified.value
        : this.dateTimeModified,
    archived: archived ?? this.archived,
    groupId: groupId.present ? groupId.value : this.groupId,
    category: category.present ? category.value : this.category,
  );
  Recipe copyWithCompanion(RecipesCompanion data) {
    return Recipe(
      recipePk: data.recipePk.present ? data.recipePk.value : this.recipePk,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      defaultYield: data.defaultYield.present
          ? data.defaultYield.value
          : this.defaultYield,
      yieldName: data.yieldName.present ? data.yieldName.value : this.yieldName,
      targetProfitMargin: data.targetProfitMargin.present
          ? data.targetProfitMargin.value
          : this.targetProfitMargin,
      targetPricePerPortion: data.targetPricePerPortion.present
          ? data.targetPricePerPortion.value
          : this.targetPricePerPortion,
      fixedOverheadCost: data.fixedOverheadCost.present
          ? data.fixedOverheadCost.value
          : this.fixedOverheadCost,
      colour: data.colour.present ? data.colour.value : this.colour,
      dateCreated: data.dateCreated.present
          ? data.dateCreated.value
          : this.dateCreated,
      dateTimeModified: data.dateTimeModified.present
          ? data.dateTimeModified.value
          : this.dateTimeModified,
      archived: data.archived.present ? data.archived.value : this.archived,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      category: data.category.present ? data.category.value : this.category,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Recipe(')
          ..write('recipePk: $recipePk, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('defaultYield: $defaultYield, ')
          ..write('yieldName: $yieldName, ')
          ..write('targetProfitMargin: $targetProfitMargin, ')
          ..write('targetPricePerPortion: $targetPricePerPortion, ')
          ..write('fixedOverheadCost: $fixedOverheadCost, ')
          ..write('colour: $colour, ')
          ..write('dateCreated: $dateCreated, ')
          ..write('dateTimeModified: $dateTimeModified, ')
          ..write('archived: $archived, ')
          ..write('groupId: $groupId, ')
          ..write('category: $category')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    recipePk,
    name,
    description,
    defaultYield,
    yieldName,
    targetProfitMargin,
    targetPricePerPortion,
    fixedOverheadCost,
    colour,
    dateCreated,
    dateTimeModified,
    archived,
    groupId,
    category,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Recipe &&
          other.recipePk == this.recipePk &&
          other.name == this.name &&
          other.description == this.description &&
          other.defaultYield == this.defaultYield &&
          other.yieldName == this.yieldName &&
          other.targetProfitMargin == this.targetProfitMargin &&
          other.targetPricePerPortion == this.targetPricePerPortion &&
          other.fixedOverheadCost == this.fixedOverheadCost &&
          other.colour == this.colour &&
          other.dateCreated == this.dateCreated &&
          other.dateTimeModified == this.dateTimeModified &&
          other.archived == this.archived &&
          other.groupId == this.groupId &&
          other.category == this.category);
}

class RecipesCompanion extends UpdateCompanion<Recipe> {
  final Value<String> recipePk;
  final Value<String> name;
  final Value<String?> description;
  final Value<double> defaultYield;
  final Value<String> yieldName;
  final Value<double> targetProfitMargin;
  final Value<double> targetPricePerPortion;
  final Value<double> fixedOverheadCost;
  final Value<String?> colour;
  final Value<DateTime> dateCreated;
  final Value<DateTime?> dateTimeModified;
  final Value<bool> archived;
  final Value<String?> groupId;
  final Value<String?> category;
  final Value<int> rowid;
  const RecipesCompanion({
    this.recipePk = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.defaultYield = const Value.absent(),
    this.yieldName = const Value.absent(),
    this.targetProfitMargin = const Value.absent(),
    this.targetPricePerPortion = const Value.absent(),
    this.fixedOverheadCost = const Value.absent(),
    this.colour = const Value.absent(),
    this.dateCreated = const Value.absent(),
    this.dateTimeModified = const Value.absent(),
    this.archived = const Value.absent(),
    this.groupId = const Value.absent(),
    this.category = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecipesCompanion.insert({
    this.recipePk = const Value.absent(),
    required String name,
    this.description = const Value.absent(),
    required double defaultYield,
    required String yieldName,
    this.targetProfitMargin = const Value.absent(),
    this.targetPricePerPortion = const Value.absent(),
    this.fixedOverheadCost = const Value.absent(),
    this.colour = const Value.absent(),
    this.dateCreated = const Value.absent(),
    this.dateTimeModified = const Value.absent(),
    this.archived = const Value.absent(),
    this.groupId = const Value.absent(),
    this.category = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : name = Value(name),
       defaultYield = Value(defaultYield),
       yieldName = Value(yieldName);
  static Insertable<Recipe> custom({
    Expression<String>? recipePk,
    Expression<String>? name,
    Expression<String>? description,
    Expression<double>? defaultYield,
    Expression<String>? yieldName,
    Expression<double>? targetProfitMargin,
    Expression<double>? targetPricePerPortion,
    Expression<double>? fixedOverheadCost,
    Expression<String>? colour,
    Expression<DateTime>? dateCreated,
    Expression<DateTime>? dateTimeModified,
    Expression<bool>? archived,
    Expression<String>? groupId,
    Expression<String>? category,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (recipePk != null) 'recipe_pk': recipePk,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (defaultYield != null) 'default_yield': defaultYield,
      if (yieldName != null) 'yield_name': yieldName,
      if (targetProfitMargin != null)
        'target_profit_margin': targetProfitMargin,
      if (targetPricePerPortion != null)
        'target_price_per_portion': targetPricePerPortion,
      if (fixedOverheadCost != null) 'fixed_overhead_cost': fixedOverheadCost,
      if (colour != null) 'colour': colour,
      if (dateCreated != null) 'date_created': dateCreated,
      if (dateTimeModified != null) 'date_time_modified': dateTimeModified,
      if (archived != null) 'archived': archived,
      if (groupId != null) 'group_id': groupId,
      if (category != null) 'category': category,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecipesCompanion copyWith({
    Value<String>? recipePk,
    Value<String>? name,
    Value<String?>? description,
    Value<double>? defaultYield,
    Value<String>? yieldName,
    Value<double>? targetProfitMargin,
    Value<double>? targetPricePerPortion,
    Value<double>? fixedOverheadCost,
    Value<String?>? colour,
    Value<DateTime>? dateCreated,
    Value<DateTime?>? dateTimeModified,
    Value<bool>? archived,
    Value<String?>? groupId,
    Value<String?>? category,
    Value<int>? rowid,
  }) {
    return RecipesCompanion(
      recipePk: recipePk ?? this.recipePk,
      name: name ?? this.name,
      description: description ?? this.description,
      defaultYield: defaultYield ?? this.defaultYield,
      yieldName: yieldName ?? this.yieldName,
      targetProfitMargin: targetProfitMargin ?? this.targetProfitMargin,
      targetPricePerPortion:
          targetPricePerPortion ?? this.targetPricePerPortion,
      fixedOverheadCost: fixedOverheadCost ?? this.fixedOverheadCost,
      colour: colour ?? this.colour,
      dateCreated: dateCreated ?? this.dateCreated,
      dateTimeModified: dateTimeModified ?? this.dateTimeModified,
      archived: archived ?? this.archived,
      groupId: groupId ?? this.groupId,
      category: category ?? this.category,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (recipePk.present) {
      map['recipe_pk'] = Variable<String>(recipePk.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (defaultYield.present) {
      map['default_yield'] = Variable<double>(defaultYield.value);
    }
    if (yieldName.present) {
      map['yield_name'] = Variable<String>(yieldName.value);
    }
    if (targetProfitMargin.present) {
      map['target_profit_margin'] = Variable<double>(targetProfitMargin.value);
    }
    if (targetPricePerPortion.present) {
      map['target_price_per_portion'] = Variable<double>(
        targetPricePerPortion.value,
      );
    }
    if (fixedOverheadCost.present) {
      map['fixed_overhead_cost'] = Variable<double>(fixedOverheadCost.value);
    }
    if (colour.present) {
      map['colour'] = Variable<String>(colour.value);
    }
    if (dateCreated.present) {
      map['date_created'] = Variable<DateTime>(dateCreated.value);
    }
    if (dateTimeModified.present) {
      map['date_time_modified'] = Variable<DateTime>(dateTimeModified.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecipesCompanion(')
          ..write('recipePk: $recipePk, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('defaultYield: $defaultYield, ')
          ..write('yieldName: $yieldName, ')
          ..write('targetProfitMargin: $targetProfitMargin, ')
          ..write('targetPricePerPortion: $targetPricePerPortion, ')
          ..write('fixedOverheadCost: $fixedOverheadCost, ')
          ..write('colour: $colour, ')
          ..write('dateCreated: $dateCreated, ')
          ..write('dateTimeModified: $dateTimeModified, ')
          ..write('archived: $archived, ')
          ..write('groupId: $groupId, ')
          ..write('category: $category, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UnitsTable extends Units with TableInfo<$UnitsTable, Unit> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UnitsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _unitPkMeta = const VerificationMeta('unitPk');
  @override
  late final GeneratedColumn<String> unitPk = GeneratedColumn<String>(
    'unit_pk',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: () => uuid.v4(),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
    'symbol',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _factorToBaseMeta = const VerificationMeta(
    'factorToBase',
  );
  @override
  late final GeneratedColumn<double> factorToBase = GeneratedColumn<double>(
    'factor_to_base',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1.0),
  );
  static const VerificationMeta _isMutableMeta = const VerificationMeta(
    'isMutable',
  );
  @override
  late final GeneratedColumn<bool> isMutable = GeneratedColumn<bool>(
    'is_mutable',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_mutable" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    unitPk,
    name,
    symbol,
    category,
    factorToBase,
    isMutable,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'units';
  @override
  VerificationContext validateIntegrity(
    Insertable<Unit> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('unit_pk')) {
      context.handle(
        _unitPkMeta,
        unitPk.isAcceptableOrUnknown(data['unit_pk']!, _unitPkMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('symbol')) {
      context.handle(
        _symbolMeta,
        symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta),
      );
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('factor_to_base')) {
      context.handle(
        _factorToBaseMeta,
        factorToBase.isAcceptableOrUnknown(
          data['factor_to_base']!,
          _factorToBaseMeta,
        ),
      );
    }
    if (data.containsKey('is_mutable')) {
      context.handle(
        _isMutableMeta,
        isMutable.isAcceptableOrUnknown(data['is_mutable']!, _isMutableMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {unitPk};
  @override
  Unit map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Unit(
      unitPk: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit_pk'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      symbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
      factorToBase: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}factor_to_base'],
      )!,
      isMutable: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_mutable'],
      )!,
    );
  }

  @override
  $UnitsTable createAlias(String alias) {
    return $UnitsTable(attachedDatabase, alias);
  }
}

class Unit extends DataClass implements Insertable<Unit> {
  final String unitPk;
  final String name;
  final String symbol;
  final String? category;
  final double factorToBase;
  final bool isMutable;
  const Unit({
    required this.unitPk,
    required this.name,
    required this.symbol,
    this.category,
    required this.factorToBase,
    required this.isMutable,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['unit_pk'] = Variable<String>(unitPk);
    map['name'] = Variable<String>(name);
    map['symbol'] = Variable<String>(symbol);
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    map['factor_to_base'] = Variable<double>(factorToBase);
    map['is_mutable'] = Variable<bool>(isMutable);
    return map;
  }

  UnitsCompanion toCompanion(bool nullToAbsent) {
    return UnitsCompanion(
      unitPk: Value(unitPk),
      name: Value(name),
      symbol: Value(symbol),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      factorToBase: Value(factorToBase),
      isMutable: Value(isMutable),
    );
  }

  factory Unit.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Unit(
      unitPk: serializer.fromJson<String>(json['unitPk']),
      name: serializer.fromJson<String>(json['name']),
      symbol: serializer.fromJson<String>(json['symbol']),
      category: serializer.fromJson<String?>(json['category']),
      factorToBase: serializer.fromJson<double>(json['factorToBase']),
      isMutable: serializer.fromJson<bool>(json['isMutable']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'unitPk': serializer.toJson<String>(unitPk),
      'name': serializer.toJson<String>(name),
      'symbol': serializer.toJson<String>(symbol),
      'category': serializer.toJson<String?>(category),
      'factorToBase': serializer.toJson<double>(factorToBase),
      'isMutable': serializer.toJson<bool>(isMutable),
    };
  }

  Unit copyWith({
    String? unitPk,
    String? name,
    String? symbol,
    Value<String?> category = const Value.absent(),
    double? factorToBase,
    bool? isMutable,
  }) => Unit(
    unitPk: unitPk ?? this.unitPk,
    name: name ?? this.name,
    symbol: symbol ?? this.symbol,
    category: category.present ? category.value : this.category,
    factorToBase: factorToBase ?? this.factorToBase,
    isMutable: isMutable ?? this.isMutable,
  );
  Unit copyWithCompanion(UnitsCompanion data) {
    return Unit(
      unitPk: data.unitPk.present ? data.unitPk.value : this.unitPk,
      name: data.name.present ? data.name.value : this.name,
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      category: data.category.present ? data.category.value : this.category,
      factorToBase: data.factorToBase.present
          ? data.factorToBase.value
          : this.factorToBase,
      isMutable: data.isMutable.present ? data.isMutable.value : this.isMutable,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Unit(')
          ..write('unitPk: $unitPk, ')
          ..write('name: $name, ')
          ..write('symbol: $symbol, ')
          ..write('category: $category, ')
          ..write('factorToBase: $factorToBase, ')
          ..write('isMutable: $isMutable')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(unitPk, name, symbol, category, factorToBase, isMutable);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Unit &&
          other.unitPk == this.unitPk &&
          other.name == this.name &&
          other.symbol == this.symbol &&
          other.category == this.category &&
          other.factorToBase == this.factorToBase &&
          other.isMutable == this.isMutable);
}

class UnitsCompanion extends UpdateCompanion<Unit> {
  final Value<String> unitPk;
  final Value<String> name;
  final Value<String> symbol;
  final Value<String?> category;
  final Value<double> factorToBase;
  final Value<bool> isMutable;
  final Value<int> rowid;
  const UnitsCompanion({
    this.unitPk = const Value.absent(),
    this.name = const Value.absent(),
    this.symbol = const Value.absent(),
    this.category = const Value.absent(),
    this.factorToBase = const Value.absent(),
    this.isMutable = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UnitsCompanion.insert({
    this.unitPk = const Value.absent(),
    required String name,
    required String symbol,
    this.category = const Value.absent(),
    this.factorToBase = const Value.absent(),
    this.isMutable = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : name = Value(name),
       symbol = Value(symbol);
  static Insertable<Unit> custom({
    Expression<String>? unitPk,
    Expression<String>? name,
    Expression<String>? symbol,
    Expression<String>? category,
    Expression<double>? factorToBase,
    Expression<bool>? isMutable,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (unitPk != null) 'unit_pk': unitPk,
      if (name != null) 'name': name,
      if (symbol != null) 'symbol': symbol,
      if (category != null) 'category': category,
      if (factorToBase != null) 'factor_to_base': factorToBase,
      if (isMutable != null) 'is_mutable': isMutable,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UnitsCompanion copyWith({
    Value<String>? unitPk,
    Value<String>? name,
    Value<String>? symbol,
    Value<String?>? category,
    Value<double>? factorToBase,
    Value<bool>? isMutable,
    Value<int>? rowid,
  }) {
    return UnitsCompanion(
      unitPk: unitPk ?? this.unitPk,
      name: name ?? this.name,
      symbol: symbol ?? this.symbol,
      category: category ?? this.category,
      factorToBase: factorToBase ?? this.factorToBase,
      isMutable: isMutable ?? this.isMutable,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (unitPk.present) {
      map['unit_pk'] = Variable<String>(unitPk.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (factorToBase.present) {
      map['factor_to_base'] = Variable<double>(factorToBase.value);
    }
    if (isMutable.present) {
      map['is_mutable'] = Variable<bool>(isMutable.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UnitsCompanion(')
          ..write('unitPk: $unitPk, ')
          ..write('name: $name, ')
          ..write('symbol: $symbol, ')
          ..write('category: $category, ')
          ..write('factorToBase: $factorToBase, ')
          ..write('isMutable: $isMutable, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $IngredientsTable extends Ingredients
    with TableInfo<$IngredientsTable, Ingredient> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $IngredientsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _ingredientPkMeta = const VerificationMeta(
    'ingredientPk',
  );
  @override
  late final GeneratedColumn<String> ingredientPk = GeneratedColumn<String>(
    'ingredient_pk',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: () => uuid.v4(),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _costMeta = const VerificationMeta('cost');
  @override
  late final GeneratedColumn<double> cost = GeneratedColumn<double>(
    'cost',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityForCostMeta = const VerificationMeta(
    'quantityForCost',
  );
  @override
  late final GeneratedColumn<double> quantityForCost = GeneratedColumn<double>(
    'quantity_for_cost',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitFkMeta = const VerificationMeta('unitFk');
  @override
  late final GeneratedColumn<String> unitFk = GeneratedColumn<String>(
    'unit_fk',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES units (unit_pk)',
    ),
  );
  static const VerificationMeta _dateCreatedMeta = const VerificationMeta(
    'dateCreated',
  );
  @override
  late final GeneratedColumn<DateTime> dateCreated = GeneratedColumn<DateTime>(
    'date_created',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    clientDefault: () => DateTime.now(),
  );
  static const VerificationMeta _dateTimeModifiedMeta = const VerificationMeta(
    'dateTimeModified',
  );
  @override
  late final GeneratedColumn<DateTime> dateTimeModified =
      GeneratedColumn<DateTime>(
        'date_time_modified',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
        defaultValue: Constant(DateTime.now()),
      );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES "groups" (id)',
    ),
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    true,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 50),
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currentStockMeta = const VerificationMeta(
    'currentStock',
  );
  @override
  late final GeneratedColumn<double> currentStock = GeneratedColumn<double>(
    'current_stock',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _minimumStockMeta = const VerificationMeta(
    'minimumStock',
  );
  @override
  late final GeneratedColumn<double> minimumStock = GeneratedColumn<double>(
    'minimum_stock',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stockUnitMeta = const VerificationMeta(
    'stockUnit',
  );
  @override
  late final GeneratedColumn<String> stockUnit = GeneratedColumn<String>(
    'stock_unit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _costPerStockUnitMeta = const VerificationMeta(
    'costPerStockUnit',
  );
  @override
  late final GeneratedColumn<double> costPerStockUnit = GeneratedColumn<double>(
    'cost_per_stock_unit',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastStockUpdateMeta = const VerificationMeta(
    'lastStockUpdate',
  );
  @override
  late final GeneratedColumn<DateTime> lastStockUpdate =
      GeneratedColumn<DateTime>(
        'last_stock_update',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    ingredientPk,
    name,
    cost,
    quantityForCost,
    unitFk,
    dateCreated,
    dateTimeModified,
    isDeleted,
    deletedAt,
    groupId,
    category,
    currentStock,
    minimumStock,
    stockUnit,
    costPerStockUnit,
    lastStockUpdate,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ingredients';
  @override
  VerificationContext validateIntegrity(
    Insertable<Ingredient> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('ingredient_pk')) {
      context.handle(
        _ingredientPkMeta,
        ingredientPk.isAcceptableOrUnknown(
          data['ingredient_pk']!,
          _ingredientPkMeta,
        ),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('cost')) {
      context.handle(
        _costMeta,
        cost.isAcceptableOrUnknown(data['cost']!, _costMeta),
      );
    } else if (isInserting) {
      context.missing(_costMeta);
    }
    if (data.containsKey('quantity_for_cost')) {
      context.handle(
        _quantityForCostMeta,
        quantityForCost.isAcceptableOrUnknown(
          data['quantity_for_cost']!,
          _quantityForCostMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_quantityForCostMeta);
    }
    if (data.containsKey('unit_fk')) {
      context.handle(
        _unitFkMeta,
        unitFk.isAcceptableOrUnknown(data['unit_fk']!, _unitFkMeta),
      );
    } else if (isInserting) {
      context.missing(_unitFkMeta);
    }
    if (data.containsKey('date_created')) {
      context.handle(
        _dateCreatedMeta,
        dateCreated.isAcceptableOrUnknown(
          data['date_created']!,
          _dateCreatedMeta,
        ),
      );
    }
    if (data.containsKey('date_time_modified')) {
      context.handle(
        _dateTimeModifiedMeta,
        dateTimeModified.isAcceptableOrUnknown(
          data['date_time_modified']!,
          _dateTimeModifiedMeta,
        ),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('current_stock')) {
      context.handle(
        _currentStockMeta,
        currentStock.isAcceptableOrUnknown(
          data['current_stock']!,
          _currentStockMeta,
        ),
      );
    }
    if (data.containsKey('minimum_stock')) {
      context.handle(
        _minimumStockMeta,
        minimumStock.isAcceptableOrUnknown(
          data['minimum_stock']!,
          _minimumStockMeta,
        ),
      );
    }
    if (data.containsKey('stock_unit')) {
      context.handle(
        _stockUnitMeta,
        stockUnit.isAcceptableOrUnknown(data['stock_unit']!, _stockUnitMeta),
      );
    }
    if (data.containsKey('cost_per_stock_unit')) {
      context.handle(
        _costPerStockUnitMeta,
        costPerStockUnit.isAcceptableOrUnknown(
          data['cost_per_stock_unit']!,
          _costPerStockUnitMeta,
        ),
      );
    }
    if (data.containsKey('last_stock_update')) {
      context.handle(
        _lastStockUpdateMeta,
        lastStockUpdate.isAcceptableOrUnknown(
          data['last_stock_update']!,
          _lastStockUpdateMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ingredientPk};
  @override
  Ingredient map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Ingredient(
      ingredientPk: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ingredient_pk'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      cost: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}cost'],
      )!,
      quantityForCost: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quantity_for_cost'],
      )!,
      unitFk: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit_fk'],
      )!,
      dateCreated: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date_created'],
      )!,
      dateTimeModified: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date_time_modified'],
      ),
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      ),
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
      currentStock: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}current_stock'],
      ),
      minimumStock: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}minimum_stock'],
      ),
      stockUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stock_unit'],
      ),
      costPerStockUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}cost_per_stock_unit'],
      ),
      lastStockUpdate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_stock_update'],
      ),
    );
  }

  @override
  $IngredientsTable createAlias(String alias) {
    return $IngredientsTable(attachedDatabase, alias);
  }
}

class Ingredient extends DataClass implements Insertable<Ingredient> {
  final String ingredientPk;
  final String name;
  final double cost;
  final double quantityForCost;
  final String unitFk;
  final DateTime dateCreated;
  final DateTime? dateTimeModified;
  final bool isDeleted;
  final DateTime? deletedAt;
  final String? groupId;
  final String? category;
  final double? currentStock;
  final double? minimumStock;
  final String? stockUnit;
  final double? costPerStockUnit;
  final DateTime? lastStockUpdate;
  const Ingredient({
    required this.ingredientPk,
    required this.name,
    required this.cost,
    required this.quantityForCost,
    required this.unitFk,
    required this.dateCreated,
    this.dateTimeModified,
    required this.isDeleted,
    this.deletedAt,
    this.groupId,
    this.category,
    this.currentStock,
    this.minimumStock,
    this.stockUnit,
    this.costPerStockUnit,
    this.lastStockUpdate,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['ingredient_pk'] = Variable<String>(ingredientPk);
    map['name'] = Variable<String>(name);
    map['cost'] = Variable<double>(cost);
    map['quantity_for_cost'] = Variable<double>(quantityForCost);
    map['unit_fk'] = Variable<String>(unitFk);
    map['date_created'] = Variable<DateTime>(dateCreated);
    if (!nullToAbsent || dateTimeModified != null) {
      map['date_time_modified'] = Variable<DateTime>(dateTimeModified);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    if (!nullToAbsent || groupId != null) {
      map['group_id'] = Variable<String>(groupId);
    }
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    if (!nullToAbsent || currentStock != null) {
      map['current_stock'] = Variable<double>(currentStock);
    }
    if (!nullToAbsent || minimumStock != null) {
      map['minimum_stock'] = Variable<double>(minimumStock);
    }
    if (!nullToAbsent || stockUnit != null) {
      map['stock_unit'] = Variable<String>(stockUnit);
    }
    if (!nullToAbsent || costPerStockUnit != null) {
      map['cost_per_stock_unit'] = Variable<double>(costPerStockUnit);
    }
    if (!nullToAbsent || lastStockUpdate != null) {
      map['last_stock_update'] = Variable<DateTime>(lastStockUpdate);
    }
    return map;
  }

  IngredientsCompanion toCompanion(bool nullToAbsent) {
    return IngredientsCompanion(
      ingredientPk: Value(ingredientPk),
      name: Value(name),
      cost: Value(cost),
      quantityForCost: Value(quantityForCost),
      unitFk: Value(unitFk),
      dateCreated: Value(dateCreated),
      dateTimeModified: dateTimeModified == null && nullToAbsent
          ? const Value.absent()
          : Value(dateTimeModified),
      isDeleted: Value(isDeleted),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      groupId: groupId == null && nullToAbsent
          ? const Value.absent()
          : Value(groupId),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      currentStock: currentStock == null && nullToAbsent
          ? const Value.absent()
          : Value(currentStock),
      minimumStock: minimumStock == null && nullToAbsent
          ? const Value.absent()
          : Value(minimumStock),
      stockUnit: stockUnit == null && nullToAbsent
          ? const Value.absent()
          : Value(stockUnit),
      costPerStockUnit: costPerStockUnit == null && nullToAbsent
          ? const Value.absent()
          : Value(costPerStockUnit),
      lastStockUpdate: lastStockUpdate == null && nullToAbsent
          ? const Value.absent()
          : Value(lastStockUpdate),
    );
  }

  factory Ingredient.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Ingredient(
      ingredientPk: serializer.fromJson<String>(json['ingredientPk']),
      name: serializer.fromJson<String>(json['name']),
      cost: serializer.fromJson<double>(json['cost']),
      quantityForCost: serializer.fromJson<double>(json['quantityForCost']),
      unitFk: serializer.fromJson<String>(json['unitFk']),
      dateCreated: serializer.fromJson<DateTime>(json['dateCreated']),
      dateTimeModified: serializer.fromJson<DateTime?>(
        json['dateTimeModified'],
      ),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      groupId: serializer.fromJson<String?>(json['groupId']),
      category: serializer.fromJson<String?>(json['category']),
      currentStock: serializer.fromJson<double?>(json['currentStock']),
      minimumStock: serializer.fromJson<double?>(json['minimumStock']),
      stockUnit: serializer.fromJson<String?>(json['stockUnit']),
      costPerStockUnit: serializer.fromJson<double?>(json['costPerStockUnit']),
      lastStockUpdate: serializer.fromJson<DateTime?>(json['lastStockUpdate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ingredientPk': serializer.toJson<String>(ingredientPk),
      'name': serializer.toJson<String>(name),
      'cost': serializer.toJson<double>(cost),
      'quantityForCost': serializer.toJson<double>(quantityForCost),
      'unitFk': serializer.toJson<String>(unitFk),
      'dateCreated': serializer.toJson<DateTime>(dateCreated),
      'dateTimeModified': serializer.toJson<DateTime?>(dateTimeModified),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'groupId': serializer.toJson<String?>(groupId),
      'category': serializer.toJson<String?>(category),
      'currentStock': serializer.toJson<double?>(currentStock),
      'minimumStock': serializer.toJson<double?>(minimumStock),
      'stockUnit': serializer.toJson<String?>(stockUnit),
      'costPerStockUnit': serializer.toJson<double?>(costPerStockUnit),
      'lastStockUpdate': serializer.toJson<DateTime?>(lastStockUpdate),
    };
  }

  Ingredient copyWith({
    String? ingredientPk,
    String? name,
    double? cost,
    double? quantityForCost,
    String? unitFk,
    DateTime? dateCreated,
    Value<DateTime?> dateTimeModified = const Value.absent(),
    bool? isDeleted,
    Value<DateTime?> deletedAt = const Value.absent(),
    Value<String?> groupId = const Value.absent(),
    Value<String?> category = const Value.absent(),
    Value<double?> currentStock = const Value.absent(),
    Value<double?> minimumStock = const Value.absent(),
    Value<String?> stockUnit = const Value.absent(),
    Value<double?> costPerStockUnit = const Value.absent(),
    Value<DateTime?> lastStockUpdate = const Value.absent(),
  }) => Ingredient(
    ingredientPk: ingredientPk ?? this.ingredientPk,
    name: name ?? this.name,
    cost: cost ?? this.cost,
    quantityForCost: quantityForCost ?? this.quantityForCost,
    unitFk: unitFk ?? this.unitFk,
    dateCreated: dateCreated ?? this.dateCreated,
    dateTimeModified: dateTimeModified.present
        ? dateTimeModified.value
        : this.dateTimeModified,
    isDeleted: isDeleted ?? this.isDeleted,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    groupId: groupId.present ? groupId.value : this.groupId,
    category: category.present ? category.value : this.category,
    currentStock: currentStock.present ? currentStock.value : this.currentStock,
    minimumStock: minimumStock.present ? minimumStock.value : this.minimumStock,
    stockUnit: stockUnit.present ? stockUnit.value : this.stockUnit,
    costPerStockUnit: costPerStockUnit.present
        ? costPerStockUnit.value
        : this.costPerStockUnit,
    lastStockUpdate: lastStockUpdate.present
        ? lastStockUpdate.value
        : this.lastStockUpdate,
  );
  Ingredient copyWithCompanion(IngredientsCompanion data) {
    return Ingredient(
      ingredientPk: data.ingredientPk.present
          ? data.ingredientPk.value
          : this.ingredientPk,
      name: data.name.present ? data.name.value : this.name,
      cost: data.cost.present ? data.cost.value : this.cost,
      quantityForCost: data.quantityForCost.present
          ? data.quantityForCost.value
          : this.quantityForCost,
      unitFk: data.unitFk.present ? data.unitFk.value : this.unitFk,
      dateCreated: data.dateCreated.present
          ? data.dateCreated.value
          : this.dateCreated,
      dateTimeModified: data.dateTimeModified.present
          ? data.dateTimeModified.value
          : this.dateTimeModified,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      category: data.category.present ? data.category.value : this.category,
      currentStock: data.currentStock.present
          ? data.currentStock.value
          : this.currentStock,
      minimumStock: data.minimumStock.present
          ? data.minimumStock.value
          : this.minimumStock,
      stockUnit: data.stockUnit.present ? data.stockUnit.value : this.stockUnit,
      costPerStockUnit: data.costPerStockUnit.present
          ? data.costPerStockUnit.value
          : this.costPerStockUnit,
      lastStockUpdate: data.lastStockUpdate.present
          ? data.lastStockUpdate.value
          : this.lastStockUpdate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Ingredient(')
          ..write('ingredientPk: $ingredientPk, ')
          ..write('name: $name, ')
          ..write('cost: $cost, ')
          ..write('quantityForCost: $quantityForCost, ')
          ..write('unitFk: $unitFk, ')
          ..write('dateCreated: $dateCreated, ')
          ..write('dateTimeModified: $dateTimeModified, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('groupId: $groupId, ')
          ..write('category: $category, ')
          ..write('currentStock: $currentStock, ')
          ..write('minimumStock: $minimumStock, ')
          ..write('stockUnit: $stockUnit, ')
          ..write('costPerStockUnit: $costPerStockUnit, ')
          ..write('lastStockUpdate: $lastStockUpdate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    ingredientPk,
    name,
    cost,
    quantityForCost,
    unitFk,
    dateCreated,
    dateTimeModified,
    isDeleted,
    deletedAt,
    groupId,
    category,
    currentStock,
    minimumStock,
    stockUnit,
    costPerStockUnit,
    lastStockUpdate,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Ingredient &&
          other.ingredientPk == this.ingredientPk &&
          other.name == this.name &&
          other.cost == this.cost &&
          other.quantityForCost == this.quantityForCost &&
          other.unitFk == this.unitFk &&
          other.dateCreated == this.dateCreated &&
          other.dateTimeModified == this.dateTimeModified &&
          other.isDeleted == this.isDeleted &&
          other.deletedAt == this.deletedAt &&
          other.groupId == this.groupId &&
          other.category == this.category &&
          other.currentStock == this.currentStock &&
          other.minimumStock == this.minimumStock &&
          other.stockUnit == this.stockUnit &&
          other.costPerStockUnit == this.costPerStockUnit &&
          other.lastStockUpdate == this.lastStockUpdate);
}

class IngredientsCompanion extends UpdateCompanion<Ingredient> {
  final Value<String> ingredientPk;
  final Value<String> name;
  final Value<double> cost;
  final Value<double> quantityForCost;
  final Value<String> unitFk;
  final Value<DateTime> dateCreated;
  final Value<DateTime?> dateTimeModified;
  final Value<bool> isDeleted;
  final Value<DateTime?> deletedAt;
  final Value<String?> groupId;
  final Value<String?> category;
  final Value<double?> currentStock;
  final Value<double?> minimumStock;
  final Value<String?> stockUnit;
  final Value<double?> costPerStockUnit;
  final Value<DateTime?> lastStockUpdate;
  final Value<int> rowid;
  const IngredientsCompanion({
    this.ingredientPk = const Value.absent(),
    this.name = const Value.absent(),
    this.cost = const Value.absent(),
    this.quantityForCost = const Value.absent(),
    this.unitFk = const Value.absent(),
    this.dateCreated = const Value.absent(),
    this.dateTimeModified = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.groupId = const Value.absent(),
    this.category = const Value.absent(),
    this.currentStock = const Value.absent(),
    this.minimumStock = const Value.absent(),
    this.stockUnit = const Value.absent(),
    this.costPerStockUnit = const Value.absent(),
    this.lastStockUpdate = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  IngredientsCompanion.insert({
    this.ingredientPk = const Value.absent(),
    required String name,
    required double cost,
    required double quantityForCost,
    required String unitFk,
    this.dateCreated = const Value.absent(),
    this.dateTimeModified = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.groupId = const Value.absent(),
    this.category = const Value.absent(),
    this.currentStock = const Value.absent(),
    this.minimumStock = const Value.absent(),
    this.stockUnit = const Value.absent(),
    this.costPerStockUnit = const Value.absent(),
    this.lastStockUpdate = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : name = Value(name),
       cost = Value(cost),
       quantityForCost = Value(quantityForCost),
       unitFk = Value(unitFk);
  static Insertable<Ingredient> custom({
    Expression<String>? ingredientPk,
    Expression<String>? name,
    Expression<double>? cost,
    Expression<double>? quantityForCost,
    Expression<String>? unitFk,
    Expression<DateTime>? dateCreated,
    Expression<DateTime>? dateTimeModified,
    Expression<bool>? isDeleted,
    Expression<DateTime>? deletedAt,
    Expression<String>? groupId,
    Expression<String>? category,
    Expression<double>? currentStock,
    Expression<double>? minimumStock,
    Expression<String>? stockUnit,
    Expression<double>? costPerStockUnit,
    Expression<DateTime>? lastStockUpdate,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ingredientPk != null) 'ingredient_pk': ingredientPk,
      if (name != null) 'name': name,
      if (cost != null) 'cost': cost,
      if (quantityForCost != null) 'quantity_for_cost': quantityForCost,
      if (unitFk != null) 'unit_fk': unitFk,
      if (dateCreated != null) 'date_created': dateCreated,
      if (dateTimeModified != null) 'date_time_modified': dateTimeModified,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (groupId != null) 'group_id': groupId,
      if (category != null) 'category': category,
      if (currentStock != null) 'current_stock': currentStock,
      if (minimumStock != null) 'minimum_stock': minimumStock,
      if (stockUnit != null) 'stock_unit': stockUnit,
      if (costPerStockUnit != null) 'cost_per_stock_unit': costPerStockUnit,
      if (lastStockUpdate != null) 'last_stock_update': lastStockUpdate,
      if (rowid != null) 'rowid': rowid,
    });
  }

  IngredientsCompanion copyWith({
    Value<String>? ingredientPk,
    Value<String>? name,
    Value<double>? cost,
    Value<double>? quantityForCost,
    Value<String>? unitFk,
    Value<DateTime>? dateCreated,
    Value<DateTime?>? dateTimeModified,
    Value<bool>? isDeleted,
    Value<DateTime?>? deletedAt,
    Value<String?>? groupId,
    Value<String?>? category,
    Value<double?>? currentStock,
    Value<double?>? minimumStock,
    Value<String?>? stockUnit,
    Value<double?>? costPerStockUnit,
    Value<DateTime?>? lastStockUpdate,
    Value<int>? rowid,
  }) {
    return IngredientsCompanion(
      ingredientPk: ingredientPk ?? this.ingredientPk,
      name: name ?? this.name,
      cost: cost ?? this.cost,
      quantityForCost: quantityForCost ?? this.quantityForCost,
      unitFk: unitFk ?? this.unitFk,
      dateCreated: dateCreated ?? this.dateCreated,
      dateTimeModified: dateTimeModified ?? this.dateTimeModified,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      groupId: groupId ?? this.groupId,
      category: category ?? this.category,
      currentStock: currentStock ?? this.currentStock,
      minimumStock: minimumStock ?? this.minimumStock,
      stockUnit: stockUnit ?? this.stockUnit,
      costPerStockUnit: costPerStockUnit ?? this.costPerStockUnit,
      lastStockUpdate: lastStockUpdate ?? this.lastStockUpdate,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ingredientPk.present) {
      map['ingredient_pk'] = Variable<String>(ingredientPk.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (cost.present) {
      map['cost'] = Variable<double>(cost.value);
    }
    if (quantityForCost.present) {
      map['quantity_for_cost'] = Variable<double>(quantityForCost.value);
    }
    if (unitFk.present) {
      map['unit_fk'] = Variable<String>(unitFk.value);
    }
    if (dateCreated.present) {
      map['date_created'] = Variable<DateTime>(dateCreated.value);
    }
    if (dateTimeModified.present) {
      map['date_time_modified'] = Variable<DateTime>(dateTimeModified.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (currentStock.present) {
      map['current_stock'] = Variable<double>(currentStock.value);
    }
    if (minimumStock.present) {
      map['minimum_stock'] = Variable<double>(minimumStock.value);
    }
    if (stockUnit.present) {
      map['stock_unit'] = Variable<String>(stockUnit.value);
    }
    if (costPerStockUnit.present) {
      map['cost_per_stock_unit'] = Variable<double>(costPerStockUnit.value);
    }
    if (lastStockUpdate.present) {
      map['last_stock_update'] = Variable<DateTime>(lastStockUpdate.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('IngredientsCompanion(')
          ..write('ingredientPk: $ingredientPk, ')
          ..write('name: $name, ')
          ..write('cost: $cost, ')
          ..write('quantityForCost: $quantityForCost, ')
          ..write('unitFk: $unitFk, ')
          ..write('dateCreated: $dateCreated, ')
          ..write('dateTimeModified: $dateTimeModified, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('groupId: $groupId, ')
          ..write('category: $category, ')
          ..write('currentStock: $currentStock, ')
          ..write('minimumStock: $minimumStock, ')
          ..write('stockUnit: $stockUnit, ')
          ..write('costPerStockUnit: $costPerStockUnit, ')
          ..write('lastStockUpdate: $lastStockUpdate, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecipeIngredientsTable extends RecipeIngredients
    with TableInfo<$RecipeIngredientsTable, RecipeIngredient> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecipeIngredientsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _recipeIngredientPkMeta =
      const VerificationMeta('recipeIngredientPk');
  @override
  late final GeneratedColumn<String> recipeIngredientPk =
      GeneratedColumn<String>(
        'recipe_ingredient_pk',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        clientDefault: () => uuid.v4(),
      );
  static const VerificationMeta _recipeFkMeta = const VerificationMeta(
    'recipeFk',
  );
  @override
  late final GeneratedColumn<String> recipeFk = GeneratedColumn<String>(
    'recipe_fk',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES recipes (recipe_pk)',
    ),
  );
  static const VerificationMeta _ingredientFkMeta = const VerificationMeta(
    'ingredientFk',
  );
  @override
  late final GeneratedColumn<String> ingredientFk = GeneratedColumn<String>(
    'ingredient_fk',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES ingredients (ingredient_pk)',
    ),
  );
  static const VerificationMeta _amountNeededMeta = const VerificationMeta(
    'amountNeeded',
  );
  @override
  late final GeneratedColumn<double> amountNeeded = GeneratedColumn<double>(
    'amount_needed',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateTimeModifiedMeta = const VerificationMeta(
    'dateTimeModified',
  );
  @override
  late final GeneratedColumn<DateTime> dateTimeModified =
      GeneratedColumn<DateTime>(
        'date_time_modified',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
        defaultValue: Constant(DateTime.now()),
      );
  @override
  List<GeneratedColumn> get $columns => [
    recipeIngredientPk,
    recipeFk,
    ingredientFk,
    amountNeeded,
    dateTimeModified,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recipe_ingredients';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecipeIngredient> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('recipe_ingredient_pk')) {
      context.handle(
        _recipeIngredientPkMeta,
        recipeIngredientPk.isAcceptableOrUnknown(
          data['recipe_ingredient_pk']!,
          _recipeIngredientPkMeta,
        ),
      );
    }
    if (data.containsKey('recipe_fk')) {
      context.handle(
        _recipeFkMeta,
        recipeFk.isAcceptableOrUnknown(data['recipe_fk']!, _recipeFkMeta),
      );
    } else if (isInserting) {
      context.missing(_recipeFkMeta);
    }
    if (data.containsKey('ingredient_fk')) {
      context.handle(
        _ingredientFkMeta,
        ingredientFk.isAcceptableOrUnknown(
          data['ingredient_fk']!,
          _ingredientFkMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ingredientFkMeta);
    }
    if (data.containsKey('amount_needed')) {
      context.handle(
        _amountNeededMeta,
        amountNeeded.isAcceptableOrUnknown(
          data['amount_needed']!,
          _amountNeededMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountNeededMeta);
    }
    if (data.containsKey('date_time_modified')) {
      context.handle(
        _dateTimeModifiedMeta,
        dateTimeModified.isAcceptableOrUnknown(
          data['date_time_modified']!,
          _dateTimeModifiedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {recipeIngredientPk};
  @override
  RecipeIngredient map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecipeIngredient(
      recipeIngredientPk: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recipe_ingredient_pk'],
      )!,
      recipeFk: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recipe_fk'],
      )!,
      ingredientFk: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ingredient_fk'],
      )!,
      amountNeeded: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount_needed'],
      )!,
      dateTimeModified: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date_time_modified'],
      ),
    );
  }

  @override
  $RecipeIngredientsTable createAlias(String alias) {
    return $RecipeIngredientsTable(attachedDatabase, alias);
  }
}

class RecipeIngredient extends DataClass
    implements Insertable<RecipeIngredient> {
  final String recipeIngredientPk;
  final String recipeFk;
  final String ingredientFk;
  final double amountNeeded;
  final DateTime? dateTimeModified;
  const RecipeIngredient({
    required this.recipeIngredientPk,
    required this.recipeFk,
    required this.ingredientFk,
    required this.amountNeeded,
    this.dateTimeModified,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['recipe_ingredient_pk'] = Variable<String>(recipeIngredientPk);
    map['recipe_fk'] = Variable<String>(recipeFk);
    map['ingredient_fk'] = Variable<String>(ingredientFk);
    map['amount_needed'] = Variable<double>(amountNeeded);
    if (!nullToAbsent || dateTimeModified != null) {
      map['date_time_modified'] = Variable<DateTime>(dateTimeModified);
    }
    return map;
  }

  RecipeIngredientsCompanion toCompanion(bool nullToAbsent) {
    return RecipeIngredientsCompanion(
      recipeIngredientPk: Value(recipeIngredientPk),
      recipeFk: Value(recipeFk),
      ingredientFk: Value(ingredientFk),
      amountNeeded: Value(amountNeeded),
      dateTimeModified: dateTimeModified == null && nullToAbsent
          ? const Value.absent()
          : Value(dateTimeModified),
    );
  }

  factory RecipeIngredient.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecipeIngredient(
      recipeIngredientPk: serializer.fromJson<String>(
        json['recipeIngredientPk'],
      ),
      recipeFk: serializer.fromJson<String>(json['recipeFk']),
      ingredientFk: serializer.fromJson<String>(json['ingredientFk']),
      amountNeeded: serializer.fromJson<double>(json['amountNeeded']),
      dateTimeModified: serializer.fromJson<DateTime?>(
        json['dateTimeModified'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'recipeIngredientPk': serializer.toJson<String>(recipeIngredientPk),
      'recipeFk': serializer.toJson<String>(recipeFk),
      'ingredientFk': serializer.toJson<String>(ingredientFk),
      'amountNeeded': serializer.toJson<double>(amountNeeded),
      'dateTimeModified': serializer.toJson<DateTime?>(dateTimeModified),
    };
  }

  RecipeIngredient copyWith({
    String? recipeIngredientPk,
    String? recipeFk,
    String? ingredientFk,
    double? amountNeeded,
    Value<DateTime?> dateTimeModified = const Value.absent(),
  }) => RecipeIngredient(
    recipeIngredientPk: recipeIngredientPk ?? this.recipeIngredientPk,
    recipeFk: recipeFk ?? this.recipeFk,
    ingredientFk: ingredientFk ?? this.ingredientFk,
    amountNeeded: amountNeeded ?? this.amountNeeded,
    dateTimeModified: dateTimeModified.present
        ? dateTimeModified.value
        : this.dateTimeModified,
  );
  RecipeIngredient copyWithCompanion(RecipeIngredientsCompanion data) {
    return RecipeIngredient(
      recipeIngredientPk: data.recipeIngredientPk.present
          ? data.recipeIngredientPk.value
          : this.recipeIngredientPk,
      recipeFk: data.recipeFk.present ? data.recipeFk.value : this.recipeFk,
      ingredientFk: data.ingredientFk.present
          ? data.ingredientFk.value
          : this.ingredientFk,
      amountNeeded: data.amountNeeded.present
          ? data.amountNeeded.value
          : this.amountNeeded,
      dateTimeModified: data.dateTimeModified.present
          ? data.dateTimeModified.value
          : this.dateTimeModified,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecipeIngredient(')
          ..write('recipeIngredientPk: $recipeIngredientPk, ')
          ..write('recipeFk: $recipeFk, ')
          ..write('ingredientFk: $ingredientFk, ')
          ..write('amountNeeded: $amountNeeded, ')
          ..write('dateTimeModified: $dateTimeModified')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    recipeIngredientPk,
    recipeFk,
    ingredientFk,
    amountNeeded,
    dateTimeModified,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecipeIngredient &&
          other.recipeIngredientPk == this.recipeIngredientPk &&
          other.recipeFk == this.recipeFk &&
          other.ingredientFk == this.ingredientFk &&
          other.amountNeeded == this.amountNeeded &&
          other.dateTimeModified == this.dateTimeModified);
}

class RecipeIngredientsCompanion extends UpdateCompanion<RecipeIngredient> {
  final Value<String> recipeIngredientPk;
  final Value<String> recipeFk;
  final Value<String> ingredientFk;
  final Value<double> amountNeeded;
  final Value<DateTime?> dateTimeModified;
  final Value<int> rowid;
  const RecipeIngredientsCompanion({
    this.recipeIngredientPk = const Value.absent(),
    this.recipeFk = const Value.absent(),
    this.ingredientFk = const Value.absent(),
    this.amountNeeded = const Value.absent(),
    this.dateTimeModified = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecipeIngredientsCompanion.insert({
    this.recipeIngredientPk = const Value.absent(),
    required String recipeFk,
    required String ingredientFk,
    required double amountNeeded,
    this.dateTimeModified = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : recipeFk = Value(recipeFk),
       ingredientFk = Value(ingredientFk),
       amountNeeded = Value(amountNeeded);
  static Insertable<RecipeIngredient> custom({
    Expression<String>? recipeIngredientPk,
    Expression<String>? recipeFk,
    Expression<String>? ingredientFk,
    Expression<double>? amountNeeded,
    Expression<DateTime>? dateTimeModified,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (recipeIngredientPk != null)
        'recipe_ingredient_pk': recipeIngredientPk,
      if (recipeFk != null) 'recipe_fk': recipeFk,
      if (ingredientFk != null) 'ingredient_fk': ingredientFk,
      if (amountNeeded != null) 'amount_needed': amountNeeded,
      if (dateTimeModified != null) 'date_time_modified': dateTimeModified,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecipeIngredientsCompanion copyWith({
    Value<String>? recipeIngredientPk,
    Value<String>? recipeFk,
    Value<String>? ingredientFk,
    Value<double>? amountNeeded,
    Value<DateTime?>? dateTimeModified,
    Value<int>? rowid,
  }) {
    return RecipeIngredientsCompanion(
      recipeIngredientPk: recipeIngredientPk ?? this.recipeIngredientPk,
      recipeFk: recipeFk ?? this.recipeFk,
      ingredientFk: ingredientFk ?? this.ingredientFk,
      amountNeeded: amountNeeded ?? this.amountNeeded,
      dateTimeModified: dateTimeModified ?? this.dateTimeModified,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (recipeIngredientPk.present) {
      map['recipe_ingredient_pk'] = Variable<String>(recipeIngredientPk.value);
    }
    if (recipeFk.present) {
      map['recipe_fk'] = Variable<String>(recipeFk.value);
    }
    if (ingredientFk.present) {
      map['ingredient_fk'] = Variable<String>(ingredientFk.value);
    }
    if (amountNeeded.present) {
      map['amount_needed'] = Variable<double>(amountNeeded.value);
    }
    if (dateTimeModified.present) {
      map['date_time_modified'] = Variable<DateTime>(dateTimeModified.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecipeIngredientsCompanion(')
          ..write('recipeIngredientPk: $recipeIngredientPk, ')
          ..write('recipeFk: $recipeFk, ')
          ..write('ingredientFk: $ingredientFk, ')
          ..write('amountNeeded: $amountNeeded, ')
          ..write('dateTimeModified: $dateTimeModified, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecipeStepsTable extends RecipeSteps
    with TableInfo<$RecipeStepsTable, RecipeStep> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecipeStepsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _stepPkMeta = const VerificationMeta('stepPk');
  @override
  late final GeneratedColumn<String> stepPk = GeneratedColumn<String>(
    'step_pk',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    clientDefault: () => uuid.v4(),
  );
  static const VerificationMeta _recipeFkMeta = const VerificationMeta(
    'recipeFk',
  );
  @override
  late final GeneratedColumn<String> recipeFk = GeneratedColumn<String>(
    'recipe_fk',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES recipes (recipe_pk)',
    ),
  );
  static const VerificationMeta _stepNumberMeta = const VerificationMeta(
    'stepNumber',
  );
  @override
  late final GeneratedColumn<int> stepNumber = GeneratedColumn<int>(
    'step_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _instructionMeta = const VerificationMeta(
    'instruction',
  );
  @override
  late final GeneratedColumn<String> instruction = GeneratedColumn<String>(
    'instruction',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateTimeModifiedMeta = const VerificationMeta(
    'dateTimeModified',
  );
  @override
  late final GeneratedColumn<DateTime> dateTimeModified =
      GeneratedColumn<DateTime>(
        'date_time_modified',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
        defaultValue: Constant(DateTime.now()),
      );
  @override
  List<GeneratedColumn> get $columns => [
    stepPk,
    recipeFk,
    stepNumber,
    instruction,
    dateTimeModified,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recipe_steps';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecipeStep> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('step_pk')) {
      context.handle(
        _stepPkMeta,
        stepPk.isAcceptableOrUnknown(data['step_pk']!, _stepPkMeta),
      );
    }
    if (data.containsKey('recipe_fk')) {
      context.handle(
        _recipeFkMeta,
        recipeFk.isAcceptableOrUnknown(data['recipe_fk']!, _recipeFkMeta),
      );
    } else if (isInserting) {
      context.missing(_recipeFkMeta);
    }
    if (data.containsKey('step_number')) {
      context.handle(
        _stepNumberMeta,
        stepNumber.isAcceptableOrUnknown(data['step_number']!, _stepNumberMeta),
      );
    } else if (isInserting) {
      context.missing(_stepNumberMeta);
    }
    if (data.containsKey('instruction')) {
      context.handle(
        _instructionMeta,
        instruction.isAcceptableOrUnknown(
          data['instruction']!,
          _instructionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_instructionMeta);
    }
    if (data.containsKey('date_time_modified')) {
      context.handle(
        _dateTimeModifiedMeta,
        dateTimeModified.isAcceptableOrUnknown(
          data['date_time_modified']!,
          _dateTimeModifiedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {stepPk};
  @override
  RecipeStep map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecipeStep(
      stepPk: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}step_pk'],
      )!,
      recipeFk: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recipe_fk'],
      )!,
      stepNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}step_number'],
      )!,
      instruction: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}instruction'],
      )!,
      dateTimeModified: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date_time_modified'],
      ),
    );
  }

  @override
  $RecipeStepsTable createAlias(String alias) {
    return $RecipeStepsTable(attachedDatabase, alias);
  }
}

class RecipeStep extends DataClass implements Insertable<RecipeStep> {
  final String stepPk;
  final String recipeFk;
  final int stepNumber;
  final String instruction;
  final DateTime? dateTimeModified;
  const RecipeStep({
    required this.stepPk,
    required this.recipeFk,
    required this.stepNumber,
    required this.instruction,
    this.dateTimeModified,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['step_pk'] = Variable<String>(stepPk);
    map['recipe_fk'] = Variable<String>(recipeFk);
    map['step_number'] = Variable<int>(stepNumber);
    map['instruction'] = Variable<String>(instruction);
    if (!nullToAbsent || dateTimeModified != null) {
      map['date_time_modified'] = Variable<DateTime>(dateTimeModified);
    }
    return map;
  }

  RecipeStepsCompanion toCompanion(bool nullToAbsent) {
    return RecipeStepsCompanion(
      stepPk: Value(stepPk),
      recipeFk: Value(recipeFk),
      stepNumber: Value(stepNumber),
      instruction: Value(instruction),
      dateTimeModified: dateTimeModified == null && nullToAbsent
          ? const Value.absent()
          : Value(dateTimeModified),
    );
  }

  factory RecipeStep.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecipeStep(
      stepPk: serializer.fromJson<String>(json['stepPk']),
      recipeFk: serializer.fromJson<String>(json['recipeFk']),
      stepNumber: serializer.fromJson<int>(json['stepNumber']),
      instruction: serializer.fromJson<String>(json['instruction']),
      dateTimeModified: serializer.fromJson<DateTime?>(
        json['dateTimeModified'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'stepPk': serializer.toJson<String>(stepPk),
      'recipeFk': serializer.toJson<String>(recipeFk),
      'stepNumber': serializer.toJson<int>(stepNumber),
      'instruction': serializer.toJson<String>(instruction),
      'dateTimeModified': serializer.toJson<DateTime?>(dateTimeModified),
    };
  }

  RecipeStep copyWith({
    String? stepPk,
    String? recipeFk,
    int? stepNumber,
    String? instruction,
    Value<DateTime?> dateTimeModified = const Value.absent(),
  }) => RecipeStep(
    stepPk: stepPk ?? this.stepPk,
    recipeFk: recipeFk ?? this.recipeFk,
    stepNumber: stepNumber ?? this.stepNumber,
    instruction: instruction ?? this.instruction,
    dateTimeModified: dateTimeModified.present
        ? dateTimeModified.value
        : this.dateTimeModified,
  );
  RecipeStep copyWithCompanion(RecipeStepsCompanion data) {
    return RecipeStep(
      stepPk: data.stepPk.present ? data.stepPk.value : this.stepPk,
      recipeFk: data.recipeFk.present ? data.recipeFk.value : this.recipeFk,
      stepNumber: data.stepNumber.present
          ? data.stepNumber.value
          : this.stepNumber,
      instruction: data.instruction.present
          ? data.instruction.value
          : this.instruction,
      dateTimeModified: data.dateTimeModified.present
          ? data.dateTimeModified.value
          : this.dateTimeModified,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecipeStep(')
          ..write('stepPk: $stepPk, ')
          ..write('recipeFk: $recipeFk, ')
          ..write('stepNumber: $stepNumber, ')
          ..write('instruction: $instruction, ')
          ..write('dateTimeModified: $dateTimeModified')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(stepPk, recipeFk, stepNumber, instruction, dateTimeModified);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecipeStep &&
          other.stepPk == this.stepPk &&
          other.recipeFk == this.recipeFk &&
          other.stepNumber == this.stepNumber &&
          other.instruction == this.instruction &&
          other.dateTimeModified == this.dateTimeModified);
}

class RecipeStepsCompanion extends UpdateCompanion<RecipeStep> {
  final Value<String> stepPk;
  final Value<String> recipeFk;
  final Value<int> stepNumber;
  final Value<String> instruction;
  final Value<DateTime?> dateTimeModified;
  final Value<int> rowid;
  const RecipeStepsCompanion({
    this.stepPk = const Value.absent(),
    this.recipeFk = const Value.absent(),
    this.stepNumber = const Value.absent(),
    this.instruction = const Value.absent(),
    this.dateTimeModified = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecipeStepsCompanion.insert({
    this.stepPk = const Value.absent(),
    required String recipeFk,
    required int stepNumber,
    required String instruction,
    this.dateTimeModified = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : recipeFk = Value(recipeFk),
       stepNumber = Value(stepNumber),
       instruction = Value(instruction);
  static Insertable<RecipeStep> custom({
    Expression<String>? stepPk,
    Expression<String>? recipeFk,
    Expression<int>? stepNumber,
    Expression<String>? instruction,
    Expression<DateTime>? dateTimeModified,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (stepPk != null) 'step_pk': stepPk,
      if (recipeFk != null) 'recipe_fk': recipeFk,
      if (stepNumber != null) 'step_number': stepNumber,
      if (instruction != null) 'instruction': instruction,
      if (dateTimeModified != null) 'date_time_modified': dateTimeModified,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecipeStepsCompanion copyWith({
    Value<String>? stepPk,
    Value<String>? recipeFk,
    Value<int>? stepNumber,
    Value<String>? instruction,
    Value<DateTime?>? dateTimeModified,
    Value<int>? rowid,
  }) {
    return RecipeStepsCompanion(
      stepPk: stepPk ?? this.stepPk,
      recipeFk: recipeFk ?? this.recipeFk,
      stepNumber: stepNumber ?? this.stepNumber,
      instruction: instruction ?? this.instruction,
      dateTimeModified: dateTimeModified ?? this.dateTimeModified,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (stepPk.present) {
      map['step_pk'] = Variable<String>(stepPk.value);
    }
    if (recipeFk.present) {
      map['recipe_fk'] = Variable<String>(recipeFk.value);
    }
    if (stepNumber.present) {
      map['step_number'] = Variable<int>(stepNumber.value);
    }
    if (instruction.present) {
      map['instruction'] = Variable<String>(instruction.value);
    }
    if (dateTimeModified.present) {
      map['date_time_modified'] = Variable<DateTime>(dateTimeModified.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecipeStepsCompanion(')
          ..write('stepPk: $stepPk, ')
          ..write('recipeFk: $recipeFk, ')
          ..write('stepNumber: $stepNumber, ')
          ..write('instruction: $instruction, ')
          ..write('dateTimeModified: $dateTimeModified, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, Category> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(maxTextLength: 50),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconNameMeta = const VerificationMeta(
    'iconName',
  );
  @override
  late final GeneratedColumn<String> iconName = GeneratedColumn<String>(
    'icon_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, iconName];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<Category> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('icon_name')) {
      context.handle(
        _iconNameMeta,
        iconName.isAcceptableOrUnknown(data['icon_name']!, _iconNameMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      iconName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon_name'],
      ),
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }
}

class Category extends DataClass implements Insertable<Category> {
  final String id;
  final String name;
  final String? iconName;
  const Category({required this.id, required this.name, this.iconName});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || iconName != null) {
      map['icon_name'] = Variable<String>(iconName);
    }
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      name: Value(name),
      iconName: iconName == null && nullToAbsent
          ? const Value.absent()
          : Value(iconName),
    );
  }

  factory Category.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Category(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      iconName: serializer.fromJson<String?>(json['iconName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'iconName': serializer.toJson<String?>(iconName),
    };
  }

  Category copyWith({
    String? id,
    String? name,
    Value<String?> iconName = const Value.absent(),
  }) => Category(
    id: id ?? this.id,
    name: name ?? this.name,
    iconName: iconName.present ? iconName.value : this.iconName,
  );
  Category copyWithCompanion(CategoriesCompanion data) {
    return Category(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      iconName: data.iconName.present ? data.iconName.value : this.iconName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Category(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('iconName: $iconName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, iconName);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category &&
          other.id == this.id &&
          other.name == this.name &&
          other.iconName == this.iconName);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> iconName;
  final Value<int> rowid;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.iconName = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CategoriesCompanion.insert({
    required String id,
    required String name,
    this.iconName = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<Category> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? iconName,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (iconName != null) 'icon_name': iconName,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CategoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? iconName,
    Value<int>? rowid,
  }) {
    return CategoriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      iconName: iconName ?? this.iconName,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (iconName.present) {
      map['icon_name'] = Variable<String>(iconName.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('iconName: $iconName, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecipeSpacesTable extends RecipeSpaces
    with TableInfo<$RecipeSpacesTable, RecipeSpace> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecipeSpacesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _recipeIdMeta = const VerificationMeta(
    'recipeId',
  );
  @override
  late final GeneratedColumn<String> recipeId = GeneratedColumn<String>(
    'recipe_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES recipes (recipe_pk) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _spaceIdMeta = const VerificationMeta(
    'spaceId',
  );
  @override
  late final GeneratedColumn<String> spaceId = GeneratedColumn<String>(
    'space_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES "groups" (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    recipeId,
    spaceId,
    createdAt,
    isDeleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recipe_spaces';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecipeSpace> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('recipe_id')) {
      context.handle(
        _recipeIdMeta,
        recipeId.isAcceptableOrUnknown(data['recipe_id']!, _recipeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_recipeIdMeta);
    }
    if (data.containsKey('space_id')) {
      context.handle(
        _spaceIdMeta,
        spaceId.isAcceptableOrUnknown(data['space_id']!, _spaceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_spaceIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {recipeId, spaceId};
  @override
  RecipeSpace map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecipeSpace(
      recipeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recipe_id'],
      )!,
      spaceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}space_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
    );
  }

  @override
  $RecipeSpacesTable createAlias(String alias) {
    return $RecipeSpacesTable(attachedDatabase, alias);
  }
}

class RecipeSpace extends DataClass implements Insertable<RecipeSpace> {
  final String recipeId;
  final String spaceId;
  final DateTime createdAt;
  final bool isDeleted;
  const RecipeSpace({
    required this.recipeId,
    required this.spaceId,
    required this.createdAt,
    required this.isDeleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['recipe_id'] = Variable<String>(recipeId);
    map['space_id'] = Variable<String>(spaceId);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['is_deleted'] = Variable<bool>(isDeleted);
    return map;
  }

  RecipeSpacesCompanion toCompanion(bool nullToAbsent) {
    return RecipeSpacesCompanion(
      recipeId: Value(recipeId),
      spaceId: Value(spaceId),
      createdAt: Value(createdAt),
      isDeleted: Value(isDeleted),
    );
  }

  factory RecipeSpace.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecipeSpace(
      recipeId: serializer.fromJson<String>(json['recipeId']),
      spaceId: serializer.fromJson<String>(json['spaceId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'recipeId': serializer.toJson<String>(recipeId),
      'spaceId': serializer.toJson<String>(spaceId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'isDeleted': serializer.toJson<bool>(isDeleted),
    };
  }

  RecipeSpace copyWith({
    String? recipeId,
    String? spaceId,
    DateTime? createdAt,
    bool? isDeleted,
  }) => RecipeSpace(
    recipeId: recipeId ?? this.recipeId,
    spaceId: spaceId ?? this.spaceId,
    createdAt: createdAt ?? this.createdAt,
    isDeleted: isDeleted ?? this.isDeleted,
  );
  RecipeSpace copyWithCompanion(RecipeSpacesCompanion data) {
    return RecipeSpace(
      recipeId: data.recipeId.present ? data.recipeId.value : this.recipeId,
      spaceId: data.spaceId.present ? data.spaceId.value : this.spaceId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecipeSpace(')
          ..write('recipeId: $recipeId, ')
          ..write('spaceId: $spaceId, ')
          ..write('createdAt: $createdAt, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(recipeId, spaceId, createdAt, isDeleted);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecipeSpace &&
          other.recipeId == this.recipeId &&
          other.spaceId == this.spaceId &&
          other.createdAt == this.createdAt &&
          other.isDeleted == this.isDeleted);
}

class RecipeSpacesCompanion extends UpdateCompanion<RecipeSpace> {
  final Value<String> recipeId;
  final Value<String> spaceId;
  final Value<DateTime> createdAt;
  final Value<bool> isDeleted;
  final Value<int> rowid;
  const RecipeSpacesCompanion({
    this.recipeId = const Value.absent(),
    this.spaceId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecipeSpacesCompanion.insert({
    required String recipeId,
    required String spaceId,
    this.createdAt = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : recipeId = Value(recipeId),
       spaceId = Value(spaceId);
  static Insertable<RecipeSpace> custom({
    Expression<String>? recipeId,
    Expression<String>? spaceId,
    Expression<DateTime>? createdAt,
    Expression<bool>? isDeleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (recipeId != null) 'recipe_id': recipeId,
      if (spaceId != null) 'space_id': spaceId,
      if (createdAt != null) 'created_at': createdAt,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecipeSpacesCompanion copyWith({
    Value<String>? recipeId,
    Value<String>? spaceId,
    Value<DateTime>? createdAt,
    Value<bool>? isDeleted,
    Value<int>? rowid,
  }) {
    return RecipeSpacesCompanion(
      recipeId: recipeId ?? this.recipeId,
      spaceId: spaceId ?? this.spaceId,
      createdAt: createdAt ?? this.createdAt,
      isDeleted: isDeleted ?? this.isDeleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (recipeId.present) {
      map['recipe_id'] = Variable<String>(recipeId.value);
    }
    if (spaceId.present) {
      map['space_id'] = Variable<String>(spaceId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecipeSpacesCompanion(')
          ..write('recipeId: $recipeId, ')
          ..write('spaceId: $spaceId, ')
          ..write('createdAt: $createdAt, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DeletedRecordsTable extends DeletedRecords
    with TableInfo<$DeletedRecordsTable, DeletedRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeletedRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _recordPkMeta = const VerificationMeta(
    'recordPk',
  );
  @override
  late final GeneratedColumn<String> recordPk = GeneratedColumn<String>(
    'record_pk',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [recordPk, entityType, deletedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'deleted_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeletedRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('record_pk')) {
      context.handle(
        _recordPkMeta,
        recordPk.isAcceptableOrUnknown(data['record_pk']!, _recordPkMeta),
      );
    } else if (isInserting) {
      context.missing(_recordPkMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_deletedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {recordPk, entityType};
  @override
  DeletedRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeletedRecord(
      recordPk: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_pk'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      )!,
    );
  }

  @override
  $DeletedRecordsTable createAlias(String alias) {
    return $DeletedRecordsTable(attachedDatabase, alias);
  }
}

class DeletedRecord extends DataClass implements Insertable<DeletedRecord> {
  final String recordPk;
  final String entityType;
  final DateTime deletedAt;
  const DeletedRecord({
    required this.recordPk,
    required this.entityType,
    required this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['record_pk'] = Variable<String>(recordPk);
    map['entity_type'] = Variable<String>(entityType);
    map['deleted_at'] = Variable<DateTime>(deletedAt);
    return map;
  }

  DeletedRecordsCompanion toCompanion(bool nullToAbsent) {
    return DeletedRecordsCompanion(
      recordPk: Value(recordPk),
      entityType: Value(entityType),
      deletedAt: Value(deletedAt),
    );
  }

  factory DeletedRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeletedRecord(
      recordPk: serializer.fromJson<String>(json['recordPk']),
      entityType: serializer.fromJson<String>(json['entityType']),
      deletedAt: serializer.fromJson<DateTime>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'recordPk': serializer.toJson<String>(recordPk),
      'entityType': serializer.toJson<String>(entityType),
      'deletedAt': serializer.toJson<DateTime>(deletedAt),
    };
  }

  DeletedRecord copyWith({
    String? recordPk,
    String? entityType,
    DateTime? deletedAt,
  }) => DeletedRecord(
    recordPk: recordPk ?? this.recordPk,
    entityType: entityType ?? this.entityType,
    deletedAt: deletedAt ?? this.deletedAt,
  );
  DeletedRecord copyWithCompanion(DeletedRecordsCompanion data) {
    return DeletedRecord(
      recordPk: data.recordPk.present ? data.recordPk.value : this.recordPk,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeletedRecord(')
          ..write('recordPk: $recordPk, ')
          ..write('entityType: $entityType, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(recordPk, entityType, deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeletedRecord &&
          other.recordPk == this.recordPk &&
          other.entityType == this.entityType &&
          other.deletedAt == this.deletedAt);
}

class DeletedRecordsCompanion extends UpdateCompanion<DeletedRecord> {
  final Value<String> recordPk;
  final Value<String> entityType;
  final Value<DateTime> deletedAt;
  final Value<int> rowid;
  const DeletedRecordsCompanion({
    this.recordPk = const Value.absent(),
    this.entityType = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DeletedRecordsCompanion.insert({
    required String recordPk,
    required String entityType,
    required DateTime deletedAt,
    this.rowid = const Value.absent(),
  }) : recordPk = Value(recordPk),
       entityType = Value(entityType),
       deletedAt = Value(deletedAt);
  static Insertable<DeletedRecord> custom({
    Expression<String>? recordPk,
    Expression<String>? entityType,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (recordPk != null) 'record_pk': recordPk,
      if (entityType != null) 'entity_type': entityType,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DeletedRecordsCompanion copyWith({
    Value<String>? recordPk,
    Value<String>? entityType,
    Value<DateTime>? deletedAt,
    Value<int>? rowid,
  }) {
    return DeletedRecordsCompanion(
      recordPk: recordPk ?? this.recordPk,
      entityType: entityType ?? this.entityType,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (recordPk.present) {
      map['record_pk'] = Variable<String>(recordPk.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeletedRecordsCompanion(')
          ..write('recordPk: $recordPk, ')
          ..write('entityType: $entityType, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $GroupsTable groups = $GroupsTable(this);
  late final $RecipesTable recipes = $RecipesTable(this);
  late final $UnitsTable units = $UnitsTable(this);
  late final $IngredientsTable ingredients = $IngredientsTable(this);
  late final $RecipeIngredientsTable recipeIngredients =
      $RecipeIngredientsTable(this);
  late final $RecipeStepsTable recipeSteps = $RecipeStepsTable(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $RecipeSpacesTable recipeSpaces = $RecipeSpacesTable(this);
  late final $DeletedRecordsTable deletedRecords = $DeletedRecordsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    groups,
    recipes,
    units,
    ingredients,
    recipeIngredients,
    recipeSteps,
    categories,
    recipeSpaces,
    deletedRecords,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'recipes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('recipe_spaces', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'groups',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('recipe_spaces', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$GroupsTableCreateCompanionBuilder =
    GroupsCompanion Function({
      Value<String> id,
      required String name,
      Value<String?> iconName,
      Value<String?> colorHex,
      Value<bool> isActive,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> isDeleted,
      Value<int> rowid,
    });
typedef $$GroupsTableUpdateCompanionBuilder =
    GroupsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> iconName,
      Value<String?> colorHex,
      Value<bool> isActive,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<bool> isDeleted,
      Value<int> rowid,
    });

final class $$GroupsTableReferences
    extends BaseReferences<_$AppDatabase, $GroupsTable, Group> {
  $$GroupsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$RecipesTable, List<Recipe>> _recipesRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.recipes,
    aliasName: $_aliasNameGenerator(db.groups.id, db.recipes.groupId),
  );

  $$RecipesTableProcessedTableManager get recipesRefs {
    final manager = $$RecipesTableTableManager(
      $_db,
      $_db.recipes,
    ).filter((f) => f.groupId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_recipesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$IngredientsTable, List<Ingredient>>
  _ingredientsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.ingredients,
    aliasName: $_aliasNameGenerator(db.groups.id, db.ingredients.groupId),
  );

  $$IngredientsTableProcessedTableManager get ingredientsRefs {
    final manager = $$IngredientsTableTableManager(
      $_db,
      $_db.ingredients,
    ).filter((f) => f.groupId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_ingredientsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RecipeSpacesTable, List<RecipeSpace>>
  _recipeSpacesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.recipeSpaces,
    aliasName: $_aliasNameGenerator(db.groups.id, db.recipeSpaces.spaceId),
  );

  $$RecipeSpacesTableProcessedTableManager get recipeSpacesRefs {
    final manager = $$RecipeSpacesTableTableManager(
      $_db,
      $_db.recipeSpaces,
    ).filter((f) => f.spaceId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_recipeSpacesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$GroupsTableFilterComposer
    extends Composer<_$AppDatabase, $GroupsTable> {
  $$GroupsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iconName => $composableBuilder(
    column: $table.iconName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> recipesRefs(
    Expression<bool> Function($$RecipesTableFilterComposer f) f,
  ) {
    final $$RecipesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recipes,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipesTableFilterComposer(
            $db: $db,
            $table: $db.recipes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> ingredientsRefs(
    Expression<bool> Function($$IngredientsTableFilterComposer f) f,
  ) {
    final $$IngredientsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.ingredients,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IngredientsTableFilterComposer(
            $db: $db,
            $table: $db.ingredients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> recipeSpacesRefs(
    Expression<bool> Function($$RecipeSpacesTableFilterComposer f) f,
  ) {
    final $$RecipeSpacesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recipeSpaces,
      getReferencedColumn: (t) => t.spaceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipeSpacesTableFilterComposer(
            $db: $db,
            $table: $db.recipeSpaces,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$GroupsTableOrderingComposer
    extends Composer<_$AppDatabase, $GroupsTable> {
  $$GroupsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconName => $composableBuilder(
    column: $table.iconName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GroupsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GroupsTable> {
  $$GroupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get iconName =>
      $composableBuilder(column: $table.iconName, builder: (column) => column);

  GeneratedColumn<String> get colorHex =>
      $composableBuilder(column: $table.colorHex, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  Expression<T> recipesRefs<T extends Object>(
    Expression<T> Function($$RecipesTableAnnotationComposer a) f,
  ) {
    final $$RecipesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recipes,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipesTableAnnotationComposer(
            $db: $db,
            $table: $db.recipes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> ingredientsRefs<T extends Object>(
    Expression<T> Function($$IngredientsTableAnnotationComposer a) f,
  ) {
    final $$IngredientsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.ingredients,
      getReferencedColumn: (t) => t.groupId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IngredientsTableAnnotationComposer(
            $db: $db,
            $table: $db.ingredients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> recipeSpacesRefs<T extends Object>(
    Expression<T> Function($$RecipeSpacesTableAnnotationComposer a) f,
  ) {
    final $$RecipeSpacesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recipeSpaces,
      getReferencedColumn: (t) => t.spaceId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipeSpacesTableAnnotationComposer(
            $db: $db,
            $table: $db.recipeSpaces,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$GroupsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GroupsTable,
          Group,
          $$GroupsTableFilterComposer,
          $$GroupsTableOrderingComposer,
          $$GroupsTableAnnotationComposer,
          $$GroupsTableCreateCompanionBuilder,
          $$GroupsTableUpdateCompanionBuilder,
          (Group, $$GroupsTableReferences),
          Group,
          PrefetchHooks Function({
            bool recipesRefs,
            bool ingredientsRefs,
            bool recipeSpacesRefs,
          })
        > {
  $$GroupsTableTableManager(_$AppDatabase db, $GroupsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> iconName = const Value.absent(),
                Value<String?> colorHex = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GroupsCompanion(
                id: id,
                name: name,
                iconName: iconName,
                colorHex: colorHex,
                isActive: isActive,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                required String name,
                Value<String?> iconName = const Value.absent(),
                Value<String?> colorHex = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GroupsCompanion.insert(
                id: id,
                name: name,
                iconName: iconName,
                colorHex: colorHex,
                isActive: isActive,
                createdAt: createdAt,
                updatedAt: updatedAt,
                isDeleted: isDeleted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$GroupsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                recipesRefs = false,
                ingredientsRefs = false,
                recipeSpacesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (recipesRefs) db.recipes,
                    if (ingredientsRefs) db.ingredients,
                    if (recipeSpacesRefs) db.recipeSpaces,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (recipesRefs)
                        await $_getPrefetchedData<Group, $GroupsTable, Recipe>(
                          currentTable: table,
                          referencedTable: $$GroupsTableReferences
                              ._recipesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$GroupsTableReferences(
                                db,
                                table,
                                p0,
                              ).recipesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.groupId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (ingredientsRefs)
                        await $_getPrefetchedData<
                          Group,
                          $GroupsTable,
                          Ingredient
                        >(
                          currentTable: table,
                          referencedTable: $$GroupsTableReferences
                              ._ingredientsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$GroupsTableReferences(
                                db,
                                table,
                                p0,
                              ).ingredientsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.groupId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (recipeSpacesRefs)
                        await $_getPrefetchedData<
                          Group,
                          $GroupsTable,
                          RecipeSpace
                        >(
                          currentTable: table,
                          referencedTable: $$GroupsTableReferences
                              ._recipeSpacesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$GroupsTableReferences(
                                db,
                                table,
                                p0,
                              ).recipeSpacesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.spaceId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$GroupsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GroupsTable,
      Group,
      $$GroupsTableFilterComposer,
      $$GroupsTableOrderingComposer,
      $$GroupsTableAnnotationComposer,
      $$GroupsTableCreateCompanionBuilder,
      $$GroupsTableUpdateCompanionBuilder,
      (Group, $$GroupsTableReferences),
      Group,
      PrefetchHooks Function({
        bool recipesRefs,
        bool ingredientsRefs,
        bool recipeSpacesRefs,
      })
    >;
typedef $$RecipesTableCreateCompanionBuilder =
    RecipesCompanion Function({
      Value<String> recipePk,
      required String name,
      Value<String?> description,
      required double defaultYield,
      required String yieldName,
      Value<double> targetProfitMargin,
      Value<double> targetPricePerPortion,
      Value<double> fixedOverheadCost,
      Value<String?> colour,
      Value<DateTime> dateCreated,
      Value<DateTime?> dateTimeModified,
      Value<bool> archived,
      Value<String?> groupId,
      Value<String?> category,
      Value<int> rowid,
    });
typedef $$RecipesTableUpdateCompanionBuilder =
    RecipesCompanion Function({
      Value<String> recipePk,
      Value<String> name,
      Value<String?> description,
      Value<double> defaultYield,
      Value<String> yieldName,
      Value<double> targetProfitMargin,
      Value<double> targetPricePerPortion,
      Value<double> fixedOverheadCost,
      Value<String?> colour,
      Value<DateTime> dateCreated,
      Value<DateTime?> dateTimeModified,
      Value<bool> archived,
      Value<String?> groupId,
      Value<String?> category,
      Value<int> rowid,
    });

final class $$RecipesTableReferences
    extends BaseReferences<_$AppDatabase, $RecipesTable, Recipe> {
  $$RecipesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $GroupsTable _groupIdTable(_$AppDatabase db) => db.groups.createAlias(
    $_aliasNameGenerator(db.recipes.groupId, db.groups.id),
  );

  $$GroupsTableProcessedTableManager? get groupId {
    final $_column = $_itemColumn<String>('group_id');
    if ($_column == null) return null;
    final manager = $$GroupsTableTableManager(
      $_db,
      $_db.groups,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_groupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$RecipeIngredientsTable, List<RecipeIngredient>>
  _recipeIngredientsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.recipeIngredients,
        aliasName: $_aliasNameGenerator(
          db.recipes.recipePk,
          db.recipeIngredients.recipeFk,
        ),
      );

  $$RecipeIngredientsTableProcessedTableManager get recipeIngredientsRefs {
    final manager =
        $$RecipeIngredientsTableTableManager(
          $_db,
          $_db.recipeIngredients,
        ).filter(
          (f) =>
              f.recipeFk.recipePk.sqlEquals($_itemColumn<String>('recipe_pk')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _recipeIngredientsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RecipeStepsTable, List<RecipeStep>>
  _recipeStepsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.recipeSteps,
    aliasName: $_aliasNameGenerator(
      db.recipes.recipePk,
      db.recipeSteps.recipeFk,
    ),
  );

  $$RecipeStepsTableProcessedTableManager get recipeStepsRefs {
    final manager = $$RecipeStepsTableTableManager($_db, $_db.recipeSteps)
        .filter(
          (f) =>
              f.recipeFk.recipePk.sqlEquals($_itemColumn<String>('recipe_pk')!),
        );

    final cache = $_typedResult.readTableOrNull(_recipeStepsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RecipeSpacesTable, List<RecipeSpace>>
  _recipeSpacesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.recipeSpaces,
    aliasName: $_aliasNameGenerator(
      db.recipes.recipePk,
      db.recipeSpaces.recipeId,
    ),
  );

  $$RecipeSpacesTableProcessedTableManager get recipeSpacesRefs {
    final manager = $$RecipeSpacesTableTableManager($_db, $_db.recipeSpaces)
        .filter(
          (f) =>
              f.recipeId.recipePk.sqlEquals($_itemColumn<String>('recipe_pk')!),
        );

    final cache = $_typedResult.readTableOrNull(_recipeSpacesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RecipesTableFilterComposer
    extends Composer<_$AppDatabase, $RecipesTable> {
  $$RecipesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get recipePk => $composableBuilder(
    column: $table.recipePk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get defaultYield => $composableBuilder(
    column: $table.defaultYield,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get yieldName => $composableBuilder(
    column: $table.yieldName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get targetProfitMargin => $composableBuilder(
    column: $table.targetProfitMargin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get targetPricePerPortion => $composableBuilder(
    column: $table.targetPricePerPortion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fixedOverheadCost => $composableBuilder(
    column: $table.fixedOverheadCost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colour => $composableBuilder(
    column: $table.colour,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dateCreated => $composableBuilder(
    column: $table.dateCreated,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dateTimeModified => $composableBuilder(
    column: $table.dateTimeModified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  $$GroupsTableFilterComposer get groupId {
    final $$GroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableFilterComposer(
            $db: $db,
            $table: $db.groups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> recipeIngredientsRefs(
    Expression<bool> Function($$RecipeIngredientsTableFilterComposer f) f,
  ) {
    final $$RecipeIngredientsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recipePk,
      referencedTable: $db.recipeIngredients,
      getReferencedColumn: (t) => t.recipeFk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipeIngredientsTableFilterComposer(
            $db: $db,
            $table: $db.recipeIngredients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> recipeStepsRefs(
    Expression<bool> Function($$RecipeStepsTableFilterComposer f) f,
  ) {
    final $$RecipeStepsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recipePk,
      referencedTable: $db.recipeSteps,
      getReferencedColumn: (t) => t.recipeFk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipeStepsTableFilterComposer(
            $db: $db,
            $table: $db.recipeSteps,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> recipeSpacesRefs(
    Expression<bool> Function($$RecipeSpacesTableFilterComposer f) f,
  ) {
    final $$RecipeSpacesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recipePk,
      referencedTable: $db.recipeSpaces,
      getReferencedColumn: (t) => t.recipeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipeSpacesTableFilterComposer(
            $db: $db,
            $table: $db.recipeSpaces,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RecipesTableOrderingComposer
    extends Composer<_$AppDatabase, $RecipesTable> {
  $$RecipesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get recipePk => $composableBuilder(
    column: $table.recipePk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get defaultYield => $composableBuilder(
    column: $table.defaultYield,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get yieldName => $composableBuilder(
    column: $table.yieldName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get targetProfitMargin => $composableBuilder(
    column: $table.targetProfitMargin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get targetPricePerPortion => $composableBuilder(
    column: $table.targetPricePerPortion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fixedOverheadCost => $composableBuilder(
    column: $table.fixedOverheadCost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colour => $composableBuilder(
    column: $table.colour,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dateCreated => $composableBuilder(
    column: $table.dateCreated,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dateTimeModified => $composableBuilder(
    column: $table.dateTimeModified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get archived => $composableBuilder(
    column: $table.archived,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  $$GroupsTableOrderingComposer get groupId {
    final $$GroupsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableOrderingComposer(
            $db: $db,
            $table: $db.groups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecipesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecipesTable> {
  $$RecipesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get recipePk =>
      $composableBuilder(column: $table.recipePk, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<double> get defaultYield => $composableBuilder(
    column: $table.defaultYield,
    builder: (column) => column,
  );

  GeneratedColumn<String> get yieldName =>
      $composableBuilder(column: $table.yieldName, builder: (column) => column);

  GeneratedColumn<double> get targetProfitMargin => $composableBuilder(
    column: $table.targetProfitMargin,
    builder: (column) => column,
  );

  GeneratedColumn<double> get targetPricePerPortion => $composableBuilder(
    column: $table.targetPricePerPortion,
    builder: (column) => column,
  );

  GeneratedColumn<double> get fixedOverheadCost => $composableBuilder(
    column: $table.fixedOverheadCost,
    builder: (column) => column,
  );

  GeneratedColumn<String> get colour =>
      $composableBuilder(column: $table.colour, builder: (column) => column);

  GeneratedColumn<DateTime> get dateCreated => $composableBuilder(
    column: $table.dateCreated,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get dateTimeModified => $composableBuilder(
    column: $table.dateTimeModified,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  $$GroupsTableAnnotationComposer get groupId {
    final $$GroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.groups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> recipeIngredientsRefs<T extends Object>(
    Expression<T> Function($$RecipeIngredientsTableAnnotationComposer a) f,
  ) {
    final $$RecipeIngredientsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.recipePk,
          referencedTable: $db.recipeIngredients,
          getReferencedColumn: (t) => t.recipeFk,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$RecipeIngredientsTableAnnotationComposer(
                $db: $db,
                $table: $db.recipeIngredients,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> recipeStepsRefs<T extends Object>(
    Expression<T> Function($$RecipeStepsTableAnnotationComposer a) f,
  ) {
    final $$RecipeStepsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recipePk,
      referencedTable: $db.recipeSteps,
      getReferencedColumn: (t) => t.recipeFk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipeStepsTableAnnotationComposer(
            $db: $db,
            $table: $db.recipeSteps,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> recipeSpacesRefs<T extends Object>(
    Expression<T> Function($$RecipeSpacesTableAnnotationComposer a) f,
  ) {
    final $$RecipeSpacesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recipePk,
      referencedTable: $db.recipeSpaces,
      getReferencedColumn: (t) => t.recipeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipeSpacesTableAnnotationComposer(
            $db: $db,
            $table: $db.recipeSpaces,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RecipesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecipesTable,
          Recipe,
          $$RecipesTableFilterComposer,
          $$RecipesTableOrderingComposer,
          $$RecipesTableAnnotationComposer,
          $$RecipesTableCreateCompanionBuilder,
          $$RecipesTableUpdateCompanionBuilder,
          (Recipe, $$RecipesTableReferences),
          Recipe,
          PrefetchHooks Function({
            bool groupId,
            bool recipeIngredientsRefs,
            bool recipeStepsRefs,
            bool recipeSpacesRefs,
          })
        > {
  $$RecipesTableTableManager(_$AppDatabase db, $RecipesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecipesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecipesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecipesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> recipePk = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<double> defaultYield = const Value.absent(),
                Value<String> yieldName = const Value.absent(),
                Value<double> targetProfitMargin = const Value.absent(),
                Value<double> targetPricePerPortion = const Value.absent(),
                Value<double> fixedOverheadCost = const Value.absent(),
                Value<String?> colour = const Value.absent(),
                Value<DateTime> dateCreated = const Value.absent(),
                Value<DateTime?> dateTimeModified = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<String?> groupId = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecipesCompanion(
                recipePk: recipePk,
                name: name,
                description: description,
                defaultYield: defaultYield,
                yieldName: yieldName,
                targetProfitMargin: targetProfitMargin,
                targetPricePerPortion: targetPricePerPortion,
                fixedOverheadCost: fixedOverheadCost,
                colour: colour,
                dateCreated: dateCreated,
                dateTimeModified: dateTimeModified,
                archived: archived,
                groupId: groupId,
                category: category,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> recipePk = const Value.absent(),
                required String name,
                Value<String?> description = const Value.absent(),
                required double defaultYield,
                required String yieldName,
                Value<double> targetProfitMargin = const Value.absent(),
                Value<double> targetPricePerPortion = const Value.absent(),
                Value<double> fixedOverheadCost = const Value.absent(),
                Value<String?> colour = const Value.absent(),
                Value<DateTime> dateCreated = const Value.absent(),
                Value<DateTime?> dateTimeModified = const Value.absent(),
                Value<bool> archived = const Value.absent(),
                Value<String?> groupId = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecipesCompanion.insert(
                recipePk: recipePk,
                name: name,
                description: description,
                defaultYield: defaultYield,
                yieldName: yieldName,
                targetProfitMargin: targetProfitMargin,
                targetPricePerPortion: targetPricePerPortion,
                fixedOverheadCost: fixedOverheadCost,
                colour: colour,
                dateCreated: dateCreated,
                dateTimeModified: dateTimeModified,
                archived: archived,
                groupId: groupId,
                category: category,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RecipesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                groupId = false,
                recipeIngredientsRefs = false,
                recipeStepsRefs = false,
                recipeSpacesRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (recipeIngredientsRefs) db.recipeIngredients,
                    if (recipeStepsRefs) db.recipeSteps,
                    if (recipeSpacesRefs) db.recipeSpaces,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (groupId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.groupId,
                                    referencedTable: $$RecipesTableReferences
                                        ._groupIdTable(db),
                                    referencedColumn: $$RecipesTableReferences
                                        ._groupIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (recipeIngredientsRefs)
                        await $_getPrefetchedData<
                          Recipe,
                          $RecipesTable,
                          RecipeIngredient
                        >(
                          currentTable: table,
                          referencedTable: $$RecipesTableReferences
                              ._recipeIngredientsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RecipesTableReferences(
                                db,
                                table,
                                p0,
                              ).recipeIngredientsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.recipeFk == item.recipePk,
                              ),
                          typedResults: items,
                        ),
                      if (recipeStepsRefs)
                        await $_getPrefetchedData<
                          Recipe,
                          $RecipesTable,
                          RecipeStep
                        >(
                          currentTable: table,
                          referencedTable: $$RecipesTableReferences
                              ._recipeStepsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RecipesTableReferences(
                                db,
                                table,
                                p0,
                              ).recipeStepsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.recipeFk == item.recipePk,
                              ),
                          typedResults: items,
                        ),
                      if (recipeSpacesRefs)
                        await $_getPrefetchedData<
                          Recipe,
                          $RecipesTable,
                          RecipeSpace
                        >(
                          currentTable: table,
                          referencedTable: $$RecipesTableReferences
                              ._recipeSpacesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RecipesTableReferences(
                                db,
                                table,
                                p0,
                              ).recipeSpacesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.recipeId == item.recipePk,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$RecipesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecipesTable,
      Recipe,
      $$RecipesTableFilterComposer,
      $$RecipesTableOrderingComposer,
      $$RecipesTableAnnotationComposer,
      $$RecipesTableCreateCompanionBuilder,
      $$RecipesTableUpdateCompanionBuilder,
      (Recipe, $$RecipesTableReferences),
      Recipe,
      PrefetchHooks Function({
        bool groupId,
        bool recipeIngredientsRefs,
        bool recipeStepsRefs,
        bool recipeSpacesRefs,
      })
    >;
typedef $$UnitsTableCreateCompanionBuilder =
    UnitsCompanion Function({
      Value<String> unitPk,
      required String name,
      required String symbol,
      Value<String?> category,
      Value<double> factorToBase,
      Value<bool> isMutable,
      Value<int> rowid,
    });
typedef $$UnitsTableUpdateCompanionBuilder =
    UnitsCompanion Function({
      Value<String> unitPk,
      Value<String> name,
      Value<String> symbol,
      Value<String?> category,
      Value<double> factorToBase,
      Value<bool> isMutable,
      Value<int> rowid,
    });

final class $$UnitsTableReferences
    extends BaseReferences<_$AppDatabase, $UnitsTable, Unit> {
  $$UnitsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$IngredientsTable, List<Ingredient>>
  _ingredientsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.ingredients,
    aliasName: $_aliasNameGenerator(db.units.unitPk, db.ingredients.unitFk),
  );

  $$IngredientsTableProcessedTableManager get ingredientsRefs {
    final manager = $$IngredientsTableTableManager($_db, $_db.ingredients)
        .filter(
          (f) => f.unitFk.unitPk.sqlEquals($_itemColumn<String>('unit_pk')!),
        );

    final cache = $_typedResult.readTableOrNull(_ingredientsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$UnitsTableFilterComposer extends Composer<_$AppDatabase, $UnitsTable> {
  $$UnitsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get unitPk => $composableBuilder(
    column: $table.unitPk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get factorToBase => $composableBuilder(
    column: $table.factorToBase,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isMutable => $composableBuilder(
    column: $table.isMutable,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> ingredientsRefs(
    Expression<bool> Function($$IngredientsTableFilterComposer f) f,
  ) {
    final $$IngredientsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.unitPk,
      referencedTable: $db.ingredients,
      getReferencedColumn: (t) => t.unitFk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IngredientsTableFilterComposer(
            $db: $db,
            $table: $db.ingredients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$UnitsTableOrderingComposer
    extends Composer<_$AppDatabase, $UnitsTable> {
  $$UnitsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get unitPk => $composableBuilder(
    column: $table.unitPk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get factorToBase => $composableBuilder(
    column: $table.factorToBase,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isMutable => $composableBuilder(
    column: $table.isMutable,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UnitsTableAnnotationComposer
    extends Composer<_$AppDatabase, $UnitsTable> {
  $$UnitsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get unitPk =>
      $composableBuilder(column: $table.unitPk, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get symbol =>
      $composableBuilder(column: $table.symbol, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<double> get factorToBase => $composableBuilder(
    column: $table.factorToBase,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isMutable =>
      $composableBuilder(column: $table.isMutable, builder: (column) => column);

  Expression<T> ingredientsRefs<T extends Object>(
    Expression<T> Function($$IngredientsTableAnnotationComposer a) f,
  ) {
    final $$IngredientsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.unitPk,
      referencedTable: $db.ingredients,
      getReferencedColumn: (t) => t.unitFk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IngredientsTableAnnotationComposer(
            $db: $db,
            $table: $db.ingredients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$UnitsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UnitsTable,
          Unit,
          $$UnitsTableFilterComposer,
          $$UnitsTableOrderingComposer,
          $$UnitsTableAnnotationComposer,
          $$UnitsTableCreateCompanionBuilder,
          $$UnitsTableUpdateCompanionBuilder,
          (Unit, $$UnitsTableReferences),
          Unit,
          PrefetchHooks Function({bool ingredientsRefs})
        > {
  $$UnitsTableTableManager(_$AppDatabase db, $UnitsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UnitsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UnitsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UnitsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> unitPk = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> symbol = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<double> factorToBase = const Value.absent(),
                Value<bool> isMutable = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UnitsCompanion(
                unitPk: unitPk,
                name: name,
                symbol: symbol,
                category: category,
                factorToBase: factorToBase,
                isMutable: isMutable,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> unitPk = const Value.absent(),
                required String name,
                required String symbol,
                Value<String?> category = const Value.absent(),
                Value<double> factorToBase = const Value.absent(),
                Value<bool> isMutable = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UnitsCompanion.insert(
                unitPk: unitPk,
                name: name,
                symbol: symbol,
                category: category,
                factorToBase: factorToBase,
                isMutable: isMutable,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$UnitsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({ingredientsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (ingredientsRefs) db.ingredients],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (ingredientsRefs)
                    await $_getPrefetchedData<Unit, $UnitsTable, Ingredient>(
                      currentTable: table,
                      referencedTable: $$UnitsTableReferences
                          ._ingredientsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$UnitsTableReferences(db, table, p0).ingredientsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.unitFk == item.unitPk),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$UnitsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UnitsTable,
      Unit,
      $$UnitsTableFilterComposer,
      $$UnitsTableOrderingComposer,
      $$UnitsTableAnnotationComposer,
      $$UnitsTableCreateCompanionBuilder,
      $$UnitsTableUpdateCompanionBuilder,
      (Unit, $$UnitsTableReferences),
      Unit,
      PrefetchHooks Function({bool ingredientsRefs})
    >;
typedef $$IngredientsTableCreateCompanionBuilder =
    IngredientsCompanion Function({
      Value<String> ingredientPk,
      required String name,
      required double cost,
      required double quantityForCost,
      required String unitFk,
      Value<DateTime> dateCreated,
      Value<DateTime?> dateTimeModified,
      Value<bool> isDeleted,
      Value<DateTime?> deletedAt,
      Value<String?> groupId,
      Value<String?> category,
      Value<double?> currentStock,
      Value<double?> minimumStock,
      Value<String?> stockUnit,
      Value<double?> costPerStockUnit,
      Value<DateTime?> lastStockUpdate,
      Value<int> rowid,
    });
typedef $$IngredientsTableUpdateCompanionBuilder =
    IngredientsCompanion Function({
      Value<String> ingredientPk,
      Value<String> name,
      Value<double> cost,
      Value<double> quantityForCost,
      Value<String> unitFk,
      Value<DateTime> dateCreated,
      Value<DateTime?> dateTimeModified,
      Value<bool> isDeleted,
      Value<DateTime?> deletedAt,
      Value<String?> groupId,
      Value<String?> category,
      Value<double?> currentStock,
      Value<double?> minimumStock,
      Value<String?> stockUnit,
      Value<double?> costPerStockUnit,
      Value<DateTime?> lastStockUpdate,
      Value<int> rowid,
    });

final class $$IngredientsTableReferences
    extends BaseReferences<_$AppDatabase, $IngredientsTable, Ingredient> {
  $$IngredientsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $UnitsTable _unitFkTable(_$AppDatabase db) => db.units.createAlias(
    $_aliasNameGenerator(db.ingredients.unitFk, db.units.unitPk),
  );

  $$UnitsTableProcessedTableManager get unitFk {
    final $_column = $_itemColumn<String>('unit_fk')!;

    final manager = $$UnitsTableTableManager(
      $_db,
      $_db.units,
    ).filter((f) => f.unitPk.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_unitFkTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $GroupsTable _groupIdTable(_$AppDatabase db) => db.groups.createAlias(
    $_aliasNameGenerator(db.ingredients.groupId, db.groups.id),
  );

  $$GroupsTableProcessedTableManager? get groupId {
    final $_column = $_itemColumn<String>('group_id');
    if ($_column == null) return null;
    final manager = $$GroupsTableTableManager(
      $_db,
      $_db.groups,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_groupIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$RecipeIngredientsTable, List<RecipeIngredient>>
  _recipeIngredientsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.recipeIngredients,
        aliasName: $_aliasNameGenerator(
          db.ingredients.ingredientPk,
          db.recipeIngredients.ingredientFk,
        ),
      );

  $$RecipeIngredientsTableProcessedTableManager get recipeIngredientsRefs {
    final manager =
        $$RecipeIngredientsTableTableManager(
          $_db,
          $_db.recipeIngredients,
        ).filter(
          (f) => f.ingredientFk.ingredientPk.sqlEquals(
            $_itemColumn<String>('ingredient_pk')!,
          ),
        );

    final cache = $_typedResult.readTableOrNull(
      _recipeIngredientsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$IngredientsTableFilterComposer
    extends Composer<_$AppDatabase, $IngredientsTable> {
  $$IngredientsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ingredientPk => $composableBuilder(
    column: $table.ingredientPk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get cost => $composableBuilder(
    column: $table.cost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get quantityForCost => $composableBuilder(
    column: $table.quantityForCost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dateCreated => $composableBuilder(
    column: $table.dateCreated,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dateTimeModified => $composableBuilder(
    column: $table.dateTimeModified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get currentStock => $composableBuilder(
    column: $table.currentStock,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get minimumStock => $composableBuilder(
    column: $table.minimumStock,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stockUnit => $composableBuilder(
    column: $table.stockUnit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get costPerStockUnit => $composableBuilder(
    column: $table.costPerStockUnit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastStockUpdate => $composableBuilder(
    column: $table.lastStockUpdate,
    builder: (column) => ColumnFilters(column),
  );

  $$UnitsTableFilterComposer get unitFk {
    final $$UnitsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.unitFk,
      referencedTable: $db.units,
      getReferencedColumn: (t) => t.unitPk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UnitsTableFilterComposer(
            $db: $db,
            $table: $db.units,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$GroupsTableFilterComposer get groupId {
    final $$GroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableFilterComposer(
            $db: $db,
            $table: $db.groups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> recipeIngredientsRefs(
    Expression<bool> Function($$RecipeIngredientsTableFilterComposer f) f,
  ) {
    final $$RecipeIngredientsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ingredientPk,
      referencedTable: $db.recipeIngredients,
      getReferencedColumn: (t) => t.ingredientFk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipeIngredientsTableFilterComposer(
            $db: $db,
            $table: $db.recipeIngredients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$IngredientsTableOrderingComposer
    extends Composer<_$AppDatabase, $IngredientsTable> {
  $$IngredientsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ingredientPk => $composableBuilder(
    column: $table.ingredientPk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get cost => $composableBuilder(
    column: $table.cost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get quantityForCost => $composableBuilder(
    column: $table.quantityForCost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dateCreated => $composableBuilder(
    column: $table.dateCreated,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dateTimeModified => $composableBuilder(
    column: $table.dateTimeModified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get currentStock => $composableBuilder(
    column: $table.currentStock,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get minimumStock => $composableBuilder(
    column: $table.minimumStock,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stockUnit => $composableBuilder(
    column: $table.stockUnit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get costPerStockUnit => $composableBuilder(
    column: $table.costPerStockUnit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastStockUpdate => $composableBuilder(
    column: $table.lastStockUpdate,
    builder: (column) => ColumnOrderings(column),
  );

  $$UnitsTableOrderingComposer get unitFk {
    final $$UnitsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.unitFk,
      referencedTable: $db.units,
      getReferencedColumn: (t) => t.unitPk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UnitsTableOrderingComposer(
            $db: $db,
            $table: $db.units,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$GroupsTableOrderingComposer get groupId {
    final $$GroupsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableOrderingComposer(
            $db: $db,
            $table: $db.groups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$IngredientsTableAnnotationComposer
    extends Composer<_$AppDatabase, $IngredientsTable> {
  $$IngredientsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ingredientPk => $composableBuilder(
    column: $table.ingredientPk,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get cost =>
      $composableBuilder(column: $table.cost, builder: (column) => column);

  GeneratedColumn<double> get quantityForCost => $composableBuilder(
    column: $table.quantityForCost,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get dateCreated => $composableBuilder(
    column: $table.dateCreated,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get dateTimeModified => $composableBuilder(
    column: $table.dateTimeModified,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<double> get currentStock => $composableBuilder(
    column: $table.currentStock,
    builder: (column) => column,
  );

  GeneratedColumn<double> get minimumStock => $composableBuilder(
    column: $table.minimumStock,
    builder: (column) => column,
  );

  GeneratedColumn<String> get stockUnit =>
      $composableBuilder(column: $table.stockUnit, builder: (column) => column);

  GeneratedColumn<double> get costPerStockUnit => $composableBuilder(
    column: $table.costPerStockUnit,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastStockUpdate => $composableBuilder(
    column: $table.lastStockUpdate,
    builder: (column) => column,
  );

  $$UnitsTableAnnotationComposer get unitFk {
    final $$UnitsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.unitFk,
      referencedTable: $db.units,
      getReferencedColumn: (t) => t.unitPk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UnitsTableAnnotationComposer(
            $db: $db,
            $table: $db.units,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$GroupsTableAnnotationComposer get groupId {
    final $$GroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.groupId,
      referencedTable: $db.groups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.groups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> recipeIngredientsRefs<T extends Object>(
    Expression<T> Function($$RecipeIngredientsTableAnnotationComposer a) f,
  ) {
    final $$RecipeIngredientsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.ingredientPk,
          referencedTable: $db.recipeIngredients,
          getReferencedColumn: (t) => t.ingredientFk,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$RecipeIngredientsTableAnnotationComposer(
                $db: $db,
                $table: $db.recipeIngredients,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$IngredientsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $IngredientsTable,
          Ingredient,
          $$IngredientsTableFilterComposer,
          $$IngredientsTableOrderingComposer,
          $$IngredientsTableAnnotationComposer,
          $$IngredientsTableCreateCompanionBuilder,
          $$IngredientsTableUpdateCompanionBuilder,
          (Ingredient, $$IngredientsTableReferences),
          Ingredient,
          PrefetchHooks Function({
            bool unitFk,
            bool groupId,
            bool recipeIngredientsRefs,
          })
        > {
  $$IngredientsTableTableManager(_$AppDatabase db, $IngredientsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$IngredientsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$IngredientsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$IngredientsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> ingredientPk = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> cost = const Value.absent(),
                Value<double> quantityForCost = const Value.absent(),
                Value<String> unitFk = const Value.absent(),
                Value<DateTime> dateCreated = const Value.absent(),
                Value<DateTime?> dateTimeModified = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String?> groupId = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<double?> currentStock = const Value.absent(),
                Value<double?> minimumStock = const Value.absent(),
                Value<String?> stockUnit = const Value.absent(),
                Value<double?> costPerStockUnit = const Value.absent(),
                Value<DateTime?> lastStockUpdate = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => IngredientsCompanion(
                ingredientPk: ingredientPk,
                name: name,
                cost: cost,
                quantityForCost: quantityForCost,
                unitFk: unitFk,
                dateCreated: dateCreated,
                dateTimeModified: dateTimeModified,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                groupId: groupId,
                category: category,
                currentStock: currentStock,
                minimumStock: minimumStock,
                stockUnit: stockUnit,
                costPerStockUnit: costPerStockUnit,
                lastStockUpdate: lastStockUpdate,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> ingredientPk = const Value.absent(),
                required String name,
                required double cost,
                required double quantityForCost,
                required String unitFk,
                Value<DateTime> dateCreated = const Value.absent(),
                Value<DateTime?> dateTimeModified = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String?> groupId = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<double?> currentStock = const Value.absent(),
                Value<double?> minimumStock = const Value.absent(),
                Value<String?> stockUnit = const Value.absent(),
                Value<double?> costPerStockUnit = const Value.absent(),
                Value<DateTime?> lastStockUpdate = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => IngredientsCompanion.insert(
                ingredientPk: ingredientPk,
                name: name,
                cost: cost,
                quantityForCost: quantityForCost,
                unitFk: unitFk,
                dateCreated: dateCreated,
                dateTimeModified: dateTimeModified,
                isDeleted: isDeleted,
                deletedAt: deletedAt,
                groupId: groupId,
                category: category,
                currentStock: currentStock,
                minimumStock: minimumStock,
                stockUnit: stockUnit,
                costPerStockUnit: costPerStockUnit,
                lastStockUpdate: lastStockUpdate,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$IngredientsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                unitFk = false,
                groupId = false,
                recipeIngredientsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (recipeIngredientsRefs) db.recipeIngredients,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (unitFk) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.unitFk,
                                    referencedTable:
                                        $$IngredientsTableReferences
                                            ._unitFkTable(db),
                                    referencedColumn:
                                        $$IngredientsTableReferences
                                            ._unitFkTable(db)
                                            .unitPk,
                                  )
                                  as T;
                        }
                        if (groupId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.groupId,
                                    referencedTable:
                                        $$IngredientsTableReferences
                                            ._groupIdTable(db),
                                    referencedColumn:
                                        $$IngredientsTableReferences
                                            ._groupIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (recipeIngredientsRefs)
                        await $_getPrefetchedData<
                          Ingredient,
                          $IngredientsTable,
                          RecipeIngredient
                        >(
                          currentTable: table,
                          referencedTable: $$IngredientsTableReferences
                              ._recipeIngredientsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$IngredientsTableReferences(
                                db,
                                table,
                                p0,
                              ).recipeIngredientsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.ingredientFk == item.ingredientPk,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$IngredientsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $IngredientsTable,
      Ingredient,
      $$IngredientsTableFilterComposer,
      $$IngredientsTableOrderingComposer,
      $$IngredientsTableAnnotationComposer,
      $$IngredientsTableCreateCompanionBuilder,
      $$IngredientsTableUpdateCompanionBuilder,
      (Ingredient, $$IngredientsTableReferences),
      Ingredient,
      PrefetchHooks Function({
        bool unitFk,
        bool groupId,
        bool recipeIngredientsRefs,
      })
    >;
typedef $$RecipeIngredientsTableCreateCompanionBuilder =
    RecipeIngredientsCompanion Function({
      Value<String> recipeIngredientPk,
      required String recipeFk,
      required String ingredientFk,
      required double amountNeeded,
      Value<DateTime?> dateTimeModified,
      Value<int> rowid,
    });
typedef $$RecipeIngredientsTableUpdateCompanionBuilder =
    RecipeIngredientsCompanion Function({
      Value<String> recipeIngredientPk,
      Value<String> recipeFk,
      Value<String> ingredientFk,
      Value<double> amountNeeded,
      Value<DateTime?> dateTimeModified,
      Value<int> rowid,
    });

final class $$RecipeIngredientsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $RecipeIngredientsTable,
          RecipeIngredient
        > {
  $$RecipeIngredientsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $RecipesTable _recipeFkTable(_$AppDatabase db) =>
      db.recipes.createAlias(
        $_aliasNameGenerator(
          db.recipeIngredients.recipeFk,
          db.recipes.recipePk,
        ),
      );

  $$RecipesTableProcessedTableManager get recipeFk {
    final $_column = $_itemColumn<String>('recipe_fk')!;

    final manager = $$RecipesTableTableManager(
      $_db,
      $_db.recipes,
    ).filter((f) => f.recipePk.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_recipeFkTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $IngredientsTable _ingredientFkTable(_$AppDatabase db) =>
      db.ingredients.createAlias(
        $_aliasNameGenerator(
          db.recipeIngredients.ingredientFk,
          db.ingredients.ingredientPk,
        ),
      );

  $$IngredientsTableProcessedTableManager get ingredientFk {
    final $_column = $_itemColumn<String>('ingredient_fk')!;

    final manager = $$IngredientsTableTableManager(
      $_db,
      $_db.ingredients,
    ).filter((f) => f.ingredientPk.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_ingredientFkTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RecipeIngredientsTableFilterComposer
    extends Composer<_$AppDatabase, $RecipeIngredientsTable> {
  $$RecipeIngredientsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get recipeIngredientPk => $composableBuilder(
    column: $table.recipeIngredientPk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get amountNeeded => $composableBuilder(
    column: $table.amountNeeded,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dateTimeModified => $composableBuilder(
    column: $table.dateTimeModified,
    builder: (column) => ColumnFilters(column),
  );

  $$RecipesTableFilterComposer get recipeFk {
    final $$RecipesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recipeFk,
      referencedTable: $db.recipes,
      getReferencedColumn: (t) => t.recipePk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipesTableFilterComposer(
            $db: $db,
            $table: $db.recipes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$IngredientsTableFilterComposer get ingredientFk {
    final $$IngredientsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ingredientFk,
      referencedTable: $db.ingredients,
      getReferencedColumn: (t) => t.ingredientPk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IngredientsTableFilterComposer(
            $db: $db,
            $table: $db.ingredients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecipeIngredientsTableOrderingComposer
    extends Composer<_$AppDatabase, $RecipeIngredientsTable> {
  $$RecipeIngredientsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get recipeIngredientPk => $composableBuilder(
    column: $table.recipeIngredientPk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get amountNeeded => $composableBuilder(
    column: $table.amountNeeded,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dateTimeModified => $composableBuilder(
    column: $table.dateTimeModified,
    builder: (column) => ColumnOrderings(column),
  );

  $$RecipesTableOrderingComposer get recipeFk {
    final $$RecipesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recipeFk,
      referencedTable: $db.recipes,
      getReferencedColumn: (t) => t.recipePk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipesTableOrderingComposer(
            $db: $db,
            $table: $db.recipes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$IngredientsTableOrderingComposer get ingredientFk {
    final $$IngredientsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ingredientFk,
      referencedTable: $db.ingredients,
      getReferencedColumn: (t) => t.ingredientPk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IngredientsTableOrderingComposer(
            $db: $db,
            $table: $db.ingredients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecipeIngredientsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecipeIngredientsTable> {
  $$RecipeIngredientsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get recipeIngredientPk => $composableBuilder(
    column: $table.recipeIngredientPk,
    builder: (column) => column,
  );

  GeneratedColumn<double> get amountNeeded => $composableBuilder(
    column: $table.amountNeeded,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get dateTimeModified => $composableBuilder(
    column: $table.dateTimeModified,
    builder: (column) => column,
  );

  $$RecipesTableAnnotationComposer get recipeFk {
    final $$RecipesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recipeFk,
      referencedTable: $db.recipes,
      getReferencedColumn: (t) => t.recipePk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipesTableAnnotationComposer(
            $db: $db,
            $table: $db.recipes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$IngredientsTableAnnotationComposer get ingredientFk {
    final $$IngredientsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ingredientFk,
      referencedTable: $db.ingredients,
      getReferencedColumn: (t) => t.ingredientPk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$IngredientsTableAnnotationComposer(
            $db: $db,
            $table: $db.ingredients,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecipeIngredientsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecipeIngredientsTable,
          RecipeIngredient,
          $$RecipeIngredientsTableFilterComposer,
          $$RecipeIngredientsTableOrderingComposer,
          $$RecipeIngredientsTableAnnotationComposer,
          $$RecipeIngredientsTableCreateCompanionBuilder,
          $$RecipeIngredientsTableUpdateCompanionBuilder,
          (RecipeIngredient, $$RecipeIngredientsTableReferences),
          RecipeIngredient,
          PrefetchHooks Function({bool recipeFk, bool ingredientFk})
        > {
  $$RecipeIngredientsTableTableManager(
    _$AppDatabase db,
    $RecipeIngredientsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecipeIngredientsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecipeIngredientsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecipeIngredientsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> recipeIngredientPk = const Value.absent(),
                Value<String> recipeFk = const Value.absent(),
                Value<String> ingredientFk = const Value.absent(),
                Value<double> amountNeeded = const Value.absent(),
                Value<DateTime?> dateTimeModified = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecipeIngredientsCompanion(
                recipeIngredientPk: recipeIngredientPk,
                recipeFk: recipeFk,
                ingredientFk: ingredientFk,
                amountNeeded: amountNeeded,
                dateTimeModified: dateTimeModified,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> recipeIngredientPk = const Value.absent(),
                required String recipeFk,
                required String ingredientFk,
                required double amountNeeded,
                Value<DateTime?> dateTimeModified = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecipeIngredientsCompanion.insert(
                recipeIngredientPk: recipeIngredientPk,
                recipeFk: recipeFk,
                ingredientFk: ingredientFk,
                amountNeeded: amountNeeded,
                dateTimeModified: dateTimeModified,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RecipeIngredientsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({recipeFk = false, ingredientFk = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (recipeFk) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.recipeFk,
                                referencedTable:
                                    $$RecipeIngredientsTableReferences
                                        ._recipeFkTable(db),
                                referencedColumn:
                                    $$RecipeIngredientsTableReferences
                                        ._recipeFkTable(db)
                                        .recipePk,
                              )
                              as T;
                    }
                    if (ingredientFk) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.ingredientFk,
                                referencedTable:
                                    $$RecipeIngredientsTableReferences
                                        ._ingredientFkTable(db),
                                referencedColumn:
                                    $$RecipeIngredientsTableReferences
                                        ._ingredientFkTable(db)
                                        .ingredientPk,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RecipeIngredientsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecipeIngredientsTable,
      RecipeIngredient,
      $$RecipeIngredientsTableFilterComposer,
      $$RecipeIngredientsTableOrderingComposer,
      $$RecipeIngredientsTableAnnotationComposer,
      $$RecipeIngredientsTableCreateCompanionBuilder,
      $$RecipeIngredientsTableUpdateCompanionBuilder,
      (RecipeIngredient, $$RecipeIngredientsTableReferences),
      RecipeIngredient,
      PrefetchHooks Function({bool recipeFk, bool ingredientFk})
    >;
typedef $$RecipeStepsTableCreateCompanionBuilder =
    RecipeStepsCompanion Function({
      Value<String> stepPk,
      required String recipeFk,
      required int stepNumber,
      required String instruction,
      Value<DateTime?> dateTimeModified,
      Value<int> rowid,
    });
typedef $$RecipeStepsTableUpdateCompanionBuilder =
    RecipeStepsCompanion Function({
      Value<String> stepPk,
      Value<String> recipeFk,
      Value<int> stepNumber,
      Value<String> instruction,
      Value<DateTime?> dateTimeModified,
      Value<int> rowid,
    });

final class $$RecipeStepsTableReferences
    extends BaseReferences<_$AppDatabase, $RecipeStepsTable, RecipeStep> {
  $$RecipeStepsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RecipesTable _recipeFkTable(_$AppDatabase db) =>
      db.recipes.createAlias(
        $_aliasNameGenerator(db.recipeSteps.recipeFk, db.recipes.recipePk),
      );

  $$RecipesTableProcessedTableManager get recipeFk {
    final $_column = $_itemColumn<String>('recipe_fk')!;

    final manager = $$RecipesTableTableManager(
      $_db,
      $_db.recipes,
    ).filter((f) => f.recipePk.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_recipeFkTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RecipeStepsTableFilterComposer
    extends Composer<_$AppDatabase, $RecipeStepsTable> {
  $$RecipeStepsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get stepPk => $composableBuilder(
    column: $table.stepPk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stepNumber => $composableBuilder(
    column: $table.stepNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get instruction => $composableBuilder(
    column: $table.instruction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dateTimeModified => $composableBuilder(
    column: $table.dateTimeModified,
    builder: (column) => ColumnFilters(column),
  );

  $$RecipesTableFilterComposer get recipeFk {
    final $$RecipesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recipeFk,
      referencedTable: $db.recipes,
      getReferencedColumn: (t) => t.recipePk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipesTableFilterComposer(
            $db: $db,
            $table: $db.recipes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecipeStepsTableOrderingComposer
    extends Composer<_$AppDatabase, $RecipeStepsTable> {
  $$RecipeStepsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get stepPk => $composableBuilder(
    column: $table.stepPk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stepNumber => $composableBuilder(
    column: $table.stepNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get instruction => $composableBuilder(
    column: $table.instruction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dateTimeModified => $composableBuilder(
    column: $table.dateTimeModified,
    builder: (column) => ColumnOrderings(column),
  );

  $$RecipesTableOrderingComposer get recipeFk {
    final $$RecipesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recipeFk,
      referencedTable: $db.recipes,
      getReferencedColumn: (t) => t.recipePk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipesTableOrderingComposer(
            $db: $db,
            $table: $db.recipes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecipeStepsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecipeStepsTable> {
  $$RecipeStepsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get stepPk =>
      $composableBuilder(column: $table.stepPk, builder: (column) => column);

  GeneratedColumn<int> get stepNumber => $composableBuilder(
    column: $table.stepNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get instruction => $composableBuilder(
    column: $table.instruction,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get dateTimeModified => $composableBuilder(
    column: $table.dateTimeModified,
    builder: (column) => column,
  );

  $$RecipesTableAnnotationComposer get recipeFk {
    final $$RecipesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recipeFk,
      referencedTable: $db.recipes,
      getReferencedColumn: (t) => t.recipePk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipesTableAnnotationComposer(
            $db: $db,
            $table: $db.recipes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecipeStepsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecipeStepsTable,
          RecipeStep,
          $$RecipeStepsTableFilterComposer,
          $$RecipeStepsTableOrderingComposer,
          $$RecipeStepsTableAnnotationComposer,
          $$RecipeStepsTableCreateCompanionBuilder,
          $$RecipeStepsTableUpdateCompanionBuilder,
          (RecipeStep, $$RecipeStepsTableReferences),
          RecipeStep,
          PrefetchHooks Function({bool recipeFk})
        > {
  $$RecipeStepsTableTableManager(_$AppDatabase db, $RecipeStepsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecipeStepsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecipeStepsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecipeStepsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> stepPk = const Value.absent(),
                Value<String> recipeFk = const Value.absent(),
                Value<int> stepNumber = const Value.absent(),
                Value<String> instruction = const Value.absent(),
                Value<DateTime?> dateTimeModified = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecipeStepsCompanion(
                stepPk: stepPk,
                recipeFk: recipeFk,
                stepNumber: stepNumber,
                instruction: instruction,
                dateTimeModified: dateTimeModified,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<String> stepPk = const Value.absent(),
                required String recipeFk,
                required int stepNumber,
                required String instruction,
                Value<DateTime?> dateTimeModified = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecipeStepsCompanion.insert(
                stepPk: stepPk,
                recipeFk: recipeFk,
                stepNumber: stepNumber,
                instruction: instruction,
                dateTimeModified: dateTimeModified,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RecipeStepsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({recipeFk = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (recipeFk) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.recipeFk,
                                referencedTable: $$RecipeStepsTableReferences
                                    ._recipeFkTable(db),
                                referencedColumn: $$RecipeStepsTableReferences
                                    ._recipeFkTable(db)
                                    .recipePk,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RecipeStepsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecipeStepsTable,
      RecipeStep,
      $$RecipeStepsTableFilterComposer,
      $$RecipeStepsTableOrderingComposer,
      $$RecipeStepsTableAnnotationComposer,
      $$RecipeStepsTableCreateCompanionBuilder,
      $$RecipeStepsTableUpdateCompanionBuilder,
      (RecipeStep, $$RecipeStepsTableReferences),
      RecipeStep,
      PrefetchHooks Function({bool recipeFk})
    >;
typedef $$CategoriesTableCreateCompanionBuilder =
    CategoriesCompanion Function({
      required String id,
      required String name,
      Value<String?> iconName,
      Value<int> rowid,
    });
typedef $$CategoriesTableUpdateCompanionBuilder =
    CategoriesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> iconName,
      Value<int> rowid,
    });

class $$CategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get iconName => $composableBuilder(
    column: $table.iconName,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get iconName => $composableBuilder(
    column: $table.iconName,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get iconName =>
      $composableBuilder(column: $table.iconName, builder: (column) => column);
}

class $$CategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CategoriesTable,
          Category,
          $$CategoriesTableFilterComposer,
          $$CategoriesTableOrderingComposer,
          $$CategoriesTableAnnotationComposer,
          $$CategoriesTableCreateCompanionBuilder,
          $$CategoriesTableUpdateCompanionBuilder,
          (Category, BaseReferences<_$AppDatabase, $CategoriesTable, Category>),
          Category,
          PrefetchHooks Function()
        > {
  $$CategoriesTableTableManager(_$AppDatabase db, $CategoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> iconName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion(
                id: id,
                name: name,
                iconName: iconName,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> iconName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CategoriesCompanion.insert(
                id: id,
                name: name,
                iconName: iconName,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CategoriesTable,
      Category,
      $$CategoriesTableFilterComposer,
      $$CategoriesTableOrderingComposer,
      $$CategoriesTableAnnotationComposer,
      $$CategoriesTableCreateCompanionBuilder,
      $$CategoriesTableUpdateCompanionBuilder,
      (Category, BaseReferences<_$AppDatabase, $CategoriesTable, Category>),
      Category,
      PrefetchHooks Function()
    >;
typedef $$RecipeSpacesTableCreateCompanionBuilder =
    RecipeSpacesCompanion Function({
      required String recipeId,
      required String spaceId,
      Value<DateTime> createdAt,
      Value<bool> isDeleted,
      Value<int> rowid,
    });
typedef $$RecipeSpacesTableUpdateCompanionBuilder =
    RecipeSpacesCompanion Function({
      Value<String> recipeId,
      Value<String> spaceId,
      Value<DateTime> createdAt,
      Value<bool> isDeleted,
      Value<int> rowid,
    });

final class $$RecipeSpacesTableReferences
    extends BaseReferences<_$AppDatabase, $RecipeSpacesTable, RecipeSpace> {
  $$RecipeSpacesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RecipesTable _recipeIdTable(_$AppDatabase db) =>
      db.recipes.createAlias(
        $_aliasNameGenerator(db.recipeSpaces.recipeId, db.recipes.recipePk),
      );

  $$RecipesTableProcessedTableManager get recipeId {
    final $_column = $_itemColumn<String>('recipe_id')!;

    final manager = $$RecipesTableTableManager(
      $_db,
      $_db.recipes,
    ).filter((f) => f.recipePk.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_recipeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $GroupsTable _spaceIdTable(_$AppDatabase db) => db.groups.createAlias(
    $_aliasNameGenerator(db.recipeSpaces.spaceId, db.groups.id),
  );

  $$GroupsTableProcessedTableManager get spaceId {
    final $_column = $_itemColumn<String>('space_id')!;

    final manager = $$GroupsTableTableManager(
      $_db,
      $_db.groups,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_spaceIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RecipeSpacesTableFilterComposer
    extends Composer<_$AppDatabase, $RecipeSpacesTable> {
  $$RecipeSpacesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  $$RecipesTableFilterComposer get recipeId {
    final $$RecipesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recipeId,
      referencedTable: $db.recipes,
      getReferencedColumn: (t) => t.recipePk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipesTableFilterComposer(
            $db: $db,
            $table: $db.recipes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$GroupsTableFilterComposer get spaceId {
    final $$GroupsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.spaceId,
      referencedTable: $db.groups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableFilterComposer(
            $db: $db,
            $table: $db.groups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecipeSpacesTableOrderingComposer
    extends Composer<_$AppDatabase, $RecipeSpacesTable> {
  $$RecipeSpacesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  $$RecipesTableOrderingComposer get recipeId {
    final $$RecipesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recipeId,
      referencedTable: $db.recipes,
      getReferencedColumn: (t) => t.recipePk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipesTableOrderingComposer(
            $db: $db,
            $table: $db.recipes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$GroupsTableOrderingComposer get spaceId {
    final $$GroupsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.spaceId,
      referencedTable: $db.groups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableOrderingComposer(
            $db: $db,
            $table: $db.groups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecipeSpacesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecipeSpacesTable> {
  $$RecipeSpacesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  $$RecipesTableAnnotationComposer get recipeId {
    final $$RecipesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recipeId,
      referencedTable: $db.recipes,
      getReferencedColumn: (t) => t.recipePk,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecipesTableAnnotationComposer(
            $db: $db,
            $table: $db.recipes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$GroupsTableAnnotationComposer get spaceId {
    final $$GroupsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.spaceId,
      referencedTable: $db.groups,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GroupsTableAnnotationComposer(
            $db: $db,
            $table: $db.groups,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecipeSpacesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecipeSpacesTable,
          RecipeSpace,
          $$RecipeSpacesTableFilterComposer,
          $$RecipeSpacesTableOrderingComposer,
          $$RecipeSpacesTableAnnotationComposer,
          $$RecipeSpacesTableCreateCompanionBuilder,
          $$RecipeSpacesTableUpdateCompanionBuilder,
          (RecipeSpace, $$RecipeSpacesTableReferences),
          RecipeSpace,
          PrefetchHooks Function({bool recipeId, bool spaceId})
        > {
  $$RecipeSpacesTableTableManager(_$AppDatabase db, $RecipeSpacesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecipeSpacesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecipeSpacesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecipeSpacesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> recipeId = const Value.absent(),
                Value<String> spaceId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecipeSpacesCompanion(
                recipeId: recipeId,
                spaceId: spaceId,
                createdAt: createdAt,
                isDeleted: isDeleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String recipeId,
                required String spaceId,
                Value<DateTime> createdAt = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecipeSpacesCompanion.insert(
                recipeId: recipeId,
                spaceId: spaceId,
                createdAt: createdAt,
                isDeleted: isDeleted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RecipeSpacesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({recipeId = false, spaceId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (recipeId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.recipeId,
                                referencedTable: $$RecipeSpacesTableReferences
                                    ._recipeIdTable(db),
                                referencedColumn: $$RecipeSpacesTableReferences
                                    ._recipeIdTable(db)
                                    .recipePk,
                              )
                              as T;
                    }
                    if (spaceId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.spaceId,
                                referencedTable: $$RecipeSpacesTableReferences
                                    ._spaceIdTable(db),
                                referencedColumn: $$RecipeSpacesTableReferences
                                    ._spaceIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RecipeSpacesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecipeSpacesTable,
      RecipeSpace,
      $$RecipeSpacesTableFilterComposer,
      $$RecipeSpacesTableOrderingComposer,
      $$RecipeSpacesTableAnnotationComposer,
      $$RecipeSpacesTableCreateCompanionBuilder,
      $$RecipeSpacesTableUpdateCompanionBuilder,
      (RecipeSpace, $$RecipeSpacesTableReferences),
      RecipeSpace,
      PrefetchHooks Function({bool recipeId, bool spaceId})
    >;
typedef $$DeletedRecordsTableCreateCompanionBuilder =
    DeletedRecordsCompanion Function({
      required String recordPk,
      required String entityType,
      required DateTime deletedAt,
      Value<int> rowid,
    });
typedef $$DeletedRecordsTableUpdateCompanionBuilder =
    DeletedRecordsCompanion Function({
      Value<String> recordPk,
      Value<String> entityType,
      Value<DateTime> deletedAt,
      Value<int> rowid,
    });

class $$DeletedRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $DeletedRecordsTable> {
  $$DeletedRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get recordPk => $composableBuilder(
    column: $table.recordPk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DeletedRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $DeletedRecordsTable> {
  $$DeletedRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get recordPk => $composableBuilder(
    column: $table.recordPk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DeletedRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DeletedRecordsTable> {
  $$DeletedRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get recordPk =>
      $composableBuilder(column: $table.recordPk, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$DeletedRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DeletedRecordsTable,
          DeletedRecord,
          $$DeletedRecordsTableFilterComposer,
          $$DeletedRecordsTableOrderingComposer,
          $$DeletedRecordsTableAnnotationComposer,
          $$DeletedRecordsTableCreateCompanionBuilder,
          $$DeletedRecordsTableUpdateCompanionBuilder,
          (
            DeletedRecord,
            BaseReferences<_$AppDatabase, $DeletedRecordsTable, DeletedRecord>,
          ),
          DeletedRecord,
          PrefetchHooks Function()
        > {
  $$DeletedRecordsTableTableManager(
    _$AppDatabase db,
    $DeletedRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeletedRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeletedRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeletedRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> recordPk = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<DateTime> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DeletedRecordsCompanion(
                recordPk: recordPk,
                entityType: entityType,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String recordPk,
                required String entityType,
                required DateTime deletedAt,
                Value<int> rowid = const Value.absent(),
              }) => DeletedRecordsCompanion.insert(
                recordPk: recordPk,
                entityType: entityType,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DeletedRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DeletedRecordsTable,
      DeletedRecord,
      $$DeletedRecordsTableFilterComposer,
      $$DeletedRecordsTableOrderingComposer,
      $$DeletedRecordsTableAnnotationComposer,
      $$DeletedRecordsTableCreateCompanionBuilder,
      $$DeletedRecordsTableUpdateCompanionBuilder,
      (
        DeletedRecord,
        BaseReferences<_$AppDatabase, $DeletedRecordsTable, DeletedRecord>,
      ),
      DeletedRecord,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$GroupsTableTableManager get groups =>
      $$GroupsTableTableManager(_db, _db.groups);
  $$RecipesTableTableManager get recipes =>
      $$RecipesTableTableManager(_db, _db.recipes);
  $$UnitsTableTableManager get units =>
      $$UnitsTableTableManager(_db, _db.units);
  $$IngredientsTableTableManager get ingredients =>
      $$IngredientsTableTableManager(_db, _db.ingredients);
  $$RecipeIngredientsTableTableManager get recipeIngredients =>
      $$RecipeIngredientsTableTableManager(_db, _db.recipeIngredients);
  $$RecipeStepsTableTableManager get recipeSteps =>
      $$RecipeStepsTableTableManager(_db, _db.recipeSteps);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$RecipeSpacesTableTableManager get recipeSpaces =>
      $$RecipeSpacesTableTableManager(_db, _db.recipeSpaces);
  $$DeletedRecordsTableTableManager get deletedRecords =>
      $$DeletedRecordsTableTableManager(_db, _db.deletedRecords);
}
