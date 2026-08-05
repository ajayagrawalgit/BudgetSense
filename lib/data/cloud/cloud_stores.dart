import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tiny storage abstractions so the cloud layer is fully unit-testable without
/// SharedPreferences or platform secure-storage plugins. Production wires the
/// real implementations; tests use in-memory fakes.

/// Plain (non-secret) key/value store. Used for device/account-specific cloud
/// metadata that must NOT live in the user snapshot.
abstract interface class KeyValueStore {
  String? getString(String key);
  Future<void> setString(String key, String value);
  int? getInt(String key);
  Future<void> setInt(String key, int value);
  bool? getBool(String key);
  Future<void> setBool(String key, bool value);
  Future<void> remove(String key);
}

/// Secret store, backed by Android Keystore / iOS Keychain in production. Only
/// wrapped/derived key material is cached here, never the passphrase.
abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// SharedPreferences-backed [KeyValueStore]. Uses its own key prefix so cloud
/// metadata never collides with app settings.
class PrefsKeyValueStore implements KeyValueStore {
  PrefsKeyValueStore(this._prefs, {this.prefix = 'budgetsense.cloud.'});
  final SharedPreferences _prefs;
  final String prefix;

  String _k(String key) => '$prefix$key';

  @override
  String? getString(String key) => _prefs.getString(_k(key));
  @override
  Future<void> setString(String key, String value) =>
      _prefs.setString(_k(key), value);
  @override
  int? getInt(String key) => _prefs.getInt(_k(key));
  @override
  Future<void> setInt(String key, int value) => _prefs.setInt(_k(key), value);
  @override
  bool? getBool(String key) => _prefs.getBool(_k(key));
  @override
  Future<void> setBool(String key, bool value) =>
      _prefs.setBool(_k(key), value);
  @override
  Future<void> remove(String key) => _prefs.remove(_k(key));
}

/// flutter_secure_storage-backed [SecretStore].
class FlutterSecureSecretStore implements SecretStore {
  FlutterSecureSecretStore([FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
