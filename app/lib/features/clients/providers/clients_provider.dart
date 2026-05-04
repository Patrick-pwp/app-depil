import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';

class Client {
  final String id;
  final String name;
  final String phone;
  final String? notes;

  const Client({required this.id, required this.name, required this.phone, this.notes});

  factory Client.fromMap(Map<String, dynamic> m) => Client(
        id: m['id'] as String,
        name: m['name'] as String,
        phone: m['phone'] as String,
        notes: m['notes'] as String?,
      );
}

class ClientsNotifier extends AsyncNotifier<List<Client>> {
  @override
  Future<List<Client>> build() async {
    final data = await ref.watch(supabaseProvider).from('clients').select().order('name');
    return (data as List).map((e) => Client.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> upsert({String? id, required String name, required String phone, String? notes}) async {
    final supabase = ref.read(supabaseProvider);
    final userId = supabase.auth.currentUser!.id;
    final payload = {'user_id': userId, 'name': name, 'phone': phone, 'notes': notes};
    if (id != null) {
      await supabase.from('clients').update(payload).eq('id', id);
    } else {
      await supabase.from('clients').insert(payload);
    }
    ref.invalidateSelf();
  }

  Future<void> delete(String id) async {
    await ref.read(supabaseProvider).from('clients').delete().eq('id', id);
    ref.invalidateSelf();
  }
}

final clientsNotifierProvider =
    AsyncNotifierProvider<ClientsNotifier, List<Client>>(ClientsNotifier.new);
