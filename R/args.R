# 极简参数解析：支持 --flag value、--flag=value、-f value 与可重复的 list 参数。

mint_flag <- function(name, alias = NULL, type = "string", description = "", placeholder = NULL) {
  list(name = name, alias = alias, type = type, description = description, placeholder = placeholder)
}

mint_parse_args <- function(argv, specs) {
  values <- list()
  positionals <- character(0)
  i <- 1
  find_spec <- function(token) {
    key <- sub("^--?", "", token)
    for (spec in specs) {
      if (identical(spec$name, key) || (!is.null(spec$alias) && identical(spec$alias, key))) return(spec)
    }
    NULL
  }

  while (i <= length(argv)) {
    token <- argv[[i]]
    if (grepl("^--?[A-Za-z]", token)) {
      spec <- find_spec(token)
      if (is.null(spec)) {
        mint_fail("UNKNOWN_FLAG", sprintf("无法识别的参数：%s", token), "用 mint help 查看可用参数")
      }
      value <- NULL
      if (grepl("=", token, fixed = TRUE)) {
        value <- sub("^[^=]*=", "", token)
      }
      if (identical(spec$type, "boolean")) {
        values[[spec$name]] <- if (is.null(value)) TRUE else mint_parse_bool(value, token)
      } else {
        if (is.null(value)) {
          i <- i + 1
          if (i > length(argv)) {
            mint_fail("MISSING_ARGUMENT", sprintf("%s 缺少取值", token))
          }
          value <- argv[[i]]
        }
        if (identical(spec$type, "list")) {
          values[[spec$name]] <- c(values[[spec$name]] %||% character(0), value)
        } else {
          values[[spec$name]] <- value
        }
      }
    } else {
      positionals <- c(positionals, token)
    }
    i <- i + 1
  }

  list(positionals = positionals, values = values)
}

mint_parse_bool <- function(text, token) {
  if (text %in% c("true", "1", "yes", "on")) return(TRUE)
  if (text %in% c("false", "0", "no", "off")) return(FALSE)
  mint_fail("INVALID_VALUE", sprintf("%s 需要布尔值，收到「%s」", token, text))
}

mint_arg <- function(parsed, name, default = NULL) parsed$values[[name]] %||% default

#' 把 --set 的字符串还原成字面量（布尔/数值/数组/对象）
mint_coerce_literal <- function(text) {
  text <- trimws(text)
  if (identical(text, "true")) return(TRUE)
  if (identical(text, "false")) return(FALSE)
  if (identical(text, "null")) return(NULL)
  if (grepl("^-?[0-9]+(\\.[0-9]+)?$", text)) return(as.numeric(text))
  if (grepl("^[\\[{]", text)) {
    parsed <- tryCatch(jsonlite::fromJSON(text, simplifyVector = FALSE), error = function(e) NULL)
    if (!is.null(parsed)) return(parsed)
  }
  text
}

mint_parse_set_flags <- function(entries) {
  options <- list()
  for (entry in entries %||% character(0)) {
    eq <- regexpr("=", entry, fixed = TRUE)
    if (eq <= 1) {
      mint_fail("INVALID_VALUE", sprintf("--set 需要 key=value 形式，收到「%s」", entry),
                "例如 --set groupMode=stacked")
    }
    key <- trimws(substr(entry, 1, eq - 1))
    options[[key]] <- mint_coerce_literal(substr(entry, eq + 1, nchar(entry)))
  }
  options
}

mint_parse_options_json <- function(raw) {
  if (is.null(raw) || !nzchar(raw)) return(list())
  parsed <- tryCatch(jsonlite::fromJSON(raw, simplifyVector = FALSE), error = function(e) {
    mint_fail("INVALID_VALUE", sprintf("--options 不是合法 JSON：%s", conditionMessage(e)))
  })
  if (!is.list(parsed) || !is.null(names(parsed)) && any(!nzchar(names(parsed)))) {
    mint_fail("INVALID_VALUE", "--options 需要是一个 JSON 对象")
  }
  if (!is.null(names(parsed)) && length(names(parsed)) == 0) {
    mint_fail("INVALID_VALUE", "--options 需要是一个 JSON 对象")
  }
  parsed
}

#' 打印参数表
mint_flag_table <- function(specs) {
  lines <- character(0)
  for (spec in specs) {
    flag <- if (is.null(spec$alias)) sprintf("--%s", spec$name) else sprintf("-%s, --%s", spec$alias, spec$name)
    if (!identical(spec$type, "boolean")) flag <- paste(flag, spec$placeholder %||% "<value>")
    lines <- c(lines, sprintf("  %-28s %s", flag, spec$description))
  }
  lines
}
