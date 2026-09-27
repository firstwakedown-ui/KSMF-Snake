"""Export hernich planu do prenositelneho PostgreSQL SQL dumpu.

Vystup obsahuje pouze mapove plany a jejich geometrii. Neobsahuje ucty,
hrace, zalozene/odehrane hry ani globalni nastaveni zapasu.
"""

from __future__ import annotations

import os
from datetime import datetime, timezone
from pathlib import Path
import sys

import psycopg
from psycopg import sql


TABLES: tuple[tuple[str, tuple[str, ...]], ...] = (
    (
        "matches",
        (
            "id",
            "name",
            "area",
            "status",
            "created_at",
            "idle_timeout_s",
            "outside_timeout_s",
            "snap_tolerance_m",
            "is_active",
            "footpaths_enabled",
            "started_at",
            "ready",
            "walk_speed_mps",
            "run_speed_mps",
            "sprint_speed_mps",
            "sprint_range_m",
            "snake_initial_length_m",
            "strawberry_growth_m",
            "game_duration_s",
            "snake_speed_mps",
            "strawberry_spawn_min_s",
            "strawberry_spawn_max_s",
            "max_lead_m",
            "respawn_countdown_s",
            "collision_radius_m",
            "strawberry_radius_m",
            "strawberry_active_percent",
            "self_collision_grace_m",
            "strawberry_initial_percent",
        ),
    ),
    # ID a puvodni OSM uzly se zamerne neprenaseji. Azure si pro hrany
    # vytvori vlastni ID a plan tak nezavisi na tabulce street_nodes.
    ("street_edges", ("match_id", "name", "geom", "enabled", "is_foot")),
    ("start_points", ("id", "match_id", "label", "geom", "created_at")),
    ("respawn_points", ("id", "match_id", "label", "geom", "created_at")),
    ("strawberry_points", ("id", "match_id", "geom", "created_at")),
)


def with_sslmode(url: str) -> str:
    if "sslmode=" in url:
        return url
    return url + ("&" if "?" in url else "?") + "sslmode=require"


def verify_schema(conn: psycopg.Connection[object]) -> None:
    missing: list[str] = []
    with conn.cursor() as cur:
        for table, columns in TABLES:
            cur.execute(
                """
                select column_name
                from information_schema.columns
                where table_schema = 'public' and table_name = %s
                """,
                (table,),
            )
            actual = {row[0] for row in cur.fetchall()}
            if not actual:
                missing.append(f"public.{table} (chybi tabulka)")
                continue
            for column in columns:
                if column not in actual:
                    missing.append(f"public.{table}.{column}")

        cur.execute("select exists(select 1 from pg_extension where extname='postgis')")
        if not cur.fetchone()[0]:
            missing.append("PostGIS extension")

    if missing:
        details = "\n- ".join(missing)
        raise RuntimeError(f"Databaze nema aktualni schema:\n- {details}")


def export_table(
    conn: psycopg.Connection[object],
    target,
    table: str,
    columns: tuple[str, ...],
) -> int:
    identifiers = sql.SQL(", ").join(map(sql.Identifier, columns))
    order_column = "id" if "id" in columns else "match_id"
    where = sql.SQL("")
    if table != "matches":
        where = sql.SQL(
            " where match_id in (select id from public.matches)"
        )

    with conn.cursor() as cur:
        cur.execute(
            sql.SQL("select count(*) from public.{}{}").format(
                sql.Identifier(table), where
            )
        )
        count = cur.fetchone()[0]

        target.write(
            sql.SQL("COPY public.{} ({}) FROM stdin;\n")
            .format(sql.Identifier(table), identifiers)
            .as_string(conn)
            .encode("utf-8")
        )
        copy_query = sql.SQL(
            "COPY (select {} from public.{}{} order by {}) TO STDOUT"
        ).format(
            identifiers,
            sql.Identifier(table),
            where,
            sql.Identifier(order_column),
        )
        with cur.copy(copy_query) as copy:
            for chunk in copy:
                target.write(bytes(chunk))
        target.write(b"\\.\n\n")
    return count


def main() -> None:
    if len(sys.argv) > 2:
        print("Pouziti: export-plans.py [vystupni-soubor.sql]")
        raise SystemExit(2)

    url = os.environ.get("DATABASE_URL")
    if not url:
        print("Chybi DATABASE_URL (spust pres export-plans.ps1).")
        raise SystemExit(1)

    output = (
        Path(sys.argv[1])
        if len(sys.argv) == 2
        else Path(__file__).resolve().parents[2] / "supabase" / "data" / "plans.sql"
    )
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_suffix(output.suffix + ".tmp")

    counts: dict[str, int] = {}
    try:
        with psycopg.connect(with_sslmode(url)) as conn:
            verify_schema(conn)
            with temporary.open("wb") as target:
                generated = datetime.now(timezone.utc).isoformat(timespec="seconds")
                target.write(
                    (
                        "-- KSMF Snake: mapove plany (automaticky generovano)\n"
                        f"-- Vytvoreno: {generated}\n"
                        "-- Neobsahuje hrace, hry, herni stav ani game_settings.\n"
                        "-- Cilova databaze musi mit aplikovane aktualni migrace a PostGIS.\n\n"
                        "\\set ON_ERROR_STOP on\n"
                        "BEGIN;\n\n"
                    ).encode("utf-8")
                )
                for table, columns in TABLES:
                    counts[table] = export_table(conn, target, table, columns)
                target.write(b"COMMIT;\n")
        temporary.replace(output)
    except Exception:
        temporary.unlink(missing_ok=True)
        raise

    print(f"Hotovo: {output}")
    for table, count in counts.items():
        print(f"  {table}: {count}")


if __name__ == "__main__":
    main()
