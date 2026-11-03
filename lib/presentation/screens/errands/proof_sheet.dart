// lib/presentation/screens/errands/proof_sheet.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:the_runner/configs/size_config.dart';
import 'package:the_runner/constants/color_constant.dart';
import 'package:the_runner/constants/font_constant.dart';
import 'package:the_runner/core/utils/fees.dart';
import 'package:the_runner/data/models/errand_model.dart';
import 'package:the_runner/data/repositories/errand/errand_repository.dart';
import 'package:the_runner/utils/translate.dart';

/// Bottom sheet where the runner adds photos (and, for shopping, the
/// till slip and its total) before finishing. Returns the request, or
/// null if they closed it.
Future<SubmitProofRequest?> showProofSheet(
  BuildContext context, {
  required ErrandModel errand,
}) {
  return showModalBottomSheet<SubmitProofRequest>(
    context: context,
    isScrollControlled: true,
    backgroundColor: ColorConst.surfaceColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _ProofSheet(errand: errand),
  );
}

class _ProofSheet extends StatefulWidget {
  final ErrandModel errand;

  const _ProofSheet({required this.errand});

  @override
  State<_ProofSheet> createState() => _ProofSheetState();
}

class _ProofSheetState extends State<_ProofSheet> {
  static const _maxPhotos = 4;

  final _picker = ImagePicker();
  final List<File> _photos = [];
  File? _receipt;
  final _total = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _total.dispose();
    _note.dispose();
    super.dispose();
  }

  double? get _totalValue => double.tryParse(_total.text.replaceAll(',', '.'));

  bool get _overBudget {
    final budget = widget.errand.purchaseBudget;
    final total = _totalValue;
    return budget != null && total != null && total > budget;
  }

  bool get _canSubmit {
    if (_photos.isEmpty) return false;
    if (!widget.errand.isShopping) return true;
    return _receipt != null && _totalValue != null && !_overBudget;
  }

  Future<File?> _take() async {
    final picked = await _picker.pickImage(source: ImageSource.camera, maxWidth: 1600);
    return picked == null ? null : File(picked.path);
  }

  @override
  Widget build(BuildContext context) {
    final errand = widget.errand;
    return Padding(
      padding: EdgeInsets.only(
        left: SizeConfig.defaultPadding,
        right: SizeConfig.defaultPadding,
        top: SizeConfig.defaultPadding,
        bottom: MediaQuery.of(context).viewInsets.bottom + SizeConfig.defaultPadding,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.tr('submit_proof'), style: FontConst.BOLD_DEFAULT_20),
            SizedBox(height: SizeConfig.defaultPadding * 0.3),
            Text(context.tr('proof_explainer'), style: FontConst.REGULAR_SECONDARY_14),
            SizedBox(height: SizeConfig.defaultPadding * 0.8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final photo in _photos)
                  _Thumb(file: photo, onRemove: () => setState(() => _photos.remove(photo))),
                if (_photos.length < _maxPhotos)
                  _AddTile(
                    label: context.tr('add_photo'),
                    onTap: () async {
                      final file = await _take();
                      if (file != null) setState(() => _photos.add(file));
                    },
                  ),
              ],
            ),
            if (errand.isShopping) ...[
              SizedBox(height: SizeConfig.defaultPadding),
              Text(context.tr('till_slip'), style: FontConst.MEDIUM_DEFAULT_16),
              SizedBox(height: SizeConfig.defaultPadding * 0.4),
              Row(
                children: [
                  _receipt == null
                      ? _AddTile(
                          label: context.tr('add_receipt'),
                          onTap: () async {
                            final file = await _take();
                            if (file != null) setState(() => _receipt = file);
                          },
                        )
                      : _Thumb(file: _receipt!, onRemove: () => setState(() => _receipt = null)),
                  SizedBox(width: SizeConfig.defaultPadding * 0.6),
                  Expanded(
                    child: TextField(
                      controller: _total,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                      decoration: InputDecoration(
                        labelText: context.tr('receipt_total'),
                        prefixText: 'R ',
                        helperText: context.tr('budget_was', {
                          'amount': Fees.format(errand.purchaseBudget ?? 0),
                        }),
                        errorText: _overBudget ? context.tr('error_over_budget') : null,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ],
            SizedBox(height: SizeConfig.defaultPadding * 0.6),
            TextField(
              controller: _note,
              maxLines: 2,
              decoration: InputDecoration(hintText: context.tr('proof_note_hint')),
            ),
            SizedBox(height: SizeConfig.defaultPadding * 0.6),
            ElevatedButton(
              onPressed: _canSubmit
                  ? () => Navigator.of(context).pop(SubmitProofRequest(
                        errandId: errand.id,
                        photos: List.of(_photos),
                        receipt: _receipt,
                        finalPurchaseAmount: errand.isShopping ? _totalValue : null,
                        note: _note.text.trim(),
                      ))
                  : null,
              child: Text(context.tr('submit_proof')),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final File file;
  final VoidCallback onRemove;

  const _Thumb({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(file, width: 72, height: 72, fit: BoxFit.cover),
        ),
        Positioned(
          right: -6,
          top: -6,
          child: GestureDetector(
            onTap: onRemove,
            child: const CircleAvatar(
              radius: 11,
              backgroundColor: Colors.black54,
              child: Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AddTile({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ColorConst.borderColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_camera_outlined, color: ColorConst.primaryColor),
            Text(label, style: FontConst.REGULAR_SECONDARY_12, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
