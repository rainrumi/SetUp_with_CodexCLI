# Windows 一括セットアップキット

このフォルダは、同じフォルダに配置済みのインストーラーを使って Windows PC の開発ツールを一括セットアップするための PowerShell ツールです。

インストーラー EXE/MSI はインターネットから自動取得しません。OpenAI Codex CLI だけは、Node.js 導入後に npm でグローバルインストールします。

セットアップ処理の最後に、Google Chrome で次のタブを開きます。

- `https://chatgpt.com/ja-JP/`
- `https://github.co.jp/`
- `https://www.microsoft.com/ja-jp/microsoft-teams/log-in`
- `https://discord.com/`

Chrome が見つからない場合、タブは開かずログにスキップ理由を記録します。

## 同梱バージョン（2026-10-28 確認）

| ソフト | バージョン | 公式配布元 |
| --- | --- | --- |
| 7-Zip | 26.05 | https://www.7-zip.org/download.html |
| Godot（標準版） | 4.7.2 stable | https://godotengine.org/download/windows/ |
| Node.js | 24.22.1 LTS | https://nodejs.org/en/download |
| Git for Windows | 2.56.0.windows.4 | https://git-scm.com/install/windows |
| Sourcetree Enterprise | 3.4.32 | https://www.sourcetreeapp.com/enterprise |
| Visual Studio Code | 1.143.1 | https://code.visualstudio.com/updates |
| OpenAI Codex CLI | 実行時の npm latest | https://www.npmjs.com/package/@openai/codex |

これらは確認時点の最新版です。次回以降も自動で新版を取得する仕組みではありません。
既存のソフトはバージョンにかかわらずスキップされます。このキットの更新だけでは、この PC にインストール済みのソフトは更新されません。

## フォルダ構成

実行前に、次の構成でファイルを置いてください。6つの配布ファイルは `resource` フォルダに格納します。

```text
install_all.ps1
RUN_AS_ADMIN.bat
config\software.json
resource\7z2605-x64.exe
resource\Godot_v4.7.2-stable_win64.exe
resource\node-v24.22.1-x64.msi
resource\Git-2.56.0.4-64-bit.exe
resource\SourcetreeEnterpriseSetup_3.4.32.msi
resource\VSCodeUserSetup-x64-1.143.1.exe
```

ログは次のフォルダに出力されます。

```text
logs\
```

## 必須ファイル

- `resource\7z2605-x64.exe`
- `resource\Godot_v4.7.2-stable_win64.exe`
- `resource\node-v24.22.1-x64.msi`
- `resource\Git-2.56.0.4-64-bit.exe`
- `resource\SourcetreeEnterpriseSetup_3.4.32.msi`
- `resource\VSCodeUserSetup-x64-1.143.1.exe`

Godot はインストーラーとして実行せず、単体実行ファイルとしてコピーします。既定の配置先は次の通りです。

```text
C:\Tools\Godot\Godot_v4.7.2-stable_win64.exe
```

配置ルートを変える場合は `-InstallRoot` を指定してください。

## DryRun

実際のインストール、Godot コピー、ExecutionPolicy 変更、npm install、Chrome タブ起動を行わず、予定だけ確認します。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install_all.ps1 -DryRun
```

## 管理者実行

ダブルクリックで開始する場合:

```text
RUN_AS_ADMIN.bat
```

PowerShell から実行する場合:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install_all.ps1
```

管理者権限で実行されていない場合、`install_all.ps1` が自分自身を管理者権限で再実行します。`-DryRun` は管理者権限なしでも続行します。テスト用に昇格を抑止する場合は `-NoElevate` を指定できます。

## 本番実行

必須インストーラーを `resource` フォルダに置いたあと、次を実行します。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install_all.ps1
```

互換性のため `-Force` も受け付けますが、インストール済みソフトは引き続きスキップします:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\install_all.ps1 -Force
```

`-Force` を指定しても、既存ソフトのアンインストールや削除処理は行いません。

PowerShell の実行ポリシーは、未設定の場合のみ `CurrentUser` を `RemoteSigned` に設定します。既に `RemoteSigned` の場合は `-Force` 指定時も再設定しません。組織ポリシーや `-ExecutionPolicy Bypass` など、より優先度の高いスコープで実効ポリシーが上書きされている場合は、警告をログに残してセットアップを続行します。

## ログ確認

メインログ:

```text
logs\install.log
```

個別ログ:

```text
logs\node-install.log
logs\git-install.log
logs\sourcetree-install.log
logs\vscode-install.log
logs\codex-install.log
```

## 初回認証

Codex CLI の初回認証は自動化しません。セットアップ後、ユーザーが手動で次を実行してください。

```powershell
codex
```

その後、ChatGPT アカウントまたは API キーで認証してください。

Sourcetree の初回登録、Atlassian / Bitbucket / GitHub へのログイン、アカウント設定も自動化しません。インストール後に Sourcetree を手動で起動して設定してください。
