"""
build_graph.py — stáhne síť ulic z OpenStreetMap (OSMnx) pro Prahu–Barrandov
a vygeneruje SQL pro import grafu do PostGIS (Supabase).

Použití:
    .venv\\Scripts\\python.exe build_graph.py     (Windows)

Výstup:
    ../../supabase/import_graph.sql   → spustí se přes tools/db/migrate (nebo SQL Editor).

Pozn.: Síť = `drive` (osy silnic) → **jedna hrana na ulici** (ne dvojité chodníky).
Hraniční silnice (K Barrandovu na jihu, Štěpařská na východě) jsou z plánu vyloučené.
Hrany se deduplikují podle dvojice uzlů (obousměrná ulice = jedna čára).
"""
import os
import osmnx as ox

# Hrací oblast Praha–Barrandov (left=západ, bottom=jih, right=východ, top=sever).
# Sever ~Werichova/Voskovcova, východ ~Štěpařská (zahrnuta), jih uříznut nad Ke Smíchovu/K Barrandovu.
WEST, SOUTH, EAST, NORTH = 14.3625, 50.0248, 14.3782, 50.0335

# Síť silnic (osy ulic) – jedna hrana na ulici.
NETWORK_TYPE = "drive"

# Hlavní průtahy na jihu, které NEJSOU součástí herního plánu. (Štěpařská je naopak zahrnuta.)
EXCLUDE_NAMES = {"K Barrandovu", "Ke Smíchovu"}

OUT_SQL = os.path.join("..", "..", "supabase", "import_graph.sql")


def _norm(s) -> str:
    # Sjednotí bílé znaky (vč. nbsp) a ořeže – kvůli názvům s neviditelnými mezerami.
    return " ".join(str(s).replace(" ", " ").split())


EXCLUDE_NORM = {_norm(n) for n in EXCLUDE_NAMES}


def sql_str(value) -> str:
    if value is None:
        return "NULL"
    if isinstance(value, float):  # pandas NaN = chybějící název
        return "NULL"
    if isinstance(value, list):
        value = ", ".join(str(v) for v in value)
    return "'" + str(value).replace("'", "''") + "'"


def is_excluded(name) -> bool:
    names = name if isinstance(name, list) else [name]
    for x in names:
        if x is None or isinstance(x, float):
            continue
        if _norm(x) in EXCLUDE_NORM:
            return True
    return False


def main() -> None:
    os.makedirs(os.path.dirname(OUT_SQL), exist_ok=True)

    print("Stahuji síť ulic z OpenStreetMap (Praha–Barrandov, drive)…")
    graph = ox.graph_from_bbox((WEST, SOUTH, EAST, NORTH), network_type=NETWORK_TYPE)
    nodes, edges = ox.graph_to_gdfs(graph)
    node_ids = set(int(i) for i in nodes.index)

    # Hrany: dedup podle neuspořádané dvojice uzlů + vyloučení hraničních silnic.
    edge_rows = []
    seen = set()
    for (u, v, _key), row in edges.iterrows():
        u, v = int(u), int(v)
        if u not in node_ids or v not in node_ids:
            continue
        pair = frozenset((u, v))
        if pair in seen:
            continue
        if is_excluded(row.get("name")):
            continue
        geom = row.get("geometry")
        if geom is None:
            continue
        seen.add(pair)
        edge_rows.append((u, v, row.get("name"), geom))

    # Vkládáme jen uzly, které nějaká ponechaná hrana používá.
    used_nodes = set()
    for u, v, _name, _geom in edge_rows:
        used_nodes.add(u)
        used_nodes.add(v)

    out = []
    out.append("-- Vygenerováno build_graph.py (OSM drive -> PostGIS). Spusť přes tools/db/migrate.")
    out.append("begin;")
    out.append("truncate table street_edges, street_nodes restart identity cascade;")

    for osmid, row in nodes.iterrows():
        if int(osmid) not in used_nodes:
            continue
        out.append(
            f"insert into street_nodes (id, geom) values "
            f"({int(osmid)}, ST_SetSRID(ST_MakePoint({row['x']}, {row['y']}), 4326)) "
            f"on conflict (id) do nothing;"
        )

    for u, v, name, geom in edge_rows:
        out.append(
            f"insert into street_edges (source_node, target_node, name, geom) values "
            f"({u}, {v}, {sql_str(name)}, ST_GeomFromText('{geom.wkt}', 4326));"
        )

    out.append("commit;")

    with open(OUT_SQL, "w", encoding="utf-8") as f:
        f.write("\n".join(out))

    print(f"Hotovo: {len(used_nodes)} uzlů, {len(edge_rows)} hran -> {OUT_SQL}")


if __name__ == "__main__":
    main()
