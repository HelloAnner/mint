# 调色板。
#
# 默认 palette 走期刊配色（Nature / Lancet / JAMA / AAAS / NEJM 系列，
# 取自 ggsci 的公开色值，这里直接内联，既不依赖 ggsci 也能让 `mint palettes` 秒开），
# 另有色盲安全的 Okabe-Ito 与顺序/发散色阶供热力图类图表使用。

MINT_PALETTES <- list(
  npg = list(
    id = "npg", name = "Nature", kind = "categorical", source = "ggsci::pal_npg",
    description = "Nature 系期刊常用配色，克制、印刷友好，适合多系列对比",
    colors = c("#E64B35", "#4DBBD5", "#00A087", "#3C5488", "#F39B7F", "#8491B4", "#91D1C2", "#DC0000")
  ),
  aaas = list(
    id = "aaas", name = "Science", kind = "categorical", source = "ggsci::pal_aaas",
    description = "Science 系配色，饱和度高，投影与幻灯片上依然清晰",
    colors = c("#3B4992", "#EE0000", "#008B45", "#631879", "#008280", "#BB0021", "#5F559B", "#A20056", "#808180", "#1B1919")
  ),
  nejm = list(
    id = "nejm", name = "NEJM", kind = "categorical", source = "ggsci::pal_nejm",
    description = "新英格兰医学杂志配色，医学/临床报告常用",
    colors = c("#BC3C29", "#0072B5", "#E18727", "#20854E", "#7876B1", "#6F99AD", "#FFDC91", "#EE4C97")
  ),
  lancet = list(
    id = "lancet", name = "Lancet", kind = "categorical", source = "ggsci::pal_lancet",
    description = "柳叶刀配色，深色为主，适合黑白打印后仍可区分的场景",
    colors = c("#00468B", "#ED0000", "#42B540", "#0099B4", "#925E9F", "#FDAF91", "#AD002A", "#ADB6B6", "#1B1919")
  ),
  jama = list(
    id = "jama", name = "JAMA", kind = "categorical", source = "ggsci::pal_jama",
    description = "JAMA 配色，低饱和、稳重，适合正式报告",
    colors = c("#374E55", "#DF8F44", "#00A1D5", "#B24745", "#79AF97", "#6A6599", "#80796B")
  ),
  okabe = list(
    id = "okabe", name = "Okabe-Ito", kind = "categorical", source = "Okabe & Ito (2008)",
    description = "色盲安全配色，红绿色觉障碍下仍可区分，投稿首选",
    colors = c("#0072B2", "#E69F00", "#009E73", "#D55E00", "#CC79A7", "#56B4E9", "#000000", "#F0E442")
  ),
  greys = list(
    id = "greys", name = "灰阶", kind = "categorical",
    description = "同色系灰阶，适合黑白印刷或极简报告",
    colors = c("#1A1A1A", "#4D4D4D", "#767676", "#9E9E9E", "#BFBFBF", "#D9D9D9", "#8C8C8C", "#333333")
  ),
  blue = list(
    id = "blue", name = "蓝（顺序）", kind = "sequential",
    description = "单色蓝色阶，用于热力图、日历图等连续映射",
    colors = c("#F7FBFF", "#DEEBF7", "#C6DBEF", "#9ECAE1", "#6BAED6", "#4292C6", "#2171B5", "#08519C", "#08306B")
  ),
  viridis = list(
    id = "viridis", name = "viridis（顺序）", kind = "sequential",
    description = "感知均匀的顺序色阶，投影与色盲场景下都稳",
    colors = c("#440154", "#472D7B", "#3B528B", "#2C728E", "#21918C", "#28AE80", "#5EC962", "#ADD51D", "#FDE725")
  ),
  rdbu = list(
    id = "rdbu", name = "红蓝（发散）", kind = "diverging",
    description = "以中点为白/浅色的发散色阶，适合有正负或基准线的数据",
    colors = c("#67001F", "#B2182B", "#D6604D", "#F4A582", "#FDDBC7", "#F7F7F7", "#D1E5F0", "#92C5DE", "#4393C3", "#2166AC", "#053061")
  )
)

MINT_DEFAULT_PALETTE <- "npg"

mint_palettes <- function() MINT_PALETTES

mint_get_palette <- function(id = NULL) {
  id <- id %||% MINT_DEFAULT_PALETTE
  pal <- MINT_PALETTES[[id]]
  if (is.null(pal)) {
    ids <- paste(names(MINT_PALETTES), collapse = ", ")
    mint_fail("UNKNOWN_PALETTE", sprintf("没有名为「%s」的调色板", id),
              sprintf("可用调色板：%s（用 mint palettes 查看）", ids))
  }
  pal
}

#' 顺序色阶取色
mint_get_ramp <- function(id = NULL, reverse = FALSE) {
  pal <- mint_get_palette(id)
  cols <- pal$colors
  if (identical(pal$kind, "categorical")) cols <- rep(cols, length.out = 8)
  if (reverse) rev(cols) else cols
}
