app_footer <- function() {
  tags$footer(
    img(
      src = "nova_logomm.png",
      height = "40px",
      style = "vertical-align: middle; margin-right: 8px;"
    ),
    paste0("Â© 2025 MelonMundi - Global Solutions | Agrofito v", APP_VERSION)
  )
}


fluidPage(
  useShinyjs(),
  tags$head(
    tags$link(
      rel = "preconnect",
      href = "https://fonts.googleapis.com"
    ),
    tags$link(
      rel = "preconnect",
      href = "https://fonts.gstatic.com",
      crossorigin = "anonymous"
    ),
    tags$link(
      rel = "stylesheet",
      href = "https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap"
    ),
    includeCSS("www/estilo.css"),
    tags$link(
      rel = "stylesheet",
      href = "https://cdnjs.cloudflare.com/ajax/libs/font-awesome/4.7.0/css/font-awesome.min.css"
    )
  ),
  
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
          "Consulte todos os produtos registrados no Sistema de AgrotÃ³xicos FitossanitÃ¡rios (AGROFIT) do MinistÃ©rio da Agricultura, PecuÃ¡ria e Abastecimento (MAPA)."
        ),
        tags$p(
          "Ã‰ possÃ­vel pesquisar por cultura e classe de produto, e obter informaÃ§Ãµes detalhadas sobre cada produto, incluindo cultura, classe agronÃ´mica, marca comercial, ingrediente ativo e prazo de seguranÃ§a."
        ),
        tags$p("Filtre sua consulta por cultura e classe agronÃ´mica."),
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
        # fluidRow(column(
        #   12, class = "input-box", withSpinner(DTOutput("produtos_table"), type = 6)
        # ))
        fluidRow(
          column(
            12,
            class = "input-box",
            div(
              class = "view-switch",
              
              actionButton(
                "btn_table",
                tagList(icon("table"), "Tabela"),
                class = "view-pill active"
              ),
              
              actionButton(
                "btn_cards",
                tagList(icon("rectangle-list"), "Lista"),
                class = "view-pill"
              )
            ),
            br(),
            br(),
            uiOutput("result_view")
          )
        )
        
      ),
      
      # ---- VersÃ£o ----
      tabPanel(
        title = tagList(icon("info-circle"), "VersÃ£o dos dados"),
        span(class = "panel-title", "VersÃ£o dos dados"),
        tags$p(
          "Aqui vocÃª encontra a data da Ãºltima atualizaÃ§Ã£o dos dados disponÃ­veis no Sistema de AgrotÃ³xicos FitossanitÃ¡rios (AGROFIT) do MinistÃ©rio da Agricultura, PecuÃ¡ria e Abastecimento (MAPA), bem como a fonte oficial de pesquisa."
        ),
        br(),
        div(
          id = "versao_box",
          p(strong("Ã“rgÃ£o mantenedor: "), dados_versao$mantenedor),
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
            strong("Ãšltima atualizaÃ§Ã£o dos dados no AGROFIT: "),
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
        p(class = "title", "âš–ï¸ Aviso Legal"),
        p(
          "As informaÃ§Ãµes apresentadas neste relatÃ³rio tÃªm carÃ¡ter exclusivamente informativo e nÃ£o substituem, em hipÃ³tese alguma, as orientaÃ§Ãµes tÃ©cnicas, legais ou regulatÃ³rias emitidas pelos Ã³rgÃ£os oficiais competentes."
        ),
        p(
          "A MelonMundi exime-se de qualquer responsabilidade por eventuais danos, prejuÃ­zos ou consequÃªncias decorrentes da interpretaÃ§Ã£o, aplicaÃ§Ã£o ou uso inadequado dos produtos quÃ­micos aqui listados, incluindo defensivos agrÃ­colas, fertilizantes, produtos biolÃ³gicos e demais insumos."
        ),
        p(
          "ReforÃ§amos que a fonte oficial para consulta, validaÃ§Ã£o e atualizaÃ§Ã£o de informaÃ§Ãµes sobre produtos fitossanitÃ¡rios Ã© o portal do Sistema de AgrotÃ³xicos FitossanitÃ¡rios (AGROFIT) do MinistÃ©rio da Agricultura, PecuÃ¡ria e Abastecimento (MAPA), que pode ser acessado nesse link:",
          a(
            href = "https://agrofit.agricultura.gov.br/agrofit_cons/principal_agrofit_cons",
            target = "_blank",
            "https://agrofit.agricultura.gov.br/agrofit_cons/principal_agrofit_cons"
          )
        ),
        p(
          "Ã‰ imprescindÃ­vel que o usuÃ¡rio consulte as bulas e fichas tÃ©cnicas dos produtos diretamente no portal Agrofit, verificando cuidadosamente as recomendaÃ§Ãµes de uso, restriÃ§Ãµes, culturas autorizadas, doses e intervalos de seguranÃ§a."
        ),
        p(
          "O usuÃ¡rio Ã© integralmente responsÃ¡vel por verificar a conformidade legal, tÃ©cnica e ambiental dos produtos antes de sua aquisiÃ§Ã£o, recomendaÃ§Ã£o ou utilizaÃ§Ã£o, observando sempre a legislaÃ§Ã£o vigente e as boas prÃ¡ticas agrÃ­colas."
        )
      ))
      
    ),
  # Footer
  app_footer()
)
