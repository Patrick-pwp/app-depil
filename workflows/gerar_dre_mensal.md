# Workflow: Gerar DRE Mensal

## Objetivo
Consolidar automaticamente todos os atendimentos realizados no mês e apresentar o Demonstrativo de Resultado do Exercício (DRE) simplificado.

## Entradas Necessárias
- Mês e ano selecionados (padrão: mês atual)
- `user_id` da profissional autenticada

## Passos

### 1. Acessar Tela de DRE
- Profissional acessa menu "Financeiro" → "DRE Mensal"
- Seletor de mês/ano disponível (padrão: mês corrente)

### 2. Carregar Consolidação
- Chamar `tools/get_monthly_dre.py` com `user_id`, `year`, `month`
- Retorna: totais agregados + breakdown por procedimento

### 3. Exibir DRE Simplificado
```
┌────────────────────────────────────────┐
│ DRE — Maio/2026                        │
│                                        │
│ Atendimentos Realizados:    47         │
│                                        │
│ (+) Receita Bruta:    R$ 4.230,00      │
│ (-) Custo Total:      R$   846,00      │
│ (=) Lucro Bruto:      R$ 3.384,00      │
│     Margem:           80%              │
└────────────────────────────────────────┘
```

### 4. Exibir Breakdown por Procedimento
| Procedimento | Qtd | Receita | Custo | Lucro |
|---|---|---|---|---|
| Perna inteira | 18 | R$1.800 | R$360 | R$1.440 |
| Virilha | 15 | R$1.125 | R$225 | R$900 |
| Axilas | 14 | R$1.305 | R$261 | R$1.044 |

### 5. Botão de Exportação
- Exibir botão "Exportar Excel"
- Aciona o workflow `exportar_relatorio_excel.md` com o período pré-selecionado

## Saídas Esperadas
- DRE consolidado do mês com totais e breakdown por procedimento
- Margem de lucro calculada: `(lucro / receita) * 100`

## Casos Extremos
- **Mês sem atendimentos realizados:** exibir DRE zerado com mensagem "Nenhum atendimento realizado neste mês"
- **Mês em andamento (atual):** exibir dados parciais com indicação "Mês em andamento"
- **Procedimento excluído após atendimentos:** os lançamentos em `financial_entries` são desnormalizados — o nome do procedimento fica preservado mesmo após exclusão

## Notas
- O DRE do MVP considera apenas receita de serviços — despesas operacionais são evolução futura
- A margem de lucro bruta é `lucro / receita * 100` — não confundir com margem líquida (que inclui despesas)
- Dados vêm exclusivamente de `financial_entries` — garantia de que só atendimentos Realizados entram no cálculo
