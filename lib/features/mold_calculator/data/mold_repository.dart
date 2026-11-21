import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/entities/mold_preset.dart';

/// Persistence helper for user-defined custom mold presets via SharedPreferences.
class MoldRepository {
  static const String _storageKey = 'custom_mold_presets_v1';

  final SharedPreferences? _prefs;

  const MoldRepository(this._prefs);

  List<MoldPreset> loadCustomMolds() {
    if (_prefs == null) return const [];
    final raw = _prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((m) => MoldPreset.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<MoldPreset>> saveCustomMold(MoldPreset preset) async {
    final current = List<MoldPreset>.from(loadCustomMolds());
    final idx = current.indexWhere((p) => p.id == preset.id);
    if (idx >= 0) {
      current[idx] = preset;
    } else {
      current.add(preset);
    }
    await _persist(current);
    return current;
  }

  Future<List<MoldPreset>> deleteCustomMold(String id) async {
    final current = loadCustomMolds().where((p) => p.id != id).toList();
    await _persist(current);
    return current;
  }

  Future<void> _persist(List<MoldPreset> items) async {
    if (_prefs == null) return;
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    await _prefs.setString(_storageKey, encoded);
  }
}
