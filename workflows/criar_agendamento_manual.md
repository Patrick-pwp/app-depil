# Workflow: Criar Agendamento Manual

## Objetivo
A profissional cria um agendamento diretamente pelo sistema para uma cliente, definindo procedimento, data e horário.

## Entradas Necessárias
- Cliente (existente ou nova)
- Procedimento selecionado
- Data e horário desejados

## Passos

### 1. Selecionar ou Cadastrar Cliente
- Profissional busca cliente pelo nome ou telefone (`tools/search_client.py`)
- Se não encontrar: oferecer cadastro rápido (nome + telefone) inline
- Selecionar cliente da lista de resultados

### 2. Selecionar Procedimento
- Exibir lista de procedimentos ativos da profissional
- Mostrar nome, duração e valor cobrado
- Profissional seleciona o procedimento

### 3. Selecionar Data e Horário
- Profissional escolhe data no calendário
- **Bloquear datas passadas** — não permitir seleção de datas anteriores a hoje
- Chamar `tools/check_availability.py` com `user_id`, `procedure_id`, `date`
- Exibir slots disponíveis (horários sem conflito)
- Profissional seleciona o horário

### 4. Confirmar Agendamento
- Exibir resumo: cliente, procedimento, data, horário, duração, valor
- Profissional confirma
- Chamar `tools/create_appointment.py` com todos os dados
  - Status inicial: `scheduled`
  - `booked_via`: `manual`

### 5. Feedback
- Exibir confirmação visual do agendamento na agenda
- Agendamento aparece imediatamente no calendário

## Saídas Esperadas
- Registro criado em `appointments` com status `scheduled`
- Agendamento visível no calendário da profissional

## Casos Extremos
- **Conflito de horário:** `check_availability` retorna slot indisponível — exibir mensagem clara e oferecer próximo horário livre
- **Data passada:** bloquear seleção no frontend e validar no backend (retornar erro 400)
- **Cliente sem histórico:** criar normalmente, histórico ficará vazio
- **Procedimento inativo:** não exibir na lista de seleção

## Notas
- O agendamento manual já nasce com status `scheduled` (não `pending`)
- Duração do `ends_at` = `scheduled_at` + `procedure.duration_minutes`
