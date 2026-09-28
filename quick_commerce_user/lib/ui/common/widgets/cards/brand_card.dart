import 'package:flutter/material.dart';

import '../../../../core/constants/app_durations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/model/brand.dart';

/// Clean rounded brand card displaying the Brand Name matching the screenshot.
class BrandCard extends StatefulWidget {
  const BrandCard({
    super.key,
    required this.brand,
    required this.onTap,
    this.width = 86,
    this.height = 64,
  });

  final Brand brand;
  final VoidCallback onTap;
  final double width;
  final double height;

  @override
  State<BrandCard> createState() => _BrandCardState();
}

class _BrandCardState extends State<BrandCard> {
  bool _pressed = false;

  Color _brandColor(String name) {
    final lower = name.toLowerCase().trim();
    if (lower.contains('amul')) return const Color(0xFFDC2626); // Red
    if (lower.contains('aashirvaad')) return const Color(0xFFEA580C); // Orange
    if (lower.contains('nestle') || lower.contains('nestlé')) return const Color(0xFF374151); // Dark Gray
    if (lower.contains('tata')) return const Color(0xFF2563EB); // Royal Blue
    if (lower.contains('haldiram')) return const Color(0xFFB91C1C); // Deep Red
    if (lower.contains('fortune')) return const Color(0xFFF97316); // Bright Orange
    if (lower.contains('bingo')) return const Color(0xFFD97706); // Amber
    if (lower.contains('dabur')) return const Color(0xFF15803D); // Green
    if (lower.contains('britannia')) return const Color(0xFFDC2626); // Red
    if (lower.contains('cadbury')) return const Color(0xFF6B21A8); // Purple
    return const Color(0xFF1F2937); // Default Charcoal Dark
  }

  @override
  Widget build(BuildContext context) {
    final brandName = widget.brand.name.trim();
    final color = _brandColor(brandName);

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: AppDurations.instant,
        child: Container(
          width: widget.width,
          height: widget.height,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFF3F4F6),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            brandName,
            maxLines: 1,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: context.text.titleSmall!.copyWith(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              color: color,
              letterSpacing: -0.4,
            ),
          ),
        ),
      ),
    );
  }
}
