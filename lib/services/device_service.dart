import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Service for managing device identification.
/// Generates a unique device ID on first launch and persists it.
class DeviceService {
  static const _deviceIdKey = 'device_id';
  static String? _cachedDeviceId;

  /// Gets the device ID, generating one if it doesn't exist.
  static Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }

    final prefs = await SharedPreferences.getInstance();
    var deviceId = prefs.getString(_deviceIdKey);

    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString(_deviceIdKey, deviceId);
    }

    _cachedDeviceId = deviceId;
    return deviceId;
  }

  /// Clears the cached device ID (useful for testing).
  static void clearCache() {
    _cachedDeviceId = null;
  }
}
