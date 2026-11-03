import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:the_runner/presentation/common_blocs/errand/errand.dart';
import 'package:the_runner/presentation/screens/auth/login_screen.dart';
import 'package:the_runner/presentation/screens/auth/otp_verification_screen.dart';
import 'package:the_runner/presentation/screens/errands/errand_detail_screen.dart';
import 'package:the_runner/presentation/screens/errands/my_errands_screen.dart';
import 'package:the_runner/presentation/screens/errands/new_errand_screen.dart';
import 'package:the_runner/presentation/screens/home/bottom_navigation.dart';
import 'package:the_runner/presentation/screens/notifications/notifications_screen.dart';
import 'package:the_runner/presentation/screens/onboarding/onboarding_screen.dart';
import 'package:the_runner/presentation/screens/profile/profile_screen.dart';
import 'package:the_runner/presentation/screens/settings/blocked_people_screen.dart';
import 'package:the_runner/presentation/screens/settings/settings_screen.dart';
import 'package:the_runner/presentation/screens/splash/splash_screen.dart';

class AppRouter {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String otpVerification = '/otp_verification';
  static const String home = '/home';
  static const String newErrand = '/new_errand';
  static const String errandDetail = '/errand_detail';
  static const String myErrands = '/my_errands';
  static const String userProfile = '/user_profile';
  static const String notifications = '/notifications';
  static const String settings = '/settings';
  static const String blockedPeople = '/blocked_people';

  // NOTE: every route below passes `settings: settings` through to
  // MaterialPageRoute. Without this, RouteSettings.arguments (the data
  // passed via Navigator.pushNamed(route, arguments: ...)) would be lost -
  // ModalRoute.of(context)?.settings.arguments would read null in the
  // pushed screen even though the caller passed a real value. Several
  // screens (OTP verification, errand detail) depend on this to receive
  // their arguments correctly.
  //
  // NOTE: ErrandBloc is wrapped locally per-route via BlocProvider rather
  // than shared globally. The feed, My Errands and an errand's detail
  // page all use it for different things - sharing one instance meant
  // one screen's query could silently overwrite what another screen,
  // still mounted in the background, was displaying.
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );
 
      case onboarding:
        return MaterialPageRoute(
          builder: (_) => const OnboardingScreen(),
          settings: settings,
        );
 
      case login:
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
          settings: settings,
        );
 
      case otpVerification:
        return MaterialPageRoute(
          builder: (_) => const OTPVerificationScreen(),
          settings: settings,
        );
 
      case home:
        return MaterialPageRoute(
          builder: (_) => const BottomNavigation(),
          settings: settings,
        );
 
      case newErrand:
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (_) => ErrandBloc(),
            child: const NewErrandScreen(),
          ),
          settings: settings,
        );

      case errandDetail:
        return MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (_) => ErrandBloc(),
            child: const ErrandDetailScreen(),
          ),
          settings: settings,
        );

      case myErrands:
        return MaterialPageRoute(
          builder: (_) => const MyErrandsScreen(),
          settings: settings,
        );

      case userProfile:
        return MaterialPageRoute(
          builder: (_) => const ProfileScreen(),
          settings: settings,
        );
 
      case notifications:
        return MaterialPageRoute(
          builder: (_) => const NotificationsScreen(),
          settings: settings,
        );
 
      case blockedPeople:
        return MaterialPageRoute(
          builder: (_) => const BlockedPeopleScreen(),
          settings: settings,
        );

      case AppRouter.settings:
        return MaterialPageRoute(
          builder: (_) => const SettingsScreen(),
          settings: settings,
        );
 
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text(
                'ERROR: Route ${settings.name} not found',
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Courier',
                ),
              ),
            ),
          ),
          settings: settings,
        );
    }
  }
 
  static final AppRouter _instance = AppRouter._internal();
 
  factory AppRouter() {
    return _instance;
  }
 
  AppRouter._internal();
}