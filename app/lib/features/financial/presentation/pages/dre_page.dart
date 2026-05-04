import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/supabase_client.dart';

final _selectedMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

final _dreProvider = FutureProvider.family<Map<String, dynamic>, DateTime>((ref, month) async {
  final supabase = ref.watch(supabaseProvider);
  final start = DateTime(month.year, month.month, 1);
  final end = DateTime(month.year, month.month + 1, 0);
  final startStr = DateFormat('yyyy-MM-dd').format(start);
  final endStr = DateFormat('yyyy-MM-dd').format(end);

  final rows = await supabase
      .from('financial_entries')
      .select('revenue, cost, profit, procedure_name')
      .gte('entry_date', startStr)
      .lte('entry_date', endStr);

  double totalRevenue = 0, totalCost = 0, totalProfit = 0;
  final Map<String, Map<String, dynamic>> byProc = {};

  for (final r in rows as List) {
    final m = r as Map<String, dynamic>;
    final rev = (m['revenue'] as num).toDouble();
    final cost = (m['cost'] as num).toDouble();
    final profit = (m['profit'] as num).toDouble();
    final procName = m['procedure_name'] as String;
    totalRevenue += rev;
    totalCost += cost;
    totalProfit += profit;
    byProc.putIfAbsent(procName, () => {'count': 0, 'revenue': 0.0, 'cost': 0.0, 'profit': 0.0});
    byProc[procName]!['count'] = (byProc[procName]!['count'] as int) + 1;
    byProc[procName]!['revenue'] = (byProc[procName]!['revenue'] as double) + rev;
    byProc[procName]!['cost'] = (byProc[procName]!['cost'] as double) + cost;
    byProc[procName]!['profit'] = (byProc[procName]!['profit'] as double) + profit;
  }

  final sortedProcs = byProc.entries.toList()
    ..sort((a, b) => (b.value['revenue'] as double).compareTo(a.value['revenue'] as double));

  return {
    'count': rows.length,
    'revenue': totalRevenue,
    'cost': totalCost,
    'profit': totalProfit,
    'margin': totalRevenue > 0 ? (totalProfit / totalRevenue * 100) : 0.0,
    'by_procedure': sortedProcs,
  };
});

class DrePage extends ConsumerWidget {
  const DrePage({super.key});

  static final _currencyFmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  static final _monthFmt = DateFormat('MMMM/yyyy', 'pt_BR');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(_selectedMonthProvider);
    final dreAsync = ref.watch(_dreProvider(month));

    return Scaffold(
      appBar: AppBar(title: const Text('DRE Mensal')),
      body: Column(
        children: [
          // Seletor de mês
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => ref.read(_selectedMonthProvider.notifier).state =
                      DateTime(month.year, month.month - 1),
                ),
                Expanded(
                  child: Text(
                    _monthFmt.format(month).capitalize(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: DateTime(month.year, month.month).isBefore(DateTime(DateTime.now().year, DateTime.now().month))
                      ? () => ref.read(_selectedMonthProvider.notifier).state = DateTime(month.year, month.month + 1)
                      : null,
                ),
              ],
            ),
          ),
          dreAsync.when(
            loading: () => const Expanded(child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Expanded(child: Center(child: Text('Erro: $e'))),
            data: (dre) => Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // DRE Summary Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _DreRow(label: 'Atendimentos Realizados', value: '${dre['count']}', bold: false),
                          const Divider(),
                          _DreRow(label: '(+) Receita Bruta', value: _currencyFmt.format(dre['revenue']), color: Colors.green[700]!),
                          _DreRow(label: '(-) Custo Total', value: _currencyFmt.format(dre['cost']), color: Colors.orange[700]!),
                          const Divider(thickness: 2),
                          _DreRow(label: '(=) Lucro Bruto', value: _currencyFmt.format(dre['profit']), color: const Color(0xFFD4447A), bold: true),
                          _DreRow(label: 'Margem de Lucro', value: '${(dre['margin'] as double).toStringAsFixed(1)}%', bold: false),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if ((dre['by_procedure'] as List).isNotEmpty) ...[
                    const Text('Por Serviço', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    ...(dre['by_procedure'] as List).map((entry) {
                      final e = entry as MapEntry<String, Map<String, dynamic>>;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold))),
                                  Text('${e.value['count']}x', style: const TextStyle(color: Colors.grey)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Receita: ${_currencyFmt.format(e.value['revenue'])}', style: TextStyle(fontSize: 12, color: Colors.green[700])),
                                  Text('Lucro: ${_currencyFmt.format(e.value['profit'])}', style: const TextStyle(fontSize: 12, color: Color(0xFFD4447A))),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DreRow extends StatelessWidget {
  const _DreRow({required this.label, required this.value, this.color, this.bold = true});
  final String label;
  final String value;
  final Color? color;
  final bool bold;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
            Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color, fontSize: bold ? 15 : 14)),
          ],
        ),
      );
}

extension _StringExtension on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
