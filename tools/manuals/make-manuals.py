#!/usr/bin/env python
"""Vygeneruje PDF příručky z Markdown zdrojů v docs/."""
from __future__ import annotations

import html
import os
import re
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, StyleSheet1
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    BaseDocTemplate, Frame, HRFlowable, Image, ListFlowable, ListItem,
    PageTemplate, Paragraph, Spacer, Table, TableStyle,
)

ROOT = Path(__file__).resolve().parents[2]
PUBLIC = ROOT / "app" / "public"
LOGO = ROOT / "assets" / "branding" / "ksmf-snake-logo-v2.png"
FONTS = Path(os.environ.get("WINDIR", r"C:\Windows")) / "Fonts"

NAVY = colors.HexColor("#0d1117")
BLUE = colors.HexColor("#1f6feb")
RED = colors.HexColor("#e5484d")
GREY = colors.HexColor("#57606a")

pdfmetrics.registerFont(TTFont("Arial", str(FONTS / "arial.ttf")))
pdfmetrics.registerFont(TTFont("Arial-Bold", str(FONTS / "arialbd.ttf")))
pdfmetrics.registerFont(TTFont("Arial-It", str(FONTS / "ariali.ttf")))
pdfmetrics.registerFontFamily("Arial", normal="Arial", bold="Arial-Bold", italic="Arial-It")


def stylesheet():
    styles = StyleSheet1()
    styles.add(ParagraphStyle("Body", fontName="Arial", fontSize=10.2, leading=14.5, textColor=NAVY, spaceAfter=6))
    styles.add(ParagraphStyle("Title", fontName="Arial-Bold", fontSize=24, leading=28, textColor=BLUE))
    styles.add(ParagraphStyle("H2", fontName="Arial-Bold", fontSize=15, leading=19, textColor=BLUE, spaceBefore=13, spaceAfter=5, keepWithNext=True))
    styles.add(ParagraphStyle("H3", fontName="Arial-Bold", fontSize=11.5, leading=15, textColor=NAVY, spaceBefore=8, spaceAfter=3, keepWithNext=True))
    styles.add(ParagraphStyle("Bullet", parent=styles["Body"], leftIndent=4, spaceAfter=2))
    styles.add(ParagraphStyle("Callout", parent=styles["Body"], backColor=colors.HexColor("#fff0f0"), borderColor=RED, borderWidth=1, borderPadding=8, borderRadius=5, spaceBefore=5, spaceAfter=9))
    return styles


def inline(markdown: str) -> str:
    value = html.escape(markdown.strip())
    value = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", value)
    value = re.sub(r"`(.+?)`", r"<font name='Courier'>\1</font>", value)
    return value


def markdown_flow(path: Path, styles):
    lines = path.read_text(encoding="utf-8").splitlines()
    flow, paragraph, bullets, numbers = [], [], [], []

    def flush_paragraph():
        if paragraph:
            flow.append(Paragraph(inline(" ".join(paragraph)), styles["Body"]))
            paragraph.clear()

    def flush_lists():
        if bullets:
            flow.append(ListFlowable([ListItem(Paragraph(inline(x), styles["Bullet"])) for x in bullets], bulletType="bullet", bulletColor=BLUE, leftIndent=15))
            bullets.clear()
        if numbers:
            flow.append(ListFlowable([ListItem(Paragraph(inline(x), styles["Bullet"])) for x in numbers], bulletType="1", leftIndent=18))
            numbers.clear()

    for line in lines[1:]:
        text = line.strip()
        if not text:
            flush_paragraph(); flush_lists(); continue
        if text.startswith("## "):
            flush_paragraph(); flush_lists(); flow.append(Paragraph(inline(text[3:]), styles["H2"])); continue
        if text.startswith("### "):
            flush_paragraph(); flush_lists(); flow.append(Paragraph(inline(text[4:]), styles["H3"])); continue
        if text.startswith("> "):
            flush_paragraph(); flush_lists(); flow.append(Paragraph(inline(text[2:]), styles["Callout"])); continue
        if text.startswith("- "):
            flush_paragraph()
            if numbers: flush_lists()
            bullets.append(text[2:]); continue
        numbered = re.match(r"^\d+\.\s+(.+)$", text)
        if numbered:
            flush_paragraph()
            if bullets: flush_lists()
            numbers.append(numbered.group(1)); continue
        if text == "---":
            flush_paragraph(); flush_lists(); flow.append(HRFlowable(width="100%", color=colors.HexColor("#d0d7de"))); continue
        paragraph.append(text)
    flush_paragraph(); flush_lists()
    return flow


def build(source: Path, target: Path, subtitle: str):
    title = source.read_text(encoding="utf-8").splitlines()[0].removeprefix("# ").strip()
    styles = stylesheet()
    doc = BaseDocTemplate(str(target), pagesize=A4, topMargin=17 * mm, bottomMargin=17 * mm, leftMargin=18 * mm, rightMargin=18 * mm, title=title, author="KŠMF Snake")
    frame = Frame(doc.leftMargin, doc.bottomMargin, doc.width, doc.height, id="main")

    def footer(canvas, current_doc):
        canvas.saveState()
        canvas.setFont("Arial", 8)
        canvas.setFillColor(GREY)
        canvas.drawString(doc.leftMargin, 10 * mm, "KŠMF Snake - lokační hra v reálném městě")
        canvas.drawRightString(doc.leftMargin + doc.width, 10 * mm, f"strana {current_doc.page}")
        canvas.restoreState()

    doc.addPageTemplates([PageTemplate(id="manual", frames=[frame], onPage=footer)])
    heading = Table([[Image(str(LOGO), width=30 * mm, height=30 * mm), Paragraph(f"<b>{html.escape(title)}</b><br/><font size='10' color='#57606a'>{html.escape(subtitle)}</font>", styles["Title"])]], colWidths=[34 * mm, None])
    heading.setStyle(TableStyle([("VALIGN", (0, 0), (-1, -1), "MIDDLE"), ("LEFTPADDING", (0, 0), (-1, -1), 0)]))
    flow = [heading, Spacer(1, 5), HRFlowable(width="100%", thickness=1.2, color=BLUE), Spacer(1, 7)]
    flow.extend(markdown_flow(source, styles))
    doc.build(flow)
    print(f"wrote {target.relative_to(ROOT)} from {source.relative_to(ROOT)}")


if __name__ == "__main__":
    build(ROOT / "docs" / "06-manual-hrac.md", PUBLIC / "manual-hrac.pdf", "Jak hrát bezpečně a co znamenají prvky na mapě")
    build(ROOT / "docs" / "07-manual-admin.md", PUBLIC / "manual-admin.pdf", "Příprava mapy, řízení hry a vyhodnocení")
