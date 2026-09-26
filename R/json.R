# JSON 读写：数据与 spec 都从这里进出。
#
# 一律用 simplifyVector = FALSE 解析，保持 JSON 的原始形状，
# 由各图表自己决定怎么转成 data.frame —— 自动简化会把
# [{a:1},{a:2}] 这种规整数据悄悄变成 data.frame，反而不利于给出准确报错。

mint_read_json <- function(text, source = "<data>") {
  if (length(text) == 0 || all(trimws(text) == "")) {
    mint_fail("INVALID_DATA", sprintf("%s 是空的", source))
  }
  tryCatch(
    jsonlite::fromJSON(paste(text, collapse = "\n"), simplifyVector = FALSE),
    error = function(e) {
      mint_fail("INVALID_DATA", sprintf("%s 不是合法 JSON：%s", source, conditionMessage(e)),
                "mint 只接受 JSON；CSV 请先转成 JSON")
    }
  )
}

mint_read_json_file <- function(path) {
  if (!file.exists(path)) {
    mint_fail("DATA_NOT_FOUND", sprintf("读不到文件：%s", path))
  }
  mint_read_json(readLines(path, warn = FALSE), path)
}

#' --data 支持文件路径与 "-"（stdin）
mint_load_data <- function(source) {
  if (is.null(source) || identical(source, "")) return(NULL)
  if (identical(source, "-")) {
    return(list(data = mint_read_json(readLines(file("stdin"), warn = FALSE), "<stdin>"), from = "<stdin>"))
  }
  list(data = mint_read_json_file(source), from = source)
}

mint_to_json <- function(value, pretty = TRUE) {
  jsonlite::toJSON(value, auto_unbox = TRUE, null = "null", digits = NA,
                   pretty = pretty, force = TRUE)
}

mint_write_json <- function(value, path) {
  writeLines(as.character(mint_to_json(value, pretty = TRUE)), path)
  invisible(path)
}
