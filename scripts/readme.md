
# README Generator Script

This `generate-readme.sh` script updates `README.md` by generating a Table of Contents (ToC) from all Markdown files in the repository.
It replaces the `[table_of_contents]` placeholder in `README.template.md` with the generated index.

## Usage

```bash
./scripts/generate-readme.sh [option]
```

Options:

* `--check` : verify if `README.md` is up to date (exit 1 if not).
* `--bless` : regenerate and overwrite `README.md`.

## Notes

* `README.template.md` must contain `[table_of_contents]`.
* Run `--check` before committing to ensure the ToC is current.

# Book Builder Script

This `build-book.sh` script renders the specification as an [mdbook](https://rust-lang.github.io/mdBook/).
It stages the spec chapters, `extensions/` and `img/` into `book/src` and runs `mdbook` with `book/book.toml`.
The output is written to `book/build`, which `.github/workflows/deploy-mdbook.yml` deploys to GitHub Pages on every push to `main`.

## Usage

```bash
./scripts/build-book.sh [build|serve]
```

* `build` (default): render the book into `book/build`.
* `serve`: render and serve the book at `http://localhost:3000`.

## Notes

* New chapters or extensions MUST be added to `book/SUMMARY.md`; the script fails otherwise.
* `serve` watches the staged copy, so re-run the script to pick up edits to the spec files.
