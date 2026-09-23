import 'package:flutter/material.dart';

/// Pin premium para puntos del mapa del conductor: anillo blanco + núcleo en
/// gradiente + punta triangular que señala el punto exacto.
class WaypointPin extends StatelessWidget {
  final IconData icon;
  final Gradient gradient;
  final String? label;

  const WaypointPin({
    super.key,
    required this.icon,
    required this.gradient,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(3),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: gradient,
            ),
            child: Icon(icon, color: Colors.white, size: 19),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -7),
          child: ClipPath(
            clipper: _TriangleClipper(10),
            child: Container(width: 20, height: 13, color: Colors.white),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Text(
              label!,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TriangleClipper extends CustomClipper<Path> {
  final double baseWidth;
  const _TriangleClipper(this.baseWidth);

  @override
  Path getClip(Size size) {
    final path = Path()
      ..moveTo(size.width / 2 - baseWidth / 2, 0)
      ..lineTo(size.width / 2 + baseWidth / 2, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(_TriangleClipper oldClipper) =>
      oldClipper.baseWidth != baseWidth;
}