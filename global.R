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
  if (!nzchar(consumer_key) || !nzchar(consumer_secret)) {
    return(NULL)
  }

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
  if (is.null(token) || !nzchar(token)) {
    return(tibble())
  }

  base_url <- url_pesquisa_produtos
  pagina <- 1
  todos <- list()

  repeat {
    query_params <- list(page = pagina)
    if (!is.null(cultura) && nzchar(cultura)) {
      query_params$cultura <- cultura
    }

    res <- tryCatch(
      GET(
        url = base_url,
        query = query_params,
        add_headers(Authorization = paste("Bearer", token))
      ),
      error = function(e) NULL
    )

    if (is.null(res) || status_code(res) != 200) break

    conteudo <- tryCatch(
      content(res, as = "text", encoding = "UTF-8"),
      error = function(e) NULL
    )
    if (is.null(conteudo)) break
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

limpar_cache_produtos <- function(remover_arquivo = FALSE) {
  cache_keys <- ls(envir = .produtos_cache, all.names = TRUE)
  if (length(cache_keys) > 0) {
    rm(list = cache_keys, envir = .produtos_cache)
  }

  if (isTRUE(remover_arquivo) && file.exists(.cache_arquivo_produtos)) {
    unlink(.cache_arquivo_produtos)
  }
}

marcar_fonte_dados <- function(df, source) {
  attr(df, "data_source") <- source
  if (is.null(attr(df, "data_updated_at", exact = TRUE))) {
    attr(df, "data_updated_at") <- NA
  }
  df
}

marcar_data_atualizacao_dados <- function(df, updated_at) {
  attr(df, "data_updated_at") <- updated_at
  df
}

formatar_data_hora_cache <- function(updated_at) {
  if (is.null(updated_at) || length(updated_at) == 0 || all(is.na(updated_at))) {
    return(NA_character_)
  }

  updated_at <- tryCatch(
    as.POSIXct(updated_at, tz = "America/Sao_Paulo"),
    error = function(e) NA
  )

  if (all(is.na(updated_at))) {
    return(NA_character_)
  }

  format(updated_at[[1]], "%d/%m/%Y %H:%M")
}

ler_cache_produtos <- function(cache_path) {
  cache_obj <- tryCatch(readRDS(cache_path), error = function(e) NULL)
  if (is.null(cache_obj)) {
    return(NULL)
  }

  if (is.data.frame(cache_obj)) {
    return(list(
      data = cache_obj,
      updated_at = file.info(cache_path)$mtime[[1]]
    ))
  }

  if (is.list(cache_obj) && is.data.frame(cache_obj$data)) {
    updated_at <- cache_obj$updated_at
    if (is.null(updated_at) || all(is.na(updated_at))) {
      updated_at <- file.info(cache_path)$mtime[[1]]
    }

    return(list(
      data = cache_obj$data,
      updated_at = updated_at
    ))
  }

  NULL
}

get_produtos_base <- function(token, force_refresh = FALSE) {
  cache_key <- "__MELAO_MELANCIA_TODAS__"

  if (isTRUE(force_refresh)) {
    limpar_cache_produtos(remover_arquivo = TRUE)
  }

  if (exists(cache_key, envir = .produtos_cache, inherits = FALSE)) {
    df_memoria <- get(cache_key, envir = .produtos_cache, inherits = FALSE)
    df_memoria <- marcar_fonte_dados(df_memoria, "memory")
    return(df_memoria)
  }

  if (file.exists(.cache_arquivo_produtos)) {
    idade_horas <- as.numeric(difftime(Sys.time(), file.info(.cache_arquivo_produtos)$mtime, units = "hours"))
    if (!is.na(idade_horas) && idade_horas <= .cache_ttl_horas) {
      cache_payload <- ler_cache_produtos(.cache_arquivo_produtos)
      if (!is.null(cache_payload) && is.data.frame(cache_payload$data)) {
        df_cache <- cache_payload$data |>
          marcar_data_atualizacao_dados(cache_payload$updated_at) |>
          marcar_fonte_dados("disk_cache")
        assign(cache_key, df_cache, envir = .produtos_cache)
        return(df_cache)
      }
    }
  }

  if (is.null(token) || !nzchar(token)) {
    return(marcar_fonte_dados(normalizar_produtos(tibble()), "unavailable"))
  }

  culturas_labels <- names(CULTURAS_SUPORTADAS)

  dfs <- lapply(seq_along(culturas_labels), function(i) {
    cultura_label <- culturas_labels[[i]]
    cultura_api <- unname(CULTURAS_SUPORTADAS[[cultura_label]])
    df_c <- buscar_produtos_cultura(cultura_api, token)
    if (nrow(df_c) == 0) return(df_c)
    df_c$filtro_cultura <- cultura_label
    df_c
  })
  df <- bind_rows(dfs) |>
    normalizar_produtos()
  updated_at <- Sys.time()
  df <- df |>
    marcar_data_atualizacao_dados(updated_at) |>
    marcar_fonte_dados("api")

  dir.create(dirname(.cache_arquivo_produtos), showWarnings = FALSE, recursive = TRUE)
  try(saveRDS(list(data = df, updated_at = updated_at), .cache_arquivo_produtos), silent = TRUE)

  assign(cache_key, df, envir = .produtos_cache)
  df
}

# -------------------------------
# Pré-carregamento
# -------------------------------
dados_versao <- list(
  mantenedor = "MAPA",
  fonte = "https://agrofit.agricultura.gov.br/agrofit_cons/principal_agrofit_cons",
  url_mapa_dados = "https://api.cnptia.embrapa.br/agrofit/v1/versao",
  data_ultima_atualizacao = NA_character_
)

token <- tryCatch(
  gerar_token(consumer_key, consumer_secret),
  error = function(e) NULL
)

API_DISPONIVEL <- !is.null(token) && nzchar(token)

if (API_DISPONIVEL) {
  res_versao <- tryCatch(
    request(url_versao) |>
      req_headers(Authorization = paste("Bearer", token)) |>
      req_perform(),
    error = function(e) NULL
  )

  if (!is.null(res_versao)) {
    dados_versao_api <- tryCatch(
      resp_body_json(res_versao, simplifyVector = TRUE),
      error = function(e) NULL
    )

    if (is.list(dados_versao_api)) {
      dados_versao <- modifyList(dados_versao, dados_versao_api)
    }
  }
}

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
