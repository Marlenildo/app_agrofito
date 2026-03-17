function(input, output, session) {
  carregando_base <- reactiveVal(TRUE)
  mensagem_carregamento <- reactiveVal(list(
    title = "Carregando dados do AGROFIT...",
    detail = "Lendo cache local ou preparando o primeiro download."
  ))
  dados_base <- reactiveVal(normalizar_produtos(tibble()))
  status_dados <- reactiveVal(NULL)

  mensagem_api_indisponivel <- function() {
    div(
      class = "empty-box",
      strong("Consulta indisponivel no momento."),
      p("Nao foi possivel acessar a API do AGROFIT agora. Tente novamente em alguns minutos.")
    )
  }

  loading_hint_ui <- function() {
    info <- mensagem_carregamento()

    div(
      class = "loading-hint-inline",
      div(class = "loading-hint-title", info$title),
      div(class = "loading-hint-detail", info$detail)
    )
  }

  formatar_contagem <- function(n) {
    format(n, big.mark = ".", decimal.mark = ",", trim = TRUE, scientific = FALSE)
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

  montar_status_dados <- function(data_source, updated_at = NULL, force_refresh = FALSE) {
    data_hora <- formatar_data_hora_cache(updated_at)

    if (identical(data_source, "api")) {
      list(
        class = "success",
        icon = "download",
        text = if (!is.na(data_hora)) {
          if (isTRUE(force_refresh)) {
            paste0("Base baixada agora do AGROFIT em ", data_hora, ".")
          } else {
            paste0("Base baixada do AGROFIT em ", data_hora, ".")
          }
        } else if (isTRUE(force_refresh)) {
          "Base baixada agora do AGROFIT."
        } else {
          "Base baixada do AGROFIT."
        }
      )
    } else if (identical(data_source, "disk_cache")) {
      list(
        class = "neutral",
        icon = "database",
        text = if (!is.na(data_hora)) {
          paste0("Consulta usando cache local, baixado em ", data_hora, ".")
        } else {
          "Consulta usando cache local salvo anteriormente neste computador."
        }
      )
    } else if (identical(data_source, "memory")) {
      list(
        class = "neutral",
        icon = "database",
        text = if (!is.na(data_hora)) {
          paste0("Consulta usando base ja carregada nesta sessao, baixada em ", data_hora, ".")
        } else {
          "Consulta usando base ja carregada nesta sessao."
        }
      )
    } else {
      list(
        class = "warning",
        icon = "triangle-exclamation",
        text = "Nao foi possivel carregar dados do AGROFIT neste momento."
      )
    }
  }

  carregar_base_produtos <- function(force_refresh = FALSE) {
    carregando_base(TRUE)
    status_dados(NULL)

    if (isTRUE(force_refresh)) {
      mensagem_carregamento(list(
        title = "Atualizando dados do AGROFIT...",
        detail = "Baixando a versao mais recente da base."
      ))
    } else {
      mensagem_carregamento(list(
        title = "Carregando dados do AGROFIT...",
        detail = "Lendo cache local ou preparando o primeiro download."
      ))
    }

    df <- tryCatch(
      get_produtos_base(token, force_refresh = force_refresh),
      error = function(e) normalizar_produtos(tibble())
    )

    dados_base(df)
    status_dados(montar_status_dados(
      attr(df, "data_source"),
      updated_at = attr(df, "data_updated_at", exact = TRUE),
      force_refresh = force_refresh
    ))
    carregando_base(FALSE)
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

  updateSelectizeInput(
    session,
    "grupo",
    choices = "Todas as classes",
    selected = "Todas as classes",
    options = selectize_mobile_options
  )

  observeEvent(TRUE, {
    carregar_base_produtos(force_refresh = FALSE)
  }, once = TRUE)

  # -------------------------------
  # Produtos reativos (base)
  # -------------------------------
  produtos_reactive <- reactive({
    req(input$cultura)

    df <- dados_base()

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

    grupo_selecionado <- isolate(input$grupo)
    grupo_default <- if (!is.null(grupo_selecionado) && grupo_selecionado %in% c("Todas as classes", grupos)) {
      grupo_selecionado
    } else {
      "Todas as classes"
    }

    updateSelectizeInput(
      session,
      "grupo",
      choices = c("Todas as classes", grupos),
      selected = grupo_default,
      options = selectize_mobile_options
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

    updateSelectizeInput(
      session,
      "cultura",
      selected = "Todos os produtos",
      options = selectize_mobile_options
    )

    updateSelectizeInput(
      session,
      "grupo",
      choices = "Todas as classes",
      selected = "Todas as classes",
      options = selectize_mobile_options
    )
  })

  observeEvent(input$btn_atualizar_dados, {
    carregar_base_produtos(force_refresh = TRUE)
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

  output$data_status <- renderUI({
    info <- status_dados()

    if (is.null(info) || carregando_base()) {
      return(NULL)
    }

    div(
      class = paste("data-status-line", paste0("data-status-", info$class)),
      icon(info$icon, class = "data-status-icon"),
      span(class = "data-status-message", info$text)
    )
  })

  output$filters_summary <- renderUI({
    req(input$cultura, input$grupo)

    df_cultura <- preparar_produtos_exibicao(aplicar_busca(produtos_reactive(), input$busca_produto))
    df_classe <- preparar_produtos_exibicao(aplicar_busca(produtos_por_classe(), input$busca_produto))

    classe_label <- dplyr::case_when(
      identical(input$grupo, "Biológico") ~ "Biológicos",
      identical(input$grupo, "Fungicida") ~ "Fungicidas",
      identical(input$grupo, "Inseticida") ~ "Inseticidas",
      identical(input$grupo, "Herbicida") ~ "Herbicidas",
      identical(input$grupo, "Outros") ~ "Outros",
      TRUE ~ input$grupo
    )

    resumo_itens <- list(
      tags$span(
        class = "summary-inline-item",
        tags$strong(
          if (identical(input$cultura, "Todos os produtos")) "Total de produtos" else input$cultura
        ),
        paste0(": ", formatar_contagem(nrow(df_cultura)))
      )
    )

    if (!identical(input$grupo, "Todas as classes")) {
      resumo_itens <- c(
        resumo_itens,
        list(
          tags$span(
            class = "summary-inline-item",
            tags$strong(classe_label),
            paste0(": ", formatar_contagem(nrow(df_classe)))
          )
        )
      )
    }

    div(class = "summary-inline", resumo_itens)
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
    if (carregando_base()) {
      return(
        div(
          class = "result-loading-box",
          loading_hint_ui()
        )
      )
    }

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
