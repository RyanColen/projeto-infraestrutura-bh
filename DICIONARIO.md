# Dicionário de dados — Infraestrutura urbana de Belo Horizonte (MG)

## 1. Visão geral

| Item | Descrição |
|---|---|
| Título | Mapeamento da infraestrutura urbana e dos equipamentos públicos de saúde de Belo Horizonte (MG) |
| Finalidade | Organizar limites de bairros, trechos de logradouro e equipamentos de saúde em uma base PostGIS para consultas e análises espaciais. |
| Cobertura espacial | Município de Belo Horizonte, Minas Gerais, Brasil. |
| Cobertura temporal | Retratos de versões distintas: bairros (arquivo de 02/09/2024), trechos de logradouro (04/05/2026) e rede de assistência à saúde (04/05/2026). Não constitui série histórica. |
| Fontes | Portal de Dados Abertos da Prefeitura de Belo Horizonte (PBH). URLs e atribuições em `DADOS-LICENCA.md`. |
| Data efetiva de download | 25 de novembro de 2026. |
| Formato de origem | CSV UTF-8, delimitador ponto e vírgula (`;`), geometrias WKT na coluna `GEOMETRIA`, sem SRID embutido. |
| SRID final | **EPSG:31983 — SIRGAS 2000 / UTM zone 23S**. Os metadados consultados para as três camadas indicam esse SRC. É projetado em metros e adequado para medições locais em Belo Horizonte. |
| Licença dos dados | As páginas dos três conjuntos indicam Creative Commons Attribution, sem especificar versão numérica. Ver `DADOS-LICENCA.md`; não presumir CC BY 4.0. |
| Precisão/escala | Não especificadas nos metadados consultados. Não inferir precisão posicional pelo número de casas decimais. |
| Ambiente observado | QGIS 3.44.15; PostgreSQL 17; PostGIS 3.7.0; GEOS 3.15.0; PROJ 9.8.1. Registrar a versão exata do servidor antes da entrega final, se exigida. |

## 2. Fontes dos dados

| Tabela final | Conjunto | Arquivo original | Órgão indicado | Página do conjunto |
|---|---|---|---|---|
| `bairros` | Bairro Popular — Lei 11.490/2023 | `20240902_bairro_popular.csv` | SMPU / Prodabel (mantenedor do recurso) | [Bairro Popular](https://dados.pbh.gov.br/dataset/bairro-popular) |
| `vias` | Trecho Logradouro | `20260504_trecho_logradouro.csv` | Prodabel | [Trecho Logradouro](https://dados.pbh.gov.br/dataset/trecho-logradouro-2) |
| `equipamentos_saude` | Rede de Assistência Saúde | `20260504_rede_assistencia_saude.csv` | Secretaria Municipal de Saúde (SMSA) | [Rede de Assistência Saúde](https://dados.pbh.gov.br/dataset/rede-de-assistencia-saude) |

## 3. Tratamentos aplicados e convenções

1. Os CSVs originais foram preservados em `dados/brutos/`.
2. As camadas foram carregadas no QGIS com UTF-8, separador `;`, campo WKT `GEOMETRIA` e SRC EPSG:31983.
3. Foram criadas cópias GeoPackage para tratamento.
4. A camada de bairros continha 3 geometrias inválidas. Foi executado **Corrigir geometrias** no QGIS, método **Estrutura**. A saída foi novamente validada: 493 válidas, 0 inválidas e 0 erros.
5. As vias foram verificadas com **Check Validity** (GEOS): 55.143 válidas, 0 inválidas e 0 erros.
6. Os equipamentos de saúde foram verificados com **Check Validity** (GEOS): 398 válidos, 0 inválidos e 0 erros.
7. A expressão `$geometry IS NULL OR is_empty($geometry)` selecionou zero feições em cada uma das três camadas.
8. O destino foi padronizado para nomes minúsculos em `snake_case`, texto UTF-8 e geometrias tipadas: `MultiPolygon`, `LineString` e `Point`, todas com SRID 31983.
9. Os 207 telefones ausentes foram mantidos como `NULL`; não houve preenchimento artificial.
10. Os 398 equipamentos de saúde foram associados a exatamente um bairro usando `ST_Covers` e conferência de igualdade do nome normalizado (`UPPER(BTRIM(...))`). Os 398 nomes coincidiram com o bairro espacial.
11. Os trechos de vias que não intersectam diretamente qualquer bairro foram mantidos. A verificação espacial preliminar encontrou 84 trechos sem interseção; eles não foram excluídos.
12. No bairro Vila Real I (código 1458), a via mais próxima identificada foi “VILA REAL”, a aproximadamente 0,14 m do limite; não houve interseção direta. As geometrias foram mantidas sem deslocamento artificial.
13. A tabela final `vias` armazena `LINESTRING` (a fonte contém 55.143 `LINESTRING`); a tabela final `bairros` armazena `MULTIPOLYGON`; a tabela final `equipamentos_saude` armazena `POINT`.

## 4. Tabelas espaciais

### 4.1 `bairros`

Limites dos bairros populares de Belo Horizonte.

- Geometria: `geometry(MultiPolygon, 31983)`.
- Registros finais: **493**.
- Atributos não geométricos: 5.
- Chave primária: `codigo`.
- Restrição única: `id_origem`.

| Coluna | Tipo | Tamanho/domínio | Nulo? | PK/FK | Descrição | Exemplo |
|---|---|---|---|---|---|---|
| `codigo` | integer | código da PBH; 493 valores distintos | Não | PK | Código publicado para bairro/conjunto/vila. | 1464 |
| `id_origem` | integer | identificador original; 493 valores distintos | Não | UNIQUE | Campo `ID` do arquivo de origem. | 455 |
| `nome` | varchar(60) | máximo observado: 31 caracteres | Não | — | Nome do bairro, conjunto ou vila. | Vila Santo Antônio Barroquinha |
| `area_km2` | numeric(12,3) | km²; origem: 0,001 a 17,377; não negativo | Não | — | Área informada pela fonte. | 0,033 |
| `perimetro_m` | numeric(12,3) | metros; origem: 150,595 a 26.926,686; não negativo | Não | — | Perímetro informado pela fonte. | 1264,788 |
| `geom` | geometry(MultiPolygon,31983) | MULTIPOLYGON; SRID 31983 | Não | — | Limite espacial do bairro. | MULTIPOLYGON(...) |

**Qualidade:** 493 geometrias válidas após correção; zero geometrias nulas ou vazias na verificação final do QGIS/PostGIS.

### 4.2 `vias`

Trechos lineares de logradouros. Um mesmo logradouro pode possuir vários trechos.

- Geometria: `geometry(LineString, 31983)`.
- Registros finais: **55.143**.
- Atributos não geométricos: 8.
- Chave primária: `id_trecho_logradouro`.

| Coluna | Tipo | Tamanho/domínio | Nulo? | PK/FK | Descrição | Exemplo |
|---|---|---|---|---|---|---|
| `id_trecho_logradouro` | integer | identificador único da fonte; 55.143 valores distintos | Não | PK | Identificador do trecho de logradouro. | 50722 |
| `id_logradouro` | integer | identificador de logradouro; pode se repetir | Não | — | Identifica o logradouro ao qual o trecho pertence. | 17707 |
| `sigla_tipo_logradouro` | varchar(10) | 17 siglas observadas; máximo 3 caracteres | Não | — | Sigla do tipo de logradouro. | BEC |
| `descricao_tipo_logradouro` | varchar(30) | máximo observado: 15 caracteres | Não | — | Descrição da sigla do tipo de logradouro. | BECO |
| `nome_logradouro` | varchar(100) | máximo observado: 50 caracteres | Não | — | Nome do logradouro. | JOSIAS |
| `comprimento` | numeric(12,3) | metros; origem: 0,067 a 3.897,841; não negativo | Não | — | Comprimento informado para o trecho. | 16,043 |
| `largura` | numeric(8,2) | metros; origem: 0,50 a 96,60; não negativo | Não | — | Largura informada para o trecho. | 2,00 |
| `situacao` | varchar(20) | domínio observado: `Real`, `Interno` | Não | — | Situação/classificação do trecho conforme a fonte. | Real |
| `geom` | geometry(LineString,31983) | LINESTRING; SRID 31983 | Não | — | Traçado espacial do trecho. | LINESTRING(...) |

**Domínios observados:** `situacao`: Real (54.990 registros), Interno (153). `id_logradouro` possui 16.641 valores distintos; sua repetição é esperada porque um logradouro pode ser composto por vários trechos.

**Qualidade:** 55.143 geometrias válidas; zero geometrias nulas ou vazias. Na verificação de interseção espacial com bairros, 84 trechos não tiveram interseção direta; foram mantidos para rastreabilidade.

### 4.3 `equipamentos_saude`

Estabelecimentos e serviços da rede municipal de assistência à saúde representados por pontos.

- Geometria: `geometry(Point, 31983)`.
- Registros finais: **398**.
- Atributos não geométricos: 10 (inclui `codigo_bairro`, derivado no projeto).
- Chave primária: `id_eq_saude`.
- Chave estrangeira: `codigo_bairro` → `bairros.codigo`.

| Coluna | Tipo | Tamanho/domínio | Nulo? | PK/FK | Descrição | Exemplo |
|---|---|---|---|---|---|---|
| `id_eq_saude` | integer | identificador de origem; 398 valores distintos | Não | PK | Identificador do equipamento de saúde. | 230 |
| `categoria` | varchar(100) | 29 categorias; máximo observado: 64 caracteres | Não | — | Categoria do equipamento. | CENTRO DE SAUDE |
| `sigla_categoria` | varchar(30) | siglas/códigos de categoria; máximo: 19 caracteres | Não | — | Sigla ou identificação abreviada da categoria. | CTR |
| `nome` | varchar(120) | máximo observado: 85 caracteres | Não | — | Nome do estabelecimento/serviço. | LABORATORIO DE INFECCOES SEXUALMENTE TRANSMISSIVEIS |
| `tipo_logradouro` | varchar(10) | tipo de logradouro; máximo: 3 caracteres | Não | — | Tipo de logradouro do endereço. | ALA |
| `logradouro` | varchar(100) | máximo observado: 39 caracteres | Não | — | Nome do logradouro do endereço. | VEREADOR ALVARO CELSO |
| `numero_imovel` | integer | números observados: 1 a 16.950 | Não | — | Número do imóvel informado no cadastro. | 241 |
| `telefone` | varchar(40) | máximo observado: 38 caracteres | Sim | — | Telefone de contato informado pela fonte. | NULL |
| `nome_bairro_popular` | varchar(60) | máximo observado: 29 caracteres | Não | — | Nome do bairro informado no cadastro de saúde. | SANTA EFIGÊNIA |
| `codigo_bairro` | integer | referência a `bairros.codigo` | Sim* | FK | Código do bairro associado por relação espacial e conferência do nome. | 765 |
| `geom` | geometry(Point,31983) | POINT; SRID 31983 | Não | — | Localização pontual do equipamento. | POINT(611953.89 7796661.73) |

\* A coluna foi criada como anulável no esquema atual; após a carga, os 398 registros possuem `codigo_bairro` preenchido e a FK não apresenta órfãos.

**Qualidade:** 398 geometrias válidas; zero nulas ou vazias. O campo `telefone` contém 207 valores nulos. Todos os 398 pontos foram associados a exatamente um bairro por `ST_Covers`, e os nomes coincidiram com `nome_bairro_popular`.

## 5. Relacionamentos

| Origem | Destino | Tipo | Regra/descrição |
|---|---|---|---|
| `equipamentos_saude.codigo_bairro` | `bairros.codigo` | FK 1:N | Cada equipamento pode estar associado a zero ou um bairro por meio da chave estrangeira `codigo_bairro`. Na carga atual, os 398 equipamentos possuem associação com exatamente um bairro. Um bairro pode estar associado a vários equipamentos. |
| `vias.geom` | `bairros.geom` | Espacial N:N | `ST_Intersects(vias.geom, bairros.geom)`. Uma via pode atravessar mais de um bairro, e um bairro contém vários trechos. 84 trechos não tiveram interseção direta na verificação efetuada. |

## 6. Índices e restrições

- Chaves primárias: `bairros.codigo`, `vias.id_trecho_logradouro`, `equipamentos_saude.id_eq_saude`.
- Restrição `UNIQUE`: `bairros.id_origem`.
- Chave estrangeira: `equipamentos_saude.codigo_bairro` → `bairros.codigo`.
- `CHECK`: áreas e medidas não negativas; geometrias válidas e não vazias.
- Índices espaciais GiST: `idx_bairros_geom`, `idx_vias_geom`, `idx_saude_geom`.
- Índice B-tree da FK: `idx_saude_codigo_bairro`.

## 7. Resultados exploratórios e limitações

Uma consulta espacial de exemplo retornou 493 bairros, com contagem de equipamentos e soma do comprimento das interseções dos trechos de vias com cada polígono. Nos dados consultados, 195 bairros tinham ao menos um equipamento e 298 não tinham equipamento cadastrado. Padre Eustáquio tinha 14 registros e Sagrada Família 11. Esses números descrevem o cadastro utilizado, não a disponibilidade ou capacidade real de atendimento.

A soma de comprimentos por bairro é exploratória: não representa uma rede viária topológica dissolvida e segmentos coincidentes com limites podem contribuir em mais de um polígono. A ausência de interseção direta de um trecho com um bairro não prova ausência de via no terreno. No caso de Vila Real I (código 1458), o trecho “VILA REAL” mais próximo estava a cerca de 0,14 m do limite, sem interseção geométrica. Os dados foram mantidos sem deslocamentos artificiais.

Os 207 telefones nulos permaneceram sem preenchimento. Pontos coincidentes foram preservados, pois equipamentos distintos podem compartilhar um endereço. A precisão posicional e a escala de produção não foram informadas nos metadados consultados.
