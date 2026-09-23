import 'package:flutter/material.dart';

import 'package:muevex_conductor/core/theme/muevex_theme.dart';
import 'package:muevex_conductor/core/widgets/custom_button.dart';

/// Carga centrada con el color de marca para estados de carga consistentes.
class MuevexLoading extends StatelessWidget {
  final String? message;
  const MuevexLoading({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: MuevexTheme.primaryColor,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 14),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

/// Estado de error en tarjeta consistente con acción de reintento.
class MuevexErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const MuevexErrorView({
    super.key,
    this.message = 'No se pudo cargar la información.',
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: MuevexTheme.errorColor.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: MuevexTheme.errorColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  color: MuevexTheme.errorColor,
                  size: 32,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Algo salió mal',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.4),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 18),
                CustomButton(
                  text: 'Reintentar',
                  icon: Icons.refresh_rounded,
                  onPressed: onRetry!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Estado vacío bonito: icono en óvalo + título + descripción + CTA opcional.
class MuevexEmptyState extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  const MuevexEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.iconColor = MuevexTheme.primaryColor,
    this.subtitle,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 42, color: iconColor),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 22),
              CustomButton(
                text: actionLabel!,
                icon: actionIcon,
                onPressed: onAction!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// AppBar de marca con degradado y SafeArea, para pantallas de detalle.
AppBar brandMuevexAppBar({
  required String title,
  List<Widget>? actions,
}) {
  return AppBar(
    title: Text(title),
    actions: actions,
    centerTitle: true,
    flexibleSpace: Container(
      decoration: const BoxDecoration(gradient: MuevexTheme.primaryGradient),
    ),
    backgroundColor: Colors.transparent,
    foregroundColor: Colors.white,
    iconTheme: const IconThemeData(color: Colors.white),
    titleTextStyle: const TextStyle(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.bold,
    ),
  );
}