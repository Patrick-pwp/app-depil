"""
Consolida o DRE de um mês completo.

Uso:
    python tools/get_monthly_dre.py --user_id <uuid> --year 2026 --month 5
"""

import argparse
import json
from calendar import monthrange

from supabase_client import get_admin_client


def get_monthly_dre(user_id: str, year: int, month: int) -> dict:
    from datetime import date
    first_day = date(year, month, 1).isoformat()
    last_day = date(year, month, monthrange(year, month)[1]).isoformat()
    period = f"{year}-{month:02d}"

    sb = get_admin_client()
    rows = sb.table("financial_entries").select("revenue,cost,profit,procedure_name").eq("user_id", user_id).gte("entry_date", first_day).lte("entry_date", last_day).execute()

    total_revenue = total_cost = total_profit = 0.0
    by_procedure: dict = {}

    for r in rows.data:
        rev = float(r["revenue"])
        cost = float(r["cost"])
        profit = float(r["profit"])
        name = r["procedure_name"]
        total_revenue += rev
        total_cost += cost
        total_profit += profit
        if name not in by_procedure:
            by_procedure[name] = {"count": 0, "revenue": 0.0, "cost": 0.0, "profit": 0.0}
        by_procedure[name]["count"] += 1
        by_procedure[name]["revenue"] += rev
        by_procedure[name]["cost"] += cost
        by_procedure[name]["profit"] += profit

    margin = round(total_profit / total_revenue * 100, 1) if total_revenue > 0 else 0.0
    sorted_procs = sorted(by_procedure.items(), key=lambda x: x[1]["revenue"], reverse=True)

    return {
        "period": period,
        "totals": {"count": len(rows.data), "revenue": round(total_revenue, 2), "cost": round(total_cost, 2), "profit": round(total_profit, 2), "margin_pct": margin},
        "by_procedure": [{"procedure_name": k, **{kk: round(vv, 2) if isinstance(vv, float) else vv for kk, vv in v.items()}} for k, v in sorted_procs],
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="DRE mensal")
    parser.add_argument("--user_id", required=True)
    parser.add_argument("--year", required=True, type=int)
    parser.add_argument("--month", required=True, type=int)
    args = parser.parse_args()
    print(json.dumps(get_monthly_dre(args.user_id, args.year, args.month), ensure_ascii=False, indent=2))
