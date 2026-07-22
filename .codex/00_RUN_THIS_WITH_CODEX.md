# Codex実行用エントリーファイル

## Codexへの指示

このMarkdownファイルを起点として、下記の参照先Markdownをすべて順番に読み込んでください。
そのうえで、Windows PowerShellで実行できる一括セットアップツール一式をこのフォルダ内に作成してください。

ユーザーからの実行指示は次の1行だけで成立する想定です。

```text
00_RUN_THIS_WITH_CODEX.md ファイルを実行してください
```

## 実装時の厳守事項

- 実装中に実際のインストーラーを実行しないこと。
- `install_all.ps1` は作成するが、Codex自身が勝手に実行しないこと。
- PowerShellコードは Windows PowerShell 5.1 以上で動くようにすること。
- インストーラーはローカルに既に存在する前提で扱うこと。
- インターネットから取得するのは、Node/npm導入後の `@openai/codex` の npm グローバルインストールだけにすること。
- 管理者権限が必要な処理は、スクリプト側で検出し、必要なら昇格再実行すること。
- UIの規約同意画面を無理やり操作する処理は書かないこと。
- サイレントインストール引数として公式・標準的に用意されている同意プロパティのみ使うこと。
- 既にインストール済みのものは原則スキップすること。
- 失敗した場合はログに残し、次に何を確認すべきか分かるメッセージを出すこと。

## 参照する要件ファイル

以下のファイルをすべて読み込んでから実装してください。

1. `requirements/01_goal_and_scope.md`
2. `requirements/02_local_files_and_paths.md`
3. `requirements/03_output_files.md`
4. `requirements/04_powershell_architecture.md`
5. `requirements/05_install_targets.md`
6. `requirements/06_detection_rules.md`
7. `requirements/07_silent_install_commands.md`
8. `requirements/08_codex_cli_and_execution_policy.md`
9. `requirements/09_logging_error_handling_security.md`
10. `requirements/10_acceptance_tests.md`

## 最終的に作成するもの

最低限、次のファイルを作成してください。

```text
install_all.ps1
RUN_AS_ADMIN.bat
README.md
config/software.json
```

必要なら補助ファイルを追加してもよいですが、上記4ファイルは必須です。

## 実装完了後に出す説明

実装後、次を簡潔に説明してください。

- 作成したファイル一覧
- 実行方法
- 実行前に同じフォルダへ置く必要があるインストーラー一覧
- DryRunの実行方法
- 本番実行方法
- SourceTree Enterprise MSIで `ACCEPTEULA=1` を使っている箇所
- Codex CLIを `npm i -g @openai/codex` で入れる箇所
