# 使い方

1. `LAUNCH_GUI.bat` を起動
2. 画面の指示に従って使いたいツールや起動するツールをカスタマイズ
3. 「セットアップを開始」をクリック
4. 完了

---

# Windows 一括セットアップキット

ローカル配置済みのインストーラーや `winget` / `npm` を使って、Windows PC の開発ツール・アプリを一括セットアップするためのツールです。

`LAUNCH_GUI.bat`（または `python .\app\setup_gui.py`）から tkinter GUI を起動し、ワンボタンでセットアップを開始できます。

## 主な機能・GUI 仕様

- **ダウンロード / インストールするソフトの個別選択**
  - 7-Zip / Godot / Node.js / Git for Windows / Sourcetree Enterprise / Visual Studio Code / OpenAI Codex CLI / ChatGPT / Google Antigravity (x64/Win) / Unity Hub (x64/Win) / Steam
- **ChatGPT の利用方式選択**
  - **デスクトップ版**（Microsoft Store から `winget` で導入・起動）または **Web版**（`https://chatgpt.com/` をブラウザで開く）を選択可能
- **セットアップ後に展開するウィンドウの個別選択**
  - 起動するアプリ（Godot / Sourcetree / VS Code / ChatGPT / Antigravity / Unity Hub / Steam）
  - Chrome で開くタブ（GitHub / Microsoft Teams / Discord / ChatGPT Web版）
  - 未導入かつダウンロード側でチェックが外れているアプリを起動対象にチェックした場合、横に赤文字で `※ダウンロードされないため起動されません` と警告表示します。
- **設定の自動保存・復元**
  - チェックボックス・ChatGPT モード・Godot 配置ルートは `app\config\gui_settings.json` に自動保存され、次回起動時も前回の設定が復元されます。
- **未選択項目の視覚的区別**
  - チェックが外れているソフトは、メイン GUI のステータス表示およびダウンロードリンク集の該当行全体が薄いグレー表示になります（リンク集のボタンはそのまま押せます）。
- **`resource` フォルダの自動作成と開始時チェック**
  - `LAUNCH_GUI.bat` 起動時に `resource` フォルダが存在しない場合は自動で作成します。
  - ローカルインストーラー 6 種は **選択中かつ未導入で実際にファイルを使用する場合のみ必要** です。
  - 「セットアップを開始」／「DryRunで確認」をクリックした際に不足ファイルがある場合、必要なファイルを箇条書きで明記した確認ダイアログを表示し、「はい」を選んだときのみ **ダウンロードリンク集 GUI**（`app\resource_links_gui.py`）を開きます（メイン GUI 右上の「DLリンク集を開く」からいつでも手動で開くこともできます）。

Chrome が見つからない場合、タブは開かずログにスキップ理由を記録します（ただし ChatGPT Web版のみ既定ブラウザへフォールバックします）。

## 動作要件

- **OS**: Windows 10 / Windows 11 (x64)
- **GUI 起動**: Python 3（標準ライブラリ `tkinter` 同梱）
- **PowerShell**: Windows PowerShell 5.1 以上
- **自動取得系ソフト**（ChatGPT デスクトップ版 / Antigravity / Unity Hub / Steam）: インターネット接続および `winget.exe`（Microsoft Store の「アプリ インストーラー」）

## GUI からの起動（推奨）

ダブルクリックで GUI を起動する場合:

```text
LAUNCH_GUI.bat
```

コマンドから起動する場合:

```powershell
python .\app\setup_gui.py
```

ダウンロードリンク集 GUI のみを単体で開く場合:

```powershell
python .\app\resource_links_gui.py
```

## 対象ソフトとファイル名規格

ローカルインストーラーは **バージョン番号を固定せずワイルドカード（パターン）で自動検出** します。`resource` フォルダ内に同じソフトの複数バージョンが置かれている場合は、最も新しいファイルが自動選択されます。

| ソフト | ファイル名規格（`resource\` 内） | 導入方法 | 公式配布元 |
| --- | --- | --- | --- |
| 7-Zip | `7z*-x64.exe` | ローカル（選択導入時のみ必要） | https://www.7-zip.org/download.html |
| Godot（標準版） | `Godot_v*-stable_win64.exe` | ローカル（選択導入時のみ必要・コピー配置） | https://godotengine.org/download/windows/ |
| Node.js | `node-v*-x64.msi` | ローカル（選択導入時のみ必要） | https://nodejs.org/en/download |
| Git for Windows | `Git-*-64-bit.exe` | ローカル（選択導入時のみ必要） | https://git-scm.com/install/windows |
| Sourcetree Enterprise | `SourcetreeEnterpriseSetup_*.msi` | ローカル（選択導入時のみ必要） | https://www.sourcetreeapp.com/enterprise |
| Visual Studio Code | `VSCodeUserSetup-x64-*.exe` | ローカル（選択導入時のみ必要） | https://code.visualstudio.com/updates |
| OpenAI Codex CLI | 不要 | `npm` 自動導入（Node.js 導入後） | https://www.npmjs.com/package/@openai/codex |
| ChatGPT | 不要 | `winget` (Store) または Web (`https://chatgpt.com/`) | https://apps.microsoft.com/detail/9PLM9XGG6VKS |
| Google Antigravity (x64/Win) | `Antigravity*.exe`（任意） | `winget` 自動導入（`resource` 配置時はローカル優先） | https://antigravity.google/download |
| Unity Hub (x64/Win) | `UnityHubSetup*.exe`（任意） | `winget` 自動導入（`resource` 配置時はローカル優先） | https://unity.com/download |
| Steam | `SteamSetup*.exe`（任意） | `winget` 自動導入（`resource` 配置時はローカル優先） | https://store.steampowered.com/about/ |

> exe / msi ファイルは GitHub 規約・配布ライセンスの都合上リポジトリに含めず、公式リンクのみを記載しています。手動で `resource` フォルダへ配置するインストーラーは、必ず各公式サイトから取得したものを使用してください。
>
> また、サイレントインストール処理では各ソフト公式の規約同意フラグ（Sourcetree の `ACCEPTEULA=1`、`winget` の `--accept-package-agreements` 等）を使用します。各ソフトウェアの利用規約に同意したうえで実行してください。

既存のソフトはバージョンにかかわらずスキップされます。このキットの実行によってインストール済みのソフトがアンインストール・上書きされることはありません。

## フォルダ構成

```text
LAUNCH_GUI.bat                 # GUI 起動ランチャー（ダブルクリック用）
README.md
LICENSE
簡易コマンド集.txt
app\
  setup_gui.py                 # メイン GUI
  resource_links_gui.py        # 公式ダウンロードリンク集 GUI
  install_all.ps1              # セットアップ本体スクリプト
  RUN_AS_ADMIN.bat             # CLI 実行用ランチャー
  config\
    software.json              # ソフト定義・ファイル名規格
    gui_settings.json          # GUI 選択状態の自動保存先（git 管理外）
  logs\                        # 実行ログ出力先（git 管理外）
  shortcut\
resource\                      # ローカルインストーラー配置先（git 管理外・自動作成）
  7z*-x64.exe
  Godot_v*-stable_win64.exe
  node-v*-x64.msi
  Git-*-64-bit.exe
  SourcetreeEnterpriseSetup_*.msi
  VSCodeUserSetup-x64-*.exe
```

## ローカルインストーラーの配置ルール

選択した未導入ソフトがローカルインストーラーを必要とする場合のみ、対応するファイルを `resource\` フォルダへ配置してください：

- `resource\7z*-x64.exe`
- `resource\Godot_v*-stable_win64.exe`
- `resource\node-v*-x64.msi`
- `resource\Git-*-64-bit.exe`
- `resource\SourcetreeEnterpriseSetup_*.msi`
- `resource\VSCodeUserSetup-x64-*.exe`

Godot はインストーラーとして実行せず、単体実行ファイルとしてコピーします。既定の配置先は次の通りです（配置された実ファイル名でコピーされます）：

```text
C:\Tools\Godot\Godot_v*-stable_win64.exe
```

配置ルートを変える場合は、GUI の「Godot 配置ルート (`-InstallRoot`)」または CLI の `-InstallRoot` 引数で指定してください。

## CLI からの実行（PowerShell）

### DryRun（テスト確認）

実際のインストール、Godot コピー、ExecutionPolicy 変更、npm install、アプリ・Chrome タブ起動を行わず、予定だけ確認します。GUI の「DryRunで確認」ボタンでも同じ確認ができます。

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\app\install_all.ps1 -DryRun
```

### 通常実行 / 管理者実行

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\app\install_all.ps1
```

互換性のため `-Force` も受け付けますが、インストール済みソフトは引き続きスキップし、アンインストールや削除は行いません：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\app\install_all.ps1 -Force
```

管理者権限が必要なソフトが選択されている場合、`install_all.ps1` は自動的に管理者権限で再実行します（`-DryRun` やユーザー権限のみで完結する選択時は昇格しません。昇格を抑止する場合は `-NoElevate` を指定できます）。

### 主な CLI オプション

- `-SoftwareIds "7zip,godot,antigravity,unity,steam,chatgpt"`（カンマ区切りで導入対象を指定、`NONE` で導入なし）
- `-LaunchAppIds "godot,vscode,chatgpt"`（セットアップ後に起動するアプリを指定、`NONE` で起動なし）
- `-BrowserTabIds "github,teams,discord"`（Chrome で開くタブを指定、`NONE` で開かない）
- `-ChatGPTMode Desktop | Web | None`（ChatGPT の導入・起動方式）
- `-InstallRoot "C:\Tools"`（Godot の配置ルート）
- `-SkipAppLaunches` / `-SkipChromeTabs` / `-DryRun` / `-NoElevate`

PowerShell の実行ポリシーは、Node.js または Codex CLI が対象に含まれる場合に未設定のときのみ `CurrentUser` を `RemoteSigned` に設定します。

## ログ確認

メインログ:

```text
app\logs\install.log
```

個別ログ:

```text
app\logs\node-install.log
app\logs\git-install.log
app\logs\sourcetree-install.log
app\logs\vscode-install.log
app\logs\codex-install.log
```

## 初回認証

- **ChatGPT デスクトップ版**: 起動したアプリ上で手動ログインしてください（公式案内: [OpenAI の Windows アプリ案内](https://help.openai.com/en/articles/9982051-using-the-chatgpt-windows-app)）。
- **OpenAI Codex CLI**: セットアップ後、手動で以下を実行し ChatGPT アカウントまたは API キーで認証してください。
  ```powershell
  codex
  ```
- **Sourcetree**: インストール後に手動で起動し、初回登録・アカウント設定を行ってください。
