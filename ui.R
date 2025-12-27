app_footer <- function() {
  tags$footer(
    img(
      src = "nova_logomm.png",
      height = "40px",
      style = "vertical-align: middle; margin-right: 8px;"
    ),
    paste0("© 2025 MelonMundi - Global Solutions | Agrofito ", APP_VERSION)
  )
}


fluidPage(
  tags$head(
    includeCSS("www/estilo.css"),
    tags$link(rel = "stylesheet", href = "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/css/font-awesome.min.css")
  ),
  
  # Tela de login
  uiOutput("login_ui"),
  
  # Conteúdo principal só aparece se logado
  conditionalPanel(
    condition = "output.loggedIn == true",
    navbarPage(
      title = tags$div(
        style = "display:flex; align-items:center; justify-content:center;",
        img(src = 'nova_logomm.png', height = 40),
        tags$span(style = "width: 20px"),
        tags$span(style = "color: #548238; font-weight: bold; font-family: Arial; font-size: 16px;", "Agrofito")
      ),
      inverse = FALSE,
      collapsible = TRUE,
      fluid = TRUE,
      
      # ---- Consulta ----
      tabPanel(
        title = tagList(icon("search"), "Consulta"),
        span(class = "panel-title", "Consulta por cultura"),
        tags$p(
          "Consulte todos os produtos registrados no Sistema de Agrotóxicos Fitossanitários (AGROFIT) do Ministério da Agricultura, Pecuária e Abastecimento (MAPA)."
        ),
        tags$p(
          "É possível pesquisar por cultura e classe de produto, e obter informações detalhadas sobre cada produto, incluindo cultura, classe agronômica, marca comercial, ingrediente ativo e prazo de segurança."
        ),
        tags$p("Filtre sua consulta por cultura e classe agronômica."),
        br(),
        fluidRow(class = "input-box", column(
          6,
          selectInput(
            "cultura",
            "Selecione a cultura:",
            choices = NULL,
            selectize = TRUE
          )
        ), column(
          6,
          selectInput(
            "grupo",
            "Selecione a classe do produto:",
            choices = NULL,
            selectize = TRUE
          )
        )),
        fluidRow(column(
          12, class = "input-box", withSpinner(DTOutput("produtos_table"), type = 6)
        ))
      ),
      
      # ---- Versão ----
      tabPanel(
        title = tagList(icon("info-circle"), "Versão dos dados"),
        span(class = "panel-title", "Versão dos Dados"),
        tags$p(
          "Aqui você encontra a data da última atualização dos dados disponíveis no Sistema de Agrotóxicos Fitossanitários (AGROFIT) do Ministério da Agricultura, Pecuária e Abastecimento (MAPA), bem como a fonte oficial de pesquisa."
        ),
        br(),
        div(
          id = "versao_box",
          p(strong("Órgão mantenedor: "), dados_versao$mantenedor),
          p(
            strong("Link para o AGROFIT: "),
            a(href = dados_versao$fonte, target = "_blank", dados_versao$fonte)
          ),
          p(
            strong("Mapa de dados: "),
            a(
              href = dados_versao$url_mapa_dados,
              target = "_blank",
              dados_versao$url_mapa_dados
            )
          ),
          p(
            strong("Última atualização dos dados no AGROFIT: "),
            formatar_data(dados_versao$data_ultima_atualizacao)
          )
        ),
        br(),
        br()
      ),
      
      # ---- Aviso Legal ----
      tabPanel(
        title = tagList(icon("balance-scale"), "Aviso Legal"),
        div(
        class = "info-box",
        p(class = "title", "⚖️ Aviso Legal"),
        p(
          "As informações apresentadas neste relatório têm caráter exclusivamente informativo e não substituem, em hipótese alguma, as orientações técnicas, legais ou regulatórias emitidas pelos órgãos oficiais competentes."
        ),
        p(
          "A MelonMundi exime-se de qualquer responsabilidade por eventuais danos, prejuízos ou consequências decorrentes da interpretação, aplicação ou uso inadequado dos produtos químicos aqui listados, incluindo defensivos agrícolas, fertilizantes, produtos biológicos e demais insumos."
        ),
        p(
          "Reforçamos que a fonte oficial para consulta, validação e atualização de informações sobre produtos fitossanitários é o portal do Sistema de Agrotóxicos Fitossanitários (AGROFIT) do Ministério da Agricultura, Pecuária e Abastecimento (MAPA), que pode ser acessado nesse link:",
          a(
            href = "https://agrofit.agricultura.gov.br/agrofit_cons/principal_agrofit_cons",
            target = "_blank",
            "https://agrofit.agricultura.gov.br/agrofit_cons/principal_agrofit_cons"
          )
        ),
        p(
          "É imprescindível que o usuário consulte as bulas e fichas técnicas dos produtos diretamente no portal Agrofit, verificando cuidadosamente as recomendações de uso, restrições, culturas autorizadas, doses e intervalos de segurança."
        ),
        p(
          "O usuário é integralmente responsável por verificar a conformidade legal, técnica e ambiental dos produtos antes de sua aquisição, recomendação ou utilização, observando sempre a legislação vigente e as boas práticas agrícolas."
        )
      ))
      
    )
  ),
  # ✅ Footer sempre visível (login + app)
  app_footer()
)