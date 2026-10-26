#!/usr/bin/env python3
"""One-time conversion: build refs.bib from the Paperpile reference list of the Google Docs export.

The docx bibliography is APA text, one entry per paragraph, each linked to
http://paperpile.com/b/<lib>/<ID>; in-text citations link to paperpile.com/c/<lib>/<ID>+<ID>.
Writes refs.bib (keys = first-author surname + year) and keys.tsv (Paperpile ID -> bib key),
which the pandoc filter docx2tex.lua reads to turn citation links into \\citep{}.

usage: build_bib.py draft.docx out_dir
"""
import re, subprocess, sys, unicodedata
from collections import OrderedDict

docx, outdir = sys.argv[1], sys.argv[2]
md = subprocess.run(["pandoc", docx, "-t", "markdown", "--wrap=none"],
                    capture_output=True, text=True, check=True).stdout

entries = OrderedDict()
for m in re.finditer(r"^# \[(.*)\]\(http://paperpile\.com/b/\w+/(\w+)\)\s*$", md, re.M):
    entries[m.group(2)] = m.group(1).replace("\\[", "[").replace("\\]", "]")


def latexify(s):
    s = s.replace("\\'", "'").replace('\\"', '"')
    s = re.sub(r"([&%#_$])", r"\\\1", s)
    s = re.sub(r"\*([^*]+)\*", r"\\textit{\1}", s)
    return s.replace("--", "--")


INIT = re.compile(r"^(?:[A-Z][a-z]?\.(?:[\s-]|$))+$")


def parse_authors(a):
    a = a.strip().rstrip(",")
    # APA 7 lists 19 authors, "...", then the last author: keep the 19, then "others"
    others = "..." in a
    a = a.split("...")[0].replace("& ", "")
    toks = [t.strip() for t in a.split(",") if t.strip()]
    names, i = [], 0
    while i < len(toks):
        sur = toks[i]
        if i + 1 < len(toks) and INIT.match(toks[i + 1] + (" " if not toks[i + 1].endswith(".") else "")):
            names.append(f"{sur}, {toks[i + 1]}")
            i += 2
            if i < len(toks) and toks[i].rstrip(".") == "Jr":  # "Welch, K. C., Jr" -> "Welch, Jr, K. C."
                names[-1] = f"{sur}, Jr, {names[-1].split(', ', 1)[1]}"
                i += 1
        else:
            names.append("{" + sur + "}")
            i += 1
    if others:
        names.append("others")
    return names


def ascii_key(s):
    s = unicodedata.normalize("NFKD", s).encode("ascii", "ignore").decode()
    return re.sub(r"[^a-z]", "", s.lower())


bib, keymap, used = [], {}, {}
for pid, t in entries.items():
    rec = {}
    m = re.match(r"^(.*?)\s*\((\d{4}[a-z]?|n\.d\.)\)\.\s*(.*)$", t)
    if m and not m.group(1).startswith("*"):
        authors, year, rest = m.groups()
        rec["author"] = " and ".join(parse_authors(authors))
        first = authors.split(",")[0]
    else:
        # "*Title*. (n.d.). Publisher. Retrieved ..." (no author)
        m2 = re.match(r"^\*(.+?)\*\.\s*\((\d{4}|n\.d\.)\)\.\s*(.*)$", t)
        if not m2:
            sys.exit(f"cannot parse reference {pid}: {t}")
        title, year, rest = m2.groups()
        rec["title"] = latexify(title)
        first = title.split()[0]
        authors = None
    rec["year"] = year if year != "n.d." else "n.d."
    doi = re.search(r"https://doi\.org/(\S+?)\.?$", rest)
    url = None if doi else re.search(r"(https?://\S+?)\.?$", rest)
    rest_nolink = re.sub(r"\s*https?://\S+$", "", rest).strip()
    etype = "misc"
    if "title" not in rec:
        mt = re.match(r"^\*(.+?)\*\.?\s*(.*)$", rest_nolink)  # italic title: software / book
        if mt:
            rec["title"] = latexify(mt.group(1))
            pub = re.sub(r"\s*Retrieved .*? from$", "", mt.group(2)).strip(" .")
            if pub:
                rec["howpublished"] = latexify(pub)
        else:
            mj = re.match(r"^(.*?[.?!])\s+(In\s+)?\*(.+?)\*(.*)$", rest_nolink)
            if mj:
                rec["title"] = latexify(mj.group(1).rstrip("."))
                rec["journal"] = latexify(mj.group(3))
                if mj.group(2) and url and "biorxiv.org" in url.group(1):  # "In *Neuroscience*" = bioRxiv subject area
                    rec["journal"] = "bioRxiv"
                tail = mj.group(4)
                mv = re.match(r"^,\s*\*([^*]+)\*(?:\(([^)]+)\))?(?:,\s*([^.]+))?", tail)
                if mv:
                    rec["volume"] = latexify(mv.group(1))
                    if mv.group(2):
                        rec["number"] = latexify(mv.group(2))
                    if mv.group(3):
                        rec["pages"] = latexify(mv.group(3).strip())
                etype = "article"
            else:
                rec["title"] = latexify(rest_nolink.rstrip("."))
    else:
        pub = re.sub(r"\s*Retrieved .*? from$", "", rest_nolink).strip(" .")
        if pub:
            rec["howpublished"] = latexify(pub)
    ret = re.search(r"Retrieved ([A-Z][a-z]+ \d+, \d{4})", t)
    if ret:
        rec["note"] = f"Accessed {ret.group(1)}"
    if doi:
        rec["doi"] = doi.group(1)
    if url:
        rec["url"] = url.group(1)
    base = ascii_key(first) + (rec["year"] if rec["year"][0].isdigit() else "nd")
    n = used.get(base, 0)
    used[base] = n + 1
    key = base if n == 0 else base + "abcdefghij"[n]
    keymap[pid] = key
    rec["title"] = "{" + rec["title"] + "}"
    fields = ",\n".join(f"  {k:<12} = {{{v}}}" for k, v in rec.items())
    bib.append((key, f"@{etype}{{{key},\n{fields}\n}}\n"))

# Cited in the text from a different Paperpile library, so absent from the doc's reference list.
EXTRA = {"96co": ("haas2003", """@article{haas2003,
  author       = {Haas, B. J. and Delcher, A. L. and Mount, S. M. and Wortman, J. R. and Smith, Jr, R. K. and Hannick, L. I. and Maiti, R. and Ronning, C. M. and Rusch, D. B. and Town, C. D. and Salzberg, S. L. and White, O.},
  year         = {2003},
  title        = {{Improving the Arabidopsis genome annotation using maximal transcript alignment assemblies}},
  journal      = {Nucleic Acids Research},
  volume       = {31},
  number       = {19},
  pages        = {5654--5666},
  doi          = {10.1093/nar/gkg770}
}
""")}
for pid, (key, entry) in EXTRA.items():
    keymap[pid] = key
    bib.append((key, entry))

with open(f"{outdir}/refs.bib", "w") as fh:
    fh.write("% Converted from the Paperpile reference list of LRAA-2026-draft.docx (2026-10-19).\n"
             "% Keys: first-author surname + year. tools/keys.tsv maps the Paperpile IDs.\n\n")
    for _, e in sorted(bib):
        fh.write(e + "\n")
with open(f"{outdir}/tools/keys.tsv", "w") as fh:
    for pid, key in keymap.items():
        fh.write(f"{pid}\t{key}\n")
print(f"{len(entries)} references -> {outdir}/refs.bib", file=sys.stderr)
