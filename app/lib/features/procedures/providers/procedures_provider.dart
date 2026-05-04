import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client.dart';

class Procedure {
  final String id;
  final String name;
  final double revenue;
  final double cost;
  final double profit;
  final int durationMinutes;
  final bool isActive;

  const Procedure({
    required this.id,
    required this.name,
    required this.revenue,
    required this.cost,
    required this.profit,
    required this.durationMinutes,
    required this.isActive,
  });

  factory Procedure.fromMap(Map<String, dynamic> m) => Procedure(
        id: m['id'] as String,
        name: m['name'] as String,
        revenue: (m['revenue'] as num).toDouble(),
        cost: (m['cost'] as num).toDouble(),
        profit: (m['profit'] as num).toDouble(),
        durationMinutes: m['duration_minutes'] as int,
        isActive: m['is_active'] as bool,
      );
}

final proceduresProvider = FutureProvider<List<Procedure>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final data = await supabase
      .from('procedures')
      .select()
      .eq('is_active', true)
      .order('name');
  return (data as List).map((e) => Procedure.fromMap(e as Map<String, dynamic>)).toList();
});

class ProceduresNotifier extends AsyncNotifier<List<Procedure>> {
  @override
  Future<List<Procedure>> build() async {
    final supabase = ref.watch(supabaseProvider);
    final data = await supabase.from('procedures').select().order('name');
    return (data as List).map((e) => Procedure.fromMap(e as Map<String, dynamic>)).toList();
  }

  Future<void> upsert({
    String? id,
    required String name,
    required double revenue,
    required double cost,
    required int durationMinutes,
  }) async {
    final supabase = ref.read(supabaseProvider);
    final userId = supabase.auth.currentUser!.id;
    final payload = {
      'user_id': userId,
      'name': name,
      'revenue': revenue,
      'cost': cost,
      'duration_minutes': durationMinutes,
      'is_active': true,
    };
    if (id != null) {
      await supabase.from('procedures').update(payload).eq('id', id);
    } else {
      await supabase.from('procedures').insert(payload);
    }
    ref.invalidateSelf();
  }

  Future<void> toggleActive(String id, bool isActive) async {
    await ref.read(supabaseProvider).from('procedures').update({'is_active': isActive}).eq('id', id);
    ref.invalidateSelf();
  }
}

final proceduresNotifierProvider =
    AsyncNotifierProvider<ProceduresNotifier, List<Procedure>>(ProceduresNotifier.new);
