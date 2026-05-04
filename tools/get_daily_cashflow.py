"""
Retorna os lançamentos financeiros e totais de um dia específico.

Uso:
    python tools/get_daily_cashflow.py --user_id <uuid> --date 2026-05-10

Saída (stdout JSON):
    {
      "date": "2026-05-10",
      "totals": {"revenue": 450.00, "cost": 90.00, "profit": 360.00, "count": 3},
      "entries": [
        {
          "id": "<uuid>",
          "appointment_id": "<uuid>",
          "time": "09:00",
          "client_name": "Ana Silva",
          "procedure_name": "Perna inteira",
          "revenue": 100.00,
          "cost": 20.00,
          "profit": 80.00,
          "is_paid": true
        }
      ]
    }
"""

import argparse
import json
import os
import sys
from datetime import date

import asyncpg
from dotenv import load_dotenv

load_dotenv()


async def get_daily_cashflow(user_id: str, date_str: str) -> dict:
    date_val = date.fromisoformat(date_str)

    conn = await asyncpg.connect(os.environ["DATABASE_URL"])
    try:
        rows = await conn.fetch(
            """
            SELECT
                fe.id,
                fe.appointment_id,
                a.scheduled_at,
                a.is_paid,
                fe.client_name,
                fe.procedure_name,
                fe.revenue,
                fe.cost,
                fe.profit
            FROM financial_entries fe
            JOIN appointments a ON a.id = fe.appointment_id
            WHERE fe.user_id = $1
              AND fe.entry_date = $2
            ORDER BY a.scheduled_at ASC
            """,
            user_id, date_val,
        )

        entries = []
        total_revenue = 0.0
        total_cost = 0.0
        total_profit = 0.0

        for r in rows:
            revenue = float(r["revenue"])
            cost = float(r["cost"])
            profit = float(r["profit"])
            total_revenue += revenue
            total_cost += cost
            total_profit += profit
            entries.append({
                "id": str(r["id"]),
                "appointment_id": str(r["appointment_id"]),
                "time": r["scheduled_at"].strftime("%H:%M"),
                "client_name": r["client_name"],
                "procedure_name": r["procedure_name"],
                "revenue": revenue,
                "cost": cost,
                "profit": profit,
                "is_paid": r["is_paid"],
            })

        return {
            "date": date_str,
            "totals": {
                "revenue": round(total_revenue, 2),
                "cost": round(total_cost, 2),
                "profit": round(total_profit, 2),
                "count": len(entries),
            },
            "entries": entries,
        }
    finally:
        await conn.close()


if __name__ == "__main__":
    import asyncio

    parser = argparse.ArgumentParser(description="Caixa do dia")
    parser.add_argument("--user_id", required=True)
    parser.add_argument("--date", required=True, help="YYYY-MM-DD")
    args = parser.parse_args()

    result = asyncio.run(get_daily_cashflow(args.user_id, args.date))
    print(json.dumps(result, ensure_ascii=False, indent=2))
