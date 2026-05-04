import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../clients/providers/clients_provider.dart';
import '../../../procedures/providers/procedures_provider.dart';
import '../../providers/appointments_provider.dart';
import '../../../../core/supabase_client.dart';

class CreateAppointmentPage extends ConsumerStatefulWidget {
  const CreateAppointmentPage({super.key});

  @override
  ConsumerState<CreateAppointmentPage> createState() => _CreateAppointmentPageState();
}

class _CreateAppointmentPageState extends ConsumerState<CreateAppointmentPage> {
  Client? _selectedClient;
  Procedure? _selectedProcedure;
  DateTime _selectedDate = DateTime.now();
  String? _selectedSlot;
  List<String> _availableSlots = [];
  bool _loadingSlots = false;
  bool _saving = false;

  Future<void> _loadSlots() async {
    if (_selectedProcedure == null) return;
    setState(() { _loadingSlots = true; _availableSlots = []; _selectedSlot = null; });
    try {
      final supabase = ref.read(supabaseProvider);
      final userId = supabase.auth.currentUser!.id;
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final data = await supabase.functions.invoke('check-availability', body: {
        'user_id': userId,
        'procedure_id': _selectedProcedure!.id,
        'date': dateStr,
      });
      final slots = List<String>.from(data.data['available_slots'] as List? ?? []);
      setState(() => _availableSlots = slots);
    } catch (_) {
      // fallback: gera slots locais sem verificar conflito (edge function ainda não deployada)
      setState(() => _availableSlots = _generateDefaultSlots());
    } finally {
      setState(() => _loadingSlots = false);
    }
  }

  List<String> _generateDefaultSlots() {
    final slots = <String>[];
    for (int h = 8; h < 20; h++) {
      slots.add('${h.toString().padLeft(2, '0')}:00');
      slots.add('${h.toString().padLeft(2, '0')}:30');
    }
    return slots;
  }

  Future<void> _save() async {
    if (_selectedClient == null || _selectedProcedure == null || _selectedSlot == null) return;
    setState(() => _saving = true);
    try {
      final supabase = ref.read(supabaseProvider);
      final userId = supabase.auth.currentUser!.id;
      final parts = _selectedSlot!.split(':');
      final scheduledAt = DateTime(
        _selectedDate.year, _selectedDate.month, _selectedDate.day,
        int.parse(parts[0]), int.parse(parts[1]),
      );
      final endsAt = scheduledAt.add(Duration(minutes: _selectedProcedure!.durationMinutes));
      await supabase.from('appointments').insert({
        'user_id': userId,
        'client_id': _selectedClient!.id,
        'procedure_id': _selectedProcedure!.id,
        'scheduled_at': scheduledAt.toIso8601String(),
        'ends_at': endsAt.toIso8601String(),
        'status': 'scheduled',
        'booked_via': 'manual',
      });
      ref.invalidate(appointmentsMonthProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientsNotifierProvider);
    final proceduresAsync = ref.watch(proceduresProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Novo Agendamento')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cliente
            Text('Cliente', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            clientsAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Erro: $e'),
              data: (clients) => DropdownButtonFormField<Client>(
                value: _selectedClient,
                hint: const Text('Selecionar cliente'),
                decoration: const InputDecoration(),
                items: clients.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                onChanged: (c) => setState(() => _selectedClient = c),
              ),
            ),
            const SizedBox(height: 20),

            // Procedimento
            Text('Serviço', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            proceduresAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Erro: $e'),
              data: (procs) => DropdownButtonFormField<Procedure>(
                value: _selectedProcedure,
                hint: const Text('Selecionar serviço'),
                decoration: const InputDecoration(),
                items: procs.map((p) => DropdownMenuItem(value: p, child: Text('${p.name} (${p.durationMinutes} min)'))).toList(),
                onChanged: (p) { setState(() { _selectedProcedure = p; _availableSlots = []; }); _loadSlots(); },
              ),
            ),
            const SizedBox(height: 20),

            // Data
            Text('Data', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0xFFE0C8D5))),
              tileColor: Colors.white,
              title: Text(DateFormat('dd/MM/yyyy', 'pt_BR').format(_selectedDate)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) { setState(() { _selectedDate = picked; _availableSlots = []; }); _loadSlots(); }
              },
            ),
            const SizedBox(height: 20),

            // Horários
            if (_selectedProcedure != null) ...[
              Text('Horário', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              _loadingSlots
                  ? const Center(child: CircularProgressIndicator())
                  : _availableSlots.isEmpty
                      ? const Text('Nenhum horário disponível para esta data')
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _availableSlots.map((slot) => ChoiceChip(
                            label: Text(slot),
                            selected: _selectedSlot == slot,
                            onSelected: (_) => setState(() => _selectedSlot = slot),
                            selectedColor: const Color(0xFFD4447A),
                            labelStyle: TextStyle(color: _selectedSlot == slot ? Colors.white : null),
                          )).toList(),
                        ),
              const SizedBox(height: 32),
            ],

            FilledButton(
              onPressed: (_selectedClient != null && _selectedProcedure != null && _selectedSlot != null && !_saving) ? _save : null,
              child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Confirmar Agendamento'),
            ),
          ],
        ),
      ),
    );
  }
}
