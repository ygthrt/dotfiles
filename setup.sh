#!/bin/bash
set -e

echo "セットアップを開始します..."

# =========================================================
# 1. 必要なディレクトリの作成
# =========================================================
echo "必要なディレクトリを作成しています..."
mkdir -p ~/.config/zsh
mkdir -p ~/.config/ghostty
mkdir -p "${HOME}/Library/Application Support/Code/User"
mkdir -p ~/.config/mise

# DOTFILES_DIR: 環境変数 > スクリプト引数 > デフォルト
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
    mv "$target" "$BACKUP_DIR/${bn}.pre-dotfiles-${ts}"
    echo "バックアップ: $target -> $BACKUP_DIR/${bn}.pre-dotfiles-${ts}"
  fi
}

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
if ! brew bundle; then
  echo "brew bundle に失敗しました。ログを確認してください。" >&2
  exit 1
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
        opam init --disable-sandboxing --reinit -y
        
        # MetaOCamlの環境を自動作成(-y)
        opam switch create metaocaml 5.3.0+BER -y
    else
        echo "opam はすでにセットアップされています。"
    fi
fi

# mise は brew bundle 後に存在するはずなのでここで trust と install を行う
if command -v mise &> /dev/null; then
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
else
  echo "mise が見つかりません。brew bundle で mise がインストールされているか確認してください。" >&2
fi

echo "すべてのセットアップが完了しました！ターミナルを再起動してください。"
echo "すべてのセットアップが完了しました！ターミナルを再起動してください。"