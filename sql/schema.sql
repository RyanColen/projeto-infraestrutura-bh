-- ============================================================
-- Projeto: Infraestrutura urbana de Belo Horizonte (MG)
-- PostgreSQL 17 / PostGIS 3.7.0
-- SRID: 31983 - SIRGAS 2000 / UTM zone 23S
-- Execute em um banco de dados vazio.
-- ============================================================

CREATE EXTENSION IF NOT EXISTS postgis;

-- 1. Bairros: limite territorial (polígono/multipolígono).
CREATE TABLE public.bairros (
    codigo          INTEGER PRIMARY KEY,
    id_origem       INTEGER NOT NULL UNIQUE,
    nome            VARCHAR(60) NOT NULL,
    area_km2        NUMERIC(12,3) NOT NULL,
    perimetro_m     NUMERIC(12,3) NOT NULL,
    geom            geometry(MultiPolygon, 31983) NOT NULL,
    CONSTRAINT chk_bairros_area
        CHECK (area_km2 >= 0),
    CONSTRAINT chk_bairros_perimetro
        CHECK (perimetro_m >= 0),
    CONSTRAINT chk_bairros_geom_valida
        CHECK (ST_IsValid(geom)),
    CONSTRAINT chk_bairros_geom_vazia
        CHECK (NOT ST_IsEmpty(geom))
);

-- 2. Vias: trechos de logradouro (linha).
CREATE TABLE public.vias (
    id_trecho_logradouro      INTEGER PRIMARY KEY,
    id_logradouro             INTEGER NOT NULL,
    sigla_tipo_logradouro     VARCHAR(10) NOT NULL,
    descricao_tipo_logradouro VARCHAR(30) NOT NULL,
    nome_logradouro           VARCHAR(100) NOT NULL,
    comprimento               NUMERIC(12,3) NOT NULL,
    largura                   NUMERIC(8,2) NOT NULL,
    situacao                  VARCHAR(20) NOT NULL,
    geom                      geometry(LineString, 31983) NOT NULL,
    CONSTRAINT chk_vias_comprimento
        CHECK (comprimento >= 0),
    CONSTRAINT chk_vias_largura
        CHECK (largura >= 0),
    CONSTRAINT chk_vias_geom_valida
        CHECK (ST_IsValid(geom)),
    CONSTRAINT chk_vias_geom_vazia
        CHECK (NOT ST_IsEmpty(geom))
);

-- 3. Equipamentos de saúde: localização pontual.
CREATE TABLE public.equipamentos_saude (
    id_eq_saude          INTEGER PRIMARY KEY,
    categoria            VARCHAR(100) NOT NULL,
    sigla_categoria      VARCHAR(30) NOT NULL,
    nome                 VARCHAR(120) NOT NULL,
    tipo_logradouro      VARCHAR(10) NOT NULL,
    logradouro           VARCHAR(100) NOT NULL,
    numero_imovel        INTEGER NOT NULL,
    telefone             VARCHAR(40),
    nome_bairro_popular  VARCHAR(60) NOT NULL,
    codigo_bairro        INTEGER,
    geom                 geometry(Point, 31983) NOT NULL,
    CONSTRAINT fk_saude_bairro
        FOREIGN KEY (codigo_bairro)
        REFERENCES public.bairros (codigo),
    CONSTRAINT chk_saude_geom_valida
        CHECK (ST_IsValid(geom)),
    CONSTRAINT chk_saude_geom_vazia
        CHECK (NOT ST_IsEmpty(geom))
);

-- Índices espaciais GiST.
CREATE INDEX idx_bairros_geom
    ON public.bairros USING GIST (geom);

CREATE INDEX idx_vias_geom
    ON public.vias USING GIST (geom);

CREATE INDEX idx_saude_geom
    ON public.equipamentos_saude USING GIST (geom);

-- Índice convencional para consultas/joins pela FK.
CREATE INDEX idx_saude_codigo_bairro
    ON public.equipamentos_saude (codigo_bairro);

-- Metadados descritivos no catálogo do PostgreSQL.
COMMENT ON TABLE public.bairros IS
    'Limites dos bairros populares de Belo Horizonte; fonte PBH.';
COMMENT ON COLUMN public.bairros.codigo IS
    'Código do bairro publicado pela fonte; chave primária desta base.';
COMMENT ON COLUMN public.bairros.id_origem IS
    'Identificador ID do registro no arquivo original da PBH.';
COMMENT ON COLUMN public.bairros.geom IS
    'Limite do bairro em MultiPolygon, EPSG:31983.';

COMMENT ON TABLE public.vias IS
    'Trechos de logradouros de Belo Horizonte; fonte PBH/Prodabel.';
COMMENT ON COLUMN public.vias.id_trecho_logradouro IS
    'Identificador único do trecho de logradouro na fonte.';
COMMENT ON COLUMN public.vias.id_logradouro IS
    'Identificador do logradouro ao qual o trecho pertence; pode se repetir.';
COMMENT ON COLUMN public.vias.geom IS
    'Geometria linear do trecho, EPSG:31983.';

COMMENT ON TABLE public.equipamentos_saude IS
    'Equipamentos da rede de assistência à saúde de Belo Horizonte; fonte PBH/SMSA.';
COMMENT ON COLUMN public.equipamentos_saude.codigo_bairro IS
    'Código do bairro associado por ST_Covers e conferência do nome do bairro.';
COMMENT ON COLUMN public.equipamentos_saude.geom IS
    'Localização pontual do equipamento, EPSG:31983.';
