function(input, output, session) {
  
  
  # -------------------------------
  # Carrega lista de culturas
  # -------------------------------
  res_c <- request(url_culturas) |>
    req_headers(Authorization = paste("Bearer", token)) |>
    req_perform()
  
  dados_culturas <- resp_body_json(res_c, simplifyVector = TRUE)
  culturas <- sort(unique(dados_culturas$nome))
  
  # Se quiser usar toda a lista de culturas da API, pode trocar esta linha por:
  # updateSelectInput(session, "cultura",
  #                   choices = c("Todas as culturas", culturas),
  #                   selected = "Melancia")
  updateSelectInput(session, "cultura",
                    choices = c("Melão", "Melancia", "Todas as culturas"),
                    selected = "Melancia")
  
  # -------------------------------
  # Produtos reativos
  # -------------------------------
  produtos_reactive <- reactive({
    req(input$cultura)
    
    df <- buscar_produtos_cultura(input$cultura, token)
    
    # Se vier vazio, retorna tibble vazio logo
    if (nrow(df) == 0) {
      df <- tibble(
        cultura = character(),
        classe_categoria_agronomica = character(),
        marca_comercial = character(),
        ingrediente_ativo = character(),
        prazo_de_seguranca = character(),
        GRUPO = character()
      )
      return(df)
    }
    
    # NÃO vamos mais fazer unnest em 'indicacao_uso' para evitar erros de tipos mistos,
    # até porque ela não é usada na tabela final.
    if ("indicacao_uso" %in% names(df)) {
      df$indicacao_uso <- NULL
    }
    
    # Filtra pela cultura (exceto "Todas as culturas")
    if (input$cultura != "Todas as culturas" && "cultura" %in% names(df)) {
      df <- df |> filter(cultura == input$cultura)
    }
    
    # Cria coluna GRUPO a partir da classe agronômica
    if ("classe_categoria_agronomica" %in% names(df)) {
      df <- df |>
        mutate(
          GRUPO = case_when(
            grepl("Biológico", classe_categoria_agronomica, ignore.case = TRUE) ~ "Biológico",
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
    updateSelectInput(session, "grupo", choices = grupos, selected = grupos[1])
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
    df <- produtos_reactive()
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
        filter(GRUPO == input$grupo) |>
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
                if (is.null(y)) NA_character_
                else paste(unlist(y), collapse = ", ")
              })
            } else {
              as.character(.x)
            }
          }
        )) |>
        distinct()
    }
    
    datatable(
      df_filtrado,
      rownames = TRUE,
      caption = paste0(
        "Lista de ", toupper(input$grupo),
        " disponíveis para ", input$cultura,
        " — Quantidade de produtos distintos: ", nrow(df_filtrado)
      ),
      options = list(
        dom = "Blfrtip",
        pageLength = 10,
        lengthMenu = list(
          c(10, 25, 50, 100, -1),
          c('10', '25', '50', '100', 'Todos')
        ),
        responsive = TRUE,
        scrollX = TRUE,
        buttons = c('copy', 'excel', 'pdf'),
        language = list(
          url = "//cdn.datatables.net/plug-ins/1.13.8/i18n/pt-BR.json"
        )
      ),
      extensions = 'Buttons'
    )
  })
  
  
  output$produtos_cards <- renderUI({
    df <- produtos_reactive()
    req(input$grupo)
    
    if (nrow(df) == 0) {
      return(
        div(class = "empty-box",
            "Nenhum produto encontrado para os filtros selecionados.")
      )
    }
    
    df_filtrado <- df |>
      filter(GRUPO == input$grupo) |>
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
          p(strong("Ingrediente ativo: "),
            to_text(produto$ingrediente_ativo)),
          div(
            class = "produto-classes",
            classe_badges(produto$classe_categoria_agronomica)
          ),
          if ("cultura" %in% names(produto))
            p(strong("Cultura: "),
              to_text(produto$cultura)),
          if ("prazo_de_seguranca" %in% names(produto))
            p(strong("Prazo de segurança: "),
              to_text(produto$prazo_de_seguranca))
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
