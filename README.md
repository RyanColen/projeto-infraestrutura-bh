# Mapeamento da infraestrutura urbana de Belo Horizonte (MG)

Projeto acadêmico da disciplina **CSI803 — Banco de Dados Geográficos**. A base integra limites de bairros, trechos de logradouro e equipamentos da rede de assistência à saúde de Belo Horizonte, preparados para PostgreSQL/PostGIS.

## 1. Objetivo e escopo

Disponibilizar três tabelas espaciais relacionadas e documentadas, permitindo que outra pessoa recrie o banco, entenda os atributos e execute consultas espaciais sem depender dos autores.

| Tabela | Conteúdo | Geometria | Registros |
|---|---|---|---:|
| `bairros` | Limites dos bairros populares | `MULTIPOLYGON` | 493 |
| `vias` | Trechos de logradouro | `LINESTRING` | 55.143 |
| `equipamentos_saude` | Estabelecimentos/serviços de saúde | `POINT` | 398 |
| **Total** |  | **3 tipos geométricos** | **56.034** |

Área de estudo: Belo Horizonte, Minas Gerais, Brasil. Todos os dados finais usam **EPSG:31983 — SIRGAS 2000 / UTM zone 23S**, em metros.

## 2. Fontes e licença

Os dados foram obtidos no Portal de Dados Abertos da Prefeitura de Belo Horizonte:

| Tabela | Recurso | Arquivo de origem | Página |
|---|---|---|---|
| `bairros` | Bairro Popular — Lei 11.490/2023 | `20240902_bairro_popular.csv` | [PBH](https://dados.pbh.gov.br/dataset/bairro-popular) |
| `vias` | Trecho Logradouro | `20260504_trecho_logradouro.csv` | [PBH](https://dados.pbh.gov.br/dataset/trecho-logradouro-2) |
| `equipamentos_saude` | Rede de Assistência Saúde | `20260504_rede_assistencia_saude.csv` | [PBH](https://dados.pbh.gov.br/dataset/rede-de-assistencia-saude) |

As fichas dos três conjuntos indicam **Creative Commons Attribution**. A versão numérica não foi especificada nas páginas consultadas; este repositório não presume uma versão. Consulte `DADOS-LICENCA.md` antes de redistribuir. `LICENSE` aplica-se somente ao código e aos scripts originais deste repositório.

**Data efetiva de download:** 25 de novembro de 2026

## 3. Estrutura do repositório

```text
projeto_infraestrutura_bh/
├── consultas_resultado.txt
├── README.md
├── DICIONARIO.md
├── LICENSE
├── DADOS-LICENCA.md
├── sql/
│   ├── schema.sql
│   ├── dados.sql
│   └── consultas.sql
├── dados/
│   ├── brutos/       
│   └── tratados/     
├── scripts/
│   └── gerar_ewkt.py
└── docs/
    ├── der.png
    ├── OMTG-infraestrutura_bh_omtg_designer.xml
    ├── LEIA-ME-DER.md
    └── RELATORIO_CONTROLE_QUALIDADE.md
```

## 4. Requisitos e versões observadas

- PostgreSQL 17 (ambiente utilizado no desenvolvimento).
- PostGIS 3.7.0 (extensão ativada no banco `infraestrutura_bh`).
- GEOS 3.15.0 e PROJ 9.8.1 (informados por `PostGIS_Full_Version()`).
- QGIS 3.44.15 (visualização, correção e validação das camadas).
- `psql` para executar `sql/dados.sql`, pois o arquivo usa o comando cliente `\copy`.
- Python 3 (opcional) para regenerar os CSVs EWKT; `scripts/gerar_ewkt.py` usa apenas a biblioteca padrão.

## 5. Como recriar o banco em uma instalação limpa

> Os comandos abaixo são destinados a um **banco novo e vazio**. Não os execute sobre o banco de trabalho já preenchido. Faça o teste em um banco separado, por exemplo `infraestrutura_bh_teste`.

### 5.1 Criar o banco

No pgAdmin, crie um banco chamado `infraestrutura_bh_teste` com codificação UTF-8 e template `template0`, ou use:

```bash
createdb -h localhost -p 5432 -U postgres -T template0 infraestrutura_bh_teste
```

### 5.2 Criar tabelas, restrições e índices

A partir da raiz do repositório:

```bash
psql -h localhost -p 5432 -U postgres -d infraestrutura_bh_teste -v ON_ERROR_STOP=1 -f sql/schema.sql
```

O script ativa PostGIS, cria as três tabelas, geometrias tipadas, chaves, restrições `CHECK`/`UNIQUE` e índices GiST.

### 5.3 Regenerar os arquivos EWKT (opcional)

Os CSVs EWKT já estão em `dados/tratados/`. Para recriá-los a partir dos CSVs originais:

```bash
python scripts/gerar_ewkt.py
```

O script adiciona o prefixo `SRID=31983;` à geometria WKT. Não altera coordenadas nem corrige geometrias; a correção dos polígonos é aplicada no SQL de carga.

### 5.4 Carregar os dados

Execute a partir da raiz do repositório, para que os caminhos relativos de `\copy` sejam encontrados:

```bash
psql -h localhost -p 5432 -U postgres -d infraestrutura_bh_teste -v ON_ERROR_STOP=1 -f sql/dados.sql
```

`sql/dados.sql` carrega os CSVs EWKT em tabelas temporárias, valida as contagens, corrige os polígonos com `ST_MakeValid`, converte para os tipos geométricos tipados e associa cada equipamento a exatamente um bairro por `ST_Covers` e coincidência do nome normalizado.

**Importante:** `\copy` é um comando do cliente `psql`; não execute `sql/dados.sql` no Query Tool do pgAdmin. Use o terminal com `psql`.

### 5.5 Validar a carga

Depois da carga, conecte ao banco de teste e execute:

```sql
SELECT 'bairros' AS tabela, COUNT(*) AS registros FROM public.bairros
UNION ALL
SELECT 'vias', COUNT(*) FROM public.vias
UNION ALL
SELECT 'equipamentos_saude', COUNT(*) FROM public.equipamentos_saude;
```

Contagens esperadas: 493, 55.143 e 398 (56.034 no total). Execute também `sql/consultas.sql` para exemplos e verificações espaciais.

## 6. Consultas e diagrama

- `sql/consultas.sql`: contagens, validade, equipamentos por bairro, extensão de vias por bairro, trechos sem interseção e proximidade.
- `docs/der.png`: diagrama entidade-relacionamento. A FK é `equipamentos_saude.codigo_bairro` → `bairros.codigo`; a relação `vias`–`bairros` é espacial, por `ST_Intersects`.
- `DICIONARIO.md`: definição de todas as colunas, tipos, tamanhos/domínios, nulabilidade, chaves, descrições e exemplos.
- `docs/RELATORIO_CONTROLE_QUALIDADE.md`: resumo dos testes executados no ambiente de desenvolvimento.

## 7. Estado do teste de reprodutibilidade

A base de desenvolvimento foi carregada e conferida com 56.034 registros. Os scripts de reconstrução estão preparados. O teste de ponta a ponta em banco limpo já foi executado e registrado em consultas_resultado.txt pelos autores antes da entrega.

## 8. Como citar

PREFEITURA DE BELO HORIZONTE. Portal de Dados Abertos: Bairro Popular — Lei 11.490/2023; Trecho Logradouro; Rede de Assistência Saúde. Belo Horizonte: PBH. Licença indicada nos conjuntos: Creative Commons Attribution. Acesso em: 25 de novembro de 2026.

Para detalhes de proveniência e limitações, consulte `DADOS-LICENCA.md` e `DICIONARIO.md`.
