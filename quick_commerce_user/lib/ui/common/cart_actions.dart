import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/app_haptics.dart';
import '../../di/app_providers.dart';
import '../../di/repository_providers.dart';
import '../../domain/model/addon.dart';
import '../../domain/model/product.dart';
import '../../domain/model/product_variant.dart';
import '../../domain/usecase/add_to_cart_usecase.dart';
import '../screens/product/widgets/addon_sheet.dart';
import '../screens/product/widgets/variant_sheet.dart';
import 'widgets/feedback/app_dialog.dart';
import 'widgets/feedback/app_toast.dart';
import 'widgets/misc/fly_to_cart.dart';

/// One place that owns "user tapped ADD".
///
/// Product cards, the details screen and the cross-sell rows all funnel through
/// here so the variant sheet, add-on sheet, seller-conflict dialog and the
/// fly-to-cart animation behave identically everywhere.
abstract final class CartActions {
  static Future<void> add(
    BuildContext context,
    WidgetRef ref, {
    required Product product,
    ProductVariant? variant,
    List<Addon> addons = const [],
    int quantity = 1,

    /// Card key used as the origin of the fly-to-cart ghost.
    GlobalKey? sourceKey,

    /// Skips the add-on sheet — the details screen collects them in-page.
    bool askForAddons = true,
  }) async {
    var chosenVariant = variant;
    var chosenAddons = addons;

    if (product.hasVariants && chosenVariant == null) {
      chosenVariant = await VariantSheet.show(context, product: product);
      if (chosenVariant == null || !context.mounted) return;
    }

    if (askForAddons && chosenAddons.isEmpty) {
      final groups = await _addonGroups(ref, product);
      if (!context.mounted) return;
      if (groups.isNotEmpty) {
        final picked = await AddonSheet.show(
          context,
          groups: groups,
          productName: product.name,
          basePrice: chosenVariant?.price ?? product.price,
        );
        if (picked == null || !context.mounted) return;
        chosenAddons = picked;
      }
    }

    await _commit(
      context,
      ref,
      product: product,
      variant: chosenVariant,
      addons: chosenAddons,
      quantity: quantity,
      sourceKey: sourceKey,
    );
  }

  static Future<void> _commit(
    BuildContext context,
    WidgetRef ref, {
    required Product product,
    required ProductVariant? variant,
    required List<Addon> addons,
    required int quantity,
    GlobalKey? sourceKey,
    bool replaceSeller = false,
  }) async {
    final outcome = await ref.read(cartProvider.notifier).add(
          product,
          variant: variant,
          addons: addons,
          quantity: quantity,
          replaceSeller: replaceSeller,
          skipVariantPrompt: true,
        );

    if (!context.mounted) return;

    switch (outcome) {
      case CartUpdated():
        if (sourceKey != null) {
          FlyToCart.run(context, sourceKey: sourceKey, imageUrl: product.imageUrl);
        }
        AppToast.success(context, '${product.name} added to cart');

      case SellerConflict(:final currentSellerName):
        final replace = await AppDialog.confirm(
          context,
          icon: Icons.storefront_outlined,
          title: 'Start a new cart?',
          message:
              'Your cart has items from $currentSellerName. Adding this will '
              'clear it so everything arrives in one delivery.',
          confirmLabel: 'Start new cart',
          destructive: true,
        );
        if (replace && context.mounted) {
          await _commit(
            context,
            ref,
            product: product,
            variant: variant,
            addons: addons,
            quantity: quantity,
            sourceKey: sourceKey,
            replaceSeller: true,
          );
        }

      case AddRejected(:final reason):
        AppToast.error(context, reason);

      case NeedsVariantSelection():
        // Unreachable: variants are resolved before this call.
        break;
    }
  }

  static Future<List<AddonGroup>> _addonGroups(
    WidgetRef ref,
    Product product,
  ) async {
    if (product.sellerId.isEmpty) return const [];
    try {
      return await ref.read(productRepositoryProvider).addonsFor(
            sellerId: product.sellerId,
            productId: product.id,
          );
    } catch (_) {
      // Add-ons are an enhancement; failing to load them must not block the add.
      return const [];
    }
  }

  /// Increments the first cart line for [product] (cards only ever show one).
  static Future<void> increment(WidgetRef ref, Product product) async {
    final cart = ref.read(cartProvider).cart;
    final line = cart.items.where((i) => i.product.id == product.id).firstOrNull;
    if (line == null) return;
    await ref.read(cartProvider.notifier).increment(line.lineId);
  }

  static Future<void> decrement(WidgetRef ref, Product product) async {
    final cart = ref.read(cartProvider).cart;
    final line = cart.items.where((i) => i.product.id == product.id).firstOrNull;
    if (line == null) return;
    await ref.read(cartProvider.notifier).decrement(line.lineId);
  }

  static Future<void> toggleWishlist(
    BuildContext context,
    WidgetRef ref,
    Product product,
  ) async {
    if (!ref.read(authProvider).isSignedIn) {
      AppToast.show(context, 'Sign in to save items to your wishlist');
      return;
    }
    // Single call site for every heart in the app (cards, PDP, sub-category),
    // so one cue here can never double-fire.
    AppHaptics.selection();
    try {
      await ref.read(wishlistProvider.notifier).toggle(product.id);
      if (!context.mounted) return;

      // Confirm by name. The heart alone is easy to miss on a dense grid, and
      // on a card the icon is small enough that a mis-tap looks identical to a
      // hit. Read back the settled state rather than assuming the flip, so the
      // wording always matches what the server actually stored.
      final saved = ref.read(wishlistProvider.notifier).contains(product.id);
      final name = product.name.trim().isEmpty ? 'Item' : product.name.trim();
      AppToast.success(
        context,
        saved ? '$name added to wishlist' : '$name removed from wishlist',
      );
    } catch (_) {
      if (context.mounted) {
        AppToast.error(context, 'Could not update your wishlist');
      }
    }
  }
}
