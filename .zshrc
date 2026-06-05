# ~/.zshrc

# このリポジトリからzsh設定を読み込む
if [ -f "$HOME/.config/zsh/.zshrc" ]; then
  source "$HOME/.config/zsh/.zshrc"
fi

# cdコマンドを省略してディレクトリ名のみで移動できる（今回設定したもの）
setopt AUTO_CD

# 入力したコマンドのスペルミスを自動で訂正・提案してくれる
setopt CORRECT

# コマンド履歴に同じコマンドが連続して残らないようにする
setopt HIST_IGNORE_DUPS

# 複数のターミナル（タブ）を開いている場合、コマンド履歴を共有する
setopt SHARE_HISTORY

# cdで移動するたびに履歴を保存し、「cd -[Tab]」で過去のディレクトリにアクセスできるようにする
setopt AUTO_PUSHD

# Homebrew専用のクリーンなPATHでBrewfileを出力する
alias brew-dump='env PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin" brew bundle dump --force'

# ==========================================
# opam (OCaml パッケージマネージャー)
# ==========================================
[[ ! -r ~/.opam/opam-init/init.zsh ]] || source ~/.opam/opam-init/init.zsh  > /dev/null 2> /dev/null

# ==========================================
# mise (環境構築・バージョン管理)
# ==========================================
eval "$(mise activate zsh)"
