/// Modelo principal de una jornada de trabajo registrada en la base local.
/// Cada sesión puede tener pausas, fotos y selfies asociadas (inicio / fin).
class WorkSession {
  final int? id;
  final DateTime startAt;
  final DateTime? endAt;
  final int totalSeconds; // excluye pausas en el cálculo
  final String status; // 'running' | 'paused' | 'stopped'

  // 📸 Medios capturados
  final String? selfieStart; // selfie del inicio
  final String? selfieEnd; // selfie del final
  final String? photoStart; // foto del contexto inicial
  final String? photoEnd; // foto del contexto final

  WorkSession({
    this.id,
    required this.startAt,
    this.endAt,
    required this.totalSeconds,
    required this.status,
    this.selfieStart,
    this.selfieEnd,
    this.photoStart,
    this.photoEnd,
  });

  /// Crea una copia modificada del objeto (inmutable)
  WorkSession copyWith({
    int? id,
    DateTime? startAt,
    DateTime? endAt,
    int? totalSeconds,
    String? status,
    String? selfieStart,
    String? selfieEnd,
    String? photoStart,
    String? photoEnd,
  }) {
    return WorkSession(
      id: id ?? this.id,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      status: status ?? this.status,
      selfieStart: selfieStart ?? this.selfieStart,
      selfieEnd: selfieEnd ?? this.selfieEnd,
      photoStart: photoStart ?? this.photoStart,
      photoEnd: photoEnd ?? this.photoEnd,
    );
  }

  /// Serializa el objeto a un mapa compatible con SQLite
  Map<String, Object?> toMap() => {
    'id': id,
    'start_at': startAt.millisecondsSinceEpoch,
    'end_at': endAt?.millisecondsSinceEpoch,
    'total_seconds': totalSeconds,
    'status': status,
    'selfie_start': selfieStart,
    'selfie_end': selfieEnd,
    'photo_start': photoStart,
    'photo_end': photoEnd,
  };

  /// Crea una instancia desde una fila de la base de datos
  static WorkSession fromMap(Map<String, Object?> m) => WorkSession(
    id: m['id'] as int?,
    startAt: DateTime.fromMillisecondsSinceEpoch(m['start_at'] as int),
    endAt: m['end_at'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(m['end_at'] as int),
    totalSeconds: (m['total_seconds'] as int?) ?? 0,
    status: (m['status'] as String?) ?? 'stopped',
    selfieStart: m['selfie_start'] as String?,
    selfieEnd: m['selfie_end'] as String?,
    photoStart: m['photo_start'] as String?,
    photoEnd: m['photo_end'] as String?,
  );
}
