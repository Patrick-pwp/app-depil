import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client.dart';

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseProvider).auth.onAuthStateChange;
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(supabaseProvider).auth.currentUser;
});

class AuthNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> signUp({required String email, required String password, required String name}) async {
    final supabase = ref.read(supabaseProvider);
    await supabase.auth.signUp(
      email: email,
      password: password,
      data: {'name': name},
    );
  }

  Future<void> signIn({required String email, required String password}) async {
    final supabase = ref.read(supabaseProvider);
    await supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> resetPassword(String email) async {
    final supabase = ref.read(supabaseProvider);
    await supabase.auth.resetPasswordForEmail(email);
  }

  Future<void> signOut() async {
    await ref.read(supabaseProvider).auth.signOut();
  }
}

final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, void>(AuthNotifier.new);
