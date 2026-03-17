app_footer <- function() {
  tags$footer(
    class = "app-footer",
    img(
      class = "app-footer-logo",
      src = "nova_logomm.png",
      height = "40px",
      style = "vertical-align: middle; margin-right: 8px;"
    ),
        tags$div(
          class = "app-footer-content",
          tags$div(
            class = "app-footer-line app-footer-line-main",
            tags$span(HTML("&copy; 2026 MelonMundi - Global Solutions. Todos os direitos reservados."))
      ),
      tags$div(
        class = "app-footer-line app-footer-line-legal",
        tags$span(paste0("Agrofito v", APP_VERSION, " | ")),
        tags$a(
          href = "https://github.com/Marlenildo/app_agrofito/blob/main/LICENSE",
          target = "_blank",
          "Licença proprietária"
        )
      )
    )
  )
}

selectize_mobile_options <- list(
  onInitialize = I(
    "function() {
      this.$control_input.prop('readonly', true);
      this.$control_input.attr('inputmode', 'none');
    }"
  ),
  onDropdownOpen = I(
    "function() {
      this.$control_input.prop('readonly', true);
      this.$control_input.blur();
    }"
  )
)

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
      img(src = "nova_logomm.png", height = 40),
      tags$span(style = "width: 20px"),
      tags$span(style = "color: #548238; font-weight: bold; font-family: Arial; font-size: 16px;", "Agrofito")
    ),
    inverse = FALSE,
    collapsible = TRUE,
    fluid = TRUE,

    tabPanel(
      title = tagList(icon("search"), "Consulta"),
      span(class = "panel-title", "Consulta por cultura"),
      tags$p(
        "Consulte os produtos registrados no Sistema de Agrotóxicos Fitossanitários (AGROFIT) do Ministério da Agricultura e Pecuária (MAPA), com foco em Melão, Melancia e Todas as culturas."
      ),
      tags$p(
        "Pesquise por produto e refine os resultados por cultura e classe agronômica. Você pode visualizar informações como marca comercial, ingrediente ativo, classe agronômica e prazo de segurança."
      ),
      br(),
      fluidRow(
        class = "input-box filters-box",
        column(
          4,
          textInput(
            "busca_produto",
            "Pesquisar produto:",
            value = "",
            placeholder = "Marca, ingrediente ativo ou classe"
          )
        ),
        column(
          4,
          selectizeInput(
            "cultura",
            "Selecione a cultura:",
            choices = c("Todos os produtos", names(CULTURAS_SUPORTADAS)),
            selected = "Todos os produtos",
            options = selectize_mobile_options
          )
        ),
        column(
          4,
          selectizeInput(
            "grupo",
            "Selecione a classe do produto:",
            choices = "Todas as classes",
            selected = "Todas as classes",
            options = selectize_mobile_options
          )
        ),
        column(
          12,
          div(
            class = "filter-actions",
            actionButton(
              "btn_atualizar_dados",
              tagList(icon("arrows-rotate"), "Atualizar dados"),
              class = "filter-refresh-btn"
            ),
            actionButton(
              "btn_limpar_filtros",
              tagList(icon("rotate-left"), "Limpar filtros"),
              class = "filter-clear-btn"
            )
          ),
          tags$hr(class = "filters-summary-divider"),
          uiOutput("filters_summary")
        )
      ),
      fluidRow(
        column(
          12,
          uiOutput("data_status")
        )
      ),
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
          uiOutput("result_view")
        )
      )
    ),

    tabPanel(
      title = tagList(icon("info-circle"), "Versão dos dados"),
      span(class = "panel-title", "Versão dos dados"),
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

    tabPanel(
      title = tagList(icon("balance-scale"), "Aviso Legal"),
      div(
        class = "info-box",
        p(class = "title", "Aviso Legal"),
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
      )
    )
  ),

  app_footer()
)
