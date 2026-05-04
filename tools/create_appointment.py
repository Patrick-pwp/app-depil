"""
Cria um novo agendamento com verificação de conflito.

Uso:
    python tools/create_appointment.py \
        --user_id <uuid> \
        --client_id <uuid> \
        --procedure_id <uuid> \
        --scheduled_at "2026-05-10T09:00:00" \
        --status scheduled \
        --booked_via manual
"""

import argparse
import json
import sys
from datetime import datetime, timedelta, timezone

from supabase_client import get_admin_client


def create_appointment(user_id: str, client_id: str, procedure_id: str, scheduled_at_str: str, status: str = "scheduled", booked_via: str = "manual", notes: str = "") -> dict:
    scheduled_at = datetime.fromisoformat(scheduled_at_str)
    if scheduled_at.date() < datetime.now(timezone.utc).date():
        return {"error": "data_passada", "message": "Não é permitido agendar em datas passadas."}

    sb = get_admin_client()
    proc = sb.table("procedures").select("duration_minutes").eq("id", procedure_id).eq("user_id", user_id).eq("is_active", True).maybe_single().execute()
    if not proc.data:
        return {"error": "procedimento_nao_encontrado"}

    ends_at = scheduled_at + timedelta(minutes=proc.data["duration_minutes"])

    # Verificar conflito
    conflict = sb.table("appointments").select("id", count="exact").eq("user_id", user_id).not_.in_("status", ["cancelled", "no_show"]).lt("scheduled_at", ends_at.isoformat()).gt("ends_at", scheduled_at.isoformat()).execute()
    if conflict.count and conflict.count > 0:
        return {"error": "conflito_horario", "message": "Este horário já está ocupado."}

    result = sb.table("appointments").insert({"user_id": user_id, "client_id": client_id, "procedure_id": procedure_id, "scheduled_at": scheduled_at.isoformat(), "ends_at": ends_at.isoformat(), "status": status, "booked_via": booked_via, "notes": notes}).execute()
    appt = result.data[0]
    return {"appointment_id": appt["id"], "ends_at": appt["ends_at"], "status": status}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Cria agendamento")
    parser.add_argument("--user_id", required=True)
    parser.add_argument("--client_id", required=True)
    parser.add_argument("--procedure_id", required=True)
    parser.add_argument("--scheduled_at", required=True)
    parser.add_argument("--status", default="scheduled", choices=["scheduled", "pending"])
    parser.add_argument("--booked_via", default="manual", choices=["manual", "public_page"])
    parser.add_argument("--notes", default="")
    args = parser.parse_args()
    result = create_appointment(args.user_id, args.client_id, args.procedure_id, args.scheduled_at, args.status, args.booked_via, args.notes)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    if "error" in result:
        sys.exit(1)
