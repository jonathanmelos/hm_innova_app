import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../network/api_client.dart';

class DeviceService {
  DeviceService._();
  static final DeviceService _instance = DeviceService._();
  factory DeviceService() => _instance;

  static const _kDeviceUuidKey = 'device_uuid';

  Future<String> _loadOrCreateDeviceUuid() async {
    final prefs = await SharedPreferences.getInstance();
    var uuid = prefs.getString(_kDeviceUuidKey);
    if (uuid != null && uuid.isNotEmpty) return uuid;

    uuid = const Uuid().v4();
    await prefs.setString(_kDeviceUuidKey, uuid);
    return uuid;
  }

  /// Registra el dispositivo en el backend si aún no está registrado
  /// y devuelve el `device_uuid` lógico que usamos en las sesiones.
  Future<String> registerDeviceIfNeeded() async {
    final deviceUuid = await _loadOrCreateDeviceUuid();

    String platform = Platform.isAndroid
        ? 'android'
        : (Platform.isIOS ? 'ios' : 'other');

    String? brand;
    String? model;
    String? osVersion;

    final deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final info = await deviceInfo.androidInfo;
      brand = info.manufacturer;
      model = info.model;
      osVersion = info.version.release;
    } else if (Platform.isIOS) {
      final info = await deviceInfo.iosInfo;
      brand = 'Apple';
      model = info.utsname.machine;
      osVersion = info.systemVersion;
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final appVersion = packageInfo.version;

    final token = await ApiClient.I.getToken();

    await ApiClient.I.post(
      '/api/devices/register', // 👈 aquí va el /api
      bearerToken: token,
      body: {
        'device_uuid': deviceUuid,
        'platform': platform,
        'brand': brand,
        'model': model,
        'os_version': osVersion,
        'app_version': appVersion,
      },
    );

    return deviceUuid;
  }

  Future<String> getDeviceUuid() async {
    final prefs = await SharedPreferences.getInstance();
    final uuid = prefs.getString(_kDeviceUuidKey);
    if (uuid != null && uuid.isNotEmpty) return uuid;

    // Si no existe en local, lo registra en el backend y lo guarda.
    return registerDeviceIfNeeded();
  }
}
