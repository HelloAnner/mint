#!/usr/bin/env Rscript
# mint 的 R 入口。bin/mint 会带着 MINT_HOME 调到这里。
#
#   Rscript --vanilla R/main.R <command> [args...]

args_all <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args_all, value = TRUE)
entry <- if (length(file_arg) > 0) normalizePath(sub("^--file=", "", file_arg[1]), mustWork = FALSE) else NULL
home <- if (!is.null(entry)) normalizePath(file.path(dirname(entry), ".."), mustWork = FALSE) else getwd()

source(file.path(home, "R", "load.R"), encoding = "UTF-8")
mint_load_sources(home)
status <- mint_main(commandArgs(trailingOnly = TRUE), home)
quit(save = "no", status = if (is.numeric(status)) as.integer(status) else 0L)
