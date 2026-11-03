// lib/core/utils/labels.dart

import 'package:flutter/material.dart';
import 'package:the_runner/constants/color_constant.dart';
import 'package:the_runner/data/models/errand_model.dart';
import 'package:the_runner/utils/translate.dart';

/// Display names for values the app STORES in English (errand types and
/// statuses). The stored value never changes, only what the person
/// sees, so switching language doesn't break queries or data.

String errandTypeLabel(BuildContext context, ErrandType type) =>
    context.tr('errand_type_${type.wire}');

IconData errandTypeIcon(ErrandType type) {
  switch (type) {
    case ErrandType.pickupDropoff:
      return Icons.local_shipping_outlined;
    case ErrandType.queue:
      return Icons.hourglass_bottom_rounded;
    case ErrandType.admin:
      return Icons.description_outlined;
    case ErrandType.shopping:
      return Icons.shopping_basket_outlined;
  }
}

String errandStatusLabel(BuildContext context, ErrandStatus status) =>
    context.tr('errand_status_${status.wire}');

/// Status chip colour: green when money is safely moving, gold while
/// someone needs to act, red for the two "something went wrong" states.
Color errandStatusColor(ErrandStatus status) {
  switch (status) {
    case ErrandStatus.completed:
    case ErrandStatus.funded:
    case ErrandStatus.inProgress:
      return ColorConst.successColor;
    case ErrandStatus.disputed:
    case ErrandStatus.cancelled:
      return ColorConst.errorColor;
    case ErrandStatus.accepted:
    case ErrandStatus.proofSubmitted:
      return ColorConst.warningColor;
    case ErrandStatus.draft:
    case ErrandStatus.bidding:
      return ColorConst.secondaryColor;
  }
}
