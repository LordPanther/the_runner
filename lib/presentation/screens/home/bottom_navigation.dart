// lib/presentation/screens/home/bottom_navigation.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:the_runner/constants/color_constant.dart';
import 'package:the_runner/constants/font_constant.dart';
import 'package:the_runner/configs/size_config.dart';
import 'package:the_runner/presentation/common_blocs/errand/errand.dart';
import 'package:the_runner/presentation/common_blocs/notification/notification.dart';
import 'package:the_runner/presentation/screens/errands/my_errands_screen.dart';
import 'package:the_runner/presentation/screens/home/home_tab.dart';
import 'package:the_runner/presentation/screens/notifications/notifications_screen.dart';
import 'package:the_runner/presentation/screens/profile/profile_screen.dart';
import 'package:the_runner/utils/translate.dart';

class BottomNavigation extends StatefulWidget {
  const BottomNavigation({super.key});

  @override
  State<BottomNavigation> createState() => _BottomNavigationState();
}

class _BottomNavigationState extends State<BottomNavigation> {
  int _currentIndex = 0;

  // NOTE: the feed gets its OWN ErrandBloc here rather than sharing a
  // global one. IndexedStack keeps every tab mounted at once, so a
  // shared bloc would let My Errands overwrite what the feed shows.
  // Built once in initState (not const) so each BlocProvider's create()
  // runs exactly once per app session, not on every rebuild.
  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    context.read<NotificationBloc>().add(LoadUnreadCount());

    _tabs = [
      BlocProvider(
        create: (_) => ErrandBloc(),
        child: const HomeTab(),
      ),
      const MyErrandsScreen(),
      const NotificationsScreen(),
      const ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _tabs),
      bottomNavigationBar: _buildNavBar(),
    );
  }

  Widget _buildNavBar() {
    return BlocBuilder<NotificationBloc, NotificationState>(
      builder: (context, state) {
        final unreadCount = state is UnreadCountUpdated
            ? state.count
            : (state is NotificationLoaded ? state.unreadCount : 0);

        return BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: ColorConst.surfaceColor,
          selectedItemColor: ColorConst.primaryColor,
          unselectedItemColor: ColorConst.textSecondaryColor,
          selectedLabelStyle: FontConst.MEDIUM_DEFAULT_16.copyWith(
            fontSize: SizeConfig.defaultSize * 1.1,
          ),
          unselectedLabelStyle: FontConst.REGULAR_SECONDARY_12.copyWith(
            fontSize: SizeConfig.defaultSize * 1.1,
          ),
          items: [
            BottomNavigationBarItem(
              icon: Icon(Icons.directions_run_outlined),
              activeIcon: Icon(Icons.directions_run_rounded),
              label: context.tr('nav_errands'),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment_outlined),
              activeIcon: Icon(Icons.assignment_rounded),
              label: context.tr('nav_my_errands'),
            ),
            BottomNavigationBarItem(
              icon: _NotificationIcon(count: unreadCount, filled: false),
              activeIcon: _NotificationIcon(count: unreadCount, filled: true),
              label: context.tr('notifications'),
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: context.tr('profile'),
            ),
          ],
        );
      },
    );
  }
}

class _NotificationIcon extends StatelessWidget {
  final int count;
  final bool filled;

  const _NotificationIcon({required this.count, required this.filled});

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      filled ? Icons.notifications_rounded : Icons.notifications_outlined,
    );

    if (count <= 0) return icon;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        Positioned(
          right: -6,
          top: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: ColorConst.errorColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              count > 9 ? '9+' : '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}