# Plano Futuro: PS Editavel por Role

## Objetivo
Permitir edicao controlada do campo PS para usuarios autorizados, mantendo usuarios comuns em modo somente leitura.

## Fases

### Fase 1: Fundacao de dados
- Provisionar PostgreSQL no VPS.
- Criar schema inicial (`ps_manual`, `ps_manual_audit`).
- Definir estrategia de backup.

Criterios de aceite:
- Banco acessivel pelo app no VPS.
- Estruturas criadas e validadas.

### Fase 2: Integracao no app
- Conectar Shiny ao PostgreSQL (`DBI` + `RPostgres`).
- Carregar dados da API e aplicar `LEFT JOIN` com `ps_manual` por `numero_registro`.
- Priorizar PS manual quando existir.

Criterios de aceite:
- Visualizacao mostra PS manual quando cadastrado.
- Sem regressao no fluxo atual de consulta.

### Fase 3: Controle por role
- Receber usuario e role da autenticacao do ecossistema.
- Implementar permissao:
  - `viewer`: sem escrita;
  - `editor_ps`: com escrita de PS.

Criterios de aceite:
- Viewer nao ve comandos de edicao.
- Editor consegue salvar alteracoes.

### Fase 4: UI de edicao
- Campo editavel de PS para `editor_ps`.
- Validacoes de entrada.
- Feedback de sucesso/erro.

Criterios de aceite:
- Edicao funcional com UX clara.
- Tratamento de erros de persistencia.

### Fase 5: Auditoria e operacao
- Registrar trilha de auditoria em toda alteracao.
- Revisar politicas de acesso e logs.
- Definir rotina de manutencao.

Criterios de aceite:
- Historico consultavel por alteracao.
- Processo operacional documentado.

## Dependencias
- Integracao com autenticacao central.
- Ambiente de VPS com recursos para Postgres.
- Credenciais seguras via variaveis de ambiente.

## Riscos e mitigacoes
- Risco: falha de conectividade com banco.
  Mitigacao: retry controlado + mensagem amigavel.
- Risco: edicao indevida.
  Mitigacao: checagem server-side de role e auditoria.
- Risco: perda de dados.
  Mitigacao: backup automatizado e teste de restore.

