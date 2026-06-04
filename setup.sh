#!/bin/bash

echo "セットアップを開始します..."

# =========================================================
# 1. 必要なディレクトリの作成
# =========================================================
echo "必要なディレクトリを作成しています..."
mkdir -p ~/.config/zsh
mkdir -p ~/.config/ghostty

# =========================================================
# 2. シンボリックリンクの作成
# =========================================================
echo "シンボリックリンクを作成しています..."
# ln -snf で既存のファイルがあっても上書きしてリンクします
ln -snf ~/dotfiles/.zshrc ~/.zshrc
ln -snf ~/dotfiles/.config/zsh/.zshrc ~/.config/zsh/.zshrc
ln -snf ~/dotfiles/.config/zsh/hidden ~/.config/zsh/hidden
ln -snf ~/dotfiles/.config/starship.toml ~/.config/starship.toml
ln -snf ~/dotfiles/.config/ghostty/config ~/.config/ghostty/config

# =========================================================
# 3. Homebrew のインストールとパス設定
# =========================================================
echo "Homebrew の状態を確認しています..."
if ! command -v brew &> /dev/null; then
    echo "Homebrew が見つからないため、インストールします..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Apple Silicon (M1/M2/M3) 用のパス設定
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    echo "Homebrew は既にインストールされています。スキップします。"
fi

# =========================================================
# 4. Brewfile からアプリとツールのインストール
# =========================================================
echo "Brewfile からアプリをインストールしています..."
cd ~/dotfiles
brew bundle

echo "すべてのセットアップが完了しました！ターミナルを再起動してください。"