# Workflow: Atualizar Status do Atendimento

## Objetivo
A profissional atualiza o status de um agendamento conforme o que aconteceu no dia. Marcar como "Realizado" é a ação crítica — ela dispara o lançamento financeiro automático.

## Entradas Necessárias
- `appointment_id` do agendamento a ser atualizado
- Novo status desejado

## Transições de Status Permitidas

| De | Para | Ação financeira |
|---|---|---|
| `scheduled` | `completed` | **Cria lançamento em `financial_entries`** |
| `scheduled` | `cancelled` | Nenhuma |
| `scheduled` | `no_show` | Nenhuma |
| `pending` | `scheduled` | Nenhuma (ver workflow de confirmação) |
| `pending` | `cancelled` | Nenhuma |
| `completed` | — | **Imutável** — não pode ser revertido |

## Passos

### 1. Selecionar Agendamento
- Profissional toca/clica no agendamento no calendário ou na lista do dia
- Visualizar detalhes: cliente, procedimento, horário, status atual

### 2. Escolher Novo Status
- Exibir apenas transições válidas para o status atual
- Para `scheduled`, mostrar botões: **Realizado**, **Cancelado**, **Faltou**

### 3a. Marcar como Realizado
- Exibir confirmação: "Confirmar atendimento realizado para [cliente] — [procedimento]?"
- Marcar campo `is_paid` (Pago: Sim/Não) — opcional, padrão Não
- Ao confirmar: chamar `tools/update_appointment_status.py` com `new_status = 'completed'`
- **O tool aciona o trigger PostgreSQL que insere em `financial_entries`:**
  - `entry_date` = data do agendamento
  - `client_name` = nome do cliente (desnormalizado)
  - `procedure_name` = nome do procedimento (desnormalizado)
  - `revenue` = `procedure.revenue`
  - `cost` = `procedure.cost`
  - `profit` = `procedure.profit`

### 3b. Marcar como Cancelado
- Chamar `tools/update_appointment_status.py` com `new_status = 'cancelled'`
- Nenhum lançamento financeiro gerado

### 3c. Marcar como Faltou (No-show)
- Chamar `tools/update_appointment_status.py` com `new_status = 'no_show'`
- Nenhum lançamento financeiro gerado

### 4. Feedback
- Status atualizado no calendário imediatamente
- Se Realizado: toast "Atendimento registrado! Receita de R$[valor] lançada no caixa."
- Caixa do dia e DRE mensal atualizados em tempo real

## Saídas Esperadas
- `appointments.status` atualizado
- Se `completed`: novo registro em `financial_entries` com dados corretos

## Casos Extremos
- **Tentar reverter "Realizado":** bloquear — o lançamento financeiro é permanente. Se foi erro, profissional deve contatar suporte (pós-MVP: soft delete com justificativa)
- **Agendamento no futuro sendo marcado como Realizado:** permitir (atendimento pode ter sido adiantado)
- **Procedimento editado após agendamento:** usar os valores do procedimento **no momento do agendamento**, não os valores atuais — por isso `financial_entries` é desnormalizado

## Notas
- A regra "somente Realizado gera financeiro" é o coração do produto — nunca burlar isso
- O trigger PostgreSQL garante atomicidade: se a inserção em `financial_entries` falhar, o update de status também reverte (transaction)
