-- =============================================================
-- App Depil — Schema Inicial
-- Executar no Supabase SQL Editor ou via supabase db push
-- =============================================================

-- Extensões necessárias
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";  -- busca full-text eficiente

-- =============================================================
-- PROFESSIONALS
-- Mapeado 1:1 com auth.users do Supabase Auth
-- =============================================================
CREATE TABLE professionals (
    id          uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    name        text NOT NULL,
    email       text NOT NULL,
    slug        text NOT NULL UNIQUE,
    created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_professionals_slug ON professionals(slug);

-- =============================================================
-- CLIENTS
-- Clientes de cada profissional (não são usuários do sistema)
-- =============================================================
CREATE TABLE clients (
    id          uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     uuid NOT NULL REFERENCES professionals(id) ON DELETE CASCADE,
    name        text NOT NULL,
    phone       text NOT NULL,
    notes       text,
    created_at  timestamptz NOT NULL DEFAULT now(),

    UNIQUE (user_id, phone)
);

CREATE INDEX idx_clients_user_id    ON clients(user_id);
CREATE INDEX idx_clients_name_trgm  ON clients USING gin(name gin_trgm_ops);
CREATE INDEX idx_clients_phone      ON clients(user_id, phone);

-- =============================================================
-- PROCEDURES
-- Catálogo de serviços de cada profissional
-- =============================================================
CREATE TABLE procedures (
    id               uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id          uuid NOT NULL REFERENCES professionals(id) ON DELETE CASCADE,
    name             text NOT NULL,
    revenue          numeric(10,2) NOT NULL CHECK (revenue >= 0),
    cost             numeric(10,2) NOT NULL CHECK (cost >= 0),
    profit           numeric(10,2) GENERATED ALWAYS AS (revenue - cost) STORED,
    duration_minutes integer NOT NULL CHECK (duration_minutes > 0),
    is_active        boolean NOT NULL DEFAULT true,
    created_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_procedures_user_id ON procedures(user_id);

-- =============================================================
-- APPOINTMENTS
-- Agenda central de atendimentos
-- =============================================================
CREATE TYPE appointment_status AS ENUM (
    'pending',
    'scheduled',
    'completed',
    'cancelled',
    'no_show'
);

CREATE TYPE booking_source AS ENUM ('manual', 'public_page');

CREATE TABLE appointments (
    id              uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         uuid NOT NULL REFERENCES professionals(id) ON DELETE CASCADE,
    client_id       uuid NOT NULL REFERENCES clients(id) ON DELETE RESTRICT,
    procedure_id    uuid NOT NULL REFERENCES procedures(id) ON DELETE RESTRICT,
    scheduled_at    timestamptz NOT NULL,
    ends_at         timestamptz NOT NULL,
    status          appointment_status NOT NULL DEFAULT 'scheduled',
    is_paid         boolean NOT NULL DEFAULT false,
    booked_via      booking_source NOT NULL DEFAULT 'manual',
    notes           text,
    created_at      timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT chk_appointment_times CHECK (ends_at > scheduled_at)
);

CREATE INDEX idx_appointments_user_id       ON appointments(user_id);
CREATE INDEX idx_appointments_scheduled_at  ON appointments(user_id, scheduled_at);
CREATE INDEX idx_appointments_client_id     ON appointments(client_id);
CREATE INDEX idx_appointments_status        ON appointments(user_id, status);

-- =============================================================
-- FINANCIAL_ENTRIES
-- Lançamentos gerados automaticamente ao marcar status = completed
-- =============================================================
CREATE TABLE financial_entries (
    id              uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id         uuid NOT NULL REFERENCES professionals(id) ON DELETE CASCADE,
    appointment_id  uuid NOT NULL UNIQUE REFERENCES appointments(id) ON DELETE RESTRICT,
    entry_date      date NOT NULL,
    client_name     text NOT NULL,     -- desnormalizado para preservar histórico
    procedure_name  text NOT NULL,     -- desnormalizado para preservar histórico
    revenue         numeric(10,2) NOT NULL,
    cost            numeric(10,2) NOT NULL,
    profit          numeric(10,2) NOT NULL,
    created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_financial_entries_user_date ON financial_entries(user_id, entry_date);
CREATE INDEX idx_financial_entries_user_id   ON financial_entries(user_id);
