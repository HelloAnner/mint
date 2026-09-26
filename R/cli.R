# 命令行分发。

MINT_VERSION <- "0.2.0"

mint_dispatch <- function(argv, home = mint_home_dir) {
  command <- if (length(argv) == 0) "help" else argv[[1]]
  rest <- if (length(argv) > 1) argv[-1] else character(0)

  # 全局开关
  if (command %in% c("--version", "-v", "version")) return(mint_cmd_version())
  if (command %in% c("--help", "-h", "help")) return(mint_cmd_help(rest))

  switch(command,
    render = mint_cmd_render(rest, home),
    batch = mint_cmd_batch(rest, home),
    list = mint_cmd_list(rest),
    info = mint_cmd_info(rest),
    palettes = mint_cmd_palettes(rest),
    styles = mint_cmd_styles(rest),
    doctor = mint_cmd_doctor(rest, home),
    skill = mint_cmd_skill(rest, home),
    install = mint_cmd_install(rest, home),
    uninstall = mint_cmd_uninstall(rest, home),
    {
      suggest <- mint_suggest_command(command)
      hint <- if (length(suggest) > 0) sprintf("你是不是想用：%s", paste(suggest, collapse = " / ")) else "用 mint help 查看全部命令"
      mint_fail("UNKNOWN_COMMAND", sprintf("没有名为「%s」的命令", command), hint)
    }
  )
}

mint_suggest_command <- function(command) {
  known <- c("render", "batch", "list", "info", "palettes", "styles", "doctor", "skill",
             "install", "uninstall", "version", "help")
  target <- tolower(command)
  known[vapply(known, function(k) grepl(target, k, fixed = TRUE) || grepl(k, target, fixed = TRUE), logical(1))]
}

#' 进程入口
mint_main <- function(argv = commandArgs(trailingOnly = TRUE), home = mint_home_dir) {
  # 依赖装在私有库里，直接跑 Rscript 时也要能找到
  lib <- Sys.getenv("MINT_LIB", unset = file.path(Sys.getenv("HOME"), ".local", "share", "mint", "rlib"))
  if (dir.exists(lib)) .libPaths(c(lib, .libPaths()))

  tryCatch(
    {
      status <- mint_dispatch(argv, home)
      if (is.numeric(status)) status else 0L
    },
    mint_error = function(e) {
      cat(mint_format_error(e), "\n", sep = "", file = stderr())
      1L
    },
    error = function(e) {
      cat(mint_format_error(e), "\n", sep = "", file = stderr())
      if (nzchar(Sys.getenv("MINT_DEBUG"))) {
        cat(paste(utils::head(capture.output(traceback()), 12), collapse = "\n"), "\n", file = stderr())
      } else {
        cat("      （设 MINT_DEBUG=1 查看堆栈）\n", file = stderr())
      }
      1L
    }
  )
}
