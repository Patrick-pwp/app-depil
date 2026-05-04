# Workflow: Controle de Caixa Diário

## Objetivo
A profissional visualiza os lançamentos financeiros do dia e acompanha receita, custo e lucro em tempo real.

## Entradas Necessárias
- Data selecionada (padrão: hoje)
- `user_id` da profissional autenticada

## Passos

### 1. Acessar Tela de Caixa
- Profissional acessa menu "Financeiro" → "Caixa do Dia"
- Data exibida: hoje (com seletor para navegar entre dias)

### 2. Carregar Lançamentos
- Chamar `tools/get_daily_cashflow.py` com `user_id` e `date`
- Retorna: lista de lançamentos + totais agregados

### 3. Exibir Resumo do Dia
```
┌─────────────────────────────────┐
│ Caixa — [Data]                  │
│                                 │
│ Receita Total:   R$ 450,00      │
│ Custo Total:     R$ 90,00       │
│ Lucro do Dia:    R$ 360,00      │
│                                 │
│ Atendimentos realizados: 3      │
└─────────────────────────────────┘
```

### 4. Exibir Lançamentos Individuais
Para cada lançamento do dia, mostrar:
- Horário do atendimento
- Nome da cliente
- Procedimento realizado
- Receita (R$)
- Custo (R$)
- Lucro (R$)
- Indicador de pagamento: Pago / Não Pago

### 5. Atualização em Tempo Real
- Supabase Realtime escuta inserções em `financial_entries` para o `user_id` atual
- Ao marcar um atendimento como Realizado em qualquer tela, o caixa atualiza automaticamente sem precisar recarregar

## Saídas Esperadas
- Visualização dos lançamentos do dia selecionado
- Totais de receita, custo e lucro do dia

## Casos Extremos
- **Dia sem atendimentos realizados:** exibir "Nenhum atendimento realizado neste dia" com totais zerados
- **Data futura selecionada:** permitir visualizar (útil para dias com agendamentos confirmados), mas não haverá lançamentos (pois nenhum foi realizado ainda)
- **Lançamentos de dias anteriores editados:** não aplicável — lançamentos são imutáveis no MVP

## Notas
- O caixa exibe apenas `financial_entries` (atendimentos Realizados) — não mistura com despesas manuais no MVP
- Despesas operacionais (aluguel, produtos) são evolução futura
- O indicador "Pago/Não Pago" vem de `appointments.is_paid` — pode ser atualizado na própria tela
