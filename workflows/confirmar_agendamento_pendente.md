# Workflow: Confirmar Agendamento Pendente

## Objetivo
A profissional revisa solicitações de agendamento feitas por clientes via página pública e decide confirmar ou recusar cada uma.

## Entradas Necessárias
- Lista de agendamentos com status `pending` da profissional autenticada

## Passos

### 1. Visualizar Solicitações Pendentes
- Exibir lista de agendamentos com status `pending`
- Para cada solicitação mostrar: nome do cliente, telefone, procedimento solicitado, data e horário pedido
- Ordenar por data/horário crescente
- Indicar visualmente (badge/contador) quantos estão pendentes — exibir no dashboard

### 2. Revisar Solicitação Individual
- Profissional abre uma solicitação
- Verificar se o horário ainda está disponível: chamar `tools/check_availability.py`
  - Se conflito surgiu após a solicitação: avisar profissional antes de confirmar

### 3a. Confirmar
- Profissional clica em "Confirmar"
- Chamar `tools/update_appointment_status.py` com `appointment_id`, `new_status = 'scheduled'`
- Agendamento passa de `pending` para `scheduled`
- Agendamento entra no calendário normalmente

### 3b. Recusar
- Profissional clica em "Recusar" (com motivo opcional)
- Chamar `tools/update_appointment_status.py` com `new_status = 'cancelled'`
- Registro mantido com `cancelled_by = 'professional'`

### 4. Feedback
- Atualizar contador de pendentes em tempo real (Supabase Realtime)
- Solicitação sai da fila após decisão

## Saídas Esperadas
- Agendamento `pending` → `scheduled` (confirmado) ou `cancelled` (recusado)
- Calendário atualizado automaticamente

## Casos Extremos
- **Conflito descoberto na confirmação:** avisar que o horário agora tem conflito, oferecer cancelar ou confirmar mesmo assim (override manual)
- **Cliente solicitou horário em data passada** (edge case de fuso): bloquear confirmação e marcar como `cancelled` automaticamente
- **Muitos pendentes acumulados:** exibir todos, permitir confirmar/recusar em lote

## Notas
- No MVP, não há notificação automática ao cliente (sem WhatsApp/email ainda)
- A profissional deve informar o cliente por fora (WhatsApp pessoal) sobre a confirmação
- WhatsApp automático é evolução futura
