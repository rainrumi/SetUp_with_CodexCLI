# 03. 生成ファイル要件

Codexは最低限、次のファイルを生成すること。

## 1. `install_all.ps1`

メインのPowerShellスクリプト。
以下の機能を持つ。

- 管理者権限チェック
- 必要なら管理者として自己再実行
- 必須ファイル存在チェック
- インストール済み判定
- 7-Zipインストール
- Godot配置
- Node.jsインストール
- Sourcetree Enterprise MSIインストール
- Visual Studio Codeインストール
- PowerShell ExecutionPolicy設定
- Codex CLIインストール
- ログ出力
- DryRun対応
- エラー処理

## 2. `RUN_AS_ADMIN.bat`

ユーザーがダブルクリックで開始できる補助ファイル。
ただし、最終的にはPowerShellを管理者権限で起動して `install_all.ps1` を呼ぶだけにする。

例の方向性：

```bat
@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install_all.ps1"
pause
```

実装時は管理者昇格が必要ならPowerShell側で処理する。

## 3. `README.md`

ユーザー向け説明。
以下を書く。

- このツールの目的
- フォルダ構成
- 必須ファイル一覧
- DryRun方法
- 本番実行方法
- ログ確認方法
- Codex CLI初回認証は自動化しないこと
- Sourcetree初回起動時の登録・認証は自動化しないこと

## 4. `config/software.json`

対象ソフト、ファイル名、検出パス、インストール引数を設定として分離する。

要件：

- JSONとして正しいこと
- PowerShellから `ConvertFrom-Json` で読めること
- ハッシュ値は任意項目とし、未指定なら検証をスキップすること
- Godot配置先を設定できること

## 補助ファイル

必要なら以下を追加してよい。

```text
scripts\common.ps1
scripts\installers.ps1
```

ただし、シンプルさを優先する場合は `install_all.ps1` だけにまとめてよい。
