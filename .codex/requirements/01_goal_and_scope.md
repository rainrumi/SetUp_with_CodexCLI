# 01. 目的とスコープ

## 目的

ローカルに既にダウンロード済みのインストーラーを使い、Windows PCへ以下のソフトウェアを一括セットアップするPowerShellツールを作成する。

対象：

- 7-Zip
- Godot
- Node.js v24系
- Sourcetree Enterprise 3.4.30 MSI
- Visual Studio Code
- OpenAI Codex CLI
- PowerShell実行ポリシー設定

## 非目的

以下は今回作らない。

- 任意URLからEXE/MSIを自動収集するダウンローダー
- ブラウザやGUI画面を自動クリックして規約同意する仕組み
- 未知のEXEを自動実行する汎用ランチャー
- ユーザーのOpenAI / Atlassian / Microsoft / GitHubアカウントへの自動ログイン
- Codex CLIの初回認証自動化

## 実行環境

- OS: Windows 10 / Windows 11
- Shell: Windows PowerShell 5.1以上
- 文字コード: UTF-8
- 管理者権限: MSI/EXEインストールで必要になるため、スクリプト内で検出して昇格再実行する

## 基本方針

- 同じフォルダに置かれたインストーラーを使う。
- 既にインストール済みならスキップする。
- すべての処理をログへ記録する。
- 失敗時は停止し、原因をログに残す。
- `-DryRun` オプションで実行予定だけ確認できるようにする。
- Codex CLIだけはNode.js導入後にnpmで取得する。
