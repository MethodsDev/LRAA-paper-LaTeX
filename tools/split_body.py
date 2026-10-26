#!/usr/bin/env python3
"""One-time conversion: split the pandoc output (build/body.tex) into the manuscript's files.

  frontmatter.tex           title, authors, affiliations
  sections/abstract.tex     the long abstract
  sections/abstract_short.tex  the short (NBT) abstract; not \\input by main.tex
  sections/introduction.tex, results.tex, discussion.tex, methods.tex
  sections/backmatter.tex   acknowledgements, contributions, data resources table
  sections/supplement.tex   supplementary figures

usage: split_body.py build/body.tex outdir
"""
import re, sys

body, outdir = open(sys.argv[1]).read(), sys.argv[2]


def cut(text, start, end=None):
    i = text.index(start)
    j = text.index(end, i) if end else len(text)
    return text[i:j], text[:i] + text[j:]


front, rest = body.split("\\section{Abstract (long version)}", 1)
rest = "\\section{Abstract (long version)}" + rest

# --- front matter: first paragraph is the title ----------------------------------------
paras = front.strip().split("\n\n")
title, others = paras[0].replace("\\\\\n", " "), paras[1:]
front_tex = ("% Title, authors and affiliations (from LRAA-2026-draft.docx, 2026-10-19)\n"
             "\\begin{center}\n{\\LARGE\\bfseries " + title + "\\par}\n\\end{center}\n\n"
             + "\n\n".join(others) + "\n")

sections = {}
abstract, rest = cut(rest, "\\section{Abstract (long version)}", "\\section{Introduction}")
long_abs, short_abs = abstract.split("\\textbf{Abstract (shortest version for NBT)}")
sections["abstract"] = "\\section*{Abstract}\n" + long_abs.split("\n", 1)[1].strip() + "\n"
sections["abstract_short"] = ("% Short abstract (\"shortest version for NBT\" in the Google Doc); "
                              "not included by main.tex\n\\section*{Abstract}\n" + short_abs.strip() + "\n")

intro, rest = cut(rest, "\\section{Introduction}", "\\section{Results}")
sections["introduction"] = intro
results, rest = cut(rest, "\\section{Results}", "\\subsection{Discussion}")
sections["results"] = results
disc, rest = cut(rest, "\\subsection{Discussion}", "\\section{Methods}")
sections["discussion"] = disc.replace("\\subsection{Discussion}", "\\section{Discussion}", 1)
methods, rest = cut(rest, "\\section{Methods}", "\\section{Acknowledgements}")
sections["methods"] = methods
m = re.search(r"\\section\{\\texorpdfstring\{\\hfill\\break\s*Supplementary Figures\}.*?\n", rest)
back, supp = rest[:m.start()], rest[m.end():]
sections["backmatter"] = back
sections["supplement"] = ("\\clearpage\n\\section*{Supplementary Figures}\n"
                          "\\setcounter{figure}{0}\n\\renewcommand{\\figurename}{Supplementary Figure}\n\n"
                          + supp.lstrip())
if rest.strip() == "":
    sys.exit("nothing left for the supplement")

with open(f"{outdir}/frontmatter.tex", "w") as fh:
    fh.write(front_tex)
for name, text in sections.items():
    with open(f"{outdir}/sections/{name}.tex", "w") as fh:
        fh.write(text.strip() + "\n")
print("wrote", ", ".join(sections), file=sys.stderr)
