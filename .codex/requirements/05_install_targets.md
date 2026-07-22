# 05. インストール対象要件

## 7-Zip

- 入力ファイル: `7z2501-x64.exe`
- 未インストールならインストールする
- 標準検出パス: `C:\Program Files\7-Zip\7z.exe`
- サイレント引数: `/S`

## Godot

- 入力ファイル: `Godot_v4.6.2-stable_win64.exe`
- インストールではなくコピー配置する
- 既定配置先: `C:\Tools\Godot\Godot_v4.6.2-stable_win64.exe`
- 既に配置済みならスキップする
- 必要ならショートカット作成は任意。ただし必須ではない

## Node.js

- 入力ファイル: `node-v24.15.0-x64.msi`
- `node.exe` と `npm.cmd` が利用可能なら原則スキップする
- Nodeが未導入ならMSIでインストールする
- インストール後に `node -v` と `npm -v` をログに出す
- 既に別バージョンのNodeがある場合は、勝手に削除・置換しない。ログで警告する

## Sourcetree Enterprise

- 入力ファイル: `SourcetreeEnterpriseSetup_3.4.30.msi`
- `SourceTree.exe` が存在すればスキップする
- MSIでサイレントインストールする
- EULA同意プロパティとして `ACCEPTEULA=1` を使う
- 初回起動時のAtlassian/Bitbucket登録やログインは自動化しない

## Visual Studio Code

- 入力ファイル: `VSCodeUserSetup-x64-1.119.0.exe`
- VS Codeがインストール済みならスキップする
- ユーザーインストーラーとして扱う
- 起動タスクは無効にする

## OpenAI Codex CLI

- Node.js/npm導入後に npm でインストールする
- 基本コマンド: `npm i -g @openai/codex`
- インストール後に `codex --version` を実行してログに残す
- 初回の `codex` 認証は自動化しない

## PowerShell ExecutionPolicy

- Scope: `CurrentUser`
- Policy: `RemoteSigned`
- 実行コマンド: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force`
