import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'l10n/app_localizations.dart';
import 'locale_provider.dart';
import 'providers/user_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'auth_gate.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (kIsWeb) {
      final opts = DefaultFirebaseOptions.currentPlatform;
      if (opts.apiKey.isEmpty || opts.appId.isEmpty) {
        debugPrint('Skipping Firebase init in background handler: firebase options empty for web.');
      } else {
        await Firebase.initializeApp(options: opts);
      }
    } else {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
  } catch (e) {
    debugPrint('Background Firebase init error: $e');
  }
  debugPrint('Background message received: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Safe Firebase initialization for web/dev: if DefaultFirebaseOptions for web
  // are left with placeholder empty strings, skip initialization and log a
  // helpful message instead of crashing with an assertion (prevents white screen).
  try {
    if (kIsWeb) {
      final opts = DefaultFirebaseOptions.currentPlatform;
      if (opts.apiKey.isEmpty || opts.appId.isEmpty) {
        debugPrint('FirebaseOptions for web appear empty — skipping Firebase.initializeApp().\n'
            'Fill lib/firebase_options.dart or run `flutterfire configure` to generate real values.');
      } else {
        await Firebase.initializeApp(options: opts);
      }
    } else {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
  } catch (e) {
    debugPrint('Firebase initialize error: $e');
  }

  // Register background handler only if Firebase is configured (avoids web errors)
  final optsAfter = DefaultFirebaseOptions.currentPlatform;
  final firebaseConfiguredAfter = !(kIsWeb && (optsAfter.apiKey.isEmpty || optsAfter.appId.isEmpty));
  if (firebaseConfiguredAfter) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } else {
    debugPrint('Not registering FirebaseMessaging.onBackgroundMessage: Firebase not configured for web.');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => LocaleProvider()),
        ChangeNotifierProvider(create: (context) => UserProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

// Removed ThemeNotifier: single-theme design enforced for Zinc frontend.

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
  // Swipeat brand colors
  const Color brandDeep = Color(0xFF7CB342); // Avocado green (primary action)
  const Color brandReject = Color(0xFFFF6B6B); // Coral / Tomato red (reject)
  const Color bgLight = Color(0xFFFFFFFF); // clean white background
  const Color cardLight = Color(0xFFF4F4F8); // very light grey card surface

  // Dark theme variables removed — Zinc uses a single light theme.

    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        final localeProvider = Provider.of<LocaleProvider>(context);
        // Single-theme (light, warm) design for Zinc. No dark mode.
        final base = ThemeData(
          primaryColor: brandDeep,
        );

        final theme = base.copyWith(
          brightness: Brightness.light,
          scaffoldBackgroundColor: bgLight,
          colorScheme: ColorScheme.fromSeed(seedColor: brandDeep, brightness: Brightness.light).copyWith(
            primary: brandDeep,
            secondary: brandReject,
            surface: cardLight,
            onPrimary: Colors.white,
          ),
          appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, foregroundColor: Color(0xFF042028), elevation: 0),
          cardTheme: CardThemeData(color: cardLight, elevation: 8, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r))),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: brandDeep,
              foregroundColor: Colors.white,
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
            ),
          ),
          textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme).apply(bodyColor: const Color(0xFF042028)),
          visualDensity: VisualDensity.adaptivePlatformDensity,
          pageTransitionsTheme: const PageTransitionsTheme(builders: { TargetPlatform.iOS: CupertinoPageTransitionsBuilder(), TargetPlatform.android: FadeUpwardsPageTransitionsBuilder() }),
        );

        return MaterialApp(
          locale: localeProvider.locale,
          debugShowCheckedModeBanner: false,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          onGenerateTitle: (context) => "Swipeat",
          theme: theme,
          home: child,
        );
      },
      child: const FirstRunInitializer(child: AuthGate()),
    );
  }
}

/// Widget that runs once after app start to request notification permission
/// for first-time installs. It persists a 'notification_permission_requested'
/// flag and the resulting 'notifications_enabled' boolean in SharedPreferences.
class FirstRunInitializer extends StatefulWidget {
  final Widget child;
  const FirstRunInitializer({required this.child, super.key});

  @override
  State<FirstRunInitializer> createState() => _FirstRunInitializerState();
}

class _FirstRunInitializerState extends State<FirstRunInitializer> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRequestPermission());
  }

  Future<void> _maybeRequestPermission() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final alreadyAsked = prefs.getBool('notification_permission_requested') ?? false;
      if (alreadyAsked) return;

      // Mark as asked so we don't repeatedly prompt on subsequent launches.
      await prefs.setBool('notification_permission_requested', true);

      // Request permission from FCM. We don't block startup on this.
      // Guard FirebaseMessaging usage: if Firebase wasn't initialized (common in
      // web dev when firebase_options.dart has placeholders), skip calling
      // FirebaseMessaging.instance which throws a '[core/no-app]' exception.
      final opts = DefaultFirebaseOptions.currentPlatform;
      final firebaseConfigured = !(kIsWeb && (opts.apiKey.isEmpty || opts.appId.isEmpty));
      if (!firebaseConfigured) {
        debugPrint('Skipping FirebaseMessaging permission request: Firebase not configured for web.');
        await prefs.setBool('notifications_enabled', false);
        return;
      }

      try {
        final settings = await FirebaseMessaging.instance.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );
        final allowed = (settings.authorizationStatus == AuthorizationStatus.authorized) || (settings.authorizationStatus == AuthorizationStatus.provisional);
        await prefs.setBool('notifications_enabled', allowed);
      } catch (e) {
        // Some platforms may throw when calling requestPermission; fall back to not enabled.
        debugPrint('FirebaseMessaging requestPermission error: $e');
        await prefs.setBool('notifications_enabled', false);
      }
    } catch (e) {
      // ignore errors silently; permission prompt is non-critical
      debugPrint('FirstRunInitializer error: $e');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
