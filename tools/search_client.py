"""
Busca clientes por nome ou telefone dentro da conta da profissional.

Uso:
    python tools/search_client.py --user_id <uuid> --query "Ana" --limit 10

Saída (stdout JSON):
    {
      "clients": [
        {
          "id": "<uuid>",
          "name": "Ana Silva",
          "phone": "+5511999998888",
          "notes": "",
          "appointment_count": 5,
          "last_appointment_at": "2026-04-20T10:00:00"
        }
      ],
      "count": 1
    }
"""

import argparse
import json
import os

import asyncpg
from dotenv import load_dotenv

load_dotenv()


async def search_client(user_id: str, query: str, limit: int = 10) -> dict:
    conn = await asyncpg.connect(os.environ["DATABASE_URL"])
    try:
        # Busca por nome (ilike) ou telefone (contém dígitos do query)
        rows = await conn.fetch(
            """
            SELECT
                c.id,
                c.name,
                c.phone,
                c.notes,
                COUNT(a.id) AS appointment_count,
                MAX(a.scheduled_at) AS last_appointment_at
            FROM clients c
            LEFT JOIN appointments a ON a.client_id = c.id AND a.status = 'completed'
            WHERE c.user_id = $1
              AND (
                  c.name ILIKE $2
                  OR c.phone LIKE $3
              )
            GROUP BY c.id, c.name, c.phone, c.notes
            ORDER BY c.name ASC
            LIMIT $4
            """,
            user_id,
            f"%{query}%",
            f"%{query}%",
            limit,
        )

        clients = [
            {
                "id": str(r["id"]),
                "name": r["name"],
                "phone": r["phone"],
                "notes": r["notes"] or "",
                "appointment_count": int(r["appointment_count"]),
                "last_appointment_at": r["last_appointment_at"].isoformat() if r["last_appointment_at"] else None,
            }
            for r in rows
        ]

        return {"clients": clients, "count": len(clients)}
    finally:
        await conn.close()


if __name__ == "__main__":
    import asyncio

    parser = argparse.ArgumentParser(description="Busca clientes por nome ou telefone")
    parser.add_argument("--user_id", required=True)
    parser.add_argument("--query", required=True, help="Nome ou telefone parcial")
    parser.add_argument("--limit", type=int, default=10)
    args = parser.parse_args()

    result = asyncio.run(search_client(args.user_id, args.query, args.limit))
    print(json.dumps(result, ensure_ascii=False, indent=2))
