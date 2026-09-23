import 'package:flutter/material.dart';
import 'package:muevex_conductor/core/theme/muevex_theme.dart';
import 'package:muevex_conductor/core/widgets/animations.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? textColor;
  final double? height;
  final bool loading;
  final BorderRadius? borderRadius;
  final IconData? icon;
  final bool gradient;
  final Color? borderColor;
  final bool enabled;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.backgroundColor,
    this.textColor,
    this.height,
    this.loading = false,
    this.borderRadius,
    this.icon,
    this.gradient = false,
    this.borderColor,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDimmed = !enabled && !loading;
    final color = isDimmed ? Colors.grey.shade300 : (backgroundColor ?? MuevexTheme.primaryColor);
    final fg = isDimmed ? Colors.grey.shade600 : (textColor ?? Colors.white);
    final radius = borderRadius ?? BorderRadius.circular(14);
    final bg = gradient && !isDimmed ? MuevexTheme.primaryGradient : null;

    final button = Material(
      color: (gradient && !isDimmed) ? null : color,
      elevation: 0,
      borderRadius: radius,
      child: Ink(
        // Soporta gradiente o color sólido dentro del recorte del ink.
        decoration: BoxDecoration(
          gradient: bg,
          color: isDimmed
              ? Colors.grey.shade300
              : (gradient ? null : color),
          borderRadius: radius,
          border: borderColor != null && !isDimmed
              ? Border.all(color: borderColor!, width: 1.5)
              : null,
        ),
        child: InkWell(
          onTap: (loading || !enabled) ? null : onPressed,
          borderRadius: radius,
          splashColor: Colors.white24,
          highlightColor: Colors.transparent,
          child: Container(
            height: height ?? 52,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, size: 20, color: fg),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        text,
                        style: TextStyle(
                          color: fg,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );

    // Escala sutil al presionar para feedback táctil.
    // La acción la dispara el InkWell interno; Listener solo anima la escala.
    return PressableScale(
      pressedScale: 0.97,
      child: button,
    );
  }
}