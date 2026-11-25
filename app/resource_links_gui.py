#!/usr/bin/env python3
"""不足している resource インストーラーの公式ダウンロードリンク集 GUI。"""

from __future__ import annotations

import json
import os
import re
import sys
import tkinter as tk
from pathlib import Path
from tkinter import messagebox, ttk
import webbrowser

APP_DIR = Path(__file__).resolve().parent
BASE_DIR = APP_DIR.parent
CONFIG_PATH = APP_DIR / "config" / "software.json"
SETTINGS_PATH = APP_DIR / "config" / "gui_settings.json"
RESOURCE_DIR = BASE_DIR / "resource"


def load_config() -> dict:
    with CONFIG_PATH.open("r", encoding="utf-8") as fh:
        return json.load(fh)


def load_saved_software_selection(config: dict | None = None) -> dict[str, bool]:
    if config is None:
        config = load_config()
    selection = {
        item["id"]: bool(item.get("defaultSelected", False))
        for item in config.get("software", [])
    }
    if not SETTINGS_PATH.is_file():
        return selection
    try:
        with SETTINGS_PATH.open("r", encoding="utf-8") as fh:
            saved = json.load(fh)
        saved_sw = saved.get("software") if isinstance(saved, dict) else None
        if isinstance(saved_sw, dict):
            for item_id in list(selection.keys()):
                if item_id in saved_sw and isinstance(saved_sw[item_id], bool):
                    selection[item_id] = saved_sw[item_id]
    except Exception:
        pass
    return selection


def _natural_sort_key(text: str) -> str:
    return re.sub(r"\d+", lambda m: m.group(0).zfill(10), text.lower())


def find_resource_file(item: dict) -> Path | None:
    if not RESOURCE_DIR.is_dir():
        return None

    candidates: list[str] = []
    file_name = (item.get("fileName") or "").strip()
    if file_name:
        candidates.append(file_name)
    for alt in item.get("alternateFileNames") or []:
        if alt and alt.strip():
            candidates.append(alt.strip())

    for name in candidates:
        candidate = RESOURCE_DIR / name
        if candidate.is_file():
            return candidate

    pattern = (item.get("filePattern") or "").strip()
    if pattern:
        matched = [p for p in RESOURCE_DIR.glob(pattern) if p.is_file()]
        if matched:
            matched.sort(
                key=lambda p: (_natural_sort_key(p.name), p.stat().st_mtime),
                reverse=True,
            )
            return matched[0]

    return None


def get_missing_required_items(config: dict | None = None) -> list[dict]:
    if config is None:
        config = load_config()
    missing: list[dict] = []
    for item in config.get("software", []):
        if not item.get("resourceRequired"):
            continue
        if find_resource_file(item) is None:
            missing.append(item)
    return missing


class ResourceLinksWindow(tk.Tk):
    def __init__(self) -> None:
        super().__init__()
        self.title("不足ファイル・公式ダウンロードリンク集")
        self.geometry("920x640")
        self.minsize(780, 500)

        self.config_data = load_config()
        self.row_widgets: list[dict] = []

        self._configure_style()
        self._build_ui()
        self.refresh_status()

    def _configure_style(self) -> None:
        style = ttk.Style(self)
        if "vista" in style.theme_names():
            style.theme_use("vista")
        elif "clam" in style.theme_names():
            style.theme_use("clam")

        style.configure("Header.TLabel", font=("Yu Gothic UI", 13, "bold"))
        style.configure("SubHeader.TLabel", font=("Yu Gothic UI", 9))
        style.configure("Section.TLabel", font=("Yu Gothic UI", 10, "bold"))
        style.configure("Missing.TLabel", foreground="#b91c1c", font=("Yu Gothic UI", 9, "bold"))
        style.configure("Present.TLabel", foreground="#15803d", font=("Yu Gothic UI", 9, "bold"))
        style.configure("Optional.TLabel", foreground="#1d4ed8", font=("Yu Gothic UI", 9, "bold"))
        style.configure("Dimmed.TLabel", foreground="#b3b3b3", font=("Yu Gothic UI", 9))
        style.configure("Dimmed.TButton", foreground="#b3b3b3")

    def _build_ui(self) -> None:
        root_frame = ttk.Frame(self, padding=14)
        root_frame.pack(fill=tk.BOTH, expand=True)

        # Header
        header_frame = ttk.Frame(root_frame)
        header_frame.pack(fill=tk.X, pady=(0, 6))

        ttk.Label(
            header_frame,
            text="resource フォルダ用 インストーラー ダウンロードリンク集",
            style="Header.TLabel",
        ).pack(anchor=tk.W)

        desc = (
            "exe / msi ファイルは GitHub 規約・配布ライセンスの都合上リポジトリに含めていません。\n"
            "下記の公式ページからインストーラーをダウンロードし、resource フォルダに配置してください。"
        )
        ttk.Label(header_frame, text=desc, style="SubHeader.TLabel", justify=tk.LEFT).pack(
            anchor=tk.W, pady=(4, 0)
        )

        # Top status + right-aligned action buttons above the local installer section
        top_bar = ttk.Frame(root_frame)
        top_bar.pack(fill=tk.X, pady=(4, 6))

        self.summary_var = tk.StringVar(value="")
        self.summary_label = ttk.Label(top_bar, textvariable=self.summary_var)
        self.summary_label.pack(side=tk.LEFT, anchor=tk.W)

        ttk.Button(
            top_bar,
            text="未配置のリンクを開く",
            command=self.open_all_missing_links,
        ).pack(side=tk.RIGHT)

        ttk.Button(
            top_bar,
            text="再チェック",
            command=self.refresh_status,
        ).pack(side=tk.RIGHT, padx=(0, 8))

        # Scrollable container
        canvas_container = ttk.Frame(root_frame)
        canvas_container.pack(fill=tk.BOTH, expand=True)

        self.canvas = tk.Canvas(canvas_container, highlightthickness=0)
        scrollbar = ttk.Scrollbar(canvas_container, orient=tk.VERTICAL, command=self.canvas.yview)
        self.scrollable_frame = ttk.Frame(self.canvas, padding=(2, 4))

        self.scrollable_frame.bind(
            "<Configure>",
            lambda _e: self.canvas.configure(scrollregion=self.canvas.bbox("all")),
        )
        self.canvas_window = self.canvas.create_window(
            (0, 0), window=self.scrollable_frame, anchor=tk.NW
        )
        self.canvas.bind(
            "<Configure>",
            lambda e: self.canvas.itemconfigure(self.canvas_window, width=e.width),
        )
        self.canvas.configure(yscrollcommand=scrollbar.set)

        self.canvas.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)

        self.canvas.bind_all(
            "<MouseWheel>",
            lambda e: self.canvas.yview_scroll(int(-1 * (e.delta / 120)), "units"),
        )

        # Build sections
        required_items = [
            item for item in self.config_data.get("software", []) if item.get("resourceRequired")
        ]
        optional_items = [
            item
            for item in self.config_data.get("software", [])
            if not item.get("resourceRequired") and item.get("downloadUrl")
        ]

        self._build_section(
            "ローカルインストーラー（対象ソフトを選択して導入する場合に resource フォルダへ配置）",
            required_items,
            is_required=True,
        )
        self._build_section(
            "任意 / 自動取得対応ソフト（winget・npm・Store から自動導入可能 / 手動DLリンク）",
            optional_items,
            is_required=False,
        )

        # Bottom toolbar (folder button stays bottom-left, close stays bottom-right)
        btn_frame = ttk.Frame(root_frame)
        btn_frame.pack(fill=tk.X, pady=(12, 0))

        ttk.Button(
            btn_frame,
            text="resource フォルダを開く",
            command=self.open_resource_folder,
        ).pack(side=tk.LEFT)

        ttk.Button(
            btn_frame,
            text="閉じる",
            command=self.destroy,
        ).pack(side=tk.RIGHT)

    def _build_section(self, title: str, items: list[dict], is_required: bool) -> None:
        section = ttk.LabelFrame(self.scrollable_frame, text=title, padding=10)
        section.pack(fill=tk.X, expand=True, pady=(0, 12))

        table = ttk.Frame(section)
        table.pack(fill=tk.X, expand=True)
        table.columnconfigure(0, weight=0, minsize=105)
        table.columnconfigure(1, weight=0, minsize=190)
        table.columnconfigure(2, weight=0, minsize=215)
        table.columnconfigure(3, weight=1, minsize=220)
        table.columnconfigure(4, weight=0, minsize=125)

        for col, text in enumerate(("状態", "ソフト名", "ファイル名", "備考", "ダウンロード")):
            ttk.Label(table, text=text, style="Section.TLabel").grid(
                row=0, column=col, sticky=tk.W, padx=6, pady=(0, 6)
            )

        ttk.Separator(table, orient=tk.HORIZONTAL).grid(
            row=1, column=0, columnspan=5, sticky=tk.EW, pady=(0, 6)
        )

        for idx, item in enumerate(items, start=2):
            status_var = tk.StringVar(value="")
            status_lbl = ttk.Label(table, textvariable=status_var)
            status_lbl.grid(row=idx, column=0, sticky=tk.W, padx=6, pady=4)

            name_lbl = ttk.Label(table, text=item.get("name", item["id"]))
            name_lbl.grid(row=idx, column=1, sticky=tk.W, padx=6, pady=4)

            file_pattern = (item.get("filePattern") or item.get("fileName") or "-").strip()
            file_lbl = ttk.Label(table, text=file_pattern)
            file_lbl.grid(row=idx, column=2, sticky=tk.W, padx=6, pady=4)

            notes_lbl = ttk.Label(
                table,
                text=(item.get("notes") or "-"),
                wraplength=250,
                justify=tk.LEFT,
            )
            notes_lbl.grid(row=idx, column=3, sticky=tk.W, padx=6, pady=4)

            url = item.get("downloadUrl") or ""
            btn = ttk.Button(
                table,
                text="公式ページを開く",
                command=lambda u=url: self.open_url(u),
            )
            btn.grid(row=idx, column=4, sticky=tk.E, padx=6, pady=4)

            self.row_widgets.append(
                {
                    "item": item,
                    "is_required": is_required,
                    "status_var": status_var,
                    "status_lbl": status_lbl,
                    "name_lbl": name_lbl,
                    "file_lbl": file_lbl,
                    "notes_lbl": notes_lbl,
                    "open_btn": btn,
                }
            )

    def open_url(self, url: str) -> None:
        if not url or not url.startswith(("https://", "http://")):
            messagebox.showwarning("無効なURL", "http:// または https:// 以外のリンクは開けません。")
            return
        webbrowser.open(url)

    def open_resource_folder(self) -> None:
        RESOURCE_DIR.mkdir(parents=True, exist_ok=True)
        try:
            os.startfile(str(RESOURCE_DIR))
        except Exception as exc:
            messagebox.showerror("エラー", f"resource フォルダを開けませんでした:\n{exc}")

    def open_all_missing_links(self) -> None:
        selection = load_saved_software_selection(self.config_data)
        missing = [
            item
            for item in get_missing_required_items(self.config_data)
            if selection.get(item["id"], True)
        ]
        if not missing:
            messagebox.showinfo("完了", "選択中のソフトに必要なファイルはすべて resource フォルダに配置済みです。")
            return
        for item in missing:
            url = item.get("downloadUrl") or ""
            if url.startswith(("https://", "http://")):
                webbrowser.open(url)

    def refresh_status(self) -> None:
        selection = load_saved_software_selection(self.config_data)
        missing_selected = 0
        selected_required_total = 0

        for entry in self.row_widgets:
            item = entry["item"]
            is_required = entry["is_required"]
            is_selected = selection.get(item["id"], True)
            found = find_resource_file(item)

            if is_required:
                if is_selected:
                    selected_required_total += 1
                if found:
                    entry["status_var"].set("配置済")
                    status_style = "Present.TLabel"
                else:
                    if is_selected:
                        missing_selected += 1
                    entry["status_var"].set("未配置 (不足)")
                    status_style = "Missing.TLabel"
            else:
                if found:
                    entry["status_var"].set("ローカル有")
                    status_style = "Present.TLabel"
                else:
                    entry["status_var"].set("自動導入可")
                    status_style = "Optional.TLabel"

            if is_selected:
                entry["status_lbl"].configure(style=status_style)
                entry["name_lbl"].configure(style="TLabel")
                entry["file_lbl"].configure(style="TLabel")
                entry["notes_lbl"].configure(style="TLabel")
                entry["open_btn"].configure(style="TButton")
            else:
                entry["status_lbl"].configure(style="Dimmed.TLabel")
                entry["name_lbl"].configure(style="Dimmed.TLabel")
                entry["file_lbl"].configure(style="Dimmed.TLabel")
                entry["notes_lbl"].configure(style="Dimmed.TLabel")
                entry["open_btn"].configure(style="Dimmed.TButton")

        if missing_selected == 0:
            self.summary_var.set(
                f"選択中のローカル対象 ({selected_required_total} 件) はすべて配置済みです。"
            )
            self.summary_label.configure(style="Present.TLabel")
        else:
            self.summary_var.set(
                f"選択中のソフトで未配置のファイルが {missing_selected} 件あります。配置後に「再チェック」を押してください。"
            )
            self.summary_label.configure(style="Missing.TLabel")


def main() -> int:
    app = ResourceLinksWindow()
    app.mainloop()
    return 0


if __name__ == "__main__":
    sys.exit(main())
