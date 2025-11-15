import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
// Notifications disabled for this project — we do not request permissions
// or register background handlers. Keep firebase_messaging out to avoid
// prompting users for notification permissions.
import 'firebase_options.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'l10n/app_localizations.dart';
import 'locale_provider.dart';
import 'providers/user_provider.dart';
// shared_preferences removed — notifications handling deleted
import 'package:flutter/foundation.dart' show kIsWeb;
import 'auth_gate.dart';

// Background message handling intentionally disabled. We do not run
// background push/message logic in this app.

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

  // Notifications and background message handlers are disabled by project
  // policy — we will not register FirebaseMessaging background handlers
  // or request notification permissions anywhere in the app.

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
      child: const AuthGate(),
    );
  }
}

