"""
Exporta tablas de la base SQLite a archivos CSV para usarlos en Power BI.

Uso:
    python export_to_csv.py --db ../db/northwind_dwa.db
    python export_to_csv.py --db ../db/northwind_dwa.db --out ../exports
    python export_to_csv.py --db ../db/northwind_dwa.db --tables DP01_VENTAS DQM_ALERTA
"""
import argparse
import csv
import os
import sqlite3

# Tablas que se exportan por defecto: productos de datos + tablas del DQM
# usadas en los tableros de Power BI.
DEFAULT_TABLES = [
    "DP01_VENTAS",
    "DP02_CLIENTES",
    "DP03_PRODUCTOS",
    "DQM_LOG_EJECUCION",
    "DQM_CONTROL_CAMPO",
    "DQM_ALERTA",
    "DQM_RESUMEN_CALIDAD",
    "DQM_INVENTARIO_SCRIPTS",
]


def table_exists(conn: sqlite3.Connection, table: str) -> bool:
    cur = conn.execute(
        "SELECT 1 FROM sqlite_master WHERE type IN ('table','view') AND name = ?",
        (table,),
    )
    return cur.fetchone() is not None


def export_table(conn: sqlite3.Connection, table: str, out_folder: str) -> int:
    if not table_exists(conn, table):
        print(f"  [WARN] No existe: {table} (se omite)")
        return 0

    cur = conn.execute(f"SELECT * FROM {table}")
    columns = [d[0] for d in cur.description]
    rows = cur.fetchall()

    csv_path = os.path.join(out_folder, f"{table}.csv")
    with open(csv_path, "w", encoding="utf-8-sig", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(columns)
        writer.writerows(rows)

    print(f"  [OK] {table} → {os.path.basename(csv_path)}: {len(rows)} filas")
    return len(rows)


def main():
    parser = argparse.ArgumentParser(description="Exporta tablas de northwind_dwa.db a CSV")
    parser.add_argument("--db", default="../db/northwind_dwa.db", help="Path al archivo .db")
    parser.add_argument("--out", default="../exports", help="Carpeta de salida para los CSV")
    parser.add_argument("--tables", nargs="*", default=DEFAULT_TABLES,
                         help="Lista de tablas a exportar (por defecto: productos de datos + DQM)")
    args = parser.parse_args()

    if not os.path.exists(args.db):
        print(f"[ERROR] Base de datos no encontrada: {args.db}")
        return

    out_folder = os.path.join(os.path.dirname(__file__), args.out)
    os.makedirs(out_folder, exist_ok=True)

    conn = sqlite3.connect(args.db)

    print(f"\n=== Exportación a CSV → {out_folder} ===")
    total = 0
    for table in args.tables:
        total += export_table(conn, table, out_folder)

    print(f"\nTotal filas exportadas: {total}")
    conn.close()


if __name__ == "__main__":
    main()
