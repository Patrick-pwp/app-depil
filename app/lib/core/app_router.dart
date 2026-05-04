import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/signup_page.dart';
import '../features/auth/presentation/pages/forgot_password_page.dart';
import '../features/appointments/presentation/pages/appointments_page.dart';
import '../features/appointments/presentation/pages/create_appointment_page.dart';
import '../features/clients/presentation/pages/clients_page.dart';
import '../features/clients/presentation/pages/client_detail_page.dart';
import '../features/procedures/presentation/pages/procedures_page.dart';
import '../features/financial/presentation/pages/cashflow_page.dart';
import '../features/financial/presentation/pages/dre_page.dart';
import '../features/public_booking/presentation/pages/public_booking_page.dart';
import '../shared/widgets/main_scaffold.dart';

// ChangeNotifier que escuta o stream de auth do Supabase e notifica o GoRouter
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier() {
    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final _authNotifierProvider = Provider<_AuthChangeNotifier>((ref) {
  final notifier = _AuthChangeNotifier();
  ref.onDispose(notifier.dispose);
  return notifier;
});

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(_authNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: authNotifier,  // router reage a mudanças de auth
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;
      final loc = state.matchedLocation;

      final isPublicRoute = loc.startsWith('/book/') ||
          loc == '/login' ||
          loc == '/signup' ||
          loc == '/forgot-password';

      if (!isLoggedIn && !isPublicRoute) return '/login';
      if (isLoggedIn && (loc == '/login' || loc == '/signup')) return '/';
      return null;
    },
    routes: [
      // Autenticação
      GoRoute(path: '/login',           builder: (c, s) => const LoginPage()),
      GoRoute(path: '/signup',          builder: (c, s) => const SignupPage()),
      GoRoute(path: '/forgot-password', builder: (c, s) => const ForgotPasswordPage()),

      // Página pública (sem auth)
      GoRoute(
        path: '/book/:slug',
        builder: (c, s) => PublicBookingPage(slug: s.pathParameters['slug']!),
      ),

      // App autenticado com bottom navigation
      ShellRoute(
        builder: (context, state, child) => MainScaffold(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (c, s) => const AppointmentsPage(),
            routes: [
              GoRoute(
                path: 'appointment/new',
                builder: (c, s) => const CreateAppointmentPage(),
              ),
            ],
          ),
          GoRoute(
            path: '/clients',
            builder: (c, s) => const ClientsPage(),
            routes: [
              GoRoute(
                path: ':clientId',
                builder: (c, s) => ClientDetailPage(
                  clientId: s.pathParameters['clientId']!,
                ),
              ),
            ],
          ),
          GoRoute(path: '/procedures', builder: (c, s) => const ProceduresPage()),
          GoRoute(path: '/cashflow',   builder: (c, s) => const CashflowPage()),
          GoRoute(path: '/dre',        builder: (c, s) => const DrePage()),
        ],
      ),
    ],
  );
});
