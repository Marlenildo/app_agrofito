# Changelog
Todas as mudanÃ§as relevantes deste projeto serÃ£o documentadas neste arquivo.

O formato segue o padrÃ£o [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/)
e o versionamento segue [Semantic Versioning](https://semver.org/lang/pt-BR/).

## [1.4.6] - 2026-02-19

### Changed
- Incluída barra de pesquisa de produtos junto aos filtros da aba `Consulta`, antes dos seletores.
- Removida a barra de pesquisa nativa do DataTable (DT), mantendo a busca apenas no novo campo de filtros.
- Filtro de cultura passou a incluir `Todos os produtos` como padrão, além de `Melão`, `Melancia` e `Todas as culturas`.
- Filtro de classe passou a incluir `Todas as classes` como opção padrão.
- Tabela e visualização em lista agora usam a mesma filtragem combinada (busca + cultura + classe).


## [Unreleased]

## [1.4.5] - 2026-02-19

### Fixed
- Workflow de deploy (`.github/workflows/deploy-vps.yml`) ajustado para normalizar a chave SSH (`tr -d '\r'`) e validar formato com `ssh-keygen`, evitando erro `Load key ... error in libcrypto`.

## [1.4.4] - 2026-02-19

### Fixed
- Corrige codificacao de caracteres em `ui.R` e `server.R` para UTF-8, removendo textos corrompidos (acentos quebrados) na interface.

## [1.4.3] - 2026-02-19

### Changed
- Removida a autenticaÃ§Ã£o interna da aplicaÃ§Ã£o (`ui.R` e `server.R`).
- O acesso ao app passa a depender apenas do SSO externo (Keycloak/OAuth2 no ambiente de produÃ§Ã£o).

## [1.4.2] - 2026-02-19

### Added
- Workflow de deploy para VPS em `.github/workflows/deploy-vps.yml`, acionado em push na `main`.

### Changed
- Publicacao do app em producao passou a sincronizar automaticamente via SSH executando `sync-prod-content.sh agrofito` no VPS.
- Reinicio automatico do servico `shiny` apos sincronizacao para aplicar atualizacoes do app.

## [1.4.0] - 2025-12-29

### Added
- Novo layout de login centralizado e responsivo
- PadronizaÃ§Ã£o visual dos campos de usuÃ¡rio, senha e botÃ£o de acesso
- VisualizaÃ§Ã£o em cards

### Improved
- ConsistÃªncia visual do formulÃ¡rio de autenticaÃ§Ã£o
- Melhor experiÃªncia em dispositivos mÃ³veis

## [1.3.1] â€“ 2025-12-29

### Changed
- Navbar ajustada para ocupar toda a largura da tela
- Refinamento do tamanho da logo
- Ajuste tipogrÃ¡fico do nome Agrofito

## [1.3.0] â€“ 2025-12-28

### Added
- Ãcones nos tÃ­tulos da navbar
- Novo refinamento visual da interface (layout v2)
- PadronizaÃ§Ã£o visual do login e footer

### Changed
- OrganizaÃ§Ã£o do CSS em design system
- Estrutura visual da tela de consulta
- Navbar com melhor hierarquia e usabilidade

### Fixed
- EspaÃ§amentos inconsistentes na navbar

## [1.2.0] - 2025-12-16

### Added
- Footer institucional exibido tambÃ©m na tela de login
- ExibiÃ§Ã£o da versÃ£o do aplicativo no login

### Changed
- Footer padronizado e exibido globalmente

## [1.1.0] - 2025-12-16

### Changed
- SeparaÃ§Ã£o do aplicativo em ui, server e global
- InclusÃ£o de arquivo VERSION para controle de versÃ£o
- VersÃ£o do aplicativo exibida dinamicamente no footer

### Security
- RemoÃ§Ã£o de usuÃ¡rios e senhas do cÃ³digo-fonte
- Credenciais carregadas via `.Renviron`

## [1.0.0] - 2025-12-16

### Added
- Consulta aos dados do sistema AGROFIT (MAPA)
- Filtros por cultura e classe agronÃ´mica
- Interface web com autenticaÃ§Ã£o
- Tabela interativa com exportaÃ§Ã£o

### Changed
- Estrutura inicial do projeto Shiny
