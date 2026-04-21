import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'data/services/notification_service.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/friends/screens/friend_comparison_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'firebase_options.dart';

// Listenable that fires whenever the Firebase auth state changes,
// allowing go_router to re-evaluate redirects reactively.
class _AuthStateListenable extends ChangeNotifier {
  _AuthStateListenable() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        NotificationService.checkAndNotifyOverdueMaintenance(user.uid);
        NotificationService.checkAndNotifyFriendRequests(user.uid);
      }
      notifyListeners();
    });
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await NotificationService.initialize();

  final authListenable = _AuthStateListenable();

  final router = GoRouter(
    initialLocation: '/login',
    refreshListenable: authListenable,
    redirect: (context, state) {
      final signedIn = FirebaseAuth.instance.currentUser != null;
      final onAuth = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';
      if (signedIn && onAuth) return '/home';
      if (!signedIn && !onAuth) return '/login';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/friends/compare/:friendUid',
        builder: (context, state) => FriendComparisonScreen(
          friendUid: state.pathParameters['friendUid']!,
        ),
      ),
    ],
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(ProviderScope(child: MomentumApp(router: router)));
}

class MomentumApp extends StatelessWidget {
  const MomentumApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Momentum',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
