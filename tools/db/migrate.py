"""
migrate.py — spustí jeden nebo více SQL souborů proti Postgres/Supabase.

Připojení se bere z proměnné prostředí DATABASE_URL, kterou nastaví `migrate.ps1`
(dešifruje ji z DPAPI). Heslo se nikam neukládá v plaintextu ani neloguje.

Použití (přes wrapper, ne přímo):
    ./migrate.ps1 ../../supabase/schema.sql ../../supabase/import_graph.sql
"""
import os
import sys
import psycopg


def main() -> None:
    if len(sys.argv) < 2:
        print("Použití: migrate.py <soubor.sql> [další.sql ...]")
        sys.exit(1)

    url = os.environ.get("DATABASE_URL")
    if not url:
        print("Chybí DATABASE_URL (spusť přes migrate.ps1).")
        sys.exit(1)
    if "sslmode=" not in url:
        url += ("&" if "?" in url else "?") + "sslmode=require"

    with psycopg.connect(url, autocommit=True) as conn:
        for path in sys.argv[1:]:
            with open(path, "r", encoding="utf-8") as f:
                sql = f.read()
            with conn.cursor() as cur:
                cur.execute(sql)
            print(f"OK: {path}")
    print("Hotovo.")


if __name__ == "__main__":
    main()
