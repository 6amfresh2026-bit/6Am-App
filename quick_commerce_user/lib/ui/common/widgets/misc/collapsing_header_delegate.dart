import 'dart:math';
import 'package:flutter/material.dart';

/// Renders [banner] behind a single fixed-height "sticky block" that travels
/// from its expanded position (floating over the banner) to its collapsed
/// position (pinned below the status bar) as the user scrolls, tracking
/// [shrinkOffset] 1:1 so it never desyncs or snaps. The banner fades and
/// drifts upward in the same motion, and a solid backdrop + shadow fade in
/// behind the block as it approaches fully collapsed, so the pinned header
/// reads as an elevated surface once the banner is gone.
class CollapsingHeaderDelegate extends SliverPersistentHeaderDelegate {
  CollapsingHeaderDelegate({
    required this.expandedExtent,
    required this.collapsedExtent,
    required this.expandedBlockTop,
    required this.collapsedBlockTop,
    required this.blockHeight,
    required this.backdropColor,
    required this.banner,
    required this.stickyBlock,
    this.bannerDriftUp = 30.0,
  });

  final double expandedExtent;
  final double collapsedExtent;
  final double expandedBlockTop;
  final double collapsedBlockTop;
  final double blockHeight;
  final Color backdropColor;
  final Widget banner;
  final Widget stickyBlock;
  final double bannerDriftUp;

  @override
  double get minExtent => collapsedExtent;

  @override
  double get maxExtent => max(expandedExtent, minExtent);

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final delta = maxExtent - minExtent;
    final t = delta > 0 ? (shrinkOffset / delta).clamp(0.0, 1.0) : 0.0;

    // Sticky block interpolates 1:1 between expanded & collapsed top positions
    final currentBlockTop =
        expandedBlockTop + t * (collapsedBlockTop - expandedBlockTop);

    // Banner drifts upward and fades out as user scrolls up
    final currentBannerTop = -t * bannerDriftUp;
    final bannerOpacity = (1.0 - t * 1.2).clamp(0.0, 1.0);

    return ClipRect(
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // 1. Collapsed Surface Backdrop & Elevation Shadow
          Positioned.fill(
            child: Opacity(
              opacity: t,
              child: Container(
                decoration: BoxDecoration(
                  color: backdropColor,
                  boxShadow: t > 0.8
                      ? const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ),

          // 2. Banner Layer (Fades & Drifts Up on Scroll)
          if (bannerOpacity > 0.01)
            Positioned(
              top: currentBannerTop,
              left: 0,
              right: 0,
              height: expandedExtent,
              child: Opacity(
                opacity: bannerOpacity,
                child: banner,
              ),
            ),

          // 3. Sticky Block Layer (Search Bar + 10 Min Delivery Badge)
          Positioned(
            top: currentBlockTop,
            left: 0,
            right: 0,
            height: blockHeight,
            child: stickyBlock,
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant CollapsingHeaderDelegate oldDelegate) {
    return expandedExtent != oldDelegate.expandedExtent ||
        collapsedExtent != oldDelegate.collapsedExtent ||
        expandedBlockTop != oldDelegate.expandedBlockTop ||
        collapsedBlockTop != oldDelegate.collapsedBlockTop ||
        blockHeight != oldDelegate.blockHeight ||
        backdropColor != oldDelegate.backdropColor ||
        banner != oldDelegate.banner ||
        stickyBlock != oldDelegate.stickyBlock ||
        bannerDriftUp != oldDelegate.bannerDriftUp;
  }
}
