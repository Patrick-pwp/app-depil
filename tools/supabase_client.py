"""
Cliente Supabase compartilhado para todos os WAT tools.

Uso:
    from tools.supabase_client import get_client, get_admin_client

    # Cliente com anon key (respeita RLS — use para operações do usuário)
    sb = get_client()

    # Cliente com service role key (bypassa RLS — use para automações)
    sb = get_admin_client()
"""

import os
from functools import lru_cache

from dotenv import load_dotenv
from supabase import Client, create_client

load_dotenv()


def _require(key: str) -> str:
    value = os.environ.get(key)
    if not value:
        raise EnvironmentError(
            f"Variável de ambiente '{key}' não definida. "
            f"Verifique o arquivo .env na raiz do projeto."
        )
    return value


@lru_cache(maxsize=1)
def get_client() -> Client:
    """Cliente com anon/publishable key — respeita Row Level Security."""
    return create_client(
        supabase_url=_require("SUPABASE_URL"),
        supabase_key=_require("SUPABASE_ANON_KEY"),
    )


@lru_cache(maxsize=1)
def get_admin_client() -> Client:
    """
    Cliente com service role key — bypassa RLS.
    Use apenas em automações server-side (WAT tools).
    A service role key fica em Settings > API Keys > Legacy > service_role.
    """
    service_key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY")
    if not service_key:
        # fallback: usa anon key com aviso
        print(
            "⚠️  SUPABASE_SERVICE_ROLE_KEY não definida. "
            "Usando anon key — operações que requerem bypass de RLS podem falhar.\n"
            "Adicione a service role key em .env para automações completas."
        )
        return get_client()
    return create_client(
        supabase_url=_require("SUPABASE_URL"),
        supabase_key=service_key,
    )
