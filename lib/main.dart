import 'package:flutter/material.dart';
import 'app.dart';

// Fechas e internacionalización
import 'package:intl/date_symbol_data_local.dart';

// Notificaciones / TZ
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'core/notifications/notification_service.dart';

// Foreground Service (ubicación en segundo plano)
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'features/attendance/bg_location_task.dart'; // handler del servicio

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // (Solo para escritorio usaríamos sqflite_common_ffi; en Android/iOS no hace falta)

  // Locale ES
  await initializeDateFormatting('es');

  // Zona horaria local (Ecuador: America/Guayaquil)
  tzdata.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('America/Guayaquil'));

  // Inicializa opciones del servicio en primer plano (notificación persistente)
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'workday_channel_id',
      channelName: 'Jornada activa',
      channelDescription: 'Registro de ubicación en segundo plano',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
      iconData: const NotificationIconData(
        resType: ResourceType.mipmap,
        resPrefix: ResourcePrefix.ic,
        name: 'launcher', // usa tu mipmap/ic_launcher
      ),
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: true,
      playSound: false,
    ),
    foregroundTaskOptions: const ForegroundTaskOptions(
      interval: 3600000, // 60 min en milisegundos
      isOnceEvent: false,
      autoRunOnBoot: false,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );

  // Notificaciones locales propias de la app
  final notis = NotificationService.instance;
  await notis.init();
  await notis.ensurePermissionOnAndroid13();
  await notis.scheduleMorningPlan();

  runApp(const WithForegroundTask(child: HmInnovaApp()));
}

/// Entry-point del Foreground Service (lo llamarás al iniciar la jornada).
@pragma('vm:entry-point')
void startForegroundCallback() {
  FlutterForegroundTask.setTaskHandler(BgLocationTask());
}
