#!/bin/bash
set -e
set -o pipefail

LOGFILE="$HOME/.dotfiles-setup.log"

echo "セットアップを開始します..."
echo "ログ: $LOGFILE"

# DOTFILES_DIR: 環境変数 > スクリプト引数 > デフォルト
# 引数の先頭に --dry-run を指定できるようにする
DRY_RUN=0
if [ "$1" = "--dry-run" ]; then
  DRY_RUN=1
  shift
fi

# =========================================================
# 破壊的コマンドのラッパー関数
# =========================================================
# 副作用のあるコマンド（mkdir, ln, curl, echo への追記など）を管理
# DRY_RUN=1 の場合、コマンドを表示するだけで実行しない
execute_cmd() {
  if [ "$DRY_RUN" -eq 1 ]; then
    # 環境変数を展開してコマンドを表示
    echo "[DRY-RUN] $(eval echo "$*")"
    return 0
  else
    eval "$@"
  fi
}

# =========================================================
# 1. 必要なディレクトリの作成
# =========================================================
echo "必要なディレクトリを作成しています..."
execute_cmd "mkdir -p ~/.config/zsh"
execute_cmd "mkdir -p ~/.config/ghostty"
execute_cmd "mkdir -p \"${HOME}/Library/Application Support/Code/User\""
execute_cmd "mkdir -p ~/.config/mise"

if [ -n "$DOTFILES_DIR" ]; then
  DOTFILES_DIR="$DOTFILES_DIR"
elif [ -n "$1" ]; then
  DOTFILES_DIR="$1"
else
  DOTFILES_DIR="$HOME/dotfiles"
fi

# backup utility
BACKUP_DIR="$HOME/.dotfiles-backup"
backup_if_needed() {
  target="$1"
  if [ -e "$target" ] || [ -L "$target" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      # ドライラン時は警告を表示
      echo "[DRY-RUN] 警告: 既に存在します ($target)"
      ts_sample=$(date +%Y%m%d%H%M%S)
      echo "[DRY-RUN] バックアップ予定: $target -> $BACKUP_DIR/$(basename "$target").pre-dotfiles-$ts_sample"
    else
      mkdir -p "$BACKUP_DIR"
      ts=$(date +%Y%m%d%H%M%S)
      bn=$(basename "$target")
      execute_cmd "mv \"$target\" \"$BACKUP_DIR/${bn}.pre-dotfiles-${ts}\""
      echo "バックアップ: $target -> $BACKUP_DIR/${bn}.pre-dotfiles-${ts}"
    fi
  fi
}

# dry-run helper for commands
run_cmd() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY-RUN] $*"
    return 0
  else
    eval "$@"
  fi
}

# run command and append output to logfile; abort on failure
run_and_log() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY-RUN] $*"
    return 0
  fi
  echo "[RUN] $*" | tee -a "$LOGFILE"
  eval "$@" >>"$LOGFILE" 2>&1
  status=$?
  if [ $status -ne 0 ]; then
    echo "コマンドが失敗しました: $* (exit $status)" | tee -a "$LOGFILE" >&2
    return $status
  fi
  return 0
}

on_error() {
  rc=$?
  echo "エラー発生: exit $rc" >&2
  echo "最後の20行 ($LOGFILE):" >&2
  if [ -f "$LOGFILE" ]; then
    tail -n 20 "$LOGFILE" >&2
  fi
  exit $rc
}

trap 'on_error' ERR

# =========================================================
# 2. シンボリックリンクの作成
# =========================================================
echo "シンボリックリンクを作成しています..."
# ln -snf で既存のファイルがあっても上書きしてリンクします
backup_if_needed ~/.zshrc
execute_cmd "ln -snf \"$DOTFILES_DIR/.zshrc\" ~/.zshrc"

backup_if_needed ~/.config/zsh/.zshrc
execute_cmd "ln -snf \"$DOTFILES_DIR/.config/zsh/.zshrc\" ~/.config/zsh/.zshrc"

# hidden は機密情報用（gitignore済み）
backup_if_needed ~/.config/zsh/hidden
execute_cmd "ln -snf \"$DOTFILES_DIR/.config/zsh/hidden\" ~/.config/zsh/hidden"

backup_if_needed ~/.config/starship.toml
execute_cmd "ln -snf \"$DOTFILES_DIR/.config/starship/starship.toml\" ~/.config/starship.toml"

backup_if_needed ~/.config/ghostty/config
execute_cmd "ln -snf \"$DOTFILES_DIR/.config/ghostty/config\" ~/.config/ghostty/config"

backup_if_needed "${HOME}/Library/Application Support/Code/User/settings.json"
execute_cmd "ln -snf \"$DOTFILES_DIR/vscode/settings.json\" \"${HOME}/Library/Application Support/Code/User/settings.json\""

backup_if_needed "${HOME}/Library/Application Support/Code/User/keybindings.json"
execute_cmd "ln -snf \"$DOTFILES_DIR/vscode/keybindings.json\" \"${HOME}/Library/Application Support/Code/User/keybindings.json\""

backup_if_needed ~/.config/mise/config.toml
execute_cmd "ln -snf \"$DOTFILES_DIR/.config/mise/config.toml\" ~/.config/mise/config.toml"
# mise trust は mise が利用可能になってから実行する（brew bundle 後）

backup_if_needed ~/.config/nvim
execute_cmd "ln -snf \"$DOTFILES_DIR/.config/nvim\" ~/.config/nvim"

# =========================================================
# 3. Homebrew のインストールとパス設定
# =========================================================
echo "Homebrew の状態を確認しています..."
# Homebrew プレフィクスをアーキテクチャに応じて決定
ARCH=$(uname -m || true)
if [ "$ARCH" = "arm64" ]; then
  BREW_PREFIX="/opt/homebrew"
else
  BREW_PREFIX="/usr/local"
fi

if ! command -v brew &> /dev/null; then
    echo "Homebrew が見つからないため、インストールします..."
    execute_cmd "/bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    
    # インストール後、適切な shellenv を ~/.zprofile に追記（重複チェックあり）
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "[DRY-RUN] ~/.zprofile への Homebrew shellenv の追記チェック"
      echo "[DRY-RUN] eval \"\$($BREW_PREFIX/bin/brew shellenv)\" を追記予定"
    else
      if ! grep -q "eval \"$($BREW_PREFIX/bin/brew shellenv)\"" ~/.zprofile 2>/dev/null; then
        execute_cmd "echo 'eval \"\$($BREW_PREFIX/bin/brew shellenv)\"' >> ~/.zprofile"
      fi
    fi
    
    # shellenv を eval（ドライラン時はスキップ）
    if [ "$DRY_RUN" -eq 0 ]; then
      eval "$($BREW_PREFIX/bin/brew shellenv)"
    fi
else
    echo "Homebrew は既にインストールされています。スキップします。"
fi

# =========================================================
# 4. Brewfile からアプリとツールのインストール
# =========================================================
echo "Brewfile からアプリをインストールしています..."
cd "$DOTFILES_DIR"
if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY-RUN] cd $DOTFILES_DIR"
  echo "[DRY-RUN] brew bundle (will not run)"
else
  if [ "$CI" = "true" ]; then
    # CI環境では、GUIアプリ（cask）、Macアプリ（mas）、VS Code拡張機能（vscode）を除外してパイプで渡す
    run_and_log "cat Brewfile | grep -E -v '^(cask|mas|vscode)' | brew bundle --file=-" || { echo "brew bundle に失敗しました" >&2; exit 1; }
  else
    # ローカルのMacでは通常通りすべてインストール
    run_and_log "brew bundle" || { echo "brew bundle に失敗しました" >&2; exit 1; }
  fi
fi

# =========================================================
# 5. opam (OCaml / MetaOCaml) の自動セットアップ
# =========================================================
echo "opam の状態を確認しています..."

# brew bundle で opam がインストールされているか確認
# ドライラン時は opam が存在しない可能性があるため、チェックを適切に分岐
if [ "$DRY_RUN" -eq 0 ] && command -v opam &> /dev/null; then
    # ~/.opam フォルダがない場合のみ（初回のみ）実行する
    if [ ! -d "$HOME/.opam" ]; then
        echo "opam を初期化し、MetaOCaml (5.3.0+BER) を構築します..."
        run_and_log "opam init --disable-sandboxing --reinit -y" || { echo "opam init が失敗しました" >&2; exit 1; }
        run_and_log "opam switch create metaocaml 5.3.0+BER -y" || { echo "opam switch の作成に失敗しました" >&2; exit 1; }
    else
        echo "opam はすでにセットアップされています。"
    fi
elif [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY-RUN] opam の初期化（存在確認後）"
    echo "[DRY-RUN] opam init --disable-sandboxing --reinit -y"
    echo "[DRY-RUN] opam switch create metaocaml 5.3.0+BER -y"
fi

# mise は brew bundle 後に存在するはずなのでここで trust と install を行う
if [ "$DRY_RUN" -eq 0 ] && command -v mise &> /dev/null; then
  echo "mise が見つかりました。設定を信頼し、ツールをインストールします..."
  if [ -f "$DOTFILES_DIR/.config/mise/config.toml" ]; then
    if ! mise trust "$DOTFILES_DIR/.config/mise/config.toml"; then
      echo "mise trust に失敗しました" >&2
      exit 1
    fi
  else
    echo "mise 設定ファイルが見つかりません: $DOTFILES_DIR/.config/mise/config.toml" >&2
  fi

  if ! mise install; then
    echo "mise install に失敗しました" >&2
    exit 1
  fi
elif [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY-RUN] mise の信頼設定とツールインストール"
    echo "[DRY-RUN] mise trust $DOTFILES_DIR/.config/mise/config.toml"
    echo "[DRY-RUN] mise install"
else
  echo "mise が見つかりません。brew bundle で mise がインストールされているか確認してください。" >&2
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY-RUN] すべての処理がスキップされました。実行時は --dry-run を外してください。"
else
  echo "すべてのセットアップが完了しました！ターミナルを再起動してください。"
fi