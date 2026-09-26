# 入口：定位仓库根目录、加载所有 R 源文件、执行命令。
#
# 用法（由 bin/mint 调用）：
#   Rscript --vanilla <repo>/R/main.R <command> [args...]

mint_entry_file <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  hit <- grep("^--file=", args, value = TRUE)
  if (length(hit) == 0) return(NULL)
  normalizePath(sub("^--file=", "", hit[1]), mustWork = FALSE)
}

mint_home_dir <- local({
  env_home <- Sys.getenv("MINT_HOME", unset = "")
  if (nzchar(env_home)) return(normalizePath(env_home, mustWork = FALSE))
  entry <- mint_entry_file()
  if (is.null(entry)) return(normalizePath(".", mustWork = FALSE))
  normalizePath(file.path(dirname(entry), ".."), mustWork = FALSE)
})

#' 加载仓库里的全部源文件（按依赖顺序）
mint_load_sources <- function(home = mint_home_dir) {
  files <- c(
    "errors.R", "util.R", "json.R", "data.R",
    "palettes.R", "style.R", "font.R", "frame.R", "output.R",
    "registry.R", "spec.R", "args.R", "render.R",
    "commands/help.R", "commands/render.R", "commands/batch.R",
    "commands/list.R", "commands/palettes.R",
    "commands/doctor.R", "commands/skill.R"
  )
  for (file in files) {
    path <- file.path(home, "R", file)
    if (!file.exists(path)) mint_fail("INTERNAL", sprintf("缺少源文件：%s", path))
    source(path, local = FALSE, encoding = "UTF-8")
  }
  source(file.path(home, "R", "charts", "_index.R"), local = FALSE, encoding = "UTF-8")
  mint_source_charts(home)
  source(file.path(home, "R", "cli.R"), local = FALSE, encoding = "UTF-8")
  invisible(home)
}
