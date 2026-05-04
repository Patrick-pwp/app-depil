import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/supabase_client.dart';

final _selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

final _cashflowProvider = FutureProvider.family<Map<String, dynamic>, DateTime>((ref, date) async {
  final supabase = ref.watch(supabaseProvider);
  final dateStr = DateFormat('yyyy-MM-dd').format(date);
  final rows = await supabase
      .from('financial_entries')
      .select('*, appointments(scheduled_at, is_paid)')
      .eq('entry_date', dateStr)
      .order('created_at');

  double totalRevenue = 0, totalCost = 0, totalProfit = 0;
  final entries = (rows as List).map((r) {
    final m = r as Map<String, dynamic>;
    totalRevenue += (m['revenue'] as num).toDouble();
    totalCost += (m['cost'] as num).toDouble();
    totalProfit += (m['profit'] as num).toDouble();
    return m;
  }).toList();

  return {
    'entries': entries,
    'totals': {'revenue': totalRevenue, 'cost': totalCost, 'profit': totalProfit},
  };
});

class CashflowPage extends ConsumerWidget {
  const CashflowPage({super.key});

  static final _currencyFmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
  static final _dateFmt = DateFormat('dd/MM/yyyy', 'pt_BR');
  static final _timeFmt = DateFormat('HH:mm');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(_selectedDateProvider);
    final cashflowAsync = ref.watch(_cashflowProvider(selectedDate));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Caixa do Dia'),
        actions: [
          TextButton(
            onPressed: () => context.push('/dre'),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('DRE Mensal'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Seletor de data
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => ref.read(_selectedDateProvider.notifier).state =
                      selectedDate.subtract(const Duration(days: 1)),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (picked != null) ref.read(_selectedDateProvider.notifier).state = picked;
                    },
                    child: Text(
                      _dateFmt.format(selectedDate),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: selectedDate.isBefore(DateTime.now().subtract(const Duration(days: 1)))
                      ? () => ref.read(_selectedDateProvider.notifier).state =
                          selectedDate.add(const Duration(days: 1))
                      : null,
                ),
              ],
            ),
          ),
          cashflowAsync.when(
            loading: () => const Expanded(child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Expanded(child: Center(child: Text('Erro: $e'))),
            data: (data) {
              final totals = data['totals'] as Map<String, dynamic>;
              final entries = data['entries'] as List;
              return Expanded(
                child: Column(
                  children: [
                    // Cards de totais
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(children: [
                        _TotalCard(label: 'Receita', value: totals['revenue'] as double, color: Colors.green[700]!),
                        const SizedBox(width: 8),
                        _TotalCard(label: 'Custo', value: totals['cost'] as double, color: Colors.orange[700]!),
                        const SizedBox(width: 8),
                        _TotalCard(label: 'Lucro', value: totals['profit'] as double, color: const Color(0xFFD4447A)),
                      ]),
                    ),
                    const SizedBox(height: 8),
                    Text('${entries.length} atendimento(s) realizado(s)', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    const Divider(),
                    Expanded(
                      child: entries.isEmpty
                          ? const Center(child: Text('Nenhum atendimento realizado neste dia'))
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: entries.length,
                              itemBuilder: (_, i) {
                                final e = entries[i] as Map<String, dynamic>;
                                final appt = e['appointments'] as Map<String, dynamic>?;
                                final time = appt != null ? _timeFmt.format(DateTime.parse(appt['scheduled_at'] as String)) : '';
                                final isPaid = appt?['is_paid'] as bool? ?? false;
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        Text(time, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                        const SizedBox(width: 12),
                                        Expanded(child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(e['client_name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                                            Text(e['procedure_name'] as String, style: const TextStyle(fontSize: 13)),
                                          ],
                                        )),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(_currencyFmt.format(e['revenue']), style: const TextStyle(color: Colors.green, fontSize: 13)),
                                            Text('Lucro: ${_currencyFmt.format(e['profit'])}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: isPaid ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(isPaid ? 'Pago' : 'Pendente', style: TextStyle(fontSize: 10, color: isPaid ? Colors.green[700] : Colors.orange[700])),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.label, required this.value, required this.color});
  final String label;
  final double value;
  final Color color;

  static final _fmt = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  @override
  Widget build(BuildContext context) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(_fmt.format(value), style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
            ]),
          ),
        ),
      );
}
