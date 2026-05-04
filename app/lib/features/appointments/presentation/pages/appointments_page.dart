import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../providers/appointments_provider.dart';

final _selectedDayProvider = StateProvider<DateTime>((ref) => DateTime.now());
final _focusedDayProvider = StateProvider<DateTime>((ref) => DateTime.now());

class AppointmentsPage extends ConsumerWidget {
  const AppointmentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDay = ref.watch(_selectedDayProvider);
    final focusedDay = ref.watch(_focusedDayProvider);
    final monthAsync = ref.watch(appointmentsMonthProvider(focusedDay));
    final pendingAsync = ref.watch(pendingAppointmentsProvider);

    final allAppointments = monthAsync.valueOrNull ?? [];
    final dayAppointments = allAppointments
        .where((a) => isSameDay(a.scheduledAt, selectedDay))
        .toList();
    final pendingCount = pendingAsync.valueOrNull?.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agenda'),
        actions: [
          if (pendingCount > 0)
            Stack(
              alignment: Alignment.topRight,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () => _showPendingSheet(context, ref),
                ),
                Positioned(
                  right: 8, top: 8,
                  child: CircleAvatar(radius: 8, backgroundColor: Colors.red, child: Text('$pendingCount', style: const TextStyle(fontSize: 10, color: Colors.white))),
                ),
              ],
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/appointment/new'),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          TableCalendar<Appointment>(
            firstDay: DateTime(2020),
            lastDay: DateTime(2030),
            focusedDay: focusedDay,
            selectedDayPredicate: (d) => isSameDay(d, selectedDay),
            eventLoader: (day) => allAppointments.where((a) => isSameDay(a.scheduledAt, day)).toList(),
            calendarFormat: CalendarFormat.week,
            startingDayOfWeek: StartingDayOfWeek.monday,
            onDaySelected: (selected, focused) {
              ref.read(_selectedDayProvider.notifier).state = selected;
              ref.read(_focusedDayProvider.notifier).state = focused;
            },
            onPageChanged: (focused) => ref.read(_focusedDayProvider.notifier).state = focused,
            calendarStyle: CalendarStyle(
              markerDecoration: const BoxDecoration(color: Color(0xFFD4447A), shape: BoxShape.circle),
              selectedDecoration: const BoxDecoration(color: Color(0xFFD4447A), shape: BoxShape.circle),
              todayDecoration: BoxDecoration(color: const Color(0xFFD4447A).withOpacity(0.3), shape: BoxShape.circle),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: dayAppointments.isEmpty
                ? const Center(child: Text('Nenhum atendimento neste dia'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: dayAppointments.length,
                    itemBuilder: (_, i) => _AppointmentTile(appointment: dayAppointments[i]),
                  ),
          ),
        ],
      ),
    );
  }

  void _showPendingSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PendingAppointmentsSheet(ref: ref),
    );
  }
}

class _AppointmentTile extends ConsumerWidget {
  const _AppointmentTile({required this.appointment});
  final Appointment appointment;

  static const _statusColors = {
    'scheduled': Color(0xFF1976D2),
    'completed': Color(0xFF388E3C),
    'cancelled': Color(0xFF757575),
    'no_show': Color(0xFFF57C00),
    'pending': Color(0xFFE65100),
  };

  static const _statusLabels = {
    'scheduled': 'Agendado',
    'completed': 'Realizado',
    'cancelled': 'Cancelado',
    'no_show': 'Faltou',
    'pending': 'Pendente',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _statusColors[appointment.status] ?? Colors.grey;
    final label = _statusLabels[appointment.status] ?? appointment.status;
    final timeFmt = DateFormat('HH:mm');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(timeFmt.format(appointment.scheduledAt), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(timeFmt.format(appointment.endsAt), style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        title: Text(appointment.clientName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(appointment.procedureName),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color)),
              child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        onTap: () => appointment.status == 'scheduled' ? _showStatusSheet(context, ref) : null,
      ),
    );
  }

  void _showStatusSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${appointment.clientName} — ${appointment.procedureName}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await ref.read(appointmentsNotifierProvider.notifier).updateStatus(appointment.id, 'completed');
              },
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Marcar como Realizado'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await ref.read(appointmentsNotifierProvider.notifier).updateStatus(appointment.id, 'no_show');
              },
              icon: const Icon(Icons.person_off_outlined),
              label: const Text('Faltou'),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await ref.read(appointmentsNotifierProvider.notifier).updateStatus(appointment.id, 'cancelled');
              },
              icon: const Icon(Icons.cancel_outlined, color: Colors.red),
              label: const Text('Cancelar', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingAppointmentsSheet extends ConsumerWidget {
  const _PendingAppointmentsSheet({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef _) {
    final pendingAsync = ref.watch(pendingAppointmentsProvider);
    final dateFmt = DateFormat("dd/MM 'às' HH:mm", 'pt_BR');

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      expand: false,
      builder: (_, ctrl) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Solicitações Pendentes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            Expanded(
              child: pendingAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Erro: $e')),
                data: (pending) => ListView.builder(
                  controller: ctrl,
                  itemCount: pending.length,
                  itemBuilder: (_, i) {
                    final a = pending[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.clientName, style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('${a.procedureName} · ${dateFmt.format(a.scheduledAt)}'),
                            const SizedBox(height: 8),
                            Row(children: [
                              Expanded(child: FilledButton(onPressed: () async { await ref.read(appointmentsNotifierProvider.notifier).updateStatus(a.id, 'scheduled'); if (context.mounted) Navigator.pop(context); }, child: const Text('Confirmar'))),
                              const SizedBox(width: 8),
                              Expanded(child: OutlinedButton(onPressed: () async { await ref.read(appointmentsNotifierProvider.notifier).updateStatus(a.id, 'cancelled'); if (context.mounted) Navigator.pop(context); }, child: const Text('Recusar'))),
                            ]),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
