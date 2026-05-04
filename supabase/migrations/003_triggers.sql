-- =============================================================
-- App Depil — Triggers
-- =============================================================

-- =============================================================
-- TRIGGER: Gerar lançamento financeiro ao marcar Realizado
--
-- Quando appointments.status muda para 'completed', insere
-- automaticamente em financial_entries com dados desnormalizados.
-- Executa como SECURITY DEFINER para bypassar RLS.
-- =============================================================

CREATE OR REPLACE FUNCTION fn_create_financial_entry()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_client_name   text;
    v_procedure_name text;
    v_revenue       numeric(10,2);
    v_cost          numeric(10,2);
    v_profit        numeric(10,2);
BEGIN
    -- Só age quando o status muda PARA 'completed'
    IF NEW.status = 'completed' AND (OLD.status IS DISTINCT FROM 'completed') THEN

        -- Buscar nome do cliente
        SELECT name INTO v_client_name
        FROM clients WHERE id = NEW.client_id;

        -- Buscar dados do procedimento (valores no momento do agendamento via snapshot)
        SELECT name, revenue, cost, profit
        INTO v_procedure_name, v_revenue, v_cost, v_profit
        FROM procedures WHERE id = NEW.procedure_id;

        -- Inserir lançamento financeiro (ON CONFLICT para idempotência)
        INSERT INTO financial_entries (
            user_id,
            appointment_id,
            entry_date,
            client_name,
            procedure_name,
            revenue,
            cost,
            profit
        ) VALUES (
            NEW.user_id,
            NEW.id,
            NEW.scheduled_at::date,
            COALESCE(v_client_name, 'Cliente removido'),
            COALESCE(v_procedure_name, 'Procedimento removido'),
            COALESCE(v_revenue, 0),
            COALESCE(v_cost, 0),
            COALESCE(v_profit, 0)
        )
        ON CONFLICT (appointment_id) DO NOTHING;

    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_appointment_completed
    AFTER UPDATE OF status ON appointments
    FOR EACH ROW
    EXECUTE FUNCTION fn_create_financial_entry();

-- =============================================================
-- TRIGGER: Criar perfil de profissional após cadastro no Auth
--
-- Quando um novo usuário se cadastra via Supabase Auth,
-- insere automaticamente em professionals com dados básicos.
-- =============================================================

CREATE OR REPLACE FUNCTION fn_handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_slug text;
    v_base_slug text;
    v_counter integer := 0;
BEGIN
    -- Gerar slug base a partir do e-mail (parte antes do @)
    v_base_slug := LOWER(
        REGEXP_REPLACE(
            SPLIT_PART(NEW.email, '@', 1),
            '[^a-z0-9]', '-', 'g'
        )
    );
    v_slug := v_base_slug;

    -- Garantir unicidade do slug
    WHILE EXISTS (SELECT 1 FROM professionals WHERE slug = v_slug) LOOP
        v_counter := v_counter + 1;
        v_slug := v_base_slug || '-' || v_counter;
    END LOOP;

    INSERT INTO professionals (id, name, email, slug)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'name', SPLIT_PART(NEW.email, '@', 1)),
        NEW.email,
        v_slug
    )
    ON CONFLICT (id) DO NOTHING;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION fn_handle_new_user();

-- =============================================================
-- FUNÇÃO AUXILIAR: Verificar disponibilidade de horário
-- Usada internamente e pelos tools Python como validação extra
-- =============================================================

CREATE OR REPLACE FUNCTION fn_check_slot_available(
    p_user_id       uuid,
    p_scheduled_at  timestamptz,
    p_ends_at       timestamptz,
    p_exclude_id    uuid DEFAULT NULL  -- para edições de agendamento
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
    SELECT NOT EXISTS (
        SELECT 1
        FROM appointments
        WHERE user_id = p_user_id
          AND status NOT IN ('cancelled', 'no_show')
          AND id IS DISTINCT FROM p_exclude_id
          AND scheduled_at < p_ends_at
          AND ends_at > p_scheduled_at
    );
$$;
