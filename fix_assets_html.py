#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
fix_assets_html.py
Perbaiki tag <img> & URL icon di index.html:
- Ubah URL polos dalam .profile-slide-asset-row menjadi <img ...>
- Perbaiki src tanpa skema (000000?text=MOGA)
- Hilangkan duplikasi URL placeholder
- Pastikan class="profile-slide-asset-icon"
"""

import re
from pathlib import Path
import shutil

HTML_FILE = Path("index.html")
BACKUP_FILE = Path("index.html.bak")

if not HTML_FILE.exists():
    raise SystemExit(f"File {HTML_FILE} tidak ditemukan. Jalankan dari folder yang berisi index.html")

# Backup
shutil.copy2(HTML_FILE, BACKUP_FILE)
html = HTML_FILE.read_text(encoding="utf-8")

KNOWN_ICON_URLS = {
    "https://plume.org/media-kit/plume-logomark-red.png": ("PLUME", "Plume Native"),
    "https://via.placeholder.com/44/FFCC00/000000?text=MOGA": ("MOGA", "Mogaland Token"),
    "https://cryptologos.cc/logos/usd-coin-usdc-logo.png?v=035": ("USDC", "USD Coin"),
    "https://cryptologos.cc/logos/tether-usdt-logo.png?v=035": ("USDT", "Tether"),
}

def replace_bare_urls_in_asset_rows(text: str) -> str:
    row_pattern = re.compile(r'(<div\s+class="profile-slide-asset-row"[^>]*>)(.*?)(</div>)', re.DOTALL)
    def fix_row(m):
        start, body, end = m.groups()
        urls = re.findall(r'(https?://[^\s"<>\']+)', body)
        new_body = body
        for url in urls:
            # skip kalau sudah jadi <img src="url">
            if re.search(rf'<img[^>]+src=["\']{re.escape(url)}["\']', body):
                continue
            alt = KNOWN_ICON_URLS.get(url, ("Asset", ""))[0]
            img_tag = f'<img src="{url}" alt="{alt}" class="profile-slide-asset-icon">'
            # ganti url polos dengan tag <img>
            new_body = new_body.replace(url, img_tag)
        return start + new_body + end
    return row_pattern.sub(fix_row, text)

html = replace_bare_urls_in_asset_rows(html)

# Perbaiki src tanpa skema '000000?text=MOGA' -> placeholder absolut
MOGA_PLACEHOLDER = 'https://via.placeholder.com/44/FFCC00/000000?text=MOGA'
html = re.sub(r'(["\'])000000\?text=MOGA\1', f'"{MOGA_PLACEHOLDER}"', html)
html = re.sub(r'(?<![a-zA-Z0-9])000000\?text=MOGA(?![a-zA-Z0-9])', MOGA_PLACEHOLDER, html)

# Hilangkan duplikasi URL placeholder (yang memicu DNS error)
dup_pattern = re.compile(
    r'https://via\.placeholder\.com/44/FFCC00/https://via\.placeholder\.com/44/FFCC00/000000\?text=MOGA'
)
html = dup_pattern.sub(MOGA_PLACEHOLDER, html)

# Pastikan setiap <img> di asset-row punya class profile-slide-asset-icon
def ensure_icon_class(text: str) -> str:
    def add_class(tag: str) -> str:
        if 'class=' in tag:
            if 'profile-slide-asset-icon' in tag:
                return tag
            return re.sub(r'class="([^"]*)"', r'class="\1 profile-slide-asset-icon"', tag, count=1)
        return tag.replace('<img', '<img class="profile-slide-asset-icon"', 1)
    def fix_row_imgs(m):
        row_html = m.group(0)
        imgs = re.findall(r'<img\b[^>]*>', row_html)
        fixed = row_html
        for img in imgs:
            fixed = fixed.replace(img, add_class(img))
        return fixed
    pattern = re.compile(r'<div\s+class="profile-slide-asset-row"[^>]*>.*?</div>', re.DOTALL)
    return pattern.sub(fix_row_imgs, text)

html = ensure_icon_class(html)

# Tulis kembali
HTML_FILE.write_text(html, encoding="utf-8")
print("Selesai ✅: index.html diperbaiki. Backup tersimpan sebagai index.html.bak")
