TEX := main.tex frontmatter.tex $(wildcard sections/*.tex)

# Tectonic (fetches LaTeX packages on demand, runs BibTeX itself). On this workstation it is in
# the conda env "latex": mamba create -n latex -c conda-forge tectonic
TECTONIC ?= $(firstword $(shell command -v tectonic) $(wildcard $(HOME)/miniforge3/envs/latex/bin/tectonic))

all: main.pdf

main.pdf: $(TEX) refs.bib $(wildcard figures/*/*)
	$(TECTONIC) --keep-logs main.tex
	@grep -E 'undefined|Citation .* undefined|multiply defined' main.log || echo "no undefined references or citations"

# Refresh the benchmark figures from the analysis repo (this repo checked out as its submodule
# LRAA-paper-LaTeX/). Rebuild them there first: make in __PaperFigs/benchmark_figs/.
BMARK_FIGS := Fig2_benchmarks_sims_SIRVs_MORFs Fig3_benchmarks_cell_lines \
	SuppFig2_benchmarks_sim_error_rates SuppFig3_benchmarks_SIRVs_E0_E2 SuppFig4b_benchmarks_MORFs_ONT
BMARK_SRC ?= ../__PaperFigs/benchmark_figs
# assembled main figures (__PaperFigs/main_figs/: make there first)
MAIN_FIGS := Fig5
MAIN_SRC ?= ../__PaperFigs/main_figs

sync-figs:
	@test -d $(BMARK_SRC) || { echo "no $(BMARK_SRC): run from the analysis repo's submodule"; exit 1; }
	cp $(addprefix $(BMARK_SRC)/,$(addsuffix .pdf,$(BMARK_FIGS))) figures/benchmark/
	cp $(addprefix $(MAIN_SRC)/,$(addsuffix .pdf,$(MAIN_FIGS))) figures/main/

clean:
	rm -f main.aux main.bbl main.blg main.log main.out main.toc main.pdf

.PHONY: all clean sync-figs
