# 统一的错误类型与退出码。
#
# mint 的所有可预期失败都走 mint_fail()，带上机器可读的 code 与给人看的 hint。
# cli.R 顶层捕获后打印成:
#   mint: [CODE] message
#         hint

mint_condition <- function(code, message, hint = NULL) {
  structure(
    class = c("mint_error", "error", "condition"),
    list(message = message, call = NULL, code = code, hint = hint)
  )
}

mint_fail <- function(code, message, hint = NULL) {
  stop(mint_condition(code, message, hint))
}

mint_warn <- function(message) {
  message(sprintf("mint: %s", message))
}

#' 把错误渲染成终端文本
mint_format_error <- function(cond) {
  if (inherits(cond, "mint_error")) {
    out <- sprintf("mint: [%s] %s", cond$code, conditionMessage(cond))
    if (!is.null(cond$hint)) out <- paste0(out, "\n      ", cond$hint)
    return(out)
  }
  sprintf("mint: [INTERNAL] %s", conditionMessage(cond))
}

mint_error_code <- function(cond) {
  if (inherits(cond, "mint_error")) cond$code else "INTERNAL"
}
