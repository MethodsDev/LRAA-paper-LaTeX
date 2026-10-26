# LRAA manuscript (LaTeX)

Converted on 2026-10-19 from the Google Doc (`__biorxiv/LRAA-2026-draft.docx` in the analysis repo,
which is frozen: "moving to LaTeX, Oct192026 - no more edits here"). From here on these `.tex` files
are the source of truth.

This repo is the Overleaf project: `main.tex` sits at the root, and every path in it is relative to
the root. It is also a submodule of the paper's analysis repo (`LRAA_PAPER_Analyses`, at
`LRAA-paper-LaTeX/`), where the results traceability (`PAPER_RESULTS_TRACEABILITY.md`) and the
figure builds live. Paths below that start with `<analysis repo>/` are in that repo.

## Build

On Overleaf: import this GitHub repo (New Project > Import from GitHub). The main document is
`main.tex`, and the default compiler (pdfLaTeX) is the intended one. The PDF is not tracked here;
Overleaf and `make` each build their own.

Locally:

```bash
make            # -> main.pdf
```

The Makefile runs [Tectonic](https://tectonic-typesetting.github.io), which fetches LaTeX packages
on demand and runs BibTeX itself (XeTeX engine). If your TeX Live is a bare install that cannot
build the document, put Tectonic in a conda env named `latex`
(`mamba create -n latex -c conda-forge tectonic`); the Makefile finds it there. The preamble
switches on the engine, so the same `main.tex` builds with pdfLaTeX + BibTeX on Overleaf.

## Layout

| file | contents |
|---|---|
| `main.tex` | preamble, then `\input`s the parts below in order |
| `frontmatter.tex` | title, authors, affiliations |
| `sections/abstract.tex` | abstract (the Google Doc's "long version") |
| `sections/abstract_short.tex` | the doc's "shortest version for NBT"; not included (uncomment in `main.tex`) |
| `sections/{introduction,results,discussion,methods}.tex` | main text; Table 1 is in the introduction |
| `sections/backmatter.tex` | acknowledgements, contributions, AI disclosure, data resources table |
| `sections/supplement.tex` | supplementary figures (numbered Supplementary Figure 1, 2, ...) |
| `refs.bib` | references (keys: first-author surname + year, e.g. `kovaka2019`) |
| `figures/docx_export/` | the figure images as they were in the Google Doc |
| `tools/` | the one-time conversion (kept for provenance; see below) |

## Conventions

- Cite with `\citep{key}` (parenthetical) or `\citet{key}` (textual); add new references to `refs.bib`.
- Refer to figures by label: `Figure~\ref{fig:5}d` (`Fig.~\ref{fig:1}` in two places), `Supplementary Figure~\ref{sfig:4}`. Numbers
  follow the order of the figures in the text.
- Figure legends are `\captionof{figure}{...}` right after the image, in the text flow rather than
  in a float, because most legends are too long to share a page with their figure.
- Open items carried over from the Google Doc:
  - `\pending{...}`: text that was highlighted in the doc, shown in orange. There are 8: two
    author names (Bartlett, Brookhart), the FLAMES citation twice (Table 1 and its footnote), the
    union-find sentence in Methods, and three `°` signs in the MORF methods, which look like
    stray highlights. The highlight on the FTD data-generation heading covered no text and was
    dropped.
  - `\doccomment{who}{date}{text}`: the doc's 15 comments (14 from Houlin, 1 reply from Brian), where they were anchored. Shown
    in red; `\showcommentsfalse` in `main.tex` hides them all. Delete each one once it is resolved.

## Figures

All figures are still the images from the Google Doc. Replacing them with the figures the analysis
repo builds (current LRAA version) is a separate step. The paths are in the analysis repo:

| figure | now | built in the analysis repo |
|---|---|---|
| Fig 1 (LRAA overview) | `Fig1.png` | no (schematic) |
| Fig 2 (sims, SIRVs, MORFs) | `Fig2.png` | `__PaperFigs/benchmark_figs/Fig2_benchmarks_sims_SIRVs_MORFs.pdf` |
| Fig 3 (cell lines) | `Fig3.png` | `__PaperFigs/benchmark_figs/Fig3_benchmarks_cell_lines.pdf` |
| Fig 4 (sc pipeline) | `Fig4.png` | no (schematic) |
| Fig 5 (PBMC) | `Fig5.png` | panels only: `PBMCs_kinnex/LRAA_PBMCs_eval/__Paper_Figures/` (AIF1, SELENOH; the doc shows AIF1 and EMP3) |
| Fig 6 (FTD/ALS) | `Fig6.png` | panels only: `ALS_LP00714/ALS_LRAA_eval/__Paper_Figures/` (STMN2, ATP5MJ; the doc shows STMN2 and EIF1) |
| Supp Fig 1 (algorithm) | `SuppFig1.png` | no (schematic) |
| Supp Fig 2 (sim error rates) | `SuppFig2.png` | `__PaperFigs/benchmark_figs/SuppFig2_benchmarks_sim_error_rates.pdf` |
| Supp Fig 3 (SIRV E0/E2) | `SuppFig3.png` | `__PaperFigs/benchmark_figs/SuppFig3_benchmarks_SIRVs_E0_E2.pdf` |
| Supp Fig 4 (MORFs) | `SuppFig4.png` | panel b only: `__PaperFigs/benchmark_figs/SuppFig4b_benchmarks_MORFs_ONT.pdf` |
| Supp Fig 5 (SQANTI-like scheme) | `SuppFig5.png` | no (schematic) |
| Supp Fig 6, 7 (proteoforms) | `SuppFig6.jpg`, `SuppFig7.jpg` | no |

## The conversion (`tools/`)

Run from this repo checked out as `LRAA-paper-LaTeX/` in the analysis repo, whose `__biorxiv/`
holds the docx:

```bash
python3 tools/build_bib.py ../__biorxiv/LRAA-2026-draft.docx .        # refs.bib, tools/keys.tsv
KEYS=tools/keys.tsv FIGDIR=figures/docx_export IMGLOG=build/images.tsv \
  pandoc ../__biorxiv/LRAA-2026-draft.docx --track-changes=all --natbib \
  -L tools/docx2tex.lua -t latex --wrap=none -o build/body.tex
python3 tools/split_body.py build/body.tex .                          # frontmatter.tex, sections/
```

Running it again overwrites the edited `.tex` files, so it is history, not a build step.

- **Citations:** Paperpile citation links became `\citep`, and its reference list became `refs.bib`.
  One citation (Haas et al. 2003, PASA) came from a different Paperpile library and was missing
  from the doc's reference list, so `build_bib.py` adds it.
- **Equations:** the doc's equation images were rebuilt as LaTeX from the source stored in their
  links.
- **Tracked changes:** Houlin's 3 pending suggestions (the insertions "supporting" ×2 and
  "gtf" → "GTF") were accepted.
- **Dropped:** the two bracketed editorial notes at the top of the doc.
- **Changed:**
  - The "Abstract (long version)" heading is now just "Abstract".
  - Discussion was promoted from a subsection of Results to a section.
  - The references come before the Supplementary Figures; the doc had them after.
