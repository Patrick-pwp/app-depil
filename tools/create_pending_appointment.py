"""
Cria um agendamento com status 'pending' via página pública.
Busca ou cria o cliente pelo telefone (sem duplicar).

Uso:
    python tools/create_pending_appointment.py \
        --slug maria-depil \
        --procedure_id <uuid> \
        --scheduled_at "2026-05-10T09:00:00" \
        --client_name "Ana Silva" \
        --client_phone "11999998888"

Saída (stdout JSON):
    {
      "appointment_id": "<uuid>",
      "client_id": "<uuid>",
      "client_created": true,
      "status": "pending"
    }

Exit code 1 em caso de conflito, data passada ou profissional não encontrada.
"""

import argparse
import json
import os
import sys
from datetime import datetime, timedelta, timezone

import asyncpg
from dotenv import load_dotenv

load_dotenv()


def normalize_phone(phone: str) -> str:
    digits = "".join(c for c in phone if c.isdigit())
    if len(digits) == 11 and not digits.startswith("55"):
        digits = "55" + digits
    return "+" + digits


async def create_pending_appointment(
    slug: str,
    procedure_id: str,
    scheduled_at_str: str,
    client_name: str,
    client_phone: str,
) -> dict:
    scheduled_at = datetime.fromisoformat(scheduled_at_str)

    if scheduled_at.date() < datetime.now(timezone.utc).date():
        return {"error": "data_passada", "message": "Não é possível solicitar agendamento em datas passadas."}

    phone_normalized = normalize_phone(client_phone)

    conn = await asyncpg.connect(os.environ["DATABASE_URL"])
    try:
        professional = await conn.fetchrow(
            "SELECT id FROM professionals WHERE slug = $1",
            slug,
        )
        if not professional:
            return {"error": "profissional_nao_encontrada"}

        user_id = str(professional["id"])

        procedure = await conn.fetchrow(
            "SELECT duration_minutes FROM procedures WHERE id = $1 AND user_id = $2 AND is_active = true",
            procedure_id, user_id,
        )
        if not procedure:
            return {"error": "procedimento_nao_encontrado"}

        ends_at = scheduled_at + timedelta(minutes=procedure["duration_minutes"])

        async with conn.transaction():
            # Verificar conflito antes de criar
            conflict = await conn.fetchval(
                """
                SELECT COUNT(*) FROM appointments
                WHERE user_id = $1
                  AND status NOT IN ('cancelled', 'no_show')
                  AND scheduled_at < $2
                  AND ends_at > $3
                """,
                user_id, ends_at, scheduled_at,
            )
            if conflict > 0:
                return {"error": "conflito_horario", "message": "Este horário não está mais disponível."}

            # Buscar ou criar cliente pelo telefone
            client = await conn.fetchrow(
                "SELECT id FROM clients WHERE user_id = $1 AND phone = $2",
                user_id, phone_normalized,
            )
            client_created = False
            if client:
                client_id = str(client["id"])
            else:
                client_id = str(await conn.fetchval(
                    "INSERT INTO clients (user_id, name, phone) VALUES ($1, $2, $3) RETURNING id",
                    user_id, client_name.strip(), phone_normalized,
                ))
                client_created = True

            appointment_id = str(await conn.fetchval(
                """
                INSERT INTO appointments
                    (user_id, client_id, procedure_id, scheduled_at, ends_at, status, booked_via)
                VALUES ($1, $2, $3, $4, $5, 'pending', 'public_page')
                RETURNING id
                """,
                user_id, client_id, procedure_id, scheduled_at, ends_at,
            ))

        return {
            "appointment_id": appointment_id,
            "client_id": client_id,
            "client_created": client_created,
            "status": "pending",
        }
    finally:
        await conn.close()


if __name__ == "__main__":
    import asyncio

    parser = argparse.ArgumentParser(description="Cria agendamento pendente via página pública")
    parser.add_argument("--slug", required=True)
    parser.add_argument("--procedure_id", required=True)
    parser.add_argument("--scheduled_at", required=True, help="ISO 8601: 2026-05-10T09:00:00")
    parser.add_argument("--client_name", required=True)
    parser.add_argument("--client_phone", required=True, help="Telefone com ou sem DDD/DDI")
    args = parser.parse_args()

    result = asyncio.run(create_pending_appointment(
        args.slug, args.procedure_id, args.scheduled_at,
        args.client_name, args.client_phone,
    ))
    print(json.dumps(result, ensure_ascii=False, indent=2))
    if "error" in result:
        sys.exit(1)
