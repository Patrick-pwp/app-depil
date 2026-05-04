"""
Gera relatório financeiro em .xlsx com duas abas: lançamentos e resumo DRE.

Uso:
    python tools/export_financial_to_excel.py \
        --user_id <uuid> \
        --start_date 2026-05-01 \
        --end_date 2026-05-31

Saída:
    .tmp/relatorio_2026-05-01_2026-05-31.xlsx
"""

import argparse
import json
from datetime import date
from pathlib import Path

from openpyxl import Workbook
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.utils import get_column_letter

from supabase_client import get_admin_client

HEADER_FILL = PatternFill("solid", fgColor="D4447A")
HEADER_FONT = Font(bold=True, color="FFFFFF")
PINK_FILL   = PatternFill("solid", fgColor="F8D7E3")
ALT_FILL    = PatternFill("solid", fgColor="F9F9F9")


def _br_currency(v: float) -> str:
    return f"R$ {v:,.2f}".replace(",", "X").replace(".", ",").replace("X", ".")

def _br_date(d: date) -> str:
    return d.strftime("%d/%m/%Y")


def export_to_excel(user_id: str, start_date_str: str, end_date_str: str) -> dict:
    sb = get_admin_client()
    rows = sb.table("financial_entries").select("entry_date,client_name,procedure_name,revenue,cost,profit,appointments(scheduled_at,is_paid)").eq("user_id", user_id).gte("entry_date", start_date_str).lte("entry_date", end_date_str).order("entry_date").execute()

    total_revenue = sum(float(r["revenue"]) for r in rows.data)
    total_cost    = sum(float(r["cost"])    for r in rows.data)
    total_profit  = sum(float(r["profit"])  for r in rows.data)
    margin = (total_profit / total_revenue * 100) if total_revenue > 0 else 0.0

    wb = Workbook()
    ws1 = wb.active
    ws1.title = "Lançamentos"

    headers = ["Data", "Horário", "Cliente", "Procedimento", "Receita (R$)", "Custo (R$)", "Lucro (R$)", "Pago"]
    for col, h in enumerate(headers, 1):
        cell = ws1.cell(row=1, column=col, value=h)
        cell.fill = HEADER_FILL
        cell.font = HEADER_FONT
        cell.alignment = Alignment(horizontal="center")

    for i, r in enumerate(rows.data, 2):
        appt = r.get("appointments") or {}
        scheduled_at = appt.get("scheduled_at", "")
        time_str = scheduled_at[11:16] if len(scheduled_at) >= 16 else ""
        entry_date = date.fromisoformat(r["entry_date"])
        values = [_br_date(entry_date), time_str, r["client_name"], r["procedure_name"],
                  float(r["revenue"]), float(r["cost"]), float(r["profit"]),
                  "Sim" if appt.get("is_paid") else "Não"]
        for col, val in enumerate(values, 1):
            ws1.cell(row=i, column=col, value=val)
            if i % 2 == 0:
                ws1.cell(row=i, column=col).fill = ALT_FILL

    for col, w in enumerate([12, 10, 25, 25, 14, 14, 14, 8], 1):
        ws1.column_dimensions[get_column_letter(col)].width = w

    ws2 = wb.create_sheet("Resumo DRE")
    ws2.column_dimensions["A"].width = 30
    ws2.column_dimensions["B"].width = 20
    ws2["A1"] = "DRE — Resumo do Período"
    ws2["A1"].font = Font(bold=True, size=14)
    ws2.merge_cells("A1:B1")

    start = date.fromisoformat(start_date_str)
    end   = date.fromisoformat(end_date_str)
    summary = [
        ("Período", f"{_br_date(start)} a {_br_date(end)}"),
        ("Atendimentos Realizados", len(rows.data)),
        ("", ""),
        ("(+) Receita Bruta", _br_currency(total_revenue)),
        ("(-) Custo Total",   _br_currency(total_cost)),
        ("(=) Lucro Bruto",   _br_currency(total_profit)),
        ("Margem de Lucro",   f"{margin:.1f}%"),
    ]
    for offset, (label, value) in enumerate(summary, 3):
        ws2.cell(row=offset, column=1, value=label).font = Font(bold=True)
        ws2.cell(row=offset, column=2, value=value)
        if label == "(=) Lucro Bruto":
            ws2.cell(row=offset, column=1).fill = PINK_FILL
            ws2.cell(row=offset, column=2).fill = PINK_FILL

    Path(".tmp").mkdir(exist_ok=True)
    filename = f".tmp/relatorio_{start_date_str}_{end_date_str}.xlsx"
    wb.save(filename)
    return {"file_path": filename, "entry_count": len(rows.data)}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Exporta relatório para Excel")
    parser.add_argument("--user_id", required=True)
    parser.add_argument("--start_date", required=True)
    parser.add_argument("--end_date", required=True)
    args = parser.parse_args()
    result = export_to_excel(args.user_id, args.start_date, args.end_date)
    print(json.dumps(result, ensure_ascii=False, indent=2))
