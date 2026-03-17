function(input, output, session) {
  carregando_inicial <- reactiveVal(TRUE)

  mensagem_api_indisponivel <- function() {
    div(
      class = "empty-box",
      strong("Consulta indisponivel no momento."),
      p("Nao foi possivel acessar a API do AGROFIT agora. Tente novamente em alguns minutos.")
    )
  }

  formatar_contagem <- function(n) {
    format(n, big.mark = ".", decimal.mark = ",", trim = TRUE, scientific = FALSE)
  }

  preparar_produtos_exibicao <- function(df) {
    if (nrow(df) == 0) {
      return(tibble(
        classe_categoria_agronomica = character(),
        marca_comercial = character(),
        ingrediente_ativo = character(),
        prazo_de_seguranca = character()
      ))
    }

    df |>
      dplyr::select(any_of(
        c(
          "classe_categoria_agronomica",
          "marca_comercial",
          "ingrediente_ativo",
          "prazo_de_seguranca"
        )
      )) |>
      mutate(across(
        everything(),
        ~ {
          if (is.list(.x)) {
            sapply(.x, function(y) {
              if (is.null(y)) NA_character_ else paste(unlist(y), collapse = ", ")
            })
          } else {
            as.character(.x)
          }
        }
      )) |>
      distinct()
  }

  aplicar_busca <- function(df, busca) {
    if (nrow(df) == 0) {
      return(df)
    }

    busca <- trimws(if (is.null(busca)) "" else busca)
    if (!nzchar(busca)) {
      return(df)
    }

    busca_lower <- tolower(busca)
    cols_busca <- intersect(
      c("marca_comercial", "ingrediente_ativo", "classe_categoria_agronomica"),
      names(df)
    )

    if (length(cols_busca) == 0) {
      return(df)
    }

    df |>
      filter(
        if_any(
          all_of(cols_busca),
          ~ grepl(busca_lower, tolower(as.character(.x)), fixed = TRUE)
        )
      )
  }

  # -------------------------------
  # Carrega lista de culturas
  # -------------------------------
  culturas <- c("Todos os produtos", names(CULTURAS_SUPORTADAS))

  updateSelectInput(
    session,
    "cultura",
    choices = culturas,
    selected = "Todos os produtos"
  )

  updateSelectInput(
    session,
    "grupo",
    choices = "Todas as classes",
    selected = "Todas as classes"
  )

  # -------------------------------
  # Produtos reativos (base)
  # -------------------------------
  produtos_reactive <- reactive({
    req(input$cultura)

    df <- get_produtos_base(token)
    carregando_inicial(FALSE)

    if (nrow(df) == 0) {
      return(normalizar_produtos(tibble()))
    }

    if (input$cultura %in% names(CULTURAS_SUPORTADAS) && "filtro_cultura" %in% names(df)) {
      df <- df |>
        filter(filtro_cultura == input$cultura)
    }

    # Em "Todos os produtos", remove duplicados entre consultas de culturas.
    # Mantem prioridade para a fonte "Todas as culturas", quando existir.
    if (identical(input$cultura, "Todos os produtos") &&
      "numero_registro" %in% names(df)) {
      if ("filtro_cultura" %in% names(df)) {
        df <- df |>
          mutate(.prioridade_fonte = if_else(filtro_cultura == "Todas as culturas", 0L, 1L)) |>
          arrange(.prioridade_fonte) |>
          distinct(numero_registro, .keep_all = TRUE) |>
          select(-.prioridade_fonte)
      } else {
        df <- df |>
          distinct(numero_registro, .keep_all = TRUE)
      }
    }

    df
  })

  observe({
    df <- produtos_reactive()

    grupos <- if ("GRUPO" %in% names(df) && nrow(df) > 0) {
      sort(unique(df$GRUPO))
    } else {
      character(0)
    }

    updateSelectInput(
      session,
      "grupo",
      choices = c("Todas as classes", grupos),
      selected = "Todas as classes"
    )
  })

  # -------------------------------
  # Produtos filtrados (classe + busca)
  # -------------------------------
  produtos_por_classe <- reactive({
    df <- produtos_reactive()
    req(input$grupo, input$cultura)

    if (nrow(df) == 0) {
      return(df)
    }

    if (input$grupo != "Todas as classes") {
      df <- df |>
        filter(GRUPO == input$grupo)
    }

    df
  })

  produtos_filtrados <- reactive({
    df <- produtos_por_classe()
    req(input$grupo, input$cultura)

    if (nrow(df) == 0) {
      return(df)
    }

    aplicar_busca(df, input$busca_produto)
  })

  produtos_exibicao <- reactive({
    preparar_produtos_exibicao(produtos_filtrados())
  })

  view_mode <- reactiveVal("table")

  observeEvent(input$btn_table, {
    view_mode("table")
  })

  observeEvent(input$btn_cards, {
    view_mode("cards")
  })

  observeEvent(input$btn_limpar_filtros, {
    updateTextInput(
      session,
      "busca_produto",
      value = ""
    )

    updateSelectInput(
      session,
      "cultura",
      selected = "Todos os produtos"
    )

    updateSelectInput(
      session,
      "grupo",
      selected = "Todas as classes"
    )
  })

  observe({
    if (view_mode() == "table") {
      shinyjs::addClass("btn_table", "active")
      shinyjs::removeClass("btn_cards", "active")
    } else {
      shinyjs::addClass("btn_cards", "active")
      shinyjs::removeClass("btn_table", "active")
    }
  })

  output$loading_hint <- renderUI({
    if (!carregando_inicial()) {
      return(NULL)
    }

    div(
      class = "loading-hint",
      icon("download"),
      tags$span("Na primeira carga, o app pode levar alguns segundos para ler o cache local ou baixar dados do AGROFIT.")
    )
  })

  output$filters_summary <- renderUI({
    req(input$cultura, input$grupo)

    df_cultura <- preparar_produtos_exibicao(aplicar_busca(produtos_reactive(), input$busca_produto))
    df_classe <- preparar_produtos_exibicao(aplicar_busca(produtos_por_classe(), input$busca_produto))
    texto_cultura <- if (identical(input$cultura, "Todos os produtos")) {
      "Produtos considerando todas as culturas."
    } else {
      "Produtos na cultura selecionada."
    }
    texto_classe <- if (identical(input$grupo, "Todas as classes")) {
      "Produtos considerando todas as classes."
    } else {
      "Produtos na classe selecionada."
    }

    cards <- list(
      div(
        class = "summary-card summary-card-primary",
        div(class = "summary-label", "Cultura"),
        div(class = "summary-context", input$cultura),
        div(class = "summary-value", formatar_contagem(nrow(df_cultura))),
        div(class = "summary-helper", texto_cultura)
      )
    )

    if (!identical(input$grupo, "Todas as classes")) {
      cards <- c(cards, list(
        div(
          class = "summary-card",
          div(class = "summary-label", "Classe"),
          div(class = "summary-context", input$grupo),
          div(class = "summary-value", formatar_contagem(nrow(df_classe))),
          div(class = "summary-helper", texto_classe)
        )
      ))
    }

    div(class = "summary-grid", cards)
  })

  output$produtos_table <- renderDT({
    df_filtrado <- produtos_exibicao()
    req(input$grupo, input$cultura)

    datatable(
      df_filtrado,
      rownames = TRUE,
      options = list(
        dom = "Blrtip",
        pageLength = 10,
        lengthMenu = list(
          c(10, 25, 50, 100, -1),
          c("10", "25", "50", "100", "Todos")
        ),
        responsive = TRUE,
        scrollX = TRUE,
        buttons = c("copy", "excel", "pdf"),
        language = list(
          url = "//cdn.datatables.net/plug-ins/1.13.8/i18n/pt-BR.json"
        )
      ),
      extensions = "Buttons"
    )
  })

  output$produtos_cards <- renderUI({
    df_filtrado <- produtos_exibicao()
    req(input$grupo)

    if (nrow(df_filtrado) == 0) {
      return(div(class = "empty-box", "Nenhum produto encontrado para os filtros selecionados."))
    }

    tagList(
      lapply(seq_len(nrow(df_filtrado)), function(i) {
        produto <- df_filtrado[i, ]

        div(
          class = "produto-card",
          h4(to_text(produto$marca_comercial)),
          p(strong("Ingrediente ativo: "), to_text(produto$ingrediente_ativo)),
          div(
            class = "produto-classes",
            classe_badges(produto$classe_categoria_agronomica)
          ),
          if ("prazo_de_seguranca" %in% names(produto)) p(strong("Prazo de seguranca: "), to_text(produto$prazo_de_seguranca))
        )
      })
    )
  })

  output$result_view <- renderUI({
    df_base <- produtos_reactive()
    df <- produtos_filtrados()
    base_sem_dados <- nrow(df_base) == 0

    if (nrow(df) == 0 && base_sem_dados) {
      return(mensagem_api_indisponivel())
    }

    if (view_mode() == "table") {
      DTOutput("produtos_table")
    } else {
      uiOutput("produtos_cards")
    }
  })
}
