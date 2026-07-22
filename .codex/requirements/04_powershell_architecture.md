# 04. PowerShell設計要件

## スクリプト引数

`install_all.ps1` は最低限、次の引数を受け取る。

```powershell
param(
    [switch]$DryRun,
    [switch]$Force,
    [switch]$NoElevate,
    [string]$InstallRoot = "C:\Tools"
)
```

## 引数の意味

| 引数 | 意味 |
|---|---|
| `-DryRun` | 実際にはインストールせず、実行予定だけログと画面に出す |
| `-Force` | 一部の既存判定を無視して再実行できるようにする。ただし危険な上書きは避ける |
| `-NoElevate` | 管理者昇格の自己再実行を抑止する。テスト用 |
| `-InstallRoot` | Godotなどの配置先ルート |

## 関数設計

最低限、以下の関数に分ける。

```powershell
Write-Log
Assert-RequiredFiles
Test-IsAdmin
Restart-AsAdminIfNeeded
Invoke-ExternalProcess
Test-CommandExists
Get-CommandVersion
Get-FileSha256
Install-7Zip
Install-Godot
Install-Node
Install-SourcetreeEnterprise
Install-VSCode
Set-UserExecutionPolicy
Install-CodexCli
Show-Summary
```

## 実行順序

次の順番で処理する。

1. 初期化
2. ログフォルダ作成
3. 管理者権限確認
4. 必須ファイル存在確認
5. 7-Zip
6. Godot
7. Node.js
8. Sourcetree Enterprise
9. Visual Studio Code
10. ExecutionPolicy設定
11. Codex CLI
12. 最終結果表示

## DryRun要件

`-DryRun` の場合：

- ファイル存在チェックは行う
- インストール済み判定は行う
- 実行予定コマンドを表示する
- `Start-Process` は呼ばない
- `Set-ExecutionPolicy` は呼ばない
- `npm install` は実行しない
- Godotのコピーも実行しない

## 外部プロセス実行

外部プロセス実行は必ず共通関数 `Invoke-ExternalProcess` 経由にする。

要件：

- 実行ファイルパスをログに出す
- 引数をログに出す
- 終了コードをログに出す
- 終了コードが `0` 以外なら例外にする
- MSIでは `3010` を「再起動要求つき成功」として扱ってよい

## PATH反映

Node.jsインストール後、現在のPowerShellセッションへ以下を反映する。

```powershell
$env:Path = "C:\Program Files\nodejs;$env:Path"
```

npmグローバルパスも必要に応じて検出する。
