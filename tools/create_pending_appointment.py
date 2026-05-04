"""
Cria agendamento pendente via página pública (busca ou cria cliente pelo telefone).

Uso:
    python tools/create_pending_appointment.py \
        --slug maria-depil \
        --procedure_id <uuid> \
        --scheduled_at "2026-05-10T09:00:00" \
        --client_name "Ana Silva" \
        --client_phone "11999998888"
"""

import argparse
import json
import sys
from datetime import datetime, timedelta, timezone

from supabase_client import get_admin_client


def normalize_phone(phone: str) -> str:
    digits = "".join(c for c in phone if c.isdigit())
    if len(digits) == 11 and not digits.startswith("55"):
        digits = "55" + digits
    return "+" + digits


def create_pending_appointment(slug: str, procedure_id: str, scheduled_at_str: str, client_name: str, client_phone: str) -> dict:
    scheduled_at = datetime.fromisoformat(scheduled_at_str)
    if scheduled_at.date() < datetime.now(timezone.utc).date():
        return {"error": "data_passada"}

    sb = get_admin_client()
    prof = sb.table("professionals").select("id").eq("slug", slug).maybe_single().execute()
    if not prof.data:
        return {"error": "profissional_nao_encontrada"}

    user_id = prof.data["id"]
    proc = sb.table("procedures").select("duration_minutes").eq("id", procedure_id).eq("user_id", user_id).eq("is_active", True).maybe_single().execute()
    if not proc.data:
        return {"error": "procedimento_nao_encontrado"}

    ends_at = scheduled_at + timedelta(minutes=proc.data["duration_minutes"])

    # Verificar conflito
    conflict = sb.table("appointments").select("id", count="exact").eq("user_id", user_id).not_.in_("status", ["cancelled", "no_show"]).lt("scheduled_at", ends_at.isoformat()).gt("ends_at", scheduled_at.isoformat()).execute()
    if conflict.count and conflict.count > 0:
        return {"error": "conflito_horario", "message": "Este horário não está mais disponível."}

    phone = normalize_phone(client_phone)
    existing = sb.table("clients").select("id").eq("user_id", user_id).eq("phone", phone).maybe_single().execute()
    if existing.data:
        client_id = existing.data["id"]
        client_created = False
    else:
        new_client = sb.table("clients").insert({"user_id": user_id, "name": client_name.strip(), "phone": phone}).execute()
        client_id = new_client.data[0]["id"]
        client_created = True

    result = sb.table("appointments").insert({"user_id": user_id, "client_id": client_id, "procedure_id": procedure_id, "scheduled_at": scheduled_at.isoformat(), "ends_at": ends_at.isoformat(), "status": "pending", "booked_via": "public_page"}).execute()

    return {"appointment_id": result.data[0]["id"], "client_id": client_id, "client_created": client_created, "status": "pending"}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Cria agendamento pendente via página pública")
    parser.add_argument("--slug", required=True)
    parser.add_argument("--procedure_id", required=True)
    parser.add_argument("--scheduled_at", required=True)
    parser.add_argument("--client_name", required=True)
    parser.add_argument("--client_phone", required=True)
    args = parser.parse_args()
    result = create_pending_appointment(args.slug, args.procedure_id, args.scheduled_at, args.client_name, args.client_phone)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    if "error" in result:
        sys.exit(1)
