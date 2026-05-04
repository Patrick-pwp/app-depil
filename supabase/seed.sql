-- =============================================================
-- App Depil — Seed de Desenvolvimento
-- Dados de teste para validar o schema localmente.
-- NÃO executar em produção.
-- =============================================================

-- ATENÇÃO: substitua o UUID abaixo pelo id real de um usuário
-- criado via Supabase Auth no painel de desenvolvimento.
DO $$
DECLARE
    v_user_id uuid := '00000000-0000-0000-0000-000000000001';  -- substituir pelo auth.users.id real
    v_client1 uuid := uuid_generate_v4();
    v_client2 uuid := uuid_generate_v4();
    v_proc1   uuid := uuid_generate_v4();
    v_proc2   uuid := uuid_generate_v4();
    v_proc3   uuid := uuid_generate_v4();
    v_appt1   uuid := uuid_generate_v4();
    v_appt2   uuid := uuid_generate_v4();
BEGIN
    -- Profissional
    INSERT INTO professionals (id, name, email, slug) VALUES
    (v_user_id, 'Maria Silva', 'maria@teste.com', 'maria-depil')
    ON CONFLICT DO NOTHING;

    -- Clientes
    INSERT INTO clients (id, user_id, name, phone) VALUES
    (v_client1, v_user_id, 'Ana Lima',    '+5511999990001'),
    (v_client2, v_user_id, 'Bruna Costa', '+5511999990002')
    ON CONFLICT DO NOTHING;

    -- Procedimentos
    INSERT INTO procedures (id, user_id, name, revenue, cost, duration_minutes) VALUES
    (v_proc1, v_user_id, 'Perna inteira',  100.00, 15.00, 60),
    (v_proc2, v_user_id, 'Virilha',         75.00, 10.00, 30),
    (v_proc3, v_user_id, 'Axilas',          50.00,  8.00, 20)
    ON CONFLICT DO NOTHING;

    -- Agendamentos (status completed → trigger gera financial_entries)
    INSERT INTO appointments
        (id, user_id, client_id, procedure_id, scheduled_at, ends_at, status, is_paid, booked_via)
    VALUES
    (v_appt1, v_user_id, v_client1, v_proc1,
     now() - interval '2 days', now() - interval '2 days' + interval '60 min',
     'completed', true, 'manual'),
    (v_appt2, v_user_id, v_client2, v_proc2,
     now() - interval '1 day', now() - interval '1 day' + interval '30 min',
     'scheduled', false, 'manual')
    ON CONFLICT DO NOTHING;

END $$;
