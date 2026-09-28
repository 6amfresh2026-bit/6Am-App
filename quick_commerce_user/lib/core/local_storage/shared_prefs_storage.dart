import 'package:shared_preferences/shared_preferences.dart';

import 'local_storage.dart';

class SharedPrefsStorage implements LocalStorage {
  SharedPrefsStorage(this._prefs);

  final SharedPreferences _prefs;

  static Future<SharedPrefsStorage> create() async =>
      SharedPrefsStorage(await SharedPreferences.getInstance());

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) => _prefs.setString(key, value);

  @override
  bool? getBool(String key) => _prefs.getBool(key);

  @override
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);

  @override
  List<String> getStringList(String key) => _prefs.getStringList(key) ?? const [];

  @override
  Future<void> setStringList(String key, List<String> value) =>
      _prefs.setStringList(key, value);

  @override
  Future<void> remove(String key) => _prefs.remove(key);
}
