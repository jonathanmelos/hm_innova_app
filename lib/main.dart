import 'dart:io';
import 'package:flutter/material.dart';
import 'app.dart';

// Desktop DB
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Locale/intl
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // SQLite FFI solo en escritorio
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Inicializa datos de fecha para 'es'
  await initializeDateFormatting('es');

  runApp(const HmInnovaApp());
}
