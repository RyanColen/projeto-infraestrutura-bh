#!/usr/bin/env python3
"""Cria cópias EWKT dos CSVs originais, preservando os arquivos brutos.

O script apenas prefixa a coluna GEOMETRIA com SRID=31983;. Ele não altera
coordenadas nem corrige topologia. A correção de polígonos é executada no
PostGIS pelo sql/dados.sql, com ST_MakeValid e extração de componentes poligonais.
"""
from pathlib import Path
import csv

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "dados" / "brutos"
OUT = ROOT / "dados" / "tratados"
FILES = [
    "20240902_bairro_popular.csv",
    "20260504_trecho_logradouro.csv",
    "20260504_rede_assistencia_saude.csv",
]


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for filename in FILES:
        source = RAW / filename
        target = OUT / filename.replace(".csv", "_ewkt.csv")
        if not source.is_file():
            raise FileNotFoundError(f"Arquivo de origem não encontrado: {source}")

        with source.open("r", encoding="utf-8-sig", newline="") as fin:
            reader = csv.DictReader(fin, delimiter=";")
            if not reader.fieldnames or "GEOMETRIA" not in reader.fieldnames:
                raise ValueError(f"Coluna GEOMETRIA não encontrada em {filename}")
            with target.open("w", encoding="utf-8", newline="") as fout:
                writer = csv.DictWriter(
                    fout,
                    fieldnames=reader.fieldnames,
                    delimiter=";",
                    quotechar='"',
                    quoting=csv.QUOTE_MINIMAL,
                    lineterminator="\n",
                )
                writer.writeheader()
                count = 0
                for row in reader:
                    wkt = (row.get("GEOMETRIA") or "").strip()
                    if not wkt:
                        raise ValueError(f"Geometria vazia em {filename}, linha {count + 2}")
                    if not wkt.upper().startswith("SRID="):
                        row["GEOMETRIA"] = f"SRID=31983;{wkt}"
                    writer.writerow(row)
                    count += 1
        print(f"{target.relative_to(ROOT)}: {count} registros")


if __name__ == "__main__":
    main()
