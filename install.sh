#!/bin/sh
# mint 一键安装：装 R 依赖 → 装 CLI shim → 装 skill 软链 → 自检
#
#   curl -fsSL https://raw.githubusercontent.com/HelloAnner/mint/main/install.sh | bash
#
# 可用环境变量：
#   MINT_PREFIX   安装前缀，默认 ~/.local（CLI 落到 $MINT_PREFIX/bin/mint）
#   MINT_VERSION  latest 或具体 tag，如 v0.2.0
#   MINT_REPO     覆盖仓库，默认 HelloAnner/mint
#   MINT_LIB      R 依赖库位置，默认 ~/.local/share/mint/rlib
#   MINT_CRAN     CRAN 镜像

set -e

MINT_PREFIX=${MINT_PREFIX:-$HOME/.local}
MINT_VERSION=${MINT_VERSION:-latest}
MINT_REPO=${MINT_REPO:-HelloAnner/mint}
MINT_LIB=${MINT_LIB:-$HOME/.local/share/mint/rlib}
MINT_SRC=${MINT_SRC:-$HOME/.local/share/mint}

say() { printf '%s\n' "$*"; }
die() { printf 'mint: %s\n' "$*" >&2; exit 1; }

# ── 1. 前置检查 ─────────────────────────────────────────────
command -v Rscript >/dev/null 2>&1 || die "找不到 Rscript。请先装 R：
    macOS:  brew install r
    其它:   https://cran.r-project.org/bin/"
say "R: $(Rscript --vanilla -e 'cat(R.version.string)' 2>/dev/null)"

# ── 2. 取源码 ──────────────────────────────────────────────
if [ -f "./R/main.R" ] && [ -d "./skills/mint" ]; then
  # 从仓库里直接跑
  MINT_HOME=$(cd "$(dirname "$0")" && pwd)
  say "使用当前目录作为 mint 安装目录：$MINT_HOME"
else
  if [ "$MINT_VERSION" = "latest" ]; then
    URL="https://github.com/$MINT_REPO/archive/refs/heads/main.tar.gz"
  else
    URL="https://github.com/$MINT_REPO/archive/refs/tags/$MINT_VERSION.tar.gz"
  fi
  TMP=$(mktemp -d)
  trap 'rm -rf "$TMP"' EXIT
  say "下载 $URL"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$URL" | tar xz -C "$TMP"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "$URL" | tar xz -C "$TMP"
  else
    die "需要 curl 或 wget"
  fi
  mkdir -p "$MINT_SRC"
  rm -rf "$MINT_SRC.old" && [ -d "$MINT_SRC" ] && mv "$MINT_SRC" "$MINT_SRC.old" || true
  mv "$TMP"/*/ "$MINT_SRC"
  rm -rf "$MINT_SRC.old"
  MINT_HOME="$MINT_SRC"
  say "已解压到 $MINT_HOME"
fi

# ── 3. 装 R 依赖 ───────────────────────────────────────────
say "安装 R 依赖到 $MINT_LIB（首次会编译几百个源包，慢是正常的）"
MINT_LIB="$MINT_LIB" MINT_CRAN="${MINT_CRAN:-}" Rscript "$MINT_HOME/scripts/install-deps.R"

# ── 4. 装 CLI ─────────────────────────────────────────────
mkdir -p "$MINT_PREFIX/bin"
chmod +x "$MINT_HOME/bin/mint"
ln -sfn "$MINT_HOME/bin/mint" "$MINT_PREFIX/bin/mint"
say "已安装 CLI：$MINT_PREFIX/bin/mint"

# ── 5. 装 skill ───────────────────────────────────────────
SKILLS_DIR=${MINT_SKILLS_DIR:-$HOME/.agents/skills}
mkdir -p "$SKILLS_DIR"
ln -sfn "$MINT_HOME/skills/mint" "$SKILLS_DIR/mint"
say "已安装 skill：$SKILLS_DIR/mint"

# ── 6. 自检 ───────────────────────────────────────────────
case ":$PATH:" in
  *":$MINT_PREFIX/bin:"*) ;;
  *) say ""; say "提示：把 $MINT_PREFIX/bin 加进 PATH："
     say "  echo 'export PATH=\"$MINT_PREFIX/bin:\$PATH\"' >> ~/.zshrc" ;;
esac
say ""
MINT_LIB="$MINT_LIB" "$MINT_PREFIX/bin/mint" doctor || true
say ""
say "完成。试一张：$MINT_PREFIX/bin/mint render bar -o /tmp/mint-check.png"
