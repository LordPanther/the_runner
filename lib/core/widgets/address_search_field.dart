// lib/core/widgets/address_search_field.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:the_runner/constants/color_constant.dart';
import 'package:the_runner/constants/font_constant.dart';
import 'package:the_runner/data/services/address_search_service.dart';
import 'package:the_runner/utils/translate.dart';

/// An address box that only accepts a place picked from search results.
/// Typing shows suggestions underneath; choosing one locks it in (green
/// tick). Editing the text again clears the choice, so a typo can never
/// sneak through as a "real" address.
///
/// Suggestions show inline (not in an overlay) so they scroll naturally
/// with the form and never end up hidden behind the keyboard.
class AddressSearchField extends FormField<AddressSuggestion> {
  AddressSearchField({
    super.key,
    required String hint,
    required IconData icon,
    double? nearLat,
    double? nearLng,
    ValueChanged<AddressSuggestion?>? onChanged,

    /// Shows a "Use my current location" button; called when tapped and
    /// should return the address at the person's position (or null).
    Future<AddressSuggestion?> Function()? useCurrentLocation,
    /// Pre-picked address, e.g. when editing an errand.
    super.initialValue,
    super.validator,
  }) : super(
          builder: (field) => _AddressSearchBody(
            field: field,
            hint: hint,
            icon: icon,
            nearLat: nearLat,
            nearLng: nearLng,
            onChanged: onChanged,
            useCurrentLocation: useCurrentLocation,
          ),
        );
}

class _AddressSearchBody extends StatefulWidget {
  final FormFieldState<AddressSuggestion> field;
  final String hint;
  final IconData icon;
  final double? nearLat;
  final double? nearLng;
  final ValueChanged<AddressSuggestion?>? onChanged;
  final Future<AddressSuggestion?> Function()? useCurrentLocation;

  const _AddressSearchBody({
    required this.field,
    required this.hint,
    required this.icon,
    this.nearLat,
    this.nearLng,
    this.onChanged,
    this.useCurrentLocation,
  });

  @override
  State<_AddressSearchBody> createState() => _AddressSearchBodyState();
}

class _AddressSearchBodyState extends State<_AddressSearchBody> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  List<AddressSuggestion> _results = const [];
  bool _searching = false;
  bool _failed = false;

  /// Bumped on every new search, so a slow older response can't
  /// overwrite the results for what's typed now.
  int _searchId = 0;

  @override
  void initState() {
    super.initState();
    // Editing: show the already-picked address with its green tick.
    final initial = widget.field.value;
    if (initial != null) _controller.text = initial.label;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onTyped(String text) {
    // Any edit means the old pick no longer matches what's shown.
    if (widget.field.value != null) _select(null, keepText: true);

    _debounce?.cancel();
    if (text.trim().length < 3) {
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    // Wait for a pause in typing: one request per word, not per letter.
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(text));
  }

  Future<void> _search(String text) async {
    final id = ++_searchId;
    try {
      final results = await AddressSearchService.search(
        text,
        nearLat: widget.nearLat,
        nearLng: widget.nearLng,
      );
      if (!mounted || id != _searchId) return;
      setState(() {
        _results = results;
        _searching = false;
        _failed = false;
      });
    } catch (_) {
      if (!mounted || id != _searchId) return;
      setState(() {
        _results = const [];
        _searching = false;
        _failed = true;
      });
    }
  }

  void _select(AddressSuggestion? suggestion, {bool keepText = false}) {
    if (suggestion != null && !keepText) {
      _controller.text = suggestion.label;
      _focus.unfocus();
    }
    setState(() {
      _results = const [];
      _failed = false;
    });
    widget.field.didChange(suggestion);
    widget.onChanged?.call(suggestion);
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _searching = true);
    try {
      final here = await widget.useCurrentLocation!();
      if (!mounted) return;
      setState(() => _searching = false);
      if (here == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('location_not_available'))),
        );
        return;
      }
      _select(here);
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final picked = widget.field.value != null;
    final text = _controller.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focus,
          onChanged: _onTyped,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: Icon(widget.icon),
            errorText: widget.field.errorText,
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : picked
                    ? Icon(Icons.check_circle_rounded, color: ColorConst.successColor)
                    : null,
          ),
        ),
        if (widget.useCurrentLocation != null && !picked)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _searching ? null : _useCurrentLocation,
              icon: const Icon(Icons.my_location_rounded, size: 18),
              label: Text(context.tr('use_my_location')),
            ),
          ),
        if (_results.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: ColorConst.surfaceColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: ColorConst.borderColor),
            ),
            child: Column(
              children: [
                for (final result in _results)
                  ListTile(
                    dense: true,
                    leading: Icon(Icons.place_outlined, color: ColorConst.primaryColor),
                    title: Text(
                      result.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: FontConst.REGULAR_DEFAULT,
                    ),
                    onTap: () => _select(result),
                  ),
              ],
            ),
          )
        else if (!picked && !_searching && text.length >= 3)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              context.tr(_failed ? 'address_search_failed' : 'address_no_results'),
              style: FontConst.REGULAR_SECONDARY_12,
            ),
          ),
      ],
    );
  }
}
