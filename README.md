# dotfiles

macOS の開発環境を再現しやすくするための dotfiles リポジトリです。

`setup.sh` で設定ファイルのリンク作成、Homebrew によるアプリ・CLI ツールの導入、mise / opam の初期セットアップを行います。

## 対象環境

- macOS
- Apple Silicon / Intel Mac

## 事前準備

コマンドラインツールをインストールします。

```bash
xcode-select --install
```


## セットアップ

既定では `~/dotfiles` に clone して実行します。

```bash
cd ~
git clone https://github.com/ygthrt/dotfiles.git
cd dotfiles
chmod +x setup.sh
./setup.sh --dry-run
./setup.sh
```

別の場所に clone した場合は、`DOTFILES_DIR` を指定して実行します。

```bash
git clone https://github.com/ygthrt/dotfiles.git "$HOME/my-dotfiles"
cd "$HOME/my-dotfiles"
chmod +x setup.sh
DOTFILES_DIR="$PWD" ./setup.sh --dry-run
DOTFILES_DIR="$PWD" ./setup.sh
```

セットアップ後、ターミナルを再起動するか、zsh 設定を読み込み直します。

```bash
source ~/.zshrc
```

## 詳細

- [設計方針](docs/design.md)
- [運用手順](docs/operations.md)
- [Roadmap](docs/roadmap.md)
