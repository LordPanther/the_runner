import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:the_runner/configs/size_config.dart';
import 'package:the_runner/constants/color_constant.dart';
import 'package:the_runner/constants/font_constant.dart';
import 'package:the_runner/presentation/common_blocs/auth/auth.dart';
import 'package:the_runner/utils/translate.dart';
import 'package:the_runner/core/utils/friendly_error.dart';

class OTPVerificationScreen extends StatefulWidget {
  const OTPVerificationScreen({super.key});

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  static const _otpLength = 6;
  static const _resendSeconds = 30;

  final List<TextEditingController> _controllers = List.generate(
    _otpLength,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    _otpLength,
    (_) => FocusNode(),
  );

  Timer? _resendTimer;
  int _secondsRemaining = _resendSeconds;

  String? _verificationId;
  String? _phoneNumber;
  bool _argsLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argsLoaded) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        _verificationId = args['verificationId'] as String?;
        _phoneNumber = args['phoneNumber'] as String?;
      }
      _argsLoaded = true;
      _startResendTimer();
    }
  }

  void _startResendTimer() {
    _secondsRemaining = _resendSeconds;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() => _secondsRemaining = 0);
      } else {
        setState(() => _secondsRemaining -= 1);
      }
    });
  }

  String get _code => _controllers.map((c) => c.text).join();

  bool get _isComplete => _code.length == _otpLength;

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty && index < _otpLength - 1) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    setState(() {});
  }

  void _onVerifyPressed() {
    if (!_isComplete || _verificationId == null) return;
    FocusScope.of(context).unfocus();
    context.read<AuthBloc>().add(
      VerifyOtp(verificationId: _verificationId!, otpCode: _code),
    );
  }

  void _onResendPressed() {
    if (_secondsRemaining > 0 || _phoneNumber == null) return;
    context.read<AuthBloc>().add(SignInWithPhone(_phoneNumber!));
    _startResendTimer();
    for (final controller in _controllers) {
      controller.clear();
    }
    _focusNodes.first.requestFocus();
    setState(() {});
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorConst.backgroundColor,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: BlocConsumer<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthError) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: ColorConst.errorColor,
                      ),
                      SizedBox(width: SizeConfig.defaultPadding * 0.5),
                      Text(context.tr('incorrect_code')),
                    ],
                  ),
                  content: Text(
                    context.errorText(state.message),
                    style: FontConst.REGULAR_SECONDARY_14,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        // Clear and refocus so the person can
                        // immediately retype, rather than manually
                        // clearing each digit themselves.
                        for (final controller in _controllers) {
                          controller.clear();
                        }
                        _focusNodes.first.requestFocus();
                        setState(() {});
                      },
                      child: Text(context.tr('try_again')),
                    ),
                  ],
                ),
              );
              // Authenticated success is handled globally by AppView's
              // BlocListener, which redirects to home - nothing to do here.
            }
          },
          builder: (context, state) {
            final isLoading = state is AuthLoading;

            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: SizeConfig.defaultPadding * 1.5,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: SizeConfig.defaultPadding),
                  Text(context.tr('verify_your_number'), style: FontConst.BOLD_DEFAULT_24),
                  SizedBox(height: SizeConfig.defaultPadding * 0.6),
                  Text(
                    _phoneNumber == null
                        ? context.tr('otp_verification_1')
                        : context.tr('otp_sent_to', {'phone': _phoneNumber}),
                    style: FontConst.REGULAR_SECONDARY_14,
                  ),
                  SizedBox(height: SizeConfig.defaultPadding * 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(_otpLength, (index) {
                      return SizedBox(
                        width: SizeConfig.defaultSize * 4.8,
                        height: SizeConfig.defaultSize * 4.8,
                        child: TextField(
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLength: 1,
                          style: FontConst.BOLD_DEFAULT_20,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: ColorConst.surfaceColor,
                            contentPadding: EdgeInsets.zero,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(
                                color: ColorConst.borderColor,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide(
                                color: ColorConst.borderColor,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: const BorderSide(
                                color: ColorConst.primaryColor,
                                width: 1.5,
                              ),
                            ),
                          ),
                          onChanged: (value) => _onDigitChanged(index, value),
                        ),
                      );
                    }),
                  ),
                  SizedBox(height: SizeConfig.defaultPadding * 3),
                  ElevatedButton(
                    onPressed: (_isComplete && !isLoading)
                        ? _onVerifyPressed
                        : null,
                    child: isLoading
                        ? SizedBox(
                            width: SizeConfig.defaultSize * 2,
                            height: SizeConfig.defaultSize * 2,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : Text(context.tr('verify')),
                  ),
                  SizedBox(height: SizeConfig.defaultPadding * 2),
                  Center(
                    child: _secondsRemaining > 0
                        ? Text(
                            context.tr('resend_in_seconds', {'seconds': _secondsRemaining}),
                            style: FontConst.REGULAR_SECONDARY_14,
                          )
                        : TextButton(
                            onPressed: _onResendPressed,
                            child: Text(
                              context.tr('resend_code'),
                              style: FontConst.MEDIUM_PRIMARY_16,
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
