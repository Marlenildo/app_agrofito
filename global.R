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

consumer_key  <- Sys.getenv("CONSUMER_KEY")
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
  
  return(NA_character_)
}

buscar_produtos_cultura <- function(cultura, token) {
  base_url <- url_pesquisa_produtos
  pagina <- 1
  todos <- list()
  
  repeat {
    res <- GET(
      url = base_url,
      query = list(cultura = cultura, page = pagina),
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
