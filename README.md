Use at your own risk.

This tool was created for personal use, so it may include breaking or destructive changes without notice.

## How to Use

1. Run the code written in `これをパワーシェルで実行.txt` from the `Codex_setup\` directory using PowerShell.
2. When prompted about security permissions, allow the execution.
3. Have some tea while you wait for the environment setup to finish.
4. Done.

## Software That Will Be Installed or Opened

- CodexCLI
- Node.js
- VSCode
- Sourcetree
- Git
- Godot
- 7zip
- Several web pages: ChatGPT, GitHub, Microsoft Teams, Discord

## What It Does

When you run the command written in `これをパワーシェルで実行.txt` in PowerShell, `install_all.ps1` starts the full setup process.

The `-NoProfile` option prevents PowerShell from loading any user-specific PowerShell settings.  
The `-ExecutionPolicy Bypass` option bypasses script execution restrictions only for this run.  
The `-File .\install_all.ps1` option runs the main setup script, and the `-Force` option allows the process to continue while skipping confirmation prompts.

The script relaunches itself with administrator privileges when necessary, then checks the installation status of each application based on the configuration files.

Software that is not yet installed will be installed or placed in the appropriate location.  
Software that already exists will be skipped.

After the process is complete, the results are written to a log file. The script then opens applications such as Godot, VSCode, and Sourcetree, as well as related web pages.

The applications are launched as independent processes that do not depend on the terminal, so their windows will remain open even if PowerShell is closed.


/*******************************************************************************************************************************/

使用は自己責任です。
個人用に作成したものなので破壊的な改変をすることがあります。

～使用方法～
1,これをパワーシェルで実行.txtに書かれたコードをCodex_setup\で実行。
2,セキュリティについて聞かれるので許可する
3,環境構築完了を待つ間にお茶を飲む
4,完了

～展開されるソフト～
CodexCLI
Node.js
VSCode
Sourcetree
Git
Godot
7zip
いくつかのウェブページ（ChatGPT, Github, MicrosoftTeams, Discord）

～実行内容～
これをパワーシェルで実行.txt に記載されたコマンドをPowerShellで実行すると、install_all.ps1 が一括セットアップ処理を開始しま
  す。-NoProfile によりユーザー固有のPowerShell設定を読み込まず、-ExecutionPolicy Bypass によりこの実行時だけスクリプト実行制限
  を回避します。-File .\install_all.ps1 でセットアップ本体を実行し、-Force を付けて確認処理を省略しながら処理を進めます。

  スクリプトは必要に応じて管理者権限で再実行し、設定ファイルをもとに各ソフトの導入状況を確認します。未導入のソフトはインストー
  ルまたは配置し、既に存在するものはスキップします。処理後は結果をログに記録し、Godot、VSCode、Sourcetreeなどのアプリと、関連
  Webページを開きます。アプリはターミナルに依存しない独立プロセスとして起動されるため、PowerShellを閉じてもウィンドウは残りま
  す。
