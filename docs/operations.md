# 運用手順

このドキュメントには、dotfiles を更新・保守するときの手順をまとめます。

## Brewfile の更新

Homebrew に新しいパッケージやアプリを追加した場合は、標準の `brew bundle dump` ではなく、このリポジトリで用意している `brew-dump` を使います。

```bash
brew install <package-name>
cd ~/dotfiles
brew-dump
```

`brew-dump` は `.config/zsh/.zshrc` で定義しています。

```bash
alias brew-dump='env PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin" brew bundle dump --force'
```

通常の `brew bundle dump` をそのまま実行すると、mise や npm など別の仕組みで管理しているツールが `Brewfile` に混入することがあります。`brew-dump` は Homebrew 用の PATH に絞ってから `Brewfile` を更新します。

## hidden 設定

API キー、パスワード、特定のマシンでだけ使う設定は、Git 管理対象の設定ファイルには書きません。

ローカルの hidden ディレクトリに `.zsh` ファイルを作成します。

```bash
cd ~/.config/zsh/hidden
cp secrets.zsh.example secrets.zsh
```

`secrets.zsh` は Git 管理外です。必要な環境変数やローカル設定をこのファイルに書きます。

`~/.config/zsh/hidden/` 内の `.zsh` ファイルは shell 起動時に自動で読み込まれます。信頼できる内容だけを配置してください。

## public repository の確認

公開前や公開後の大きな変更時は、秘密情報やローカル状態が混ざっていないか確認します。

```bash
rg -n --hidden -i "(secret|token|password|api[_-]?key|credential|private[_-]?key)" .
git ls-files
git grep -n -I -E "(gh[pousr]_[A-Za-z0-9_]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|sk-[A-Za-z0-9]{20,}|-----BEGIN [A-Z ]*PRIVATE KEY-----)" $(git rev-list --all)
```

実際の秘密情報が履歴に入っていた場合は、現在のファイルから消すだけでは不十分です。該当するキーを失効・再発行し、必要に応じて履歴の扱いを見直します。

## 新しい設定を管理対象に追加する

新しい設定ファイルを dotfiles で管理する場合は、次の順で追加します。

1. 設定ファイルをリポジトリ内の適切な場所に置く。
2. `setup.sh` にリンク作成や初回コピー処理を追加する。
3. 状態変更を伴うコマンドは、ドライラン対応ラッパーを経由させる。
4. `./setup.sh --dry-run` で実行予定を確認する。
5. 必要に応じて `./setup.sh` を実行する。

シンボリックリンクを作る場合は、原則として `ln -snf` を使います。

```bash
execute_cmd "ln -snf \"$DOTFILES_DIR/.config/example/config\" \"$HOME/.config/example/config\""
```

初回配置だけにしたい設定は、既存ファイルがない場合のみ `cp` する形にします。

## 変更後の確認

`setup.sh` や管理設定を変更した後は、まずドライランで確認します。

```bash
./setup.sh --dry-run
```

確認する内容:

- パスが正しく展開されているか
- 予期しないファイルを変更しようとしていないか
- 破壊的操作が直接実行されていないか
- 同じ処理が重複していないか

問題なければ本番実行します。

```bash
./setup.sh
```

## 判断に迷ったときの優先順位

迷った場合は、次の順に優先します。

1. 秘密情報を漏らさない
2. ユーザーの環境を壊さない
3. ドライランで安全に確認できる
4. 何度実行しても同じ状態に収束する
5. 管理責務を重複させない
6. 将来の自分が理解できる
7. 便利さを追加する
