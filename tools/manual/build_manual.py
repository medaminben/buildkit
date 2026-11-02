#!/usr/bin/env python3
"""Render a multilingual user manual from Markdown into static HTML.

Standard library only (Python 3.11+).

Source layout (the --root directory):

    <root>/content/<lang>/<page>.md   pages, one directory per language
    <root>/assets/                    images, css, js; copied to <out>/assets
    <root>/template.html              optional page template (else the one
                                      next to this script)

    build_manual.py --root R --out O [--title T] [--labels L.json]
        writes O/<lang>/<page>.html, O/index.html (language chooser) and O/assets
    build_manual.py --root R --check [--labels L.json]
        writes nothing; prints every problem and exits 1 if there is one:
        a page in one language but not in another, a broken link, anchor or
        image, an external URL, missing front matter, and (with --labels) a
        `label` that is not in the language's list of the JSON {lang: [labels]}

Pages start with front matter (title, order, summary between --- lines).
Markdown subset: ## / ### headings (optional {#anchor}), paragraphs, - and 1.
lists, | tables, ::: note / ::: warning / ::: formula / ::: step blocks,
![caption](assets/x.png) or ![caption](shot:name) (assets/shots/<lang>/name.png),
**bold**, *italic*, [text](page#anchor) and `label` for a label of the
application. Template placeholders: {{lang}} {{dir}} {{title}} {{summary}}
{{site}} {{manual}} {{contents}} {{language}} {{nav}} {{switcher}} {{body}}
{{prev}} {{next}} {{icon}} {{logo}}.
"""
from __future__ import annotations

import argparse
import html
import json
import posixpath
import re
import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
RTL = {"ar", "he", "fa", "ur"}
LANG_ORDER = ("en", "de", "es", "it", "fr", "nl", "ar")
LANG_NAMES = {"en": "English", "de": "Deutsch", "es": "Español", "it": "Italiano", "fr": "Français",
              "nl": "Nederlands", "ar": "العربية", "he": "עברית", "fa": "فارسی", "ur": "اردو"}
UI = {
    "en": {"contents": "Contents", "prev": "Previous", "next": "Next", "manual": "User manual",
           "language": "Language"},
    "de": {"contents": "Inhalt", "prev": "Zurück", "next": "Weiter", "manual": "Benutzerhandbuch",
           "language": "Sprache"},
    "es": {"contents": "Contenido", "prev": "Anterior", "next": "Siguiente", "manual": "Manual de usuario",
           "language": "Idioma"},
    "it": {"contents": "Indice", "prev": "Precedente", "next": "Successivo", "manual": "Manuale utente",
           "language": "Lingua"},
    "fr": {"contents": "Sommaire", "prev": "Précédent", "next": "Suivant", "manual": "Manuel d'utilisation",
           "language": "Langue"},
    "nl": {"contents": "Inhoud", "prev": "Vorige", "next": "Volgende", "manual": "Handleiding",
           "language": "Taal"},
    "ar": {"contents": "المحتويات", "prev": "السابق", "next": "التالي", "manual": "دليل الاستخدام",
           "language": "اللغة"},
}
DEFAULT_TITLE = "User manual"
DEFAULT_ASSETS = ("manual.css", "manual.js")


def ui(lang: str) -> dict[str, str]:
    return UI.get(lang, UI["en"])


# ---------------------------------------------------------------- front matter

def parse_front_matter(text: str) -> tuple[dict[str, str], str]:
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return {}, text
    meta: dict[str, str] = {}
    for index, line in enumerate(lines[1:], start=1):
        if line.strip() == "---":
            return meta, "\n".join(lines[index + 1:])
        key, _, value = line.partition(":")
        meta[key.strip()] = value.strip()
    return meta, ""


# ---------------------------------------------------------------- inline

_INLINE = re.compile(
    r"`(?P<ui>[^`]+)`"
    r"|\*\*(?P<b>.+?)\*\*"
    r"|\*(?P<i>[^*]+)\*"
    r"|\[(?P<lt>[^\]]+)\]\((?P<lh>[^)\s]+)\)"
)
_SCHEME = re.compile(r"^[A-Za-z][A-Za-z0-9+.-]*:")


def _href(target: str) -> str:
    if _SCHEME.match(target):
        return target
    page, _, anchor = target.partition("#")
    if page.endswith(".md"):
        page = page[:-3]
    elif "." in posixpath.basename(page):  # a file such as ../assets/x.pdf
        return target
    out = f"{page}.html" if page else ""
    return out + (f"#{anchor}" if anchor else "")


def inline(text: str) -> str:
    out: list[str] = []
    pos = 0
    for m in _INLINE.finditer(text):
        out.append(html.escape(text[pos:m.start()], quote=False))
        if m.group("ui") is not None:
            out.append(f'<span class="ui">{html.escape(m.group("ui"), quote=False)}</span>')
        elif m.group("b") is not None:
            out.append(f"<strong>{inline(m.group('b'))}</strong>")
        elif m.group("i") is not None:
            out.append(f"<em>{inline(m.group('i'))}</em>")
        else:
            out.append(f'<a href="{html.escape(_href(m.group("lh")))}">{inline(m.group("lt"))}</a>')
        pos = m.end()
    out.append(html.escape(text[pos:], quote=False))
    return "".join(out)


# ---------------------------------------------------------------- blocks

_HEADING = re.compile(r"^(#{2,3})\s+(.*?)(?:\s+\{#([A-Za-z0-9_-]+)\})?\s*$")
_IMAGE = re.compile(r"^!\[(.*)\]\(([^)\s]+)\)\s*$")
_OL = re.compile(r"^\d+\.\s+(.*)$")


class _Renderer:
    def __init__(self, lang: str):
        self.lang = lang
        self.heading_count = 0

    def render(self, text: str) -> str:
        lines = text.splitlines()
        out: list[str] = []
        i = 0
        while i < len(lines):
            stripped = lines[i].strip()
            if not stripped:
                i += 1
                continue
            if stripped.startswith(":::"):
                kind = stripped[3:].strip()
                j = i + 1
                depth = 1
                while j < len(lines):
                    s = lines[j].strip()
                    if s.startswith(":::") and s[3:].strip():
                        depth += 1
                    elif s == ":::":
                        depth -= 1
                        if depth == 0:
                            break
                    j += 1
                inner = self.render("\n".join(lines[i + 1:j]))
                if kind == "step":
                    item = f"<li>{inner}</li>"
                    if out and out[-1].startswith('<ol class="steps">'):
                        out[-1] = out[-1][: -len("</ol>")] + item + "</ol>"
                    else:
                        out.append(f'<ol class="steps">{item}</ol>')
                elif kind == "formula":  # one line each, as written
                    rows = "".join(f"<p>{inline(s.strip())}</p>" for s in lines[i + 1:j] if s.strip())
                    out.append(f'<div class="formula">{rows}</div>')
                else:
                    out.append(f'<aside class="{html.escape(kind)}">{inner}</aside>')
                i = j + 1
                continue
            m = _HEADING.match(stripped)
            if m:
                level = len(m.group(1))
                self.heading_count += 1
                anchor = m.group(3) or f"h-{self.heading_count}"
                out.append(f'<h{level} id="{anchor}">{inline(m.group(2))}</h{level}>')
                i += 1
                continue
            m = _IMAGE.match(stripped)
            if m:
                caption, target = m.group(1), m.group(2)
                if target.startswith("shot:"):
                    target = f"assets/shots/{self.lang}/{target[5:]}.png"
                src = html.escape("../" + target)
                out.append(
                    f'<figure class="shot"><a href="{src}"><img src="{src}" '
                    f'alt="{html.escape(caption)}" loading="lazy"></a>'
                    f"<figcaption>{inline(caption)}</figcaption></figure>")
                i += 1
                continue
            if stripped.startswith("|"):
                rows = []
                while i < len(lines) and lines[i].strip().startswith("|"):
                    rows.append([c.strip() for c in lines[i].strip().strip("|").split("|")])
                    i += 1
                head, body = rows[0], rows[2:]
                out.append(
                    "<table><thead><tr>" + "".join(f"<th>{inline(c)}</th>" for c in head)
                    + "</tr></thead><tbody>"
                    + "".join("<tr>" + "".join(f"<td>{inline(c)}</td>" for c in r) + "</tr>"
                              for r in body)
                    + "</tbody></table>")
                continue
            if stripped.startswith("- ") or _OL.match(stripped):
                ordered = not stripped.startswith("- ")
                items: list[str] = []
                while i < len(lines):
                    s = lines[i]
                    st = s.strip()
                    if ordered and _OL.match(st):
                        items.append(_OL.match(st).group(1))
                    elif not ordered and st.startswith("- "):
                        items.append(st[2:])
                    elif st and s.startswith("  ") and items:
                        items[-1] += " " + st
                    else:
                        break
                    i += 1
                tag = "ol" if ordered else "ul"
                out.append(f"<{tag}>" + "".join(f"<li>{inline(t)}</li>" for t in items) + f"</{tag}>")
                continue
            para = [stripped]
            i += 1
            while i < len(lines):
                st = lines[i].strip()
                if not st or st.startswith((":::", "#", "|", "- ", "![")) or _OL.match(st):
                    break
                para.append(st)
                i += 1
            out.append(f"<p>{inline(' '.join(para))}</p>")
        return "\n".join(out)


# a number with its unit, a range ("0.1–100 mm"), a product ("15.04 × 11.28 mm")
# or a sensor format ("1/2.3″"), not a digit inside a word ("mm2")
_LTR_RUN = re.compile(r"(?<![\w./])[+−]?\d[\d.]*(?:/\d[\d.]*)?″?(?:\s?[–×x]\s?\d[\d.]*)*"
                      r"(?:\s?(?:mm/px|mm²|cm²|m²|mm|µm|px|%|°|s\b))?")


def isolate_ltr(page: str) -> str:
    """Each number with its unit isolated left to right, in the text between
    tags: in a right-to-left page "1500 mm" would read "mm 1500"."""
    parts = re.split(r"(<[^>]+>)", page)
    return "".join(p if p.startswith("<") else _LTR_RUN.sub(lambda m: f'<bdi dir="ltr">{m.group(0)}</bdi>', p)
                   for p in parts)


def render_markdown(body: str, lang: str) -> str:
    out = _Renderer(lang).render(body)
    return isolate_ltr(out) if lang in RTL else out


# ---------------------------------------------------------------- site

def languages(root: Path) -> list[str]:
    found = {p.name for p in (root / "content").glob("*") if p.is_dir()}
    known = [lang for lang in LANG_ORDER if lang in found]
    return known + sorted(found - set(known))


def _pages_for(root: Path, lang: str) -> list[tuple[str, dict[str, str], str]]:
    out = []
    for path in sorted((root / "content" / lang).glob("*.md")):
        meta, body = parse_front_matter(path.read_text(encoding="utf-8"))
        out.append((path.stem, meta, body))
    out.sort(key=lambda p: int(p[1]["order"]) if p[1].get("order", "").isdigit() else 999)
    return out


def _fill(template: str, values: dict[str, str]) -> str:
    return re.sub(r"\{\{(\w+)\}\}", lambda m: values.get(m.group(1), ""), template)


def find_template(root: Path) -> Path:
    own = root / "template.html"
    return own if own.exists() else HERE / "template.html"


def _brand(root: Path) -> tuple[bool, bool]:
    return ((root / "assets/brand/icon-light.png").exists(),
            (root / "assets/brand/icon-dark.png").exists())


def _picture(prefix: str, dark: bool, css_class: str = "") -> str:
    cls = f' class="{css_class}"' if css_class else ""
    source = (f'<source srcset="{prefix}assets/brand/icon-dark.png" '
              f'media="(prefers-color-scheme: dark)">') if dark else ""
    return f'<picture{cls}>{source}<img src="{prefix}assets/brand/icon-light.png" alt=""></picture>'


def build(root: Path, title: str = DEFAULT_TITLE) -> dict[str, str]:
    """All pages in memory, keyed by their path relative to the output directory."""
    template = find_template(root).read_text(encoding="utf-8")
    langs = languages(root)
    has_light, has_dark = _brand(root)
    has_flag = {lang: (root / "assets/flags" / f"{lang}.png").exists() for lang in langs}
    by_lang = {lang: _pages_for(root, lang) for lang in langs}
    result: dict[str, str] = {}
    for lang in langs:
        pages = by_lang[lang]
        for index, (name, meta, body) in enumerate(pages):
            nav = "".join(
                f'<li><a href="{n}.html"{_current(n == name, "page")}>'
                f"{html.escape(m.get('title', n))}</a></li>" for n, m, _ in pages)
            prev_link = next_link = ""
            if index > 0:
                p = pages[index - 1]
                prev_link = (f'<a class="prev" href="{p[0]}.html"><span>{ui(lang)["prev"]}</span>'
                             f"{html.escape(p[1].get('title', p[0]))}</a>")
            if index + 1 < len(pages):
                n = pages[index + 1]
                next_link = (f'<a class="next" href="{n[0]}.html"><span>{ui(lang)["next"]}</span>'
                             f"{html.escape(n[1].get('title', n[0]))}</a>")
            switcher = "".join(
                f'<a href="../{other}/{name}.html" lang="{other}" title="{html.escape(LANG_NAMES.get(other, other))}"'
                f'{_current(other == lang, "true")}>'
                + (f'<img src="../assets/flags/{other}.png" alt="{html.escape(LANG_NAMES.get(other, other))}">'
                   if has_flag[other] else html.escape(LANG_NAMES.get(other, other)))
                + "</a>"
                for other in langs if any(n == name for n, _, _ in by_lang[other]))
            result[f"{lang}/{name}.html"] = _fill(template, {
                "lang": lang,
                "dir": "rtl" if lang in RTL else "ltr",
                "title": html.escape(meta.get("title", name)),
                "summary": html.escape(meta.get("summary", "")),
                "site": html.escape(title),
                "manual": ui(lang)["manual"],
                "contents": ui(lang)["contents"],
                "language": ui(lang)["language"],
                "nav": nav,
                "switcher": switcher,
                "body": render_markdown(body, lang),
                "prev": prev_link,
                "next": next_link,
                "icon": '<link rel="icon" href="../assets/brand/icon-light.png">' if has_light else "",
                "logo": _picture("../", has_dark) if has_light else "",
            })
    result["index.html"] = _chooser(root, langs, title, has_light, has_dark)
    return result


def _current(flag: bool, value: str) -> str:
    return f' aria-current="{value}"' if flag else ""


def _chooser(root: Path, langs: list[str], title: str, has_light: bool, has_dark: bool) -> str:
    cards = "".join(
        f'<a class="choice" href="{lang}/index.html" lang="{lang}" dir="{"rtl" if lang in RTL else "ltr"}">'
        + (f'<img src="assets/flags/{lang}.png" alt="">' if (root / "assets/flags" / f"{lang}.png").exists() else "")
        + f'<span>{ui(lang)["manual"]}</span><small>{html.escape(LANG_NAMES.get(lang, lang))}</small></a>'
        for lang in langs)
    icon = '<link rel="icon" href="assets/brand/icon-light.png">\n' if has_light else ""
    logo = (_picture("", has_dark, "logo") + "\n") if has_light else ""
    return (
        '<!doctype html>\n<html lang="en" dir="ltr">\n<head>\n<meta charset="utf-8">\n'
        '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
        f"<title>{html.escape(title)}</title>\n{icon}"
        '<link rel="stylesheet" href="assets/manual.css">\n</head>\n'
        f'<body class="chooser">\n<main>\n{logo}<h1>{html.escape(title)}</h1>\n'
        f'<nav class="choices">{cards}</nav>\n</main>\n</body>\n</html>\n')


# ---------------------------------------------------------------- checks

def _norm(label: str) -> str:
    return label.strip().rstrip(":…").strip()


def load_labels(path: Path) -> dict[str, set[str]]:
    data = json.loads(path.read_text(encoding="utf-8"))
    # a text with values ("Table covered: {value}") also counts by its words before the first value
    return {lang: {_norm(v) for v in vals} | {_norm(v.split("{")[0]) for v in vals if "{" in v}
            for lang, vals in data.items()}


def check_site(root: Path, pages: dict[str, str], labels: dict[str, set[str]] | None) -> list[str]:
    problems: list[str] = []
    langs = languages(root)
    stems = {lang: {p.stem for p in (root / "content" / lang).glob("*.md")} for lang in langs}
    for lang in langs:
        for name in sorted(set().union(*stems.values()) - stems[lang]):
            problems.append(f"missing page: {lang}/{name}.md")
        seen_orders: dict[str, str] = {}
        for name in sorted(stems[lang]):
            meta, _ = parse_front_matter((root / "content" / lang / f"{name}.md").read_text(encoding="utf-8"))
            for key in ("title", "order", "summary"):
                if not meta.get(key):
                    problems.append(f"{lang}/{name}.md: front matter lacks {key}")
            order = meta.get("order", "")
            if order in seen_orders:
                problems.append(f"{lang}/{name}.md: order {order} also used by {seen_orders[order]}")
            seen_orders[order] = name
    for rel, text in pages.items():
        if "http://" in text or "https://" in text:
            problems.append(f"{rel}: external URL")
        for m in re.finditer(r'(?:src|srcset|href)="([^"]+)"', text):
            target = m.group(1)
            if _SCHEME.match(target):
                continue
            file_part, _, anchor = target.partition("#")
            dest = posixpath.normpath(posixpath.join(posixpath.dirname(rel), file_part)) if file_part else rel
            default = dest.removeprefix("assets/") in DEFAULT_ASSETS
            if dest not in pages and not default and not (dest.startswith("assets/") and (root / dest).is_file()):
                kind = "missing image" if re.search(r"\.(png|jpe?g|gif|svg|webp)$", target) else "broken link"
                problems.append(f"{rel}: {kind} {target}")
                continue
            if anchor and dest in pages and f'id="{anchor}"' not in pages[dest]:
                problems.append(f"{rel}: missing anchor {target}")
        lang = rel.split("/")[0] if "/" in rel else None
        if labels is not None and lang:
            known = labels.get(lang, set())
            for m in re.finditer(r'<span class="ui">([^<]+)</span>', text):
                label = html.unescape(m.group(1))
                if _norm(label) not in known:
                    problems.append(f"{rel}: not a {lang} label of the application: {label}")
    return problems


# ---------------------------------------------------------------- main

def _inside(path: Path, parent: Path) -> bool:
    return path == parent or parent in path.parents


def write_site(root: Path, out: Path, pages: dict[str, str]) -> None:
    for lang in languages(root):  # pages removed from the sources go from the site too
        shutil.rmtree(out / lang, ignore_errors=True)
    out.mkdir(parents=True, exist_ok=True)
    (out / "assets").mkdir(parents=True, exist_ok=True)
    for name in DEFAULT_ASSETS:  # defaults, overridden by the root's own assets
        shutil.copy2(HERE / name, out / "assets" / name)
    if (root / "assets").is_dir():
        shutil.copytree(root / "assets", out / "assets", dirs_exist_ok=True)
    for rel, text in pages.items():
        path = out / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--root", type=Path, required=True, help="manual directory (content/, assets/)")
    parser.add_argument("--out", type=Path, help="output directory (required unless --check)")
    parser.add_argument("--title", default=DEFAULT_TITLE, help=f'site title (default: "{DEFAULT_TITLE}")')
    parser.add_argument("--check", action="store_true", help="check only; write nothing")
    parser.add_argument("--labels", type=Path, help='JSON {"lang": ["label", ...]}')
    args = parser.parse_args(argv)
    root = args.root.resolve()
    if not (root / "content").is_dir():
        parser.error(f"{root}/content does not exist")
    if not args.check:
        if args.out is None:
            parser.error("--out is required unless --check is given")
        out = args.out.resolve()
        if _inside(out, root / "content") or _inside(root / "content", out) or _inside(root / "assets", out):
            parser.error("--out must not contain or lie inside the source content or assets")
    pages = build(root, args.title)
    if args.check:
        labels = load_labels(args.labels) if args.labels else None
        problems = check_site(root, pages, labels)
        for p in problems:
            print(p)
        return 1 if problems else 0
    write_site(root, out, pages)
    print(f"wrote {len(pages)} pages")
    return 0


if __name__ == "__main__":
    sys.exit(main())
