TEX := main.tex frontmatter.tex $(wildcard sections/*.tex)

# Tectonic (fetches LaTeX packages on demand, runs BibTeX itself). On this workstation it is in
# the conda env "latex": mamba create -n latex -c conda-forge tectonic
TECTONIC ?= $(firstword $(shell command -v tectonic) $(wildcard $(HOME)/miniforge3/envs/latex/bin/tectonic))

all: main.pdf

main.pdf: $(TEX) refs.bib $(wildcard figures/*/*)
	$(TECTONIC) --keep-logs main.tex
	@grep -E 'undefined|Citation .* undefined|multiply defined' main.log || echo "no undefined references or citations"

clean:
	rm -f main.aux main.bbl main.blg main.log main.out main.toc main.pdf

.PHONY: all clean
