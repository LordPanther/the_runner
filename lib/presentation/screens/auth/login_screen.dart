import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:the_runner/configs/router.dart';
import 'package:the_runner/configs/size_config.dart';
import 'package:the_runner/constants/color_constant.dart';
import 'package:the_runner/constants/font_constant.dart';
import 'package:the_runner/constants/country_code_constant.dart';
import 'package:the_runner/core/utils/phone_number.dart';
import 'package:the_runner/presentation/common_blocs/auth/auth.dart';
import 'package:the_runner/utils/translate.dart';
import 'package:the_runner/core/utils/friendly_error.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  CountryCode _selectedCountry = countryCodes.first;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  // Handles the leading 0 (082...), spaces, dashes and a typed +27, so
  // the number always reaches Firebase as +27821234567.
  String get _fullPhoneNumber =>
      normalizePhoneNumber(_phoneController.text, _selectedCountry.dialCode);

  void _pickCountryCode() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.symmetric(vertical: SizeConfig.defaultPadding),
        itemCount: countryCodes.length,
        separatorBuilder: (_, _) => Divider(color: ColorConst.dividerColor),
        itemBuilder: (context, index) {
          final country = countryCodes[index];
          return ListTile(
            leading: Text(country.flag, style: const TextStyle(fontSize: 24)),
            title: Text(country.name, style: FontConst.MEDIUM_DEFAULT_16),
            trailing: Text(country.dialCode, style: FontConst.REGULAR_SECONDARY_14),
            onTap: () {
              setState(() => _selectedCountry = country);
              Navigator.of(context).pop();
            },
          );
        },
      ),
    );
  }

  void _onContinuePressed() {
    if (_formKey.currentState?.validate() != true) return;
    FocusScope.of(context).unfocus();
    context.read<AuthBloc>().add(SignInWithPhone(_fullPhoneNumber));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorConst.backgroundColor,
      body: SafeArea(
        child: BlocConsumer<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is PhoneVerificationSent) {
              Navigator.of(context).pushNamed(
                AppRouter.otpVerification,
                arguments: {
                  'verificationId': state.verificationId,
                  'phoneNumber': _fullPhoneNumber,
                },
              );
            } else if (state is AuthError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(context.errorText(state.message)),
                  backgroundColor: ColorConst.errorColor,
                ),
              );
            }
          },
          builder: (context, state) {
            final isLoading = state is AuthLoading;

            return SingleChildScrollView(
              padding: EdgeInsets.all(SizeConfig.defaultPadding * 1.5),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: SizeConfig.defaultPadding * 2),
                    Icon(
                      Icons.location_on_rounded,
                      size: SizeConfig.defaultSize * 4,
                      color: ColorConst.primaryColor,
                    ),
                    SizedBox(height: SizeConfig.defaultPadding * 1.5),
                    Text(Translate.of(context).translate('welcome_to_runner'), style: FontConst.BOLD_DEFAULT_26),
                    SizedBox(height: SizeConfig.defaultPadding * 0.5),
                    Text(
                      Translate.of(context).translate('enter_your_phone_number_to_continue'),
                      style: FontConst.REGULAR_SECONDARY_14,
                    ),
                    SizedBox(height: SizeConfig.defaultPadding * 2.5),
                    Text(Translate.of(context).translate('phone_number'), style: FontConst.MEDIUM_DEFAULT_16),
                    SizedBox(height: SizeConfig.defaultPadding * 0.6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: _pickCountryCode,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            height: SizeConfig.defaultSize * 4.8,
                            padding: EdgeInsets.symmetric(
                              horizontal: SizeConfig.defaultPadding * 0.8,
                            ),
                            decoration: BoxDecoration(
                              color: ColorConst.surfaceColor,
                              border: Border.all(color: ColorConst.borderColor),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_selectedCountry.flag,
                                    style: const TextStyle(fontSize: 20)),
                                SizedBox(width: SizeConfig.defaultPadding * 0.4),
                                Text(_selectedCountry.dialCode,
                                    style: FontConst.MEDIUM_DEFAULT_16),
                                Icon(Icons.keyboard_arrow_down,
                                    color: ColorConst.textSecondaryColor),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: SizeConfig.defaultPadding * 0.8),
                        Expanded(
                          child: TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            style: FontConst.MEDIUM_DEFAULT_16,
                            decoration: const InputDecoration(
                              hintText: '082 123 4567',
                            ),
                            validator: (value) {
                              final errorKey = validatePhoneNumber(
                                value ?? '',
                                _selectedCountry.dialCode,
                              );
                              return errorKey == null
                                  ? null
                                  : Translate.of(context).translate(errorKey);
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: SizeConfig.defaultPadding * 2),
                    ElevatedButton(
                      onPressed: isLoading ? null : _onContinuePressed,
                      child: isLoading
                          ? SizedBox(
                              width: SizeConfig.defaultSize * 2,
                              height: SizeConfig.defaultSize * 2,
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : Text(Translate.of(context).translate('continue_with_phone'),),
                    ),
                    SizedBox(height: SizeConfig.defaultPadding * 2),
                    Text(
                      Translate.of(context).translate('terms_and_privacy_policy'),
                      textAlign: TextAlign.center,
                      style: FontConst.REGULAR_SECONDARY_12,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}