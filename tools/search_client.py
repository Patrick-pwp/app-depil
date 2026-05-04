"""
Busca clientes por nome ou telefone.

Uso:
    python tools/search_client.py --user_id <uuid> --query "Ana"
"""

import argparse
import json

from supabase_client import get_admin_client


def search_client(user_id: str, query: str, limit: int = 10) -> dict:
    sb = get_admin_client()
    # Supabase REST: ilike para busca case-insensitive
    by_name = sb.table("clients").select("id,name,phone,notes").eq("user_id", user_id).ilike("name", f"%{query}%").limit(limit).execute()
    by_phone = sb.table("clients").select("id,name,phone,notes").eq("user_id", user_id).ilike("phone", f"%{query}%").limit(limit).execute()

    seen = set()
    clients = []
    for r in [*by_name.data, *by_phone.data]:
        if r["id"] not in seen:
            seen.add(r["id"])
            clients.append({"id": r["id"], "name": r["name"], "phone": r["phone"], "notes": r.get("notes") or ""})

    clients.sort(key=lambda c: c["name"])
    return {"clients": clients[:limit], "count": len(clients[:limit])}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Busca clientes")
    parser.add_argument("--user_id", required=True)
    parser.add_argument("--query", required=True)
    parser.add_argument("--limit", type=int, default=10)
    args = parser.parse_args()
    print(json.dumps(search_client(args.user_id, args.query, args.limit), ensure_ascii=False, indent=2))
