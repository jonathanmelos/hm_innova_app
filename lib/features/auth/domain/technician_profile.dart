class TechnicianProfile {
  final int id;
  final int userId;
  final String? cedula;
  final String? nombres;
  final String? apellidos;
  final String? telefono;
  final String? correo;
  final String? direccion;
  final String? tipoSangre;
  final String? contactoEmergencia;
  final String? fotoPerfil;
  final bool perfilCompleto;
  final String estado;

  TechnicianProfile({
    required this.id,
    required this.userId,
    this.cedula,
    this.nombres,
    this.apellidos,
    this.telefono,
    this.correo,
    this.direccion,
    this.tipoSangre,
    this.contactoEmergencia,
    this.fotoPerfil,
    required this.perfilCompleto,
    required this.estado,
  });

  factory TechnicianProfile.fromJson(Map<String, dynamic> json) {
    return TechnicianProfile(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      cedula: json['cedula'] as String?,
      nombres: json['nombres'] as String?,
      apellidos: json['apellidos'] as String?,
      telefono: json['telefono'] as String?,
      correo: json['correo'] as String?,
      direccion: json['direccion'] as String?,
      tipoSangre: json['tipo_sangre'] as String?,
      contactoEmergencia: json['contacto_emergencia'] as String?,
      fotoPerfil: json['foto_perfil'] as String?,
      perfilCompleto:
          (json['perfil_completo'] ?? 0) == 1 ||
          json['perfil_completo'] == true,
      estado: (json['estado'] as String?) ?? 'activo',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cedula': cedula,
      'nombres': nombres,
      'apellidos': apellidos,
      'telefono': telefono,
      'correo': correo,
      'direccion': direccion,
      'tipo_sangre': tipoSangre,
      'contacto_emergencia': contactoEmergencia,
      // foto_perfil la dejamos para después (subida de archivos)
    };
  }
}
