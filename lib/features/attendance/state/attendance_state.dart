enum SessionStatus { idle, running, paused, stopped }

class AttendanceState {
  final SessionStatus status;
  final Duration elapsed; // tiempo trabajado excluyendo pausas
  final DateTime? startAt; // para mostrar fecha/hora de inicio
  final DateTime? endAt; // para mostrar fecha/hora fin

  const AttendanceState({
    required this.status,
    required this.elapsed,
    this.startAt,
    this.endAt,
  });

  factory AttendanceState.initial() => const AttendanceState(
        status: SessionStatus.idle,
        elapsed: Duration.zero,
        startAt: null,
        endAt: null,
      );

  AttendanceState copyWith({
    SessionStatus? status,
    Duration? elapsed,
    DateTime? startAt,
    DateTime? endAt,
  }) {
    return AttendanceState(
      status: status ?? this.status,
      elapsed: elapsed ?? this.elapsed,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
    );
  }
}
