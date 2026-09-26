#!/usr/bin/env Rscript
# mint 的 R 依赖安装脚本。
#
# 用法：
#   Rscript scripts/install-deps.R                 # 装到默认库
#   MINT_LIB=/path/to/lib Rscript scripts/install-deps.R
#   MINT_CRAN=https://cloud.r-project.org Rscript scripts/install-deps.R
#
# mint 不依赖任何私有包，全部来自 CRAN；装到一个独立库目录里，
# 不污染用户自己的 R 环境。

lib <- Sys.getenv("MINT_LIB", unset = file.path(Sys.getenv("HOME"), ".local", "share", "mint", "rlib"))
ncpus <- max(1L, as.integer(Sys.getenv("MINT_NCPUS", unset = "4")))

# 国内镜像优先（CRAN 官方源在部分网络下很慢），逐个回退。
cran_mirrors <- local({
  explicit <- Sys.getenv("MINT_CRAN", unset = "")
  if (nzchar(explicit)) return(explicit)
  c(
    "https://mirrors.ustc.edu.cn/CRAN/",
    "https://mirror.nju.edu.cn/CRAN/",
    "https://mirrors.aliyun.com/CRAN/",
    "https://cloud.r-project.org/"
  )
})

#' 探测一个 CRAN 镜像是否可用（能取到包索引）
cran_alive <- function(url) {
  old <- options(repos = c(CRAN = url), timeout = 25)
  on.exit(options(old), add = TRUE)
  ok <- tryCatch(nrow(available.packages()) > 100,
                 error = function(e) FALSE, warning = function(w) FALSE)
  isTRUE(ok)
}

dir.create(lib, recursive = TRUE, showWarnings = FALSE)

# ── 依赖清单 ─────────────────────────────────────────────
# 分成三档，任何一档装不上都会明确报出来，而不是静默降级。
pkgs_core <- c(
  "jsonlite",   # 读写 JSON
  "ggplot2",    # 绘图底座
  "scales",     # 刻度与格式化
  "systemfonts",# 字体解析（中文关键依赖）
  "ragg",       # PNG 设备（支持中文）
  "svglite",    # SVG 设备（输出可编辑矢量图）
  "gtable",     # grob 布局
  "gridtext",   # 富文本 grob（标题/脚注）
  "glue", "cli", "rlang", "withr", "labeling", "farver", "colorspace"
)

pkgs_layout <- c(
  "patchwork",  # 多面板拼装
  "gridExtra",
  "ggtext",     # 标题/标注里的 markdown 与富文本
  "dplyr", "tidyr", "tibble", "stringr", "purrr", "magrittr"
)

pkgs_charts <- c(
  "ggsci",      # 期刊配色（NPG / Lancet / JAMA / AAAS / NEJM）
  "ggrepel",    # 智能避让标签
  "ggfittext",  # 文字自适应填入图形
  "ggforce",    # 圆/椭圆等几何
  "treemapify", # 矩形树图
  "packcircles",# 圆堆积布局
  "ggalluvial", # 桑基/冲积图
  "ggridges",   # 山脊图
  "ggbeeswarm", # 蜂群散点
  "ggdist",     # 分布
  "ggpubr"      # 期刊风格统计图层与显著性标注
)

all_pkgs <- c(pkgs_core, pkgs_layout, pkgs_charts)

.libPaths(c(lib, .libPaths()))
all_pkgs <- c(pkgs_core, pkgs_layout, pkgs_charts)
installed <- rownames(installed.packages(lib.loc = lib))
missing <- setdiff(all_pkgs, installed)

cat(sprintf("库目录: %s\n", lib))

if (length(missing) == 0) {
  cat("所有依赖已就绪，无需安装。\n")
  quit(status = 0)
}

cat(sprintf("待安装 %d 个包: %s\n", length(missing), paste(missing, collapse = ", ")))

options(Ncpus = ncpus, warn = 1)

# macOS 自带 clang 不支持 R 4.6 默认的 -std=gnu23，用仓库里的 Makevars 降级编译。
# 注意必须是绝对路径：R CMD INSTALL 在包源码目录里跑，相对路径会失效。
script_file <- grep("^--file=", commandArgs(FALSE), value = TRUE)
makevars <- if (length(script_file) > 0) {
  file.path(dirname(normalizePath(sub("^--file=", "", script_file[1]))), "Makevars")
} else {
  ""
}
if (nzchar(makevars) && file.exists(makevars)) {
  Sys.setenv(R_MAKEVARS_USER = makevars)
  cat(sprintf("编译参数: %s\n", makevars))
}

for (mirror in cran_mirrors) {
  if (!cran_alive(mirror)) {
    cat(sprintf("镜像不可用，跳过: %s\n", mirror))
    next
  }
  cat(sprintf("使用镜像: %s\n", mirror))
  options(repos = c(CRAN = mirror))
  try(install.packages(missing, lib = lib, dependencies = c("Depends", "Imports", "LinkingTo")),
      silent = TRUE)
  missing <- setdiff(all_pkgs, rownames(installed.packages(lib.loc = lib)))
  if (length(missing) == 0) break
  cat(sprintf("该镜像下还缺 %d 个包，换下一个镜像重试\n", length(missing)))
}

still <- setdiff(all_pkgs, rownames(installed.packages(lib.loc = lib)))
if (length(still) > 0) {
  cat(sprintf("\n[FAILED] 以下包没能装上: %s\n", paste(still, collapse = ", ")))
  cat("重试: Rscript scripts/install-deps.R\n")
  quit(status = 1)
}

cat("\n[OK] 依赖安装完成\n")
