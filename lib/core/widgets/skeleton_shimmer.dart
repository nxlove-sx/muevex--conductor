import 'package:flutter/material.dart';

/// Barra pulsante (skeleton) con efecto shimmer para estados de carga.
class SkeletonShimmer extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonShimmer({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 10,
  });

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [
                Color(0xFFD5DAE2),
                Color(0xFFEFF1F5),
                Color(0xFFD5DAE2),
              ],
              stops: [
                (t - 0.35).clamp(0.0, 1.0),
                t,
                (t + 0.35).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton que imita la tarjeta de servicio disponible del conductor.
class ServiceCardSkeleton extends StatelessWidget {
  const ServiceCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Row(
            children: [
              SkeletonShimmer(width: 42, height: 42, borderRadius: 12),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonShimmer(width: 130, height: 14, borderRadius: 6),
                    SizedBox(height: 8),
                    SkeletonShimmer(width: 90, height: 12, borderRadius: 6),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          SkeletonShimmer(width: 150, height: 10, borderRadius: 5),
          SizedBox(height: 12),
          SkeletonShimmer(width: 120, height: 10, borderRadius: 5),
          SizedBox(height: 16),
          SkeletonShimmer(width: double.infinity, height: 46, borderRadius: 12),
        ],
      ),
    );
  }
}