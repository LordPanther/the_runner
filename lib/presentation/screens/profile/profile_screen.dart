// lib/presentation/screens/profile/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:the_runner/core/utils/file_picker_helper.dart';
import 'package:the_runner/core/widgets/loading_overlay.dart';
import 'package:the_runner/data/repositories/app_repository.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:the_runner/configs/router.dart';
import 'package:the_runner/configs/size_config.dart';
import 'package:the_runner/constants/color_constant.dart';
import 'package:the_runner/constants/font_constant.dart';
import 'package:the_runner/data/models/user_model.dart';
import 'package:the_runner/presentation/common_blocs/auth/auth.dart';
import 'package:the_runner/presentation/common_blocs/profile/profile.dart';
import 'package:the_runner/utils/translate.dart';
import 'package:the_runner/core/utils/friendly_error.dart';

// TODO(launch): make sure this mailbox exists before release.
const String kSupportEmail = 'support@therunner.co.za';
const String kAppVersion = '1.0.0';
 
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
 
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}
 
class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ProfileBloc>().add(LoadProfile());
  }
 
  Future<void> _contactSupport() async {
    final uri = Uri(scheme: 'mailto', path: kSupportEmail, query: 'subject=The Runner Support');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
 
  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('logout_q')),
        content: Text(context.tr('logout_note')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr('logout'), style: TextStyle(color: ColorConst.errorColor)),
          ),
        ],
      ),
    );
 
    if (confirmed == true && mounted) {
      context.read<AuthBloc>().add(SignOut());
    }
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorConst.backgroundColor,
      appBar: AppBar(title: Text(context.tr('profile'))),
      body: BlocBuilder<ProfileBloc, ProfileState>(
        builder: (context, state) {
          if (state is ProfileLoading || state is ProfileInitial) {
            return const Center(child: CircularProgressIndicator());
          }
 
          if (state is ProfileError) {
            return Center(
              child: Text(context.errorText(state.message), style: FontConst.REGULAR_SECONDARY_14),
            );
          }
 
          final user = state is ProfileLoaded
              ? state.user
              : (state as ProfileUpdateSuccess).user;
 
          return ListView(
            padding: EdgeInsets.all(SizeConfig.defaultPadding),
            children: [
              _buildHeader(user),
              SizedBox(height: SizeConfig.defaultPadding * 1.5),
              _buildRoleBadges(user),
              SizedBox(height: SizeConfig.defaultPadding * 1.5),
              _MenuItem(
                icon: Icons.assignment_outlined,
                label: context.tr('my_errands'),
                onTap: () => Navigator.of(context).pushNamed(AppRouter.myErrands),
              ),
              if (!user.isRunner)
                // TODO(runner-onboarding): ID check + bank details screen.
                // Until it exists, this explains what's coming.
                _MenuItem(
                  icon: Icons.directions_run_rounded,
                  label: context.tr('become_a_runner'),
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.tr('runner_onboarding_soon'))),
                  ),
                ),
              _MenuItem(
                icon: Icons.settings_outlined,
                label: context.tr('settings'),
                onTap: () => Navigator.of(context).pushNamed(AppRouter.settings),
              ),
              _MenuItem(
                icon: Icons.help_outline_rounded,
                label: context.tr('support_help'),
                onTap: _contactSupport,
              ),
              SizedBox(height: SizeConfig.defaultPadding),
              _MenuItem(
                icon: Icons.logout_rounded,
                label: context.tr('logout'),
                labelColor: ColorConst.errorColor,
                onTap: _confirmLogout,
              ),
              SizedBox(height: SizeConfig.defaultPadding * 2),
              Center(
                child: Text(
                  'The Runner v$kAppVersion',
                  style: FontConst.REGULAR_SECONDARY_12,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
 
  Widget _buildHeader(UserModel user) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => _pickAndUploadPhoto(user.uid),
          child: Stack(
            children: [
              CircleAvatar(
                radius: SizeConfig.defaultSize * 3.2,
                backgroundColor: ColorConst.primaryColor.withValues(alpha: 0.12),
                backgroundImage:
                    user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                child: user.photoUrl == null
                    ? Icon(Icons.person_rounded, size: 32, color: ColorConst.primaryColor)
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: ColorConst.primaryColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: ColorConst.backgroundColor, width: 2),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: SizeConfig.defaultPadding),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      user.displayName.isEmpty ? context.tr('runner_user') : user.displayName,
                      style: FontConst.BOLD_DEFAULT_20,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () => _showEditNameDialog(user.displayName),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.edit_outlined, size: 18, color: ColorConst.textSecondaryColor),
                    ),
                  ),
                ],
              ),
              SizedBox(height: SizeConfig.defaultPadding * 0.2),
              Text(user.phoneNumber, style: FontConst.REGULAR_SECONDARY_14),
            ],
          ),
        ),
      ],
    );
  }
 
  Future<void> _pickAndUploadPhoto(String uid) async {
    final image = await FilePickerHelper.pickImageFromGallery();
    if (image == null || !mounted) return;
 
    await LoadingOverlay.wrap(() async {
      try {
        final url = await AppRepository.authRepository.uploadAvatar(image);
        if (!mounted) return;
        context.read<ProfileBloc>().add(UpdateProfileDetails(photoUrl: url));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('photo_upload_failed'))),
        );
      }
    }, message: context.tr('uploading_photo'));
  }
 
  void _showEditNameDialog(String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('your_name')),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: context.tr('enter_your_name')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.tr('cancel')),
          ),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              context.read<ProfileBloc>().add(UpdateProfileDetails(displayName: name));
              Navigator.of(context).pop();
            },
            child: Text(context.tr('save')),
          ),
        ],
      ),
    );
  }
 
  Widget _buildRoleBadges(UserModel user) {
    final labels = user.roles.map((role) {
      switch (role) {
        case 'runner':
          return context.tr('role_runner');
        case 'admin':
          return context.tr('role_admin');
        default:
          return context.tr('role_user');
      }
    }).toSet();
 
    return Wrap(
      spacing: 8,
      children: labels
          .map((label) => Chip(
                label: Text(
                  label,
                  style: FontConst.MEDIUM_PRIMARY_16.copyWith(
                    fontSize: SizeConfig.defaultSize * 1.2,
                  ),
                ),
                backgroundColor: ColorConst.primaryColor.withValues(alpha: 0.1),
                side: BorderSide.none,
              ))
          .toList(),
    );
  }
}
 
class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? labelColor;
  final VoidCallback onTap;
 
  const _MenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.labelColor,
  });
 
  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: labelColor ?? ColorConst.textColor),
      title: Text(
        label,
        style: FontConst.MEDIUM_DEFAULT_16.copyWith(color: labelColor),
      ),
      trailing: labelColor == null
          ? Icon(Icons.chevron_right_rounded, color: ColorConst.textSecondaryColor)
          : null,
      onTap: onTap,
    );
  }
}
