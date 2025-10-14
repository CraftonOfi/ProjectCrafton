import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/home/search_screen.dart';
import '../screens/resources/resource_detail_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/profile/edit_profile_screen.dart';
import '../screens/booking/my_bookings_screen.dart';
import '../screens/admin/manage_resources_screen.dart';
import '../screens/admin/admin_bookings_screen.dart';
import '../screens/admin/admin_reports_screen.dart';
import '../screens/booking/booking_screen.dart';
import '../screens/booking/booking_confirmation_screen.dart';
import '../screens/admin/admin_dashboard_screen.dart';
import '../screens/splash/splash_screen.dart';
import '../screens/misc/not_found_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/chat/admin_threads_screen.dart';

class AppRouterConfig {
  // ===== Path constants (centralizado para evitar typos) =====
  static const splashPath = '/splash';
  static const loginPath = '/login';
  static const registerPath = '/register';
  static const forgotPasswordPath = '/forgot-password';
  static const homePath = '/home';
  static const homeSearchPath = '/home/search';
  static const legacyResourcePath = '/resource/:id';
  // nested: /home/resource/:id
  static const myBookingsPath = '/my-bookings';
  static const bookingPath = '/booking/:resourceId';
  static const bookingConfirmationPath = '/booking-confirmation/:bookingId';
  static const profilePath = '/profile';
  static const editProfilePath = '/profile/edit';
  static const adminPath = '/admin';
  static const notificationsPath = '/notifications';
  static const chatPath = '/chat';
  static const adminChatPath = '/admin/chat';

  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  static final _shellNavigatorKey = GlobalKey<NavigatorState>();

  static GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: splashPath,
    redirect: _redirect,
    errorBuilder: (context, state) =>
        NotFoundScreen(attemptedPath: state.uri.toString()),
    routes: [
      // Splash Screen
      GoRoute(
        path: splashPath,
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // Auth Routes
      GoRoute(
        path: loginPath,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: registerPath,
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: forgotPasswordPath,
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // Main App with Bottom Navigation
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) {
          return MainNavigationScreen(child: child);
        },
        routes: [
          // HOME & nested
          GoRoute(
            path: homePath,
            name: 'home',
            builder: (context, state) => const HomeScreen(),
            routes: [
              // Nested resource detail inside shell to keep bottom nav
              GoRoute(
                path: 'resource/:id',
                name: 'home-resource-detail',
                builder: (context, state) {
                  final id = state.pathParameters['id']!;
                  return ResourceDetailScreen(resourceId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: homeSearchPath,
            name: 'home-search',
            builder: (context, state) => const SearchScreen(),
          ),
          GoRoute(
            path: myBookingsPath,
            name: 'my-bookings',
            builder: (context, state) => const MyBookingsScreen(),
          ),
          GoRoute(
            path: bookingPath,
            name: 'booking',
            builder: (context, state) {
              final resourceId = state.pathParameters['resourceId']!;
              return BookingScreen(resourceId: resourceId);
            },
          ),
          GoRoute(
            path: bookingConfirmationPath,
            name: 'booking-confirmation',
            builder: (context, state) {
              final bookingId = state.pathParameters['bookingId']!;
              return BookingConfirmationScreen(bookingId: bookingId);
            },
          ),
          GoRoute(
            path: profilePath,
            name: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: editProfilePath,
            name: 'profile-edit',
            builder: (context, state) => const EditProfileScreen(),
          ),
          GoRoute(
            path: notificationsPath,
            name: 'notifications',
            builder: (context, state) => const NotificationsScreen(),
          ),
          GoRoute(
            path: chatPath,
            name: 'chat',
            builder: (context, state) => const ChatScreen(),
          ),
          GoRoute(
            path: adminPath,
            name: 'admin',
            builder: (context, state) => const AdminDashboardScreen(),
          ),
          GoRoute(
            path: adminChatPath,
            name: 'admin-chat',
            builder: (context, state) => const AdminThreadsScreen(),
          ),
          GoRoute(
            path: '/admin/resources',
            name: 'admin-resources',
            builder: (context, state) => const ManageResourcesScreen(),
          ),
          GoRoute(
            path: '/admin/bookings',
            name: 'admin-bookings',
            builder: (context, state) => const AdminBookingsScreen(),
          ),
          GoRoute(
            path: '/admin/reports',
            name: 'admin-reports',
            builder: (context, state) => const AdminReportsScreen(),
          ),
        ],
      ),

      // Other routes
      // Legacy direct resource route -> redirect to nested under /home
      GoRoute(
        path: legacyResourcePath,
        redirect: (context, state) {
          final id = state.pathParameters['id'];
          return id != null ? '$homePath/resource/$id' : homePath;
        },
      ),
    ],
  );

  static String? _redirect(BuildContext context, GoRouterState state) {
    // Guardas simples: requiere login y admin para /admin
    final container = ProviderScope.containerOf(context, listen: false);
    final isAuth = container.read(isAuthenticatedProvider);
    final isAdmin = container.read(isAdminProvider);

    final loc = state.matchedLocation;
    if (!isAuth &&
        loc != loginPath &&
        loc != registerPath &&
        loc != forgotPasswordPath &&
        loc != splashPath) {
      return loginPath;
    }
    if (isAuth && loc == loginPath) {
      return homePath;
    }
    if (loc.startsWith('/admin') && !isAdmin) {
      return homePath;
    }
    return null;
  }
}

// Bottom Navigation Shell
class MainNavigationScreen extends ConsumerWidget {
  final Widget child;

  const MainNavigationScreen({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    final items = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(
        icon: Icon(Icons.home_outlined),
        activeIcon: Icon(Icons.home),
        label: 'Inicio',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.book_outlined),
        activeIcon: Icon(Icons.book),
        label: 'Mis Reservas',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.person_outline),
        activeIcon: Icon(Icons.person),
        label: 'Perfil',
      ),
      if (isAdmin)
        const BottomNavigationBarItem(
          icon: Icon(Icons.admin_panel_settings_outlined),
          activeIcon: Icon(Icons.admin_panel_settings),
          label: 'Admin',
        ),
    ];

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _calculateSelectedIndex(context, isAdmin: isAdmin),
        onTap: (index) => _onItemTapped(index, context, isAdmin: isAdmin),
        items: items,
      ),
    );
  }

  static int _calculateSelectedIndex(BuildContext context,
      {required bool isAdmin}) {
    final String location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/home')) {
      return 0; // includes /home/search & /home/resource/:id
    }
    if (location.startsWith('/my-bookings')) return 1;
    if (location.startsWith('/profile')) return 2;
    if (isAdmin && location.startsWith('/admin')) return 3;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context, {required bool isAdmin}) {
    switch (index) {
      case 0:
        GoRouter.of(context).go('/home');
        break;
      case 1:
        GoRouter.of(context).go('/my-bookings');
        break;
      case 2:
        GoRouter.of(context).go('/profile');
        break;
      case 3:
        if (isAdmin) GoRouter.of(context).go('/admin');
        break;
    }
  }
}
