# CineExplorer — Notebooks

Exploratory data analysis to support ERD design decisions for the official IMDb migration. This folder is **auxiliary** — not part of the migration MIG-tasks. Findings are distilled into `docs/raw_imdb_analysis.md` (the durable artifact); the notebook is the workshop.

---

## Setup (UV)

```bash
cd notebooks
uv sync                          # creates .venv/ and installs deps
uv run jupyter lab               # interactive
# OR
uv run python 01_imdb_raw_analysis.py   # run as a script (jupytext py:percent)
```

UV reads `pyproject.toml` and pins exact versions on first run. Re-running on another machine reproduces the same env.

---

## Files

| File | Purpose |
|------|---------|
| `pyproject.toml` | UV project metadata + deps (polars, pandas, matplotlib, jupyter, jupytext) |
| `01_imdb_raw_analysis.py` | Source-of-truth analysis (jupytext `py:percent` format — round-trippable to `.ipynb`) |
| `01_imdb_raw_analysis.ipynb` | Generated notebook for interactive use |
| `output/` | Generated tables / plots (gitignored) |

---

## Notebook commit policy

- **`.py` is the source of truth.** All analysis logic lives there in jupytext `py:percent` format. Edit either the `.py` or the `.ipynb` — `jupytext` keeps them in sync via the `[tool.jupytext]` config in `pyproject.toml`.
- **`.ipynb` is committed without outputs.** Strip outputs before committing: `uv run jupyter nbconvert --clear-output --inplace 01_imdb_raw_analysis.ipynb` (or use `nbstripout` as a pre-commit hook).
- **`output/` is gitignored.** Tables and plots regenerate on every run.
- **Findings live in `docs/raw_imdb_analysis.md`**, not in committed notebook outputs.

---

## Data dependencies

The notebook reads from `../database/sources/imdb-official/raw/*.tsv.gz`. If those files are missing, run `bash database/etl/download.sh` from the repo root first (Phase 1 prerequisite — see `database/etl/README.md`).
