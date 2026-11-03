// lib/presentation/screens/settings/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:the_runner/configs/language.dart';
import 'package:the_runner/configs/size_config.dart';
import 'package:the_runner/constants/color_constant.dart';
import 'package:the_runner/constants/font_constant.dart';
import 'package:the_runner/core/widgets/loading_overlay.dart';
import 'package:the_runner/data/repositories/app_repository.dart';
import 'package:the_runner/presentation/common_blocs/auth/auth.dart';
import 'package:the_runner/presentation/common_blocs/settings/app_settings_bloc.dart';
import 'package:the_runner/presentation/common_blocs/settings/app_settings_event.dart';
import 'package:the_runner/presentation/common_blocs/settings/app_settings_state.dart';
import 'package:the_runner/presentation/screens/profile/profile_screen.dart'
    show kAppVersion;
import 'package:the_runner/configs/router.dart';
import 'package:the_runner/utils/translate.dart';
import 'package:the_runner/data/services/language_sync.dart';
import 'package:the_runner/core/utils/friendly_error.dart';

const Map<String, String> _kLanguageLabels = {'en': 'English', 'zu': 'isiZulu'};

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmAndDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final authBloc = context.read<AuthBloc>();
    final t = Translate.of(context);
    try {
      await LoadingOverlay.wrap(
        () => AppRepository.authRepository.deleteAccount(),
        message: t.translate('deleting_account'),
      );
      // Sends the app back to the login screen, same as Logout.
      authBloc.add(SignOut());
      messenger.showSnackBar(
        SnackBar(content: Text(t.translate('account_deleted'))),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(t.translate('account_delete_failed')),
          backgroundColor: ColorConst.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorConst.backgroundColor,
      appBar: AppBar(title: Text(context.tr('settings'))),
      body: BlocBuilder<AppSettingsBloc, AppSettingsState>(
        builder: (context, state) {
          return ListView(
            padding: EdgeInsets.all(SizeConfig.defaultPadding),
            children: [
              Text(context.tr('language'), style: FontConst.BOLD_DEFAULT_18),
              SizedBox(height: SizeConfig.defaultPadding * 0.6),
              ...AppLanguage.supportLanguage.map((locale) {
                return RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  value: locale.languageCode,
                  groupValue: state.locale.languageCode,
                  activeColor: ColorConst.primaryColor,
                  title: Text(
                    _kLanguageLabels[locale.languageCode] ??
                        locale.languageCode,
                    style: FontConst.REGULAR_DEFAULT_16,
                  ),
                  onChanged: (code) {
                    if (code != null) {
                      context.read<AppSettingsBloc>().add(
                        ChangeLanguage(Locale(code)),
                      );
                    }
                  },
                );
              }),
              SizedBox(height: SizeConfig.defaultPadding * 2),
              Divider(color: ColorConst.dividerColor),
              SizedBox(height: SizeConfig.defaultPadding),
              Text(
                context.tr('search_radius'),
                style: FontConst.BOLD_DEFAULT_18,
              ),
              SizedBox(height: SizeConfig.defaultPadding * 0.3),
              Text(
                context.tr('search_radius_note'),
                style: FontConst.REGULAR_SECONDARY_14,
              ),
              SizedBox(height: SizeConfig.defaultPadding * 0.6),
              Text(
                '${state.searchRadiusKm.toStringAsFixed(0)}km',
                style: FontConst.BOLD_PRIMARY_16,
              ),
              Slider(
                value: state.searchRadiusKm,
                min: 5,
                max: 50,
                divisions: 9,
                activeColor: ColorConst.primaryColor,
                label: '${state.searchRadiusKm.toStringAsFixed(0)}km',
                onChanged: (value) {
                  context.read<AppSettingsBloc>().add(
                    ChangeSearchRadius(value),
                  );
                },
              ),
              SizedBox(height: SizeConfig.defaultPadding * 1.4),
              Divider(color: ColorConst.dividerColor),
              SizedBox(height: SizeConfig.defaultPadding),
              const _ErrandAlertsSection(),
              Text(context.tr('about'), style: FontConst.BOLD_DEFAULT_18),
              SizedBox(height: SizeConfig.defaultPadding * 0.6),
              Text(
                'The Runner v$kAppVersion',
                style: FontConst.REGULAR_SECONDARY_14,
              ),
              SizedBox(height: SizeConfig.defaultPadding * 1.4),
              Divider(color: ColorConst.dividerColor),
              SizedBox(height: SizeConfig.defaultPadding),
              Text(context.tr('account'), style: FontConst.BOLD_DEFAULT_18),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.block_rounded, color: ColorConst.textColor),
                title: Text(
                  Translate.of(context).translate('blocked_people_title'),
                  style: FontConst.MEDIUM_DEFAULT_16,
                ),
                subtitle: Text(
                  Translate.of(context).translate('blocked_people_subtitle'),
                  style: FontConst.REGULAR_SECONDARY_12,
                ),
                trailing: Icon(
                  Icons.chevron_right_rounded,
                  color: ColorConst.textSecondaryColor,
                ),
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRouter.blockedPeople),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.delete_forever_outlined,
                  color: ColorConst.errorColor,
                ),
                title: Text(
                  context.tr('delete_account'),
                  style: FontConst.MEDIUM_DEFAULT_16.copyWith(
                    color: ColorConst.errorColor,
                  ),
                ),
                subtitle: Text(
                  context.tr('delete_account_subtitle'),
                  style: FontConst.REGULAR_SECONDARY_12,
                ),
                onTap: () => _confirmAndDeleteAccount(context),
              ),
              SizedBox(height: SizeConfig.defaultPadding * 2),
            ],
          );
        },
      ),
    );
  }
}

/// Explains exactly what deletion does, then asks the user to type
/// DELETE. A plain Yes/No is too easy to tap by accident for something
/// that can't be undone.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _controller = TextEditingController();
  bool _ready = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('delete_account_q')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('delete_account_intro'),
              style: FontConst.REGULAR_DEFAULT_16,
            ),
            const SizedBox(height: 8),
            for (final line in [
              context.tr('delete_item_profile'),
              context.tr('delete_item_errands'),
              context.tr('delete_item_bids'),
              context.tr('delete_item_notifications'),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '\u2022 $line',
                  style: FontConst.REGULAR_SECONDARY_14,
                ),
              ),
            const SizedBox(height: 8),
            Text(
              context.tr('delete_account_note'),
              style: FontConst.REGULAR_SECONDARY_14,
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('type_delete_to_confirm'),
              style: FontConst.MEDIUM_DEFAULT_16,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(hintText: 'DELETE'),
              onChanged: (value) => setState(
                () => _ready = value.trim().toUpperCase() == 'DELETE',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.tr('cancel')),
        ),
        TextButton(
          onPressed: _ready ? () => Navigator.of(context).pop(true) : null,
          child: Text(
            context.tr('delete_forever'),
            style: TextStyle(
              color: _ready
                  ? ColorConst.errorColor
                  : ColorConst.textSecondaryColor,
            ),
          ),
        ),
      ],
    );
  }
}

/// Runners only: turn new-errand alerts on or off. Saved in
/// users/{uid}/private/settings and read by the
/// notifyRunnersOnErrandCreated Cloud Function.
class _ErrandAlertsSection extends StatefulWidget {
  const _ErrandAlertsSection();

  @override
  State<_ErrandAlertsSection> createState() => _ErrandAlertsSectionState();
}

class _ErrandAlertsSectionState extends State<_ErrandAlertsSection> {
  bool? _enabled;

  @override
  void initState() {
    super.initState();
    LanguageSync.errandAlertsEnabled().then((value) {
      if (mounted) setState(() => _enabled = value);
    });
  }

  Future<void> _toggle(bool value) async {
    final previous = _enabled;
    setState(() => _enabled = value);
    try {
      await LanguageSync.setErrandAlerts(value);
    } catch (e) {
      if (!mounted) return;
      setState(() => _enabled = previous);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(context.errorText(e)),
        backgroundColor: ColorConst.errorColor,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthBloc>().state;
    final isRunner = auth is Authenticated && auth.user.isRunner;
    if (!isRunner) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _enabled ?? true,
          activeThumbColor: ColorConst.primaryColor,
          title: Text(context.tr('errand_alerts_title'), style: FontConst.MEDIUM_DEFAULT_16),
          subtitle: Text(context.tr('errand_alerts_subtitle'), style: FontConst.REGULAR_SECONDARY_12),
          onChanged: _enabled == null ? null : _toggle,
        ),
        SizedBox(height: SizeConfig.defaultPadding * 0.6),
        Divider(color: ColorConst.dividerColor),
        SizedBox(height: SizeConfig.defaultPadding),
      ],
    );
  }
}
