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
# ConfiguraÃ§Ã£o da API Agrofit
# -------------------------------
url_token <- "https://api.cnptia.embrapa.br/token"
url_versao <- "https://api.cnptia.embrapa.br/agrofit/v1/versao"
url_culturas <- "https://api.cnptia.embrapa.br/agrofit/v1/culturas"
url_pesquisa_produtos <- "https://api.cnptia.embrapa.br/agrofit/v1/search/produtos-formulados"

consumer_key  <- Sys.getenv("CONSUMER_KEY")
consumer_secret <- Sys.getenv("CONSUMER_SECRET")

# -------------------------------
# FunÃ§Ãµes auxiliares
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
      return(format(dt, "%d %b %Y Ã s %H:%M"))
    }
  }
  
  dt2 <- suppressWarnings(lubridate::ymd_hms(data_iso, tz = "America/Sao_Paulo"))
  if (!is.na(dt2)) {
    return(format(dt2, "%d %b %Y Ã s %H:%M"))
  }
  
  return(NA_character_)
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

# -------------------------------
# PrÃ©-carregamento
# -------------------------------
token <- gerar_token(consumer_key, consumer_secret)

res_versao <- request(url_versao) |>
  req_headers(Authorization = paste("Bearer", token)) |>
  req_perform()

dados_versao <- resp_body_json(res_versao, simplifyVector = TRUE)


# -------------------------------
# VersÃ£o do aplicativo
# -------------------------------
APP_VERSION <- tryCatch(
  readLines("VERSION", warn = FALSE)[1],
  error = function(e) "dev"
)

to_text <- function(x) {
  if (is.null(x) || length(x) == 0) return("NÃ£o informado")
  
  # Caso 1: vetor real
  if (is.atomic(x) && length(x) > 1) {
    return(paste(x, collapse = ", "))
  }
  
  x <- as.character(x)
  
  # Caso 2: string no formato c("A","B")
  if (grepl("^c\\(", x)) {
    x <- gsub('^c\\(|\\)$', '', x)
    x <- gsub('"', '', x)
    return(x)
  }
  
  x
}

classe_badges <- function(x) {
  
  if (is.null(x) || length(x) == 0) return(NULL)
  
  # ðŸ”§ NormalizaÃ§Ã£o TOTAL para character vector
  if (is.list(x)) {
    x <- unlist(x, use.names = FALSE)
  }
  
  x <- as.character(x)
  
  # Caso venha como string "c('A','B')"
  if (length(x) == 1 && grepl("^c\\(", x)) {
    x <- gsub('^c\\(|\\)$', '', x)
    x <- gsub('"', '', x)
    x <- strsplit(x, ",\\s*")[[1]]
  }
  
  x <- trimws(x)
  x <- x[x != ""]
  
  if (length(x) == 0) return(NULL)
  
  tagList(
    lapply(x, function(classe) {
      
      classe_css <- switch(
        tolower(classe),
        "fungicida"   = "badge-fungicida",
        "inseticida"  = "badge-inseticida",
        "herbicida"   = "badge-herbicida",
        "acaricida"   = "badge-acaricida",
        "biolÃ³gico"   = "badge-biologico",
        "badge-outros"
      )
      
      span(class = paste("badge", classe_css), classe)
    })
  )
}
