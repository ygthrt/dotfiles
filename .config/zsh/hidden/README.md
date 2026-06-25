このファイルはダミーです。`hidden/` ディレクトリをリポジトリに残すために置いてあります。
このディレクトリは機密情報（APIキー、パスワード、マシン固有の設定）をローカルにのみ保持するための場所です。

-- 使用方法（雛形） --
1. 以下のテンプレートファイルをコピーして、`secrets.zsh` として作成してください。

```bash
cp secrets.zsh.example secrets.zsh
# 必要に応じて編集
```

2. `secrets.zsh` の中には、ローカルでだけ使う値を書いてください。例:

```bash
# secrets.zsh
export EXAMPLE_SERVICE_API_KEY="replace-with-local-value"
export EXAMPLE_SERVICE_TOKEN="replace-with-local-value"
```

3. このディレクトリは .gitignore により Git 管理から除外されています。リポジトリに機密情報が含まれないことを確認してください。

注意: このフォルダ内の .zsh ファイルは shell 起動時に自動的に読み込まれます。信頼できる内容のみ配置してください。
