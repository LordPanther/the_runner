import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:the_runner/data/models/notification_model.dart';
import 'package:the_runner/data/repositories/repository.dart';
import 'package:the_runner/presentation/common_blocs/notification/notification_event.dart';
import 'package:the_runner/presentation/common_blocs/notification/notification_state.dart';

class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final NotificationRepository _notificationRepository =
      AppRepository.notificationRepository;
  Stream<NotificationModel>? _newNotificationStream;

  List<NotificationModel> _cachedNotifications = [];

  NotificationBloc() : super(NotificationInitial()) {
    on<InitializeNotifications>((event, emit) async {
      await _onInitialize(event, emit);
    });
    on<LoadNotifications>((event, emit) async {
      await _onLoadNotifications(event, emit);
    });
    // restartable(): subscribing again (e.g. after signing in as
    // someone else) replaces the old listener instead of adding one.
    on<SubscribeToNewNotifications>(
      _onSubscribeToNewNotifications,
      transformer: restartable(),
    );
    on<LoadUnreadCount>((event, emit) async {
      await _onLoadUnreadCount(event, emit);
    });
    on<MarkAsRead>((event, emit) async {
      await _onMarkAsRead(event, emit);
    });
    on<MarkAllAsRead>((event, emit) async {
      await _onMarkAllAsRead(event, emit);
    });
    on<DeleteNotification>((event, emit) async {
      await _onDeleteNotification(event, emit);
    });
    on<ClearAllNotifications>((event, emit) async {
      await _onClearAll(event, emit);
    });
  }

  Future<void> _onInitialize(
    InitializeNotifications event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      await _notificationRepository.initialize();
      add(const LoadNotifications());
      add(SubscribeToNewNotifications());
    } catch (e) {
      emit(NotificationError(message: e.toString()));
    }
  }

  Future<void> _onLoadNotifications(
    LoadNotifications event,
    Emitter<NotificationState> emit,
  ) async {
    emit(NotificationLoading());
    try {
      final notifications = await _notificationRepository.getNotifications(
        limit: event.limit,
        lastDocumentId: event.lastDocumentId,
      );
      final unreadCount = await _notificationRepository.getUnreadCount();

      _cachedNotifications = notifications;

      emit(NotificationLoaded(
        notifications: notifications,
        unreadCount: unreadCount,
      ));
    } catch (e) {
      emit(NotificationError(message: e.toString()));
    }
  }

  Future<void> _onSubscribeToNewNotifications(
    SubscribeToNewNotifications event,
    Emitter<NotificationState> emit,
  ) async {
    _newNotificationStream = _notificationRepository.streamNewNotifications();
    await emit.forEach(
      _newNotificationStream!,
      onData: (notification) {
        _cachedNotifications = [notification, ..._cachedNotifications];
        return NewNotificationReceived(notification: notification);
      },
      onError: (e, _) => NotificationError(message: e.toString()),
    );
  }

  Future<void> _onLoadUnreadCount(
    LoadUnreadCount event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      final count = await _notificationRepository.getUnreadCount();
      emit(UnreadCountUpdated(count: count));
    } catch (e) {
      emit(NotificationError(message: e.toString()));
    }
  }

  Future<void> _onMarkAsRead(
    MarkAsRead event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      await _notificationRepository.markAsRead(event.notificationId);
      add(const LoadNotifications());
    } catch (e) {
      emit(NotificationError(message: e.toString()));
    }
  }

  Future<void> _onMarkAllAsRead(
    MarkAllAsRead event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      await _notificationRepository.markAllAsRead();
      add(const LoadNotifications());
    } catch (e) {
      emit(NotificationError(message: e.toString()));
    }
  }

  Future<void> _onDeleteNotification(
    DeleteNotification event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      await _notificationRepository.deleteNotification(event.notificationId);
      add(const LoadNotifications());
    } catch (e) {
      emit(NotificationError(message: e.toString()));
    }
  }

  Future<void> _onClearAll(
    ClearAllNotifications event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      await _notificationRepository.clearAllNotifications();
      emit(const NotificationLoaded(notifications: [], unreadCount: 0));
    } catch (e) {
      emit(NotificationError(message: e.toString()));
    }
  }

  @override
  Future<void> close() {
    _newNotificationStream = null;
    return super.close();
  }
}
