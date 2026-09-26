# 字体解析。
#
# mint 必须开箱支持中文标签，所以这里做三件事：
#   1. 按风格给出的优先级列表，从系统里挑一个同时覆盖中英文的家族；
#   2. 把结果缓存到磁盘 —— systemfonts 扫描系统字体有 0.5~2s 的固定开销，
#      而 mint 是「一条命令出一张图」的模型，每次启动都扫一遍不可接受；
#   3. 支持显式指定家族名（MINT_FONT_FAMILY）或字体文件（MINT_FONT）。

mint_cache_dir <- function() {
  dir <- file.path(Sys.getenv("HOME"), ".cache", "mint")
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  dir
}

mint_font_cache_path <- function() file.path(mint_cache_dir(), "font-family")

#' 已注册的字体家族名列表
mint_installed_families <- function() {
  if (!requireNamespace("systemfonts", quietly = TRUE)) return(character(0))
  tryCatch(unique(systemfonts::system_fonts()$family), error = function(e) character(0))
}

mint_normalize_family <- function(x) gsub("[^a-z0-9]", "", tolower(x))

#' 解析当前应该使用的字体家族
mint_resolve_family <- function(style, explicit = NULL, refresh = FALSE) {
  # 1) 显式指定字体文件：注册成 mint 专用家族，保证 PNG/SVG 用的是同一个字体
  font_file <- explicit %||% Sys.getenv("MINT_FONT", unset = "")
  if (nzchar(font_file) && grepl("\\.(ttf|otf|ttc|otc)$", font_file, ignore.case = TRUE)) {
    if (!file.exists(font_file)) {
      mint_fail("FONT_NOT_FOUND", sprintf("找不到字体文件：%s", font_file))
    }
    if (requireNamespace("systemfonts", quietly = TRUE)) {
      try(systemfonts::register_font(
        name = "mint-font",
        plain = font_file, bold = font_file, italic = font_file, bolditalic = font_file
      ), silent = TRUE)
      return("mint-font")
    }
  }

  # 2) 显式指定家族名
  family_override <- if (nzchar(font_file)) font_file else Sys.getenv("MINT_FONT_FAMILY", unset = "")
  if (nzchar(family_override)) return(family_override)

  # 3) 缓存
  cache <- mint_font_cache_path()
  if (!refresh && file.exists(cache)) {
    cached <- trimws(readLines(cache, warn = FALSE)[1])
    if (!is.na(cached) && nzchar(cached)) return(cached)
  }

  # 4) 扫描系统字体并按优先级挑
  families <- mint_installed_families()
  chosen <- NULL
  if (length(families) > 0) {
    normalized <- mint_normalize_family(families)
    for (candidate in style$font_preferences) {
      hit <- which(normalized == mint_normalize_family(candidate))
      if (length(hit) > 0) {
        chosen <- families[hit[1]]
        break
      }
    }
  }
  if (is.null(chosen)) chosen <- "sans"

  writeLines(chosen, cache)
  chosen
}

#' 清掉字体缓存，让下次运行重新探测（doctor 用）
mint_reset_font_cache <- function() {
  cache <- mint_font_cache_path()
  if (file.exists(cache)) unlink(cache)
  invisible(NULL)
}

#' 探测系统里可用的字体（doctor 用）
mint_font_report <- function() {
  families <- mint_installed_families()
  cjk <- c("PingFang SC", "Hiragino Sans GB", "Noto Sans CJK SC", "Source Han Sans SC",
           "Noto Sans SC", "Songti SC", "Microsoft YaHei", "WenQuanYi Zen Hei")
  normalized <- mint_normalize_family(families)
  present <- cjk[vapply(cjk, function(f) any(normalized == mint_normalize_family(f)), logical(1))]
  list(total = length(families), cjk = present, resolved = mint_resolve_family(mint_get_style()))
}
