import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/clients_provider.dart';

class ClientsPage extends ConsumerWidget {
  const ClientsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientsAsync = ref.watch(clientsNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showClientForm(context, ref),
        child: const Icon(Icons.person_add_outlined),
      ),
      body: clientsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (clients) => clients.isEmpty
            ? const Center(child: Text('Nenhuma cliente cadastrada.\nToque em + para adicionar.', textAlign: TextAlign.center))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: clients.length,
                itemBuilder: (_, i) => ListTile(
                  leading: CircleAvatar(child: Text(clients[i].name[0].toUpperCase())),
                  title: Text(clients[i].name),
                  subtitle: Text(clients[i].phone),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/clients/${clients[i].id}'),
                ),
              ),
      ),
    );
  }

  void _showClientForm(BuildContext context, WidgetRef ref, [Client? existing]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ClientForm(existing: existing, ref: ref),
    );
  }
}

class _ClientForm extends ConsumerStatefulWidget {
  const _ClientForm({this.existing, required this.ref});
  final Client? existing;
  final WidgetRef ref;

  @override
  ConsumerState<_ClientForm> createState() => _ClientFormState();
}

class _ClientFormState extends ConsumerState<_ClientForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.existing?.name);
  late final _phoneCtrl = TextEditingController(text: widget.existing?.phone);
  late final _notesCtrl = TextEditingController(text: widget.existing?.notes);
  bool _loading = false;

  @override
  void dispose() { _nameCtrl.dispose(); _phoneCtrl.dispose(); _notesCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(clientsNotifierProvider.notifier).upsert(
            id: widget.existing?.id,
            name: _nameCtrl.text.trim(),
            phone: _phoneCtrl.text.trim(),
            notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.existing == null ? 'Nova cliente' : 'Editar cliente', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(controller: _nameCtrl, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nome completo *'), validator: (v) => v!.trim().isEmpty ? 'Obrigatório' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Telefone / WhatsApp *'), validator: (v) => v!.trim().isEmpty ? 'Obrigatório' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _notesCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Observações (opcional)')),
            const SizedBox(height: 24),
            FilledButton(onPressed: _loading ? null : _save, child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Salvar')),
          ],
        ),
      ),
    );
  }
}
