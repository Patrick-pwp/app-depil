import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase_client.dart';

class Appointment {
  final String id;
  final String clientId;
  final String clientName;
  final String procedureId;
  final String procedureName;
  final DateTime scheduledAt;
  final DateTime endsAt;
  final String status;
  final bool isPaid;
  final String bookedVia;

  const Appointment({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.procedureId,
    required this.procedureName,
    required this.scheduledAt,
    required this.endsAt,
    required this.status,
    required this.isPaid,
    required this.bookedVia,
  });

  factory Appointment.fromMap(Map<String, dynamic> m) => Appointment(
        id: m['id'] as String,
        clientId: m['client_id'] as String,
        clientName: (m['clients'] as Map?)?['name'] as String? ?? '',
        procedureId: m['procedure_id'] as String,
        procedureName: (m['procedures'] as Map?)?['name'] as String? ?? '',
        scheduledAt: DateTime.parse(m['scheduled_at'] as String),
        endsAt: DateTime.parse(m['ends_at'] as String),
        status: m['status'] as String,
        isPaid: m['is_paid'] as bool,
        bookedVia: m['booked_via'] as String,
      );
}

// Agendamentos do mês selecionado
final appointmentsMonthProvider =
    FutureProvider.family<List<Appointment>, DateTime>((ref, month) async {
  final supabase = ref.watch(supabaseProvider);
  final start = DateTime(month.year, month.month, 1);
  final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
  final data = await supabase
      .from('appointments')
      .select('*, clients(name), procedures(name)')
      .gte('scheduled_at', start.toIso8601String())
      .lte('scheduled_at', end.toIso8601String())
      .order('scheduled_at');
  return (data as List).map((e) => Appointment.fromMap(e as Map<String, dynamic>)).toList();
});

// Agendamentos pendentes de confirmação
final pendingAppointmentsProvider = FutureProvider<List<Appointment>>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final data = await supabase
      .from('appointments')
      .select('*, clients(name), procedures(name)')
      .eq('status', 'pending')
      .order('scheduled_at');
  return (data as List).map((e) => Appointment.fromMap(e as Map<String, dynamic>)).toList();
});

class AppointmentsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> updateStatus(String appointmentId, String newStatus) async {
    await ref.read(supabaseProvider).from('appointments').update({'status': newStatus}).eq('id', appointmentId);
    ref.invalidate(appointmentsMonthProvider);
    ref.invalidate(pendingAppointmentsProvider);
  }

  Future<void> togglePaid(String appointmentId, bool isPaid) async {
    await ref.read(supabaseProvider).from('appointments').update({'is_paid': isPaid}).eq('id', appointmentId);
    ref.invalidate(appointmentsMonthProvider);
  }
}

final appointmentsNotifierProvider =
    AsyncNotifierProvider<AppointmentsNotifier, void>(AppointmentsNotifier.new);
