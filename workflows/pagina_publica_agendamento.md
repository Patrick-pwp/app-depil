# Workflow: Página Pública de Agendamento (Cliente Final)

## Objetivo
O cliente final acessa a página pública da profissional, escolhe procedimento e horário disponível, informa seus dados e solicita o agendamento — sem precisar criar conta.

## Entradas Necessárias
- `slug` da profissional (da URL: `appdepil.com.br/[slug]`)
- Dados do cliente: nome e telefone

## Rota
`GET /[slug]` — rota pública, sem autenticação

## Passos

### 1. Carregar Página da Profissional
- Sistema resolve `slug` → `user_id` via tabela `professionals`
- Se slug não encontrado: exibir página 404 amigável ("Profissional não encontrada")
- Exibir: nome da profissional, lista de procedimentos ativos (nome, duração, valor)

### 2. Cliente Seleciona Procedimento
- Cliente toca/clica no procedimento desejado
- Sistema avança para seleção de data

### 3. Cliente Seleciona Data
- Exibir calendário com datas disponíveis (não mostrar datas passadas)
- Cliente seleciona uma data

### 4. Carregar Horários Disponíveis
- Chamar `tools/get_public_availability.py` com `user_id`, `procedure_id`, `date`
- Exibir slots livres como botões de horário
- Se nenhum slot disponível nessa data: exibir "Sem horários disponíveis neste dia. Escolha outra data."

### 5. Cliente Seleciona Horário
- Cliente toca no horário desejado
- Avança para formulário de dados

### 6. Cliente Informa Dados
- Campo obrigatório: **Nome completo**
- Campo obrigatório: **Telefone** (WhatsApp)
- Exibir resumo da solicitação: procedimento, data, horário

### 7. Confirmar Solicitação
- Cliente clica em "Solicitar Agendamento"
- Chamar `tools/create_pending_appointment.py`:
  - Buscar ou criar cliente pelo telefone na conta da profissional
  - Criar agendamento com status `pending`
  - `booked_via = 'public_page'`
- Exibir mensagem de sucesso: "Solicitação enviada! A profissional irá confirmar em breve. Entre em contato pelo WhatsApp para mais informações."

## Saídas Esperadas
- Agendamento criado em `appointments` com status `pending`
- Cliente criado em `clients` se for primeira vez (identificado pelo telefone)
- Profissional vê nova solicitação pendente no seu dashboard

## Casos Extremos
- **Telefone já cadastrado como cliente:** usar cliente existente (não duplicar)
- **Horário ficou ocupado entre seleção e confirmação (race condition):** `create_pending_appointment.py` verifica conflito atomicamente — retornar erro "Este horário acabou de ser reservado. Por favor, escolha outro."
- **Slug de profissional com conta inativa/trial expirado:** não exibir página pública (retornar 404 ou mensagem de indisponibilidade)
- **Cliente tenta agendar múltiplos pendentes:** permitir no MVP (profissional revisa)

## Notas
- A página pública não exige login do cliente — apenas nome e telefone
- Não há confirmação automática por WhatsApp no MVP — comunicação é manual
- A URL pública é estável e pode ser usada no link da bio do Instagram da profissional
- No MVP, a página não exibe foto ou branding personalizado da profissional além do nome
