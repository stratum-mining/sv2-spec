
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

