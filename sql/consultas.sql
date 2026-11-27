-- ============================================================
-- Consultas de exemplo - Infraestrutura urbana de Belo Horizonte
-- Execute conectada ao banco infraestrutura_bh.
-- SRID: 31983 (unidades lineares em metros).
-- ============================================================

-- 1. Quantidade de registros por tabela.
SELECT 'bairros' AS tabela, COUNT(*) AS registros FROM public.bairros
UNION ALL
SELECT 'vias', COUNT(*) FROM public.vias
UNION ALL
SELECT 'equipamentos_saude', COUNT(*) FROM public.equipamentos_saude
ORDER BY tabela;

-- 2. Tipo, SRID e qualidade geométrica de cada tabela.
SELECT 'bairros' AS tabela,
       GeometryType(geom) AS tipo_geometria,
       ST_SRID(geom) AS srid,
       COUNT(*) AS registros,
       COUNT(*) FILTER (WHERE geom IS NULL) AS geometrias_nulas,
       COUNT(*) FILTER (WHERE ST_IsEmpty(geom)) AS geometrias_vazias,
       COUNT(*) FILTER (WHERE NOT ST_IsValid(geom)) AS geometrias_invalidas
FROM public.bairros
GROUP BY GeometryType(geom), ST_SRID(geom)
UNION ALL
SELECT 'vias', GeometryType(geom), ST_SRID(geom), COUNT(*),
       COUNT(*) FILTER (WHERE geom IS NULL),
       COUNT(*) FILTER (WHERE ST_IsEmpty(geom)),
       COUNT(*) FILTER (WHERE NOT ST_IsValid(geom))
FROM public.vias
GROUP BY GeometryType(geom), ST_SRID(geom)
UNION ALL
SELECT 'equipamentos_saude', GeometryType(geom), ST_SRID(geom), COUNT(*),
       COUNT(*) FILTER (WHERE geom IS NULL),
       COUNT(*) FILTER (WHERE ST_IsEmpty(geom)),
       COUNT(*) FILTER (WHERE NOT ST_IsValid(geom))
FROM public.equipamentos_saude
GROUP BY GeometryType(geom), ST_SRID(geom)
ORDER BY tabela;

-- 3. Quantidade de equipamentos por bairro (inclui bairros sem cadastro).
SELECT b.codigo,
       b.nome AS bairro,
       COUNT(e.id_eq_saude) AS equipamentos_saude
FROM public.bairros b
LEFT JOIN public.equipamentos_saude e
       ON e.codigo_bairro = b.codigo
GROUP BY b.codigo, b.nome
ORDER BY equipamentos_saude DESC, b.nome;

-- 4. Extensão dos trechos de vias calculada dentro de cada polígono.
-- Observação: soma comprimentos das interseções dos trechos fornecidos com cada
-- bairro. Não é uma rede topológica dissolvida; segmentos em limites podem
-- contribuir para mais de um polígono. Use como indicador exploratório.
WITH vias_por_bairro AS (
    SELECT b.codigo,
           SUM(ST_Length(ST_Intersection(v.geom, b.geom))) AS extensao_vias_m
    FROM public.bairros b
    JOIN public.vias v
      ON b.geom && v.geom
     AND ST_Intersects(b.geom, v.geom)
    GROUP BY b.codigo
),
saude_por_bairro AS (
    SELECT codigo_bairro, COUNT(*) AS quantidade
    FROM public.equipamentos_saude
    GROUP BY codigo_bairro
)
SELECT b.codigo,
       b.nome AS bairro,
       COALESCE(s.quantidade, 0) AS equipamentos_saude,
       ROUND(COALESCE(v.extensao_vias_m, 0)::numeric, 2) AS extensao_vias_m
FROM public.bairros b
LEFT JOIN saude_por_bairro s ON s.codigo_bairro = b.codigo
LEFT JOIN vias_por_bairro v ON v.codigo = b.codigo
ORDER BY b.nome;

-- 5. Trechos de logradouro sem interseção direta com qualquer bairro.
-- Não excluir estes registros: investigar e documentar diferenças de cobertura.
SELECT v.id_trecho_logradouro,
       v.id_logradouro,
       v.nome_logradouro
FROM public.vias v
WHERE NOT EXISTS (
    SELECT 1
    FROM public.bairros b
    WHERE b.geom && v.geom
      AND ST_Intersects(b.geom, v.geom)
)
ORDER BY v.id_trecho_logradouro;

-- 6. Cinco trechos mais próximos do bairro Vila Real I (código 1458).
SELECT b.codigo,
       b.nome AS bairro,
       v.id_trecho_logradouro,
       v.nome_logradouro,
       ROUND(ST_Distance(b.geom, v.geom)::numeric, 2) AS distancia_m
FROM public.bairros b
CROSS JOIN LATERAL (
    SELECT id_trecho_logradouro, nome_logradouro, geom
    FROM public.vias
    ORDER BY ST_Distance(geom, b.geom)
    LIMIT 5
) v
WHERE b.codigo = 1458
ORDER BY distancia_m;

-- 7. Equipamentos de saúde a até 1 km de qualquer trecho de via.
-- EPSG:31983 usa metros; ST_DWithin faz a busca em distância planar projetada.
SELECT COUNT(DISTINCT e.id_eq_saude) AS equipamentos_ate_1km_de_uma_via
FROM public.equipamentos_saude e
WHERE EXISTS (
    SELECT 1
    FROM public.vias v
    WHERE ST_DWithin(e.geom, v.geom, 1000)
);

-- 8. Estatística resumida da associação equipamento-bairro.
SELECT COUNT(*) AS total_equipamentos,
       COUNT(*) FILTER (WHERE codigo_bairro IS NULL) AS sem_bairro
FROM public.equipamentos_saude;
