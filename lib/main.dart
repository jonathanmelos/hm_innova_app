// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

// ⬇️ Localización / formateo de fechas
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'features/attendance/bg_location_task.dart';
import 'features/attendance/presentation/app.dart'; // HmInnovaApp
import 'features/auth/presentation/auth_page.dart'; // ⬅️ NUEVO: AuthGate

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa datos de fecha en español
  Intl.defaultLocale = 'es';
  await initializeDateFormatting('es');

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
      interval: 300000, // 5 min
      isOnceEvent: false,
      autoRunOnBoot: false,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );

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
        locale: const Locale('es'),
        supportedLocales: const [Locale('es'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // ⬇️ ANTES: home: const HmInnovaApp(),
        // AHORA: protegemos con el gate de autenticación
        home: const AuthGate(),
      ),
    );
  }
}
