#!/usr/bin/env python3
"""
run_pipeline.py — Orquestador del pipeline Northwind DWA (Opcion B).

Se conecta directo a SQLite con el modulo sqlite3 de Python (no depende
de tener el binario `sqlite3` en el PATH), ejecuta cada script .sql con
executescript() y corre los loaders Python (S12, S30) como subprocesos.
Al final imprime un resumen leyendo DQM_LOG_EJECUCION y DQM_CONTROL_CAMPO.

100% stdlib: sqlite3, argparse, subprocess, pathlib, time, sys.

Uso:
    python run_pipeline.py                       # corre todo el pipeline
    python run_pipeline.py --list                # lista los pasos y sale
    python run_pipeline.py --dry-run             # muestra el plan sin tocar la DB
    python run_pipeline.py --stage 03            # solo una etapa (00,01,02,03,04)
    python run_pipeline.py --from S30 --to S36   # un rango de pasos
    python run_pipeline.py --only S35,S36        # pasos puntuales
    python run_pipeline.py --db otra/ruta.db
    python run_pipeline.py --continue-on-error   # no detener ante el primer ERROR
    python run_pipeline.py --no-color            # sin colores ANSI (cmd.exe viejo)
"""

import argparse
import sqlite3
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent
SCRIPTS = ROOT / "scripts"
DEFAULT_DB = ROOT / "db" / "northwind_dwa.db"


class Color:
    GREEN = "\033[92m"
    RED = "\033[91m"
    YELLOW = "\033[93m"
    CYAN = "\033[96m"
    BOLD = "\033[1m"
    DIM = "\033[2m"
    RESET = "\033[0m"

    @classmethod
    def disable(cls):
        for attr in ("GREEN", "RED", "YELLOW", "CYAN", "BOLD", "DIM", "RESET"):
            setattr(cls, attr, "")


# Orden del pipeline. "extra_args" se le agrega a los pasos "py" despues de --db.
PIPELINE = [
    {"id": "S00", "stage": "00_init",          "file": "S00_create_infrastructure.sql", "kind": "sql",
     "desc": "Crea tablas TXT_ (12) y DQM_ (5) base"},
    {"id": "S01", "stage": "00_init",          "file": "S01_populate_inventory.sql",    "kind": "sql",
     "desc": "Registra los pasos del pipeline en el inventario"},

    {"id": "S10", "stage": "01_adquisicion",   "file": "S10_create_txt_tables.sql",     "kind": "sql",
     "desc": "Verifica existencia de tablas TXT_"},
    {"id": "S11", "stage": "01_adquisicion",   "file": "S11_create_tmp_tables.sql",     "kind": "sql",
     "desc": "Crea tablas TMP_ con tipos y PK/FK"},
    {"id": "S12", "stage": "01_adquisicion",   "file": "S12_load_csv.py",               "kind": "py",
     "desc": "Carga CSV de Ingesta1 a TXT_", "extra_args": ["--ingesta", "1"]},
    {"id": "S13", "stage": "01_adquisicion",   "file": "S13_validate_txt_format.sql",   "kind": "sql",
     "desc": "Valida formato campo a campo en TXT_"},
    {"id": "S14", "stage": "01_adquisicion",   "file": "S14_validate_pk.sql",           "kind": "sql",
     "desc": "Valida unicidad de PK"},
    {"id": "S15", "stage": "01_adquisicion",   "file": "S15_profiling.sql",            "kind": "sql",
     "desc": "Perfilado + outliers (IQR) + faltantes"},
    {"id": "S16", "stage": "01_adquisicion",   "file": "S16_txt_to_tmp.sql",           "kind": "sql",
     "desc": "Copia TXT_ -> TMP_ con CAST"},
    {"id": "S17", "stage": "01_adquisicion",   "file": "S17_validate_referential.sql", "kind": "sql",
     "desc": "Valida integridad referencial en TMP_"},

    {"id": "S20", "stage": "02_ingenieria",    "file": "S20_create_metadata.sql",       "kind": "sql",
     "desc": "Crea tablas MET_"},
    {"id": "S21", "stage": "02_ingenieria",    "file": "S21_populate_metadata.sql",     "kind": "sql",
     "desc": "Documenta entidades, campos y procesos"},
    {"id": "S22", "stage": "02_ingenieria",    "file": "S22_create_dwa_model.sql",      "kind": "sql",
     "desc": "Crea el modelo estrella DWA_"},
    {"id": "S23", "stage": "02_ingenieria",    "file": "S23_create_dwm_memory.sql",     "kind": "sql",
     "desc": "Crea tablas DWM_ (SCD tipo 2)"},
    {"id": "S24", "stage": "02_ingenieria",    "file": "S24_create_enrichment.sql",     "kind": "sql",
     "desc": "Crea vistas analiticas para Power BI"},
    {"id": "S25", "stage": "02_ingenieria",    "file": "S25_create_dqm_full.sql",       "kind": "sql",
     "desc": "Extiende DQM (alertas y resumenes)"},
    {"id": "S26", "stage": "02_ingenieria",    "file": "S26_initial_load.sql",          "kind": "sql",
     "desc": "Carga inicial TMP_ -> DWA_"},

    {"id": "S30", "stage": "03_actualizacion", "file": "S30_load_ingesta2_txt.py",      "kind": "py",
     "desc": "Carga CSV de Ingesta2 a TXT_ con nombres limpios"},
    {"id": "S31", "stage": "03_actualizacion", "file": "S31_validate_ingesta2.sql",     "kind": "sql",
     "desc": "Valida Ingesta2"},
    {"id": "S32", "stage": "03_actualizacion", "file": "S32_update_dwa.sql",            "kind": "sql",
     "desc": "Actualiza DWA_ con novedades de Ingesta2"},
    {"id": "S33", "stage": "03_actualizacion", "file": "S33_update_memory.sql",         "kind": "sql",
     "desc": "Puebla la Memoria DWM_"},
    {"id": "S34", "stage": "03_actualizacion", "file": "S34_update_enrichment.sql",     "kind": "sql",
     "desc": "Verifica consistencia de derivados"},
    {"id": "S35", "stage": "03_actualizacion", "file": "S35_add_world_data.sql",        "kind": "sql",
     "desc": "Incorpora world-data (PIB, capital, poblacion)"},
    {"id": "S36", "stage": "03_actualizacion", "file": "S36_add_customer_score.sql",    "kind": "sql",
     "desc": "Incorpora score y deriva segmento"},

    {"id": "S40", "stage": "04_publicacion",   "file": "S40_create_dp_ventas.sql",      "kind": "sql",
     "desc": "Crea DP01_VENTAS"},
    {"id": "S41", "stage": "04_publicacion",   "file": "S41_create_dp_clientes.sql",    "kind": "sql",
     "desc": "Crea DP02_CLIENTES"},
    {"id": "S42", "stage": "04_publicacion",   "file": "S42_register_products.sql",     "kind": "sql",
     "desc": "Registra DPs y genera resumen final"},
]


def stage_matches(stage_name, query):
    return stage_name == query or stage_name.split("_", 1)[0] == query


def resolve_steps(args):
    steps = PIPELINE

    if args.stage:
        queries = {q.strip() for q in args.stage.split(",")}
        steps = [s for s in steps if any(stage_matches(s["stage"], q) for q in queries)]

    if args.only:
        ids = {i.strip().upper() for i in args.only.split(",")}
        steps = [s for s in steps if s["id"] in ids]

    if args.from_step or args.to_step:
        all_ids = [s["id"] for s in PIPELINE]
        start = all_ids.index(args.from_step.upper()) if args.from_step else 0
        end = all_ids.index(args.to_step.upper()) + 1 if args.to_step else len(all_ids)
        allowed = set(all_ids[start:end])
        steps = [s for s in steps if s["id"] in allowed]

    return steps


def run_sql_step(conn, step):
    path = SCRIPTS / step["stage"] / step["file"]
    if not path.exists():
        return "SKIPPED", f"archivo no encontrado: {path.relative_to(ROOT)}"
    sql = path.read_text(encoding="utf-8")
    try:
        conn.executescript(sql)
        return "OK", None
    except sqlite3.Error as e:
        return "ERROR", str(e)


def run_python_step(step, db_path):
    path = SCRIPTS / step["stage"] / step["file"]
    if not path.exists():
        return "SKIPPED", f"archivo no encontrado: {path.relative_to(ROOT)}"
    cmd = [sys.executable, str(path), "--db", str(db_path)] + step.get("extra_args", [])
    result = subprocess.run(cmd, capture_output=True, text=True)
    output = (result.stdout + result.stderr).strip()
    return ("OK" if result.returncode == 0 else "ERROR"), output


def print_summary(conn, results, total_elapsed):
    print(f"\n{Color.BOLD}=== Resumen de la corrida ==={Color.RESET}")
    status_color = {"OK": Color.GREEN, "ERROR": Color.RED, "SKIPPED": Color.YELLOW}
    for step_id, desc, status, elapsed in results:
        color = status_color.get(status, "")
        print(f"  {step_id}  {color}{status:8}{Color.RESET}  {desc}  ({elapsed:.2f}s)")

    ok = sum(1 for r in results if r[2] == "OK")
    err = sum(1 for r in results if r[2] == "ERROR")
    skip = sum(1 for r in results if r[2] == "SKIPPED")
    print(
        f"\n{Color.GREEN}{ok} OK{Color.RESET} / "
        f"{Color.RED}{err} ERROR{Color.RESET} / "
        f"{Color.YELLOW}{skip} SKIPPED{Color.RESET}  —  total {total_elapsed:.1f}s"
    )

    try:
        rows = conn.execute("""
            SELECT script_id, resultado, mensaje, registros_proc
            FROM DQM_LOG_EJECUCION
            WHERE log_id IN (SELECT MAX(log_id) FROM DQM_LOG_EJECUCION GROUP BY script_id)
            ORDER BY log_id
        """).fetchall()
    except sqlite3.Error:
        rows = []

    if rows:
        print(f"\n{Color.BOLD}=== DQM_LOG_EJECUCION (ultima corrida por script) ==={Color.RESET}")
        for script_id, resultado, mensaje, registros in rows:
            color = status_color.get(resultado, Color.YELLOW)
            print(f"  {script_id:5} {color}{(resultado or '?'):8}{Color.RESET} "
                  f"{(registros or 0):>6} regs  {mensaje or ''}")

    try:
        rows = conn.execute(
            "SELECT decision, COUNT(*) FROM DQM_CONTROL_CAMPO GROUP BY decision"
        ).fetchall()
    except sqlite3.Error:
        rows = []

    if rows:
        print(f"\n{Color.BOLD}=== DQM_CONTROL_CAMPO (controles de calidad) ==={Color.RESET}")
        for decision, count in rows:
            color = Color.GREEN if "ACEPT" in (decision or "") else Color.RED
            print(f"  {color}{(decision or '?'):10}{Color.RESET} {count}")


def main():
    parser = argparse.ArgumentParser(
        description="Orquestador del pipeline Northwind DWA (lee .sql y corre loaders .py)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument("--db", default=str(DEFAULT_DB), help="ruta al archivo .db (default: db/northwind_dwa.db)")
    parser.add_argument("--stage", help="filtrar por etapa: 00,01,02,03,04 (separadas por coma)")
    parser.add_argument("--only", help="correr solo estos pasos, ej: S35,S36")
    parser.add_argument("--from", dest="from_step", help="primer paso del rango, ej: S30")
    parser.add_argument("--to", dest="to_step", help="ultimo paso del rango, ej: S36")
    parser.add_argument("--list", action="store_true", help="listar los pasos y salir")
    parser.add_argument("--dry-run", action="store_true", help="mostrar el plan sin ejecutar nada")
    parser.add_argument("--continue-on-error", action="store_true", help="no detenerse ante el primer ERROR")
    parser.add_argument("--no-color", action="store_true", help="desactivar colores ANSI")
    args = parser.parse_args()

    if args.no_color or not sys.stdout.isatty():
        Color.disable()

    steps = resolve_steps(args)

    if args.list:
        for s in steps:
            print(f"{s['id']}  [{s['kind']:3}]  {s['stage']}/{s['file']:32}  {s['desc']}")
        return

    if args.dry_run:
        print(f"{Color.CYAN}Plan de ejecucion ({len(steps)} pasos) sobre {args.db}{Color.RESET}")
        for s in steps:
            print(f"  {s['id']}  {s['desc']}")
        return

    db_path = Path(args.db)
    if not db_path.exists():
        print(f"{Color.YELLOW}[AVISO]{Color.RESET} {db_path} no existe todavia, se creara al conectar.")
        db_path.parent.mkdir(parents=True, exist_ok=True)

    conn = sqlite3.connect(db_path)

    results = []
    start_total = time.time()
    for step in steps:
        print(f"{Color.BOLD}{step['id']}{Color.RESET}  {step['desc']} ... ", end="", flush=True)
        t0 = time.time()

        if step["kind"] == "sql":
            status, detail = run_sql_step(conn, step)
        else:
            conn.close()
            status, detail = run_python_step(step, db_path)
            conn = sqlite3.connect(db_path)

        elapsed = time.time() - t0

        if status == "OK":
            print(f"{Color.GREEN}OK{Color.RESET}  ({elapsed:.2f}s)")
            if detail and step["kind"] == "py":
                print(f"{Color.DIM}{detail}{Color.RESET}")
        elif status == "SKIPPED":
            print(f"{Color.YELLOW}SKIPPED{Color.RESET}  - {detail}")
        else:
            print(f"{Color.RED}ERROR{Color.RESET}  ({elapsed:.2f}s)")
            if detail:
                print(f"{Color.DIM}{detail}{Color.RESET}")

        results.append((step["id"], step["desc"], status, elapsed))

        if status == "ERROR" and not args.continue_on_error:
            print(f"\n{Color.RED}Pipeline detenido en {step['id']} "
                  f"(usar --continue-on-error para seguir).{Color.RESET}")
            break

    total_elapsed = time.time() - start_total
    print_summary(conn, results, total_elapsed)
    conn.close()

    if any(r[2] == "ERROR" for r in results):
        sys.exit(1)


if __name__ == "__main__":
    main()
