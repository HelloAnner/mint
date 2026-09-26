# mint —— 数据到期刊级图表的 CLI（R + ggplot2）
#
# 常用目标：
#   make             = make help
#   make deps        安装 R 依赖到 MINT_LIB（默认 ~/.local/share/mint/rlib）
#   make test        跑全部测试（含 27 张图的端到端渲染）
#   make examples    把每张图的示例渲染到 out/examples
#   make docs        从代码重新生成 skill 里的图表目录
#   make install     安装 CLI shim + skill 软链
#   make dev         直接用源码运行 CLI（需要已装依赖）

PREFIX ?= $(HOME)/.local
BIN_DIR := $(PREFIX)/bin
MINT_HOME := $(shell pwd)
MINT_LIB ?= $(HOME)/.local/share/mint/rlib
SKILL_DEST := $(HOME)/.agents/skills/mint
EXAMPLES := out/examples

export MINT_HOME
export MINT_LIB

.PHONY: help deps test check examples docs install install-cli install-skill uninstall clean doctor

help:
	@echo "mint —— 把数据变成期刊级图表"
	@echo ""
	@echo "  make deps          安装 R 依赖到 $(MINT_LIB)"
	@echo "  make test          跑全部测试"
	@echo "  make examples      渲染全部图表示例到 $(EXAMPLES)"
	@echo "  make docs          重新生成 skill 里的图表目录"
	@echo "  make doctor        环境自检"
	@echo "  make install       安装 CLI 到 $(BIN_DIR) 并装 skill 软链"
	@echo "  make uninstall     卸载 CLI 与 skill"
	@echo "  make clean         清理构建产物"
	@echo ""
	@echo "  make dev render bar -o bar.png   直接用源码跑 CLI"
	@echo ""
	@echo "PREFIX 当前为 $(PREFIX)，可用 make install PREFIX=/usr/local 覆盖"

deps:
	@command -v Rscript >/dev/null || { echo "请先安装 R（brew install r 或 https://cran.r-project.org）"; exit 1; }
	@Rscript scripts/install-deps.R

test: deps
	@Rscript tests/run-tests.R

doctor: deps
	@./bin/mint doctor

check: test

examples: deps
	@Rscript scripts/examples.R $(EXAMPLES)

docs:
	@Rscript scripts/gen-docs.R

dev: 
	@./bin/mint $(filter-out $@,$(MAKECMDGOALS))

install: install-cli install-skill
	@./bin/mint doctor || true

install-cli: deps
	@mkdir -p $(BIN_DIR)
	@ln -sfn $(MINT_HOME)/bin/mint $(BIN_DIR)/mint
	@echo "已安装 CLI：$(BIN_DIR)/mint → $(MINT_HOME)/bin/mint"
	@echo "确保 $(BIN_DIR) 在 PATH 里：export PATH=\"$(BIN_DIR):\$$PATH\""

install-skill:
	@mkdir -p $(dir $(SKILL_DEST))
	@ln -sfn $(MINT_HOME)/skills/mint $(SKILL_DEST)
	@echo "已安装 skill：$(SKILL_DEST) → $(MINT_HOME)/skills/mint"

uninstall:
	@rm -f $(BIN_DIR)/mint
	@[ -L $(SKILL_DEST) ] && rm -f $(SKILL_DEST) || true
	@echo "已卸载 CLI 与 skill（R 依赖库保留在 $(MINT_LIB)）"

clean:
	@rm -rf out dist
	@echo "已清理 out/ dist/"

%:
	@:
