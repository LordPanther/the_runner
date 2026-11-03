// lib/core/widgets/errand_card.dart

import 'package:flutter/material.dart';
import 'package:the_runner/configs/size_config.dart';
import 'package:the_runner/constants/color_constant.dart';
import 'package:the_runner/constants/font_constant.dart';
import 'package:the_runner/core/utils/fees.dart';
import 'package:the_runner/core/utils/labels.dart';
import 'package:the_runner/data/models/errand_model.dart';
import 'package:the_runner/utils/translate.dart';

/// One errand in any list: the feed, My Errands, My Runs. Takes an
/// onTap callback rather than navigating itself, so it can be reused
/// anywhere results need showing.
class ErrandCard extends StatelessWidget {
  final ErrandModel errand;
  final double? distanceMeters;
  final VoidCallback? onTap;

  /// Shows the status chip. Off in the runner feed, where every errand
  /// is in bidding anyway.
  final bool showStatus;

  const ErrandCard({
    super.key,
    required this.errand,
    this.distanceMeters,
    this.onTap,
    this.showStatus = true,
  });

  String _distanceLabel(BuildContext context) {
    if (distanceMeters == null) return '';
    return distanceMeters! < 1000
        ? context.tr('m_away', {'m': distanceMeters!.round()})
        : context.tr('km_away', {'km': (distanceMeters! / 1000).toStringAsFixed(1)});
  }

  @override
  Widget build(BuildContext context) {
    final accent = errand.isShopping ? ColorConst.accentColor : ColorConst.primaryColor;
    final subtitle = [
      errandTypeLabel(context, errand.type),
      if (errand.areaLabel.isNotEmpty) errand.areaLabel,
      if (distanceMeters != null) _distanceLabel(context),
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: EdgeInsets.all(SizeConfig.defaultPadding * 0.7),
        decoration: BoxDecoration(
          color: ColorConst.surfaceColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ColorConst.borderColor),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(errandTypeIcon(errand.type), size: 18, color: accent),
            ),
            SizedBox(width: SizeConfig.defaultPadding * 0.6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    errand.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FontConst.MEDIUM_DEFAULT_16,
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FontConst.REGULAR_SECONDARY_12,
                  ),
                  if (showStatus) ...[
                    const SizedBox(height: 4),
                    ErrandStatusChip(status: errand.status),
                  ],
                ],
              ),
            ),
            SizedBox(width: SizeConfig.defaultPadding * 0.4),
            _PriceColumn(errand: errand),
          ],
        ),
      ),
    );
  }
}

/// Agreed fee once a bid is accepted, otherwise the bidding range, with
/// the bid count underneath.
class _PriceColumn extends StatelessWidget {
  final ErrandModel errand;

  const _PriceColumn({required this.errand});

  @override
  Widget build(BuildContext context) {
    final price = errand.agreedFee != null
        ? Fees.format(errand.agreedFee!)
        : '${Fees.format(errand.startingFee)}–${Fees.format(errand.feeCap)}';
    final bids = errand.bidCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(price, style: FontConst.BOLD_PRIMARY_16),
        if (errand.status.isBiddable && bids != null)
          Text(
            bids == 0
                ? context.tr('no_bids_yet')
                : context.tr('bids_count', {'count': bids}),
            style: FontConst.REGULAR_SECONDARY_12,
          ),
      ],
    );
  }
}

class ErrandStatusChip extends StatelessWidget {
  final ErrandStatus status;

  const ErrandStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = errandStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        errandStatusLabel(context, status),
        style: FontConst.MEDIUM_SECONDARY_12.copyWith(color: color),
      ),
    );
  }
}
