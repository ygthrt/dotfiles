# dotfiles

macOS の開発環境を再現しやすくするための dotfiles リポジトリです。

`setup.sh` で設定ファイルのリンク作成、Homebrew によるアプリ・CLI ツールの導入、Elan の初期設定、mise ツールの不足分インストール、通常 OCaml と MetaOCaml の環境構築を行います。

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

`setup.sh` は Brewfile に記載されたパッケージやアプリの不足分だけを導入し、既にインストールされているものは更新しません。既存環境の更新はセットアップと分けて明示的に行います。

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

## Lean 4

Homebrew は Lean 4 の toolchain manager である Elan と公式 VS Code 拡張を導入し、Lean toolchain 自体は Elan が管理します。`setup.sh` は Elan の default toolchain が未設定の場合だけ `leanprover/lean4:stable` を設定し、既存の default は変更しません。

グローバルな `stable` はプロジェクト外で使うフォールバックです。各 Lean プロジェクトでは、プロジェクトルートの `lean-toolchain` に具体的なバージョンを指定してください。この dotfiles 自体には `lean-toolchain` を置かず、`~/.elan` も Git 管理しません。

実機導入後、最初に `lean` や `lake` を実行したときは、選択された Lean toolchain がダウンロードされる場合があります。

## OCaml

通常の OCaml 開発には opam の `default` switch を使い、`dune`、`ocaml-lsp-server`、`utop`、`ocamlformat` を導入します。VS Code の OCaml Platform も `default` switch を参照します。

MetaOCaml は `metaocaml` switch に分離し、`utop` パッケージが提供する `utop-full` を MetaOCaml 対応の REPL として使います。次のコマンドで必要なときだけ起動します。

```bash
metaocaml
metautop
metaocamlc -o example.byte example.ml
metaocamlopt -o example.native example.ml
```

OCaml 環境の構築を一時的に省略する場合は `SKIP_OCAML_SETUP=1` を指定します。

```bash
SKIP_OCAML_SETUP=1 ./setup.sh
```

詳しい構成と更新方法は [運用手順](docs/operations.md) を参照してください。

## 詳細

- [設計方針](docs/design.md)
- [運用手順](docs/operations.md)
- [Roadmap](docs/roadmap.md)
