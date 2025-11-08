import 'dart:io';
import 'package:flutter/material.dart';

import 'app.dart';

// DB desktop
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:intl/date_symbol_data_local.dart';

// Notificaciones / TZ
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'core/notifications/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // SQLite FFI solo en escritorio
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Locale ES
  await initializeDateFormatting('es');

  // Zona horaria local (Ecuador: America/Guayaquil)
  tzdata.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('America/Guayaquil'));

  // Notificaciones
  final notis = NotificationService.instance;
  await notis.init();
  await notis.ensurePermissionOnAndroid13();
  // Recordatorios de la mañana (07:30 y 07:55) todos los días
  await notis.scheduleMorningPlan();

  runApp(const HmInnovaApp());
}
