# ADR 0001: Edicao de PS por Role com PostgreSQL

## Status
Proposto

## Contexto
O app Agrofito depende da API do AGROFIT, mas o campo `prazo_de_seguranca` (PS) pode estar ausente, incompleto ou nao ser suficiente para o uso interno.
Existe necessidade de:
- manter usuarios comuns apenas em modo leitura;
- permitir que usuarios autorizados editem PS;
- persistir PS manual em fonte propria e auditavel.

## Decisao
Implementar, em fase futura, uma camada de dados propria em PostgreSQL para PS manual, com controle por perfil:
- `viewer`: somente leitura;
- `editor_ps`: leitura + edicao de PS.

Os dados da API continuam sendo a base principal.
O PS manual sera aplicado via `LEFT JOIN` por `numero_registro`, com prioridade para valor manual quando existir.

## Arquitetura alvo (futura)
- Autenticacao central do ecossistema fornece identidade e role ao app.
- Shiny aplica autorizacao na interface e nas acoes de escrita.
- PostgreSQL no VPS (preferencialmente sem exposicao publica).
- Tabela de estado atual de PS + tabela de auditoria de alteracoes.

## Modelo de dados inicial (sugestao)
Tabela `ps_manual`:
- `numero_registro` (PK)
- `prazo_de_seguranca`
- `updated_by`
- `updated_at`

Tabela `ps_manual_audit`:
- `id` (PK)
- `numero_registro`
- `valor_anterior`
- `valor_novo`
- `updated_by`
- `updated_at`

## Consequencias
Positivas:
- permite manutencao de PS mesmo sem suporte completo na API;
- governanca por perfil;
- rastreabilidade de alteracoes.

Custos/riscos:
- requer operacao de banco no VPS;
- requer sincronizacao clara entre app e ecossistema de autenticacao;
- exige politica de backup e retencao.

## Fora de escopo agora
- Implementacao tecnica no app;
- Provisionamento real do PostgreSQL;
- Migracao de dados legados.

