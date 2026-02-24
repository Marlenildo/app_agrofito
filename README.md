# Agrofito (Shiny App)

Aplicativo Shiny para consulta de produtos formulados do AGROFIT (MAPA), com foco nas culturas de melão, melancia e produtos indicados para todas as culturas.

## Objetivo

Oferecer uma interface simples para pesquisa e filtragem de produtos do AGROFIT, com:
- busca textual;
- filtros por cultura e classe agronômica;
- visualização em tabela ou cards;
- exportação de resultados.

## Funcionalidades

- Consulta baseada em três fontes da API:
  - `Melão` (`Melao`)
  - `Melancia`
  - `Todas as culturas`
- Opção `Todos os produtos` como união das três fontes.
- Deduplicação em `Todos os produtos` por `numero_registro`.
- Filtro por classe (`GRUPO`): Biológico, Fungicida, Inseticida, Herbicida e Outros.
- Busca textual por marca comercial, ingrediente ativo ou classe.
- Visualização:
  - Tabela (`DT`) com botões de exportação (`copy`, `excel`, `pdf`)
  - Cards em lista
- Aba de versão dos dados (metadados da API).
- Aviso legal no próprio app.

## Resiliência quando API está indisponível

- O app abre mesmo se não conseguir token/acesso à API.
- Se houver cache válido, o app usa cache.
- Se não houver dados disponíveis, o app mostra mensagem de indisponibilidade da consulta.

## Links oficiais

- Portal AGROFIT: https://agrofit.agricultura.gov.br/agrofit_cons/principal_agrofit_cons
- API AGROFIT (versao): https://api.cnptia.embrapa.br/agrofit/v1/versao
- Token da API CNPTIA/Embrapa: https://api.cnptia.embrapa.br/token

## Tecnologias

- R + Shiny
- `DT`, `shinycssloaders`, `shinyjs`
- `httr`, `httr2`, `jsonlite`
- `dplyr`, `tidyr`, `tibble`, `lubridate`

## Pré-requisitos

- R instalado (recomendado R 4.2+)
- Pacotes R usados no projeto (listados em `global.R`)
- Credenciais da API AGROFIT:
  - `CONSUMER_KEY`
  - `CONSUMER_SECRET`

## Configuração de ambiente

Defina as variáveis de ambiente antes de rodar o app.

Exemplo em `.Renviron`:

```env
CONSUMER_KEY=seu_consumer_key
CONSUMER_SECRET=seu_consumer_secret
```

## Como executar localmente

No diretório do projeto:

```r
shiny::runApp()
```

Ou:

```r
source("app.R")
```

## Cache de dados

- Cache em memória por processo (`.produtos_cache`)
- Cache em disco em `cache/produtos_melao_melancia_todas.rds`
- TTL atual: 24 horas

## Estrutura do projeto

- `app.R`: ponto de entrada do Shiny app
- `global.R`: configuração, autenticação API, cache, normalização de dados e funções auxiliares
- `ui.R`: interface do app (abas, filtros, layout)
- `server.R`: lógica reativa, filtros, renderização de tabela/cards
- `www/`: CSS e assets estáticos
- `CHANGELOG.md`: histórico de mudanças
- `VERSION`: versão atual do app
- `docs/adr/`: decisões arquiteturais (ADR)
- `docs/roadmap/`: planos de evolução

## Deploy

Deploy automatizado via GitHub Actions em push para `main`:
- workflow: `.github/workflows/deploy-vps.yml`
- processo: sincroniza conteúdo no VPS e reinicia serviço Shiny no stack Docker de produção

## Versionamento

Este projeto segue versionamento semântico (SemVer).
Consulte:
- `VERSION`
- `CHANGELOG.md`

Tags Git no padrão `vX.Y.Z`.

## Licenca

Este projeto utiliza licenca proprietaria (`All Rights Reserved`).
Consulte o arquivo `LICENSE` para os termos completos.

## Próximos passos documentados

Foi documentada evolução futura para edição de `prazo_de_seguranca` por perfil (`viewer`/`editor_ps`) com PostgreSQL:
- `docs/adr/0001-role-e-ps-postgres.md`
- `docs/roadmap/ps-editor-plan.md`
