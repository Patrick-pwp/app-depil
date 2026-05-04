"""
Atualiza o status de um agendamento.
Se novo status = 'completed', o trigger PostgreSQL gera financial_entry automaticamente.

Uso:
    python tools/update_appointment_status.py \
        --appointment_id <uuid> \
        --user_id <uuid> \
        --new_status completed

Saída (stdout JSON):
    {"appointment_id": "<uuid>", "old_status": "scheduled", "new_status": "completed"}

Exit code 1 se transição inválida ou agendamento não encontrado.
"""

import argparse
import json
import sys

from supabase_client import get_admin_client

VALID_TRANSITIONS = {
    "pending":   {"scheduled", "cancelled"},
    "scheduled": {"completed", "cancelled", "no_show"},
}
IMMUTABLE_STATUSES = {"completed", "cancelled", "no_show"}


def update_status(appointment_id: str, user_id: str, new_status: str) -> dict:
    sb = get_admin_client()

    appt = sb.table("appointments").select("status").eq("id", appointment_id).eq("user_id", user_id).maybe_single().execute()
    if not appt.data:
        return {"error": "agendamento_nao_encontrado"}

    old_status = appt.data["status"]

    if old_status in IMMUTABLE_STATUSES:
        return {"error": "status_imutavel", "message": f"Agendamento com status '{old_status}' não pode ser alterado."}

    allowed = VALID_TRANSITIONS.get(old_status, set())
    if new_status not in allowed:
        return {"error": "transicao_invalida", "message": f"Transição '{old_status}' → '{new_status}' não é permitida."}

    sb.table("appointments").update({"status": new_status}).eq("id", appointment_id).execute()

    return {
        "appointment_id": appointment_id,
        "old_status": old_status,
        "new_status": new_status,
        "financial_entry_created": new_status == "completed",
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Atualiza status de agendamento")
    parser.add_argument("--appointment_id", required=True)
    parser.add_argument("--user_id", required=True)
    parser.add_argument("--new_status", required=True, choices=["scheduled", "completed", "cancelled", "no_show"])
    args = parser.parse_args()

    result = update_status(args.appointment_id, args.user_id, args.new_status)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    if "error" in result:
        sys.exit(1)
