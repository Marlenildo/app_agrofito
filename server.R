function(input, output, session) {
  mensagem_api_indisponivel <- function() {
    div(
      class = "empty-box",
      strong("Consulta indisponível no momento."),
      p("Não foi possível acessar a API do AGROFIT agora. Tente novamente em alguns minutos.")
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

    if (nrow(df) == 0) {
      return(normalizar_produtos(tibble()))
    }

    if (input$cultura %in% names(CULTURAS_SUPORTADAS) && "filtro_cultura" %in% names(df)) {
      df <- df |>
        filter(filtro_cultura == input$cultura)
    }

    # Em "Todos os produtos", remove duplicados entre consultas de culturas.
    # Mantém prioridade para a fonte "Todas as culturas", quando existir.
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
  produtos_filtrados <- reactive({
    df <- produtos_reactive()
    req(input$grupo, input$cultura)

    if (nrow(df) == 0) {
      return(df)
    }

    if (input$grupo != "Todas as classes") {
      df <- df |>
        filter(GRUPO == input$grupo)
    }

    busca <- trimws(if (is.null(input$busca_produto)) "" else input$busca_produto)

    if (nzchar(busca)) {
      busca_lower <- tolower(busca)
      cols_busca <- intersect(
        c("marca_comercial", "ingrediente_ativo", "classe_categoria_agronomica"),
        names(df)
      )

      if (length(cols_busca) > 0) {
        df <- df |>
          filter(
            if_any(
              all_of(cols_busca),
              ~ grepl(busca_lower, tolower(as.character(.x)), fixed = TRUE)
            )
          )
      }
    }

    df
  })

  view_mode <- reactiveVal("table")

  observeEvent(input$btn_table, {
    view_mode("table")
  })

  observeEvent(input$btn_cards, {
    view_mode("cards")
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

  output$produtos_table <- renderDT({
    df <- produtos_filtrados()
    req(input$grupo, input$cultura)

    if (nrow(df) == 0) {
      df_filtrado <- tibble(
        classe_categoria_agronomica = character(),
        marca_comercial = character(),
        ingrediente_ativo = character(),
        prazo_de_seguranca = character()
      )
    } else {
      df_filtrado <- df |>
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

    classe_caption <- if (input$grupo == "Todas as classes") {
      "todas as classes"
    } else {
      toupper(input$grupo)
    }

    datatable(
      df_filtrado,
      rownames = TRUE,
      caption = paste0(
        "Lista de ", classe_caption,
        " disponíveis para ", input$cultura,
        " - Quantidade de produtos distintos: ", nrow(df_filtrado)
      ),
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
    df <- produtos_filtrados()
    req(input$grupo)

    if (nrow(df) == 0) {
      return(div(class = "empty-box", "Nenhum produto encontrado para os filtros selecionados."))
    }

    df_filtrado <- df |>
      dplyr::select(any_of(c(
        "classe_categoria_agronomica",
        "marca_comercial",
        "ingrediente_ativo",
        "prazo_de_seguranca"
      )))

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
          if ("prazo_de_seguranca" %in% names(produto)) p(strong("Prazo de segurança: "), to_text(produto$prazo_de_seguranca))
        )
      })
    )
  })

  output$result_view <- renderUI({
    base_sem_dados <- nrow(get_produtos_base(token)) == 0
    df <- produtos_filtrados()

    if (nrow(df) == 0 && base_sem_dados) {
      return(mensagem_api_indisponivel())
    }

    if (view_mode() == "table") {
      withSpinner(DTOutput("produtos_table"), type = 6)
    } else {
      uiOutput("produtos_cards")
    }
  })
}
