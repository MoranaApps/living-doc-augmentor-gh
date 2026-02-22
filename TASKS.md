# TASKS.md — Living Doc Augmentor GitHub Action

> **Source of truth:** All tasks are derived from **SPEC.md §24 (Roadmap)**.
> Every task references the spec section it implements.
>
> **Quality gates** are defined per-task. A task is **done** when its own
> quality gate AND all listed acceptance criteria pass.
>
> **Status legend:**
> - ✅ Done
> - 🔄 In Progress
> - ⬜ Not Started
>
> **Global quality gates** (must pass on every task that touches code):
>
> | Gate | Threshold | Tool |
> |---|---|---|
> | Lint (pylint) | ≥ 9.0 / 10 | `pylint living_doc_augmentor` |
> | Lint (ruff) | Zero violations | `ruff check .` |
> | Type checking | Zero errors (strict) | `mypy living_doc_augmentor` |
> | Formatting | Zero violations | `black --check .` |
> | Complexity | ≤ Grade B (no C+) | `radon cc living_doc_augmentor -a -nb` |
> | Test coverage | ≥ 95 % | `pytest --cov --cov-fail-under=95` |
> | Dependency audit | Clean | `pip-audit -r requirements.txt` |
> | Full suite | All above | `make qa` |

---

## Phase 0 — Initial Repository Setup _(by project owner)_

> These tasks establish the bare repository. They are performed manually by the
> project owner before any development begins.

### T-0.1 Create GitHub repository ✅

- **Status:** ✅ Done (by owner)
- **Deliverables:** GitHub repo `MoranaApps/living-doc-augmentor-gh` exists.
- **Quality gate:** Repo accessible on GitHub; default branch created.

### T-0.2 Add LICENSE ✅

- **Status:** ✅ Done (by owner)
- **Deliverables:** `LICENSE` — Apache License 2.0.
- **Quality gate:** `LICENSE` file present at repo root; content matches Apache 2.0 text.

### T-0.3 Add .gitignore ✅

- **Status:** ✅ Done (by owner)
- **Deliverables:** `.gitignore` — Python-standard ignores.
- **Quality gate:** `.gitignore` present; covers `__pycache__/`, `*.pyc`, `dist/`, `.eggs/`, `venv/`, `.mypy_cache/`, `.pytest_cache/`, `htmlcov/`.

### T-0.4 Add initial README ✅

- **Status:** ✅ Done (by owner)
- **Deliverables:** `README.md` — project title.
- **Quality gate:** `README.md` present with project name.

### T-0.5 Add SPEC.md ✅

- **Status:** ✅ Done (by owner)
- **Deliverables:** `SPEC.md` — full project specification.
- **Quality gate:** `SPEC.md` present; contains all 24 sections.

---

## Phase 1 — POC: Scaffold & Core (v0.1.0) 🚀

> **Goal:** A working end-to-end action **and CLI tool** that can scan Python files
> and report violations for three starter types.
>
> **Estimated effort:** 2–2.5 weeks.
>
> **Phase-level quality gate:** All ACs 1.1–1.13 pass; `make qa` green; ≥ 95 % coverage.

---

### T-1.1 Repository scaffolding (~1 d) ⬜

- **Status:** ⬜ Not Started
- **Spec refs:** §16, §17
- **Deliverables:**
  - `Makefile` with targets: `qa`, `qa-parallel`, `lint`, `typecheck`, `fmt`, `complexity`, `test`, `audit`
  - `scripts/run_qa.sh` — CI-equivalent wrapper (supports `--parallel` flag)
  - `.github/workflows/ci.yml` — unit tests + linting (`workflow_dispatch`, `pull_request`)
  - `.github/workflows/integration_tests.yml` — integration tests (`workflow_dispatch`)
  - `.github/workflows/check_pr_title.yml` — PR title convention (`pull_request`)
  - `.github/workflows/release_draft.yml` — release draft automation
  - `.github/dependabot.yml` — automated dependency updates
  - `.github/copilot-instructions.md` — AI assistant project context
  - `CONTRIBUTING.md` — contributor guidelines
  - `DEVELOPER.md` — developer setup & architecture guide
  - `requirements.txt` — runtime dependencies
  - `requirements-dev.txt` — dev/test dependencies (incl. `radon`, `pip-audit`, `pytest-cov`)
  - `pyproject.toml` — project metadata, black/mypy/ruff/radon configuration
  - `.pylintrc` — pylint configuration
- **Quality gate:**
  - [ ] `make qa` target exists and is runnable (even if tests are empty/trivial)
  - [ ] `make qa-parallel` runs lint, typecheck, fmt, complexity in parallel
  - [ ] `scripts/run_qa.sh` exits 0 when run with no source files
  - [ ] All CI workflow YAML files pass `yamllint` / are valid GitHub Actions syntax
  - [ ] `dependabot.yml` targets `pip` ecosystem
  - [ ] `pyproject.toml` configures: `[tool.black]`, `[tool.mypy]` (strict), `[tool.ruff]`, `[tool.radon]`
  - [ ] `.pylintrc` present and importable by pylint
  - [ ] `requirements-dev.txt` includes: `pytest`, `pytest-cov`, `pylint`, `ruff`, `mypy`, `black`, `radon`, `pip-audit`

---

### T-1.2 Configuration loader (~2 d) ⬜

- **Status:** ⬜ Not Started
- **Spec refs:** §5.2, §9, §20.1
- **Deliverables:**
  - `living_doc_augmentor/config.py` — YAML loader + Pydantic validation
  - `living_doc_augmentor/models.py` — `AugmentationType`, `Config` data models
- **Quality gate:**
  - [ ] Valid `augmentation_types.yml` loads without errors
  - [ ] Invalid config (missing `name`) → exit code `2` with human-readable error on stderr
  - [ ] All §5.2 properties used by starter types validated: `name`, `target`, `required`, `file_patterns`, `description`, `severity`
  - [ ] `version` field validated at load time; incompatible version → exit code `2` (AC-1.9)
  - [ ] Unrecognized annotations matching `@<prefix>:<Name>(…)` but not in config → `::warning` (AC-1.8)
  - [ ] Unit tests: ≥ 95 % coverage of `config.py` and `models.py`
  - [ ] `pylint config.py` ≥ 9.0; `mypy config.py` zero errors; `ruff check config.py` clean

**Acceptance criteria:** AC-1.3, AC-1.8, AC-1.9

---

### T-1.3 Python-only location detection (~1 d) ⬜

- **Status:** ⬜ Not Started
- **Spec refs:** §6 (minimal subset), §7, §18.2
- **Deliverables:**
  - `living_doc_augmentor/location.py` — three-layer detection: file selection, Python targets, Python comments
  - `DetectionStrategy(Protocol)` interface (§18.2)
  - `RegexDetectionStrategy` — regex-based Python target detection
  - `DocstringDetectionStrategy` — Python `"""` docstring detection
- **Quality gate:**
  - [ ] Layer 1: `file_patterns` / `exclude_patterns` globs correctly filter files (AC-1.5)
  - [ ] Layer 2: Python targets detected: `class`, `function`, `method`, `module`
  - [ ] Layer 3: Python `#` comments and `"""` docstrings parsed (AC-1.6, AC-1.7)
  - [ ] Zero-blank-line association rule enforced (AC-1.13)
  - [ ] Case-sensitive matching — `@LivDoc:feature` ≠ `@LivDoc:Feature`
  - [ ] Inner parens allowed when unambiguous: `@LivDoc:Feature(F-1(beta))` → value `F-1(beta)`
  - [ ] `DetectionStrategy(Protocol)` interface defined — Phase 4 will extend, not replace
  - [ ] Unit tests: ≥ 95 % coverage of `location.py`
  - [ ] `pylint location.py` ≥ 9.0; `mypy location.py` zero errors

**Acceptance criteria:** AC-1.5, AC-1.6, AC-1.7, AC-1.13

---

### T-1.4 Core scanner (~1.5 d) ⬜

- **Status:** ⬜ Not Started
- **Spec refs:** §4.1, §4.2, §13
- **Deliverables:**
  - `living_doc_augmentor/scanner.py` — regex-based single-line annotation detection
  - `living_doc_augmentor/augmentor.py` — augmentor regime, full scan mode
  - `living_doc_augmentor/collector.py` — collector regime, JSON output
- **Quality gate:**
  - [ ] Augmentor: full scan mode, exit codes `0` (clean) / `1` (violations) / `2` (config error)
  - [ ] Augmentor: unannotated required target → violation (AC-1.1); all annotated → exit 0 (AC-1.2)
  - [ ] Collector: produces `code_augmentations.json` with `type`, `value`, `file`, `line` per annotation (AC-1.4)
  - [ ] Collector: includes `target_document` and `audience` metadata from type definitions
  - [ ] Collector: always operates in full-repo mode (§4.2 — `scan-mode` ignored for collector)
  - [ ] Unit tests: ≥ 95 % coverage of `scanner.py`, `augmentor.py`, `collector.py`
  - [ ] `pylint` ≥ 9.0; `mypy` zero errors; `ruff` clean — all three files

**Acceptance criteria:** AC-1.1, AC-1.2, AC-1.4

---

### T-1.5 CLI & local usage (~1 d) ⬜

- **Status:** ⬜ Not Started
- **Spec refs:** §12 (basic)
- **Deliverables:**
  - `main.py` — CLI entry point with argument parsing
- **Quality gate:**
  - [ ] CLI args: `--regime`, `--config-path`, `--scan-mode`, `--source-paths`, `--exclude-paths`, `--output-path`, `--fail-on-violations`, `--verbose`, `--dry-run`
  - [ ] Environment auto-detection: `GITHUB_ACTIONS` env var (§12.5) — CLI vs. action mode
  - [ ] CLI defaults differ from action defaults where specified (e.g., `scan-mode` defaults to `full` in CLI, `pr` in action)
  - [ ] CLI output: coloured terminal output for violations (red errors, yellow warnings) (AC-1.10)
  - [ ] Action mode: violations emitted as `::error`/`::warning` workflow commands (AC-1.11)
  - [ ] `INPUT_*` env var reading for composite action mode; CLI args take precedence
  - [ ] Unit tests: ≥ 95 % coverage of `main.py`
  - [ ] `pylint main.py` ≥ 9.0; `mypy main.py` zero errors

**Acceptance criteria:** AC-1.10, AC-1.11

---

### T-1.6 Diagnostic logging (~0.5 d) ⬜

- **Status:** ⬜ Not Started
- **Spec refs:** §19.4 (basic)
- **Deliverables:**
  - Logging setup integrated into existing modules (no separate file — wired in `main.py` / `scanner.py`)
- **Quality gate:**
  - [ ] Structured format: `[LEVEL] [TIMESTAMP] [COMPONENT] MESSAGE`
  - [ ] Component tags: `config`, `scanner`, `location`, `augmentor`, `collector`
  - [ ] Dual output: GitHub annotations → stdout, diagnostic log → stderr
  - [ ] `--verbose true` enables `DEBUG` level; default = `ERROR`/`WARNING`/`INFO` only (AC-1.12)
  - [ ] Unit tests verify log output format and verbosity toggle
  - [ ] `pylint` ≥ 9.0 on all modified files

**Acceptance criteria:** AC-1.12

---

### T-1.7 Action packaging (~0.5 d) ⬜

- **Status:** ⬜ Not Started
- **Spec refs:** §14, §21.5
- **Deliverables:**
  - `action.yml` — composite action definition
  - `README.md` — updated with quickstart example
- **Quality gate:**
  - [ ] `action.yml` is valid composite action YAML
  - [ ] `permissions: contents: read` declared (§21.5)
  - [ ] All inputs/outputs from §11 defined in `action.yml`
  - [ ] README includes quickstart workflow snippet
  - [ ] `action.yml` passes YAML lint

**Acceptance criteria:** _(none specific — packaging enables AC-1.11)_

---

### T-1.8 Starter types: Feature, AC, TestEvidence (~1 d) ⬜

- **Status:** ⬜ Not Started
- **Spec refs:** §5.2, §8
- **Deliverables:**
  - `examples/augmentation_types_starter.yml` — all three types fully configured
  - Type definitions using: `name`, `target`, `required`, `file_patterns`, `description`, `severity`
- **Quality gate:**
  - [ ] `Feature` type: detects/reports unannotated classes (AC-1.1, AC-1.2)
  - [ ] `AC` type: simple single-value (no `sub_values` yet — Phase 3)
  - [ ] `TestEvidence` type: configured and functional
  - [ ] Example config loads cleanly; no validation errors
  - [ ] Unit tests: ≥ 1 positive-match + ≥ 1 negative-match per type
  - [ ] `pylint` ≥ 9.0; `mypy` zero errors on any new/modified files

**Acceptance criteria:** AC-1.1, AC-1.2, AC-1.4

---

### T-1.9 Phase 1 quality gate (~0.5 d) ⬜

- **Status:** ⬜ Not Started
- **Spec refs:** §16
- **Deliverables:**
  - All Phase 1 code passing full quality suite
- **Quality gate (PHASE-LEVEL — all must pass):**
  - [ ] `make qa` exits 0 (all gates green)
  - [ ] `pylint living_doc_augmentor` ≥ 9.0
  - [ ] `ruff check .` — zero violations
  - [ ] `mypy living_doc_augmentor` — zero errors (strict mode)
  - [ ] `black --check .` — zero formatting violations
  - [ ] `radon cc living_doc_augmentor -a -nb` — no function rated C+
  - [ ] `pytest --cov=living_doc_augmentor --cov-fail-under=95 tests/` — ≥ 95 % coverage
  - [ ] `pip-audit -r requirements.txt` — clean
  - [ ] All ACs pass: AC-1.1 through AC-1.13

**Acceptance criteria:** AC-1.1 through AC-1.13

---

## Phase 2 — PR Mode, Reporting & Ignore Rules (v0.2.0)

> **Goal:** The action is usable in real PR workflows — developers can review
> violations and suppress false positives.
>
> **Estimated effort:** 1.5–2 weeks.
>
> **Phase-level quality gate:** All ACs 2.1–2.13 pass; `make qa` green; ≥ 95 % coverage.

---

### T-2.1 PR mode (~2 d) ⬜

- **Status:** ⬜ Not Started
- **Spec refs:** §4.1, §4.1.1, §12.2
- **Deliverables:**
  - `living_doc_augmentor/diff_parser.py` — PR diff parsing
  - Updates to `augmentor.py` — scoped scanning (changed files only)
- **Quality gate:**
  - [ ] PR diff parsing: only files in the PR diff are checked (AC-2.1)
  - [ ] Two-tier changed-file detection: GitHub REST API (priority 1) → `git diff` fallback (AC-2.9)
  - [ ] Deleted files skipped (AC-2.8)
  - [ ] Renamed files scanned at new path (AC-2.10)
  - [ ] Binary files skipped (AC-2.11)
  - [ ] Copied files scanned at destination path (AC-2.12)
  - [ ] CLI: `--base-ref` and `--head-ref` for local PR simulation (AC-2.7)
  - [ ] Without `GITHUB_TOKEN`: fallback to `git diff`; `::warning` emitted (AC-2.9)
  - [ ] Unit tests: ≥ 95 % coverage of `diff_parser.py`
  - [ ] `pylint` ≥ 9.0; `mypy` zero errors; `ruff` clean

**Acceptance criteria:** AC-2.1, AC-2.7, AC-2.8, AC-2.9, AC-2.10, AC-2.11, AC-2.12

---

### T-2.2 Reporting (~1 d) ⬜

- **Status:** ⬜ Not Started
- **Spec refs:** §19.2, §19.5
- **Deliverables:**
  - `living_doc_augmentor/formatters.py` — output formatting (GitHub annotations, step summary)
- **Quality gate:**
  - [ ] GitHub Actions annotations: `::error`, `::warning`, `::notice` per severity (AC-2.2)
  - [ ] `$GITHUB_STEP_SUMMARY` matches §19.5 format: metrics table + violations table + suppressed count (AC-2.3)
  - [ ] Step summary: files scanned, annotations found, violations count, suppressed count
  - [ ] Unit tests: ≥ 95 % coverage of `formatters.py`
  - [ ] `pylint` ≥ 9.0; `mypy` zero errors

**Acceptance criteria:** AC-2.2, AC-2.3

---

### T-2.3 @LivDoc:Ignore rules (~1.5 d) ⬜

- **Status:** ⬜ Not Started
- **Spec refs:** §10
- **Deliverables:**
  - `living_doc_augmentor/ignore.py` — ignore rule parsing and application
- **Quality gate:**
  - [ ] `@LivDoc:Ignore` suppresses all violations for a target (AC-2.4)
  - [ ] `@LivDoc:Ignore(<Type>)` suppresses violations for specific type only (AC-2.5)
  - [ ] File-level ignore: top-of-file `@LivDoc:Ignore` (AC-2.6)
  - [ ] Ignored violations excluded from exit code but listed as "suppressed" in summary
  - [ ] `@LivDoc:Ignore(Type)` without `reason=…` → `::warning` emitted (AC-2.13)
  - [ ] Unit tests: ≥ 95 % coverage of `ignore.py`
  - [ ] `pylint` ≥ 9.0; `mypy` zero errors; `ruff` clean

**Acceptance criteria:** AC-2.4, AC-2.5, AC-2.6, AC-2.13

---

### T-2.4 Integration tests (~1.5 d) ⬜

- **Status:** ⬜ Not Started
- **Spec refs:** §15, §17
- **Deliverables:**
  - `tests/integration/` — integration test suite
  - `tests/integration/fixtures/` — sample repo, test config, expected output
  - `examples/workflow_pr_check.yml`, `examples/workflow_full_scan.yml`, `examples/workflow_collector.yml`
- **Quality gate:**
  - [ ] Sample repo fixture: files with known violations, ignore rules, and clean files
  - [ ] Integration test: augmentor full scan detects expected violations
  - [ ] Integration test: augmentor PR mode scans only changed files
  - [ ] Integration test: collector produces expected `code_augmentations.json`
  - [ ] Example workflows are valid GitHub Actions YAML
  - [ ] All integration tests pass in CI
  - [ ] `pylint` ≥ 9.0 on test files; `ruff` clean

**Acceptance criteria:** _(enables validation of AC-2.1 through AC-2.13)_

---

### T-2.5 Phase 2 quality gate ⬜

- **Status:** ⬜ Not Started
- **Quality gate (PHASE-LEVEL):**
  - [ ] `make qa` exits 0
  - [ ] All global quality gates pass (see table at top)
  - [ ] All ACs pass: AC-2.1 through AC-2.13

---

## Phase 3 — Full Type Catalogue & Extraction Pipeline (v0.3.0)

> **Goal:** All §8 augmentation categories available out of the box. Phase 1
> types extended, not re-implemented.
>
> **Estimated effort:** 2.5–3 weeks.
>
> **Phase-level quality gate:** All ACs 3.1–3.10 pass; `make qa` green; ≥ 95 % coverage.

---

### T-3.1 Extend Phase 1 types (~1 d) ⬜

- **Status:** ⬜ Not Started
- **Spec refs:** §5.2, §8
- **Deliverables:**
  - Updated type definitions for `Feature`, `AC`, `TestEvidence`
- **Quality gate:**
  - [ ] `Feature` — `extraction_rules` (capture group, `value_pattern`), `auto_fix: deterministic`, `auto_fix_template` added
  - [ ] `AC` — `sub_values`, `multi_value: true`, `value_format: repeated` added
  - [ ] `TestEvidence` — `multi_value: true`, `extraction_rules` (requirement ID capture) added
  - [ ] Phase 1 `augmentation_types_starter.yml` still loads without errors (AC-3.1)
  - [ ] New properties are optional with defaults matching Phase 1 behavior
  - [ ] Unit tests: ≥ 95 % coverage of modified models
  - [ ] `pylint` ≥ 9.0; `mypy` zero errors

**Acceptance criteria:** AC-3.1

---

### T-3.2 Extraction pipeline (~2 d) ⬜

- **Status:** ⬜ Not Started
- **Spec refs:** §5.2.1
- **Deliverables:**
  - Extraction logic in `scanner.py` / `collector.py` (or new module as needed)
- **Quality gate:**
  - [ ] `capture_groups` — named capture group extraction from annotation value regex (AC-3.6)
  - [ ] `value_pattern` — regex validation; mismatch → `warning` (AC-3.4)
  - [ ] `transform` — `none`, `lowercase`, `uppercase`, `trim` (AC-3.7)
  - [ ] `key_value_pairs` deferred to Phase 5 (requires multiline)
  - [ ] Collector output includes `target_document` and `audience` from type defs (AC-3.10)
  - [ ] Unit tests: ≥ 95 % coverage of extraction logic
  - [ ] `pylint` ≥ 9.0; `mypy` zero errors; `ruff` clean

**Acceptance criteria:** AC-3.4, AC-3.6, AC-3.7, AC-3.10

---

### T-3.3 Deprecated type property (~0.5 d) ⬜

- **Status:** ⬜ Not Started
- **Spec refs:** §5.2 (`deprecated`)
- **Deliverables:**
  - `deprecated: true` support in config models and augmentor
- **Quality gate:**
  - [ ] `deprecated: true` → violations become `warning` instead of `error` (AC-3.8)
  - [ ] Collector still extracts deprecated annotations normally
  - [ ] `::warning` at startup listing all deprecated types (AC-3.9)
  - [ ] Unit tests for deprecated path
  - [ ] `pylint` ≥ 9.0; `mypy` zero errors

**Acceptance criteria:** AC-3.8, AC-3.9

---

### T-3.4 Full §8 type catalogue (~5 d) ⬜

- **Status:** ⬜ Not Started
- **Spec refs:** §8.1–§8.15
- **Deliverables:**
  - Type definitions for all ~50 catalogue types across 14 categories:
    - Requirements & Traceability: `UserStory`, `Requirement`, `Epic`
    - Testing & Quality: `TestCategory`, `PageObject`, `BDDKeywords`, `TestData`, `CoverageExclusion`
    - Architecture & Design: `ADR`, `ArchDecision`, `DesignPattern`, `Layer`, `Component`, `BoundedContext`, `Aggregate`, `DomainEvent`
    - API & Contracts: `Endpoint`, `Contract`, `DataModel`, `APIContract`, `APIVersion`, `EventSchema`, `GraphQLType`
    - Ownership & Operations: `Owner`, `SLA`, `Runbook`, `Alert`, `AlertRule`, `Stakeholder`, `Tier`
    - Lifecycle & Deprecation: `Deprecated`, `Since`, `PlannedRemoval`, `MigrationGuide`
    - Security & Compliance: `SecurityControl`, `DataClassification`, `ComplianceRule`, `Regulation`, `AuditControl`, `ThreatModel`
    - Living Documentation: `GherkinScenario`, `GherkinFeature`, `BDDStep`, `SpecFlowBinding`
    - Decisions: `TechDecision`, `LibDecision`, `BusinessDecision`, `TechChoice`
    - Glossary & Domain Terms: `Glossary`
    - Domain Objects: `DomainObject`, `ValueObject`, `DomainService`
    - Project Descriptions: `ProjectDescription`, `ModuleDescription`
    - Dependencies & External Systems: `ExternalSystem`, `Library`, `Migration`
    - Process & Workflow: `Workflow`
- **Quality gate:**
  - [ ] All types load via Pydantic validation (AC-3.3)
  - [ ] Each type: ≥ 1 positive-match test + ≥ 1 negative-match test (AC-3.5)
  - [ ] Augmentor detects violations for each required type
  - [ ] Collector extracts annotations for each type
  - [ ] `pylint` ≥ 9.0; `mypy` zero errors; `ruff` clean on all new/modified files

**Acceptance criteria:** AC-3.3, AC-3.5

---

### T-3.5 Catalogue artifact (~1 d) ⬜

- **Status:** ⬜ Not Started
- **Spec refs:** §5.7, §8.15
- **Deliverables:**
  - `examples/augmentation_types_full.yml` — all types with all §5.2 properties
- **Quality gate:**
  - [ ] Full config loads cleanly with Pydantic validation
  - [ ] All ~50 types present with correct properties
  - [ ] AC type includes `sub_values` configuration (AC-3.2)
  - [ ] `pylint` ≥ 9.0; `mypy` zero errors on any supporting test code

**Acceptance criteria:** AC-3.2

---

### T-3.6 Phase 3 quality gate ⬜

- **Status:** ⬜ Not Started
- **Quality gate (PHASE-LEVEL):**
  - [ ] `make qa` exits 0
  - [ ] All global quality gates pass
  - [ ] All ACs pass: AC-3.1 through AC-3.10

---

## Phase 4 — Multi-Language & Location Detection (v0.4.0)

> **Goal:** The full generic location detection system (§6) supporting all specced
> languages.
>
> **Estimated effort:** 2.5–3 weeks.
>
> **Phase-level quality gate:** All ACs 4.1–4.11 pass; `make qa` green; ≥ 95 % coverage.

---

### T-4.1 Generic location detection engine (~3 d) ⬜

- **Status:** ⬜ Not Started
- **Spec refs:** §6, §18.2, §18.3
- **Deliverables:**
  - Refactored `living_doc_augmentor/location.py` — three-layer protocol generalized
  - `living_doc_augmentor/languages.py` — language registry, `inherits` support
  - `CommentBlockDetectionStrategy` (§18.3) — generic comment block detection
- **Quality gate:**
  - [ ] Phase 1 Python-only behavior preserved (AC-4.5)
  - [ ] Language registry loads definitions from config
  - [ ] `inherits` support: child copies parent's `comment_styles` and `targets` (AC-4.3)
  - [ ] Custom target definitions in `augmentation_types.yml`
  - [ ] `CommentBlockDetectionStrategy` handles `/** */`, `# …`, `<!-- -->`
  - [ ] Unit tests: ≥ 95 % coverage of `location.py`, `languages.py`
  - [ ] `pylint` ≥ 9.0; `mypy` zero errors; `ruff` clean

**Acceptance criteria:** AC-4.3, AC-4.5

---

### T-4.2 Built-in language definitions (~3 d) ⬜

- **Status:** ⬜ Not Started
- **Spec refs:** §6.2
- **Deliverables:**
  - Language definitions for: TypeScript/JavaScript, Java, Scala, Terraform, HTML/XML, Markdown, YAML, Shell, SQL, Glue
- **Quality gate:**
  - [ ] TypeScript/JavaScript: `//` line, `/** */` JSDoc
  - [ ] Java: `//` line, `/** */` Javadoc
  - [ ] Scala: `//` line, `/** */` Scaladoc; custom targets: `case_class`, `object`, `trait`, `val` (AC-4.8)
  - [ ] Terraform: `#` hash; custom targets: `resource`, `data_source`, `variable`, `output`, `module_block` (AC-4.2)
  - [ ] HTML/XML/Markdown: `<!-- -->`
  - [ ] YAML: `#` hash
  - [ ] Shell: `#` hash
  - [ ] SQL: `--` line, `/* */` block
  - [ ] Glue: inherited from Python
  - [ ] Cross-language detection works: same type across Python + TypeScript (AC-4.1)
  - [ ] Unit tests: ≥ 1 detection test per language
  - [ ] `pylint` ≥ 9.0; `mypy` zero errors

**Acceptance criteria:** AC-4.1, AC-4.2, AC-4.8

---

### T-4.3 Per-type scan mode (~1 d) ⬜

- **Status:** ⬜ Not Started
- **Spec refs:** §4.1
- **Deliverables:**
  - `scan-mode: per-type` with `--augmentation-type` argument
- **Quality gate:**
  - [ ] `--scan-mode per-type --augmentation-type Feature` → only `Feature` violations (AC-4.6)
  - [ ] `--scan-mode per-type` without `--augmentation-type` → exit code `2` with error message (AC-4.7)
  - [ ] Scans entire repo but filters to specified type
  - [ ] Unit tests for per-type mode
  - [ ] `pylint` ≥ 9.0; `mypy` zero errors

**Acceptance criteria:** AC-4.6, AC-4.7

---

### T-4.4 Comment parsing rules — all languages (~1 d) ⬜

- **Status:** ⬜ Not Started
- **Spec refs:** §7
- **Deliverables:**
  - Comment parsing generalized across all language definitions
- **Quality gate:**
  - [ ] Zero-blank-line association rule enforced across all languages
  - [ ] Case-sensitive matching: `@LivDoc:feature` ≠ `@LivDoc:Feature` (AC-4.9)
  - [ ] Single-line constructs (Scala `case class`, TS `type`) use preceding-comment form
  - [ ] Multiple annotations per comment block supported
  - [ ] Annotation key-value metadata: `@LivDoc:SLA(latency-p99, 200ms)`
  - [ ] Unit tests per language
  - [ ] `pylint` ≥ 9.0; `mypy` zero errors

**Acceptance criteria:** AC-4.9

---

### T-4.5 Cross-language parity validation (~1 d) ⬜

- **Status:** ⬜ Not Started
- **Spec refs:** §5.4
- **Deliverables:**
  - Validator in config loader
- **Quality gate:**
  - [ ] Types spanning multiple languages: all matched languages have compatible definitions
  - [ ] `::warning` when a type references a `target` not defined in a matched language (AC-4.4)
  - [ ] Unit tests for parity warnings
  - [ ] `pylint` ≥ 9.0; `mypy` zero errors

**Acceptance criteria:** AC-4.4

---

### T-4.6 Custom location matchers (~1 d) ⬜

- **Status:** ⬜ Not Started
- **Spec refs:** §6.3, §6.4
- **Deliverables:**
  - `LocationMatcher(Protocol)` interface
  - `PrecededByMatcher` built-in implementation
  - `location_matcher` property on type definitions
- **Quality gate:**
  - [ ] `LocationMatcher(Protocol)` with `matches(file_path, line_number, context_lines, target_kind) → bool`
  - [ ] `must_be_preceded_by` + `max_distance_lines` properties functional (AC-4.10)
  - [ ] Annotation within distance → matched; beyond distance → not matched (AC-4.10, AC-4.11)
  - [ ] Custom matchers loadable via `DetectionStrategy` plugin mechanism
  - [ ] Unit tests: ≥ 95 % coverage
  - [ ] `pylint` ≥ 9.0; `mypy` zero errors

**Acceptance criteria:** AC-4.10, AC-4.11

---

### T-4.7 Phase 4 quality gate ⬜

- **Status:** ⬜ Not Started
- **Quality gate (PHASE-LEVEL):**
  - [ ] `make qa` exits 0
  - [ ] All global quality gates pass
  - [ ] All ACs pass: AC-4.1 through AC-4.11

---

## Phase 5 — Advanced Annotation Features (v0.5.0)

> **Goal:** Full annotation syntax support — multiline, value formats, multiple
> config files, placement rules.
>
> **Estimated effort:** 2–2.5 weeks.
>
> **Phase-level quality gate:** All ACs 5.1–5.10 pass; `make qa` green; ≥ 95 % coverage.

---

### T-5.1 Multiline annotations (~2 d) ⬜

- **Status:** ⬜ Not Started
- **Spec refs:** §5.6
- **Deliverables:**
  - Multiline annotation detection in scanner
  - Key-value pair extraction (`extraction_rules.key_value_pairs`, `required_keys`, `optional_keys`)
- **Quality gate:**
  - [ ] Multiline annotations detected across continuation lines (AC-5.1)
  - [ ] `required_keys` / `optional_keys` extracted into `extracted_data`
  - [ ] Missing `required_keys` → augmentor violation (AC-5.7)
  - [ ] Double-quote escaping (no backslashes in values)
  - [ ] Quoted values with commas extracted verbatim (AC-5.8)
  - [ ] Unit tests: ≥ 95 % coverage
  - [ ] `pylint` ≥ 9.0; `mypy` zero errors

**Acceptance criteria:** AC-5.1, AC-5.7, AC-5.8

---

### T-5.2 Value format options (~2 d) ⬜

- **Status:** ⬜ Not Started
- **Spec refs:** §5.8
- **Deliverables:**
  - Value format parsing: `csv`, `pipe`, `repeated`, `group`
- **Quality gate:**
  - [ ] `csv` format — explicit tests (already default)
  - [ ] `pipe` format: `@LivDoc:AC(AC-001 | AC-002)` → `["AC-001", "AC-002"]` (AC-5.2)
  - [ ] `repeated` format: multiple same-type annotations merged (AC-5.3)
  - [ ] `group` format: `@LivDoc:Trace(Feature=F-1, AC=AC-001)` → expanded by `group_members` (AC-5.4)
  - [ ] Unit tests: ≥ 95 % coverage of value parsing logic
  - [ ] `pylint` ≥ 9.0; `mypy` zero errors

**Acceptance criteria:** AC-5.2, AC-5.3, AC-5.4

---

### T-5.3 Multiple config files (~1.5 d) ⬜

- **Status:** ⬜ Not Started
- **Spec refs:** §5.1, §9.1
- **Deliverables:**
  - Multi-config support in config loader
- **Quality gate:**
  - [ ] Comma-separated `config-path` input accepted
  - [ ] Each file has its own `annotation_prefix` → namespace isolation (AC-5.5)
  - [ ] Duplicate type names within same namespace → exit code `2` (AC-5.6)
  - [ ] Duplicate type names across different namespaces → OK (AC-5.5)
  - [ ] Unit tests: ≥ 95 % coverage
  - [ ] `pylint` ≥ 9.0; `mypy` zero errors

**Acceptance criteria:** AC-5.5, AC-5.6

---

### T-5.4 Placement rules (~0.5 d) ⬜

- **Status:** ⬜ Not Started
- **Spec refs:** §5.3
- **Deliverables:**
  - `placement` property on type definitions: `inside` (docstring) / `outside` (preceding comment)
- **Quality gate:**
  - [ ] `placement: inside` — annotation in preceding comment → not detected; violation reported (AC-5.9)
  - [ ] `placement: outside` — annotation inside docstring → not detected; violation reported (AC-5.10)
  - [ ] Default placement: both locations accepted (backward-compatible)
  - [ ] Unit tests for each placement mode
  - [ ] `pylint` ≥ 9.0; `mypy` zero errors

**Acceptance criteria:** AC-5.9, AC-5.10

---

### T-5.5 Phase 5 quality gate ⬜

- **Status:** ⬜ Not Started
- **Quality gate (PHASE-LEVEL):**
  - [ ] `make qa` exits 0
  - [ ] All global quality gates pass
  - [ ] All ACs pass: AC-5.1 through AC-5.10

---

## Phase 6 — Auto-Fix: Deterministic & AI (v0.6.0)

> **Goal:** Both `deterministic` and `ai` auto-fix modes (§4.3) are functional.
>
> **Estimated effort:** 2.5–3 weeks.
>
> **Phase-level quality gate:** All ACs 6.1–6.8 pass; `make qa` green; ≥ 95 % coverage.

---

### T-6.1 Auto-fix core (~1.5 d) ⬜

- **Status:** ⬜ Not Started
- **Spec refs:** §4.3
- **Deliverables:**
  - `living_doc_augmentor/auto_fix.py` — auto-fix regime entry point
- **Quality gate:**
  - [ ] Mandatory `--dry-run` default (§4.3)
  - [ ] Exit codes: `0` (no fixable / all fixed), `1` (fixable found / some failed), `2` (config error)
  - [ ] Auto-fix report in `$GITHUB_STEP_SUMMARY`
  - [ ] Unit tests: ≥ 95 % coverage of `auto_fix.py`
  - [ ] `pylint` ≥ 9.0; `mypy` zero errors

**Acceptance criteria:** AC-6.1

---

### T-6.2 Deterministic mode (~2 d) ⬜

- **Status:** ⬜ Not Started
- **Spec refs:** §4.3, §5.2.2
- **Deliverables:**
  - Template-based annotation insertion using §5.2.2 tokens
- **Quality gate:**
  - [ ] Tokens: `{class_name}`, `{function_name}`, etc. resolved correctly
  - [ ] Unknown tokens → exit code `2` at config load time (AC-6.6)
  - [ ] Dry-run: report shows proposed insertion, no files modified, exit code `1` (AC-6.1)
  - [ ] `dry-run: false`: files modified, `git diff` produced, exit code `0` (AC-6.2)
  - [ ] Unit tests: ≥ 95 % coverage
  - [ ] `pylint` ≥ 9.0; `mypy` zero errors

**Acceptance criteria:** AC-6.1, AC-6.2, AC-6.6

---

### T-6.3 AI mode (~3 d) ⬜

- **Status:** ⬜ Not Started
- **Spec refs:** §4.3.4, §4.3.5, §4.3.7
- **Deliverables:**
  - `living_doc_augmentor/ai_provider.py` — provider abstraction
  - `living_doc_augmentor/review.py` — review file generator
- **Quality gate:**
  - [ ] AI provider config loader (`auto_fix_ai` block)
  - [ ] Provider backends: `copilot`, `claude`, `openai`, `custom`
  - [ ] `auto_fix_review.json` generated when `review_required: true` (AC-6.3)
  - [ ] Per-type error handling: HTTP errors, rate limits (retry 3× with backoff), timeouts, auth failures (AC-6.5)
  - [ ] AI Provider Status section in `$GITHUB_STEP_SUMMARY`
  - [ ] No `auto_fix_ai` block + `auto_fix: ai` type → exit code `2` at config validation (AC-6.8)
  - [ ] Unit tests: ≥ 95 % coverage of `ai_provider.py`, `review.py`
  - [ ] `pylint` ≥ 9.0; `mypy` zero errors; `ruff` clean

**Acceptance criteria:** AC-6.3, AC-6.5, AC-6.8

---

### T-6.4 Auto-fix integration (~1 d) ⬜

- **Status:** ⬜ Not Started
- **Spec refs:** §4.3
- **Deliverables:**
  - Mixed-run support in auto-fix orchestration
- **Quality gate:**
  - [ ] Mixed config: `deterministic`, `ai`, and `no` types in the same run (AC-6.7)
  - [ ] `no` types skipped; deterministic applied; AI suggestions in review file
  - [ ] When no AI provider configured: `ai` types silently skipped with `::warning` (AC-6.4)
  - [ ] Summary lists all three categories
  - [ ] Unit tests for mixed mode
  - [ ] `pylint` ≥ 9.0; `mypy` zero errors

**Acceptance criteria:** AC-6.4, AC-6.7

---

### T-6.5 Phase 6 quality gate ⬜

- **Status:** ⬜ Not Started
- **Quality gate (PHASE-LEVEL):**
  - [ ] `make qa` exits 0
  - [ ] All global quality gates pass
  - [ ] All ACs pass: AC-6.1 through AC-6.8

---

## Phase 7 — AI Copilot Instructions & Agent Optimization (v0.7.0)

> **Goal:** First-class AI assistant integration within the GitHub Action —
> Copilot instructions, agent-mode contracts, AI-assisted config generation.
>
> **Estimated effort:** 1–1.5 weeks.
>
> **Scope note:** The `@livingdoc` VS Code chat participant is a separate product
> (out of scope for this roadmap).
>
> **Phase-level quality gate:** All ACs 7.1–7.3 pass; `make qa` green; ≥ 95 % coverage.

---

### T-7.1 Copilot instructions (~1 d) ⬜

- **Status:** ⬜ Not Started
- **Spec refs:** §18.1
- **Deliverables:**
  - `.github/copilot-instructions.md` — comprehensive project context
  - Protocol interfaces with rich docstring contracts
- **Quality gate:**
  - [ ] Instructions file provides full project context for AI assistants (AC-7.1)
  - [ ] Protocol interfaces discoverable by agent-mode tools
  - [ ] File passes markdown lint

**Acceptance criteria:** AC-7.1

---

### T-7.2 AI-assisted config generation (~2 d) ⬜

- **Status:** ⬜ Not Started
- **Spec refs:** §18
- **Deliverables:**
  - `/generate-config` prompt template
  - AI-assisted `augmentation_types.yml` generation
- **Quality gate:**
  - [ ] Generated config passes Pydantic validation (AC-7.2)
  - [ ] Prompt engineering: given repo scan → valid `augmentation_types.yml`
  - [ ] Output validation: generated YAML loads without errors
  - [ ] Unit tests for config validation of generated output
  - [ ] `pylint` ≥ 9.0; `mypy` zero errors

**Acceptance criteria:** AC-7.2

---

### T-7.3 Agent-mode optimization (~1 d) ⬜

- **Status:** ⬜ Not Started
- **Spec refs:** §18.2
- **Deliverables:**
  - Stable Protocol/ABC interfaces for all public APIs
  - Docstring contracts on every public method
- **Quality gate:**
  - [ ] Every public class/function has docstring with parameter types, return types, pre/post conditions (AC-7.3)
  - [ ] `pylint` ≥ 9.0 (docstring checks enabled); `mypy` zero errors
  - [ ] No public API without docstring (enforced by pylint `missing-docstring`)

**Acceptance criteria:** AC-7.3

---

### T-7.4 Phase 7 quality gate ⬜

- **Status:** ⬜ Not Started
- **Quality gate (PHASE-LEVEL):**
  - [ ] `make qa` exits 0
  - [ ] All global quality gates pass
  - [ ] All ACs pass: AC-7.1 through AC-7.3

---

## Phase 8 — Maturity & Marketplace (v1.0.0)

> **Goal:** Production hardening, performance, backward-compatibility guarantees,
> and public release.
>
> **Estimated effort:** 2.5–3 weeks.
>
> **Phase-level quality gate:** All ACs 8.1–8.8 pass; `make qa` green; ≥ 95 % coverage.

---

### T-8.1 AST-based detection — Python (~2 d) ⬜

- **Status:** ⬜ Not Started
- **Spec refs:** §6
- **Deliverables:**
  - Optional AST-based detection for Python (`ast.parse`)
- **Quality gate:**
  - [ ] Nested class annotations correctly attributed (AC-8.1)
  - [ ] Fallback to regex when AST parsing fails (syntax errors in scanned files)
  - [ ] Scope: resolve ambiguous regex matches (nested classes)
  - [ ] Unit tests: ≥ 95 % coverage of AST detection path
  - [ ] `pylint` ≥ 9.0; `mypy` zero errors

**Acceptance criteria:** AC-8.1

---

### T-8.2 Caching (~2 d) ⬜

- **Status:** ⬜ Not Started
- **Spec refs:** §22.3
- **Deliverables:**
  - Cache implementation: `.livdoc_cache.json`
- **Quality gate:**
  - [ ] Cache keyed by file content hash (SHA-256)
  - [ ] Incremental scans: unchanged files skipped (AC-8.2 — < 10 % time on second scan)
  - [ ] Cache invalidation when `augmentation_types.yml` changes (AC-8.3)
  - [ ] Cache storage: local file for CI runners
  - [ ] Unit tests: ≥ 95 % coverage
  - [ ] `pylint` ≥ 9.0; `mypy` zero errors

**Acceptance criteria:** AC-8.2, AC-8.3

---

### T-8.3 Security & performance (~2 d) ⬜

- **Status:** ⬜ Not Started
- **Spec refs:** §21, §22.2
- **Deliverables:**
  - ReDoS protection, input sanitization, parallel file processing
- **Quality gate:**
  - [ ] ReDoS protection: regex complexity analysis at config load (AC-8.4)
  - [ ] Input sanitization for all user-provided values
  - [ ] Parallel file processing: multi-threaded scanning for full-repo mode with configurable concurrency
  - [ ] Performance: ≥ 1,000 files/second on reference hardware (AC-8.5)
  - [ ] Benchmark test: 5,000 Python files → completes within 5 seconds
  - [ ] Unit tests: ≥ 95 % coverage
  - [ ] `pylint` ≥ 9.0; `mypy` zero errors

**Acceptance criteria:** AC-8.4, AC-8.5

---

### T-8.4 Versioning & backward compatibility (~1.5 d) ⬜

- **Status:** ⬜ Not Started
- **Spec refs:** §20
- **Deliverables:**
  - Output schema versioning, backward-compatibility policy
- **Quality gate:**
  - [ ] `code_augmentations.json` includes `schema_version` alongside `tool_version` (AC-8.8)
  - [ ] v0.x configs load in v1.0 with deprecation warnings (AC-8.7)
  - [ ] Deprecated config properties emit warnings for ≥ 1 minor release before removal
  - [ ] Additive-only output schema changes within major version
  - [ ] Unit tests: backward-compat test with v0.5-era config fixture
  - [ ] `pylint` ≥ 9.0; `mypy` zero errors

**Acceptance criteria:** AC-8.7, AC-8.8

---

### T-8.5 Release preparation (~1 d) ⬜

- **Status:** ⬜ Not Started
- **Spec refs:** §24
- **Deliverables:**
  - Published to GitHub Marketplace
  - Migration guide from v0.x → v1.0
- **Quality gate:**
  - [ ] Marketplace listing with correct metadata, README, branding (AC-8.6)
  - [ ] Migration guide covers all breaking changes
  - [ ] `action.yml` metadata complete for Marketplace
  - [ ] README includes all badges, examples, and documentation links

**Acceptance criteria:** AC-8.6

---

### T-8.6 Phase 8 quality gate ⬜

- **Status:** ⬜ Not Started
- **Quality gate (PHASE-LEVEL):**
  - [ ] `make qa` exits 0
  - [ ] All global quality gates pass
  - [ ] All ACs pass: AC-8.1 through AC-8.8

---

## Summary

| Phase | Tasks | ACs | Est. Effort | Status |
|---|---|---|---|---|
| Phase 0 — Repo Setup | 5 | — | — | ✅ Done |
| Phase 1 — POC: Scaffold & Core | 9 | 13 | 2–2.5 wk | ⬜ Not Started |
| Phase 2 — PR Mode & Ignore | 5 | 13 | 1.5–2 wk | ⬜ Not Started |
| Phase 3 — Type Catalogue | 6 | 10 | 2.5–3 wk | ⬜ Not Started |
| Phase 4 — Multi-Language | 7 | 11 | 2.5–3 wk | ⬜ Not Started |
| Phase 5 — Advanced Annotations | 5 | 10 | 2–2.5 wk | ⬜ Not Started |
| Phase 6 — Auto-Fix | 5 | 8 | 2.5–3 wk | ⬜ Not Started |
| Phase 7 — AI Copilot | 4 | 3 | 1–1.5 wk | ⬜ Not Started |
| Phase 8 — Maturity & Marketplace | 6 | 8 | 2.5–3 wk | ⬜ Not Started |
| **Total** | **52** | **76** | **~17–20 wk** | |
