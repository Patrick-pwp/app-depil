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

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final session = Supabase.instance.client.auth.currentSession;
      final isLoggedIn = session != null;
      final isPublicRoute = state.matchedLocation.startsWith('/book/') ||
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup' ||
          state.matchedLocation == '/forgot-password';

      if (!isLoggedIn && !isPublicRoute) return '/login';
      if (isLoggedIn && (state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup')) return '/';
      return null;
    },
    routes: [
      // Autenticação
      GoRoute(path: '/login',           builder: (c, s) => const LoginPage()),
      GoRoute(path: '/signup',          builder: (c, s) => const SignupPage()),
      GoRoute(path: '/forgot-password', builder: (c, s) => const ForgotPasswordPage()),

      // Página pública de agendamento (sem auth)
      GoRoute(
        path: '/book/:slug',
        builder: (c, s) => PublicBookingPage(slug: s.pathParameters['slug']!),
      ),

      // App principal com bottom navigation
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
