import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:the_runner/app_view.dart';
import 'package:the_runner/configs/size_config.dart';
import 'package:the_runner/presentation/common_blocs/common_bloc.dart';
import 'firebase_options.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';

void main() async {
  // Release builds (Play Store) print nothing to the device log.
  // Debug builds keep every log for testing.
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // App Check: Firebase only accepts requests from the real The Runner app
  // on a real phone (Play Integrity). Stops scripts from using our
  // Firebase project directly, e.g. to fire off SMS logins at our cost.
  // Debug builds use the debug provider: the first run prints a debug
  // token in the console, which you add once in Firebase Console ->
  // App Check -> Apps -> Manage debug tokens.
  await FirebaseAppCheck.instance.activate(
    providerAndroid: kReleaseMode
        ? const AndroidPlayIntegrityProvider()
        : const AndroidDebugProvider(),
  );

  // Crashlytics: crashes and uncaught errors from testers' phones show
  // up in Firebase Console -> Crashlytics. Off in debug so your own
  // testing doesn't fill it up.
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
    kReleaseMode,
  );
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };
  runApp(MyApp());
}

// This widget is the root of your application.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: CommonBloc.blocProviders,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return OrientationBuilder(
            builder: (context, orientation) {
              SizeConfig().init(constraints, orientation);
              return AppView();
            },
          );
        },
      ),
    );
  }
}
