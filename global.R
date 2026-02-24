library(shiny)
library(DT)
library(shinycssloaders)
library(httr)
library(httr2)
library(jsonlite)
library(dplyr)
library(tidyr)
library(tibble)
library(lubridate)
library(base64enc)
library(sodium)
library(shinyjs)

# -------------------------------
# Configuração da API Agrofit
# -------------------------------
url_token <- "https://api.cnptia.embrapa.br/token"
url_versao <- "https://api.cnptia.embrapa.br/agrofit/v1/versao"
url_culturas <- "https://api.cnptia.embrapa.br/agrofit/v1/culturas"
url_pesquisa_produtos <- "https://api.cnptia.embrapa.br/agrofit/v1/search/produtos-formulados"
CULTURAS_SUPORTADAS <- c(
  "Melão" = "Melao",
  "Melancia" = "Melancia",
  "Todas as culturas" = "Todas as culturas"
)

consumer_key <- Sys.getenv("CONSUMER_KEY")
consumer_secret <- Sys.getenv("CONSUMER_SECRET")

# -------------------------------
# Funções auxiliares
# -------------------------------
gerar_token <- function(consumer_key, consumer_secret) {
  res <- POST(
    url = url_token,
    body = list(grant_type = "client_credentials"),
    encode = "form",
    add_headers(Authorization = paste(
      "Basic", base64encode(charToRaw(
        paste0(consumer_key, ":", consumer_secret)
      ))
    ))
  )
  stop_for_status(res)
  conteudo <- content(res, as = "parsed", encoding = "UTF-8")
  conteudo$access_token
}

formatar_data <- function(data_iso) {
  if (is.null(data_iso) || is.na(data_iso) || data_iso == "") {
    return(NA_character_)
  }

  formatos <- c(
    "%Y-%m-%dT%H:%M:%S",
    "%Y-%m-%dT%H:%M:%S%z",
    "%Y-%m-%dT%H:%M:%OS%z",
    "%Y-%m-%d %H:%M:%S",
    "%Y-%m-%d",
    "%d/%m/%Y %H:%M",
    "%d/%m/%Y"
  )

  for (f in formatos) {
    dt <- suppressWarnings(as.POSIXct(data_iso, format = f, tz = "America/Sao_Paulo"))
    if (!is.na(dt)) {
      return(format(dt, "%d %b %Y às %H:%M"))
    }
  }

  dt2 <- suppressWarnings(lubridate::ymd_hms(data_iso, tz = "America/Sao_Paulo"))
  if (!is.na(dt2)) {
    return(format(dt2, "%d %b %Y às %H:%M"))
  }

  NA_character_
}

buscar_produtos_cultura <- function(cultura, token) {
  base_url <- url_pesquisa_produtos
  pagina <- 1
  todos <- list()

  repeat {
    query_params <- list(page = pagina)
    if (!is.null(cultura) && nzchar(cultura)) {
      query_params$cultura <- cultura
    }

    res <- GET(
      url = base_url,
      query = query_params,
      add_headers(Authorization = paste("Bearer", token))
    )

    if (status_code(res) != 200) break

    conteudo <- content(res, as = "text", encoding = "UTF-8")
    dados <- tryCatch(fromJSON(conteudo, flatten = TRUE), error = function(e) NULL)
    if (is.null(dados) || length(dados) == 0) break

    df_pag <- as.data.frame(dados)
    todos <- append(todos, list(df_pag))

    if (nrow(df_pag) < 100) break
    pagina <- pagina + 1
  }

  if (length(todos) == 0) return(tibble())
  bind_rows(todos)
}

remover_acentos <- function(x) {
  out <- iconv(x, from = "UTF-8", to = "ASCII//TRANSLIT")
  ifelse(is.na(out), x, out)
}

extrair_coluna_indicacao <- function(indicacao_uso, coluna, fallback = NA_character_) {
  if (is.null(indicacao_uso) || !is.data.frame(indicacao_uso) || !(coluna %in% names(indicacao_uso))) {
    return(fallback)
  }

  vals <- unique(trimws(as.character(indicacao_uso[[coluna]])))
  vals <- vals[nzchar(vals)]
  if (length(vals) == 0) fallback else paste(vals, collapse = ", ")
}

normalizar_produtos <- function(df) {
  if (nrow(df) == 0) {
    return(tibble(
      cultura = character(),
      classe_categoria_agronomica = character(),
      marca_comercial = character(),
      ingrediente_ativo = character(),
      prazo_de_seguranca = character(),
      alvo = character(),
      GRUPO = character()
    ))
  }

  if ("indicacao_uso" %in% names(df)) {
    df$cultura <- vapply(df$indicacao_uso, extrair_coluna_indicacao, character(1), coluna = "cultura")
    df$alvo <- vapply(df$indicacao_uso, extrair_coluna_indicacao, character(1), coluna = "praga_nome_comum")
    df$indicacao_uso <- NULL
  } else {
    if (!("cultura" %in% names(df))) df$cultura <- NA_character_
    if (!("alvo" %in% names(df))) df$alvo <- NA_character_
  }

  if (!("prazo_de_seguranca" %in% names(df))) {
    df$prazo_de_seguranca <- NA_character_
  }

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
}

# Cache em memória (evita redownload dentro do processo do app)
.produtos_cache <- new.env(parent = emptyenv())
.cache_arquivo_produtos <- file.path("cache", "produtos_melao_melancia_todas.rds")
.cache_ttl_horas <- 24

get_produtos_base <- function(token) {
  cache_key <- "__MELAO_MELANCIA_TODAS__"

  if (exists(cache_key, envir = .produtos_cache, inherits = FALSE)) {
    return(get(cache_key, envir = .produtos_cache, inherits = FALSE))
  }

  if (file.exists(.cache_arquivo_produtos)) {
    idade_horas <- as.numeric(difftime(Sys.time(), file.info(.cache_arquivo_produtos)$mtime, units = "hours"))
    if (!is.na(idade_horas) && idade_horas <= .cache_ttl_horas) {
      df_cache <- tryCatch(readRDS(.cache_arquivo_produtos), error = function(e) NULL)
      if (is.data.frame(df_cache)) {
        assign(cache_key, df_cache, envir = .produtos_cache)
        return(df_cache)
      }
    }
  }

  dfs <- lapply(names(CULTURAS_SUPORTADAS), function(cultura_label) {
    cultura_api <- unname(CULTURAS_SUPORTADAS[[cultura_label]])
    df_c <- buscar_produtos_cultura(cultura_api, token)
    if (nrow(df_c) == 0) return(df_c)
    df_c$filtro_cultura <- cultura_label
    df_c
  })
  df <- bind_rows(dfs) |>
    normalizar_produtos()

  dir.create(dirname(.cache_arquivo_produtos), showWarnings = FALSE, recursive = TRUE)
  try(saveRDS(df, .cache_arquivo_produtos), silent = TRUE)

  assign(cache_key, df, envir = .produtos_cache)
  df
}

# -------------------------------
# Pré-carregamento
# -------------------------------
token <- gerar_token(consumer_key, consumer_secret)

res_versao <- request(url_versao) |>
  req_headers(Authorization = paste("Bearer", token)) |>
  req_perform()

dados_versao <- resp_body_json(res_versao, simplifyVector = TRUE)

# -------------------------------
# Versão do aplicativo
# -------------------------------
APP_VERSION <- tryCatch(
  readLines("VERSION", warn = FALSE)[1],
  error = function(e) "dev"
)

to_text <- function(x) {
  if (is.null(x) || length(x) == 0) return("Não informado")
  if (all(is.na(x))) return("Não informado")

  if (is.atomic(x) && length(x) > 1) {
    vals <- x[!is.na(x) & trimws(as.character(x)) != ""]
    if (length(vals) == 0) return("Não informado")
    return(paste(vals, collapse = ", "))
  }

  x <- as.character(x)
  if (!nzchar(x) || identical(x, "NA")) return("Não informado")

  if (grepl("^c\\(", x)) {
    x <- gsub('^c\\(|\\)$', "", x)
    x <- gsub('"', "", x)
    return(x)
  }

  x
}

classe_badges <- function(x) {
  if (is.null(x) || length(x) == 0) return(NULL)

  if (is.list(x)) {
    x <- unlist(x, use.names = FALSE)
  }

  x <- as.character(x)

  if (length(x) == 1 && grepl("^c\\(", x)) {
    x <- gsub('^c\\(|\\)$', "", x)
    x <- gsub('"', "", x)
    x <- strsplit(x, ",\\s*")[[1]]
  }

  x <- trimws(x)
  x <- x[x != ""]

  if (length(x) == 0) return(NULL)

  tagList(
    lapply(x, function(classe) {
      classe_css <- switch(
        tolower(classe),
        "fungicida" = "badge-fungicida",
        "inseticida" = "badge-inseticida",
        "herbicida" = "badge-herbicida",
        "acaricida" = "badge-acaricida",
        "biológico" = "badge-biologico",
        "badge-outros"
      )

      span(class = paste("badge", classe_css), classe)
    })
  )
}
