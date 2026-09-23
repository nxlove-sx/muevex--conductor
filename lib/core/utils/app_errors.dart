String friendlyError(Object e) {
  final msg = e.toString().toLowerCase();
  if (msg.contains('invalid login credentials')) {
    return 'Correo o contraseña incorrectos.';
  }
  if (msg.contains('already registered') || msg.contains('already been registered')) {
    return 'Ya existe una cuenta con ese correo.';
  }
  if (msg.contains('email not confirmed')) {
    return 'Confirma el correo desde el enlace enviado.';
  }
  if (msg.contains('duplicate key') || msg.contains('unique constraint') || msg.contains('vehicles_plate_key')) {
    return 'La placa ya está registrada.';
  }
  if (msg.contains('capacity')) {
    return 'El peso de la carga supera la capacidad del vehículo.';
  }
  if (msg.contains('new row violates row-level security')) {
    return 'No tienes permisos para realizar esa acción.';
  }
  if (msg.contains('network') || msg.contains('socket') || msg.contains('timeout')) {
    return 'Sin conexión. Revisa tu internet e inténtalo de nuevo.';
  }
  return 'Ocurrió un error inesperado. Inténtalo de nuevo.';
}