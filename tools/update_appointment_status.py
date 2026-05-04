"""
Atualiza o status de um agendamento.
Se novo status for 'completed', dispara inserção em financial_entries (via trigger PostgreSQL).

Uso:
    python tools/update_appointment_status.py \
        --appointment_id <uuid> \
        --user_id <uuid> \
        --new_status completed

Transições válidas:
    pending    → scheduled | cancelled
    scheduled  → completed | cancelled | no_show
    completed  → (imutável — operação negada)
    cancelled  → (imutável — operação negada)
    no_show    → (imutável — operação negada)

Saída (stdout JSON):
    {"appointment_id": "<uuid>", "old_status": "scheduled", "new_status": "completed",
     "financial_entry_id": "<uuid>"}  # financial_entry_id presente só quando completed

Exit code 1 se transição inválida.
"""

import argparse
import json
import os
import sys

import asyncpg
from dotenv import load_dotenv

load_dotenv()

VALID_TRANSITIONS = {
    "pending":   {"scheduled", "cancelled"},
    "scheduled": {"completed", "cancelled", "no_show"},
}

IMMUTABLE_STATUSES = {"completed", "cancelled", "no_show"}


async def update_status(appointment_id: str, user_id: str, new_status: str) -> dict:
    conn = await asyncpg.connect(os.environ["DATABASE_URL"])
    try:
        row = await conn.fetchrow(
            """
            SELECT a.status, a.client_id, a.procedure_id, a.scheduled_at,
                   c.name AS client_name,
                   p.name AS procedure_name, p.revenue, p.cost, p.profit
            FROM appointments a
            JOIN clients c ON c.id = a.client_id
            JOIN procedures p ON p.id = a.procedure_id
            WHERE a.id = $1 AND a.user_id = $2
            """,
            appointment_id, user_id,
        )
        if not row:
            return {"error": "agendamento_nao_encontrado"}

        old_status = row["status"]

        if old_status in IMMUTABLE_STATUSES:
            return {
                "error": "status_imutavel",
                "message": f"Agendamento com status '{old_status}' não pode ser alterado.",
            }

        allowed = VALID_TRANSITIONS.get(old_status, set())
        if new_status not in allowed:
            return {
                "error": "transicao_invalida",
                "message": f"Transição '{old_status}' → '{new_status}' não é permitida.",
            }

        result = {"appointment_id": appointment_id, "old_status": old_status, "new_status": new_status}

        async with conn.transaction():
            await conn.execute(
                "UPDATE appointments SET status = $1 WHERE id = $2",
                new_status, appointment_id,
            )

            if new_status == "completed":
                # O trigger no PostgreSQL pode fazer isso automaticamente.
                # Este código serve como fallback caso o trigger não esteja configurado.
                entry_id = await conn.fetchval(
                    """
                    INSERT INTO financial_entries
                        (user_id, appointment_id, entry_date, client_name, procedure_name,
                         revenue, cost, profit)
                    VALUES ($1, $2, $3::date, $4, $5, $6, $7, $8)
                    ON CONFLICT (appointment_id) DO NOTHING
                    RETURNING id
                    """,
                    user_id,
                    appointment_id,
                    row["scheduled_at"].date(),
                    row["client_name"],
                    row["procedure_name"],
                    float(row["revenue"]),
                    float(row["cost"]),
                    float(row["profit"]),
                )
                if entry_id:
                    result["financial_entry_id"] = str(entry_id)

        return result
    finally:
        await conn.close()


if __name__ == "__main__":
    import asyncio

    parser = argparse.ArgumentParser(description="Atualiza status de agendamento")
    parser.add_argument("--appointment_id", required=True)
    parser.add_argument("--user_id", required=True)
    parser.add_argument("--new_status", required=True,
                        choices=["scheduled", "completed", "cancelled", "no_show"])
    args = parser.parse_args()

    result = asyncio.run(update_status(args.appointment_id, args.user_id, args.new_status))
    print(json.dumps(result, ensure_ascii=False, indent=2))
    if "error" in result:
        sys.exit(1)
