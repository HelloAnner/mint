# 极简测试框架：不引 testthat，靠 base R 打断言。
# 用法：Rscript tests/run-tests.R

MINT_TEST_HOME <- normalizePath(file.path(dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1]))), ".."))
Sys.setenv(MINT_HOME = MINT_TEST_HOME)
lib <- Sys.getenv("MINT_LIB", unset = file.path(Sys.getenv("HOME"), ".local", "share", "mint", "rlib"))
if (dir.exists(lib)) .libPaths(c(lib, .libPaths()))

source(file.path(MINT_TEST_HOME, "R", "load.R"), encoding = "UTF-8")
mint_load_sources(MINT_TEST_HOME)

MINT_TEST_STATE <- new.env(parent = emptyenv())
MINT_TEST_STATE$passed <- 0L
MINT_TEST_STATE$failed <- 0L
MINT_TEST_STATE$failures <- character(0)

ok <- function(condition, label) {
  if (isTRUE(condition)) {
    MINT_TEST_STATE$passed <- MINT_TEST_STATE$passed + 1L
  } else {
    MINT_TEST_STATE$failed <- MINT_TEST_STATE$failed + 1L
    MINT_TEST_STATE$failures <- c(MINT_TEST_STATE$failures, label)
    cat(sprintf("  FAIL  %s\n", label))
  }
  invisible(isTRUE(condition))
}

#' 断言某个表达式抛出 mint 错误（并返回错误码）
fails_with <- function(expr, code = NULL, label = "") {
  err <- tryCatch({ expr; NULL }, error = function(e) e)
  if (is.null(err)) {
    ok(FALSE, sprintf("%s（预期报错但成功了）", label))
    return(invisible(NULL))
  }
  if (!inherits(err, "mint_error")) {
    ok(FALSE, sprintf("%s（错误类型不对：%s）", label, conditionMessage(err)))
    return(invisible(NULL))
  }
  if (!is.null(code) && !identical(err$code, code)) {
    ok(FALSE, sprintf("%s（错误码 %s，预期 %s）", label, err$code, code))
    return(invisible(NULL))
  }
  ok(TRUE, label)
  invisible(err$code)
}

test_file <- function(name) source(file.path(MINT_TEST_HOME, "tests", name), encoding = "UTF-8")

cat(sprintf("mint 测试（R %s）\n\n", paste(R.version$major, R.version$minor, sep = ".")))
for (suite in c("test-core.R", "test-render.R", "test-charts.R")) {
  path <- file.path(MINT_TEST_HOME, "tests", suite)
  if (!file.exists(path)) next
  cat(sprintf("── %s\n", suite))
  tryCatch(source(path, encoding = "UTF-8"), error = function(e) {
    ok(FALSE, sprintf("%s 执行异常：%s", suite, conditionMessage(e)))
  })
  cat("\n")
}

cat(sprintf("%d 通过，%d 失败\n", MINT_TEST_STATE$passed, MINT_TEST_STATE$failed))
if (MINT_TEST_STATE$failed > 0) {
  cat("\n失败项：\n")
  for (f in MINT_TEST_STATE$failures) cat(sprintf("  - %s\n", f))
}
quit(save = "no", status = if (MINT_TEST_STATE$failed > 0) 1L else 0L)
