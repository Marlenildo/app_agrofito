function(input, output, session) {
  
  # --- Login ---
  user_auth <- reactiveValues(logged_in = FALSE, login_fail = FALSE)
  
  valid_users <- data.frame(
    user = c(
      Sys.getenv("AGROFIT_USER_1"),
      Sys.getenv("AGROFIT_USER_2"),
      Sys.getenv("AGROFIT_USER_3")
    ),
    password = c(
      Sys.getenv("AGROFIT_PASS_1"),
      Sys.getenv("AGROFIT_PASS_2"),
      Sys.getenv("AGROFIT_PASS_3")
    ),
    stringsAsFactors = FALSE
  )
  
  
  output$login_ui <- renderUI({
    if (!user_auth$logged_in) {
      fluidRow(
        class = "login-box",
        img(src = "nova_logomm.png", height = 100),
        p("A MelonMundi oferece soluções inovadoras para melhorar o dia a dia do agricultor."),
        br(),
        tags$h2("Acesse o Agrofito"),
        br(),
        if (user_auth$login_fail) div(class = "login-error", "Usuário ou senha incorretos"),
        column(12, textInput("user", "Digite seu usuário:")),
        column(12, passwordInput("pass", "Digite sua senha:")),
        actionButton("login_btn", "Entrar")
      )
    }
  })
  
  output$loggedIn <- reactive({ user_auth$logged_in })
  outputOptions(output, "loggedIn", suspendWhenHidden = FALSE)
  
  observeEvent(input$login_btn, {
    req(input$user, input$pass)
    cred <- valid_users
    if (any(cred$user == input$user & cred$password == input$pass)) {
      user_auth$logged_in <- TRUE
      user_auth$login_fail <- FALSE
    } else {
      user_auth$login_fail <- TRUE
    }
  })
  
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
        distinct()
    }
    
    n <- nrow(df_filtrado)
    datatable(
      df_filtrado,
      rownames = TRUE,
      caption = paste0(
        "Lista de ", toupper(input$grupo),
        " disponíveis para ", input$cultura,
        " — Quantidade de produtos distintos: ", n
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
          search = "Pesquisar:",
          lengthMenu = "Mostrar _MENU_ registros",
          info = "Mostrando de _START_ até _END_ de _TOTAL_ registros",
          zeroRecords = "Nenhum registro encontrado",
          emptyTable = "Nenhum dado disponível na tabela"
        )
      ),
      extensions = 'Buttons'
    )
  })
  
  output$produtos_cards <- renderUI({
    df <- produtos_reactive()
    req(input$grupo, input$cultura)
    
    if (nrow(df) == 0) {
      return(
        div(class = "empty-box",
            "Nenhum produto encontrado para os filtros selecionados.")
      )
    }
    
    df_filtrado <- df |>
      filter(GRUPO == input$grupo) |>
      distinct(
        cultura,
        classe_categoria_agronomica,
        marca_comercial,
        ingrediente_ativo,
        prazo_de_seguranca
      )
    
    tagList(
      lapply(seq_len(nrow(df_filtrado)), function(i) {
        produto <- df_filtrado[i, ]
        
        div(
          class = "produto-card",
          h4(produto$marca_comercial),
          p(strong("Ingrediente ativo: "), produto$ingrediente_ativo),
          p(strong("Classe: "), produto$classe_categoria_agronomica),
          p(strong("Cultura: "), produto$cultura),
          p(strong("Prazo de segurança: "), produto$prazo_de_seguranca)
        )
      })
    )
  })
  
  
}