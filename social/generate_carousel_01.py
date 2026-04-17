#!/usr/bin/env python3
"""Generate Day 1 Founding Post carousel slides (5 slides)."""

import base64
import os
import subprocess
import tempfile
from PIL import Image

# Paths
LOGO_PATH = "/Users/matt/Desktop/Arkline Appstore/Logo/icononly_transparent_nobuffer.png"
FONT_DIR = "/Users/matt/Arkline/social/fonts"
OUTPUT_DIR = "/Users/matt/Arkline/social"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

# Base64 encode logo
with open(LOGO_PATH, "rb") as f:
    logo_b64 = base64.b64encode(f.read()).decode()

# Base64 encode fonts
with open(os.path.join(FONT_DIR, "Urbanist-Bold.ttf"), "rb") as f:
    urbanist_bold_b64 = base64.b64encode(f.read()).decode()
with open(os.path.join(FONT_DIR, "Urbanist-SemiBold.ttf"), "rb") as f:
    urbanist_semi_b64 = base64.b64encode(f.read()).decode()
with open(os.path.join(FONT_DIR, "Inter-Medium.ttf"), "rb") as f:
    inter_medium_b64 = base64.b64encode(f.read()).decode()

# Slide definitions: list of (blocks, tagline)
# Each block is (text, muted: bool)
# A None entry means "divider"
slides = [
    {
        "num": 1,
        "blocks": [
            ("Hedge funds mass-hire PhDs to model risk.", False),
            None,  # divider
            ("Retail investors check YouTube.", True),
        ],
    },
    {
        "num": 2,
        "blocks": [
            ("I spent 7 years watching retail lose —", False),
            None,
            ("not because they're dumb, but because they're unarmed.", True),
        ],
    },
    {
        "num": 3,
        "blocks": [
            ("The same macro signals institutions use — VIX, DXY, net liquidity, supply-in-profit — are all public data.", False),
            None,
            ("Nobody packages them for retail.", True),
        ],
    },
    {
        "num": 4,
        "blocks": [
            ("So I'm building the tool I wish I had since 2019.", False),
        ],
    },
    {
        "num": 5,
        "blocks": [
            ("Arkline.", False),
            None,
            ("The data institutions use. In your pocket.", False),
            None,
            ("Coming soon.", True),
        ],
    },
]


def build_html(slide):
    blocks_html = ""
    for block in slide["blocks"]:
        if block is None:
            # Divider
            blocks_html += '<div class="divider"></div>\n'
        else:
            text, muted = block
            cls = "copy muted" if muted else "copy"
            blocks_html += f'<div class="{cls}">{text}</div>\n'

    return f"""<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
@font-face {{
    font-family: 'Urbanist';
    font-weight: 700;
    src: url(data:font/truetype;base64,{urbanist_bold_b64}) format('truetype');
}}
@font-face {{
    font-family: 'Urbanist';
    font-weight: 600;
    src: url(data:font/truetype;base64,{urbanist_semi_b64}) format('truetype');
}}
@font-face {{
    font-family: 'Inter';
    font-weight: 500;
    src: url(data:font/truetype;base64,{inter_medium_b64}) format('truetype');
}}

* {{ margin: 0; padding: 0; box-sizing: border-box; }}

body {{
    width: 1080px;
    height: 1080px;
    background: #1B6FEE;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    padding: 68px 80px 80px 80px;
    overflow: hidden;
}}

.logo {{
    display: flex;
    align-items: center;
    gap: 14px;
}}

.logo img {{
    height: 64px;
    width: auto;
    border-radius: 14px;
    background: white;
    padding: 6px;
}}

.logo-text {{
    font-family: 'Urbanist', sans-serif;
    font-weight: 600;
    font-size: 34px;
    color: white;
}}

.copy-block {{
    display: flex;
    flex-direction: column;
}}

.copy {{
    font-family: 'Urbanist', sans-serif;
    font-weight: 700;
    font-size: 52px;
    color: white;
    line-height: 1.15;
    letter-spacing: -0.02em;
}}

.copy.muted {{
    opacity: 0.4;
}}

.divider {{
    width: 100%;
    height: 1px;
    background: rgba(255, 255, 255, 0.2);
    margin: 32px 0;
}}

.tagline {{
    font-family: 'Inter', sans-serif;
    font-weight: 500;
    font-size: 16px;
    color: rgba(255, 255, 255, 0.5);
    text-transform: uppercase;
    letter-spacing: 0.08em;
}}
</style>
</head>
<body>
    <div class="logo">
        <img src="data:image/png;base64,{logo_b64}" alt="Arkline">
        <span class="logo-text">Arkline</span>
    </div>
    <div class="copy-block">
        {blocks_html}
    </div>
    <div class="tagline">DATA OVER NOISE.</div>
</body>
</html>"""


for slide in slides:
    num = slide["num"]
    html = build_html(slide)

    # Write HTML to temp file
    with tempfile.NamedTemporaryFile(suffix=".html", delete=False, mode="w") as f:
        f.write(html)
        html_path = f.name

    # Screenshot with Chrome headless
    raw_path = os.path.join(OUTPUT_DIR, f"carousel-01-slide{num}-raw.png")
    final_path = os.path.join(OUTPUT_DIR, f"carousel-01-slide{num}.png")

    subprocess.run([
        CHROME,
        "--headless",
        "--disable-gpu",
        "--screenshot=" + raw_path,
        "--window-size=1080,1140",
        "--hide-scrollbars",
        "file://" + html_path,
    ], capture_output=True)

    # Crop to 1080x1080
    img = Image.open(raw_path)
    img = img.crop((0, 0, 1080, 1080))
    img.save(final_path)
    os.remove(raw_path)
    os.remove(html_path)

    print(f"Slide {num}: {final_path}")

print("\nDone. 5 carousel slides generated.")
