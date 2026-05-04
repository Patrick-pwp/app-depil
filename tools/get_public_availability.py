"""
Disponibilidade pública via slug (sem autenticação).

Uso:
    python tools/get_public_availability.py --slug maria-depil --procedure_id <uuid> --date 2026-05-10
"""

import argparse
import json
import sys
from datetime import date, datetime, time, timedelta

from supabase_client import get_admin_client

SLOT_INTERVAL_MINUTES = 30
WORK_START = time(8, 0)
WORK_END   = time(20, 0)


def get_public_availability(slug: str, procedure_id: str, date_str: str) -> dict:
    date_val = date.fromisoformat(date_str)
    if date_val < date.today():
        return {"available_slots": [], "date": date_str, "error": "data_passada"}

    sb = get_admin_client()
    prof = sb.table("professionals").select("id").eq("slug", slug).maybe_single().execute()
    if not prof.data:
        return {"available_slots": [], "date": date_str, "error": "profissional_nao_encontrada"}

    user_id = prof.data["id"]
    proc = sb.table("procedures").select("name,duration_minutes").eq("id", procedure_id).eq("user_id", user_id).eq("is_active", True).maybe_single().execute()
    if not proc.data:
        return {"available_slots": [], "date": date_str, "error": "procedimento_nao_encontrado"}

    duration = proc.data["duration_minutes"]
    day_start = datetime.combine(date_val, time(0, 0)).isoformat()
    day_end   = datetime.combine(date_val, time(23, 59)).isoformat()
    busy_res  = sb.table("appointments").select("scheduled_at,ends_at").eq("user_id", user_id).gte("scheduled_at", day_start).lte("ends_at", day_end).not_.in_("status", ["cancelled", "no_show"]).execute()
    busy = [(datetime.fromisoformat(r["scheduled_at"]), datetime.fromisoformat(r["ends_at"])) for r in busy_res.data]

    slots = []
    current = datetime.combine(date_val, WORK_START)
    end_boundary = datetime.combine(date_val, WORK_END)
    while current + timedelta(minutes=duration) <= end_boundary:
        slot_end = current + timedelta(minutes=duration)
        if not any(current < b_end and slot_end > b_start for b_start, b_end in busy):
            slots.append(current.strftime("%H:%M"))
        current += timedelta(minutes=SLOT_INTERVAL_MINUTES)

    return {"available_slots": slots, "date": date_str, "procedure_name": proc.data["name"], "duration_minutes": duration}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Disponibilidade pública por slug")
    parser.add_argument("--slug", required=True)
    parser.add_argument("--procedure_id", required=True)
    parser.add_argument("--date", required=True)
    args = parser.parse_args()
    result = get_public_availability(args.slug, args.procedure_id, args.date)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    if "error" in result:
        sys.exit(1)
