# Changelog
Todas as mudancas relevantes deste projeto serao documentadas neste arquivo.

O formato segue o padrao [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/)
e o versionamento segue [Semantic Versioning](https://semver.org/lang/pt-BR/).

## [Unreleased]

### Planned
- Documentada arquitetura futura para edicao de `prazo_de_seguranca` por role (`viewer`/`editor_ps`) com persistencia em PostgreSQL no VPS.
- Criados os documentos de referencia:
  - `docs/adr/0001-role-e-ps-postgres.md`
  - `docs/roadmap/ps-editor-plan.md`

## [1.4.8] - 2026-02-24

### Changed
- Removida a exibicao de `alvo` na tabela e nos cards da aba de consulta.
- Removida a exibicao de `cultura` na tabela e nos cards da aba de consulta.
- Em `Todos os produtos`, os resultados passam a ser deduplicados por `numero_registro`, evitando repeticao do mesmo produto quando presente em mais de uma lista de cultura.

### Fixed
- Ajustado o carregamento inicial para o app abrir mesmo quando a API do AGROFIT estiver indisponivel.
- Adicionado fallback para exibir mensagem de indisponibilidade da consulta quando nao houver dados por falha de acesso a API.

## [1.4.7] - 2026-02-24

### Changed
- Filtro de cultura reorganizado para quatro opcoes: `Todos os produtos`, `Melão`, `Melancia` e `Todas as culturas`.
- A base de dados do app passou a ser montada a partir de tres consultas especificas da API (`Melao`, `Melancia` e `Todas as culturas`), em vez de baixar todo o catalogo.
- Inclusao da coluna/campo `alvo` na tabela e nos cards da aba de consulta.

### Performance
- Adicionado cache em memoria no processo do app para evitar novo download da API durante a mesma sessao.
- Adicionado cache em disco (`cache/*.rds`, TTL de 24h) para reduzir tempo de carga entre reinicios do app.

### Fixed
- Corrigidos textos com caracteres quebrados (mojibake) em `ui.R`, `server.R` e `global.R`.
- Ajustado comportamento padrao dos seletores para iniciar sem restricao de classe (`Todas as classes`) e com cultura agregada (`Todos os produtos`).
- Busca textual mantida para marca comercial, ingrediente ativo e classe agronomica.

## [1.4.6] - 2026-02-19

### Changed
- Incluida barra de pesquisa de produtos junto aos filtros da aba `Consulta`, antes dos seletores.
- Removida a barra de pesquisa nativa do DataTable (DT), mantendo a busca apenas no novo campo de filtros.
- Filtro de cultura passou a incluir `Todos os produtos` como padrao, alem de `Melão`, `Melancia` e `Todas as culturas`.
- Filtro de classe passou a incluir `Todas as classes` como opcao padrao.
- Tabela e visualizacao em lista agora usam a mesma filtragem combinada (busca + cultura + classe).

## [1.4.5] - 2026-02-19

### Fixed
- Workflow de deploy (`.github/workflows/deploy-vps.yml`) ajustado para normalizar a chave SSH (`tr -d '\r'`) e validar formato com `ssh-keygen`, evitando erro `Load key ... error in libcrypto`.

## [1.4.4] - 2026-02-19

### Fixed
- Corrige codificacao de caracteres em `ui.R` e `server.R` para UTF-8, removendo textos corrompidos (acentos quebrados) na interface.
