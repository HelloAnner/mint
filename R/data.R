# 数据整形：把 JSON 归一化成图表需要的形状。
#
# 兼容多种常见写法（和老版 mint 保持一致），并对错误给出可操作提示。

#' 数组 -> data.frame（一行一条记录）
mint_as_rows <- function(data, chart) {
  if (!is.list(data) || is.null(names(data)) && length(data) == 0) {
    mint_fail("INVALID_DATA", sprintf("%s 需要数组数据，收到 %s", chart, mint_type_name(data)),
              "参见 mint info <chart> 里的「数据结构」一节")
  }
  if (!is.null(names(data))) {
    mint_fail("INVALID_DATA", sprintf("%s 需要数组数据，收到对象", chart),
              "参见 mint info <chart> 里的「数据结构」一节")
  }
  if (length(data) == 0) {
    mint_fail("INVALID_DATA", sprintf("%s 的数据为空", chart), "至少提供一条记录")
  }
  bad <- which(!vapply(data, function(x) is.list(x) && !is.null(names(x)), logical(1)))
  if (length(bad) > 0) {
    mint_fail("INVALID_DATA", sprintf("%s 第 %d 行不是对象", chart, bad[1]),
              "每一行都必须是形如 {\"季度\": \"Q1\", \"营收\": 128} 的对象")
  }
  keys <- unique(unlist(lapply(data, names)))
  cols <- lapply(keys, function(k) {
    values <- lapply(data, function(row) row[[k]])
    present <- !vapply(values, is.null, logical(1))
    # 某行缺这个键时按列类型补 NA：不能简单用 NA，否则 vapply 会因为
    # 「character 列里混进 logical」直接抛 INTERNAL。
    proto <- if (any(present)) values[present][[1]] else NULL
    if (is.numeric(proto) && !is.list(proto)) {
      out <- rep(NA_real_, length(data))
      for (i in which(present)) {
        v <- values[[i]]
        if (is.numeric(v) && length(v) == 1) out[i] <- as.numeric(v)
      }
      return(out)
    }
    if (is.logical(proto)) {
      out <- rep(NA, length(data))
      for (i in which(present)) {
        v <- values[[i]]
        if (is.logical(v) && length(v) == 1) out[i] <- v
      }
      return(out)
    }
    out <- rep(NA_character_, length(data))
    for (i in which(present)) {
      v <- values[[i]]
      if (!is.list(v) && length(v) >= 1) out[i] <- as.character(v)[1]
    }
    out
  })
  names(cols) <- keys
  as.data.frame(cols, stringsAsFactors = FALSE, check.names = FALSE)
}

#' 推断列类型（用于 vapply 的 FUN.VALUE）
vector_of <- function(data, key) {
  for (row in data) {
    v <- row[[key]]
    if (is.null(v) || is.list(v)) next
    if (is.numeric(v)) return(numeric(1))
    if (is.logical(v)) return(logical(1))
    return(character(1))
  }
  character(1)
}

mint_type_name <- function(value) {
  if (is.null(value)) return("null")
  if (is.list(value)) return(if (is.null(names(value))) "数组" else "对象")
  if (is.numeric(value)) return("数值")
  if (is.character(value)) return("字符串")
  if (is.logical(value)) return("布尔")
  typeof(value)
}

#' 推断「分类轴 + 数值系列」
mint_infer_index_keys <- function(rows, index_by = NULL, keys = NULL, chart = "chart") {
  fields <- names(rows)
  if (is.null(index_by)) {
    chr <- fields[vapply(rows[fields], function(col) is.character(col) || is.factor(col), logical(1))]
    index_by <- chr[1] %||% fields[1]
  }
  if (is.null(index_by) || !index_by %in% fields) {
    mint_fail("INVALID_DATA", sprintf("%s 里没有字段「%s」", chart, index_by),
              sprintf("可用字段：%s", paste(fields, collapse = ", ")))
  }
  if (is.null(keys) || length(keys) == 0) {
    num <- fields[vapply(rows[fields], is.numeric, logical(1))]
    keys <- setdiff(num, index_by)
    if (length(keys) == 0) {
      mint_fail("INVALID_DATA", sprintf("无法推断数值系列：%s 之外没有数值字段", index_by),
                sprintf("可用一条形如 {\"%s\": \"Q1\", \"系列A\": 100} 的记录", index_by))
    }
  }
  absent <- setdiff(keys, fields)
  if (length(absent) > 0) {
    mint_fail("INVALID_DATA", sprintf("%s 里没有字段 %s", chart, paste(absent, collapse = ", ")),
              sprintf("可用字段：%s", paste(fields, collapse = ", ")))
  }
  list(indexBy = index_by, keys = keys)
}

#' 归一化「占比 / 流程 / 分布」类数据 -> data.frame(id, label, value)
mint_as_pairs <- function(data, chart) {
  make <- function(id, label, value) data.frame(id = id, label = label, value = value, stringsAsFactors = FALSE)

  if (is.list(data) && !is.null(names(data))) {
    if (!is.null(data$id) || !is.null(data$label) || !is.null(data$name)) {
      return(mint_as_pairs(list(data), chart))
    }
    vals <- vapply(data, function(v) is.numeric(v) && length(v) == 1, logical(1))
    if (!any(vals)) {
      mint_fail("INVALID_DATA", sprintf("%s 的对象数据里没有数值字段", chart),
                "形如 {\"搜索\": 348, \"社交\": 266}")
    }
    nms <- names(data)[vals]
    return(make(nms, nms, unlist(data[vals], use.names = FALSE)))
  }

  if (!is.list(data)) {
    mint_fail("INVALID_DATA", sprintf("%s 需要数组或对象数据，收到 %s", chart, mint_type_name(data)))
  }
  if (length(data) == 0) mint_fail("INVALID_DATA", sprintf("%s 的数据为空", chart))

  ids <- character(0); labels <- character(0); values <- numeric(0)
  for (i in seq_along(data)) {
    item <- data[[i]]
    if (is.list(item) && is.null(names(item))) {
      # ["名称", 12] 形式
      if (length(item) < 2 || !is.numeric(item[[2]])) {
        mint_fail("INVALID_DATA", sprintf("%s 的第 %d 项不是 [名称, 数值] 形式", chart, i))
      }
      ids <- c(ids, as.character(item[[1]])); labels <- c(labels, as.character(item[[1]]))
      values <- c(values, as.numeric(item[[2]]))
      next
    }
    if (is.list(item)) {
      raw_id <- item$id %||% item$name %||% item$key %||% item$label
      raw_value <- item$value %||% item$y %||% item$count %||% item$total
      if (is.null(raw_id) || !is.numeric(raw_value) || length(raw_value) != 1) {
        mint_fail("INVALID_DATA", sprintf("%s 的第 %d 项缺少 id/name 或数值型 value", chart, i),
                  "形如 {\"id\": \"搜索\", \"value\": 348}")
      }
      ids <- c(ids, as.character(raw_id))
      labels <- c(labels, as.character(item$label %||% raw_id))
      values <- c(values, as.numeric(raw_value))
      next
    }
    mint_fail("INVALID_DATA", sprintf("%s 的第 %d 项既不是对象也不是二元数组", chart, i))
  }
  make(ids, labels, values)
}

#' 归一化「多系列折线」类数据
#'
#' 支持：
#'   [{ "id": "A", "data": [{ "x": "1月", "y": 12 }] }]
#'   [{ "x": "1月", "A": 12, "B": 30 }]   （行式，自动转系列）
mint_as_series <- function(data, chart, index_by = NULL, keys = NULL) {
  if (is.list(data) && !is.null(names(data)) && !is.null(data$id) && !is.null(data$data)) {
    data <- list(data)
  }
  if (is.list(data) && length(data) > 0 &&
      all(vapply(data, function(d) is.list(d) && !is.null(d$id) && !is.null(d$data) && is.null(names(d$data)), logical(1)))) {
    return(lapply(data, function(d) {
      pts <- d$data
      x <- vapply(pts, function(p) as.character(p$x %||% p$label %||% NA), character(1))
      y <- vapply(pts, function(p) {
        v <- p$y %||% p$value
        if (!is.numeric(v)) NA_real_ else as.numeric(v)
      }, numeric(1))
      if (all(is.na(y))) {
        mint_fail("INVALID_DATA", sprintf("%s 的系列「%s」没有数值点", chart, d$id),
                  "每个点形如 {\"x\": \"1月\", \"y\": 12}")
      }
      list(id = as.character(d$id), x = x, y = y)
    }))
  }

  rows <- mint_as_rows(data, chart)
  ik <- mint_infer_index_keys(rows, index_by, keys, chart)
  lapply(ik$keys, function(k) {
    list(id = k, x = as.character(rows[[ik$indexBy]]), y = as.numeric(rows[[k]]))
  })
}

#' 组装长表（分类 + 系列 + 数值），柱状/面积/雷达等都吃这个形状
mint_melt <- function(rows, index_by, keys) {
  parts <- lapply(keys, function(k) {
    data.frame(
      index = as.character(rows[[index_by]]),
      series = k,
      value = as.numeric(rows[[k]]),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, parts)
  # 保持输入里 category / series 的原始顺序
  out$index <- factor(out$index, levels = unique(out$index))
  out$series <- factor(out$series, levels = keys)
  out
}

#' 颜色循环：系列数超过调色板长度时自动循环
mint_colors <- function(n, palette) {
  if (n <= 0) return(character(0))
  rep(palette, length.out = n)
}

#' 从一个对象里取数值，缺失报错
mint_require_number <- function(value, where, field) {
  if (is.null(value)) mint_fail("INVALID_DATA", sprintf("%s 缺少 %s", where, field))
  if (!is.numeric(value) || length(value) != 1) {
    mint_fail("INVALID_DATA", sprintf("%s 的 %s 必须是数值", where, field))
  }
  as.numeric(value)
}

mint_require_string <- function(value, where, field) {
  if (is.null(value)) mint_fail("INVALID_DATA", sprintf("%s 缺少 %s", where, field))
  as.character(value)[1]
}

#' 取一个数值列，非数值时给出明确报错
mint_numeric_column <- function(rows, column, chart, what = "字段") {
  if (is.null(column) || !column %in% names(rows)) {
    mint_fail("INVALID_DATA", sprintf("%s 里没有%s「%s」", chart, what, column %||% "?"),
              sprintf("可用字段：%s", paste(names(rows), collapse = ", ")))
  }
  values <- rows[[column]]
  if (!is.numeric(values)) {
    mint_fail("INVALID_DATA", sprintf("%s 的「%s」必须是数值", chart, column))
  }
  values
}

#' 可选数值列（缺失返回 NA 向量）
mint_optional_numeric_column <- function(rows, column) {
  if (is.null(column) || !column %in% names(rows)) return(rep(NA_real_, nrow(rows)))
  values <- suppressWarnings(as.numeric(rows[[column]]))
  values
}

#' 从一个对象里取字段，支持多个候选键名
mint_field <- function(item, keys, default = NULL) {
  for (key in keys) {
    if (!is.null(item[[key]])) return(item[[key]])
  }
  default
}

#' 简单线性回归的拟合线与置信带（不依赖 broom）
mint_lm_band <- function(data, x, y, level = 0.95) {
  fit <- stats::lm(data[[y]] ~ data[[x]])
  grid <- data.frame(x = seq(min(data[[x]]), max(data[[x]]), length.out = 80))
  pred <- stats::predict(fit, newdata = data.frame(x = grid$x), interval = "confidence", level = level)
  data.frame(x = grid$x, y = pred[, "fit"], lower = pred[, "lwr"], upper = pred[, "upr"])
}
