-- ============================================================
-- Carga reproduzível dos dados em banco recém-criado.
-- Execute com psql a partir da raiz do repositório:
-- psql -h localhost -p 5432 -U postgres -d infraestrutura_bh -v ON_ERROR_STOP=1 -f sql/dados.sql
-- Este arquivo usa \\copy (comando do cliente psql), não o Query Tool do pgAdmin.
-- Os CSVs tratados contêm EWKT com SRID=31983; as fontes brutas são preservadas.
-- ============================================================

\set ON_ERROR_STOP on
BEGIN;
SET client_encoding = 'UTF8';

-- Tabelas temporárias para receber os CSVs. São descartadas ao final da transação.
CREATE TEMP TABLE carga_bairros (
    "ID" INTEGER,
    "CODIGO" INTEGER,
    "NOME" TEXT,
    "AREA_KM2" NUMERIC,
    "PERIMETR_M" NUMERIC,
    "GEOMETRIA" TEXT
) ON COMMIT DROP;

CREATE TEMP TABLE carga_vias (
    "ID_TRECHO_LOGRADOURO" INTEGER,
    "ID_LOGRADOURO" INTEGER,
    "SIGLA_TIPO_LOGRADOURO" TEXT,
    "DESC_SIGLA_TIPO_LOGRAD" TEXT,
    "NOME_LOGRADOURO" TEXT,
    "COMPRIMENTO" NUMERIC,
    "LARGURA" NUMERIC,
    "SITUACAO" TEXT,
    "GEOMETRIA" TEXT
) ON COMMIT DROP;

CREATE TEMP TABLE carga_saude (
    "ID_EQ_SAUDE" INTEGER,
    "CATEGORIA" TEXT,
    "SIGLA_CATEGORIA" TEXT,
    "NOME" TEXT,
    "TIPO_LOGRADOURO" TEXT,
    "LOGRADOURO" TEXT,
    "NUMERO_IMOVEL" INTEGER,
    "TELEFONE" TEXT,
    "NOME_BAIRRO_POPULAR" TEXT,
    "GEOMETRIA" TEXT
) ON COMMIT DROP;

-- Importação dos arquivos EWKT. Caminhos relativos à raiz do repositório.
\copy carga_bairros ("ID", "CODIGO", "NOME", "AREA_KM2", "PERIMETR_M", "GEOMETRIA") FROM 'dados/tratados/20240902_bairro_popular_ewkt.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', NULL '', ENCODING 'UTF8')
\copy carga_vias ("ID_TRECHO_LOGRADOURO", "ID_LOGRADOURO", "SIGLA_TIPO_LOGRADOURO", "DESC_SIGLA_TIPO_LOGRAD", "NOME_LOGRADOURO", "COMPRIMENTO", "LARGURA", "SITUACAO", "GEOMETRIA") FROM 'dados/tratados/20260504_trecho_logradouro_ewkt.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', NULL '', ENCODING 'UTF8')
\copy carga_saude ("ID_EQ_SAUDE", "CATEGORIA", "SIGLA_CATEGORIA", "NOME", "TIPO_LOGRADOURO", "LOGRADOURO", "NUMERO_IMOVEL", "TELEFONE", "NOME_BAIRRO_POPULAR", "GEOMETRIA") FROM 'dados/tratados/20260504_rede_assistencia_saude_ewkt.csv' WITH (FORMAT csv, HEADER true, DELIMITER ';', NULL '', ENCODING 'UTF8')

-- Pré-condições: contagens esperadas, identificadores únicos e banco de destino vazio.
DO $$
BEGIN
    IF (SELECT COUNT(*) FROM carga_bairros) <> 493 THEN
        RAISE EXCEPTION 'Carga de bairros: esperado 493 registros.';
    END IF;
    IF (SELECT COUNT(*) FROM carga_vias) <> 55143 THEN
        RAISE EXCEPTION 'Carga de vias: esperado 55143 registros.';
    END IF;
    IF (SELECT COUNT(*) FROM carga_saude) <> 398 THEN
        RAISE EXCEPTION 'Carga de saúde: esperado 398 registros.';
    END IF;
    IF EXISTS (SELECT 1 FROM carga_bairros GROUP BY "CODIGO" HAVING COUNT(*) > 1) THEN
        RAISE EXCEPTION 'Há CODIGO duplicado em carga_bairros.';
    END IF;
    IF EXISTS (SELECT 1 FROM carga_vias GROUP BY "ID_TRECHO_LOGRADOURO" HAVING COUNT(*) > 1) THEN
        RAISE EXCEPTION 'Há ID_TRECHO_LOGRADOURO duplicado em carga_vias.';
    END IF;
    IF EXISTS (SELECT 1 FROM carga_saude GROUP BY "ID_EQ_SAUDE" HAVING COUNT(*) > 1) THEN
        RAISE EXCEPTION 'Há ID_EQ_SAUDE duplicado em carga_saude.';
    END IF;
    IF (SELECT COUNT(*) FROM public.bairros) <> 0
       OR (SELECT COUNT(*) FROM public.vias) <> 0
       OR (SELECT COUNT(*) FROM public.equipamentos_saude) <> 0 THEN
        RAISE EXCEPTION 'As tabelas de destino devem estar vazias. Use um banco limpo.';
    END IF;
END $$;

-- 1. Bairros: corrige topologia, extrai somente componentes poligonais e normaliza para MultiPolygon.
INSERT INTO public.bairros (
    codigo, id_origem, nome, area_km2, perimetro_m, geom
)
SELECT
    c."CODIGO",
    c."ID",
    c."NOME",
    c."AREA_KM2",
    c."PERIMETR_M",
    ST_Multi(
        ST_CollectionExtract(
            ST_MakeValid(ST_GeomFromEWKT(c."GEOMETRIA")),
            3
        )
    )::geometry(MultiPolygon, 31983)
FROM carga_bairros c;

-- 2. Vias: todos os registros da fonte são LineString.
INSERT INTO public.vias (
    id_trecho_logradouro,
    id_logradouro,
    sigla_tipo_logradouro,
    descricao_tipo_logradouro,
    nome_logradouro,
    comprimento,
    largura,
    situacao,
    geom
)
SELECT
    c."ID_TRECHO_LOGRADOURO",
    c."ID_LOGRADOURO",
    c."SIGLA_TIPO_LOGRADOURO",
    c."DESC_SIGLA_TIPO_LOGRAD",
    c."NOME_LOGRADOURO",
    c."COMPRIMENTO",
    c."LARGURA",
    c."SITUACAO",
    ST_GeomFromEWKT(c."GEOMETRIA")::geometry(LineString, 31983)
FROM carga_vias c;

-- Antes da associação dos pontos, exige exatamente um bairro por equipamento,
-- considerando ST_Covers e a concordância do nome cadastral.
DO $$
DECLARE problemas INTEGER;
BEGIN
    SELECT COUNT(*) INTO problemas
    FROM (
        SELECT s."ID_EQ_SAUDE"
        FROM carga_saude s
        LEFT JOIN public.bairros b
          ON ST_Covers(b.geom, ST_GeomFromEWKT(s."GEOMETRIA"))
         AND UPPER(BTRIM(b.nome)) = UPPER(BTRIM(s."NOME_BAIRRO_POPULAR"))
        GROUP BY s."ID_EQ_SAUDE"
        HAVING COUNT(b.codigo) <> 1
    ) q;

    IF problemas <> 0 THEN
        RAISE EXCEPTION '% equipamentos não tiveram exatamente um bairro correspondente.', problemas;
    END IF;
END $$;

-- 3. Equipamentos: o telefone vazio no CSV é convertido em NULL pelo \copy.
INSERT INTO public.equipamentos_saude (
    id_eq_saude,
    categoria,
    sigla_categoria,
    nome,
    tipo_logradouro,
    logradouro,
    numero_imovel,
    telefone,
    nome_bairro_popular,
    codigo_bairro,
    geom
)
SELECT
    s."ID_EQ_SAUDE",
    s."CATEGORIA",
    s."SIGLA_CATEGORIA",
    s."NOME",
    s."TIPO_LOGRADOURO",
    s."LOGRADOURO",
    s."NUMERO_IMOVEL",
    NULLIF(BTRIM(s."TELEFONE"), ''),
    s."NOME_BAIRRO_POPULAR",
    b.codigo,
    ST_GeomFromEWKT(s."GEOMETRIA")::geometry(Point, 31983)
FROM carga_saude s
JOIN public.bairros b
  ON ST_Covers(b.geom, ST_GeomFromEWKT(s."GEOMETRIA"))
 AND UPPER(BTRIM(b.nome)) = UPPER(BTRIM(s."NOME_BAIRRO_POPULAR"));

ANALYZE public.bairros;
ANALYZE public.vias;
ANALYZE public.equipamentos_saude;

COMMIT;

-- Resumo pós-carga.
SELECT 'bairros' AS tabela, COUNT(*) AS registros FROM public.bairros
UNION ALL
SELECT 'vias', COUNT(*) FROM public.vias
UNION ALL
SELECT 'equipamentos_saude', COUNT(*) FROM public.equipamentos_saude
ORDER BY tabela;
