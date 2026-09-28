import 'package:flutter/material.dart';

import '../../../../../core/theme/app_radii.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../common/widgets/buttons/primary_button.dart';
import '../../../../common/widgets/feedback/app_bottom_sheet.dart';
import '../../../../common/widgets/inputs/app_text_field.dart';
import '../../../../common/widgets/misc/rating_stars.dart';

typedef ReviewDraft = ({String orderId, int rating, String comment});

/// Rating + comment form.
///
/// A review must be attached to a delivered order, because that is the only
/// place the backend stores item ratings — so the sheet asks which order.
class WriteReviewSheet extends StatefulWidget {
  const WriteReviewSheet({super.key, required this.orders});

  final List<({String orderId, String displayId, DateTime placedAt})> orders;

  static Future<ReviewDraft?> show(
    BuildContext context, {
    required String productName,
    required List<({String orderId, String displayId, DateTime placedAt})> orders,
  }) =>
      AppBottomSheet.show<ReviewDraft>(
        context,
        title: 'Rate $productName',
        subtitle: 'Your review helps other shoppers decide',
        child: WriteReviewSheet(orders: orders),
      );

  @override
  State<WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends State<WriteReviewSheet> {
  final _comment = TextEditingController();
  late String _orderId = widget.orders.first.orderId;
  int _rating = 0;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: RatingInput(
              rating: _rating,
              onChanged: (value) => setState(() => _rating = value),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (widget.orders.length > 1) ...[
            Text('Which order?', style: context.text.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: widget.orders
                  .map(
                    (order) => GestureDetector(
                      onTap: () => setState(() => _orderId = order.orderId),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: _orderId == order.orderId
                              ? context.colors.primary.withValues(alpha: 0.10)
                              : context.semantic.surfaceAlt,
                          borderRadius: AppRadii.rPill,
                          border: Border.all(
                            color: _orderId == order.orderId
                                ? context.colors.primary
                                : context.semantic.border,
                          ),
                        ),
                        child: Text(
                          order.displayId,
                          style: context.text.labelMedium,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          AppTextField(
            controller: _comment,
            label: 'Tell us more (optional)',
            hint: 'What did you like, or what could be better?',
            maxLines: 4,
            maxLength: 500,
          ),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: 'Submit review',
            onPressed: _rating == 0
                ? null
                : () => Navigator.of(context).pop((
                      orderId: _orderId,
                      rating: _rating,
                      comment: _comment.text.trim(),
                    )),
          ),
        ],
      ),
    );
  }
}
