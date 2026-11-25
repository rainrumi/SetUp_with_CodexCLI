#!/usr/bin/env python3
"""Windows 一括セットアップキット メイン GUI (tkinter)。"""

from __future__ import annotations

import argparse
import json
import os
import queue
import shutil
import subprocess
import sys
import threading
import tkinter as tk
from pathlib import Path
from tkinter import filedialog, messagebox, scrolledtext, ttk

from resource_links_gui import (
    APP_DIR,
    BASE_DIR,
    RESOURCE_DIR,
    find_resource_file,
    get_missing_required_items,
    load_config,
)

INSTALL_SCRIPT = APP_DIR / "install_all.ps1"
LINKS_GUI_SCRIPT = APP_DIR / "resource_links_gui.py"
SETTINGS_PATH = APP_DIR / "config" / "gui_settings.json"


class SetupGuiApp(tk.Tk):
    def __init__(self, auto_open_links: bool = True) -> None:
        super().__init__()
        self.title("Windows 一括セットアップキット")
        self.geometry("1040x760")
        self.minsize(900, 640)

        self.config_data = load_config()
        self.software_items: list[dict] = self.config_data.get("software", [])
        self.browser_tabs: list[dict] = self.config_data.get("browserTabs", [])

        self.software_vars: dict[str, tk.BooleanVar] = {}
        self.software_status_labels: dict[str, tuple[tk.StringVar, ttk.Label]] = {}
        self.launch_vars: dict[str, tk.BooleanVar] = {}
        self.launch_warn_vars: dict[str, tk.StringVar] = {}
        self.tab_vars: dict[str, tk.BooleanVar] = {}
        self.chatgpt_mode_var = tk.StringVar(value="Desktop")
        self.install_root_var = tk.StringVar(value=r"C:\Tools")

        self.log_queue: queue.Queue[str] = queue.Queue()
        self.running_process: subprocess.Popen[str] | None = None
        self.is_running = False
        self.links_process: subprocess.Popen | None = None
        self._loading_settings = True

        RESOURCE_DIR.mkdir(parents=True, exist_ok=True)

        self._configure_style()
        self._build_ui()
        self._load_saved_settings()
        self._bind_setting_traces()
        self._loading_settings = False
        self.protocol("WM_DELETE_WINDOW", self._on_close)
        self.refresh_resource_status()
        self._poll_log_queue()

    def _configure_style(self) -> None:
        style = ttk.Style(self)
        if "vista" in style.theme_names():
            style.theme_use("vista")
        elif "clam" in style.theme_names():
            style.theme_use("clam")

        style.configure("Title.TLabel", font=("Yu Gothic UI", 14, "bold"))
        style.configure("Subtitle.TLabel", font=("Yu Gothic UI", 9))
        style.configure("BannerWarn.TLabel", foreground="#b91c1c", font=("Yu Gothic UI", 9, "bold"))
        style.configure("BannerOk.TLabel", foreground="#15803d", font=("Yu Gothic UI", 9, "bold"))
        style.configure("StatusMissing.TLabel", foreground="#b91c1c", font=("Yu Gothic UI", 8, "bold"))
        style.configure("StatusOk.TLabel", foreground="#15803d", font=("Yu Gothic UI", 8))
        style.configure("StatusAuto.TLabel", foreground="#1d4ed8", font=("Yu Gothic UI", 8))
        style.configure("StatusDimmed.TLabel", foreground="#b3b3b3", font=("Yu Gothic UI", 8))
        style.configure("Primary.TButton", font=("Yu Gothic UI", 10, "bold"), padding=(14, 7))

    def _build_ui(self) -> None:
        container = ttk.Frame(self, padding=14)
        container.pack(fill=tk.BOTH, expand=True)

        # Top header
        header = ttk.Frame(container)
        header.pack(fill=tk.X, pady=(0, 8))

        ttk.Label(header, text="Windows 一括セットアップキット", style="Title.TLabel").pack(
            side=tk.LEFT
        )
        ttk.Button(
            header,
            text="DLリンク集を開く",
            command=self.open_resource_links_gui,
        ).pack(side=tk.RIGHT, padx=(6, 0))
        ttk.Button(
            header,
            text="resource再チェック",
            command=self.refresh_resource_status,
        ).pack(side=tk.RIGHT)

        # Missing resource alert banner
        banner_frame = ttk.Frame(container)
        banner_frame.pack(fill=tk.X, pady=(0, 10))
        self.banner_var = tk.StringVar(value="")
        self.banner_label = ttk.Label(banner_frame, textvariable=self.banner_var)
        self.banner_label.pack(side=tk.LEFT, anchor=tk.W)

        # Middle split pane: Left = software to install, Right = windows to open + options
        middle = ttk.Frame(container)
        middle.pack(fill=tk.BOTH, expand=True)
        middle.columnconfigure(0, weight=3)
        middle.columnconfigure(1, weight=2)
        middle.rowconfigure(0, weight=1)

        self._build_software_panel(middle)
        self._build_windows_panel(middle)

        # Action bar
        action_frame = ttk.Frame(container)
        action_frame.pack(fill=tk.X, pady=(10, 8))

        self.start_button = ttk.Button(
            action_frame,
            text="セットアップを開始",
            style="Primary.TButton",
            command=lambda: self.start_setup(dry_run=False),
        )
        self.start_button.pack(side=tk.LEFT)

        self.dryrun_button = ttk.Button(
            action_frame,
            text="DryRunで確認",
            command=lambda: self.start_setup(dry_run=True),
        )
        self.dryrun_button.pack(side=tk.LEFT, padx=(8, 12))

        self.status_var = tk.StringVar(value="待機中")
        ttk.Label(action_frame, textvariable=self.status_var).pack(side=tk.RIGHT, padx=(8, 0))

        self.progress = ttk.Progressbar(action_frame, mode="indeterminate", length=140)
        self.progress.pack(side=tk.RIGHT)

        # Log output area
        log_frame = ttk.LabelFrame(container, text="実行ログ", padding=6)
        log_frame.pack(fill=tk.BOTH, expand=True)

        self.log_text = scrolledtext.ScrolledText(
            log_frame,
            height=11,
            font=("Consolas", 9),
            state=tk.DISABLED,
            wrap=tk.WORD,
        )
        self.log_text.pack(fill=tk.BOTH, expand=True)

    def _build_software_panel(self, parent: ttk.Frame) -> None:
        panel = ttk.LabelFrame(parent, text="ダウンロード / インストールするソフト", padding=10)
        panel.grid(row=0, column=0, sticky=tk.NSEW, padx=(0, 8))

        # Quick buttons
        btn_row = ttk.Frame(panel)
        btn_row.pack(fill=tk.X, pady=(0, 6))
        ttk.Button(btn_row, text="すべて選択", command=self.select_all_software).pack(
            side=tk.LEFT, padx=(0, 4)
        )
        ttk.Button(btn_row, text="すべて解除", command=self.deselect_all_software).pack(
            side=tk.LEFT, padx=(0, 4)
        )
        ttk.Button(btn_row, text="デフォルトに戻す", command=self.reset_defaults).pack(
            side=tk.LEFT
        )

        # Scrollable software list
        list_container = ttk.Frame(panel)
        list_container.pack(fill=tk.BOTH, expand=True)

        canvas = tk.Canvas(list_container, highlightthickness=0)
        scrollbar = ttk.Scrollbar(list_container, orient=tk.VERTICAL, command=canvas.yview)
        inner = ttk.Frame(canvas)
        inner.bind("<Configure>", lambda _e: canvas.configure(scrollregion=canvas.bbox("all")))
        win_id = canvas.create_window((0, 0), window=inner, anchor=tk.NW)
        canvas.bind("<Configure>", lambda e: canvas.itemconfigure(win_id, width=e.width))
        canvas.configure(yscrollcommand=scrollbar.set)

        canvas.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)

        self.chatgpt_radio_buttons: list[ttk.Radiobutton] = []

        for item in self.software_items:
            item_id = item["id"]
            var = tk.BooleanVar(value=bool(item.get("defaultSelected", False)))
            self.software_vars[item_id] = var

            row = ttk.Frame(inner)
            row.pack(fill=tk.X, pady=3)

            sub_text = (item.get("filePattern") or item.get("version") or "").strip()
            label_text = f"{item['name']}  ({sub_text})" if sub_text else item["name"]
            cb = ttk.Checkbutton(
                row,
                text=label_text,
                variable=var,
                command=self._on_chatgpt_toggle if item_id == "chatgpt" else None,
            )
            cb.pack(side=tk.LEFT, anchor=tk.W)

            status_var = tk.StringVar(value="")
            status_lbl = ttk.Label(row, textvariable=status_var)
            status_lbl.pack(side=tk.RIGHT, padx=(6, 4))
            self.software_status_labels[item_id] = (status_var, status_lbl)

            if item_id == "chatgpt":
                mode_frame = ttk.Frame(inner)
                mode_frame.pack(fill=tk.X, padx=(24, 4), pady=(0, 4))
                rb_desktop = ttk.Radiobutton(
                    mode_frame,
                    text="デスクトップ版をインストール (Microsoft Store)",
                    variable=self.chatgpt_mode_var,
                    value="Desktop",
                    command=self._update_chatgpt_hint,
                )
                rb_desktop.pack(anchor=tk.W)
                rb_web = ttk.Radiobutton(
                    mode_frame,
                    text="Web版をブラウザで開く (https://chatgpt.com/)",
                    variable=self.chatgpt_mode_var,
                    value="Web",
                    command=self._update_chatgpt_hint,
                )
                rb_web.pack(anchor=tk.W)
                self.chatgpt_radio_buttons = [rb_desktop, rb_web]

        self._on_chatgpt_toggle()

    def _build_windows_panel(self, parent: ttk.Frame) -> None:
        right_col = ttk.Frame(parent)
        right_col.grid(row=0, column=1, sticky=tk.NSEW)

        # App launch section
        app_panel = ttk.LabelFrame(right_col, text="セットアップ後に起動するアプリ", padding=10)
        app_panel.pack(fill=tk.X, pady=(0, 8))

        for item in self.software_items:
            if not item.get("canLaunch"):
                continue
            item_id = item["id"]
            var = tk.BooleanVar(value=bool(item.get("defaultLaunch", False)))
            self.launch_vars[item_id] = var

            row = ttk.Frame(app_panel)
            row.pack(fill=tk.X, pady=2)

            text = item["name"]
            if item_id == "chatgpt":
                text = "ChatGPT (デスクトップ版起動 / Web版はブラウザ)"
            ttk.Checkbutton(row, text=text, variable=var).pack(side=tk.LEFT, anchor=tk.W)

            warn_var = tk.StringVar(value="")
            self.launch_warn_vars[item_id] = warn_var
            ttk.Label(row, textvariable=warn_var, style="StatusMissing.TLabel").pack(
                side=tk.LEFT, padx=(6, 0)
            )

        # Browser tabs section
        browser_panel = ttk.LabelFrame(right_col, text="ブラウザ (Chrome) で展開するタブ", padding=10)
        browser_panel.pack(fill=tk.X, pady=(0, 8))

        for tab in self.browser_tabs:
            tab_id = tab["id"]
            var = tk.BooleanVar(value=bool(tab.get("defaultSelected", False)))
            self.tab_vars[tab_id] = var
            ttk.Checkbutton(
                browser_panel,
                text=f"{tab['name']}  ({tab['url']})",
                variable=var,
            ).pack(anchor=tk.W, pady=2)

        self.chatgpt_web_hint_var = tk.StringVar(value="")
        ttk.Label(
            browser_panel,
            textvariable=self.chatgpt_web_hint_var,
            style="Subtitle.TLabel",
            foreground="#1d4ed8",
        ).pack(anchor=tk.W, pady=(4, 0))
        self._update_chatgpt_hint()

        # Install root setting
        path_panel = ttk.LabelFrame(right_col, text="Godot 配置ルート (-InstallRoot)", padding=10)
        path_panel.pack(fill=tk.X)

        path_row = ttk.Frame(path_panel)
        path_row.pack(fill=tk.X)
        ttk.Entry(path_row, textvariable=self.install_root_var).pack(
            side=tk.LEFT, fill=tk.X, expand=True, padx=(0, 6)
        )
        ttk.Button(path_row, text="参照", command=self.browse_install_root).pack(side=tk.RIGHT)

    def _on_chatgpt_toggle(self) -> None:
        enabled = self.software_vars.get("chatgpt") and self.software_vars["chatgpt"].get()
        state = tk.NORMAL if enabled else tk.DISABLED
        for rb in self.chatgpt_radio_buttons:
            rb.configure(state=state)
        self._update_chatgpt_hint()

    def _update_chatgpt_hint(self) -> None:
        if not hasattr(self, "chatgpt_web_hint_var"):
            return
        chatgpt_on = self.software_vars.get("chatgpt") and self.software_vars["chatgpt"].get()
        if chatgpt_on and self.chatgpt_mode_var.get() == "Web":
            self.chatgpt_web_hint_var.set("※ ChatGPT Web版 (https://chatgpt.com/) も同時に開きます")
        else:
            self.chatgpt_web_hint_var.set("")

    def select_all_software(self) -> None:
        for var in self.software_vars.values():
            var.set(True)
        self._on_chatgpt_toggle()

    def deselect_all_software(self) -> None:
        for var in self.software_vars.values():
            var.set(False)
        self._on_chatgpt_toggle()

    def reset_defaults(self) -> None:
        for item in self.software_items:
            self.software_vars[item["id"]].set(bool(item.get("defaultSelected", False)))
            if item["id"] in self.launch_vars:
                self.launch_vars[item["id"]].set(bool(item.get("defaultLaunch", False)))
        for tab in self.browser_tabs:
            self.tab_vars[tab["id"]].set(bool(tab.get("defaultSelected", False)))
        self.chatgpt_mode_var.set("Desktop")
        self.install_root_var.set(r"C:\Tools")
        self._on_chatgpt_toggle()

    def browse_install_root(self) -> None:
        selected = filedialog.askdirectory(initialdir=self.install_root_var.get() or "C:\\")
        if selected:
            self.install_root_var.set(selected)

    def _load_saved_settings(self) -> None:
        if not SETTINGS_PATH.is_file():
            return
        try:
            with SETTINGS_PATH.open("r", encoding="utf-8") as fh:
                saved = json.load(fh)
        except Exception:
            return
        if not isinstance(saved, dict):
            return

        saved_software = saved.get("software")
        if isinstance(saved_software, dict):
            for item_id, var in self.software_vars.items():
                if item_id in saved_software and isinstance(saved_software[item_id], bool):
                    var.set(saved_software[item_id])

        saved_launch = saved.get("launch")
        if isinstance(saved_launch, dict):
            for app_id, var in self.launch_vars.items():
                if app_id in saved_launch and isinstance(saved_launch[app_id], bool):
                    var.set(saved_launch[app_id])

        saved_tabs = saved.get("browserTabs")
        if isinstance(saved_tabs, dict):
            for tab_id, var in self.tab_vars.items():
                if tab_id in saved_tabs and isinstance(saved_tabs[tab_id], bool):
                    var.set(saved_tabs[tab_id])

        saved_mode = saved.get("chatgptMode")
        if saved_mode in ("Desktop", "Web"):
            self.chatgpt_mode_var.set(saved_mode)

        saved_root = saved.get("installRoot")
        if isinstance(saved_root, str) and saved_root.strip():
            self.install_root_var.set(saved_root)

        self._on_chatgpt_toggle()

    def _save_settings(self, *_args: object) -> None:
        if self._loading_settings:
            return
        payload = {
            "software": {k: bool(v.get()) for k, v in self.software_vars.items()},
            "launch": {k: bool(v.get()) for k, v in self.launch_vars.items()},
            "browserTabs": {k: bool(v.get()) for k, v in self.tab_vars.items()},
            "chatgptMode": self.chatgpt_mode_var.get(),
            "installRoot": self.install_root_var.get(),
        }
        try:
            SETTINGS_PATH.parent.mkdir(parents=True, exist_ok=True)
            with SETTINGS_PATH.open("w", encoding="utf-8") as fh:
                json.dump(payload, fh, ensure_ascii=False, indent=2)
        except Exception:
            pass

    def _bind_setting_traces(self) -> None:
        for var in self.software_vars.values():
            var.trace_add("write", self._on_selection_changed)
        for var in self.launch_vars.values():
            var.trace_add("write", self._on_selection_changed)
        for var in self.tab_vars.values():
            var.trace_add("write", self._save_settings)
        self.chatgpt_mode_var.trace_add("write", self._save_settings)
        self.install_root_var.trace_add("write", self._on_selection_changed)

    def _on_selection_changed(self, *_args: object) -> None:
        self._save_settings()
        if not self._loading_settings:
            self.refresh_resource_status()

    def _on_close(self) -> None:
        self._save_settings()
        self.destroy()

    def is_software_installed(self, item: dict, install_root: str) -> bool:
        item_id = item.get("id")
        detect_paths = item.get("detectPaths") or []

        def _any_path_exists(paths: list[str]) -> bool:
            for raw in paths:
                expanded = os.path.expandvars(raw)
                if os.path.exists(expanded):
                    return True
            return False

        if item_id == "godot":
            godot_dir = Path(install_root) / "Godot"
            if godot_dir.is_dir() and any(
                p.is_file() for p in godot_dir.glob("Godot_v*_win64.exe")
            ):
                return True
            rel = item.get("destinationRelativePath")
            if rel and (Path(install_root) / rel).exists():
                return True
            return _any_path_exists(detect_paths)

        if item_id == "node":
            return bool(shutil.which("node.exe") and shutil.which("npm.cmd"))

        if item_id == "git":
            return _any_path_exists(detect_paths) or bool(shutil.which("git.exe"))

        if item_id == "vscode":
            return _any_path_exists(detect_paths) or bool(shutil.which("code.cmd"))

        return _any_path_exists(detect_paths)

    def get_missing_needed_items(self, selected_software: list[str], install_root: str) -> list[dict]:
        missing: list[dict] = []
        for item in self.software_items:
            if item["id"] not in selected_software:
                continue
            if not item.get("resourceRequired"):
                continue
            if self.is_software_installed(item, install_root):
                continue
            if find_resource_file(item) is None:
                missing.append(item)
        return missing

    def refresh_resource_status(self) -> None:
        install_root = self.install_root_var.get().strip() or r"C:\Tools"
        selected_software = [
            item["id"]
            for item in self.software_items
            if self.software_vars[item["id"]].get()
        ]

        for item in self.software_items:
            item_id = item["id"]
            status_var, status_lbl = self.software_status_labels[item_id]
            found = find_resource_file(item)
            is_selected = item_id in selected_software

            if item.get("resourceRequired"):
                if found:
                    status_var.set("resource配置済")
                    style_name = "StatusOk.TLabel"
                elif self.is_software_installed(item, install_root):
                    status_var.set("導入済 (不要)")
                    style_name = "StatusOk.TLabel"
                else:
                    status_var.set("resource未配置")
                    style_name = "StatusMissing.TLabel"
            elif item.get("installMethod") == "winget_or_local":
                if found:
                    status_var.set("ローカル優先")
                    style_name = "StatusOk.TLabel"
                else:
                    status_var.set("winget自動取得")
                    style_name = "StatusAuto.TLabel"
            elif item.get("installMethod") == "npm":
                status_var.set("npm自動取得")
                style_name = "StatusAuto.TLabel"
            elif item.get("installMethod") == "msstore":
                status_var.set("Store / Web")
                style_name = "StatusAuto.TLabel"
            else:
                style_name = "StatusAuto.TLabel"

            status_lbl.configure(style=style_name if is_selected else "StatusDimmed.TLabel")

        missing_needed = self.get_missing_needed_items(selected_software, install_root)
        if missing_needed:
            self.banner_var.set(
                f"⚠ 選択中の未導入ソフトに必要な resource ファイルが {len(missing_needed)} 件不足しています（開始時に案内されます）。"
            )
            self.banner_label.configure(style="BannerWarn.TLabel")
        else:
            self.banner_var.set("✓ 選択中のソフトに必要な resource ファイルは揃っています。")
            self.banner_label.configure(style="BannerOk.TLabel")

        for item in self.software_items:
            item_id = item["id"]
            if item_id not in self.launch_warn_vars:
                continue
            launch_on = self.launch_vars[item_id].get()
            download_on = item_id in selected_software
            already_installed = self.is_software_installed(item, install_root)
            if launch_on and not download_on and not already_installed:
                self.launch_warn_vars[item_id].set("※ダウンロードされないため起動されません")
            else:
                self.launch_warn_vars[item_id].set("")

    def _prompt_open_resource_links_gui(self, missing_items: list[dict]) -> bool:
        if not missing_items:
            return False
        bullets = "\n".join(
            f"・{it['name']} : {it.get('filePattern') or it.get('fileName', '')}"
            for it in missing_items
        )
        open_links = messagebox.askyesno(
            "不足ファイルの確認",
            "resource フォルダ内に必要なファイルが存在しません。\n\n"
            "【ダウンロードが必要なファイル】\n"
            f"{bullets}\n\n"
            "ダウンロードリンク集を開きますか？",
            parent=self,
        )
        if open_links:
            self.open_resource_links_gui()
        return open_links

    def open_resource_links_gui(self) -> None:
        self._save_settings()
        if self.links_process is not None and self.links_process.poll() is None:
            return
        try:
            self.links_process = subprocess.Popen(
                [sys.executable, str(LINKS_GUI_SCRIPT)],
                cwd=str(BASE_DIR),
            )
        except Exception as exc:
            messagebox.showerror("エラー", f"ダウンロードリンク集 GUI を起動できませんでした:\n{exc}")

    def _append_log(self, text: str) -> None:
        self.log_text.configure(state=tk.NORMAL)
        self.log_text.insert(tk.END, text)
        self.log_text.see(tk.END)
        self.log_text.configure(state=tk.DISABLED)

    def _poll_log_queue(self) -> None:
        try:
            while True:
                line = self.log_queue.get_nowait()
                self._append_log(line)
        except queue.Empty:
            pass
        self.after(100, self._poll_log_queue)

    def _set_running_state(self, running: bool, status_text: str) -> None:
        self.is_running = running
        state = tk.DISABLED if running else tk.NORMAL
        self.start_button.configure(state=state)
        self.dryrun_button.configure(state=state)
        self.status_var.set(status_text)
        if running:
            self.progress.start(12)
        else:
            self.progress.stop()

    def start_setup(self, dry_run: bool = False) -> None:
        if self.is_running:
            return

        if not INSTALL_SCRIPT.is_file():
            messagebox.showerror("エラー", f"install_all.ps1 が見つかりません:\n{INSTALL_SCRIPT}")
            return

        selected_software = [
            item["id"]
            for item in self.software_items
            if self.software_vars[item["id"]].get()
        ]
        selected_launch = [
            app_id for app_id, var in self.launch_vars.items() if var.get()
        ]
        selected_tabs = [
            tab_id for tab_id, var in self.tab_vars.items() if var.get()
        ]

        chatgpt_mode = self.chatgpt_mode_var.get() if "chatgpt" in selected_software else "None"

        if not selected_software and not selected_launch and not selected_tabs:
            messagebox.showwarning(
                "選択なし", "インストールするソフトまたは展開するウィンドウを1つ以上選択してください。"
            )
            return

        install_root = self.install_root_var.get().strip() or r"C:\Tools"
        RESOURCE_DIR.mkdir(parents=True, exist_ok=True)

        # Check resource files only for selected software that will actually use them
        missing_needed = self.get_missing_needed_items(selected_software, install_root)
        if missing_needed:
            self._prompt_open_resource_links_gui(missing_needed)
            return

        software_arg = ",".join(selected_software) if selected_software else "NONE"
        launch_arg = ",".join(selected_launch) if selected_launch else "NONE"
        tabs_arg = ",".join(selected_tabs) if selected_tabs else "NONE"

        cmd = [
            "powershell.exe",
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-File",
            str(INSTALL_SCRIPT),
            "-SoftwareIds",
            software_arg,
            "-LaunchAppIds",
            launch_arg,
            "-BrowserTabIds",
            tabs_arg,
            "-ChatGPTMode",
            chatgpt_mode,
            "-InstallRoot",
            install_root,
        ]
        if dry_run:
            cmd.append("-DryRun")

        self.log_text.configure(state=tk.NORMAL)
        self.log_text.delete("1.0", tk.END)
        self.log_text.configure(state=tk.DISABLED)

        mode_label = "DryRun実行中..." if dry_run else "セットアップ実行中..."
        self._set_running_state(True, mode_label)
        self.log_queue.put(f"> {' '.join(cmd)}\n\n")

        thread = threading.Thread(target=self._run_powershell_worker, args=(cmd, dry_run), daemon=True)
        thread.start()

    def _run_powershell_worker(self, cmd: list[str], dry_run: bool) -> None:
        exit_code = -1
        try:
            creation_flags = getattr(subprocess, "CREATE_NO_WINDOW", 0)
            env = os.environ.copy()
            self.running_process = subprocess.Popen(
                cmd,
                cwd=str(BASE_DIR),
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                encoding="utf-8",
                errors="replace",
                creationflags=creation_flags,
                env=env,
            )
            assert self.running_process.stdout is not None
            for line in self.running_process.stdout:
                self.log_queue.put(line)
            exit_code = self.running_process.wait()
        except Exception as exc:
            self.log_queue.put(f"\n[GUI ERROR] {exc}\n")
        finally:
            self.running_process = None
            self.after(0, self._on_setup_finished, exit_code, dry_run)

    def _on_setup_finished(self, exit_code: int, dry_run: bool) -> None:
        if exit_code == 0:
            label = "DryRun完了" if dry_run else "セットアップ完了"
            self._set_running_state(False, label)
            self.log_queue.put(f"\n=== {label} (ExitCode=0) ===\n")
        else:
            self._set_running_state(False, f"エラー終了 (ExitCode={exit_code})")
            self.log_queue.put(f"\n=== エラー終了 (ExitCode={exit_code}) ===\n")
            messagebox.showerror(
                "セットアップエラー",
                f"処理がエラーで終了しました (ExitCode={exit_code})。\nログ欄または app\\logs\\install.log を確認してください。",
            )


def main() -> int:
    parser = argparse.ArgumentParser(description="Windows 一括セットアップキット GUI")
    parser.add_argument(
        "--no-auto-links",
        action="store_true",
        help="起動時に不足ファイルがあってもダウンロードリンク集GUIを自動で開かない",
    )
    args = parser.parse_args()

    app = SetupGuiApp(auto_open_links=not args.no_auto_links)
    app.mainloop()
    return 0


if __name__ == "__main__":
    sys.exit(main())
