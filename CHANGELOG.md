# Changelog
Todas as mudanças relevantes deste projeto serão documentadas neste arquivo.

O formato segue o padrão [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/)
e o versionamento segue [Semantic Versioning](https://semver.org/lang/pt-BR/).

## [Unreleased]

## [1.4.3] - 2026-02-19

### Changed
- Removida a autenticação interna da aplicação (`ui.R` e `server.R`).
- O acesso ao app passa a depender apenas do SSO externo (Keycloak/OAuth2 no ambiente de produção).

## [1.4.2] - 2026-02-19

### Added
- Workflow de deploy para VPS em `.github/workflows/deploy-vps.yml`, acionado em push na `main`.

### Changed
- Publicacao do app em producao passou a sincronizar automaticamente via SSH executando `sync-prod-content.sh agrofito` no VPS.
- Reinicio automatico do servico `shiny` apos sincronizacao para aplicar atualizacoes do app.

## [1.4.0] - 2025-12-29

### Added
- Novo layout de login centralizado e responsivo
- Padronização visual dos campos de usuário, senha e botão de acesso
- Visualização em cards

### Improved
- Consistência visual do formulário de autenticação
- Melhor experiência em dispositivos móveis

## [1.3.1] – 2025-12-29

### Changed
- Navbar ajustada para ocupar toda a largura da tela
- Refinamento do tamanho da logo
- Ajuste tipográfico do nome Agrofito

## [1.3.0] – 2025-12-28

### Added
- Ícones nos títulos da navbar
- Novo refinamento visual da interface (layout v2)
- Padronização visual do login e footer

### Changed
- Organização do CSS em design system
- Estrutura visual da tela de consulta
- Navbar com melhor hierarquia e usabilidade

### Fixed
- Espaçamentos inconsistentes na navbar

## [1.2.0] - 2025-12-16

### Added
- Footer institucional exibido também na tela de login
- Exibição da versão do aplicativo no login

### Changed
- Footer padronizado e exibido globalmente

## [1.1.0] - 2025-12-16

### Changed
- Separação do aplicativo em ui, server e global
- Inclusão de arquivo VERSION para controle de versão
- Versão do aplicativo exibida dinamicamente no footer

### Security
- Remoção de usuários e senhas do código-fonte
- Credenciais carregadas via `.Renviron`

## [1.0.0] - 2025-12-16

### Added
- Consulta aos dados do sistema AGROFIT (MAPA)
- Filtros por cultura e classe agronômica
- Interface web com autenticação
- Tabela interativa com exportação

### Changed
- Estrutura inicial do projeto Shiny
