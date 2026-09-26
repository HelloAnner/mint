# skill 管理。
#
# skill 的内容就在仓库的 skills/mint 下，安装 = 建一条软链，
# 因此改 SKILL.md 立即生效，不需要重新打包。

MINT_SKILL_NAME <- "mint"

mint_skills_root <- function() {
  Sys.getenv("MINT_SKILLS_DIR", unset = file.path(Sys.getenv("HOME"), ".agents", "skills"))
}

mint_skill_link <- function() file.path(mint_skills_root(), MINT_SKILL_NAME)

mint_skill_source <- function(home = mint_home_dir) file.path(home, "skills", MINT_SKILL_NAME)

mint_skill_files <- function(home = mint_home_dir) {
  dir <- mint_skill_source(home)
  if (!dir.exists(dir)) return(character(0))
  sort(list.files(dir, recursive = TRUE, all.files = FALSE, full.names = FALSE))
}

mint_skill_status <- function(home = mint_home_dir) {
  link <- mint_skill_link()
  source <- mint_skill_source(home)

  if (isTRUE(file.exists(link) || nzchar(Sys.readlink(link)))) {
    target <- Sys.readlink(link)
    is_link <- nzchar(target)
    resolved <- if (is_link) {
      if (startsWith(target, "/")) target else file.path(dirname(link), target)
    } else {
      link
    }
    resolved <- normalizePath(resolved, mustWork = FALSE)
    same <- identical(normalizePath(resolved, mustWork = FALSE), normalizePath(source, mustWork = FALSE))
    if (is_link && same) {
      return(list(mode = "linked", path = link, detail = sprintf("→ %s", resolved), files = mint_skill_files(home)))
    }
    if (is_link) {
      return(list(mode = "other-link", path = link, detail = sprintf("指向别处：%s", resolved), files = mint_skill_files(home)))
    }
    return(list(mode = "existing", path = link, detail = "已存在且不是 mint 建的软链（加 --force 覆盖）", files = mint_skill_files(home)))
  }

  list(mode = "missing", path = link, detail = sprintf("未安装，可运行 mint install skill"), files = mint_skill_files(home))
}

mint_cmd_skill <- function(argv, home = mint_home_dir) {
  parsed <- mint_parse_args(argv, list(mint_flag("json", NULL, "boolean", "输出 JSON")))
  action <- parsed$positionals[[1]] %||% "status"
  status <- mint_skill_status(home)

  if (identical(action, "path")) {
    cat(sprintf("%s\n", status$path))
    return(0L)
  }
  if (identical(action, "list")) {
    for (file in status$files) cat(sprintf("%s\n", file))
    return(0L)
  }
  if (identical(action, "show")) {
    file <- parsed$positionals[[2]] %||% "SKILL.md"
    path <- file.path(mint_skill_source(home), file)
    if (!file.exists(path)) {
      mint_fail("DATA_NOT_FOUND", sprintf("skill 里没有文件：%s", file),
                sprintf("可用文件：%s", paste(status$files, collapse = ", ")))
    }
    cat(paste(readLines(path, warn = FALSE), collapse = "\n"), "\n", sep = "")
    return(0L)
  }

  if (isTRUE(mint_arg(parsed, "json"))) {
    cat(as.character(mint_to_json(list(mode = status$mode, path = status$path,
                                       detail = status$detail, files = as.list(status$files)),
                                  pretty = TRUE)), "\n", sep = "")
    return(0L)
  }

  cat(sprintf("skill: %s\n", status$path))
  cat(sprintf("状态:  %s\n", switch(status$mode,
    linked = "已安装（软链到仓库）",
    `other-link` = "已安装（指向其它位置）",
    existing = "目标已存在，但不是 mint 管理的软链",
    missing = "未安装")))
  cat(sprintf("说明:  %s\n", status$detail))
  cat(sprintf("内容:  %d 个文件\n", length(status$files)))
  0L
}

mint_cmd_install <- function(argv, home = mint_home_dir) {
  parsed <- mint_parse_args(argv, list(mint_flag("force", NULL, "boolean", "覆盖已有安装")))
  what <- parsed$positionals[[1]]
  if (is.null(what) || !identical(what, "skill")) {
    mint_fail("MISSING_ARGUMENT", "目前只支持 mint install skill")
  }

  source <- mint_skill_source(home)
  if (!dir.exists(source)) {
    mint_fail("INTERNAL", sprintf("仓库里找不到 skill 目录：%s", source))
  }
  link <- mint_skill_link()
  root <- dirname(link)
  if (!dir.exists(root)) dir.create(root, recursive = TRUE, showWarnings = FALSE)

  status <- mint_skill_status(home)
  if (identical(status$mode, "linked")) {
    cat(sprintf("skill 已安装：%s → %s\n", link, normalizePath(source)))
    return(0L)
  }
  if (file.exists(link) || nzchar(Sys.readlink(link))) {
    if (!isTRUE(mint_arg(parsed, "force"))) {
      mint_fail("SKILL_EXISTS", sprintf("目标已存在：%s", link),
                "确认可以覆盖后加 --force")
    }
    unlink(link, recursive = TRUE, force = TRUE)
  }

  ok <- file.symlink(normalizePath(source), link)
  if (!isTRUE(ok)) {
    mint_fail("INTERNAL", sprintf("创建软链失败：%s → %s", link, source))
  }
  cat(sprintf("已安装 skill：%s → %s\n", link, normalizePath(source)))
  0L
}

mint_cmd_uninstall <- function(argv, home = mint_home_dir) {
  parsed <- mint_parse_args(argv, character(0))
  what <- parsed$positionals[[1]]
  if (is.null(what) || !identical(what, "skill")) {
    mint_fail("MISSING_ARGUMENT", "目前只支持 mint uninstall skill")
  }
  link <- mint_skill_link()
  if (!file.exists(link) && !nzchar(Sys.readlink(link))) {
    cat(sprintf("skill 未安装：%s\n", link))
    return(0L)
  }
  if (!nzchar(Sys.readlink(link))) {
    mint_fail("SKILL_NOT_MANAGED", sprintf("%s 不是 mint 建的软链，未删除", link))
  }
  unlink(link)
  cat(sprintf("已移除 skill 软链：%s\n", link))
  0L
}
