# 02. ローカルファイルとパス要件

## 前提フォルダ

ユーザーは任意のフォルダに一式を置く。
PowerShell側では、`install_all.ps1` が存在するフォルダを基準ディレクトリとして扱う。

例：

```text
C:\InstallKit\
├─ install_all.ps1
├─ RUN_AS_ADMIN.bat
├─ config\software.json
├─ 7z2501-x64.exe
├─ Godot_v4.6.2-stable_win64.exe
├─ node-v24.15.0-x64.msi
├─ SourcetreeEnterpriseSetup_3.4.30.msi
└─ VSCodeUserSetup-x64-1.119.0.exe
```

## 必須インストーラーファイル

PowerShellスクリプトは、実行開始時に次のファイルが存在するか確認すること。

```text
7z2501-x64.exe
Godot_v4.6.2-stable_win64.exe
node-v24.15.0-x64.msi
SourcetreeEnterpriseSetup_3.4.30.msi
VSCodeUserSetup-x64-1.119.0.exe
```

## 配置先

既定の配置先は以下。

```text
logs\
config\software.json
C:\Tools\Godot\Godot_v4.6.2-stable_win64.exe
```

## Godotの扱い

`Godot_v4.6.2-stable_win64.exe` は単体実行ファイルとして扱う。
インストーラーとして起動するのではなく、既定では次へコピーする。

```text
C:\Tools\Godot\Godot_v4.6.2-stable_win64.exe
```

必要なら、`config/software.json` の設定でGodot配置先を変更できるようにする。

## ログ保存先

実行時に以下を自動作成する。

```text
logs\install.log
logs\7zip-install.log
logs\node-install.log
logs\sourcetree-install.log
logs\vscode-install.log
logs\codex-install.log
```

個別ログが不要な処理でも、`logs/install.log` には必ず記録すること。
