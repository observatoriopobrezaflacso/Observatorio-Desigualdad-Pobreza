#!/usr/bin/env python3
"""
Scraper: Contraloría General del Estado - Declaraciones Patrimoniales Juradas
URL: https://www.contraloria.gob.ec/Consultas/DeclaracionesJuradas

For each declaration found it:
  1. Parses the results table (nombre, cargo, entidad, año, pdf_token)
  2. Downloads the PDF via the authenticated session
  3. Extracts activos, pasivos, patrimonio from the PDF text

Usage:
    python scraper_contraloria.py <cedula>
    python scraper_contraloria.py 1104629116

Output:
    declaraciones_<cedula>.csv   (saved in the current directory)

Requirements:
    pip install playwright pdfplumber httpx pillow pytesseract pandas
    playwright install chromium
    macOS: brew install tesseract
"""

from __future__ import annotations

import asyncio
import io
import re
import sys
import time
from collections import Counter
from pathlib import Path

import httpx
import pdfplumber
import pandas as pd
from PIL import Image, ImageFilter
from playwright.async_api import async_playwright, Page

try:
    import pytesseract
    HAS_TESSERACT = True
except ImportError:
    HAS_TESSERACT = False

BASE_URL           = "https://www.contraloria.gob.ec"
SEARCH_URL         = f"{BASE_URL}/Consultas/DeclaracionesJuradas"
MAX_CAPTCHA_TRIES  = 15


# ─────────────────────────────────────────────────────────────────────────────
# OCR
# ─────────────────────────────────────────────────────────────────────────────

def _ocr(img: Image.Image) -> str:
    """Try several preprocessing strategies; return most-common OCR result."""
    if not HAS_TESSERACT:
        return ""
    gray = img.convert("L")
    w, h = gray.size
    big  = gray.resize((w * 3, h * 3), Image.LANCZOS)

    candidates: list[str] = []
    for base in (gray, big):
        thresh = base.point(lambda x: 0 if x < 127 else 255)
        sharp  = base.filter(ImageFilter.SHARPEN).filter(ImageFilter.SHARPEN)
        for src in (base, thresh, sharp):
            for psm in (7, 6):
                cfg = (
                    f"--oem 1 --psm {psm} "
                    "-c tessedit_char_whitelist="
                    "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
                )
                try:
                    text = pytesseract.image_to_string(src, config=cfg).strip()
                    if text:
                        candidates.append(text)
                except Exception:
                    pass

    if not candidates:
        return ""
    return Counter(candidates).most_common(1)[0][0]


# ─────────────────────────────────────────────────────────────────────────────
# Playwright helpers
# ─────────────────────────────────────────────────────────────────────────────

async def _dismiss_modal(page: Page) -> None:
    for selector in ("#divMensaje .btn-close", ".modal .btn-close"):
        try:
            await page.locator(selector).first.click(timeout=2000)
            await page.wait_for_timeout(350)
            return
        except Exception:
            pass
    try:
        await page.keyboard.press("Escape")
        await page.wait_for_timeout(350)
    except Exception:
        pass


async def _read_captcha(page: Page) -> str:
    """Return the OCR text of the current CAPTCHA image, or '' on failure."""
    import base64
    src = await page.get_attribute("#captcha", "src") or ""
    if not src:
        return ""
    b64 = src.split(",", 1)[1] if "," in src else src
    try:
        raw = base64.b64decode(b64)
        img = Image.open(io.BytesIO(raw))
        return _ocr(img)
    except Exception:
        return ""


async def _refresh_captcha(page: Page) -> None:
    """Click the CAPTCHA image to generate a new one."""
    for sel in ("#captcha", "a[onclick*='captcha']", "#lnkCaptcha"):
        try:
            await page.locator(sel).first.click(timeout=2000)
            await page.wait_for_timeout(700)
            return
        except Exception:
            pass


# ─────────────────────────────────────────────────────────────────────────────
# Search
# ─────────────────────────────────────────────────────────────────────────────

async def search_declarations(cedula: str) -> tuple[list[dict], dict]:
    """
    Search Contraloría for all declarations of the given cédula.

    Returns:
        rows    — list of dicts: {nombre, cargo, entidad, anio, pdf_token}
        cookies — dict of session cookies (needed to download PDFs)
    """
    rows: list[dict]  = []
    cookies: dict     = {}
    json_data: list   = []

    async with async_playwright() as pw:
        browser = await pw.chromium.launch(headless=True)
        page    = await browser.new_page(
            user_agent=(
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/124.0.0.0 Safari/537.36"
            )
        )

        # Intercept DataTables JSON
        async def on_response(resp):
            if "WFResultados" in resp.url and resp.status == 200:
                try:
                    body = await resp.json()
                    if isinstance(body, dict) and body.get("draw", -1) >= 0:
                        json_data.extend(body.get("data", []))
                except Exception:
                    pass

        page.on("response", on_response)
        await page.goto(SEARCH_URL, wait_until="networkidle", timeout=30000)
        await _dismiss_modal(page)

        # CAPTCHA retry loop
        for attempt in range(1, MAX_CAPTCHA_TRIES + 1):
            json_data.clear()

            if attempt == MAX_CAPTCHA_TRIES:
                # Last resort: ask user
                import base64
                src = await page.get_attribute("#captcha", "src") or ""
                if src:
                    b64  = src.split(",", 1)[1] if "," in src else src
                    img  = Image.open(io.BytesIO(base64.b64decode(b64)))
                    img.save("/tmp/contraloria_captcha.png")
                    print("\n  CAPTCHA saved to /tmp/contraloria_captcha.png — open and type the code.")
                captcha_code = input("  CAPTCHA code: ").strip()
            else:
                captcha_code = await _read_captcha(page)

            if not captcha_code:
                await _refresh_captcha(page)
                continue

            print(f"  Attempt {attempt}/{MAX_CAPTCHA_TRIES} — CAPTCHA: '{captcha_code}'")

            await page.fill("#txtCedula", cedula)
            await page.fill("#x", captcha_code)
            await page.click("#btnBuscar_in")
            await page.wait_for_load_state("networkidle")
            await page.wait_for_timeout(2500)

            if json_data:
                print(f"  [✓] Found {len(json_data)} rows on attempt {attempt}")
                break

            print("  [✗] CAPTCHA rejected — refreshing...")
            await _refresh_captcha(page)
            await page.fill("#txtCedula", cedula)

        # Collect session cookies
        for c in await page.context.cookies():
            cookies[c["name"]] = c["value"]

        await browser.close()

    # Parse rows
    # JSON row layout: [cedula, nombre, cargo, entidad, '', año, pdf_token, flag]
    for row in json_data:
        if not isinstance(row, (list, tuple)) or len(row) < 7:
            continue
        rows.append({
            "nombre":     _clean(str(row[1])),
            "cargo":      _clean(str(row[2])),
            "entidad":    _clean(str(row[3])),
            "anio":       _clean(str(row[5])),
            "pdf_token":  str(row[6]).strip(),
        })

    return rows, cookies


# ─────────────────────────────────────────────────────────────────────────────
# PDF download
# ─────────────────────────────────────────────────────────────────────────────

async def download_pdf(cedula: str, token: str, cookies: dict) -> bytes | None:
    """
    Download the PDF for a given declaration token.

    URL pattern discovered from desplegarDeclaracion3() + downDPJ():
        /sistema/WFDeclaracionAcuerdo024.aspx?xx={ms_timestamp}&id={cedula}&td={token}&op=d
    """
    if not token:
        return None
    ts  = int(time.time() * 1000)
    url = (
        f"{BASE_URL}/sistema/WFDeclaracionAcuerdo024.aspx"
        f"?xx={ts}&id={cedula}&td={token}&op=d"
    )
    try:
        async with httpx.AsyncClient(
            verify=False, timeout=30, follow_redirects=True
        ) as client:
            r = await client.get(
                url,
                cookies=cookies,
                headers={
                    "User-Agent": "Mozilla/5.0",
                    "Referer":    SEARCH_URL,
                },
            )
            if r.status_code == 200 and r.content[:4] == b"%PDF":
                return r.content
            print(f"    [!] PDF HTTP {r.status_code}: {url[:90]}")
    except Exception as e:
        print(f"    [!] PDF error: {e}")
    return None


# ─────────────────────────────────────────────────────────────────────────────
# PDF parsing
# ─────────────────────────────────────────────────────────────────────────────

def extract_wealth(pdf_bytes: bytes) -> dict:
    """
    Extract activos, pasivos, patrimonio from a Declaración Patrimonial PDF.

    The PDF uses comma as decimal separator (Ecuadorian format):
        TOTAL ACTIVOS: USD: 15986,61
        TOTAL DE PASIVOS: USD: 0,00
        TOTAL DE PATRIMONIO USD: 15986,61
    """
    result = {"activos": None, "pasivos": None, "patrimonio": None}

    with pdfplumber.open(io.BytesIO(pdf_bytes)) as pdf:
        full_text = "\n".join(p.extract_text() or "" for p in pdf.pages)

    text = full_text.upper()

    patterns = {
        "activos": [
            r"TOTAL\s+ACTIVOS?\s*:\s*USD\s*:\s*([\d\.,]+)",
            r"TOTAL\s+DE\s+ACTIVOS?\s*:\s*USD\s*:\s*([\d\.,]+)",
            r"TOTAL\s+ACTIVOS?\s*USD\s*:\s*([\d\.,]+)",
        ],
        "pasivos": [
            r"TOTAL\s+DE\s+PASIVOS?\s*:\s*USD\s*:\s*([\d\.,]+)",
            r"TOTAL\s+PASIVOS?\s*:\s*USD\s*:\s*([\d\.,]+)",
            r"TOTAL\s+PASIVOS?\s*USD\s*:\s*([\d\.,]+)",
        ],
        "patrimonio": [
            r"TOTAL\s+DE\s+PATRIMONIO\s*USD\s*:\s*([\d\.,]+)",
            r"TOTAL\s+PATRIMONIO\s*USD\s*:\s*([\d\.,]+)",
            r"PATRIMONIO\s+NETO\s*:\s*USD\s*:\s*([\d\.,]+)",
            r"PATRIMONIO\s*USD\s*:\s*([\d\.,]+)",
        ],
    }

    for key, pats in patterns.items():
        for pat in pats:
            m = re.search(pat, text)
            if m:
                val = _parse_ec_number(m.group(1))
                if val is not None:
                    result[key] = val
                    break

    return result


# ─────────────────────────────────────────────────────────────────────────────
# Utilities
# ─────────────────────────────────────────────────────────────────────────────

def _clean(s: str) -> str:
    return re.sub(r"\s+", " ", s).strip()


def _parse_ec_number(s: str) -> float | None:
    """
    Parse an Ecuadorian-format number where comma is the decimal separator.
    e.g. "15986,61" → 15986.61,  "0,00" → 0.0
    Also handles "15.986,61" (with dot as thousands separator).
    """
    s = s.strip().replace("$", "").replace(" ", "")
    # Remove dots used as thousands separators (appear before groups of exactly 3 digits)
    s = re.sub(r"\.(?=\d{3}(?:,|$))", "", s)
    # Replace comma decimal separator
    s = s.replace(",", ".")
    try:
        return float(s)
    except ValueError:
        return None


# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

async def main(cedula: str, save_csv: bool = True) -> pd.DataFrame | None:
    print(f"\n{'='*60}")
    print(f"  Contraloría — Declaraciones Patrimoniales Juradas")
    print(f"  Cédula: {cedula}")
    print(f"{'='*60}\n")

    # 1. Search
    print("[1/3] Searching declarations...")
    rows, cookies = await search_declarations(cedula)

    if not rows:
        print("  No declarations found (or CAPTCHA could not be solved).")
        return None

    print(f"  {len(rows)} declaration(s) found.\n")

    # 2. Download PDFs and extract wealth
    print("[2/3] Downloading PDFs and extracting wealth data...")
    records: list[dict] = []

    for i, row in enumerate(rows, 1):
        rec = {**row, "activos": None, "pasivos": None, "patrimonio": None}
        print(f"  [{i:>2}/{len(rows)}] {row['anio']} | {row['cargo'][:50]}")

        pdf_bytes = await download_pdf(cedula, row["pdf_token"], cookies)
        if pdf_bytes:
            wealth = extract_wealth(pdf_bytes)
            rec.update(wealth)
            print(
                f"         activos={rec['activos']}  "
                f"pasivos={rec['pasivos']}  "
                f"patrimonio={rec['patrimonio']}"
            )
        else:
            print("         [!] PDF unavailable")

        records.append(rec)

    # 3. Display
    print(f"\n[3/3] Summary\n{'─'*60}")
    df = pd.DataFrame(records)
    display_cols = ["anio", "cargo", "entidad", "activos", "pasivos", "patrimonio"]
    print(df[display_cols].to_string(index=False))

    if save_csv:
        out = Path(f"declaraciones_{cedula}.csv")
        df.to_csv(out, index=False)
        print(f"\n  Saved: {out.resolve()}")

    return df


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python scraper_contraloria.py <cedula>")
        sys.exit(1)
    asyncio.run(main(sys.argv[1]))
