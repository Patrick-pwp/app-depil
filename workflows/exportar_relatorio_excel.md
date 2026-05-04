# Workflow: Exportar Relatório para Excel

## Objetivo
A profissional gera e baixa um arquivo .xlsx com lançamentos financeiros do período selecionado, contendo detalhamento e resumo consolidado.

## Entradas Necessárias
- Data inicial e data final do período (padrão: mês atual)
- `user_id` da profissional autenticada

## Passos

### 1. Selecionar Período
- Profissional acessa "Financeiro" → "Exportar"
- Escolhe período: mês pré-definido (seletor mês/ano) ou intervalo de datas personalizado
- Clica em "Gerar relatório"

### 2. Gerar Arquivo
- Chamar `tools/export_financial_to_excel.py` com `user_id`, `start_date`, `end_date`
- Tool gera arquivo em `.tmp/relatorio_[YYYY-MM].xlsx` com duas abas:

**Aba 1 — Lançamentos (detalhe):**
| Data | Cliente | Procedimento | Receita (R$) | Custo (R$) | Lucro (R$) | Pago |
|---|---|---|---|---|---|---|
| 05/05/2026 | Ana Silva | Perna inteira | 100,00 | 20,00 | 80,00 | Sim |
| 05/05/2026 | Bruna Lima | Virilha | 75,00 | 15,00 | 60,00 | Não |

**Aba 2 — Resumo DRE:**
| Campo | Valor |
|---|---|
| Período | 01/05/2026 a 31/05/2026 |
| Atendimentos Realizados | 47 |
| Receita Bruta | R$ 4.230,00 |
| Custo Total | R$ 846,00 |
| Lucro Bruto | R$ 3.384,00 |
| Margem de Lucro | 80% |

### 3. Disponibilizar Download
- Arquivo gerado em `.tmp/` no servidor
- URL temporária gerada (válida por 10 minutos)
- Usuária clica em "Baixar" — browser/app abre download do .xlsx
- Arquivo removido de `.tmp/` após download ou expiração

## Saídas Esperadas
- Arquivo `.xlsx` com lançamentos detalhados e resumo DRE
- Download iniciado no dispositivo da profissional

## Casos Extremos
- **Período sem lançamentos:** gerar arquivo com aba de lançamentos vazia e DRE zerado (não retornar erro)
- **Período muito longo (ex: 1 ano):** permitir — não há limite de linhas no MVP
- **Falha na geração:** exibir erro "Não foi possível gerar o relatório" com botão de tentar novamente
- **Formato de datas:** usar formato brasileiro (DD/MM/AAAA) e separador decimal vírgula (R$ 1.234,56)

## Notas
- Lib utilizada: `openpyxl` — não requer LibreOffice ou Excel instalado no servidor
- Valores monetários exportados com 2 casas decimais, formato brasileiro
- Arquivo `.tmp/` é descartável — regenerado a cada solicitação
- Não salvar histórico de exportações no MVP
