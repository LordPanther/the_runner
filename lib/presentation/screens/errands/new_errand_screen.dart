// lib/presentation/screens/errands/new_errand_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:the_runner/configs/size_config.dart';
import 'package:the_runner/constants/color_constant.dart';
import 'package:the_runner/constants/font_constant.dart';
import 'package:the_runner/core/utils/fees.dart';
import 'package:the_runner/core/utils/friendly_error.dart';
import 'package:the_runner/core/utils/labels.dart';
import 'package:the_runner/core/widgets/address_search_field.dart';
import 'package:the_runner/core/widgets/loading_overlay.dart';
import 'package:the_runner/data/models/errand_model.dart';
import 'package:the_runner/data/models/errand_private_details.dart';
import 'package:the_runner/data/repositories/repository.dart';
import 'package:the_runner/data/services/address_search_service.dart';
import 'package:the_runner/presentation/common_blocs/errand/errand.dart';
import 'package:the_runner/presentation/common_blocs/location/location.dart';
import 'package:the_runner/utils/translate.dart';

/// What the form needs to edit an existing errand instead of posting a
/// new one: the errand and its private details (addresses, list).
class ErrandEditArgs {
  final ErrandModel errand;
  final ErrandPrivateDetails details;

  const ErrandEditArgs({required this.errand, required this.details});
}

/// Post an errand, or (given [edit]) change one nobody has bid on and
/// relist it. Either way it goes straight into bidding once saved.
class NewErrandScreen extends StatefulWidget {
  final ErrandEditArgs? edit;

  const NewErrandScreen({super.key, this.edit});

  @override
  State<NewErrandScreen> createState() => _NewErrandScreenState();
}

class _NewErrandScreenState extends State<NewErrandScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _area = TextEditingController();
  // Picked from search results only, never free text (see
  // AddressSearchField), so every address is one a runner can find.
  AddressSuggestion? _pickup;
  AddressSuggestion? _dropoff;
  final _instructions = TextEditingController();
  final _shoppingList = TextEditingController();
  final _startingFee = TextEditingController();
  final _feeCap = TextEditingController();
  final _budget = TextEditingController();

  ErrandType _type = ErrandType.pickupDropoff;
  DateTime? _deadline;
  Duration _biddingWindow = const Duration(hours: 2);
  bool _instantAccept = true;

  static const _biddingWindows = [
    Duration(minutes: 30),
    Duration(hours: 2),
    Duration(hours: 6),
    Duration(hours: 24),
  ];

  bool get _editing => widget.edit != null;

  @override
  void initState() {
    super.initState();
    final edit = widget.edit;
    if (edit == null) return;
    final e = edit.errand;
    final d = edit.details;
    String money(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

    _type = e.type;
    _title.text = e.title;
    _description.text = e.description;
    _area.text = e.areaLabel;
    _instructions.text = d.instructions;
    _shoppingList.text = d.shoppingList.join('\n');
    _startingFee.text = money(e.startingFee);
    _feeCap.text = money(e.feeCap);
    if (e.purchaseBudget != null) _budget.text = money(e.purchaseBudget!);
    _instantAccept = e.instantAccept;
    // An old deadline that's already passed would only get rejected.
    final deadline = e.deadline;
    _deadline = deadline != null && deadline.isAfter(DateTime.now()) ? deadline : null;
    _pickup = AddressSuggestion(label: d.pickupAddress, lat: d.pickupLat, lng: d.pickupLng);
    if (d.hasDropoff && d.dropoffLat != null && d.dropoffLng != null) {
      _dropoff = AddressSuggestion(label: d.dropoffAddress, lat: d.dropoffLat!, lng: d.dropoffLng!);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _description,
      _area,
      _instructions,
      _shoppingList,
      _startingFee,
      _feeCap,
      _budget,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _money(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(' ', '').replaceAll(',', '.'));

  bool get _isShopping => _type == ErrandType.shopping;

  /// Queue and admin errands happen at one place; the others go A to B.
  bool get _needsDropoff =>
      _type == ErrandType.pickupDropoff || _type == ErrandType.shopping;

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 3))),
    );
    if (time == null) return;
    setState(() {
      _deadline = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final pickup = _pickup!;
    final dropoff = _needsDropoff ? _dropoff : null;

    final request = CreateErrandRequest(
      type: _type,
      title: _title.text.trim(),
      description: _description.text.trim(),
      areaLabel: _area.text.trim(),
      details: ErrandPrivateDetails(
        pickupAddress: pickup.label,
        pickupLat: pickup.lat,
        pickupLng: pickup.lng,
        dropoffAddress: dropoff?.label ?? '',
        dropoffLat: dropoff?.lat,
        dropoffLng: dropoff?.lng,
        shoppingList: _isShopping
            ? _shoppingList.text
                .split('\n')
                .map((l) => l.trim())
                .where((l) => l.isNotEmpty)
                .toList()
            : const [],
        instructions: _instructions.text.trim(),
      ),
      deadline: _deadline,
      biddingClosesAt: DateTime.now().add(_biddingWindow),
      startingFee: _money(_startingFee)!,
      feeCap: _money(_feeCap)!,
      instantAccept: _instantAccept,
      purchaseBudget: _isShopping ? _money(_budget) : null,
    );
    final edit = widget.edit;
    context.read<ErrandBloc>().add(edit == null
        ? CreateErrand(request)
        : RelistErrand(errandId: edit.errand.id, request: request));
  }

  /// Where the phone is, if already known, so suggestions favour nearby
  /// places ("Spar" means the Spar down the road, not one in Cape Town).
  (double, double)? get _here {
    final state = context.read<LocationBloc>().state;
    return state is LocationLoaded ? (state.latitude, state.longitude) : null;
  }

  Future<AddressSuggestion?> _currentAddress() async {
    final position = await AppRepository.locationRepository.getCurrentPosition();
    if (position == null) return null;
    return AddressSearchService.reverse(position.latitude, position.longitude);
  }

  void _onPickupChosen(AddressSuggestion? place) {
    _pickup = place;
    // Fill in the suburb runners see, unless the requester typed one.
    final suburb = place?.suburb;
    if (suburb != null && _area.text.trim().isEmpty) {
      setState(() => _area.text = suburb);
    }
  }

  @override
  Widget build(BuildContext context) {
    final here = _here;
    return BlocListener<ErrandBloc, ErrandState>(
      listener: (context, state) {
        if (state is ErrandActionInProgress) {
          LoadingOverlay.show(message: context.tr('posting_errand'));
        } else {
          LoadingOverlay.hide();
        }
        if (state is ErrandCreateSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('errand_posted'))),
          );
          Navigator.of(context).pop(state.errandId);
        } else if (state is ErrandActionSuccess && state.messageKey == 'errand_relisted') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.tr('errand_relisted'))),
          );
          Navigator.of(context).pop(true);
        } else if (state is ErrandError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.errorText(state.message))),
          );
        }
      },
      child: Scaffold(
        backgroundColor: ColorConst.backgroundColor,
        appBar: AppBar(title: Text(context.tr(_editing ? 'edit_and_relist' : 'post_an_errand'))),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: EdgeInsets.all(SizeConfig.defaultPadding),
              children: [
                _Label(context.tr('errand_type')),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final type in ErrandType.values)
                      ChoiceChip(
                        avatar: Icon(errandTypeIcon(type), size: 18),
                        label: Text(errandTypeLabel(context, type)),
                        selected: _type == type,
                        // The type can't change once posted.
                        onSelected: _editing ? null : (_) => setState(() => _type = type),
                      ),
                  ],
                ),
                _gap(),
                _Label(context.tr('what_needs_doing')),
                TextFormField(
                  controller: _title,
                  maxLength: 60,
                  decoration: InputDecoration(hintText: context.tr('errand_title_hint')),
                  validator: _required,
                ),
                TextFormField(
                  controller: _description,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: InputDecoration(hintText: context.tr('errand_description_hint')),
                ),
                if (_isShopping) ...[
                  _gap(),
                  _Label(context.tr('shopping_list')),
                  TextFormField(
                    controller: _shoppingList,
                    maxLines: 5,
                    decoration: InputDecoration(hintText: context.tr('shopping_list_hint')),
                    validator: _required,
                  ),
                ],
                _gap(),
                _Label(context.tr('where')),
                AddressSearchField(
                  hint: context.tr(_needsDropoff ? 'pickup_address' : 'errand_address'),
                  icon: Icons.trip_origin_rounded,
                  nearLat: here?.$1,
                  nearLng: here?.$2,
                  useCurrentLocation: _currentAddress,
                  initialValue: _pickup,
                  onChanged: _onPickupChosen,
                  validator: (v) => v == null ? context.tr('pick_address_from_list') : null,
                ),
                if (_needsDropoff) ...[
                  SizedBox(height: SizeConfig.defaultPadding * 0.5),
                  AddressSearchField(
                    hint: context.tr('dropoff_address'),
                    icon: Icons.place_outlined,
                    nearLat: here?.$1,
                    nearLng: here?.$2,
                    useCurrentLocation: _currentAddress,
                    initialValue: _dropoff,
                    onChanged: (place) => _dropoff = place,
                    validator: (v) => v == null ? context.tr('pick_address_from_list') : null,
                  ),
                ],
                SizedBox(height: SizeConfig.defaultPadding * 0.5),
                TextFormField(
                  controller: _area,
                  decoration: InputDecoration(
                    hintText: context.tr('area_hint'),
                    helperText: context.tr('area_helper'),
                  ),
                  validator: _required,
                ),
                SizedBox(height: SizeConfig.defaultPadding * 0.5),
                TextFormField(
                  controller: _instructions,
                  maxLines: 2,
                  decoration: InputDecoration(hintText: context.tr('instructions_hint')),
                ),
                _gap(),
                _Label(context.tr('when')),
                OutlinedButton.icon(
                  onPressed: _pickDeadline,
                  icon: const Icon(Icons.schedule_rounded),
                  label: Text(_deadline == null
                      ? context.tr('add_deadline_optional')
                      : '${MaterialLocalizations.of(context).formatMediumDate(_deadline!)}, '
                          '${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(_deadline!))}'),
                ),
                _gap(),
                _Label(context.tr('your_price')),
                Text(context.tr('price_explainer'), style: FontConst.REGULAR_SECONDARY_12),
                SizedBox(height: SizeConfig.defaultPadding * 0.5),
                Row(
                  children: [
                    Expanded(
                      child: _MoneyField(
                        controller: _startingFee,
                        hint: context.tr('starting_fee'),
                        validator: (v) {
                          final value = _money(_startingFee);
                          if (value == null || value <= 0) return context.tr('enter_an_amount');
                          return null;
                        },
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    SizedBox(width: SizeConfig.defaultPadding * 0.5),
                    Expanded(
                      child: _MoneyField(
                        controller: _feeCap,
                        hint: context.tr('fee_cap'),
                        validator: (v) {
                          final cap = _money(_feeCap);
                          final start = _money(_startingFee);
                          if (cap == null || cap <= 0) return context.tr('enter_an_amount');
                          if (start != null && cap < start) return context.tr('error_cap_below_start');
                          return null;
                        },
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                if (_isShopping) ...[
                  SizedBox(height: SizeConfig.defaultPadding * 0.5),
                  _MoneyField(
                    controller: _budget,
                    hint: context.tr('purchase_budget'),
                    helper: context.tr('purchase_budget_helper'),
                    validator: (v) {
                      final value = _money(_budget);
                      if (value == null || value <= 0) return context.tr('enter_an_amount');
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                ],
                SizedBox(height: SizeConfig.defaultPadding * 0.5),
                _PriceSummary(
                  startingFee: _money(_startingFee),
                  feeCap: _money(_feeCap),
                  budget: _isShopping ? _money(_budget) : null,
                ),
                _gap(),
                _Label(context.tr('bidding_window')),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final window in _biddingWindows)
                      ChoiceChip(
                        label: Text(window.inHours >= 1
                            ? context.tr('hours_short', {'h': window.inHours})
                            : context.tr('minutes_short', {'m': window.inMinutes})),
                        selected: _biddingWindow == window,
                        onSelected: (_) => setState(() => _biddingWindow = window),
                      ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _instantAccept,
                  onChanged: (v) => setState(() => _instantAccept = v),
                  title: Text(context.tr('instant_accept'), style: FontConst.MEDIUM_DEFAULT),
                  subtitle: Text(
                    context.tr('instant_accept_explainer'),
                    style: FontConst.REGULAR_SECONDARY_12,
                  ),
                ),
                _gap(),
                ElevatedButton(
                  onPressed: _submit,
                  child: Text(context.tr(_editing ? 'relist_errand' : 'post_errand')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _required(String? value) =>
      (value == null || value.trim().isEmpty) ? context.tr('required_field') : null;

  Widget _gap() => SizedBox(height: SizeConfig.defaultPadding * 1.2);
}

class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: FontConst.BOLD_DEFAULT_16),
    );
  }
}

class _MoneyField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? helper;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;

  const _MoneyField({
    required this.controller,
    required this.hint,
    this.helper,
    this.validator,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      decoration: InputDecoration(
        labelText: hint,
        prefixText: 'R ',
        helperText: helper,
      ),
      validator: validator,
      onChanged: onChanged,
    );
  }
}

/// "You'll pay between R63 and R105 (incl. 5% service fee)". Shown live
/// as the requester types, so the fee split is never a surprise.
class _PriceSummary extends StatelessWidget {
  final double? startingFee;
  final double? feeCap;
  final double? budget;

  const _PriceSummary({this.startingFee, this.feeCap, this.budget});

  @override
  Widget build(BuildContext context) {
    if (startingFee == null || feeCap == null || feeCap! < startingFee!) {
      return const SizedBox.shrink();
    }
    final low = Fees.requesterTotal(startingFee!, purchaseBudget: budget ?? 0);
    final high = Fees.requesterTotal(feeCap!, purchaseBudget: budget ?? 0);
    return Container(
      padding: EdgeInsets.all(SizeConfig.defaultPadding * 0.7),
      decoration: BoxDecoration(
        color: ColorConst.secondaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_outline_rounded, size: 18, color: ColorConst.secondaryColor),
          SizedBox(width: SizeConfig.defaultPadding * 0.5),
          Expanded(
            child: Text(
              context.tr('you_will_pay_range', {
                'low': Fees.format(low),
                'high': Fees.format(high),
              }),
              style: FontConst.REGULAR_DEFAULT,
            ),
          ),
        ],
      ),
    );
  }
}
