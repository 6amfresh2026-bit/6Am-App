import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../di/app_providers.dart';
import '../../../../navigation/route_paths.dart';
import '../../notifications/notifications_provider.dart';

/// Top bar navigation widget matching exact screenshot design:
/// - Left: Location pin, Address title (e.g. 17/C v), and subtitle (e.g. New Palasia, Indore >)
/// - Right: Bell icon with red notification badge, and circular User Profile Avatar.
class DeliveryHeader extends ConsumerWidget {
  const DeliveryHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final address = ref.watch(selectedAddressProvider);
    final unread = ref.watch(
      notificationsProvider.select((s) => s.unreadCount),
    );
    final authState = ref.watch(authProvider);

    final addressTitle = address == null ? 'Set location' : address.label.wireValue;
    final addressSubtitle = address == null
        ? 'Choose a delivery address'
        : address.shortLine;

    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Location Pin Icon
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on_rounded,
              size: 22,
              color: Color(0xFF82CEC5),
              // color: Color(0xFFFFC700),
            ),
          ),
          const SizedBox(width: 8),

          // Address selector Column
          Expanded(
            child: GestureDetector(
              onTap: () => context.push(RoutePaths.addresses),
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Primary Address Name + Dropdown Arrow
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          addressTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 18.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1.1,
                            shadows: const [
                              Shadow(
                                color: Colors.black87,
                                blurRadius: 6,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black87,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),

                  // Address Subtitle + Right Chevron Arrow
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          addressSubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.1,
                            shadows: const [
                              Shadow(
                                color: Colors.black87,
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black87,
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Right Actions: Notification Bell + User Avatar
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Notification Bell Button with Red Badge
              GestureDetector(
                onTap: () => context.push(RoutePaths.notifications),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.notifications_none_rounded,
                        size: 24,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    // Red Notification Badge — hidden when there is nothing
                    // unread, rather than showing a fake count.
                    if (unread > 0)
                      Positioned(
                        top: -1,
                        right: -1,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(
                            minWidth: 19,
                            minHeight: 19,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            unread > 99 ? '99+' : '$unread',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(width: 10),

              // User Profile Avatar Circle
              GestureDetector(
                onTap: () => context.push(RoutePaths.profile),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                    gradient: const LinearGradient(
                      colors: [Color(0xFF82CEC5), Color(0xFF24665E)],
                      // colors: [Color(0xFFFDE047), Color(0xFFEAB308)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: ClipOval(
                    child:
                        authState.user != null &&
                            authState.user!.profileImage.isNotEmpty
                        ? Image.network(
                            authState.user!.profileImage,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const _DefaultAvatarIcon(),
                          )
                        : const _DefaultAvatarIcon(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DefaultAvatarIcon extends StatelessWidget {
  const _DefaultAvatarIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF82CEC5),
      // color: const Color(0xFFFDE047),
      padding: const EdgeInsets.all(4),
      child: const Icon(
        Icons.person_rounded,
        color: Color(0xFF14534C),
        // color: Color(0xFF854D0E),
        size: 28,
      ),
    );
  }
}
