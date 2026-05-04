import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Página pública — acessada sem autenticação via /book/:slug

final _publicProceduresProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, slug) async {
  final supabase = Supabase.instance.client;
  final professional = await supabase
      .from('professionals')
      .select('id, name')
      .eq('slug', slug)
      .maybeSingle();
  if (professional == null) return [];

  final procs = await supabase
      .from('procedures')
      .select('id, name, duration_minutes, revenue')
      .eq('user_id', professional['id'] as String)
      .eq('is_active', true)
      .order('name');

  return (procs as List)
      .map((p) => {...(p as Map<String, dynamic>), 'professional_name': professional['name']})
      .toList();
});

class PublicBookingPage extends ConsumerStatefulWidget {
  const PublicBookingPage({super.key, required this.slug});
  final String slug;

  @override
  ConsumerState<PublicBookingPage> createState() => _PublicBookingPageState();
}

class _PublicBookingPageState extends ConsumerState<PublicBookingPage> {
  int _step = 0;  // 0=procedimento, 1=data, 2=horário, 3=dados, 4=confirmado
  Map<String, dynamic>? _selectedProcedure;
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String? _selectedSlot;
  List<String> _availableSlots = [];
  bool _loadingSlots = false;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() { _nameCtrl.dispose(); _phoneCtrl.dispose(); super.dispose(); }

  Future<void> _loadSlots() async {
    if (_selectedProcedure == null) return;
    setState(() { _loadingSlots = true; _availableSlots = []; _selectedSlot = null; });
    try {
      final supabase = Supabase.instance.client;
      final prof = await supabase.from('professionals').select('id').eq('slug', widget.slug).single();
      final userId = prof['id'] as String;
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final start = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 0, 0);
      final end = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59);
      final busy = await supabase
          .from('appointments')
          .select('scheduled_at, ends_at')
          .eq('user_id', userId)
          .gte('scheduled_at', start.toIso8601String())
          .lte('ends_at', end.toIso8601String())
          .not('status', 'in', '(cancelled,no_show)');
      final busyIntervals = (busy as List).map((b) => (
        DateTime.parse((b as Map)['scheduled_at'] as String),
        DateTime.parse(b['ends_at'] as String),
      )).toList();
      final duration = _selectedProcedure!['duration_minutes'] as int;
      final slots = <String>[];
      var current = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 8, 0);
      final endBoundary = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 20, 0);
      while (current.add(Duration(minutes: duration)).isBefore(endBoundary) || current.add(Duration(minutes: duration)).isAtSameMomentAs(endBoundary)) {
        final slotEnd = current.add(Duration(minutes: duration));
        final conflict = busyIntervals.any((b) => current.isBefore(b.$2) && slotEnd.isAfter(b.$1));
        if (!conflict) slots.add(DateFormat('HH:mm').format(current));
        current = current.add(const Duration(minutes: 30));
      }
      setState(() => _availableSlots = slots);
    } catch (e) {
      setState(() => _error = 'Erro ao carregar horários');
    } finally {
      setState(() => _loadingSlots = false);
    }
  }

  Future<void> _confirm() async {
    if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) return;
    setState(() { _saving = true; _error = null; });
    try {
      final supabase = Supabase.instance.client;
      final prof = await supabase.from('professionals').select('id').eq('slug', widget.slug).single();
      final userId = prof['id'] as String;
      final parts = _selectedSlot!.split(':');
      final scheduledAt = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, int.parse(parts[0]), int.parse(parts[1]));
      final endsAt = scheduledAt.add(Duration(minutes: _selectedProcedure!['duration_minutes'] as int));
      // Buscar ou criar cliente
      final phone = _normalizePhone(_phoneCtrl.text.trim());
      final existingClients = await supabase.from('clients').select('id').eq('user_id', userId).eq('phone', phone);
      String clientId;
      if ((existingClients as List).isNotEmpty) {
        clientId = (existingClients.first as Map)['id'] as String;
      } else {
        final newClient = await supabase.from('clients').insert({'user_id': userId, 'name': _nameCtrl.text.trim(), 'phone': phone}).select('id').single();
        clientId = newClient['id'] as String;
      }
      await supabase.from('appointments').insert({
        'user_id': userId, 'client_id': clientId,
        'procedure_id': _selectedProcedure!['id'] as String,
        'scheduled_at': scheduledAt.toIso8601String(),
        'ends_at': endsAt.toIso8601String(),
        'status': 'pending', 'booked_via': 'public_page',
      });
      setState(() => _step = 4);
    } catch (e) {
      setState(() => _error = 'Horário indisponível. Por favor, escolha outro.');
    } finally {
      setState(() => _saving = false);
    }
  }

  String _normalizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11 && !digits.startsWith('55')) return '+55$digits';
    if (digits.startsWith('55')) return '+$digits';
    return '+$digits';
  }

  @override
  Widget build(BuildContext context) {
    final procsAsync = ref.watch(_publicProceduresProvider(widget.slug));

    if (_step == 4) return _SuccessPage(slug: widget.slug);

    return Scaffold(
      appBar: AppBar(title: procsAsync.maybeWhen(data: (p) => p.isNotEmpty ? Text('Agendar com ${p.first['professional_name']}') : const Text('Agendamento'), orElse: () => const Text('Agendamento'))),
      body: procsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (procedures) {
          if (procedures.isEmpty) return const Center(child: Text('Profissional não encontrada'));
          return Stepper(
            currentStep: _step,
            controlsBuilder: (_, details) => const SizedBox.shrink(),
            steps: [
              Step(
                title: const Text('Serviço'),
                isActive: _step >= 0,
                state: _step > 0 ? StepState.complete : StepState.indexed,
                content: Column(
                  children: procedures.map((p) => ListTile(
                    title: Text(p['name'] as String),
                    subtitle: Text('${p['duration_minutes']} min · R\$ ${(p['revenue'] as num).toStringAsFixed(2)}'),
                    trailing: _selectedProcedure?['id'] == p['id'] ? const Icon(Icons.check_circle, color: Color(0xFFD4447A)) : null,
                    onTap: () { setState(() { _selectedProcedure = p; _step = 1; }); _loadSlots(); },
                  )).toList(),
                ),
              ),
              Step(
                title: const Text('Data'),
                isActive: _step >= 1,
                state: _step > 1 ? StepState.complete : StepState.indexed,
                content: Column(
                  children: List.generate(14, (i) {
                    final d = DateTime.now().add(Duration(days: i + 1));
                    final dateFmt = DateFormat('EEEE, dd/MM', 'pt_BR');
                    return ListTile(
                      title: Text(dateFmt.format(d).capitalize()),
                      trailing: isSameDay(d, _selectedDate) ? const Icon(Icons.check_circle, color: Color(0xFFD4447A)) : null,
                      onTap: () { setState(() { _selectedDate = d; _step = 2; }); _loadSlots(); },
                    );
                  }),
                ),
              ),
              Step(
                title: const Text('Horário'),
                isActive: _step >= 2,
                state: _step > 2 ? StepState.complete : StepState.indexed,
                content: _loadingSlots
                    ? const Center(child: CircularProgressIndicator())
                    : _availableSlots.isEmpty
                        ? const Text('Nenhum horário disponível. Escolha outra data.')
                        : Wrap(
                            spacing: 8, runSpacing: 8,
                            children: _availableSlots.map((slot) => ChoiceChip(
                              label: Text(slot),
                              selected: _selectedSlot == slot,
                              onSelected: (_) { setState(() { _selectedSlot = slot; _step = 3; }); },
                              selectedColor: const Color(0xFFD4447A),
                              labelStyle: TextStyle(color: _selectedSlot == slot ? Colors.white : null),
                            )).toList(),
                          ),
              ),
              Step(
                title: const Text('Seus Dados'),
                isActive: _step >= 3,
                content: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(controller: _nameCtrl, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nome completo *')),
                    const SizedBox(height: 12),
                    TextField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'WhatsApp *')),
                    if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: const TextStyle(color: Colors.red))],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _saving ? null : _confirm,
                      child: _saving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Solicitar Agendamento'),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

class _SuccessPage extends StatelessWidget {
  const _SuccessPage({required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline, size: 80, color: Color(0xFFD4447A)),
                  const SizedBox(height: 24),
                  const Text('Solicitação enviada!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  const Text('A profissional irá confirmar seu agendamento em breve. Entre em contato pelo WhatsApp para mais informações.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 32),
                  OutlinedButton(
                    onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PublicBookingPage(slug: slug))),
                    child: const Text('Fazer outro agendamento'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

extension _StringExtension on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
