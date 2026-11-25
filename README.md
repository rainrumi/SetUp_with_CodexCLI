# 使い方

1, LAUNCH_GUI.batを起動
2, 指示に従って使いたいツールや起動するツールをカスタマイズ
3, セットアップを開始
4, 完了

# Windows 一括セットアップキット

このフォルダは、ローカル配置済みのインストーラーや `winget` / `npm` を使って Windows PC の開発ツール・アプリを一括セットアップするためのツールです。

`LAUNCH_GUI.bat`（または `python setup_gui.py`）から tkinter GUI を起動し、ワンボタンでセットアップを開始できます。GUI 上で以下を自由に選択できます。

- **ダウンロード / インストールするソフト**（7-Zip / Godot / Node.js / Git / Sourcetree / VS Code / Codex CLI / ChatGPT / Google Antigravity / Unity Hub / Steam）
- **ChatGPT の利用方式**（デスクトップ版を Microsoft Store から導入して起動 / Web版 `https://chatgpt.com/` をブラウザで開く）
- **セットアップ後に展開するウィンドウ**（起動するアプリ、Chrome で開くタブ）
- **不足ファイルの自動検知と公式ダウンロードリンク集 GUI**（`resource` フォルダに必要な exe/msi が存在しない場合、GUI 起動時に自動で別ウィンドウのリンク集が開きます）

Chrome が見つからない場合、タブは開かずログにスキップ理由を記録します（ただし ChatGPT Web版のみ既定ブラウザへフォールバックします）。

## GUI からの起動（推奨）

ダブルクリックで GUI を起動する場合:

```text
LAUNCH_GUI.bat
```

またはコマンドから起動する場合:

```powershell
python .\app\setup_gui.py
```

`resource` フォルダに未配置の必須インストーラーがある場合、メイン GUI とは別に **不足ファイル・公式ダウンロードリンク集 GUI**（`app\resource_links_gui.py`）が自動で開きます。必要なバージョンと公式ダウンロードページへのリンクを確認し、ダウンロードしたファイルを `resource` フォルダへ配置してください。

## 対象ソフトとバージョン

| ソフト | バージョン | 導入方法 | 公式配布元 |
| --- | --- | --- | --- |
| 7-Zip | 26.05 (x64) | `resource` ローカル必須 | https://www.7-zip.org/download.html |
| Godot（標準版） | 4.7.2 stable (win64) | `resource` ローカル必須（コピー配置） | https://godotengine.org/download/windows/ |
| Node.js | 24.22.1 LTS (x64) | `resource` ローカル必須 | https://nodejs.org/en/download |
| Git for Windows | 2.56.0.windows.4 (64-bit) | `resource` ローカル必須 | https://git-scm.com/install/windows |
| Sourcetree Enterprise | 3.4.32 (MSI) | `resource` ローカル必須 | https://www.sourcetreeapp.com/enterprise |
| Visual Studio Code | 1.143.1 (User x64) | `resource` ローカル必須 | https://code.visualstudio.com/updates |
| OpenAI Codex CLI | 実行時の npm latest | `npm` 自動導入 | https://www.npmjs.com/package/@openai/codex |
| ChatGPT | Microsoft Store 最新版 / Web版 | `winget` (Store) または Web (`https://chatgpt.com/`) | https://apps.microsoft.com/detail/9PLM9XGG6VKS |
| Google Antigravity (x64/Win) | Windows x64 最新 | `winget` 自動導入（`resource` に配置があれば優先） | https://antigravity.google/download |
| Unity Hub (x64/Win) | Windows x64 最新 | `winget` 自動導入（`resource` に配置があれば優先） | https://unity.com/download |
| Steam | Windows 最新 | `winget` 自動導入（`resource` に配置があれば優先） | https://store.steampowered.com/about/ |

> exe / msi ファイルは GitHub 規約・配布ライセンスの都合上リポジトリに含めず、公式リンクのみを記載しています。手動で `resource` フォルダへ配置するインストーラーは、必ず各公式サイトから取得したものを使用してください。
>
> また、サイレントインストール処理では各ソフト公式の規約同意フラグ（Sourcetree の `ACCEPTEULA=1`、`winget` の `--accept-package-agreements` 等）を使用します。各ソフトウェアの利用規約に同意したうえで実行してください。

既存のソフトはバージョンにかかわらずスキップされます。このキットの更新だけでは、この PC にインストール済みのソフトは更新されません。

## フォルダ構成

実行前に、次の構成でファイルを置いてください。6つの必須配布ファイルは `resource` フォルダに格納します。

```text
LAUNCH_GUI.bat
README.md
LICENSE
簡易コマンド集.txt
app\setup_gui.py
app\resource_links_gui.py
app\install_all.ps1
app\RUN_AS_ADMIN.bat
app\config\software.json
app\logs\
resource\7z2605-x64.exe
resource\Godot_v4.7.2-stable_win64.exe
resource\node-v24.22.1-x64.msi
resource\Git-2.56.0.4-64-bit.exe
resource\SourcetreeEnterpriseSetup_3.4.32.msi
resource\VSCodeUserSetup-x64-1.143.1.exe
```

ログは次のフォルダに出力されます。

```text
app\logs\
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

実際のインストール、ChatGPT のダウンロード、Godot コピー、ExecutionPolicy 変更、npm install、アプリ・Chrome タブ起動を行わず、予定だけ確認します。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\app\install_all.ps1 -DryRun
```

## 管理者実行

ダブルクリックで開始する場合:

```text
app\RUN_AS_ADMIN.bat
```

PowerShell から実行する場合:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\app\install_all.ps1
```

管理者権限で実行されていない場合、`install_all.ps1` が自分自身を管理者権限で再実行します。`-DryRun` は管理者権限なしでも続行します。テスト用に昇格を抑止する場合は `-NoElevate` を指定できます。

ChatGPT の導入は管理者処理の完了後、最初に実行したユーザーのプロセスで行います。Microsoft Store に接続できる環境と `winget.exe`（アプリ インストーラー）が必要です。`winget` がない場合は Microsoft Store で「アプリ インストーラー」を導入・更新してください。失敗時はログに原因を記録して停止します。公式の導入方法は [OpenAI の Windows アプリ案内](https://help.openai.com/en/articles/9982051-using-the-chatgpt-windows-app) を参照してください。

`-SkipAppLaunches` でアプリの自動起動を、`-SkipChromeTabs` で Chrome のタブ起動を省略できます。いずれもインストール処理は行います。`-DeferChatGPTInstall` は管理者への再実行で内部的に使う引数です。

画面が表示されない場合は、ログオン中のデスクトップで開いた PowerShell から実行し、`logs\install.log` の末尾を確認してください。`LaunchRequested` は Windows に起動を依頼した状態です。起動処理でエラーが検出された場合は `Failed` と原因を記録し、残りのアプリや Chrome の起動を試します。

## 本番実行

必須インストーラーを `resource` フォルダに置いたあと、次を実行します。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\app\install_all.ps1
```

互換性のため `-Force` も受け付けますが、インストール済みソフトは引き続きスキップします:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\app\install_all.ps1 -Force
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

ChatGPT デスクトップ版の初回ログインは、起動したアプリ上で手動で行ってください。

Codex CLI の初回認証は自動化しません。セットアップ後、ユーザーが手動で次を実行してください。

```powershell
codex
```

その後、ChatGPT アカウントまたは API キーで認証してください。

Sourcetree の初回登録、Atlassian / Bitbucket / GitHub へのログイン、アカウント設定も自動化しません。インストール後に Sourcetree を手動で起動して設定してください。
