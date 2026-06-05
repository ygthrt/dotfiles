#!/bin/bash
set -e
set -o pipefail

LOGFILE="$HOME/.dotfiles-setup.log"

echo "セットアップを開始します..."
echo "ログ: $LOGFILE"

# =========================================================
# 1. 必要なディレクトリの作成
# =========================================================
echo "必要なディレクトリを作成しています..."
mkdir -p ~/.config/zsh
mkdir -p ~/.config/ghostty
mkdir -p "${HOME}/Library/Application Support/Code/User"
mkdir -p ~/.config/mise

# DOTFILES_DIR: 環境変数 > スクリプト引数 > デフォルト
# 引数の先頭に --dry-run を指定できるようにする
DRY_RUN=0
if [ "$1" = "--dry-run" ]; then
  DRY_RUN=1
  shift
fi

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
    mkdir -p "$BACKUP_DIR"
    ts=$(date +%Y%m%d%H%M%S)
    bn=$(basename "$target")
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "[DRY-RUN] バックアップ予定: $target -> $BACKUP_DIR/${bn}.pre-dotfiles-${ts}"
    else
      mv "$target" "$BACKUP_DIR/${bn}.pre-dotfiles-${ts}"
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
ln -snf "$DOTFILES_DIR/.zshrc" ~/.zshrc

backup_if_needed ~/.config/zsh/.zshrc
ln -snf "$DOTFILES_DIR/.config/zsh/.zshrc" ~/.config/zsh/.zshrc

# hidden は機密情報用（gitignore済み）
backup_if_needed ~/.config/zsh/hidden
ln -snf "$DOTFILES_DIR/.config/zsh/hidden" ~/.config/zsh/hidden

backup_if_needed ~/.config/starship.toml
ln -snf "$DOTFILES_DIR/.config/starship.toml" ~/.config/starship.toml

backup_if_needed ~/.config/ghostty/config
ln -snf "$DOTFILES_DIR/.config/ghostty/config" ~/.config/ghostty/config

backup_if_needed "${HOME}/Library/Application Support/Code/User/settings.json"
ln -snf "$DOTFILES_DIR/vscode/settings.json" "${HOME}/Library/Application Support/Code/User/settings.json"

backup_if_needed "${HOME}/Library/Application Support/Code/User/keybindings.json"
ln -snf "$DOTFILES_DIR/vscode/keybindings.json" "${HOME}/Library/Application Support/Code/User/keybindings.json"

backup_if_needed ~/.config/mise/config.toml
ln -snf "$DOTFILES_DIR/.config/mise/config.toml" ~/.config/mise/config.toml
# mise trust は mise が利用可能になってから実行する（brew bundle 後）

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
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # インストール後、適切な shellenv を ~/.zprofile に追記（重複チェックあり）
    if ! grep -q "eval \"$($BREW_PREFIX/bin/brew shellenv)\"" ~/.zprofile 2>/dev/null; then
      echo "eval \"$($BREW_PREFIX/bin/brew shellenv)\"" >> ~/.zprofile
    fi
    eval "$($BREW_PREFIX/bin/brew shellenv)"
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
  run_and_log "brew bundle" || { echo "brew bundle に失敗しました。$LOGFILE を確認してください" >&2; exit 1; }
fi

# =========================================================
# 5. opam (OCaml / MetaOCaml) の自動セットアップ
# =========================================================
echo "opam の状態を確認しています..."

# brew bundle で opam がインストールされているか確認
if command -v opam &> /dev/null; then
    # ~/.opam フォルダがない場合のみ（初回のみ）実行する
    if [ ! -d "$HOME/.opam" ]; then
        echo "opam を初期化し、MetaOCaml (5.3.0+BER) を構築します..."
        
        # ユーザーへの質問をスキップ(-y)して自動初期化
        if [ "$DRY_RUN" -eq 1 ]; then
          echo "[DRY-RUN] opam init --disable-sandboxing --reinit -y"
        else
          run_and_log "opam init --disable-sandboxing --reinit -y" || { echo "opam init が失敗しました" >&2; exit 1; }
        fi
        
        # MetaOCamlの環境を自動作成(-y)
        if [ "$DRY_RUN" -eq 1 ]; then
          echo "[DRY-RUN] opam switch create metaocaml 5.3.0+BER -y"
        else
          run_and_log "opam switch create metaocaml 5.3.0+BER -y" || { echo "opam switch の作成に失敗しました" >&2; exit 1; }
        fi
    else
        echo "opam はすでにセットアップされています。"
    fi
fi

# mise は brew bundle 後に存在するはずなのでここで trust と install を行う
if command -v mise &> /dev/null; then
  echo "mise が見つかりました。設定を信頼し、ツールをインストールします..."
  if [ -f "$DOTFILES_DIR/.config/mise/config.toml" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "[DRY-RUN] mise trust $DOTFILES_DIR/.config/mise/config.toml"
    else
      if ! mise trust "$DOTFILES_DIR/.config/mise/config.toml"; then
        echo "mise trust に失敗しました" >&2
        exit 1
      fi
    fi
  else
    echo "mise 設定ファイルが見つかりません: $DOTFILES_DIR/.config/mise/config.toml" >&2
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[DRY-RUN] mise install"
  else
    if ! mise install; then
      echo "mise install に失敗しました" >&2
      exit 1
    fi
  fi
else
  echo "mise が見つかりません。brew bundle で mise がインストールされているか確認してください。" >&2
fi

if [ "$DRY_RUN" -eq 1 ]; then
  echo "[DRY-RUN] すべての処理がスキップされました。実行時は --dry-run を外してください。"
else
  echo "すべてのセットアップが完了しました！ターミナルを再起動してください。"
fi
echo "すべてのセットアップが完了しました！ターミナルを再起動してください。"