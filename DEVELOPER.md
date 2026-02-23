# Living Doc Augmentor — Developer Guide

- [Get Started](#get-started)
- [Quality Gates](#quality-gates)
- [Run Individual Gates](#run-individual-gates)
- [Running Unit Tests](#running-unit-tests)
- [Running Integration Tests](#running-integration-tests)
- [Code Coverage](#code-coverage)
- [Run Action Locally](#run-action-locally)
- [Branch Naming Convention (PID:H-1)](#branch-naming-convention-pidh-1)

## Get Started

Clone the repository and navigate to the project directory:

```shell
git clone https://github.com/MoranaApps/living-doc-augmentor-gh.git
cd living-doc-augmentor-gh
```

Set up the Python environment:

```shell
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
pip install -r requirements-dev.txt
```

## Quality Gates

The project enforces quality gates via a `Makefile`. Run **all** gates locally before pushing:

```shell
# Sequential (safe default)
make qa

# Parallel (faster — lint, typecheck, fmt, complexity run simultaneously)
make qa-parallel
```

Or via the wrapper script (same thing, used in CI):

```shell
./scripts/run_qa.sh            # sequential
./scripts/run_qa.sh --parallel # parallel
```

### Gate Summary

| Gate | Threshold | Command |
|---|---|---|
| Pylint | ≥ 9.0 / 10 | `pylint living_doc_augmentor` |
| Ruff | Zero violations | `ruff check .` |
| mypy | Zero errors (strict) | `mypy living_doc_augmentor` |
| Black | Zero formatting violations | `black --check .` |
| Radon | Cyclomatic complexity ≤ B | `radon cc living_doc_augmentor -a -nb` |
| pytest | ≥ 95 % coverage | `pytest --cov=living_doc_augmentor --cov-fail-under=95 tests/` |
| pip-audit | Clean | `pip-audit -r requirements.txt` |

## Run Individual Gates

### Pylint

```shell
pylint living_doc_augmentor
```

To lint a specific file:

```shell
pylint living_doc_augmentor/scanner.py
```

### Ruff

```shell
ruff check .
```

### Black (Formatting)

Check formatting (no changes):

```shell
black --check .
```

Auto-format all files:

```shell
black .
```

Configuration is in `pyproject.toml` (line length: 120).

### mypy (Type Checking)

```shell
mypy living_doc_augmentor
```

To check a specific file:

```shell
mypy living_doc_augmentor/config.py
```

Configuration is in `pyproject.toml`.

### Radon (Complexity)

```shell
radon cc living_doc_augmentor -a -nb
```

No function should be rated C or worse.

## Running Unit Tests

Unit tests are written using pytest. To run the tests:

```shell
pytest tests/unit/
```

## Running Integration Tests

Integration tests use sample repository fixtures. They do not require secrets or network access.

```shell
pytest tests/integration/ -v
```

## Code Coverage

```shell
pytest --cov=living_doc_augmentor --cov-fail-under=95 tests/              # Check threshold
pytest --cov=living_doc_augmentor --cov-fail-under=95 --cov-report=html tests/  # HTML report
```

View the HTML report:

```shell
open htmlcov/index.html
```

## Run Action Locally

Run the action CLI locally (no GitHub Actions environment needed):

```shell
python main.py --regime augmentor --scan-mode full --config-path augmentation_types.yml --source-paths src/
```

With verbose output:

```shell
python main.py --regime augmentor --scan-mode full --config-path augmentation_types.yml --source-paths src/ --verbose
```

Run the collector:

```shell
python main.py --regime collector --config-path augmentation_types.yml --source-paths src/ --output-path code_augmentations.json
```

## Branch Naming Convention (PID:H-1)

All work branches MUST use an allowed prefix followed by a concise kebab-case descriptor (optional numeric ID):

Allowed prefixes:
- `feature/` — new functionality & enhancements
- `fix/` — bug fixes / defect resolutions
- `docs/` — documentation-only updates
- `chore/` — maintenance, CI, dependency bumps, non-behavioral refactors

Examples:
- `feature/add-multiline-annotation`
- `fix/456-config-validation-error`
- `docs/update-readme-quickstart`
- `chore/upgrade-pydantic`

Rules:
- Prefix mandatory; rename non-compliant branches before PR (`git branch -m feature/<new-name>` etc.).
- Descriptor lowercase kebab-case; hyphens only; avoid vague terms (`update`, `changes`).
- Align scope: a docs-only PR MUST use `docs/` prefix, not `feature/`.

Verification tip:

```shell
git rev-parse --abbrev-ref HEAD | grep -E '^(feature|fix|docs|chore)/' || echo 'Branch naming violation (expected allowed prefix)'
```

Future possible prefixes (not enforced yet): `refactor/`, `perf/`.
