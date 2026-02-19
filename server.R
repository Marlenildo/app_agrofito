function(input, output, session) {

  # -------------------------------
  # Carrega lista de culturas
  # -------------------------------
  res_c <- request(url_culturas) |>
    req_headers(Authorization = paste("Bearer", token)) |>
    req_perform()

  dados_culturas <- resp_body_json(res_c, simplifyVector = TRUE)
  culturas <- sort(unique(dados_culturas$nome))

  # Mantemos opÃ§Ãµes principais e adicionamos o padrÃ£o sem filtro.
  updateSelectInput(
    session,
    "cultura",
    choices = c("Todos os produtos", "MelÃ£o", "Melancia", "Todas as culturas"),
    selected = "Todos os produtos"
  )

  # -------------------------------
  # Produtos reativos (base)
  # -------------------------------
  produtos_reactive <- reactive({
    req(input$cultura)

    cultura_consulta <- if (identical(input$cultura, "Todos os produtos")) {
      NULL
    } else {
      input$cultura
    }

    df <- buscar_produtos_cultura(cultura_consulta, token)

    # Se vier vazio, retorna tibble vazio logo
    if (nrow(df) == 0) {
      return(tibble(
        cultura = character(),
        classe_categoria_agronomica = character(),
        marca_comercial = character(),
        ingrediente_ativo = character(),
        prazo_de_seguranca = character(),
        GRUPO = character()
      ))
    }

    # NÃ£o vamos mais fazer unnest em 'indicacao_uso' para evitar erros de tipos mistos,
    # atÃ© porque ela nÃ£o Ã© usada na tabela final.
    if ("indicacao_uso" %in% names(df)) {
      df$indicacao_uso <- NULL
    }

    # Filtra pela cultura somente quando for uma cultura especÃ­fica.
    if (input$cultura %in% c("MelÃ£o", "Melancia") && "cultura" %in% names(df)) {
      df <- df |> filter(cultura == input$cultura)
    }

    # Cria coluna GRUPO a partir da classe agronÃ´mica
    if ("classe_categoria_agronomica" %in% names(df)) {
      df <- df |>
        mutate(
          GRUPO = case_when(
            grepl("BiolÃ³gico", classe_categoria_agronomica, ignore.case = TRUE) ~ "BiolÃ³gico",
            grepl("Fungicida", classe_categoria_agronomica, ignore.case = TRUE) ~ "Fungicida",
            grepl("Inseticida", classe_categoria_agronomica, ignore.case = TRUE) ~ "Inseticida",
            grepl("Herbicida", classe_categoria_agronomica, ignore.case = TRUE) ~ "Herbicida",
            TRUE ~ "Outros"
          )
        )
    } else {
      df$GRUPO <- "Outros"
    }

    df
  })

  observe({
    df <- produtos_reactive()

    if (!"GRUPO" %in% names(df) || nrow(df) == 0) {
      grupos <- character(0)
    } else {
      grupos <- sort(unique(df$GRUPO))
    }

    if (length(grupos) == 0) grupos <- "Outros"

    grupos <- c("Todas as classes", grupos)

    updateSelectInput(
      session,
      "grupo",
      choices = grupos,
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
      df <- df |> filter(GRUPO == input$grupo)
    }

    busca <- trimws(if (is.null(input$busca_produto)) "" else input$busca_produto)

    if (nzchar(busca)) {
      busca_lower <- tolower(busca)
      cols_busca <- intersect(
        c("marca_comercial", "ingrediente_ativo", "classe_categoria_agronomica", "cultura"),
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
        cultura = character(),
        classe_categoria_agronomica = character(),
        marca_comercial = character(),
        ingrediente_ativo = character(),
        prazo_de_seguranca = character()
      )
    } else {
      df_filtrado <- df |>
        dplyr::select(any_of(
          c("cultura",
            "classe_categoria_agronomica",
            "marca_comercial",
            "ingrediente_ativo",
            "prazo_de_seguranca")
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
        " disponÃ­veis para ", input$cultura,
        " â€” Quantidade de produtos distintos: ", nrow(df_filtrado)
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
        "cultura",
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
          if ("cultura" %in% names(produto)) p(strong("Cultura: "), to_text(produto$cultura)),
          if ("prazo_de_seguranca" %in% names(produto)) p(strong("Prazo de seguranÃ§a: "), to_text(produto$prazo_de_seguranca))
        )
      })
    )
  })

  output$result_view <- renderUI({
    if (view_mode() == "table") {
      withSpinner(DTOutput("produtos_table"), type = 6)
    } else {
      uiOutput("produtos_cards")
    }
  })
}
