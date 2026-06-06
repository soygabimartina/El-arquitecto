"""
Carga archivos CSV a las tablas TXT_ de la base SQLite.
Uso:
    python load_csv.py --ingesta 1 --db ../db/northwind_dwa.db
    python load_csv.py --ingesta 2 --db ../db/northwind_dwa.db
"""
import argparse
import csv
import os
import sqlite3
from datetime import datetime

# Mapeo ingesta → carpeta → tablas
INGESTA_CONFIG = {
    "1": {
        "folder": "../data/ingesta1",
        "tables": {
            "categories.csv":          "TXT_CATEGORIES",
            "customers.csv":           "TXT_CUSTOMERS",
            "employees.csv":           "TXT_EMPLOYEES",
            "suppliers.csv":           "TXT_SUPPLIERS",
            "products.csv":            "TXT_PRODUCTS",
            "shippers.csv":            "TXT_SHIPPERS",
            "regions.csv":             "TXT_REGIONS",
            "territories.csv":         "TXT_TERRITORIES",
            "employee_territories.csv":"TXT_EMPLOYEE_TERRITORIES",
            "orders.csv":              "TXT_ORDERS",
            "order_details.csv":       "TXT_ORDER_DETAILS",
        }
    },
    "2": {
        "folder": "../data/ingesta2",
        "tables": {
            "orders_update.csv":      "TXT_ORDERS",
            "world-data-2023.csv":    "TXT_WORLD_DATA",
            "customer_score.csv":     "TXT_CUSTOMER_SCORE",
        }
    }
}


def load_csv_to_table(conn: sqlite3.Connection, csv_path: str, table: str, append: bool = False) -> int:
    if not os.path.exists(csv_path):
        print(f"  [WARN] No encontrado: {csv_path}")
        return 0

    with open(csv_path, encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        rows = list(reader)

    if not rows:
        print(f"  [WARN] CSV vacío: {csv_path}")
        return 0

    cur = conn.cursor()

    if not append:
        cur.execute(f"DELETE FROM {table}")

    columns = rows[0].keys()
    placeholders = ",".join("?" for _ in columns)
    col_list = ",".join(columns)
    sql = f"INSERT OR IGNORE INTO {table} ({col_list}) VALUES ({placeholders})"

    data = [
        [row[c] if row[c] != "" else None for c in columns]
        for row in rows
    ]

    cur.executemany(sql, data)
    conn.commit()

    count = cur.rowcount if cur.rowcount > 0 else len(data)
    print(f"  [OK] {os.path.basename(csv_path)} → {table}: {len(data)} filas")
    return len(data)


def ensure_extra_txt_tables(conn: sqlite3.Connection):
    """Crea tablas TXT extra para Ingesta2 si no existen."""
    conn.executescript("""
        CREATE TABLE IF NOT EXISTS TXT_WORLD_DATA (
            country           TEXT,
            density           TEXT,
            abbreviation      TEXT,
            agricultural_land TEXT,
            land_area         TEXT,
            armed_forces      TEXT,
            birth_rate        TEXT,
            calling_code      TEXT,
            capital           TEXT,
            co2_emissions     TEXT,
            cpi               TEXT,
            cpi_change        TEXT,
            currency_code     TEXT,
            fertility_rate    TEXT,
            forested_area     TEXT,
            gasoline_price    TEXT,
            gdp               TEXT,
            gross_primary     TEXT,
            infant_mortality  TEXT,
            largest_city      TEXT,
            life_expectancy   TEXT,
            maternal_mortality TEXT,
            minimum_wage      TEXT,
            official_language TEXT,
            out_of_pocket     TEXT,
            physicians        TEXT,
            population        TEXT,
            labor_force       TEXT,
            tax_revenue       TEXT,
            total_tax_rate    TEXT,
            unemployment_rate TEXT,
            urban_population  TEXT,
            latitude          TEXT,
            longitude         TEXT
        );

        CREATE TABLE IF NOT EXISTS TXT_CUSTOMER_SCORE (
            customer_id TEXT,
            score       TEXT,
            segment     TEXT
        );
    """)
    conn.commit()


def main():
    parser = argparse.ArgumentParser(description="Carga CSV a tablas TXT_ de northwind_dwa")
    parser.add_argument("--ingesta", required=True, choices=["1", "2"], help="Número de ingesta")
    parser.add_argument("--db", default="../db/northwind_dwa.db", help="Path al archivo .db")
    parser.add_argument("--append", action="store_true", help="No borrar tabla antes de cargar")
    args = parser.parse_args()

    if not os.path.exists(args.db):
        print(f"[ERROR] Base de datos no encontrada: {args.db}")
        print("Creá primero la BD en SQLiteStudio y ejecutá S00 y S10.")
        return

    config = INGESTA_CONFIG[args.ingesta]
    folder = os.path.join(os.path.dirname(__file__), config["folder"])

    conn = sqlite3.connect(args.db)

    if args.ingesta == "2":
        ensure_extra_txt_tables(conn)

    print(f"\n=== Carga Ingesta{args.ingesta} — {datetime.now():%Y-%m-%d %H:%M} ===")
    total = 0
    for csv_file, table in config["tables"].items():
        csv_path = os.path.join(folder, csv_file)
        total += load_csv_to_table(conn, csv_path, table, append=args.append)

    print(f"\nTotal filas procesadas: {total}")
    conn.close()


if __name__ == "__main__":
    main()
