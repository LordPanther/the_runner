// lib/presentation/screens/errands/bid_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:the_runner/configs/size_config.dart';
import 'package:the_runner/constants/color_constant.dart';
import 'package:the_runner/constants/font_constant.dart';
import 'package:the_runner/core/utils/fees.dart';
import 'package:the_runner/data/models/bid_model.dart';
import 'package:the_runner/data/models/errand_model.dart';
import 'package:the_runner/utils/translate.dart';

/// What the runner entered. Null from [showBidSheet] means they closed it.
class BidInput {
  final double amount;
  final String message;

  const BidInput(this.amount, this.message);
}

/// Bottom sheet for placing (or editing, when [existing] is given) a bid.
/// Shows "you'll receive R95" live, so the 5% never surprises a runner.
Future<BidInput?> showBidSheet(
  BuildContext context, {
  required ErrandModel errand,
  BidModel? existing,
}) {
  return showModalBottomSheet<BidInput>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ColorConst.surfaceColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _BidSheet(errand: errand, existing: existing),
  );
}

class _BidSheet extends StatefulWidget {
  final ErrandModel errand;
  final BidModel? existing;

  const _BidSheet({required this.errand, this.existing});

  @override
  State<_BidSheet> createState() => _BidSheetState();
}

class _BidSheetState extends State<_BidSheet> {
  late double _amount;
  late final TextEditingController _amountText;
  final _message = TextEditingController();

  @override
  void initState() {
    super.initState();
    _amount = widget.existing?.amount ?? widget.errand.startingFee;
    _amountText = TextEditingController(text: _amount.toStringAsFixed(0));
    _message.text = widget.existing?.message ?? '';
  }

  @override
  void dispose() {
    _amountText.dispose();
    _message.dispose();
    super.dispose();
  }

  bool get _inRange =>
      _amount >= widget.errand.startingFee && _amount <= widget.errand.feeCap;

  @override
  Widget build(BuildContext context) {
    final errand = widget.errand;
    // A slider only makes sense when there's a range to slide across.
    final hasRange = errand.feeCap > errand.startingFee;

    return Padding(
      padding: EdgeInsets.only(
        left: SizeConfig.defaultPadding,
        right: SizeConfig.defaultPadding,
        top: SizeConfig.defaultPadding,
        bottom: MediaQuery.of(context).viewInsets.bottom + SizeConfig.defaultPadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr(widget.existing == null ? 'place_a_bid' : 'edit_your_bid'),
            style: FontConst.BOLD_DEFAULT_20,
          ),
          SizedBox(height: SizeConfig.defaultPadding * 0.3),
          Text(
            context.tr('bid_range', {
              'low': Fees.format(errand.startingFee),
              'high': Fees.format(errand.feeCap),
            }),
            style: FontConst.REGULAR_SECONDARY_14,
          ),
          SizedBox(height: SizeConfig.defaultPadding * 0.8),
          TextField(
            controller: _amountText,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            decoration: InputDecoration(
              labelText: context.tr('your_bid'),
              prefixText: 'R ',
              errorText: _inRange ? null : context.tr('error_bid_out_of_range'),
            ),
            onChanged: (v) => setState(() => _amount = double.tryParse(v) ?? 0),
          ),
          if (hasRange)
            Slider(
              value: _amount.clamp(errand.startingFee, errand.feeCap).toDouble(),
              min: errand.startingFee,
              max: errand.feeCap,
              activeColor: ColorConst.primaryColor,
              onChanged: (v) => setState(() {
                _amount = v.roundToDouble();
                _amountText.text = _amount.toStringAsFixed(0);
              }),
            ),
          Container(
            padding: EdgeInsets.all(SizeConfig.defaultPadding * 0.6),
            decoration: BoxDecoration(
              color: ColorConst.secondaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              context.tr('you_will_receive', {
                'amount': Fees.format(errand.runnerPayoutFor(_amount)),
              }),
              style: FontConst.MEDIUM_DEFAULT,
            ),
          ),
          SizedBox(height: SizeConfig.defaultPadding * 0.6),
          TextField(
            controller: _message,
            maxLines: 2,
            maxLength: 200,
            decoration: InputDecoration(hintText: context.tr('bid_message_hint')),
          ),
          ElevatedButton(
            onPressed: _inRange
                ? () => Navigator.of(context).pop(BidInput(_amount, _message.text.trim()))
                : null,
            child: Text(context.tr(widget.existing == null ? 'send_bid' : 'update_bid')),
          ),
        ],
      ),
    );
  }
}
