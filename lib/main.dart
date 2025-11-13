// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

// ⬇️ Localización / formateo de fechas
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'features/attendance/bg_location_task.dart';
// (No es obligatorio importar sync_service.dart aquí)
import 'features/attendance/presentation/app.dart'; // Debe exportar HmInnovaApp

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa datos de fecha en español
  Intl.defaultLocale = 'es';
  await initializeDateFormatting('es');

  // En esta versión del plugin, init() NO es const.
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'hm_innova_fg',
      channelName: 'HM INNOVA Asistencia',
      channelDescription:
          'Registro de ubicación y sincronización en segundo plano',
      channelImportance: NotificationChannelImportance.LOW,
      priority: NotificationPriority.LOW,
      iconData: NotificationIconData(
        resType: ResourceType.mipmap,
        resPrefix: ResourcePrefix.ic,
        name: 'launcher',
      ),
      buttons: [NotificationButton(id: 'open', text: 'Abrir')],
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: true,
      playSound: false,
    ),
    foregroundTaskOptions: const ForegroundTaskOptions(
      interval: 300000, // 5 min entre eventos de onEvent()
      isOnceEvent: false,
      autoRunOnBoot: false,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );

  // startService() puede devolver Future<bool>?; si tu analizador se queja,
  // elimina el 'await' de esta línea.
  await FlutterForegroundTask.startService(
    notificationTitle: 'HM INNOVA en ejecución',
    notificationText: 'Registrando ubicación y sincronizando.',
    callback: startForegroundCallback,
  );

  runApp(const MyApp());
}

@pragma('vm:entry-point')
void startForegroundCallback() {
  FlutterForegroundTask.setTaskHandler(BgLocationTask());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ¡No uses const en WithForegroundTask!
    return WithForegroundTask(
      child: MaterialApp(
        title: 'HM INNOVA Asistencia',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        // ⬇️ Localización activada
        locale: const Locale('es'),
        supportedLocales: const [Locale('es'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // Tu pantalla con cronómetro/botones/historial
        home: const HmInnovaApp(),
      ),
    );
  }
}
