import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/procedures_provider.dart';

final _currencyFmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

class ProceduresPage extends ConsumerWidget {
  const ProceduresPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final proceduresAsync = ref.watch(proceduresNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Serviços')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProcedureForm(context, ref),
        child: const Icon(Icons.add),
      ),
      body: proceduresAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (procedures) => procedures.isEmpty
            ? const Center(child: Text('Nenhum serviço cadastrado.\nToque em + para adicionar.', textAlign: TextAlign.center))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: procedures.length,
                itemBuilder: (_, i) => _ProcedureCard(procedure: procedures[i]),
              ),
      ),
    );
  }

  void _showProcedureForm(BuildContext context, WidgetRef ref, [Procedure? existing]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ProcedureForm(existing: existing, ref: ref),
    );
  }
}

class _ProcedureCard extends ConsumerWidget {
  const _ProcedureCard({required this.procedure});
  final Procedure procedure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(procedure.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${procedure.durationMinutes} min · Receita: ${_currencyFmt.format(procedure.revenue)}'),
            Text('Custo: ${_currencyFmt.format(procedure.cost)} · Lucro: ${_currencyFmt.format(procedure.profit)}',
                style: TextStyle(color: procedure.profit >= 0 ? Colors.green[700] : Colors.red)),
          ],
        ),
        trailing: Switch(
          value: procedure.isActive,
          onChanged: (v) => ref.read(proceduresNotifierProvider.notifier).toggleActive(procedure.id, v),
        ),
      ),
    );
  }
}

class _ProcedureForm extends ConsumerStatefulWidget {
  const _ProcedureForm({this.existing, required this.ref});
  final Procedure? existing;
  final WidgetRef ref;

  @override
  ConsumerState<_ProcedureForm> createState() => _ProcedureFormState();
}

class _ProcedureFormState extends ConsumerState<_ProcedureForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl = TextEditingController(text: widget.existing?.name);
  late final _revenueCtrl = TextEditingController(text: widget.existing?.revenue.toStringAsFixed(2));
  late final _costCtrl = TextEditingController(text: widget.existing?.cost.toStringAsFixed(2));
  late final _durationCtrl = TextEditingController(text: widget.existing?.durationMinutes.toString());
  bool _loading = false;

  double get _profit => (double.tryParse(_revenueCtrl.text.replaceAll(',', '.')) ?? 0) -
      (double.tryParse(_costCtrl.text.replaceAll(',', '.')) ?? 0);

  @override
  void dispose() {
    _nameCtrl.dispose(); _revenueCtrl.dispose(); _costCtrl.dispose(); _durationCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(proceduresNotifierProvider.notifier).upsert(
            id: widget.existing?.id,
            name: _nameCtrl.text.trim(),
            revenue: double.parse(_revenueCtrl.text.replaceAll(',', '.')),
            cost: double.parse(_costCtrl.text.replaceAll(',', '.')),
            durationMinutes: int.parse(_durationCtrl.text),
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
            Text(widget.existing == null ? 'Novo serviço' : 'Editar serviço', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Nome do serviço'), validator: (v) => v!.isEmpty ? 'Obrigatório' : null),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(controller: _revenueCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Receita (R\$)'), onChanged: (_) => setState(() {}), validator: (v) => double.tryParse(v!.replaceAll(',', '.')) == null ? 'Inválido' : null)),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: _costCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Custo (R\$)'), onChanged: (_) => setState(() {}), validator: (v) => double.tryParse(v!.replaceAll(',', '.')) == null ? 'Inválido' : null)),
            ]),
            const SizedBox(height: 8),
            Text('Lucro: ${_currencyFmt.format(_profit)}', style: TextStyle(color: _profit >= 0 ? Colors.green[700] : Colors.red, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextFormField(controller: _durationCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Duração (minutos)'), validator: (v) => int.tryParse(v!) == null ? 'Inválido' : null),
            const SizedBox(height: 24),
            FilledButton(onPressed: _loading ? null : _save, child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Salvar')),
          ],
        ),
      ),
    );
  }
}
