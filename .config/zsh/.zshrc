##### Language/Editor #####
export LANG=en_US.UTF-8
export EDITOR="vim"

#### starship
eval "$(starship init zsh)"

#### autosuggestions
source $HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh
#### fast syntax highlighting
source $HOMEBREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

#### History search with arrow keys #####
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey "^[[A" up-line-or-beginning-search
bindkey "^[[B" down-line-or-beginning-search

#### Make word deletion stop at path separators, etc.
WORDCHARS=''

#### Apply hidden sources (ignored by Git; e.g., secrets or machine-specific)
#### It recursively reads all .zsh files in the hidden/ 
HIDDEN_ALIASES_DIR="$HOME/.config/zsh/hidden"
if [ -d "$HIDDEN_ALIASES_DIR" ]; then
  for f in "$HIDDEN_ALIASES_DIR"/*.zsh(N); do
    if [ -r "$f" ] && [ -f "$f" ]; then
      source "$f"
    fi
  done
fi

# ==========================================
# opam (OCaml パッケージマネージャー)
# ==========================================
[[ ! -r ~/.opam/opam-init/init.zsh ]] || source ~/.opam/opam-init/init.zsh  > /dev/null 2> /dev/null

# ==========================================
# mise (環境構築・バージョン管理)
# ==========================================
eval "$(mise activate zsh)"

# Homebrew専用のクリーンなPATHでBrewfileを出力する
alias brew-dump='env PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin" brew bundle dump --force'

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

