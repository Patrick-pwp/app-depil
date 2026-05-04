"""
Consolida o DRE (Demonstrativo de Resultado) de um mês completo.

Uso:
    python tools/get_monthly_dre.py --user_id <uuid> --year 2026 --month 5

Saída (stdout JSON):
    {
      "period": "2026-05",
      "totals": {
        "count": 47,
        "revenue": 4230.00,
        "cost": 846.00,
        "profit": 3384.00,
        "margin_pct": 80.0
      },
      "by_procedure": [
        {
          "procedure_name": "Perna inteira",
          "count": 18,
          "revenue": 1800.00,
          "cost": 360.00,
          "profit": 1440.00
        }
      ]
    }
"""

import argparse
import json
import os
from calendar import monthrange
from datetime import date

import asyncpg
from dotenv import load_dotenv

load_dotenv()


async def get_monthly_dre(user_id: str, year: int, month: int) -> dict:
    first_day = date(year, month, 1)
    last_day = date(year, month, monthrange(year, month)[1])
    period = f"{year}-{month:02d}"

    conn = await asyncpg.connect(os.environ["DATABASE_URL"])
    try:
        totals_row = await conn.fetchrow(
            """
            SELECT
                COUNT(*)        AS count,
                SUM(revenue)    AS revenue,
                SUM(cost)       AS cost,
                SUM(profit)     AS profit
            FROM financial_entries
            WHERE user_id = $1
              AND entry_date BETWEEN $2 AND $3
            """,
            user_id, first_day, last_day,
        )

        by_procedure_rows = await conn.fetch(
            """
            SELECT
                procedure_name,
                COUNT(*)        AS count,
                SUM(revenue)    AS revenue,
                SUM(cost)       AS cost,
                SUM(profit)     AS profit
            FROM financial_entries
            WHERE user_id = $1
              AND entry_date BETWEEN $2 AND $3
            GROUP BY procedure_name
            ORDER BY SUM(revenue) DESC
            """,
            user_id, first_day, last_day,
        )

        total_revenue = float(totals_row["revenue"] or 0)
        total_cost = float(totals_row["cost"] or 0)
        total_profit = float(totals_row["profit"] or 0)
        count = int(totals_row["count"] or 0)
        margin = round((total_profit / total_revenue * 100), 1) if total_revenue > 0 else 0.0

        by_procedure = [
            {
                "procedure_name": r["procedure_name"],
                "count": int(r["count"]),
                "revenue": round(float(r["revenue"]), 2),
                "cost": round(float(r["cost"]), 2),
                "profit": round(float(r["profit"]), 2),
            }
            for r in by_procedure_rows
        ]

        return {
            "period": period,
            "totals": {
                "count": count,
                "revenue": round(total_revenue, 2),
                "cost": round(total_cost, 2),
                "profit": round(total_profit, 2),
                "margin_pct": margin,
            },
            "by_procedure": by_procedure,
        }
    finally:
        await conn.close()


if __name__ == "__main__":
    import asyncio

    parser = argparse.ArgumentParser(description="DRE mensal")
    parser.add_argument("--user_id", required=True)
    parser.add_argument("--year", required=True, type=int)
    parser.add_argument("--month", required=True, type=int)
    args = parser.parse_args()

    result = asyncio.run(get_monthly_dre(args.user_id, args.year, args.month))
    print(json.dumps(result, ensure_ascii=False, indent=2))
