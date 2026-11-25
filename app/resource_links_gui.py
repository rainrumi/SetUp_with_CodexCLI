#!/usr/bin/env python3
"""不足している resource インストーラーの公式ダウンロードリンク集 GUI。"""

from __future__ import annotations

import json
import os
import sys
import tkinter as tk
from pathlib import Path
from tkinter import messagebox, ttk
import webbrowser

APP_DIR = Path(__file__).resolve().parent
BASE_DIR = APP_DIR.parent
CONFIG_PATH = APP_DIR / "config" / "software.json"
RESOURCE_DIR = BASE_DIR / "resource"


def load_config() -> dict:
    with CONFIG_PATH.open("r", encoding="utf-8") as fh:
        return json.load(fh)


def find_resource_file(item: dict) -> Path | None:
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

    def _build_ui(self) -> None:
        root_frame = ttk.Frame(self, padding=14)
        root_frame.pack(fill=tk.BOTH, expand=True)

        # Header
        header_frame = ttk.Frame(root_frame)
        header_frame.pack(fill=tk.X, pady=(0, 10))

        ttk.Label(
            header_frame,
            text="resource フォルダ用 インストーラー ダウンロードリンク集",
            style="Header.TLabel",
        ).pack(anchor=tk.W)

        desc = (
            "exe / msi ファイルは GitHub 規約・配布ライセンスの都合上リポジトリに含めていません。\n"
            "下記の公式ページから必要なバージョンをダウンロードし、resource フォルダに配置してください。"
        )
        ttk.Label(header_frame, text=desc, style="SubHeader.TLabel", justify=tk.LEFT).pack(
            anchor=tk.W, pady=(4, 0)
        )

        self.summary_var = tk.StringVar(value="")
        self.summary_label = ttk.Label(header_frame, textvariable=self.summary_var)
        self.summary_label.pack(anchor=tk.W, pady=(6, 0))

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
            "必須ファイル（resource フォルダへの配置が必要）", required_items, is_required=True
        )
        self._build_section(
            "任意 / 自動取得対応ソフト（winget・npm・Store から自動導入可能 / 手動DLリンク）",
            optional_items,
            is_required=False,
        )

        # Bottom toolbar
        btn_frame = ttk.Frame(root_frame)
        btn_frame.pack(fill=tk.X, pady=(12, 0))

        ttk.Button(
            btn_frame,
            text="resource フォルダを開く",
            command=self.open_resource_folder,
        ).pack(side=tk.LEFT, padx=(0, 8))

        ttk.Button(
            btn_frame,
            text="未配置の必須リンクをすべて開く",
            command=self.open_all_missing_links,
        ).pack(side=tk.LEFT, padx=(0, 8))

        ttk.Button(
            btn_frame,
            text="再チェック",
            command=self.refresh_status,
        ).pack(side=tk.LEFT)

        ttk.Button(
            btn_frame,
            text="閉じる",
            command=self.destroy,
        ).pack(side=tk.RIGHT)

    def _build_section(self, title: str, items: list[dict], is_required: bool) -> None:
        section = ttk.LabelFrame(self.scrollable_frame, text=title, padding=10)
        section.pack(fill=tk.X, expand=True, pady=(0, 12))

        header = ttk.Frame(section)
        header.pack(fill=tk.X, pady=(0, 6))
        header.columnconfigure(0, weight=0, minsize=95)
        header.columnconfigure(1, weight=1, minsize=170)
        header.columnconfigure(2, weight=1, minsize=145)
        header.columnconfigure(3, weight=2, minsize=220)
        header.columnconfigure(4, weight=0, minsize=145)

        for col, text in enumerate(("状態", "ソフト名", "必要バージョン", "ファイル名 / 備考", "ダウンロード")):
            ttk.Label(header, text=text, style="Section.TLabel").grid(
                row=0, column=col, sticky=tk.W, padx=4
            )

        ttk.Separator(section, orient=tk.HORIZONTAL).pack(fill=tk.X, pady=(0, 4))

        for item in items:
            row_frame = ttk.Frame(section)
            row_frame.pack(fill=tk.X, pady=4)
            row_frame.columnconfigure(0, weight=0, minsize=95)
            row_frame.columnconfigure(1, weight=1, minsize=170)
            row_frame.columnconfigure(2, weight=1, minsize=145)
            row_frame.columnconfigure(3, weight=2, minsize=220)
            row_frame.columnconfigure(4, weight=0, minsize=145)

            status_var = tk.StringVar(value="")
            status_lbl = ttk.Label(row_frame, textvariable=status_var)
            status_lbl.grid(row=0, column=0, sticky=tk.W, padx=4)

            ttk.Label(row_frame, text=item.get("name", item["id"])).grid(
                row=0, column=1, sticky=tk.W, padx=4
            )

            ttk.Label(row_frame, text=item.get("version") or "-").grid(
                row=0, column=2, sticky=tk.W, padx=4
            )

            file_name = item.get("fileName") or ""
            notes = item.get("notes") or ""
            detail_text = f"{file_name}\n{notes}" if file_name else notes
            ttk.Label(row_frame, text=detail_text, wraplength=290, justify=tk.LEFT).grid(
                row=0, column=3, sticky=tk.W, padx=4
            )

            url = item.get("downloadUrl") or ""
            btn = ttk.Button(
                row_frame,
                text="公式ページを開く",
                command=lambda u=url: self.open_url(u),
            )
            btn.grid(row=0, column=4, sticky=tk.E, padx=4)

            self.row_widgets.append(
                {
                    "item": item,
                    "is_required": is_required,
                    "status_var": status_var,
                    "status_lbl": status_lbl,
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
        missing = get_missing_required_items(self.config_data)
        if not missing:
            messagebox.showinfo("完了", "必須ファイルはすべて resource フォルダに配置済みです。")
            return
        for item in missing:
            url = item.get("downloadUrl") or ""
            if url.startswith(("https://", "http://")):
                webbrowser.open(url)

    def refresh_status(self) -> None:
        missing_count = 0
        required_total = 0

        for entry in self.row_widgets:
            item = entry["item"]
            is_required = entry["is_required"]
            found = find_resource_file(item)

            if is_required:
                required_total += 1
                if found:
                    entry["status_var"].set("配置済")
                    entry["status_lbl"].configure(style="Present.TLabel")
                else:
                    missing_count += 1
                    entry["status_var"].set("未配置 (不足)")
                    entry["status_lbl"].configure(style="Missing.TLabel")
            else:
                if found:
                    entry["status_var"].set("ローカル有")
                    entry["status_lbl"].configure(style="Present.TLabel")
                else:
                    entry["status_var"].set("自動導入可")
                    entry["status_lbl"].configure(style="Optional.TLabel")

        if missing_count == 0:
            self.summary_var.set(
                f"必須ファイル ({required_total}/{required_total}) はすべて resource フォルダに配置されています。"
            )
            self.summary_label.configure(style="Present.TLabel")
        else:
            self.summary_var.set(
                f"未配置の必須ファイルが {missing_count} 件あります（全 {required_total} 件中）。配置後に「再チェック」を押してください。"
            )
            self.summary_label.configure(style="Missing.TLabel")


def main() -> int:
    app = ResourceLinksWindow()
    app.mainloop()
    return 0


if __name__ == "__main__":
    sys.exit(main())
