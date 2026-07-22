# 07. サイレントインストールコマンド要件

## 共通

外部プロセス実行は `Start-Process -Wait -PassThru` を使い、終了コードを確認する。
ログファイルを指定できるインストーラーでは個別ログを出す。

## 7-Zip

```powershell
Start-Process -FilePath ".\7z2501-x64.exe" -ArgumentList @("/S") -Wait -PassThru
```

## Node.js MSI

```powershell
msiexec.exe /i "node-v24.15.0-x64.msi" /qn /norestart /L*v "logs\node-install.log"
```

PowerShellの `Start-Process` では次のような引数配列にする。

```powershell
@(
  "/i",
  "`"$NodeMsi`"",
  "/qn",
  "/norestart",
  "/L*v",
  "`"$NodeLog`""
)
```

## Sourcetree Enterprise MSI

SourceTreeSetup EXEは使わない。
必ず以下を使う。

```text
SourcetreeEnterpriseSetup_3.4.30.msi
```

サイレントインストールコマンド：

```powershell
msiexec.exe /i "SourcetreeEnterpriseSetup_3.4.30.msi" ACCEPTEULA=1 /qn /norestart /L*v "logs\sourcetree-install.log"
```

PowerShellの `Start-Process` では次のような引数配列にする。

```powershell
@(
  "/i",
  "`"$SourcetreeMsi`"",
  "ACCEPTEULA=1",
  "/qn",
  "/norestart",
  "/L*v",
  "`"$SourcetreeLog`""
)
```

## Visual Studio Code User Installer

```powershell
Start-Process -FilePath ".\VSCodeUserSetup-x64-1.119.0.exe" -ArgumentList @("/VERYSILENT", "/NORESTART", "/MERGETASKS=!runcode") -Wait -PassThru
```

任意で以下のタスクを追加してよい。

```text
addcontextmenufiles
addcontextmenufolders
addtopath
```

ただし、自動起動はしない。

## Godot

インストーラーとして実行しない。
コピーする。

```powershell
Copy-Item -Path ".\Godot_v4.6.2-stable_win64.exe" -Destination "C:\Tools\Godot\Godot_v4.6.2-stable_win64.exe" -Force
```

## Codex CLI

Node/npmが使えるようになった後に以下を実行する。

```powershell
cmd.exe /c "npm i -g @openai/codex"
```

実行後、以下で確認する。

```powershell
cmd.exe /c "codex --version"
```

npmのWindows optional dependency問題に備えて、初回失敗時は次を1回だけリトライしてよい。

```powershell
cmd.exe /c "npm i -g @openai/codex@latest --include=optional"
```

## ExecutionPolicy

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
```

`-DryRun` のときは実行しない。
