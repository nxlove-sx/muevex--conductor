import 'package:flutter/material.dart';

import 'package:muevex_conductor/core/theme/muevex_theme.dart';

/// SnackBars de MUEVEX con icono y colores de marca consistentes.
class MuevexSnackBar {
  MuevexSnackBar._();

  static void info(BuildContext context, String message) =>
      _show(context, message, Icons.info_outline, MuevexTheme.primaryColor);

  static void success(BuildContext context, String message) =>
      _show(context, message, Icons.check_circle_outline, MuevexTheme.successColor);

  static void error(BuildContext context, String message) =>
      _show(context, message, Icons.error_outline, MuevexTheme.errorColor);

  static void _show(
    BuildContext context,
    String message,
    IconData icon,
    Color color,
  ) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        backgroundColor: MuevexTheme.textPrimaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}