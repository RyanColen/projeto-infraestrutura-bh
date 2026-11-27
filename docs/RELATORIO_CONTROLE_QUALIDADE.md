# Relatório de controle de qualidade — versão final do ambiente de desenvolvimento

**Projeto:** Mapeamento da infraestrutura urbana de Belo Horizonte (MG)  
**Software observado:** QGIS 3.44.15; PostgreSQL 17; PostGIS 3.7.0; GEOS 3.15.0; PROJ 9.8.1  
**SRC:** EPSG:31983 — SIRGAS 2000 / UTM zone 23S

> Este relatório registra os resultados visualizados no QGIS e no pgAdmin durante a montagem do banco de desenvolvimento. O teste de reconstrução em banco limpo já foi realizado:

Banco: infraestrutura_bh_teste.  
PostgreSQL: 17.  
PostGIS: 3.7.0.  
Execução de schema.sql: concluída.  
Execução de dados.sql: concluída.  
Execução de consultas.sql: concluída.  
Contagens verificadas: 493 bairros, 55.143 vias e 398 equipamentos.

## 1. Volume e tipos geométricos

| Tabela final | Registros | Tipo geométrico | SRID |
|---|---:|---|---:|
| `bairros` | 493 | MULTIPOLYGON | 31983 |
| `vias` | 55.143 | LINESTRING | 31983 |
| `equipamentos_saude` | 398 | POINT | 31983 |
| **Total** | **56.034** | **3 tipos** | **31983** |

O mínimo do exercício (3 tabelas espaciais, 2 tipos geométricos e 500 feições) é atendido.

## 2. Validade geométrica no QGIS

Foi utilizada a ferramenta **Geometria do vetor → Check validity**, método **GEOS**.

| Camada verificada | Válidas | Inválidas | Erros |
|---|---:|---:|---:|
| `bairros_corrigidos` | 493 | 0 | 0 |
| `vias_tratadas` | 55.143 | 0 | 0 |
| `equipamentos_saude_tratados` | 398 | 0 | 0 |

Na camada de bairros, a primeira verificação identificou 490 válidas, 3 inválidas e 3 erros. A camada foi processada com **Corrigir geometrias**, método **Estrutura**, preservando as 493 feições. A nova verificação resultou em 493 válidas, 0 inválidas e 0 erros.

As três geometrias originalmente sinalizadas por auto-interseção eram Jardim Liberdade (ID de origem 646), Morro dos Macacos (ID 351) e Bonsucesso (ID 220). Vias e equipamentos de saúde já estavam válidos e não precisaram de correção.

## 3. Verificação de geometrias nulas e vazias

No QGIS foi aplicada a expressão de seleção:

```qgis
$geometry IS NULL OR is_empty($geometry)
```

Resultado observado em cada tabela: **0 feições selecionadas**.

| Camada | Total | Selecionadas como nulas/vazias |
|---|---:|---:|
| `bairros_corrigidos` | 493 | 0 |
| `vias_tratadas` | 55.143 | 0 |
| `equipamentos_saude_tratados` | 398 | 0 |

## 4. Verificações de atributos e chaves

### 4.1 Bairros (tabela intermediária)

| Verificação | Resultado |
|---|---:|
| Registros | 493 |
| IDs nulos | 0 |
| Códigos nulos | 0 |
| Nomes ausentes | 0 |
| Áreas nulas | 0 |
| Perímetros nulos | 0 |
| Geometrias ausentes | 0 |
| Nomes acima de 60 caracteres | 0 |
| Códigos duplicados | 0 |
| IDs duplicados (conferência adicional) | 0 |
| Medidas negativas | 0 |

### 4.2 Vias (tabela intermediária)

Foram conferidos os 55.143 registros: identificador de trecho nulo/duplicado, ID de logradouro nulo, sigla/descrição/nome ausentes, comprimento/largura nulos ou negativos, situação ausente, geometria nula/vazia/inválida, tipo/SRID fora do padrão e textos maiores que os comprimentos definidos. **Todos os contadores de problema foram 0.**

Domínio `situacao`: Real = 54.990; Interno = 153. `id_logradouro` pode se repetir, pois um logradouro pode conter vários trechos.

### 4.3 Equipamentos de saúde (tabela intermediária)

| Verificação | Resultado |
|---|---:|
| Registros | 398 |
| ID nulo | 0 |
| IDs duplicados | 0 |
| Categoria, sigla ou nome ausente | 0 |
| Tipo de logradouro ou logradouro ausente | 0 |
| Número de imóvel inválido | 0 |
| Bairro ausente | 0 |
| Geometria inválida | 0 |
| Tipo/SRID fora do padrão | 0 |
| Textos acima dos limites | 0 |
| Telefones nulos | 207 |

Os 207 telefones nulos foram preservados como ausentes, sem preenchimento artificial.

## 5. Relacionamento equipamento de saúde–bairro

A verificação usou `ST_Covers(b.geom, s.geom)` e a igualdade dos nomes normalizados (`UPPER(BTRIM(...))`). Resultado na tabela intermediária:

| Indicador | Resultado |
|---|---:|
| Total de equipamentos | 398 |
| Sem bairro espacial | 0 |
| Mais de um bairro espacial | 0 |
| Bairro e nome compatíveis | 398 |
| Sem correspondência | 0 |

Os 398 registros foram inseridos na tabela final `equipamentos_saude`, preenchendo `codigo_bairro`, FK para `bairros.codigo`. A conferência posterior indicou 398 equipamentos, zero sem bairro e zero referências a bairro inexistente.

## 6. Relação espacial vias–bairros

A relação foi analisada com `ST_Intersects`. A inspeção preliminar encontrou 84 trechos sem interseção direta com qualquer polígono de bairro. Eles foram mantidos; não se conclui, apenas por esse teste, que não exista via no local.

Caso específico: Vila Real I (código 1458) apresentou zero trechos intersectando o polígono. A via mais próxima foi o trecho de nome “VILA REAL” (ID de trecho 30086), a cerca de **0,14 m** do limite. A busca por distância encontrou um trecho a até 0,5 m e um trecho a até 1 m. Nenhuma geometria foi deslocada ou ajustada artificialmente.

## 7. Índices e restrições confirmados no PostgreSQL

A consulta ao catálogo do PostgreSQL mostrou 8 índices nas três tabelas:

- `bairros_pkey` e `bairros_id_origem_key`;
- `idx_bairros_geom` (GiST);
- `vias_pkey` e `idx_vias_geom` (GiST);
- `equipamentos_saude_pkey`, `idx_saude_geom` (GiST) e `idx_saude_codigo_bairro` (B-tree).

Foram identificadas 15 restrições: 3 PK, 1 UNIQUE, 1 FK e 10 CHECK (medidas não negativas; geometria válida e não vazia). A FK é `equipamentos_saude.codigo_bairro` → `bairros.codigo`.

## 8. Carga final

As tabelas intermediárias criadas durante o trabalho foram carregadas pelo QGIS no esquema `public` e contadas no pgAdmin: 493 `stg_bairros`, 55.143 `stg_vias`, 398 `stg_equipamentos_saude`. Os registros foram transferidos para as tabelas definitivas e as contagens finais foram conferidas. Total: **56.034**.

## 9. Limitações

- Os conjuntos têm datas de referência diferentes (2024 para bairros; 2026 para vias e saúde).
- Os metadados consultados não especificam escala/precisão posicional.
- Os 207 telefones ausentes não permitem contato telefônico a partir dessa base.
- Pontos coincidentes podem corresponder a serviços distintos no mesmo endereço e foram preservados.
- A extensão das vias por bairro, calculada por interseção, é um indicador exploratório e pode contar segmentos de limite em mais de um polígono; não equivale a uma rede dissolvida/topológica.
