import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../di/app_providers.dart';
import '../../domain/model/product.dart';
import '../../domain/usecase/add_to_cart_usecase.dart';
import '../../navigation/route_paths.dart';
import '../screens/scanner/image_scan_analyzer.dart';
import '../screens/scanner/scan_matcher.dart';
import 'widgets/feedback/app_toast.dart';
import 'widgets/misc/app_network_image.dart';

/// The search-bar scanner. Snaps one photo and lets the user add products from
/// it — whether that photo is a barcode, a branded product (recognised by the
/// text on its packaging), loose produce (recognised by image label), or a
/// whole written grocery list. Every match comes from the live catalogue.
///
///  • Exactly one confident match → its name and image flash up, then it is
///    added automatically.
///  • Several matches, or any uncertain one → a sheet where the user ticks what
///    to add (uncertain matches start unticked, so a weak guess is never added
///    without confirmation).
abstract final class SmartScan {
  static bool _running = false;

  static Future<void> run(BuildContext context, WidgetRef ref) async {
    if (_running) return;
    _running = true;
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
      );
      if (photo == null || !context.mounted) return;

      final rootNav = Navigator.of(context, rootNavigator: true);
      _showProgress(context);
      List<DetectedProduct> detections;
      try {
        final candidates = await ImageScanAnalyzer().analyze(photo.path);
        detections = await ref.read(scanMatcherProvider).matchDetections(candidates);
      } finally {
        _dismissProgress(rootNav);
      }

      if (!context.mounted) return;
      if (detections.isEmpty) {
        AppToast.error(context, 'Couldn\'t recognise any products. Try again.');
        return;
      }

      // One sure thing → preview briefly, then add it.
      if (detections.length == 1 && !detections.first.needsConfirmation) {
        await _autoAdd(context, ref, detections.first);
        return;
      }

      // Otherwise let the user choose what to add.
      final chosen = await _showSelectionSheet(context, detections);
      if (chosen == null || chosen.isEmpty || !context.mounted) return;
      final summary = await _addAll(ref, chosen);
      if (context.mounted) {
        await _showSummary(context, summary.added, summary.unavailable);
      }
    } on MissingPluginException catch (e, s) {
      debugPrint('SmartScan MissingPlugin: $e\n$s');
      if (context.mounted) {
        AppToast.error(
          context,
          'Scanner needs a fresh install. Please fully restart the app.',
        );
      }
    } on PlatformException catch (e, s) {
      debugPrint('SmartScan PlatformException: ${e.code} ${e.message}\n$s');
      if (context.mounted) {
        AppToast.error(
          context,
          e.code == 'camera_access_denied'
              ? 'Camera permission is needed to scan.'
              : 'Could not open the camera. Please try again.',
        );
      }
    } catch (e, s) {
      debugPrint('SmartScan error: $e\n$s');
      if (context.mounted) {
        AppToast.error(context, 'Could not scan. Please try again.');
      }
    } finally {
      _running = false;
    }
  }

  // ── Adding ────────────────────────────────────────────────────────────────

  /// Flashes the detected product, then adds it (asking to switch stores if the
  /// cart belongs to another seller).
  static Future<void> _autoAdd(
    BuildContext context,
    WidgetRef ref,
    DetectedProduct detection,
  ) async {
    await _showPreview(context, detection);
    if (!context.mounted) return;

    final product = detection.product;
    if (ref.read(cartProvider).cart.quantityOf(product.id) > 0) {
      AppToast.info(context, '${product.name} is already in your cart');
      return;
    }

    final notifier = ref.read(cartProvider.notifier);
    var outcome = await notifier.add(product, skipVariantPrompt: true);
    if (!context.mounted) return;
    switch (outcome) {
      case CartUpdated():
        AppToast.success(context, '${product.name} added to cart');
      case AddRejected(:final reason):
        AppToast.error(context, reason);
      case SellerConflict():
      case NeedsVariantSelection():
        // Rare from a scan; fall back to the chooser so the user stays in control.
        final chosen = await _showSelectionSheet(context, [detection]);
        if (chosen != null && chosen.isNotEmpty && context.mounted) {
          final summary = await _addAll(ref, chosen);
          if (context.mounted) {
            await _showSummary(context, summary.added, summary.unavailable);
          }
        }
    }
  }

  static Future<({int added, List<String> unavailable})> _addAll(
    WidgetRef ref,
    List<Product> products,
  ) async {
    final notifier = ref.read(cartProvider.notifier);
    var added = 0;
    final unavailable = <String>[];

    for (final product in products) {
      if (ref.read(cartProvider).cart.quantityOf(product.id) > 0) continue;
      final outcome = await notifier.add(product, skipVariantPrompt: true);
      switch (outcome) {
        case CartUpdated():
          added++;
        case SellerConflict():
          unavailable.add('${product.name} (another store)');
        case AddRejected():
          unavailable.add(product.name);
        case NeedsVariantSelection():
          break;
      }
    }
    return (added: added, unavailable: unavailable);
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  static bool _progressUp = false;

  static void _showProgress(BuildContext context) {
    _progressUp = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text('Recognising…', style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }

  static void _dismissProgress(NavigatorState navigator) {
    if (!_progressUp) return;
    _progressUp = false;
    if (navigator.mounted) navigator.pop();
  }

  /// Shows the detected product's image and name for a moment before adding.
  static Future<void> _showPreview(
    BuildContext context,
    DetectedProduct detection,
  ) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AppNetworkImage(
                  url: detection.product.imageUrl,
                  width: 96,
                  height: 96,
                ),
              ),
              const SizedBox(height: 12),
              Text('Detected', style: context.text.labelMedium),
              const SizedBox(height: 2),
              Text(
                detection.product.name,
                textAlign: TextAlign.center,
                style: context.text.titleMedium,
              ),
              const SizedBox(height: 4),
              Text('Adding to cart…', style: context.text.bodySmall),
            ],
          ),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 1300));
    if (navigator.mounted) navigator.pop();
  }

  /// Returns the products the user chose to add, or null if they cancelled.
  static Future<List<Product>?> _showSelectionSheet(
    BuildContext context,
    List<DetectedProduct> detections,
  ) {
    return showModalBottomSheet<List<Product>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SelectionSheet(detections: detections),
    );
  }

  static Future<void> _showSummary(
    BuildContext context,
    int added,
    List<String> unavailable,
  ) {
    final headline =
        added == 1 ? '1 item added to cart' : '$added items added to cart';
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(headline),
        content: unavailable.isEmpty
            ? null
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${unavailable.length} not added:',
                    style: dialogContext.text.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 160),
                    child: SingleChildScrollView(
                      child: Text(
                        unavailable.map((n) => '• $n').join('\n'),
                        style: dialogContext.text.bodySmall!.copyWith(
                          color: dialogContext.semantic.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Done'),
          ),
          if (added > 0)
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                dialogContext.go(RoutePaths.cart);
              },
              child: const Text('View cart'),
            ),
        ],
      ),
    );
  }
}

/// Checklist of scanned matches. Confident matches start ticked; uncertain ones
/// start unticked so the user has to opt in.
class _SelectionSheet extends StatefulWidget {
  const _SelectionSheet({required this.detections});

  final List<DetectedProduct> detections;

  @override
  State<_SelectionSheet> createState() => _SelectionSheetState();
}

class _SelectionSheetState extends State<_SelectionSheet> {
  late final List<bool> _checked = [
    for (final d in widget.detections) !d.needsConfirmation,
  ];

  int get _count => _checked.where((c) => c).length;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Row(
              children: [
                Text('We found these', style: context.text.titleMedium),
                const Spacer(),
                Text(
                  'Tap to confirm uncertain items',
                  style: context.text.bodySmall!
                      .copyWith(color: context.semantic.textSecondary),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.detections.length,
              itemBuilder: (context, i) {
                final d = widget.detections[i];
                return CheckboxListTile(
                  value: _checked[i],
                  onChanged: (v) => setState(() => _checked[i] = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  secondary: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: AppNetworkImage(
                      url: d.product.imageUrl,
                      width: 44,
                      height: 44,
                    ),
                  ),
                  title: Text(d.product.name),
                  subtitle: Text(
                    d.needsConfirmation
                        ? 'Not sure — confirm to add'
                        : '₹${d.product.price.toStringAsFixed(0)}',
                    style: d.needsConfirmation
                        ? context.text.bodySmall!
                            .copyWith(color: context.semantic.warning)
                        : context.text.bodySmall,
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _count == 0
                    ? null
                    : () => Navigator.of(context).pop([
                          for (var i = 0; i < widget.detections.length; i++)
                            if (_checked[i]) widget.detections[i].product,
                        ]),
                child: Text(_count == 0 ? 'Select items' : 'Add $_count to cart'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
