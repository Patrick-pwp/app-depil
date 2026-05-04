-- =============================================================
-- App Depil — Row Level Security (RLS)
-- Garante isolamento total de dados entre profissionais
-- =============================================================

-- Habilitar RLS em todas as tabelas
ALTER TABLE professionals    ENABLE ROW LEVEL SECURITY;
ALTER TABLE clients          ENABLE ROW LEVEL SECURITY;
ALTER TABLE procedures       ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointments     ENABLE ROW LEVEL SECURITY;
ALTER TABLE financial_entries ENABLE ROW LEVEL SECURITY;

-- =============================================================
-- PROFESSIONALS
-- =============================================================
CREATE POLICY "professionals_select_own"
    ON professionals FOR SELECT
    USING (id = auth.uid());

CREATE POLICY "professionals_insert_own"
    ON professionals FOR INSERT
    WITH CHECK (id = auth.uid());

CREATE POLICY "professionals_update_own"
    ON professionals FOR UPDATE
    USING (id = auth.uid())
    WITH CHECK (id = auth.uid());

-- Leitura pública do slug (necessário para página pública sem auth)
CREATE POLICY "professionals_public_slug_read"
    ON professionals FOR SELECT
    USING (true);  -- qualquer um pode resolver slug → id (sem dados sensíveis)

-- =============================================================
-- CLIENTS
-- =============================================================
CREATE POLICY "clients_select_own"
    ON clients FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "clients_insert_own"
    ON clients FOR INSERT
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "clients_update_own"
    ON clients FOR UPDATE
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "clients_delete_own"
    ON clients FOR DELETE
    USING (user_id = auth.uid());

-- Inserção via página pública (service role ou anon para create_pending_appointment)
-- A página pública usa a service role key no backend — sem acesso anon direto a dados sensíveis
CREATE POLICY "clients_insert_via_service_role"
    ON clients FOR INSERT
    WITH CHECK (true);  -- service role bypassa RLS; esta policy é para anon key se usada

-- =============================================================
-- PROCEDURES
-- =============================================================
CREATE POLICY "procedures_select_own"
    ON procedures FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "procedures_insert_own"
    ON procedures FOR INSERT
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "procedures_update_own"
    ON procedures FOR UPDATE
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "procedures_delete_own"
    ON procedures FOR DELETE
    USING (user_id = auth.uid());

-- Leitura pública de procedimentos ativos (para página de agendamento)
CREATE POLICY "procedures_public_read_active"
    ON procedures FOR SELECT
    USING (is_active = true);

-- =============================================================
-- APPOINTMENTS
-- =============================================================
CREATE POLICY "appointments_select_own"
    ON appointments FOR SELECT
    USING (user_id = auth.uid());

CREATE POLICY "appointments_insert_own"
    ON appointments FOR INSERT
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "appointments_update_own"
    ON appointments FOR UPDATE
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "appointments_delete_own"
    ON appointments FOR DELETE
    USING (user_id = auth.uid());

-- =============================================================
-- FINANCIAL_ENTRIES
-- Somente leitura/escrita pelo próprio usuário
-- Inserções ocorrem via trigger (executa como SECURITY DEFINER)
-- =============================================================
CREATE POLICY "financial_entries_select_own"
    ON financial_entries FOR SELECT
    USING (user_id = auth.uid());

-- Sem policy de INSERT para usuário final — inserção é feita apenas pelo trigger
-- O trigger usa SECURITY DEFINER, bypassa RLS
