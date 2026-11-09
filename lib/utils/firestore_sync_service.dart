import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart' as drift;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database.dart';
import '../database/sample_manufacturing_recipe.dart';
import '../constants.dart';

/// Manages chunked batched mutations on Cloud Firestore with a maximum of [maxBatchSize] operations per batch.
class FirestoreBatchQueue {
  final FirebaseFirestore? firestore;
  final int maxBatchSize;
  WriteBatch? _batch;
  int _opCount = 0;
  int totalCommitted = 0;
  int batchCount = 0;
  final Future<void> Function(int count)? onCommit;

  FirestoreBatchQueue(
    this.firestore, {
    this.maxBatchSize = 450,
    this.onCommit,
  }) : _batch = firestore?.batch();

  int get opCount => _opCount;

  void set(
    DocumentReference<Map<String, dynamic>>? ref,
    Map<String, dynamic> data, [
    SetOptions? options,
  ]) {
    if (ref != null) {
      _batch?.set(ref, data, options);
    }
    _opCount++;
  }

  void delete(DocumentReference? ref) {
    if (ref != null) {
      _batch?.delete(ref);
    }
    _opCount++;
  }

  Future<void> queueSet(
    DocumentReference<Map<String, dynamic>>? ref,
    Map<String, dynamic> data, [
    SetOptions? options,
  ]) async {
    set(ref, data, options);
    if (_opCount >= maxBatchSize) {
      await commit();
    }
  }

  Future<void> queueDelete(DocumentReference? ref) async {
    delete(ref);
    if (_opCount >= maxBatchSize) {
      await commit();
    }
  }

  Future<void> commit() async {
    if (_opCount > 0) {
      if (_batch != null) {
        await _batch!.commit();
      }
      if (onCommit != null) {
        await onCommit!(_opCount);
      }
      batchCount++;
      totalCommitted += _opCount;
      _batch = firestore?.batch();
      _opCount = 0;
    }
  }
}

/// Service responsible for purely manual, on-demand, differential cross-platform sync
/// with Cloud Firestore. Optimized for Firebase Spark plan limits by embedding
/// ingredients/steps into recipe documents and batching writes.
class FirestoreSyncService {
  final FirebaseFirestore? _firestoreOverride;
  final FirebaseAuth? _authOverride;

  FirestoreSyncService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestoreOverride = firestore,
      _authOverride = auth;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;
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

  /// Checks if the user has an owner-granted or lifetime entitlement in Firestore.
  /// Looks up:
  /// 1. [kVipUserIds] and [kVipEmails] defined in constants.dart
  /// 2. Firestore `entitlements/{uid}` and `entitlements/{email}`
  /// 3. Firestore `users/{uid}` document (`hasLifetimeSubscription` / `isSubscribed`)
  Future<({bool isGranted, String plan})> checkRemoteEntitlement({
    String? uid,
    String? email,
  }) async {
    final activeUid = uid ?? await getActiveUserId();
    final activeEmail = email ?? authCurrentUser?.email;

    // 1. Check local VIP constant lists
    if (activeUid != null && kVipUserIds.contains(activeUid)) {
      return (isGranted: true, plan: kLifetimeSubscriptionId);
    }
    if (activeEmail != null &&
        kVipEmails.contains(activeEmail.toLowerCase().trim())) {
      return (isGranted: true, plan: kLifetimeSubscriptionId);
    }

    if (!isConfigured || activeUid == null || activeUid.isEmpty) {
      return (isGranted: false, plan: '');
    }

    try {
      // 2. Check entitlements/{uid}
      final entDoc =
          await _firestore.collection('entitlements').doc(activeUid).get();
      if (entDoc.exists) {
        final data = entDoc.data() ?? {};
        final isSub = data['isSubscribed'] == true ||
            data['hasLifetimeSubscription'] == true ||
            data['active'] == true;
        if (isSub) {
          final plan = data['plan'] as String? ?? kLifetimeSubscriptionId;
          return (isGranted: true, plan: plan);
        }
      }

      // 3. Check entitlements/{email}
      if (activeEmail != null && activeEmail.isNotEmpty) {
        final emailDoc = await _firestore
            .collection('entitlements')
            .doc(activeEmail.toLowerCase().trim())
            .get();
        if (emailDoc.exists) {
          final data = emailDoc.data() ?? {};
          final isSub = data['isSubscribed'] == true ||
              data['hasLifetimeSubscription'] == true ||
              data['active'] == true;
          if (isSub) {
            final plan = data['plan'] as String? ?? kLifetimeSubscriptionId;
            return (isGranted: true, plan: plan);
          }
        }
      }

      // 4. Check users/{uid} document
      final userDoc = await _firestore.collection('users').doc(activeUid).get();
      if (userDoc.exists) {
        final data = userDoc.data() ?? {};
        final isSub = data['hasLifetimeSubscription'] == true ||
            data['isSubscribed'] == true ||
            data['isVip'] == true;
        if (isSub) {
          final plan = data['subscriptionPlan'] as String? ??
              data['plan'] as String? ??
              kLifetimeSubscriptionId;
          return (isGranted: true, plan: plan);
        }
      }
    } catch (e) {
      debugPrint('Error checking remote entitlement: $e');
    }

    return (isGranted: false, plan: '');
  }

  /// Updates the user's subscription metadata in Firestore (`users/{userId}`).
  Future<void> updateUserSubscriptionStatus({
    required String userId,
    required bool isSubscribed,
    String? plan,
    DateTime? expiresAt,
  }) async {
    if (!isConfigured) return;
    try {
      await _firestore.collection('users').doc(userId).set({
        'isSubscribed': isSubscribed,
        'subscriptionPlan': plan,
        'subscriptionExpiresAt': expiresAt?.toUtc().toIso8601String(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating user subscription status in Firestore: $e');
    }
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

  static const String prefLastSyncTimestampKey = 'last_sync_timestamp';

  /// Gets the last synced timestamp for this user.
  Future<DateTime?> getLastSyncedAt(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('${prefLastSyncTimestampKey}_$userId') ??
        prefs.getString('${prefLastSyncKey}_$userId') ??
        prefs.getString(prefLastSyncTimestampKey) ??
        prefs.getString(prefLastSyncKey);
    return str != null ? DateTime.tryParse(str) : null;
  }

  /// Sets the last synced timestamp for this user.
  Future<void> setLastSyncedAt(String userId, DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    final str = time.toUtc().toIso8601String();
    await prefs.setString('${prefLastSyncTimestampKey}_$userId', str);
    await prefs.setString('${prefLastSyncKey}_$userId', str);
  }

  /// Resets the last synced timestamp (forces full differential re-sync next time).
  Future<void> clearLastSyncedAt(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${prefLastSyncTimestampKey}_$userId');
    await prefs.remove('${prefLastSyncKey}_$userId');
    await prefs.remove(prefLastSyncTimestampKey);
    await prefs.remove(prefLastSyncKey);
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
      throw StateError(
        'Firebase is not initialized. Please configure firebase_options.dart.',
      );
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
  Future<UserCredential> registerWithEmail(
    String email,
    String password,
  ) async {
    if (!isConfigured) {
      throw StateError(
        'Firebase is not initialized. Please configure firebase_options.dart.',
      );
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
      throw StateError(
        'Firebase is not initialized. Please configure firebase_options.dart.',
      );
    }
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Signs in with Google account (native popup on web, GoogleSignIn on mobile).
  Future<UserCredential?> signInWithGoogle() async {
    if (!isConfigured) {
      throw StateError(
        'Firebase is not initialized. Please configure firebase_options.dart.',
      );
    }
    UserCredential? cred;
    if (kIsWeb) {
      final googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      googleProvider.setCustomParameters({'prompt': 'select_account'});
      try {
        cred = await _auth.signInWithPopup(googleProvider);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'popup-closed-by-user' ||
            e.code == 'cancelled-popup-request') {
          return null;
        }
        rethrow;
      }
    } else {
      await GoogleSignIn.instance.initialize(
        serverClientId: defaultFirebaseWebClientId,
      );
      final GoogleSignInAccount googleUser;
      try {
        googleUser = await GoogleSignIn.instance.authenticate();
      } on GoogleSignInException catch (e) {
        if (e.code == GoogleSignInExceptionCode.canceled) {
          return null;
        }
        rethrow;
      } on PlatformException catch (e) {
        if (e.code == 'sign_in_canceled' || e.code == '12501') {
          return null;
        }
        rethrow;
      } catch (e) {
        final str = e.toString().toLowerCase();
        if (str.contains('canceled') ||
            str.contains('cancelled') ||
            str.contains('12501')) {
          return null;
        }
        rethrow;
      }

      final auth = googleUser.authentication;
      final credential = GoogleAuthProvider.credential(idToken: auth.idToken);
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

  /// Permanently deletes all remote recipes, ingredients, custom units, and sync metadata
  /// from Firestore for the given user, without deleting local database records.
  Future<void> deleteFirestoreCloudData({String? userId}) async {
    if (!isConfigured) return;
    final activeUid = userId ?? await getActiveUserId();
    if (activeUid == null || activeUid.isEmpty) return;

    final userDoc = _firestore.collection('users').doc(activeUid);
    final subcollections = ['recipes', 'ingredients', 'units', 'groups', 'sync_meta'];

    for (final subcol in subcollections) {
      try {
        final snapshot = await userDoc.collection(subcol).get();
        if (snapshot.docs.isNotEmpty) {
          final batchQueue = FirestoreBatchQueue(_firestore, maxBatchSize: 450);
          for (final doc in snapshot.docs) {
            await batchQueue.queueDelete(doc.reference);
          }
          await batchQueue.commit();
        }
      } catch (e) {
        debugPrint('Error deleting subcollection: $e');
      }
    }

    try {
      await userDoc.delete();
    } catch (_) {}

    await clearLastSyncedAt(activeUid);
  }

  /// Permanently deletes all user data from Cloud Firestore (recipes, ingredients, units, sync_meta, and user doc)
  /// and deletes the Firebase Auth account.
  /// Handles `requires-recent-login` re-authentication when [reauthPassword] is provided or Google credentials are used.
  Future<void> deleteAccountAndCloudData({String? reauthPassword}) async {
    if (!isConfigured) {
      throw StateError('Firebase is not initialized.');
    }
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user found to delete.');
    }
    final uid = user.uid;

    // 1. Delete all Firestore collections belonging to this user
    try {
      final userDoc = _firestore.collection('users').doc(uid);
      final subcollections = [
        'recipes',
        'ingredients',
        'units',
        'groups',
        'sync_meta',
      ];

      for (final subcol in subcollections) {
        final snapshot = await userDoc.collection(subcol).get();
        if (snapshot.docs.isNotEmpty) {
          final batchQueue = FirestoreBatchQueue(_firestore, maxBatchSize: 450);
          for (final doc in snapshot.docs) {
            await batchQueue.queueDelete(doc.reference);
          }
          await batchQueue.commit();
        }
      }

      // Delete the root user doc
      await userDoc.delete();
    } catch (e) {
      debugPrint('Warning deleting Firestore data during account deletion: $e');
    }

    // 2. Re-authenticate if password is provided
    if (reauthPassword != null &&
        reauthPassword.isNotEmpty &&
        user.email != null) {
      try {
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: reauthPassword,
        );
        await user.reauthenticateWithCredential(credential);
      } catch (e) {
        debugPrint('Error during re-authentication: $e');
        rethrow;
      }
    }

    // 3. Delete Firebase Auth User
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        // Attempt reauthentication via Google if user signed in with Google
        final isGoogleUser = user.providerData.any(
          (p) => p.providerId == 'google.com',
        );
        if (isGoogleUser) {
          if (kIsWeb) {
            final googleProvider = GoogleAuthProvider();
            googleProvider.addScope('email');
            googleProvider.setCustomParameters({'prompt': 'select_account'});
            await user.reauthenticateWithPopup(googleProvider);
            await user.delete();
          } else {
            await GoogleSignIn.instance.initialize(
              serverClientId: defaultFirebaseWebClientId,
            );
            final googleUser = await GoogleSignIn.instance.authenticate();
            final auth = googleUser.authentication;
            final credential = GoogleAuthProvider.credential(
              idToken: auth.idToken,
            );
            await user.reauthenticateWithCredential(credential);
            await user.delete();
          }
        } else {
          rethrow;
        }
      } else {
        rethrow;
      }
    }

    // 4. Sign out and disconnect from GoogleSignIn if active
    try {
      await GoogleSignIn.instance.disconnect();
    } catch (_) {}
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}

    // 5. Clean up local Sync ID and last synced timestamps
    await clearCustomUserId();
    await clearLastSyncedAt(uid);
  }

  /// Connects with Google account using existing GoogleSignInAccount credential.
  Future<String?> linkGoogleAccount(GoogleSignInAccount googleUser) async {
    if (!isConfigured) {
      throw StateError(
        'Firebase is not initialized. Please configure firebase_options.dart.',
      );
    }
    final auth = googleUser.authentication;
    final credential = GoogleAuthProvider.credential(idToken: auth.idToken);
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
      'groupId': r.groupId,
      'space_ids': detail.spaceIds,
      'category': r.category,
      'dateCreated': r.dateCreated.toIso8601String(),
      'dateTimeModified': r.dateTimeModified?.toIso8601String(),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'archived': r.archived,
      'ingredients': detail.ingredients
          .map(
            (ri) => {
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
              'ingredientDateTimeModified': ri.ingredient.dateTimeModified
                  ?.toIso8601String(),
              'is_deleted': ri.ingredient.isDeleted,
              'deleted_at': ri.ingredient.deletedAt?.toIso8601String(),
              'group_id': ri.ingredient.groupId,
              'category': ri.ingredient.category,
              'current_stock': ri.ingredient.currentStock,
              'minimum_stock': ri.ingredient.minimumStock,
              'stock_unit': ri.ingredient.stockUnit,
              'cost_per_stock_unit': ri.ingredient.costPerStockUnit,
              'last_stock_update': ri.ingredient.lastStockUpdate
                  ?.toIso8601String(),
            },
          )
          .toList(),
      'steps': detail.steps
          .map(
            (st) => {
              'stepPk': st.stepPk,
              'recipeFk': st.recipeFk,
              'stepNumber': st.stepNumber,
              'instruction': st.instruction,
              'dateTimeModified': st.dateTimeModified?.toIso8601String(),
            },
          )
          .toList(),
    };
  }

  /// Parses a remote recipe document with embedded ingredients and steps.
  static ({
    Recipe recipe,
    List<RecipeIngredient> ingredients,
    List<RecipeStep> steps,
    List<Ingredient> nestedIngredients,
    List<String> spaceIds,
  })
  recipeFromFirestore(Map<String, dynamic> d, {String fallbackId = ''}) {
    final pk = (d['recipePk'] as String?) ?? fallbackId;
    final recipe = Recipe(
      recipePk: pk.isNotEmpty
          ? pk
          : 'recipe_${DateTime.now().millisecondsSinceEpoch}',
      name: (d['name'] as String?) ?? 'Sin título',
      description: d['description'] as String?,
      defaultYield: (d['defaultYield'] as num?)?.toDouble() ?? 1.0,
      yieldName: (d['yieldName'] as String?) ?? 'porciones',
      targetProfitMargin: (d['targetProfitMargin'] as num?)?.toDouble() ?? 0.0,
      targetPricePerPortion:
          (d['targetPricePerPortion'] as num?)?.toDouble() ?? 0.0,
      fixedOverheadCost: (d['fixedOverheadCost'] as num?)?.toDouble() ?? 0.0,
      colour: d['colour'] as String?,
      dateCreated: _parseDate(d['dateCreated']),
      dateTimeModified: _parseNullableDate(d['dateTimeModified']),
      archived: d['archived'] as bool? ?? false,
      groupId: (d['group_id'] ?? d['groupId']) as String?,
      category: (d['category'] ?? d['category_id'] as String?) ?? 'cocina',
    );
    final rawSpaceIds = d.containsKey('space_ids')
        ? d['space_ids']
        : d['spaceIds'];
    final spaceIds = d.containsKey('space_ids') || d.containsKey('spaceIds')
        ? (rawSpaceIds is Iterable
              ? rawSpaceIds.whereType<String>().toList()
              : <String>[])
        : (recipe.groupId == null ? <String>[] : <String>[recipe.groupId!]);

    final rawIngredients = (d['ingredients'] as List<dynamic>?) ?? [];
    final ingredients = <RecipeIngredient>[];
    final nestedIngredients = <Ingredient>[];

    for (final raw in rawIngredients) {
      if (raw is! Map) continue;
      final m = Map<String, dynamic>.from(raw);
      final recipeFk = (m['recipeFk'] as String?) ?? recipe.recipePk;
      final ingredientFk = (m['ingredientFk'] as String?) ?? '';
      final riPk =
          (m['recipeIngredientPk'] as String?) ?? '${recipeFk}_$ingredientFk';

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
          final isDeleted =
              (ingMap['is_deleted'] ?? ingMap['isDeleted']) as bool? ?? false;
          final deletedAt = _parseNullableDate(
            ingMap['deleted_at'] ?? ingMap['deletedAt'],
          );
          nestedIngredients.add(
            Ingredient(
              ingredientPk: ingPk,
              name: (ingMap['name'] as String?) ?? 'Ingrediente',
              cost: (ingMap['cost'] as num?)?.toDouble() ?? 0.0,
              quantityForCost:
                  (ingMap['quantityForCost'] as num?)?.toDouble() ?? 1.0,
              unitFk: (ingMap['unitFk'] as String?) ?? 'unit-g',
              dateCreated: _parseDate(ingMap['dateCreated']),
              dateTimeModified: _parseNullableDate(
                ingMap['dateTimeModified'] ??
                    ingMap['ingredientDateTimeModified'],
              ),
              isDeleted: isDeleted,
              deletedAt: deletedAt,
              groupId: (ingMap['group_id'] ?? ingMap['groupId']) as String?,
              category: ingMap['category'] as String?,
              currentStock:
                  (ingMap['current_stock'] ?? ingMap['currentStock'] as num?)
                      ?.toDouble() ??
                  0.0,
              minimumStock:
                  (ingMap['minimum_stock'] ?? ingMap['minimumStock'] as num?)
                      ?.toDouble(),
              stockUnit:
                  (ingMap['stock_unit'] ?? ingMap['stockUnit']) as String?,
              costPerStockUnit:
                  (ingMap['cost_per_stock_unit'] ??
                          ingMap['costPerStockUnit'] as num?)
                      ?.toDouble(),
              lastStockUpdate: _parseNullableDate(
                ingMap['last_stock_update'] ?? ingMap['lastStockUpdate'],
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
      final stepPk =
          (m['stepPk'] as String?) ??
          '${recipe.recipePk}_step_$defaultStepNumber';
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
      spaceIds: spaceIds,
    );
  }

  /// Serializes an [Ingredient] into Firestore format.
  static Map<String, dynamic> ingredientToFirestore(Ingredient ing) {
    final updatedAt = ing.isDeleted
        ? (ing.deletedAt ?? ing.dateTimeModified ?? ing.dateCreated)
        : (ing.dateTimeModified ?? ing.dateCreated);
    return {
      'ingredientPk': ing.ingredientPk,
      'name': ing.name,
      'cost': ing.cost,
      'quantityForCost': ing.quantityForCost,
      'unitFk': ing.unitFk,
      'dateCreated': ing.dateCreated.toIso8601String(),
      'dateTimeModified': ing.dateTimeModified?.toIso8601String(),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'is_deleted': ing.isDeleted,
      'deleted_at': ing.deletedAt?.toIso8601String(),
      'group_id': ing.groupId,
      'category': ing.category,
      'current_stock': ing.currentStock,
      'minimum_stock': ing.minimumStock,
      'stock_unit': ing.stockUnit,
      'cost_per_stock_unit': ing.costPerStockUnit,
      'last_stock_update': ing.lastStockUpdate?.toIso8601String(),
    };
  }

  /// Parses an [Ingredient] from Firestore format.
  static Ingredient ingredientFromFirestore(
    Map<String, dynamic> d, {
    String fallbackId = '',
  }) {
    final pk = (d['ingredientPk'] as String?) ?? fallbackId;
    final isDeleted = (d['is_deleted'] ?? d['isDeleted']) as bool? ?? false;
    final deletedAt = _parseNullableDate(d['deleted_at'] ?? d['deletedAt']);
    return Ingredient(
      ingredientPk: pk.isNotEmpty
          ? pk
          : 'ing_${DateTime.now().millisecondsSinceEpoch}',
      name: (d['name'] as String?) ?? 'Ingrediente',
      cost: (d['cost'] as num?)?.toDouble() ?? 0.0,
      quantityForCost: (d['quantityForCost'] as num?)?.toDouble() ?? 1.0,
      unitFk: (d['unitFk'] as String?) ?? 'unit-g',
      dateCreated: _parseDate(d['dateCreated']),
      dateTimeModified: _parseNullableDate(d['dateTimeModified']),
      isDeleted: isDeleted,
      deletedAt: deletedAt,
      groupId: (d['group_id'] ?? d['groupId']) as String?,
      category: d['category'] as String?,
      currentStock:
          (d['current_stock'] ?? d['currentStock'] as num?)?.toDouble() ?? 0.0,
      minimumStock: (d['minimum_stock'] ?? d['minimumStock'] as num?)
          ?.toDouble(),
      stockUnit: (d['stock_unit'] ?? d['stockUnit']) as String?,
      costPerStockUnit:
          (d['cost_per_stock_unit'] ?? d['costPerStockUnit'] as num?)
              ?.toDouble(),
      lastStockUpdate: _parseNullableDate(
        d['last_stock_update'] ?? d['lastStockUpdate'],
      ),
    );
  }

  /// Serializes a [Group] into Firestore format.
  static Map<String, dynamic> groupToFirestore(Group g) {
    return {
      'id': g.id,
      'name': g.name,
      'icon_name': g.iconName,
      'color_hex': g.colorHex,
      'is_active': g.isActive,
      'created_at': g.createdAt.toIso8601String(),
      'updated_at': g.updatedAt.toIso8601String(),
      'is_deleted': g.isDeleted,
      'updatedAt': Timestamp.fromDate(g.updatedAt),
    };
  }

  /// Parses a [Group] from Firestore format.
  static Group groupFromFirestore(
    Map<String, dynamic> d, {
    String fallbackId = '',
  }) {
    final id = (d['id'] as String?) ?? fallbackId;
    return Group(
      id: id.isNotEmpty ? id : 'group_${DateTime.now().millisecondsSinceEpoch}',
      name: (d['name'] as String?) ?? 'Grupo',
      iconName: (d['icon_name'] ?? d['iconName']) as String?,
      colorHex: (d['color_hex'] ?? d['colorHex']) as String?,
      isActive: (d['is_active'] ?? d['isActive']) as bool? ?? true,
      createdAt: _parseDate(d['created_at'] ?? d['createdAt']),
      updatedAt: _parseDate(d['updated_at'] ?? d['updatedAt']),
      isDeleted: (d['is_deleted'] ?? d['isDeleted']) as bool? ?? false,
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
  static Unit unitFromFirestore(
    Map<String, dynamic> d, {
    String fallbackId = '',
  }) {
    final pk = (d['unitPk'] as String?) ?? fallbackId;
    return Unit(
      unitPk: pk.isNotEmpty
          ? pk
          : 'unit_${DateTime.now().millisecondsSinceEpoch}',
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

    if (detail.spaces.isNotEmpty) {
      await Future.wait(
        detail.spaces.map((space) async {
          final spaceRef = userDoc.collection('groups').doc(space.id);
          await _firestore.runTransaction((transaction) async {
            final snapshot = await transaction.get(spaceRef);
            final remote = snapshot.data();
            if (remote != null) {
              final remoteTime = _parseDate(
                remote['updated_at'] ?? remote['updatedAt'],
              );
              if (!space.updatedAt.isAfter(remoteTime)) return;
            }
            transaction.set(
              spaceRef,
              groupToFirestore(space),
              SetOptions(merge: true),
            );
          });
        }),
      );
    }

    final batchQueue = FirestoreBatchQueue(_firestore, maxBatchSize: 450);

    // Update/upsert the nested ingredients in the cloud ingredients subcollection
    for (final ri in detail.ingredients) {
      if (isSampleManufacturingIngredient(ri.ingredient.ingredientPk)) continue;
      final ingDoc = userDoc
          .collection('ingredients')
          .doc(ri.ingredient.ingredientPk);
      await batchQueue.queueSet(
        ingDoc,
        ingredientToFirestore(ri.ingredient),
        SetOptions(merge: true),
      );
    }

    await batchQueue.queueSet(recipeDoc, data, SetOptions(merge: true));
    await batchQueue.commit();
  }

  /// Force overwrites the cloud data with the complete local SQLite dataset.
  /// Deletes existing remote documents in recipes, ingredients, and custom units,
  /// and uploads all local records directly.
  Future<SyncMergeResult> forceOverwriteCloud({
    required AppDatabase db,
    String? userId,
  }) async {
    if (!isConfigured) {
      throw StateError(
        'Firebase is not configured. Please complete Firebase setup.',
      );
    }

    final activeUid = userId ?? await getActiveUserId();
    if (activeUid == null || activeUid.isEmpty) {
      throw StateError(
        'No active user or sync ID found. Please sign in or set a Sync ID.',
      );
    }

    await initPersistence();

    final syncStartTime = DateTime.now().toUtc();

    final userDoc = _firestore.collection('users').doc(activeUid);
    final recipesCol = userDoc.collection('recipes');
    final ingsCol = userDoc.collection('ingredients');
    final unitsCol = userDoc.collection('units');
    final groupsCol = userDoc.collection('groups');

    // 1. Delete all existing remote units, ingredients, recipes, and groups
    final remoteUnitsSnap = await unitsCol.get();
    final remoteIngsSnap = await ingsCol.get();
    final remoteRecipesSnap = await recipesCol.get();
    final remoteGroupsSnap = await groupsCol.get();

    final batchQueue = FirestoreBatchQueue(_firestore, maxBatchSize: 450);

    for (final doc in remoteUnitsSnap.docs) {
      await batchQueue.queueDelete(doc.reference);
    }
    for (final doc in remoteIngsSnap.docs) {
      await batchQueue.queueDelete(doc.reference);
    }
    for (final doc in remoteRecipesSnap.docs) {
      await batchQueue.queueDelete(doc.reference);
    }
    for (final doc in remoteGroupsSnap.docs) {
      await batchQueue.queueDelete(doc.reference);
    }

    // 2. Fetch all local units, ingredients, and recipes
    final allUnits = await db.getAllUnits();
    final allGroups = await db.getAllGroups(includeDeleted: true);
    final allIngs = (await db.getAllIngredients(includeDeleted: true))
        .where((i) => !isSampleManufacturingIngredient(i.ingredientPk))
        .toList();
    final allRecipeDetails = (await db.getAllRecipeDetails())
        .where((r) => !isSampleManufacturingRecipe(r.recipe.recipePk))
        .toList();

    // 3. Upload all spaces before recipes that reference them.
    for (final group in allGroups) {
      await batchQueue.queueSet(
        groupsCol.doc(group.id),
        groupToFirestore(group),
        SetOptions(merge: true),
      );
    }

    // 4. Upload all units
    for (final unit in allUnits) {
      final docRef = unitsCol.doc(unit.unitPk);
      final data = unitToFirestore(unit);
      data['updatedAt'] = Timestamp.fromDate(syncStartTime);
      await batchQueue.queueSet(docRef, data, SetOptions(merge: true));
    }

    // 5. Upload all ingredients
    for (final ing in allIngs) {
      final docRef = ingsCol.doc(ing.ingredientPk);
      final data = ingredientToFirestore(ing);
      await batchQueue.queueSet(docRef, data, SetOptions(merge: true));
    }

    // 6. Upload all recipes
    for (final rd in allRecipeDetails) {
      final docRef = recipesCol.doc(rd.recipe.recipePk);
      final data = recipeToFirestore(rd);
      await batchQueue.queueSet(docRef, data, SetOptions(merge: true));
    }

    // Metadata
    final metaRef = userDoc.collection('sync_meta').doc('status');
    await batchQueue.queueSet(
      metaRef,
      {
        'lastSyncTimestamp': Timestamp.fromDate(syncStartTime),
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        'appVersion': kAppVersion,
        'forceOverwritten': true,
      },
      SetOptions(merge: true),
    );

    await batchQueue.commit();

    // 7. Record lastSyncedAt
    await setLastSyncedAt(activeUid, syncStartTime);

    return SyncMergeResult(
      recipesAdded: allRecipeDetails.length,
      recipesUpdated: 0,
      recipesKeptLocal: 0,
      ingredientsAdded: allIngs.length,
      ingredientsUpdated: 0,
    );
  }

  // ---------------------------------------------------------------------------
  // Two-Way Incremental Delta Sync
  // ---------------------------------------------------------------------------

  /// Performs a manual or automatic, two-way incremental delta sync with Cloud Firestore.
  ///
  /// 1. Queries only records updated after [lastSyncTimestamp] to minimize document reads.
  /// 2. Merges remote records into local SQLite using last-write-wins based on updated_at / dateTimeModified.
  /// 3. Propagates remote deletions (isDeleted == true) to SQLite without generating local tombstones.
  /// 4. Pushes local records modified after [lastSyncTimestamp] plus pending tombstones in [DeletedRecords].
  /// 5. Commits batched writes (<= 450 ops) before updating [lastSyncTimestamp].
  /// 6. Clears synced tombstones from local [DeletedRecords].
  Future<SyncMergeResult> syncTwoWay({
    required AppDatabase db,
    String? userId,
  }) async {
    if (!isConfigured) {
      throw StateError(
        'Firebase is not configured. Please complete Firebase setup.',
      );
    }

    final activeUid = userId ?? await getActiveUserId();
    if (activeUid == null || activeUid.isEmpty) {
      throw StateError(
        'No active user or sync ID found. Please sign in or set a Sync ID.',
      );
    }

    await initPersistence();

    final lastSyncTimestamp = await getLastSyncedAt(activeUid);
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
    final groupsCol = userDoc.collection('groups');

    final batchQueue = FirestoreBatchQueue(_firestore, maxBatchSize: 450);

    // -------------------------------------------------------------
    // PHASE 1: PULL REMOTE UPDATES (Delta Sync)
    // -------------------------------------------------------------

    // 1. Remote Groups / Spaces
    Query<Map<String, dynamic>> groupsQuery = groupsCol;
    if (lastSyncTimestamp != null) {
      groupsQuery = groupsQuery.where(
        'updated_at',
        isGreaterThan: lastSyncTimestamp.toIso8601String(),
      );
    }
    final remoteGroupsSnap = await groupsQuery.get();
    for (final doc in remoteGroupsSnap.docs) {
      await db.mergeGroupFromRemote(
        groupFromFirestore(doc.data(), fallbackId: doc.id),
      );
    }

    // 2. Remote Units (Pull all units so foreign keys never fail & purge remote duplicates)
    final remoteUnitsSnap = await unitsCol.get();
    final seenRemoteUnitNames = <String>{};
    for (final doc in remoteUnitsSnap.docs) {
      final unit = unitFromFirestore(doc.data(), fallbackId: doc.id);
      final normName = unit.name == 'unit_spoonfuls'
          ? 'unit_tablespoons'
          : unit.name;
      if (!seenRemoteUnitNames.add(normName)) {
        await batchQueue.queueDelete(doc.reference);
      }
      await db.mergeUnitFromRemote(unit);
    }

    // 3. Remote Ingredients (Delta query if lastSyncTimestamp exists)
    Query<Map<String, dynamic>> ingsQuery = ingsCol;
    if (lastSyncTimestamp != null) {
      ingsQuery = ingsQuery.where(
        'dateTimeModified',
        isGreaterThan: lastSyncTimestamp.toIso8601String(),
      );
    }
    final remoteIngsSnap = await ingsQuery.get();
    final Map<String, DateTime> remoteIngUpdatedTimes = {};

    for (final doc in remoteIngsSnap.docs) {
      final data = doc.data();
      final ingPk = (data['ingredientPk'] as String?) ?? doc.id;
      final isDeleted = (data['is_deleted'] ?? data['isDeleted']) as bool? ?? false;
      final remoteTime = _parseDate(data['dateTimeModified'] ?? data['updatedAt'] ?? data['dateCreated']);
      remoteIngUpdatedTimes[ingPk] = remoteTime;

      if (isDeleted) {
        final localIng = await db.getIngredientById(ingPk, includeDeleted: true);
        if (localIng != null) {
          final localTime = localIng.dateTimeModified ?? localIng.dateCreated;
          if (remoteTime.isAfter(localTime) || remoteTime.isAtSameMomentAs(localTime)) {
            await db.deleteIngredientPhysically(ingPk, recordTombstone: false);
            ingredientsUpdated++;
          }
        }
      } else {
        final ing = ingredientFromFirestore(data, fallbackId: doc.id);
        final res = await db.mergeIngredientFromRemote(ing);
        if (res == 1) ingredientsAdded++;
        if (res == 2) ingredientsUpdated++;
      }
    }

    // 4. Remote Recipes (Delta query if lastSyncTimestamp exists)
    Query<Map<String, dynamic>> recipesQuery = recipesCol;
    if (lastSyncTimestamp != null) {
      recipesQuery = recipesQuery.where(
        'dateTimeModified',
        isGreaterThan: lastSyncTimestamp.toIso8601String(),
      );
    }
    final remoteRecipesSnap = await recipesQuery.get();
    final Map<String, DateTime> remoteRecipeUpdatedTimes = {};

    for (final doc in remoteRecipesSnap.docs) {
      final data = doc.data();
      final recipePk = (data['recipePk'] as String?) ?? doc.id;
      final isDeleted = (data['isDeleted'] ?? data['is_deleted']) as bool? ?? false;
      final remoteTime = _parseDate(data['dateTimeModified'] ?? data['updatedAt'] ?? data['dateCreated']);
      remoteRecipeUpdatedTimes[recipePk] = remoteTime;

      if (isDeleted) {
        final localRecipe = (await (db.select(db.recipes)
                  ..where((t) => t.recipePk.equals(recipePk))
                  ..limit(1))
                .get())
            .firstOrNull;
        if (localRecipe != null) {
          final localTime = localRecipe.dateTimeModified ?? localRecipe.dateCreated;
          if (remoteTime.isAfter(localTime) || remoteTime.isAtSameMomentAs(localTime)) {
            await db.deleteRecipeById(recipePk, recordTombstone: false);
            recipesUpdated++;
          }
        }
      } else {
        final parsed = recipeFromFirestore(data, fallbackId: doc.id);
        final legacySpaceId = parsed.recipe.groupId;
        if (legacySpaceId != null &&
            await db.getGroupById(legacySpaceId) == null) {
          await db.insertGroup(
            GroupsCompanion.insert(
              id: drift.Value(legacySpaceId),
              name: 'Workspace',
            ),
          );
        }
        for (final spaceId in parsed.spaceIds) {
          if (await db.getGroupById(spaceId) == null) {
            await db.insertGroup(
              GroupsCompanion.insert(
                id: drift.Value(spaceId),
                name: 'Workspace',
              ),
            );
          }
        }

        final res = await db.mergeRecipeFromRemote(
          remoteRecipe: parsed.recipe,
          remoteIngredients: parsed.ingredients,
          remoteSteps: parsed.steps,
          nestedIngredients: parsed.nestedIngredients,
          remoteSpaceIds: parsed.spaceIds,
        );
        if (res == 1) recipesAdded++;
        if (res == 2) recipesUpdated++;
        if (res == 0) recipesKeptLocal++;
      }
    }

    // -------------------------------------------------------------
    // PHASE 2: PUSH LOCAL DELTA UPDATES (Modified since lastSyncTimestamp + Tombstones)
    // -------------------------------------------------------------
    final localGroups = (await db.getAllGroups(includeDeleted: true)).where((g) {
      if (lastSyncTimestamp == null) return true;
      return g.updatedAt.isAfter(lastSyncTimestamp);
    }).toList();

    for (final group in localGroups) {
      await batchQueue.queueSet(
        groupsCol.doc(group.id),
        groupToFirestore(group),
        SetOptions(merge: true),
      );
    }

    // Units
    final localUnits = lastSyncTimestamp == null
        ? await db.getAllUnits()
        : await db.getCustomUnitsModifiedSince(lastSyncTimestamp);
    for (final unit in localUnits) {
      final docRef = unitsCol.doc(unit.unitPk);
      final data = unitToFirestore(unit);
      data['updatedAt'] = Timestamp.fromDate(syncStartTime);
      await batchQueue.queueSet(docRef, data, SetOptions(merge: true));
    }

    // Modified Ingredients
    final localIngredients = (await db.getIngredientsModifiedSince(
      lastSyncTimestamp,
      includeDeleted: true,
    )).where((i) => !isSampleManufacturingIngredient(i.ingredientPk)).toList();

    final pushedIngIds = <String>{};
    for (final ing in localIngredients) {
      final localTime = ing.isDeleted
          ? (ing.deletedAt ?? ing.dateTimeModified ?? ing.dateCreated)
          : (ing.dateTimeModified ?? ing.dateCreated);
      final remoteTime = remoteIngUpdatedTimes[ing.ingredientPk];
      if (remoteTime != null && remoteTime.isAfter(localTime)) {
        continue;
      }

      pushedIngIds.add(ing.ingredientPk);
      final docRef = ingsCol.doc(ing.ingredientPk);
      await batchQueue.queueSet(
        docRef,
        ingredientToFirestore(ing),
        SetOptions(merge: true),
      );
    }

    // Modified Recipes
    final localRecipes = (await db.getAllRecipeDetails(modifiedSince: lastSyncTimestamp))
        .where((r) => !isSampleManufacturingRecipe(r.recipe.recipePk))
        .toList();

    for (final rd in localRecipes) {
      for (final ri in rd.ingredients) {
        if (!pushedIngIds.contains(ri.ingredient.ingredientPk) &&
            !isSampleManufacturingIngredient(ri.ingredient.ingredientPk)) {
          pushedIngIds.add(ri.ingredient.ingredientPk);
          final docRef = ingsCol.doc(ri.ingredient.ingredientPk);
          await batchQueue.queueSet(
            docRef,
            ingredientToFirestore(ri.ingredient),
            SetOptions(merge: true),
          );
        }
      }

      final r = rd.recipe;
      final localTime = r.dateTimeModified ?? r.dateCreated;
      final remoteTime = remoteRecipeUpdatedTimes[r.recipePk];
      if (remoteTime != null && remoteTime.isAfter(localTime)) {
        continue;
      }

      final docRef = recipesCol.doc(r.recipePk);
      await batchQueue.queueSet(
        docRef,
        recipeToFirestore(rd),
        SetOptions(merge: true),
      );
    }

    // Pending local tombstones (DeletedRecords)
    final pendingTombstones = await db.getAllDeletedRecords();
    for (final record in pendingTombstones) {
      if (record.entityType == 'recipes') {
        if (isSampleManufacturingRecipe(record.recordPk)) continue;
        final docRef = recipesCol.doc(record.recordPk);
        await batchQueue.queueSet(
          docRef,
          {
            'isDeleted': true,
            'is_deleted': true,
            'dateTimeModified': record.deletedAt.toIso8601String(),
            'deletedAt': record.deletedAt.toIso8601String(),
            'updatedAt': Timestamp.fromDate(record.deletedAt),
          },
          SetOptions(merge: true),
        );
      } else if (record.entityType == 'ingredients') {
        if (isSampleManufacturingIngredient(record.recordPk)) continue;
        final docRef = ingsCol.doc(record.recordPk);
        await batchQueue.queueSet(
          docRef,
          {
            'isDeleted': true,
            'is_deleted': true,
            'dateTimeModified': record.deletedAt.toIso8601String(),
            'deleted_at': record.deletedAt.toIso8601String(),
            'updatedAt': Timestamp.fromDate(record.deletedAt),
          },
          SetOptions(merge: true),
        );
      }
    }

    // Push Sync Status / Metadata
    final metaRef = userDoc.collection('sync_meta').doc('status');
    await batchQueue.queueSet(
      metaRef,
      {
        'lastSyncTimestamp': Timestamp.fromDate(syncStartTime),
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        'appVersion': kAppVersion,
      },
      SetOptions(merge: true),
    );

    // Commit all queued batches before updating last_sync_timestamp
    await batchQueue.commit();

    // Clear synced tombstones from local database
    await db.clearDeletedRecords(pendingTombstones);

    // -------------------------------------------------------------
    // PHASE 3: RECORD LAST SYNCED AT
    // -------------------------------------------------------------
    await setLastSyncedAt(activeUid, syncStartTime);

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
