"""
Retorna os lançamentos financeiros e totais de um dia específico.

Uso:
    python tools/get_daily_cashflow.py --user_id <uuid> --date 2026-05-10
"""

import argparse
import json

from supabase_client import get_admin_client


def get_daily_cashflow(user_id: str, date_str: str) -> dict:
    sb = get_admin_client()

    rows = sb.table("financial_entries").select("*, appointments(scheduled_at, is_paid)").eq("user_id", user_id).eq("entry_date", date_str).order("created_at").execute()

    entries = []
    total_revenue = total_cost = total_profit = 0.0

    for r in rows.data:
        revenue = float(r["revenue"])
        cost = float(r["cost"])
        profit = float(r["profit"])
        total_revenue += revenue
        total_cost += cost
        total_profit += profit
        appt = r.get("appointments") or {}
        entries.append({
            "id": r["id"],
            "appointment_id": r["appointment_id"],
            "time": appt.get("scheduled_at", "")[:16].replace("T", " ").split(" ")[1] if appt.get("scheduled_at") else "",
            "client_name": r["client_name"],
            "procedure_name": r["procedure_name"],
            "revenue": revenue,
            "cost": cost,
            "profit": profit,
            "is_paid": appt.get("is_paid", False),
        })

    return {
        "date": date_str,
        "totals": {"revenue": round(total_revenue, 2), "cost": round(total_cost, 2), "profit": round(total_profit, 2), "count": len(entries)},
        "entries": entries,
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Caixa do dia")
    parser.add_argument("--user_id", required=True)
    parser.add_argument("--date", required=True, help="YYYY-MM-DD")
    args = parser.parse_args()
    print(json.dumps(get_daily_cashflow(args.user_id, args.date), ensure_ascii=False, indent=2))
