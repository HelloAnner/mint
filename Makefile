# mint —— 数据到图表的 CLI
#
# 常用目标：
#   make             = make help
#   make install     安装 CLI 到 PREFIX/bin，并把 skill 软链到 ~/.agents/skills/mint
#   make build       编译单文件二进制到 dist/mint
#   make dev         直接用源码运行 CLI

PREFIX ?= $(HOME)/.local
BIN_DIR := $(PREFIX)/bin
DIST    := dist/mint
SKILL_SRC := skills/mint
SKILL_DEST := $(HOME)/.agents/skills/mint

.PHONY: help install install-cli install-skill uninstall uninstall-skill build dev test typecheck embed examples check clean

help:
	@echo "mint —— 把数据变成美观的图表"
	@echo ""
	@echo "  make install        安装 CLI 到 $(BIN_DIR) 并安装 skill 软链"
	@echo "  make install-cli    只安装 CLI"
	@echo "  make install-skill  只安装 skill 软链到 $(SKILL_DEST)"
	@echo "  make uninstall      卸载 CLI 与 skill"
	@echo "  make build          编译单文件二进制到 $(DIST)"
	@echo "  make dev            用源码直接运行 CLI"
	@echo "  make test           运行测试"
	@echo "  make typecheck      TypeScript 类型检查"
	@echo "  make examples       把每张图的示例渲染到 out/examples"
	@echo "  make check          typecheck + test + build"
	@echo "  make clean          清理构建产物"
	@echo ""
	@echo "PREFIX 当前为 $(PREFIX)，可用 make install PREFIX=/usr/local 覆盖"

install: install-cli install-skill
	@echo ""
	@echo "✓ 安装完成。跑 mint doctor 自检，或 mint list 看看有哪些图。"
	@if echo ":$$PATH:" | grep -q ":$(BIN_DIR):"; then echo "  $(BIN_DIR) 已在 PATH 中"; else echo "  提醒：$(BIN_DIR) 不在 PATH 中，需要自行加入"; fi

install-cli:
	@echo "→ 编译 mint ..."
	@bun run scripts/build.ts
	@mkdir -p "$(BIN_DIR)"
	@cp "$(DIST)" "$(BIN_DIR)/mint"
	@chmod +x "$(BIN_DIR)/mint"
	@echo "→ CLI 已安装到 $(BIN_DIR)/mint"

install-skill: embed
	@echo "→ 安装 skill 到 $(SKILL_DEST)"
	@mkdir -p "$(HOME)/.agents/skills"
	@rm -rf "$(SKILL_DEST)"
	@ln -s "$(CURDIR)/$(SKILL_SRC)" "$(SKILL_DEST)"
	@echo "  $(SKILL_DEST) -> $(CURDIR)/$(SKILL_SRC)"
	@test -f "$(SKILL_DEST)/SKILL.md" && echo "  ✓ SKILL.md 可读"

uninstall: uninstall-skill
	@rm -f "$(BIN_DIR)/mint"
	@echo "→ 已移除 $(BIN_DIR)/mint"

uninstall-skill:
	@if [ -L "$(SKILL_DEST)" ]; then rm -f "$(SKILL_DEST)"; echo "→ 已移除 skill 软链"; else echo "→ 未发现 skill 软链，跳过"; fi

build: embed
	@bun run scripts/build.ts

dev:
	@bun run src/cli.ts

embed:
	@bun run scripts/embed.ts

test:
	@bun test

typecheck:
	@bunx tsc --noEmit

examples:
	@bun run scripts/examples.tsx

check: typecheck test build

clean:
	@rm -rf dist out
	@echo "→ 已清理 dist/ 与 out/"
