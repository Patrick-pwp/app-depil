import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/supabase_client.dart';
import '../../providers/clients_provider.dart';

// Provider correto para buscar o histórico de atendimentos de um cliente
final clientAppointmentsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, clientId) async {
  final data = await ref
      .watch(supabaseProvider)
      .from('appointments')
      .select('status, scheduled_at, procedures(name)')
      .eq('client_id', clientId)
      .order('scheduled_at', ascending: false)
      .limit(50);
  return (data as List).cast<Map<String, dynamic>>();
});

class ClientDetailPage extends ConsumerWidget {
  const ClientDetailPage({super.key, required this.clientId});

  final String clientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientsAsync = ref.watch(clientsNotifierProvider);

    return clientsAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Erro: $e'))),
      data: (clients) {
        final client = clients.where((c) => c.id == clientId).firstOrNull;
        if (client == null) {
          return const Scaffold(body: Center(child: Text('Cliente não encontrada')));
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(client.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _showEditForm(context, ref, client),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(label: 'Telefone', value: client.phone),
                      if (client.notes != null && client.notes!.isNotEmpty) ...[
                        const Divider(),
                        _InfoRow(label: 'Observações', value: client.notes!),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Histórico de Atendimentos',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              _ClientAppointmentsList(clientId: clientId),
            ],
          ),
        );
      },
    );
  }

  void _showEditForm(BuildContext context, WidgetRef ref, Client client) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EditClientForm(client: client, ref: ref),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      );
}

class _ClientAppointmentsList extends ConsumerWidget {
  const _ClientAppointmentsList({required this.clientId});
  final String clientId;

  static final _dateFmt = DateFormat('dd/MM/yyyy HH:mm', 'pt_BR');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointmentsAsync = ref.watch(clientAppointmentsProvider(clientId));

    return appointmentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Erro ao carregar histórico: $e',
          style: const TextStyle(color: Colors.red)),
      data: (rows) {
        if (rows.isEmpty) {
          return const Text(
            'Nenhum atendimento registrado',
            style: TextStyle(color: Colors.grey),
          );
        }
        return Column(
          children: rows.map((m) {
            final procName = (m['procedures'] as Map?)?['name'] as String? ?? '';
            final scheduledAt = DateTime.parse(m['scheduled_at'] as String);
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(procName),
              subtitle: Text(_dateFmt.format(scheduledAt.toLocal())),
              trailing: _StatusChip(status: m['status'] as String),
            );
          }).toList(),
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  static const _labels = {
    'scheduled': 'Agendado',
    'completed': 'Realizado',
    'cancelled': 'Cancelado',
    'no_show': 'Faltou',
    'pending': 'Pendente',
  };
  static const _colors = {
    'scheduled': Color(0xFF1976D2),
    'completed': Color(0xFF388E3C),
    'cancelled': Color(0xFF757575),
    'no_show': Color(0xFFF57C00),
    'pending': Color(0xFFE65100),
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[status] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Text(
        _labels[status] ?? status,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _EditClientForm extends ConsumerStatefulWidget {
  const _EditClientForm({required this.client, required this.ref});
  final Client client;
  final WidgetRef ref;

  @override
  ConsumerState<_EditClientForm> createState() => _EditClientFormState();
}

class _EditClientFormState extends ConsumerState<_EditClientForm> {
  late final _nameCtrl = TextEditingController(text: widget.client.name);
  late final _phoneCtrl = TextEditingController(text: widget.client.phone);
  late final _notesCtrl = TextEditingController(text: widget.client.notes);
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      await ref.read(clientsNotifierProvider.notifier).upsert(
            id: widget.client.id,
            name: _nameCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
            notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Editar cliente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 16),
          TextFormField(controller: _nameCtrl, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nome')),
          const SizedBox(height: 12),
          TextFormField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telefone')),
          const SizedBox(height: 12),
          TextFormField(controller: _notesCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Observações')),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Salvar'),
          ),
        ],
      ),
    );
  }
}
