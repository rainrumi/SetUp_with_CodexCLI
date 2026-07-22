# 10. 受け入れテスト要件

Codexは実装後、最低限以下を満たすようにする。
実際のインストーラー実行はしないこと。構文チェックとDryRun確認を中心にする。

## 構文チェック

PowerShell構文として読めること。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$null = [scriptblock]::Create((Get-Content -Raw .\install_all.ps1)); 'OK'"
```

## DryRun

以下で実行予定だけ確認できること。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install_all.ps1 -DryRun
```

DryRunで期待すること：

- 実インストールされない
- Godotコピーされない
- ExecutionPolicyが変更されない
- npm installが実行されない
- 実行予定コマンドが表示・ログ出力される

## 必須ファイル欠落時

いずれかの必須ファイルがない場合、明確なエラーを出して停止すること。

例：

```text
必要ファイルが見つかりません: SourcetreeEnterpriseSetup_3.4.30.msi
```

## インストール済み判定

インストール済みのものはスキップされること。

例：

```text
7-Zip はインストール済みのためスキップ
Node.js はインストール済みのためスキップ
```

## Sourcetree Enterprise MSI

生成された `install_all.ps1` 内で、SourceTreeSetup EXEではなく次を使っていること。

```text
SourcetreeEnterpriseSetup_3.4.30.msi
```

また、MSI引数に以下が含まれていること。

```text
ACCEPTEULA=1
/qn
/norestart
```

## Codex CLI

生成された `install_all.ps1` 内で、Codex CLIのインストールコマンドが以下を基本としていること。

```text
npm i -g @openai/codex
```

## README確認

`README.md` に次が書かれていること。

- 実行前に置くファイル一覧
- DryRun方法
- 管理者実行方法
- 本番実行方法
- ログの場所
- Codex初回認証はユーザーが手動で行うこと
- Sourcetree初回登録はユーザーが手動で行うこと
