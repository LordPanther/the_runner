import 'package:equatable/equatable.dart';

abstract class NotificationEvent extends Equatable {
  const NotificationEvent();

  @override
  List<Object?> get props => [];
}

class InitializeNotifications extends NotificationEvent {}

class LoadNotifications extends NotificationEvent {
  final int limit;
  final String? lastDocumentId;

  const LoadNotifications({this.limit = 20, this.lastDocumentId});

  @override
  List<Object?> get props => [limit, lastDocumentId];
}

class SubscribeToNewNotifications extends NotificationEvent {}

class LoadUnreadCount extends NotificationEvent {}

class MarkAsRead extends NotificationEvent {
  final String notificationId;

  const MarkAsRead(this.notificationId);

  @override
  List<Object?> get props => [notificationId];
}

class MarkAllAsRead extends NotificationEvent {}

class DeleteNotification extends NotificationEvent {
  final String notificationId;

  const DeleteNotification(this.notificationId);

  @override
  List<Object?> get props => [notificationId];
}

class ClearAllNotifications extends NotificationEvent {}
