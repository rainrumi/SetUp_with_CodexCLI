# 06. インストール済み判定要件

## 共通方針

既にインストール済みの場合は処理をスキップする。
判定は複数候補を見てよい。
検出に失敗しただけで即インストールするのではなく、コマンド存在確認や代表パス確認を組み合わせる。

## 7-Zip

以下のどちらかで判定する。

```text
C:\Program Files\7-Zip\7z.exe
C:\Program Files (x86)\7-Zip\7z.exe
```

存在すればインストール済み。

## Godot

既定では以下が存在すれば配置済み。

```text
C:\Tools\Godot\Godot_v4.6.2-stable_win64.exe
```

`-InstallRoot` が指定された場合はその配下を見る。

## Node.js

以下を確認する。

```powershell
Get-Command node.exe
Get-Command npm.cmd
node -v
npm -v
```

`node.exe` と `npm.cmd` が存在すればインストール済み扱い。
ただし、バージョンがv24系ではない場合は警告をログへ出す。
自動削除や強制置換はしない。

## Sourcetree Enterprise

以下の候補を確認する。

```text
C:\Program Files\Atlassian\Sourcetree\SourceTree.exe
C:\Program Files (x86)\Atlassian\Sourcetree\SourceTree.exe
C:\Program Files\SourceTree\SourceTree.exe
C:\Program Files (x86)\SourceTree\SourceTree.exe
%LOCALAPPDATA%\SourceTree\SourceTree.exe
```

MSI版はProgram Files配下に入る可能性を優先する。

## Visual Studio Code

以下の候補を確認する。

```text
%LOCALAPPDATA%\Programs\Microsoft VS Code\Code.exe
C:\Program Files\Microsoft VS Code\Code.exe
C:\Program Files (x86)\Microsoft VS Code\Code.exe
```

また、`Get-Command code.cmd` が見つかればインストール済み扱いにしてよい。

## Codex CLI

以下を確認する。

```powershell
Get-Command codex.cmd
Get-Command codex
codex --version
```

存在すればインストール済み。

## ExecutionPolicy

以下で確認する。

```powershell
Get-ExecutionPolicy -Scope CurrentUser
```

`RemoteSigned` なら設定済み扱い。
それ以外なら設定する。
