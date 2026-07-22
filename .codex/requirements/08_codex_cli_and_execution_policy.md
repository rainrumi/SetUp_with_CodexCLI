# 08. Codex CLIとExecutionPolicy要件

## Codex CLI

Node.jsとnpmが利用可能になった後に、OpenAI Codex CLIをnpmでグローバルインストールする。

基本コマンド：

```powershell
cmd.exe /c "npm i -g @openai/codex"
```

確認コマンド：

```powershell
cmd.exe /c "codex --version"
```

## npm実行前チェック

実行前に以下を確認する。

```powershell
Get-Command node.exe
Get-Command npm.cmd
```

見つからない場合はエラーにする。

## PATH反映

Node.jsをインストールした直後のPowerShellセッションでnpmが見つからない場合に備えて、以下をPATHに加える。

```powershell
$env:Path = "C:\Program Files\nodejs;$env:Path"
```

必要ならnpmのグローバルbin候補も加える。

```powershell
$env:Path = "$env:APPDATA\npm;$env:Path"
```

## Codex CLI初回認証

初回認証は自動化しない。
READMEには、セットアップ後にユーザーが手動で以下を実行する必要があると書く。

```powershell
codex
```

その後、ChatGPTアカウントまたはAPIキーで認証する。

## ExecutionPolicy

以下を実行する。

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
```

設定後、以下で確認してログに残す。

```powershell
Get-ExecutionPolicy -Scope CurrentUser
```

## 実行順

ExecutionPolicy設定は、ローカルスクリプトの以後の扱いを考えてCodex CLIインストール前に行ってよい。
ただし、この `install_all.ps1` 自体は `-ExecutionPolicy Bypass` で起動される可能性があるため、実行中に必須ではない。

推奨順：

1. Node.js確認/インストール
2. ExecutionPolicyをCurrentUserでRemoteSignedへ設定
3. npmでCodex CLIインストール
4. `codex --version` 確認
