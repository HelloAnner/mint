# mint doctor —— 环境自检
#
# 目标是一眼看出「能不能出图」：R 版本、依赖包、中文字体、输出设备、skill 是否就位。

MINT_REQUIRED_PACKAGES <- c(
  "jsonlite", "ggplot2", "scales", "systemfonts", "ragg", "svglite",
  "gtable", "gridtext", "glue"
)

mint_cmd_doctor <- function(argv, home = mint_home_dir) {
  parsed <- mint_parse_args(argv, list(mint_flag("json", NULL, "boolean", "输出 JSON")))
  checks <- list()
  add <- function(name, ok, detail) {
    checks[[length(checks) + 1L]] <<- list(name = name, ok = isTRUE(ok), detail = detail)
  }

  # 1) R 版本
  r_version <- paste(R.version$major, R.version$minor, sep = ".")
  add("R 运行时", utils::compareVersion(r_version, "4.2.0") >= 0, sprintf("R %s", r_version))

  # 2) mint 私有库与依赖
  lib <- Sys.getenv("MINT_LIB", unset = file.path(Sys.getenv("HOME"), ".local", "share", "mint", "rlib"))
  installed <- if (dir.exists(lib)) rownames(installed.packages(lib.loc = lib)) else character(0)
  missing <- setdiff(MINT_REQUIRED_PACKAGES, installed)
  add("依赖库", length(missing) == 0,
      if (length(missing) == 0) sprintf("%s（%d 个核心包）", lib, length(MINT_REQUIRED_PACKAGES))
      else sprintf("缺少 %s，运行 Rscript scripts/install-deps.R", paste(missing, collapse = ", ")))

  # 2b) 图表专用包
  chart_pkgs <- unique(unlist(lapply(mint_all_charts(), function(c) c$packages)))
  chart_missing <- setdiff(chart_pkgs, installed)
  add("图表依赖", length(chart_missing) == 0,
      if (length(chart_missing) == 0) sprintf("%d 个包齐备", length(chart_pkgs))
      else sprintf("缺少 %s", paste(chart_missing, collapse = ", ")))

  # 3) 字体（中文能不能画出来）
  font <- tryCatch(mint_font_report(), error = function(e) list(total = 0, cjk = character(0), resolved = "?"))
  add("字体", length(font$cjk) > 0 || !identical(font$resolved, "sans"),
      sprintf("使用 %s；系统中文字体：%s", font$resolved,
              if (length(font$cjk) == 0) "未找到（中文会显示成方框）" else paste(font$cjk, collapse = ", ")))

  # 4) 输出设备
  add("PNG 输出", requireNamespace("ragg", quietly = TRUE), "ragg")
  add("SVG 输出", requireNamespace("svglite", quietly = TRUE), "svglite")

  # 5) 图表注册
  add("图表", length(mint_all_charts()) >= 20, sprintf("已注册 %d 张", length(mint_all_charts())))

  # 6) 风格与调色板
  add("风格", length(mint_styles()) > 0, paste(names(mint_styles()), collapse = ", "))
  add("调色板", length(mint_palettes()) > 0, paste(names(mint_palettes()), collapse = ", "))

  # 7) skill
  status <- mint_skill_status(home)
  add("skill", identical(status$mode, "linked") || identical(status$mode, "repo"),
      sprintf("%s（%s）", status$path, status$detail))

  ok_all <- all(vapply(checks, function(c) c$ok, logical(1)))

  if (isTRUE(mint_arg(parsed, "json"))) {
    cat(as.character(mint_to_json(list(ok = ok_all, checks = checks), pretty = TRUE)), "\n", sep = "")
    return(if (ok_all) 0L else 1L)
  }

  cat(sprintf("mint %s 环境自检（R %s）\n\n", MINT_VERSION, r_version))
  for (check in checks) {
    cat(sprintf("  %s %-10s %s\n", if (check$ok) "✓" else "✗", check$name, check$detail))
  }
  cat(sprintf("\n%s\n", if (ok_all) "一切就绪。" else "存在未通过的检查项，见上文。"))
  if (ok_all) 0L else 1L
}
