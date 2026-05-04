"""
Retorna horários disponíveis para a página pública de agendamento (sem autenticação).
Idêntico ao check_availability.py, mas aceita slug em vez de user_id.

Uso:
    python tools/get_public_availability.py \
        --slug maria-depil \
        --procedure_id <uuid> \
        --date 2026-05-10

Saída (stdout JSON):
    {
      "available_slots": ["09:00", "10:00", "11:30"],
      "date": "2026-05-10",
      "procedure_name": "Perna inteira",
      "duration_minutes": 60
    }
"""

import argparse
import json
import os
import sys
from datetime import date, datetime, time, timedelta

import asyncpg
from dotenv import load_dotenv

load_dotenv()

SLOT_INTERVAL_MINUTES = 30
WORK_START = time(8, 0)
WORK_END = time(20, 0)


async def get_public_availability(slug: str, procedure_id: str, date_str: str) -> dict:
    date_val = date.fromisoformat(date_str)

    if date_val < date.today():
        return {"available_slots": [], "date": date_str, "error": "data_passada"}

    conn = await asyncpg.connect(os.environ["DATABASE_URL"])
    try:
        professional = await conn.fetchrow(
            "SELECT id FROM professionals WHERE slug = $1",
            slug,
        )
        if not professional:
            return {"available_slots": [], "date": date_str, "error": "profissional_nao_encontrada"}

        user_id = str(professional["id"])

        procedure = await conn.fetchrow(
            """
            SELECT name, duration_minutes
            FROM procedures
            WHERE id = $1 AND user_id = $2 AND is_active = true
            """,
            procedure_id, user_id,
        )
        if not procedure:
            return {"available_slots": [], "date": date_str, "error": "procedimento_nao_encontrado"}

        duration = procedure["duration_minutes"]
        day_start = datetime.combine(date_val, time(0, 0))
        day_end = datetime.combine(date_val, time(23, 59))

        busy_rows = await conn.fetch(
            """
            SELECT scheduled_at, ends_at FROM appointments
            WHERE user_id = $1
              AND scheduled_at >= $2 AND ends_at <= $3
              AND status NOT IN ('cancelled', 'no_show')
            """,
            user_id, day_start, day_end,
        )
        busy = [(r["scheduled_at"], r["ends_at"]) for r in busy_rows]

        current = datetime.combine(date_val, WORK_START)
        end_boundary = datetime.combine(date_val, WORK_END)
        step = timedelta(minutes=SLOT_INTERVAL_MINUTES)
        free_slots = []
        while current + timedelta(minutes=duration) <= end_boundary:
            slot_end = current + timedelta(minutes=duration)
            conflict = any(current < b_end and slot_end > b_start for b_start, b_end in busy)
            if not conflict:
                free_slots.append(current.strftime("%H:%M"))
            current += step

        return {
            "available_slots": free_slots,
            "date": date_str,
            "procedure_name": procedure["name"],
            "duration_minutes": duration,
        }
    finally:
        await conn.close()


if __name__ == "__main__":
    import asyncio

    parser = argparse.ArgumentParser(description="Disponibilidade pública por slug")
    parser.add_argument("--slug", required=True)
    parser.add_argument("--procedure_id", required=True)
    parser.add_argument("--date", required=True, help="YYYY-MM-DD")
    args = parser.parse_args()

    result = asyncio.run(get_public_availability(args.slug, args.procedure_id, args.date))
    print(json.dumps(result, ensure_ascii=False, indent=2))
    if "error" in result:
        sys.exit(1)
