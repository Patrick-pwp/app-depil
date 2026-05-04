# Workflow: Onboarding da Profissional

## Objetivo
Guiar uma nova profissional pelo setup inicial da conta até que ela esteja pronta para receber o primeiro agendamento.

## Entradas Necessárias
- E-mail e senha escolhidos pela usuária
- Nome completo da profissional
- Slug desejado para a página pública (ex: `maria-depil`)

## Passos

### 1. Criação de Conta
- Usuária se cadastra com e-mail e senha via Supabase Auth
- Sistema verifica se e-mail já existe (retorna erro amigável se sim)
- Após cadastro, envia e-mail de confirmação via Resend

### 2. Configuração do Perfil
- Salvar nome completo na tabela `professionals`
- Definir `slug` único para URL pública: `appdepil.com.br/[slug]`
- Verificar unicidade do slug antes de salvar (sugerir alternativa se ocupado)

### 3. Cadastro de Procedimentos (mínimo 1)
- Exibir tela de cadastro de procedimento
- Campos obrigatórios: nome, receita (R$), custo (R$), duração (minutos)
- Sistema mostra lucro calculado em tempo real: `lucro = receita - custo`
- Salvar via `tools/create_appointment.py` não — salvar direto via Supabase client no Flutter
- Repetir até usuária indicar que terminou

### 4. Verificação Final
- Mostrar resumo: nome, slug, procedimentos cadastrados
- Exibir link da página pública: `appdepil.com.br/[slug]`
- Mostrar botão "Abrir página pública" para testar

## Saídas Esperadas
- Conta criada e autenticada
- Pelo menos 1 procedimento cadastrado
- Slug configurado e página pública acessível

## Casos Extremos
- **Slug ocupado:** sugerir `[nome]-[numero]` (ex: `ana-depil-2`)
- **E-mail não confirmado:** lembrar usuária de confirmar antes de prosseguir
- **Procedimento com custo maior que receita:** avisar que lucro será negativo, mas permitir salvar

## Notas
- Não exigir dados bancários no onboarding — cobrança SaaS é pós-MVP
- Horários de trabalho não são configurados no onboarding MVP — a disponibilidade é definida implicitamente pelos agendamentos existentes
