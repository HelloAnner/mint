#!/usr/bin/env bash
#
# mint 安装脚本
#
#   curl -fsSL https://raw.githubusercontent.com/HelloAnner/mint/main/install.sh | bash
#
# 做三件事：按平台下载预编译二进制 → 装到 $PREFIX/bin → 安装 skill 软链。
# 可用环境变量覆盖：
#   MINT_PREFIX   安装前缀，默认 ~/.local（二进制落在 $MINT_PREFIX/bin）
#   MINT_VERSION  latest 或具体 tag（如 v0.1.0），默认 latest
#   MINT_REPO     仓库，默认 HelloAnner/mint

set -euo pipefail

REPO="${MINT_REPO:-HelloAnner/mint}"
PREFIX="${MINT_PREFIX:-$HOME/.local}"
BIN_DIR="$PREFIX/bin"
VERSION="${MINT_VERSION:-latest}"

info() { printf '  %s\n' "$*"; }
fail() { printf '\n✗ %s\n' "$*" >&2; exit 1; }

command -v curl >/dev/null 2>&1 || fail "缺少 curl，请先安装"

# ── 判断平台 ──────────────────────────────────────────────
os="$(uname -s | tr '[:upper:]' '[:lower:]')"
case "$os" in
  darwin) os=darwin ;;
  linux)  os=linux ;;
  *) fail "暂不支持的系统：${os}（目前提供 macOS 与 Linux）" ;;
esac

case "$(uname -m)" in
  arm64|aarch64) arch=arm64 ;;
  x86_64|amd64)  arch=x64 ;;
  *) fail "暂不支持的架构：$(uname -m)" ;;
esac

asset="mint-${os}-${arch}"

if [ "$VERSION" = "latest" ]; then
  base="https://github.com/$REPO/releases/latest/download"
else
  base="https://github.com/$REPO/releases/download/$VERSION"
fi

printf '\nmint 安装程序\n'
info "平台    $os-$arch"
info "版本    $VERSION"
info "安装到  $BIN_DIR/mint"
printf '\n'

# 所有中间文件都在临时目录里，退出时（含异常）自动清理
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

info "下载 $base/$asset"
curl -fsSL "$base/$asset" -o "$tmp/mint" \
  || fail "下载失败：${base}/${asset}（该平台可能还没有发布产物）"
chmod +x "$tmp/mint"

# ── 校验和（取不到就跳过，不阻断安装）────────────────────
if curl -fsSL "$base/SHA256SUMS" -o "$tmp/SHA256SUMS" 2>/dev/null; then
  expected="$(awk -v a="$asset" '$2 == a { print $1 }' "$tmp/SHA256SUMS" | head -1)"
  if [ -n "$expected" ]; then
    if command -v sha256sum >/dev/null 2>&1; then
      actual="$(sha256sum "$tmp/mint" | awk '{ print $1 }')"
    else
      actual="$(shasum -a 256 "$tmp/mint" | awk '{ print $1 }')"
    fi
    [ "$expected" = "$actual" ] && info "校验和 ✓" || fail "SHA256 校验不通过，已中止"
  fi
fi

mkdir -p "$BIN_DIR"
mv "$tmp/mint" "$BIN_DIR/mint"
chmod +x "$BIN_DIR/mint"
info "已安装 CLI：$BIN_DIR/mint"

# ── 安装 skill（二进制内嵌了 skill 内容，这一步会释放并软链）──
"$BIN_DIR/mint" install skill --force || fail "安装 skill 失败"

printf '\n'
"$BIN_DIR/mint" doctor || true

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *)
    printf '\n提醒：%s 不在 PATH 中，把下面一行加到 shell 配置里：\n' "$BIN_DIR"
    printf '  export PATH="%s:$PATH"\n' "$BIN_DIR"
    ;;
esac

printf '\n完成。试试：mint render bar -o out.png\n\n'
