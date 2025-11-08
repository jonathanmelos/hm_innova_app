import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // Canales Android
  static const AndroidNotificationChannel _chOngoing =
      AndroidNotificationChannel(
    'hm_innova_ongoing',
    'Jornada activa',
    description: 'Notificación persistente mientras la jornada está activa',
    importance: Importance.low,
    playSound: false,
  );

  static const AndroidNotificationChannel _chReminders =
      AndroidNotificationChannel(
    'hm_innova_reminders',
    'Recordatorios de jornada',
    description: 'Pausas, reanudación y cierres',
    importance: Importance.high,
    playSound: true,
  );

  Future<void> init() async {
    // Android: creación de canales
    if (!kIsWeb && Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(_chOngoing);
      await android?.createNotificationChannel(_chReminders);
    }

    // Inicialización (Android/iOS)
    const initAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher'); // tu ícono
    const initDarwin = DarwinInitializationSettings();

    const init = InitializationSettings(android: initAndroid, iOS: initDarwin);
    await _plugin.initialize(
      init,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse:
          NotificationService._onBackgroundNotificationResponse,
    );
  }

  Future<void> ensurePermissionOnAndroid13() async {
    if (!kIsWeb && Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
    }
  }

  // ===== Ongoing =====
  Future<void> showOngoingActive() async {
    const android = AndroidNotificationDetails(
      'hm_innova_ongoing',
      'Jornada activa',
      channelDescription:
          'Notificación persistente mientras la jornada está activa',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      onlyAlertOnce: true,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      playSound: false,
    );

    const iOS = DarwinNotificationDetails(presentSound: false);

    const details = NotificationDetails(android: android, iOS: iOS);

    await _plugin.show(
      1000,
      'Jornada activa',
      'Tu jornada está en curso',
      details,
      payload: 'ongoing',
    );
  }

  Future<void> cancelOngoingActive() async {
    await _plugin.cancel(1000);
  }

  // ===== Plan diario de trabajo (pausas/cierres) =====
  Future<void> scheduleWorkdayPlan() async {
    await cancelWorkdayPlan();

    // 13:00 – sugerir Pausa
    await _zonedDailyAt(
      id: 2001,
      hour: 13,
      minute: 0,
      title: 'Pausa de almuerzo',
      body: 'Toca “Pausar” en la app y toma tu descanso.',
    );

    // 14:00 – sugerir Reanudar
    await _zonedDailyAt(
      id: 2002,
      hour: 14,
      minute: 0,
      title: 'Volvamos al trabajo',
      body: 'Reanuda tu jornada en la app.',
    );

    // 16:45 – se acerca el cierre
    await _zonedDailyAt(
      id: 2003,
      hour: 16,
      minute: 45,
      title: 'Se acerca el final',
      body:
          'Limpia tu espacio y ordena materiales/herramientas. El cierre es a las 17:30.',
    );

    // 17:00 – aviso de fin próximo (ajusta si tu fin es a otra hora)
    await _zonedDailyAt(
      id: 2004,
      hour: 17,
      minute: 0,
      title: 'Fin de jornada',
      body:
          'Tu jornada ha terminado. Finalízala en la app si aún sigue activa.',
    );

    // 17:15 – recordatorio
    await _zonedDailyAt(
      id: 2005,
      hour: 17,
      minute: 15,
      title: 'Recordatorio de cierre',
      body: 'No olvides cerrar tu jornada si aún no lo has hecho.',
    );

    // 17:25 – último aviso (5 min antes del autocierre 17:30)
    await _zonedDailyAt(
      id: 2006,
      hour: 17,
      minute: 25,
      title: 'Último aviso',
      body:
          'En 5 minutos la jornada se cerrará automáticamente si sigue activa.',
    );
  }

  Future<void> cancelWorkdayPlan() async {
    await _plugin.cancel(2001);
    await _plugin.cancel(2002);
    await _plugin.cancel(2003);
    await _plugin.cancel(2004);
    await _plugin.cancel(2005);
    await _plugin.cancel(2006);
  }

  // ===== Mañana (07:30 y 07:55) =====
  Future<void> scheduleMorningPlan() async {
    await cancelMorningPlan();

    await _zonedDailyAt(
      id: 3001,
      hour: 7,
      minute: 30,
      title: '¡Buenos días!',
      body:
          'Tu jornada empieza a las 8:00. Recuerda registrar el inicio en la app.',
    );

    await _zonedDailyAt(
      id: 3002,
      hour: 7,
      minute: 55,
      title: 'En 5 minutos iniciamos',
      body: 'Registra tu jornada a las 8:00 en punto.',
    );
  }

  Future<void> cancelMorningPlan() async {
    await _plugin.cancel(3001);
    await _plugin.cancel(3002);
  }

  Future<void> _zonedDailyAt({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    const android = AndroidNotificationDetails(
      'hm_innova_reminders',
      'Recordatorios de jornada',
      channelDescription: 'Pausas, reanudación y cierres',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
    );
    const iOS = DarwinNotificationDetails();

    const details = NotificationDetails(android: android, iOS: iOS);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      details,
      // API nueva desde v18+: reemplaza androidAllowWhileIdle
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      // En v19 no pases uiLocalNotificationDateInterpretation
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'reminder',
    );
  }

  // ===== Callbacks =====
  void _onNotificationResponse(NotificationResponse response) {
    debugPrint('[noti tap] payload=${response.payload}');
  }

  @pragma('vm:entry-point')
  static void _onBackgroundNotificationResponse(NotificationResponse response) {
    // Vacío: el tap trae la app al foreground y pasará por _onNotificationResponse.
  }
}
