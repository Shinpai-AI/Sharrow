#!/usr/bin/env python3
"""
Rules-Creator – kleine GUI zum Pflegen der Rules-Master.txt
Autor: Hannes Kell / Shinpai-AI
"""

import os
import glob
import tkinter as tk
from tkinter import ttk, filedialog, messagebox
from datetime import datetime, timedelta


LOG_PATH = os.path.join(os.path.dirname(__file__), "Rules-Creator.log")


def log_message(text: str):
    try:
        with open(LOG_PATH, "a", encoding="utf-8") as log_file:
            log_file.write(text + "\n")
    except OSError:
        pass
    print(text)


class RulesCreatorApp(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("SharrowLOL Rules Creator")
        self.geometry("520x520")
        self.resizable(False, False)

        default_path = self._detect_default_path()
        self.rules_path_var = tk.StringVar(value=default_path)
        self.symbol_var = tk.StringVar()

        now = datetime.now()
        self.date_var = tk.StringVar(value=now.strftime("%Y-%m-%d"))
        self.hour_var = tk.StringVar(value=f"{now.hour:02d}")
        self.minute_var = tk.StringVar(value=f"{(now.minute // 5) * 5:02d}")

        self.rules_list = []

        self._build_layout()
        log_message("[Rules-Creator] Anwendung gestartet.")
        self._load_rules_if_possible()

    def _build_layout(self):
        padding = {"padx": 10, "pady": 5}

        tk.Label(self, text="Speicherort Rules-Master.txt").grid(row=0, column=0, sticky="w", **padding)
        path_frame = tk.Frame(self)
        path_frame.grid(row=1, column=0, columnspan=2, sticky="ew", **padding)
        path_entry = tk.Entry(path_frame, textvariable=self.rules_path_var, width=50)
        path_entry.pack(side=tk.LEFT, expand=True, fill=tk.X)
        tk.Button(path_frame, text="…", command=self._choose_file).pack(side=tk.LEFT, padx=5)

        ttk.Separator(self, orient="horizontal").grid(row=2, column=0, columnspan=2, sticky="ew", pady=5)

        form_frame = tk.LabelFrame(self, text="Neue Rule")
        form_frame.grid(row=3, column=0, columnspan=2, padx=10, pady=5, sticky="ew")

        tk.Label(form_frame, text="Symbol").grid(row=0, column=0, sticky="w", **padding)
        tk.Entry(form_frame, textvariable=self.symbol_var).grid(row=0, column=1, sticky="ew", **padding)

        tk.Label(form_frame, text="Datum (YYYY-MM-DD)").grid(row=1, column=0, sticky="w", **padding)
        tk.Entry(form_frame, textvariable=self.date_var).grid(row=1, column=1, sticky="ew", **padding)

        tk.Label(form_frame, text="Uhrzeit").grid(row=2, column=0, sticky="w", **padding)
        time_frame = tk.Frame(form_frame)
        time_frame.grid(row=2, column=1, sticky="w", **padding)
        hours = [f"{h:02d}" for h in range(24)]
        minutes = [f"{m:02d}" for m in range(0, 60, 5)]
        ttk.Combobox(time_frame, values=hours, textvariable=self.hour_var, width=5, state="readonly").pack(side=tk.LEFT)
        tk.Label(time_frame, text=":").pack(side=tk.LEFT)
        ttk.Combobox(time_frame, values=minutes, textvariable=self.minute_var, width=5, state="readonly").pack(side=tk.LEFT)

        tk.Button(form_frame, text="Rule hinzufügen", command=self._add_rule).grid(row=3, column=0, columnspan=2, pady=5)

        ttk.Separator(self, orient="horizontal").grid(row=4, column=0, columnspan=2, sticky="ew", pady=5)

        self.grid_rowconfigure(5, weight=1)
        list_frame = tk.LabelFrame(self, text="Aktuelle Rules")
        list_frame.grid(row=5, column=0, columnspan=2, padx=10, pady=5, sticky="nsew")

        self.rules_listbox = tk.Listbox(list_frame, height=10)
        self.rules_listbox.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        scrollbar = tk.Scrollbar(list_frame, orient="vertical", command=self.rules_listbox.yview)
        scrollbar.pack(side=tk.RIGHT, fill=tk.Y)
        self.rules_listbox.config(yscrollcommand=scrollbar.set)

        action_frame = tk.Frame(self)
        action_frame.grid(row=6, column=0, columnspan=2, pady=10)
        tk.Button(action_frame, text="Ausgewählte Rule löschen", command=self._remove_selected).pack(side=tk.LEFT, padx=10)
        tk.Button(action_frame, text="Speichern", command=self._save_rules, bg="#4caf50", fg="white").pack(side=tk.LEFT, padx=10)

    def _choose_file(self):
        path = filedialog.asksaveasfilename(
            defaultextension=".txt",
            filetypes=[("Textdatei", "*.txt"), ("Alle Dateien", "*.*")],
            initialfile="Rules-Master.txt",
            title="Rules-Master speichern unter"
        )
        if path:
            safe_path = os.path.abspath(os.path.expanduser(path))
            self.rules_path_var.set(safe_path)
            log_message(f"[Rules-Creator] Speicherpfad gewählt: {safe_path}")
            self._load_rules_if_possible()

    def _add_rule(self):
        symbol = self.symbol_var.get().strip().upper()
        date_str = self.date_var.get().strip()
        hour = self.hour_var.get()
        minute = self.minute_var.get()

        if not symbol:
            messagebox.showwarning("Fehler", "Bitte ein Symbol eingeben.")
            return

        try:
            dt = datetime.strptime(f"{date_str} {hour}:{minute}", "%Y-%m-%d %H:%M")
        except ValueError:
            messagebox.showwarning("Fehler", "Datum/Uhrzeit sind ungültig.")
            return

        rule = f"{symbol};{dt.strftime('%Y-%m-%d %H:%M')}"
        if rule in self.rules_list:
            messagebox.showinfo("Hinweis", "Diese Rule existiert bereits.")
            return

        self.rules_list.append(rule)
        self.rules_list.sort()
        self._refresh_listbox()

    def _remove_selected(self):
        selection = self.rules_listbox.curselection()
        if not selection:
            return
        idx = selection[0]
        rule = self.rules_listbox.get(idx)
        if rule in self.rules_list:
            self.rules_list.remove(rule)
            self._refresh_listbox()

    def _refresh_listbox(self):
        self.rules_listbox.delete(0, tk.END)
        for entry in sorted(self.rules_list):
            self.rules_listbox.insert(tk.END, entry)

    def _save_rules(self):
        path = os.path.abspath(os.path.expanduser(self.rules_path_var.get().strip()))
        if not path:
            messagebox.showwarning("Fehler", "Bitte einen Speicherort auswählen.")
            return
        if not self.rules_list:
            log_message("[Rules-Creator] Speichern abgebrochen: keine Einträge.")
            if not messagebox.askyesno("Bestätigung", "Keine Einträge vorhanden. Datei wirklich leeren?"):
                return

        try:
            directory = os.path.dirname(path)
            if directory and not os.path.isdir(directory):
                os.makedirs(directory, exist_ok=True)

            text = "\r\n".join(sorted(self.rules_list)) + ("\r\n" if self.rules_list else "")
            with open(path, "w", encoding="utf-8") as f:
                f.write(text)
            self.rules_path_var.set(path)
            if os.path.isfile(path):
                log_message(f"[Rules-Creator] Datei geschrieben: {path} (Einträge: {len(self.rules_list)})")
                messagebox.showinfo("Gespeichert", f"Rules wurden nach\n{path}\ngeschrieben.")
            else:
                log_message(f"[Rules-Creator] WARNUNG: Datei konnte nicht verifiziert werden: {path}")
                messagebox.showwarning("Warnung", f"Datei sollte hier liegen, konnte aber nicht gefunden werden:\n{path}\nBitte Pfad prüfen.")
        except OSError as exc:
            log_message(f"[Rules-Creator] Fehler beim Speichern: {exc}")
            messagebox.showerror("Fehler", f"Datei konnte nicht gespeichert werden:\n{exc}")

    def _load_rules_if_possible(self):
        path = self.rules_path_var.get().strip()
        if not path or not os.path.isfile(path):
            self.rules_list = []
            self._refresh_listbox()
            return
        try:
            with open(path, "r", encoding="utf-8") as f:
                lines = [line.strip() for line in f.readlines() if line.strip()]
            self.rules_list = lines
            self._refresh_listbox()
            log_message(f"[Rules-Creator] Bestehende Datei geladen: {path} ({len(self.rules_list)} Einträge)")
        except OSError:
            self.rules_list = []
            self._refresh_listbox()

    def _detect_default_path(self):
        candidates = []
        home = os.path.expanduser("~")
        candidates.append(os.path.join(os.path.dirname(__file__), "Rules-Master.txt"))
        candidates.append(os.path.join(home, ".wine", "drive_c", "Program Files", "MetaTrader 5", "MQL5", "Files", "Rules-Master.txt"))
        pattern = os.path.join(home, ".wine", "drive_c", "users", "*", "AppData", "Roaming", "MetaQuotes", "Terminal", "*", "MQL5", "Files", "Rules-Master.txt")
        candidates.extend(glob.glob(pattern))
        for path in candidates:
            directory = os.path.dirname(path)
            if os.path.isdir(directory):
                return path
        return os.path.join(os.path.dirname(__file__), "Rules-Master.txt")


def main():
    app = RulesCreatorApp()
    app.mainloop()


if __name__ == "__main__":
    main()
