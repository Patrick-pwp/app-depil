"""
Retorna slots de horário disponíveis para um procedimento em uma data específica.

Uso:
    python tools/check_availability.py --user_id <uuid> --procedure_id <uuid> --date 2026-05-10

Saída (stdout JSON):
    {"available_slots": ["09:00", "10:00", "11:30"], "date": "2026-05-10"}
"""

import argparse
import json
import os
import sys
from datetime import date, datetime, time, timedelta

import asyncpg
from dotenv import load_dotenv

load_dotenv()

SLOT_INTERVAL_MINUTES = 30  # grade de horários disponíveis
WORK_START = time(8, 0)
WORK_END = time(20, 0)


async def get_busy_intervals(conn, user_id: str, date_val: date) -> list[tuple[datetime, datetime]]:
    day_start = datetime.combine(date_val, time(0, 0))
    day_end = datetime.combine(date_val, time(23, 59))
    rows = await conn.fetch(
        """
        SELECT scheduled_at, ends_at
        FROM appointments
        WHERE user_id = $1
          AND scheduled_at >= $2
          AND ends_at <= $3
          AND status NOT IN ('cancelled', 'no_show')
        """,
        user_id, day_start, day_end,
    )
    return [(r["scheduled_at"], r["ends_at"]) for r in rows]


def generate_slots(date_val: date, duration_minutes: int) -> list[datetime]:
    slots = []
    current = datetime.combine(date_val, WORK_START)
    end_boundary = datetime.combine(date_val, WORK_END)
    step = timedelta(minutes=SLOT_INTERVAL_MINUTES)
    while current + timedelta(minutes=duration_minutes) <= end_boundary:
        slots.append(current)
        current += step
    return slots


def has_conflict(slot_start: datetime, slot_end: datetime, busy: list[tuple[datetime, datetime]]) -> bool:
    for busy_start, busy_end in busy:
        if slot_start < busy_end and slot_end > busy_start:
            return True
    return False


async def check_availability(user_id: str, procedure_id: str, date_str: str) -> dict:
    date_val = date.fromisoformat(date_str)

    if date_val < date.today():
        return {"available_slots": [], "date": date_str, "error": "data_passada"}

    conn = await asyncpg.connect(os.environ["DATABASE_URL"])
    try:
        procedure = await conn.fetchrow(
            "SELECT duration_minutes FROM procedures WHERE id = $1 AND user_id = $2 AND is_active = true",
            procedure_id, user_id,
        )
        if not procedure:
            return {"available_slots": [], "date": date_str, "error": "procedimento_nao_encontrado"}

        duration = procedure["duration_minutes"]
        busy = await get_busy_intervals(conn, user_id, date_val)
        all_slots = generate_slots(date_val, duration)
        free_slots = [
            s.strftime("%H:%M")
            for s in all_slots
            if not has_conflict(s, s + timedelta(minutes=duration), busy)
        ]
        return {"available_slots": free_slots, "date": date_str, "duration_minutes": duration}
    finally:
        await conn.close()


if __name__ == "__main__":
    import asyncio

    parser = argparse.ArgumentParser(description="Verifica disponibilidade de horários")
    parser.add_argument("--user_id", required=True)
    parser.add_argument("--procedure_id", required=True)
    parser.add_argument("--date", required=True, help="YYYY-MM-DD")
    args = parser.parse_args()

    result = asyncio.run(check_availability(args.user_id, args.procedure_id, args.date))
    print(json.dumps(result, ensure_ascii=False, indent=2))
    if "error" in result:
        sys.exit(1)
