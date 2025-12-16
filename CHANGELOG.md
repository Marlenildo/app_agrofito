# Changelog
Todas as mudanças relevantes deste projeto serão documentadas neste arquivo.

O formato segue o padrão [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/)
e o versionamento segue [Semantic Versioning](https://semver.org/lang/pt-BR/).

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
