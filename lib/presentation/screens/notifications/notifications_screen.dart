// lib/presentation/screens/notifications/notifications_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:the_runner/configs/router.dart';
import 'package:the_runner/configs/size_config.dart';
import 'package:the_runner/constants/color_constant.dart';
import 'package:the_runner/constants/font_constant.dart';
import 'package:the_runner/data/models/notification_model.dart';
import 'package:the_runner/presentation/common_blocs/notification/notification.dart';
import 'package:the_runner/utils/translate.dart';
import 'package:the_runner/core/utils/friendly_error.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<NotificationBloc>().add(const LoadNotifications());
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return context.tr('just_now');
    if (diff.inMinutes < 60) return context.tr('minutes_ago', {'n': diff.inMinutes});
    if (diff.inHours < 24) return context.tr('hours_ago', {'n': diff.inHours});
    if (diff.inDays < 7) return context.tr('days_ago', {'n': diff.inDays});
    return '${time.day}/${time.month}/${time.year}';
  }

  // Notification types are created by the Cloud Functions in
  // functions/src/index.ts. Every errand notification carries
  // data.errand_id and opens that errand.
  IconData _iconForType(String type) {
    switch (type) {
      case 'new_bid':
      case 'bid_updated':
        return Icons.gavel_outlined;
      case 'bid_accepted':
        return Icons.check_circle_outline_rounded;
      case 'bid_declined':
        return Icons.do_not_disturb_on_outlined;
      case 'errand_funded':
        return Icons.lock_outline_rounded;
      case 'errand_started':
        return Icons.directions_run_rounded;
      case 'proof_submitted':
      case 'auto_release_reminder':
        return Icons.photo_camera_outlined;
      case 'payment_released':
      case 'errand_completed':
        return Icons.payments_outlined;
      case 'errand_disputed':
        return Icons.report_problem_outlined;
      case 'errand_cancelled':
        return Icons.cancel_outlined;
      case 'welcome':
        return Icons.celebration_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  void _onNotificationTap(NotificationModel notification) {
    context.read<NotificationBloc>().add(MarkAsRead(notification.id));

    final errandId = notification.data['errand_id'];
    if (errandId != null) {
      Navigator.of(context).pushNamed(AppRouter.errandDetail, arguments: errandId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorConst.backgroundColor,
      appBar: AppBar(
        title: Text(context.tr('notifications')),
        actions: [
          TextButton(
            onPressed: () => context.read<NotificationBloc>().add(MarkAllAsRead()),
            child: Text(context.tr('mark_all_read'), style: FontConst.MEDIUM_PRIMARY_16),
          ),
        ],
      ),
      body: BlocBuilder<NotificationBloc, NotificationState>(
        builder: (context, state) {
          if (state is NotificationLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is NotificationError) {
            return _EmptyState(
              icon: Icons.error_outline_rounded,
              message: context.errorText(state.message),
            );
          }

          final notifications =
              state is NotificationLoaded ? state.notifications : const <NotificationModel>[];

          if (notifications.isEmpty) {
            return _EmptyState(
              icon: Icons.notifications_none_rounded,
              message: context.tr('no_notifications'),
            );
          }

          return ListView.separated(
            padding: EdgeInsets.symmetric(vertical: SizeConfig.defaultPadding * 0.5),
            itemCount: notifications.length,
            separatorBuilder: (_, _) => Divider(
              height: 1,
              color: ColorConst.dividerColor,
            ),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return Dismissible(
                key: ValueKey(notification.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: ColorConst.errorColor,
                  alignment: Alignment.centerRight,
                  padding: EdgeInsets.symmetric(
                    horizontal: SizeConfig.defaultPadding,
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                ),
                onDismissed: (_) => context
                    .read<NotificationBloc>()
                    .add(DeleteNotification(notification.id)),
                child: ListTile(
                  onTap: () => _onNotificationTap(notification),
                  tileColor: notification.read
                      ? Colors.transparent
                      : ColorConst.primaryColor.withValues(alpha: 0.04),
                  leading: CircleAvatar(
                    backgroundColor: ColorConst.primaryColor.withValues(alpha: 0.12),
                    child: Icon(
                      _iconForType(notification.type),
                      color: ColorConst.primaryColor,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    notification.title,
                    style: notification.read
                        ? FontConst.MEDIUM_DEFAULT_16
                        : FontConst.BOLD_DEFAULT_16,
                  ),
                  subtitle: Text(
                    notification.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: FontConst.REGULAR_SECONDARY_14,
                  ),
                  trailing: Text(
                    _relativeTime(notification.createdAt),
                    style: FontConst.REGULAR_SECONDARY_12,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(SizeConfig.defaultPadding * 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: ColorConst.textSecondaryColor),
            SizedBox(height: SizeConfig.defaultPadding),
            Text(message, textAlign: TextAlign.center, style: FontConst.REGULAR_SECONDARY_14),
          ],
        ),
      ),
    );
  }
}