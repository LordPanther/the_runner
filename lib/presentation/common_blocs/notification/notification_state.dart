import 'package:equatable/equatable.dart';
import 'package:the_runner/data/models/notification_model.dart';

abstract class NotificationState extends Equatable {
  const NotificationState();

  @override
  List<Object?> get props => [];
}

class NotificationInitial extends NotificationState {}

class NotificationLoading extends NotificationState {}

class NotificationLoaded extends NotificationState {
  final List<NotificationModel> notifications;
  final int unreadCount;

  const NotificationLoaded({
    required this.notifications,
    required this.unreadCount,
  });

  @override
  List<Object?> get props => [notifications, unreadCount];
}

class UnreadCountUpdated extends NotificationState {
  final int count;

  const UnreadCountUpdated({required this.count});

  @override
  List<Object?> get props => [count];
}

class NewNotificationReceived extends NotificationState {
  final NotificationModel notification;

  const NewNotificationReceived({required this.notification});

  @override
  List<Object?> get props => [notification];
}

class NotificationError extends NotificationState {
  final String message;

  const NotificationError({required this.message});

  @override
  List<Object?> get props => [message];
}
