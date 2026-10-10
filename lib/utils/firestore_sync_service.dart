import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database.dart';
import '../database/sample_manufacturing_recipe.dart';
import '../constants.dart';

/// Service responsible for purely manual, on-demand, differential cross-platform sync
/// with Cloud Firestore. Optimized for Firebase Spark plan limits by embedding
/// ingredients/steps into recipe documents and batching writes.
class FirestoreSyncService {
  final FirebaseFirestore? _firestoreOverride;
  final FirebaseAuth? _authOverride;

  FirestoreSyncService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestoreOverride = firestore,
        _authOverride = auth;

  FirebaseFirestore get _firestore => _firestoreOverride ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  static const String prefLastSyncKey = 'firestore_last_synced_at';
  static const String prefUserIdKey = 'firestore_sync_user_id';
  static const String defaultFirebaseWebClientId =
      '194514517992-vcj4bbuljsrea1qaoathcc3a2ssg5ush.apps.googleusercontent.com';

  /// Whether Firebase has been initialized in the current runtime environment.
  bool get isConfigured {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Current user in FirebaseAuth, if any.
  User? get authCurrentUser {
    try {
      if (isConfigured) {
        return _auth.currentUser;
      }
    } catch (_) {}
    return null;
  }

  /// Retrieves the active user ID for synchronization.
  /// Prioritizes authenticated user UID, followed by stored custom Sync ID.
  Future<String?> getActiveUserId() async {
    try {
      if (isConfigured && _auth.currentUser != null) {
        return _auth.currentUser!.uid;
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(prefUserIdKey);
  }

  /// Sets a custom sync user ID (allows manual pairing between devices).
  Future<void> setCustomUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefUserIdKey, userId.trim());
  }

  /// Clears the stored custom sync user ID.
  Future<void> clearCustomUserId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefUserIdKey);
  }

  /// Gets the last synced timestamp for this user.
  Future<DateTime?> getLastSyncedAt(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('${prefLastSyncKey}_$userId');
    return str != null ? DateTime.tryParse(str) : null;
  }

  /// Resets the last synced timestamp (forces full differential re-sync next time).
  Future<void> clearLastSyncedAt(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${prefLastSyncKey}_$userId');
  }

  bool _persistenceInitialized = false;

  /// Initializes offline persistence if supported on this platform.
  Future<void> initPersistence() async {
    if (_persistenceInitialized || kIsWeb) return;
    _persistenceInitialized = true;
    try {
      _firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (e) {
      debugPrint('Firestore persistence setting notice: $e');
    }
  }


  /// Signs in with Email and Password.
  Future<UserCredential> signInWithEmail(String email, String password) async {
    if (!isConfigured) {
      throw StateError('Firebase is not initialized. Please configure firebase_options.dart.');
    }
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = cred.user?.uid;
    if (uid != null) {
      await setCustomUserId(uid);
    }
    return cred;
  }

  /// Registers a new account with Email and Password.
  Future<UserCredential> registerWithEmail(String email, String password) async {
    if (!isConfigured) {
      throw StateError('Firebase is not initialized. Please configure firebase_options.dart.');
    }
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final uid = cred.user?.uid;
    if (uid != null) {
      await setCustomUserId(uid);
    }
    return cred;
  }

  /// Sends a password reset email.
  Future<void> sendPasswordReset(String email) async {
    if (!isConfigured) {
      throw StateError('Firebase is not initialized. Please configure firebase_options.dart.');
    }
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Signs in with Google account (native popup on web, GoogleSignIn on mobile).
  Future<UserCredential?> signInWithGoogle() async {
    if (!isConfigured) {
      throw StateError('Firebase is not initialized. Please configure firebase_options.dart.');
    }
    UserCredential cred;
    if (kIsWeb) {
      final googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      googleProvider.setCustomParameters({'prompt': 'select_account'});
      cred = await _auth.signInWithPopup(googleProvider);
    } else {
      await GoogleSignIn.instance.initialize(
        serverClientId: defaultFirebaseWebClientId,
      );
      final googleUser = await GoogleSignIn.instance.authenticate();
      final auth = googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: auth.idToken,
      );
      cred = await _auth.signInWithCredential(credential);
    }
    final uid = cred.user?.uid;
    if (uid != null) {
      await setCustomUserId(uid);
    }
    return cred;
  }

  /// Disconnects from Firebase Auth and clears the stored Sync ID.
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (_) {}
    await clearCustomUserId();
  }

  /// Connects with Google account using existing GoogleSignInAccount credential.
  Future<String?> linkGoogleAccount(GoogleSignInAccount googleUser) async {
    if (!isConfigured) {
      throw StateError('Firebase is not initialized. Please configure firebase_options.dart.');
    }
    final auth = googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: auth.idToken,
    );
    final userCred = await _auth.signInWithCredential(credential);
    final uid = userCred.user?.uid;
    if (uid != null) {
      await setCustomUserId(uid);
    }
    return uid;
  }

  // ---------------------------------------------------------------------------
  // Serialization & Deserialization (Spark-plan optimized: embedded children)
  // ---------------------------------------------------------------------------

  static DateTime _parseDate(dynamic val) {
    if (val == null) return DateTime.now();
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
    if (val is num) return DateTime.fromMillisecondsSinceEpoch(val.toInt());
    return DateTime.now();
  }

  static DateTime? _parseNullableDate(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is String) return DateTime.tryParse(val);
    if (val is num) return DateTime.fromMillisecondsSinceEpoch(val.toInt());
    return null;
  }

  /// Serializes a [RecipeDetail] into a single Firestore document map, embedding
  /// all ingredients and steps directly to avoid separate document reads/writes.
  static Map<String, dynamic> recipeToFirestore(RecipeDetail detail) {
    final r = detail.recipe;
    final updatedAt = r.dateTimeModified ?? r.dateCreated;
    return {
      'recipePk': r.recipePk,
      'name': r.name,
      'description': r.description,
      'defaultYield': r.defaultYield,
      'yieldName': r.yieldName,
      'targetProfitMargin': r.targetProfitMargin,
      'targetPricePerPortion': r.targetPricePerPortion,
      'fixedOverheadCost': r.fixedOverheadCost,
      'colour': r.colour,
      'dateCreated': r.dateCreated.toIso8601String(),
      'dateTimeModified': r.dateTimeModified?.toIso8601String(),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'archived': r.archived,
      'ingredients': detail.ingredients.map((ri) => {
        'recipeIngredientPk': ri.entry.recipeIngredientPk,
        'recipeFk': ri.entry.recipeFk,
        'ingredientFk': ri.entry.ingredientFk,
        'amountNeeded': ri.entry.amountNeeded,
        'dateTimeModified': ri.entry.dateTimeModified?.toIso8601String(),
        'name': ri.ingredient.name,
        'cost': ri.ingredient.cost,
        'quantityForCost': ri.ingredient.quantityForCost,
        'unitFk': ri.ingredient.unitFk,
        'dateCreated': ri.ingredient.dateCreated.toIso8601String(),
        'ingredientDateTimeModified': ri.ingredient.dateTimeModified?.toIso8601String(),
      }).toList(),
      'steps': detail.steps.map((st) => {
        'stepPk': st.stepPk,
        'recipeFk': st.recipeFk,
        'stepNumber': st.stepNumber,
        'instruction': st.instruction,
        'dateTimeModified': st.dateTimeModified?.toIso8601String(),
      }).toList(),
    };
  }

  /// Parses a remote recipe document with embedded ingredients and steps.
  static ({
    Recipe recipe,
    List<RecipeIngredient> ingredients,
    List<RecipeStep> steps,
    List<Ingredient> nestedIngredients,
  }) recipeFromFirestore(
      Map<String, dynamic> d, {String fallbackId = ''}) {
    final pk = (d['recipePk'] as String?) ?? fallbackId;
    final recipe = Recipe(
      recipePk: pk.isNotEmpty ? pk : 'recipe_${DateTime.now().millisecondsSinceEpoch}',
      name: (d['name'] as String?) ?? 'Sin título',
      description: d['description'] as String?,
      defaultYield: (d['defaultYield'] as num?)?.toDouble() ?? 1.0,
      yieldName: (d['yieldName'] as String?) ?? 'porciones',
      targetProfitMargin: (d['targetProfitMargin'] as num?)?.toDouble() ?? 0.0,
      targetPricePerPortion: (d['targetPricePerPortion'] as num?)?.toDouble() ?? 0.0,
      fixedOverheadCost: (d['fixedOverheadCost'] as num?)?.toDouble() ?? 0.0,
      colour: d['colour'] as String?,
      dateCreated: _parseDate(d['dateCreated']),
      dateTimeModified: _parseNullableDate(d['dateTimeModified']),
      archived: d['archived'] as bool? ?? false,
    );

    final rawIngredients = (d['ingredients'] as List<dynamic>?) ?? [];
    final ingredients = <RecipeIngredient>[];
    final nestedIngredients = <Ingredient>[];

    for (final raw in rawIngredients) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      final recipeFk = (m['recipeFk'] as String?) ?? recipe.recipePk;
      final ingredientFk = (m['ingredientFk'] as String?) ?? '';
      final riPk = (m['recipeIngredientPk'] as String?) ?? '${recipeFk}_$ingredientFk';

      final ri = RecipeIngredient(
        recipeIngredientPk: riPk,
        recipeFk: recipeFk,
        ingredientFk: ingredientFk,
        amountNeeded: (m['amountNeeded'] as num?)?.toDouble() ?? 1.0,
        dateTimeModified: _parseNullableDate(m['dateTimeModified']),
      );
      ingredients.add(ri);

      final ingMap = (m['ingredient'] as Map<String, dynamic>?) ?? m;
      if (ingMap.containsKey('name') && ingMap['name'] != null) {
        final ingPk = (ingMap['ingredientPk'] ?? ingredientFk) as String;
        if (ingPk.isNotEmpty) {
          nestedIngredients.add(
            Ingredient(
              ingredientPk: ingPk,
              name: (ingMap['name'] as String?) ?? 'Ingrediente',
              cost: (ingMap['cost'] as num?)?.toDouble() ?? 0.0,
              quantityForCost: (ingMap['quantityForCost'] as num?)?.toDouble() ?? 1.0,
              unitFk: (ingMap['unitFk'] as String?) ?? 'unit-g',
              dateCreated: _parseDate(ingMap['dateCreated']),
              dateTimeModified: _parseNullableDate(
                ingMap['dateTimeModified'] ?? ingMap['ingredientDateTimeModified'],
              ),
            ),
          );
        }
      }
    }

    final rawSteps = (d['steps'] as List<dynamic>?) ?? [];
    final steps = <RecipeStep>[];
    int defaultStepNumber = 1;
    for (final raw in rawSteps) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      final stepPk = (m['stepPk'] as String?) ?? '${recipe.recipePk}_step_$defaultStepNumber';
      steps.add(
        RecipeStep(
          stepPk: stepPk,
          recipeFk: (m['recipeFk'] as String?) ?? recipe.recipePk,
          stepNumber: (m['stepNumber'] as num?)?.toInt() ?? defaultStepNumber,
          instruction: (m['instruction'] as String?) ?? '',
          dateTimeModified: _parseNullableDate(m['dateTimeModified']),
        ),
      );
      defaultStepNumber++;
    }

    return (
      recipe: recipe,
      ingredients: ingredients,
      steps: steps,
      nestedIngredients: nestedIngredients,
    );
  }

  /// Serializes an [Ingredient] into Firestore format.
  static Map<String, dynamic> ingredientToFirestore(Ingredient ing) {
    final updatedAt = ing.dateTimeModified ?? ing.dateCreated;
    return {
      'ingredientPk': ing.ingredientPk,
      'name': ing.name,
      'cost': ing.cost,
      'quantityForCost': ing.quantityForCost,
      'unitFk': ing.unitFk,
      'dateCreated': ing.dateCreated.toIso8601String(),
      'dateTimeModified': ing.dateTimeModified?.toIso8601String(),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Parses an [Ingredient] from Firestore format.
  static Ingredient ingredientFromFirestore(Map<String, dynamic> d, {String fallbackId = ''}) {
    final pk = (d['ingredientPk'] as String?) ?? fallbackId;
    return Ingredient(
      ingredientPk: pk.isNotEmpty ? pk : 'ing_${DateTime.now().millisecondsSinceEpoch}',
      name: (d['name'] as String?) ?? 'Ingrediente',
      cost: (d['cost'] as num?)?.toDouble() ?? 0.0,
      quantityForCost: (d['quantityForCost'] as num?)?.toDouble() ?? 1.0,
      unitFk: (d['unitFk'] as String?) ?? 'unit-g',
      dateCreated: _parseDate(d['dateCreated']),
      dateTimeModified: _parseNullableDate(d['dateTimeModified']),
    );
  }

  /// Serializes a custom [Unit] into Firestore format.
  static Map<String, dynamic> unitToFirestore(Unit u) {
    return {
      'unitPk': u.unitPk,
      'name': u.name,
      'symbol': u.symbol,
      'category': u.category,
      'factorToBase': u.factorToBase,
      'isMutable': u.isMutable,
    };
  }

  /// Parses a [Unit] from Firestore format.
  static Unit unitFromFirestore(Map<String, dynamic> d, {String fallbackId = ''}) {
    final pk = (d['unitPk'] as String?) ?? fallbackId;
    return Unit(
      unitPk: pk.isNotEmpty ? pk : 'unit_${DateTime.now().millisecondsSinceEpoch}',
      name: (d['name'] as String?) ?? 'Unidad',
      symbol: (d['symbol'] as String?) ?? 'u',
      category: d['category'] as String?,
      factorToBase: (d['factorToBase'] as num?)?.toDouble() ?? 1.0,
      isMutable: d['isMutable'] as bool? ?? false,
    );
  }

  /// Saves/upserts a recipe and its nested ingredients directly to Firestore.
  Future<void> saveRecipe(RecipeDetail detail, {String? userId}) async {
    if (isSampleManufacturingRecipe(detail.recipe.recipePk)) return;
    if (!isConfigured) return;
    final activeUid = userId ?? await getActiveUserId();
    if (activeUid == null || activeUid.isEmpty) return;

    await initPersistence();

    final userDoc = _firestore.collection('users').doc(activeUid);
    final recipeDoc = userDoc.collection('recipes').doc(detail.recipe.recipePk);
    final data = recipeToFirestore(detail);

    final batch = _firestore.batch();
    batch.set(recipeDoc, data, SetOptions(merge: true));

    // Also update/upsert the nested ingredients in the cloud ingredients subcollection
    for (final ri in detail.ingredients) {
      final ingDoc = userDoc.collection('ingredients').doc(ri.ingredient.ingredientPk);
      batch.set(ingDoc, ingredientToFirestore(ri.ingredient), SetOptions(merge: true));
    }

    await batch.commit();
  }

  /// Force overwrites the cloud data with the complete local SQLite dataset.
  /// Deletes existing remote documents in recipes, ingredients, and custom units,
  /// and uploads all local records directly.
  Future<SyncMergeResult> forceOverwriteCloud({
    required AppDatabase db,
    String? userId,
  }) async {
    if (!isConfigured) {
      throw StateError('Firebase is not configured. Please complete Firebase setup.');
    }

    final activeUid = userId ?? await getActiveUserId();
    if (activeUid == null || activeUid.isEmpty) {
      throw StateError('No active user or sync ID found. Please sign in or set a Sync ID.');
    }

    await initPersistence();

    final prefs = await SharedPreferences.getInstance();
    final syncStartTime = DateTime.now().toUtc();

    final userDoc = _firestore.collection('users').doc(activeUid);
    final recipesCol = userDoc.collection('recipes');
    final ingsCol = userDoc.collection('ingredients');
    final unitsCol = userDoc.collection('units');

    // 1. Delete all existing remote units, ingredients, and recipes
    final remoteUnitsSnap = await unitsCol.get();
    final remoteIngsSnap = await ingsCol.get();
    final remoteRecipesSnap = await recipesCol.get();

    WriteBatch batch = _firestore.batch();
    int opCount = 0;

    for (final doc in remoteUnitsSnap.docs) {
      batch.delete(doc.reference);
      opCount++;
      if (opCount >= 400) {
        await batch.commit();
        batch = _firestore.batch();
        opCount = 0;
      }
    }

    for (final doc in remoteIngsSnap.docs) {
      batch.delete(doc.reference);
      opCount++;
      if (opCount >= 400) {
        await batch.commit();
        batch = _firestore.batch();
        opCount = 0;
      }
    }

    for (final doc in remoteRecipesSnap.docs) {
      batch.delete(doc.reference);
      opCount++;
      if (opCount >= 400) {
        await batch.commit();
        batch = _firestore.batch();
        opCount = 0;
      }
    }

    if (opCount > 0) {
      await batch.commit();
      batch = _firestore.batch();
      opCount = 0;
    }

    // 2. Fetch all local units, ingredients, and recipes
    final allUnits = await db.getAllUnits();
    final allIngs = await db.getAllIngredients();
    final allRecipeDetails = (await db.getAllRecipeDetails())
        .where((r) => !isSampleManufacturingRecipe(r.recipe.recipePk))
        .toList();

    // 3. Upload all units
    for (final unit in allUnits) {
      final docRef = unitsCol.doc(unit.unitPk);
      final data = unitToFirestore(unit);
      data['updatedAt'] = Timestamp.fromDate(syncStartTime);
      batch.set(docRef, data);
      opCount++;
      if (opCount >= 400) {
        await batch.commit();
        batch = _firestore.batch();
        opCount = 0;
      }
    }

    // 4. Upload all ingredients
    for (final ing in allIngs) {
      final docRef = ingsCol.doc(ing.ingredientPk);
      final data = ingredientToFirestore(ing);
      batch.set(docRef, data);
      opCount++;
      if (opCount >= 400) {
        await batch.commit();
        batch = _firestore.batch();
        opCount = 0;
      }
    }

    // 5. Upload all recipes
    for (final rd in allRecipeDetails) {
      final docRef = recipesCol.doc(rd.recipe.recipePk);
      final data = recipeToFirestore(rd);
      batch.set(docRef, data);
      opCount++;
      if (opCount >= 400) {
        await batch.commit();
        batch = _firestore.batch();
        opCount = 0;
      }
    }

    // Metadata
    final metaRef = userDoc.collection('sync_meta').doc('status');
    batch.set(metaRef, {
      'lastSyncTimestamp': Timestamp.fromDate(syncStartTime),
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'appVersion': kAppVersion,
      'forceOverwritten': true,
    }, SetOptions(merge: true));
    opCount++;

    if (opCount > 0) {
      await batch.commit();
    }

    // 6. Record lastSyncedAt
    await prefs.setString('${prefLastSyncKey}_$activeUid', syncStartTime.toIso8601String());

    return SyncMergeResult(
      recipesAdded: allRecipeDetails.length,
      recipesUpdated: 0,
      recipesKeptLocal: 0,
      ingredientsAdded: allIngs.length,
      ingredientsUpdated: 0,
    );
  }

  // ---------------------------------------------------------------------------
  // Two-Way Differential Merge
  // ---------------------------------------------------------------------------

  /// Performs a purely manual, on-demand, two-way differential merge with Cloud Firestore.
  ///
  /// 1. Queries only records updated after [lastSyncedAt] to minimize document reads.
  /// 2. Merges remote records into local SQLite using last-write-wins based on updated_at.
  /// 3. Pushes local records modified after [lastSyncedAt] using batched writes (<= 400 ops).
  /// 4. Updates [lastSyncedAt] in local settings.
  Future<SyncMergeResult> syncTwoWay({
    required AppDatabase db,
    String? userId,
  }) async {
    if (!isConfigured) {
      throw StateError('Firebase is not configured. Please complete Firebase setup.');
    }

    final activeUid = userId ?? await getActiveUserId();
    if (activeUid == null || activeUid.isEmpty) {
      throw StateError('No active user or sync ID found. Please sign in or set a Sync ID.');
    }

    await initPersistence();

    final prefs = await SharedPreferences.getInstance();
    final syncStartTime = DateTime.now().toUtc();

    int recipesAdded = 0;
    int recipesUpdated = 0;
    int recipesKeptLocal = 0;
    int ingredientsAdded = 0;
    int ingredientsUpdated = 0;

    final userDoc = _firestore.collection('users').doc(activeUid);
    final recipesCol = userDoc.collection('recipes');
    final ingsCol = userDoc.collection('ingredients');
    final unitsCol = userDoc.collection('units');

    // -------------------------------------------------------------
    // PHASE 1: PULL REMOTE UPDATES
    // -------------------------------------------------------------

    // 1. Remote Units (Pull all units so foreign keys never fail)
    final remoteUnitsSnap = await unitsCol.get();
    for (final doc in remoteUnitsSnap.docs) {
      final unit = unitFromFirestore(doc.data(), fallbackId: doc.id);
      await db.mergeUnitFromRemote(unit);
    }

    // 2. Remote Ingredients
    final remoteIngsSnap = await ingsCol.get();
    final Map<String, DateTime> remoteIngUpdatedTimes = {};
    for (final doc in remoteIngsSnap.docs) {
      final ing = ingredientFromFirestore(doc.data(), fallbackId: doc.id);
      final remoteTime = ing.dateTimeModified ?? ing.dateCreated;
      remoteIngUpdatedTimes[ing.ingredientPk] = remoteTime;

      final res = await db.mergeIngredientFromRemote(ing);
      if (res == 1) ingredientsAdded++;
      if (res == 2) ingredientsUpdated++;
    }

    // 3. Remote Recipes (Differential or full, embedded ingredients & steps)
    final remoteRecipesSnap = await recipesCol.get();
    final Map<String, DateTime> remoteRecipeUpdatedTimes = {};
    for (final doc in remoteRecipesSnap.docs) {
      final parsed = recipeFromFirestore(doc.data(), fallbackId: doc.id);
      final remoteTime = parsed.recipe.dateTimeModified ?? parsed.recipe.dateCreated;
      remoteRecipeUpdatedTimes[parsed.recipe.recipePk] = remoteTime;

      final res = await db.mergeRecipeFromRemote(
        remoteRecipe: parsed.recipe,
        remoteIngredients: parsed.ingredients,
        remoteSteps: parsed.steps,
        nestedIngredients: parsed.nestedIngredients,
      );
      if (res == 1) recipesAdded++;
      if (res == 2) recipesUpdated++;
      if (res == 0) recipesKeptLocal++;
    }

    // -------------------------------------------------------------
    // PHASE 2: PUSH LOCAL UPDATES
    // -------------------------------------------------------------
    final localUnits = await db.getAllUnits();
    final localIngredients = await db.getAllIngredients();
    final localRecipes = (await db.getAllRecipeDetails())
        .where((r) => !isSampleManufacturingRecipe(r.recipe.recipePk))
        .toList();

    WriteBatch batch = _firestore.batch();
    int opCount = 0;

    // Push Units (Ensure all local units exist on remote)
    for (final unit in localUnits) {
      final docRef = unitsCol.doc(unit.unitPk);
      final data = unitToFirestore(unit);
      data['updatedAt'] = Timestamp.fromDate(syncStartTime);
      batch.set(docRef, data, SetOptions(merge: true));
      opCount++;
      if (opCount >= 400) {
        await batch.commit();
        batch = _firestore.batch();
        opCount = 0;
      }
    }

    // Push Ingredients
    final pushedIngIds = <String>{};
    for (final ing in localIngredients) {
      final localTime = ing.dateTimeModified ?? ing.dateCreated;
      final remoteTime = remoteIngUpdatedTimes[ing.ingredientPk];
      // If remote was strictly newer, remote already won locally; don't push older local edit
      if (remoteTime != null && remoteTime.isAfter(localTime)) {
        continue;
      }

      pushedIngIds.add(ing.ingredientPk);
      final docRef = ingsCol.doc(ing.ingredientPk);
      final data = ingredientToFirestore(ing);
      batch.set(docRef, data, SetOptions(merge: true));
      opCount++;
      if (opCount >= 400) {
        await batch.commit();
        batch = _firestore.batch();
        opCount = 0;
      }
    }

    // Push any ingredients referenced by localRecipes that were not already pushed
    for (final rd in localRecipes) {
      for (final ri in rd.ingredients) {
        if (!pushedIngIds.contains(ri.ingredient.ingredientPk)) {
          pushedIngIds.add(ri.ingredient.ingredientPk);
          final docRef = ingsCol.doc(ri.ingredient.ingredientPk);
          final data = ingredientToFirestore(ri.ingredient);
          batch.set(docRef, data, SetOptions(merge: true));
          opCount++;
          if (opCount >= 400) {
            await batch.commit();
            batch = _firestore.batch();
            opCount = 0;
          }
        }
      }
    }

    // Push Recipes (Single document per recipe containing embedded ingredients & steps)
    for (final rd in localRecipes) {
      final r = rd.recipe;
      final localTime = r.dateTimeModified ?? r.dateCreated;
      final remoteTime = remoteRecipeUpdatedTimes[r.recipePk];
      // If remote was strictly newer, remote already won locally; don't push older local edit
      if (remoteTime != null && remoteTime.isAfter(localTime)) {
        continue;
      }

      final docRef = recipesCol.doc(r.recipePk);
      final data = recipeToFirestore(rd);
      batch.set(docRef, data, SetOptions(merge: true));
      opCount++;
      if (opCount >= 400) {
        await batch.commit();
        batch = _firestore.batch();
        opCount = 0;
      }
    }

    // Push Sync Status / Metadata
    final metaRef = userDoc.collection('sync_meta').doc('status');
    batch.set(metaRef, {
      'lastSyncTimestamp': Timestamp.fromDate(syncStartTime),
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'appVersion': kAppVersion,
    }, SetOptions(merge: true));
    opCount++;

    if (opCount > 0) {
      await batch.commit();
    }

    // -------------------------------------------------------------
    // PHASE 3: RECORD LAST SYNCED AT
    // -------------------------------------------------------------
    await prefs.setString('${prefLastSyncKey}_$activeUid', syncStartTime.toIso8601String());

    return SyncMergeResult(
      recipesAdded: recipesAdded,
      recipesUpdated: recipesUpdated,
      recipesKeptLocal: recipesKeptLocal,
      ingredientsAdded: ingredientsAdded,
      ingredientsUpdated: ingredientsUpdated,
    );
  }
}

final firestoreSyncServiceProvider = Provider<FirestoreSyncService>((ref) {
  return FirestoreSyncService();
});
