"""
Cria um novo agendamento com verificação atômica de conflito.

Uso:
    python tools/create_appointment.py \
        --user_id <uuid> \
        --client_id <uuid> \
        --procedure_id <uuid> \
        --scheduled_at "2026-05-10T09:00:00" \
        --status scheduled \
        --booked_via manual

Saída (stdout JSON):
    {"appointment_id": "<uuid>", "ends_at": "2026-05-10T10:00:00"}

Exit code 1 em caso de conflito ou data passada.
"""

import argparse
import json
import os
import sys
from datetime import datetime, timedelta, timezone

import asyncpg
from dotenv import load_dotenv

load_dotenv()


async def create_appointment(
    user_id: str,
    client_id: str,
    procedure_id: str,
    scheduled_at_str: str,
    status: str = "scheduled",
    booked_via: str = "manual",
    notes: str = "",
) -> dict:
    scheduled_at = datetime.fromisoformat(scheduled_at_str)

    if scheduled_at.date() < datetime.now(timezone.utc).date():
        return {"error": "data_passada", "message": "Não é permitido agendar em datas passadas."}

    conn = await asyncpg.connect(os.environ["DATABASE_URL"])
    try:
        procedure = await conn.fetchrow(
            "SELECT duration_minutes FROM procedures WHERE id = $1 AND user_id = $2 AND is_active = true",
            procedure_id, user_id,
        )
        if not procedure:
            return {"error": "procedimento_nao_encontrado"}

        ends_at = scheduled_at + timedelta(minutes=procedure["duration_minutes"])

        # Verificação de conflito e inserção em uma única transação
        async with conn.transaction():
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
                return {"error": "conflito_horario", "message": "Este horário já está ocupado."}

            appointment_id = await conn.fetchval(
                """
                INSERT INTO appointments
                    (user_id, client_id, procedure_id, scheduled_at, ends_at, status, booked_via, notes)
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
                RETURNING id
                """,
                user_id, client_id, procedure_id, scheduled_at, ends_at, status, booked_via, notes,
            )

        return {
            "appointment_id": str(appointment_id),
            "ends_at": ends_at.isoformat(),
            "status": status,
        }
    finally:
        await conn.close()


if __name__ == "__main__":
    import asyncio

    parser = argparse.ArgumentParser(description="Cria agendamento com verificação de conflito")
    parser.add_argument("--user_id", required=True)
    parser.add_argument("--client_id", required=True)
    parser.add_argument("--procedure_id", required=True)
    parser.add_argument("--scheduled_at", required=True, help="ISO 8601: 2026-05-10T09:00:00")
    parser.add_argument("--status", default="scheduled", choices=["scheduled", "pending"])
    parser.add_argument("--booked_via", default="manual", choices=["manual", "public_page"])
    parser.add_argument("--notes", default="")
    args = parser.parse_args()

    result = asyncio.run(create_appointment(
        args.user_id, args.client_id, args.procedure_id,
        args.scheduled_at, args.status, args.booked_via, args.notes,
    ))
    print(json.dumps(result, ensure_ascii=False, indent=2))
    if "error" in result:
        sys.exit(1)
