#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
fix_assets_html.py
Perbaiki <img> dan URL icon di index.html untuk menghindari net::ERR_NAME_NOT_RESOLVED

Yang diperbaiki:
1) Baris URL polos pada panel asset (tanpa <img>) -> dijadikan <img ...>
2) src tanpa skema (mis. '000000?text=MOGA') -> dipetakan ke URL absolut placeholder
3) Pastikan setiap icon memakai class "profile-slide-asset-icon"

Jalankan:
  python3 fix_assets_html.py
"""

import re
from pathlib import Path
import shutil

HTML_FILE = Path("index.html")
BACKUP_FILE = Path("index.html.bak")

if not HTML_FILE.exists():
    raise SystemExit(f"File {HTML_FILE} tidak ditemukan. Jalankan dari folder yang berisi index.html")

# Backup dulu
shutil.copy2(HTML_FILE, BACKUP_FILE)

html = HTML_FILE.read_text(encoding="utf-8")

# ------------------------------
# 1) Pemetaan URL icon umum (boleh disesuaikan)
# ------------------------------
KNOWN_ICON_URLS = {
    "https://plume.org/media-kit/plume-logomark-red.png": ("PLUME", "Plume Native"),
    "https://via.placeholder.com/44/FFCC00/000000?text=MOGA": ("MOGA", "Mogaland Token"),
    "https://cryptologos.cc/logos/usd-coin-usdc-logo.png?v=035": ("USDC", "USD Coin"),
    "https://cryptologos.cc/logos/tether-usdt-logo.png?v=035": ("USDT", "Tether"),
}

# ------------------------------
# 2) Ganti URL polos di dalam .profile-slide-asset-row menjadi <img ...>
# ------------------------------
def replace_bare_urls_in_asset_rows(text: str) -> str:
    row_pattern = re.compile(r'(<div\s+class="profile-slide-asset-row"\s*>)(.*?)(</div>)', re.DOTALL)

    def fix_row(match):
        start, body, end = match.groups()
        # Cari URL absolut (http/https) yang muncul sebagai teks
        urls = re.findall(r'(https?://[^\s"<>\']+)', body)
        new_body = body
        for url in urls:
            # Jika sudah ada sebagai src pada <img>, skip
            if re.search(rf'<img[^>]+src=["\']{re.escape(url)}["\']', body):
                continue
            # Sisipkan <img> dengan URL tsb
            alt = KNOWN_ICON_URLS.get(url, ("Asset", ""))[0]
            img_tag = f'{url}'
            new_body = new_body.replace(url, img_tag)
        return start + new_body + end

    return row_pattern.sub(fix_row, text)

html = replace_bare_urls_in_asset_rows(html)

# ------------------------------
# 3) Perbaiki src tanpa skema yang diketahui (contoh '000000?text=MOGA')
# ------------------------------
BROKEN_PATTERNS = [
    r'(?<![a-zA-Z0-9])000000\?text=MOGA(?![a-zA-Z0-9])',  # tanpa kutip
    r'(["\'])000000\?text=MOGA\1',                        # di dalam kutip
]
MOGA_PLACEHOLDER = 'https://via.placeholder.com/44/FFCC00/000000?text=MOGA'

def fix_broken_src_without_scheme(text: str) -> str:
    out = text
    for pat in BROKEN_PATTERNS:
        out = re.sub(pat, MOGA_PLACEHOLDER, out)
    return out

html = fix_broken_src_without_scheme(html)

# ------------------------------
# 4) Pastikan setiap <img> dalam asset-row punya class profile-slide-asset-icon
# ------------------------------
def ensure_icon_class(text: str) -> str:
    def add_class_to_img(tag: str) -> str:
        if 'class=' in tag:
            if 'profile-slide-asset-icon' in tag:
                return tag
            # Sisipkan ke class yang sudah ada
            return re.sub(r'class="([^"]*)"', r'class="\1 profile-slide-asset-icon"', tag, count=1)
        # Tambah atribut class baru
        return tag.replace('<img', '<img class="profile-slide-asset-icon"', 1)

    def fix_row_imgs(match):
        row_html = match.group(0)
        imgs = re.findall(r'<img\b[^>]*>', row_html)
        fixed = row_html
        for img in imgs:
            fixed_img = add_class_to_img(img)
            fixed = fixed.replace(img, fixed_img)
        return fixed

    pattern = re.compile(r'<div\s+class="profile-slide-asset-row"[^>]*>.*?</div>', re.DOTALL)
    return pattern.sub(fix_row_imgs, text)

html = ensure_icon_class(html)

# ------------------------------
# 5) Tulis kembali file
# ------------------------------
HTML_FILE.write_text(html, encoding="utf-8")
print("Selesai ✅: index.html diperbaiki. Backup tersimpan sebagai index.html.bak")
