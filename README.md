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

`figures/benchmark/` holds the benchmark figures the analysis repo builds, copied in so Overleaf
can see them. They are on LRAA v0.45.0-f8db47e (copied 2026-10-26). To refresh them, rebuild
`<analysis repo>/__PaperFigs/benchmark_figs/` and run `make sync-figs` here. The other figures are
still the Google Doc images in `figures/docx_export/`. `figures/fixed/` holds supplied panels that no script builds (schematics, renders); they carry no panel letters, which the LaTeX or the assembly adds.

| figure | in the paper | built in the analysis repo |
|---|---|---|
| Fig 1 (LRAA overview) | `docx_export/Fig1.png` | no (schematic) |
| Fig 2 (sims, SIRVs, MORFs) | `benchmark/Fig2_benchmarks_sims_SIRVs_MORFs.pdf` | `__PaperFigs/benchmark_figs/` |
| Fig 3 (cell lines) | `benchmark/Fig3_benchmarks_cell_lines.pdf` | `__PaperFigs/benchmark_figs/` |
| Fig 4 (sc pipeline) | `docx_export/Fig4.png` | no (schematic) |
| Fig 5 (PBMC) | `main/Fig5.pdf` | `__PaperFigs/main_figs/Fig5.tex` assembles the eval tree's panels (heatmap, AIF1 and SELENOH blocks) with `fixed/` (UMAP, AIF1 structure) |
| Fig 6 (FTD/ALS) | `main/Fig6.pdf` | `__PaperFigs/main_figs/Fig6.tex` assembles the eval tree's panels (cluster dendrogram, STMN2 and ATP5MJ blocks) with `fixed/` (UMAP) |
| Supp Fig 1 (algorithm) | `docx_export/SuppFig1.png` | no (schematic) |
| Supp Fig 2 (sim error rates) | `benchmark/SuppFig2_benchmarks_sim_error_rates.pdf` | `__PaperFigs/benchmark_figs/` |
| Supp Fig 3 (SIRV E0/E2) | `benchmark/SuppFig3_benchmarks_SIRVs_E0_E2.pdf` | `__PaperFigs/benchmark_figs/` |
| Supp Fig 4 (MORFs) | a: `fixed/Supp_Fig_4-MORFsGenomeView.pdf` (supplied, not built); b: `benchmark/SuppFig4b_benchmarks_MORFs_ONT.pdf` | panel b only |
| Supp Fig 5 (SQANTI-like scheme) | `docx_export/SuppFig5.png` | no (schematic) |
| Supp Fig 6 (read and isoform categories, PBMC and FTD; were Figs 5a,b and 6a,b) | `supp/SuppFig_categories.pdf` | `__PaperFigs/supp_figs/SuppFig_categories.R` |
| Supp Fig 7, 8 (proteoforms) | `supp/SuppFig_proteoforms_PBMC.pdf`, `supp/SuppFig_proteoforms_FTD.pdf` | `LRAA_proteoform_analyses/LRAA_proteoform_analysis_PBMC_ALS_20260528.ipynb` (v0.45.0 ORFs) |

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
