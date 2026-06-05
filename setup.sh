#!/bin/bash

echo "セットアップを開始します..."

# =========================================================
# 1. 必要なディレクトリの作成
# =========================================================
echo "必要なディレクトリを作成しています..."
mkdir -p ~/.config/zsh
mkdir -p ~/.config/ghostty
mkdir -p ~/Library/Application\ Support/Code/User
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

ln -snf ~/dotfiles/vscode/settings.json ~/Library/Application\ Support/Code/User/settings.json
ln -snf ~/dotfiles/vscode/keybindings.json ~/Library/Application\ Support/Code/User/keybindings.json

# =========================================================
# 3. Homebrew のインストールとパス設定
# =========================================================
echo "Homebrew の状態を確認しています..."
if ! command -v brew &> /dev/null; then
    echo "Homebrew が見つからないため、インストールします..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Apple Silicon (M1/M2/M3) 用のパス設定
    if ! grep -q 'eval "$(/opt/homebrew/bin/brew shellenv)"' ~/.zprofile 2>/dev/null; then
     echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
    fi
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

echo "すべてのセットアップが完了しました！ターミナルを再起動してください。"