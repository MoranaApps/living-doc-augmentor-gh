# Living Documentation — Source Code Augmentor GitHub Action

## Specification

> **Version:** 0.1.0-draft  
> **Date:** 2026-02-19  
> **Status:** Draft  
> **Source Inspiration:** [MoranaApps/liv_doc_poc — docs/SPEC.md (M5 — Source Code Augmentor)](https://github.com/MoranaApps/liv_doc_poc/blob/master/docs/SPEC.md)  
> **Reference Implementation:** [AbsaOSS/generate-release-notes](https://github.com/AbsaOSS/generate-release-notes)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Goals & Non-Goals](#2-goals--non-goals)
3. [Architecture](#3-architecture)
4. [Regimes (Operating Modes)](#4-regimes-operating-modes)
5. [Augmentation Type System](#5-augmentation-type-system)
6. [Comment Format Specification](#6-comment-format-specification)
7. [Configuration](#7-configuration)
8. [Action Inputs & Outputs](#8-action-inputs--outputs)
9. [Collector Output Schema](#9-collector-output-schema)
10. [GitHub Action Definition (action.yml)](#10-github-action-definition-actionyml)
11. [Example Workflows](#11-example-workflows)
12. [Quality Gates](#12-quality-gates)
13. [Repository Structure](#13-repository-structure)
14. [Copilot Extensibility](#14-copilot-extensibility)
15. [Roadmap](#15-roadmap)

---

## 1. Overview

**Living Documentation Source Code Augmentor** (`living-doc-augmentor-gh`) is a **composite GitHub Action** written in **Python 3.14** that enriches source code with structured annotations and extracts those annotations into machine-readable output.

The action operates in two distinct regimes:

| Regime | Purpose |
|---|---|
| **Augmentor** | Validates that source code annotations conform to defined augmentation types and placement rules |
| **Collector** | Extracts all augmented data from source code into a structured JSON output for upstream consumption |

The concept originates from the *M5 — Source Code Augmentor (Enrichment)* milestone in the [Living Documentation PoC specification](https://github.com/MoranaApps/liv_doc_poc/blob/master/docs/SPEC.md), adapted here as a standalone, reusable GitHub Action.

---

## 2. Goals & Non-Goals

### Goals

- **G1:** Provide a composite GitHub Action (Python 3.14) for augmenting and collecting structured annotations from source code.
- **G2:** Support two regimes — **augmentor** (validation) and **collector** (extraction).
- **G3:** Allow user-defined augmentation types with configurable rules for placement and detection.
- **G4:** Run augmentor in PR mode (validate only changed files) and full-scan mode (validate entire repository).
- **G5:** Run augmentor on demand, optionally scoped to a specific augmentation type.
- **G6:** Produce deterministic, structured JSON output (`code_augmentations.json`) from the collector.
- **G7:** Maintain strong quality gates (linting, type checking, unit tests, integration tests, code coverage) modeled after [AbsaOSS/generate-release-notes](https://github.com/AbsaOSS/generate-release-notes).
- **G8:** Design the augmentor logic to be extensible by GitHub Copilot for improved detection capabilities.

### Non-Goals

- UI rendering of living documentation (handled by upstream consumers).
- Modifying source code automatically (the augmentor validates; it does not auto-fix).
- Language-specific AST parsing in v1 (regex/pattern-based detection first; AST is a future enhancement).

---

## 3. Architecture

┌─────────────────────────────────────────────────────────┐ │ GitHub Action (composite) │ │ │ │ ┌──────────────┐ ┌───────────────────────────────┐ │ │ │ action.yml │───▶│ main.py (Python 3.14 entry) │ │ │ └──────────────┘ └──────────┬────────────────────┘ │ │ │ │ │ ┌────────────┴────────────┐ │ │ ▼ ▼ │ │ ┌──────────────┐ ┌──────────────┐ │ │ │ Augmentor │ │ Collector │ │ │ │ Regime │ │ Regime │ │ │ └──────┬───────┘ └──────┬───────┘ │ │ │ │ │ │ ┌──────────┴──────────┐ │ │ │ ▼ ▼ ▼ │ │ ┌──────────┐ ┌────────────┐ ┌──────────────────┐ │ │ │ PR Mode │ │ Full Scan │ │ JSON Extractor │ │ │ │ (diff) │ │ (repo-wide)│ │ (aggregate all) │ │ │ └──────────┘ └────────────┘ └──────────────────┘ │ │ │ │ ┌─────────────────────────────────────────────────┐ │ │ │ augmentation_types.yml (user-defined rules) │ │ │ └─────────────────────────────────────────────────┘ │ └─────────────────────────────────────────────────────────┘


### Key Components

| Component | Description |
|---|---|
| `action.yml` | Composite action definition — sets up Python 3.14, installs dependencies, dispatches to the appropriate regime |
| `main.py` | Entry point — parses action inputs, routes to augmentor or collector |
| `living_doc_augmentor/augmentor.py` | Augmentor regime — validates annotations against defined types and rules |
| `living_doc_augmentor/collector.py` | Collector regime — extracts all annotations into structured JSON |
| `living_doc_augmentor/scanner.py` | Core scanning engine — file traversal, pattern matching, annotation extraction |
| `living_doc_augmentor/config.py` | Configuration loader — reads `augmentation_types.yml` and action inputs |
| `living_doc_augmentor/models.py` | Data models for augmentation types, annotations, scan results |
| `augmentation_types.yml` | User-supplied configuration defining annotation types and placement rules |

---

## 4. Regimes (Operating Modes)

### 4.1 Augmentor Regime

The **augmentor** validates that source code annotations conform to the defined augmentation types and placement rules. It **does not modify** source code; it reports violations.

#### 4.1.1 PR Mode (Automatic in Pull Requests)

- **Trigger:** Runs automatically on `pull_request` events.
- **Scope:** Only files changed in the PR (determined from the PR diff).
- **Behavior:** Checks whether changed files comply with required annotation rules. Reports violations as PR check annotations (GitHub Actions annotations / PR review comments).
- **Use case:** Continuous validation — ensures every PR maintains augmentation standards.

#### 4.1.2 Full Scan Mode (On-Demand)

- **Trigger:** `workflow_dispatch` (manual) or scheduled.
- **Scope:** Entire repository.
- **Behavior:** Scans all matching files, validates all annotations against all rules.
- **Use case:** Initial adoption, periodic audits, baseline compliance checks.

#### 4.1.3 Per-Type Scan Mode (On-Demand)

- **Trigger:** `workflow_dispatch` with `augmentation-type` input specified.
- **Scope:** Entire repository, but only for the specified augmentation type.
- **Behavior:** Scans all matching files for a single augmentation type.
- **Use case:** Targeted audits (e.g., "check only `@LivDoc:Feature` annotations").

#### 4.1.4 Augmentor Exit Codes

| Exit Code | Meaning |
|---|---|
| `0` | All checks passed — no violations |
| `1` | Violations found — annotations missing or non-conforming |
| `2` | Configuration error — invalid `augmentation_types.yml` |

### 4.2 Collector Regime

The **collector** extracts all augmented data from source code into a structured JSON output.

- **Trigger:** `workflow_dispatch`, scheduled, or as a step in a release/deploy workflow.
- **Scope:** Entire repository.
- **Output:** `code_augmentations.json` — structured JSON with all extracted annotations, grouped by type and source file.
- **Use case:** Feed augmented metadata into upstream processes (living documentation builders, dashboards, reports).

---

## 5. Augmentation Type System

Users define augmentation types in `augmentation_types.yml`. Each type specifies:

| Property | Type | Description |
|---|---|---|
| `name` | `string` | Unique identifier (e.g., `Feature`, `AC`, `TestEvidence`) |
| `tag` | `string` | The annotation tag as it appears in source code (e.g., `@LivDoc:Feature`) |
| `pattern` | `string` (regex) | Regex pattern to detect the annotation in comments/docstrings |
| `target` | `enum` | Where the annotation must appear: `function`, `class`, `module`, `method`, `any` |
| `required` | `boolean` | Whether the annotation is mandatory for matching targets |
| `file_patterns` | `list[string]` | Glob patterns for files where this type applies (e.g., `["src/**/*.py", "tests/**/*.py"]`) |
| `description` | `string` | Human-readable description of the annotation type |
| `extraction_rules` | `object` | Rules for extracting structured data from the annotation body |

### Example `augmentation_types.yml`

```yaml
version: "1.0"

annotation_prefix: "@LivDoc"

types:
  - name: Feature
    tag: "@LivDoc:Feature"
    pattern: '@LivDoc:Feature\(([^)]+)\)'
    target: class
    required: true
    file_patterns:
      - "src/**/*.py"
    description: "Links a class to a feature identifier from the feature registry."
    extraction_rules:
      capture_groups:
        - name: feature_id
          group: 1

  - name: AC
    tag: "@LivDoc:AC"
    pattern: '@LivDoc:AC\(([^)]+)\)'
    target: method
    required: false
    file_patterns:
      - "src/**/*.py"
      - "tests/**/*.py"
    description: "Links a method to an acceptance criterion."
    extraction_rules:
      capture_groups:
        - name: ac_id
          group: 1

  - name: TestEvidence
    tag: "@LivDoc:TestEvidence"
    pattern: '@LivDoc:TestEvidence\(([^)]+)\)'
    target: function
    required: true
    file_patterns:
      - "tests/**/*.py"
    description: "Links a test function to the requirement it verifies."
    extraction_rules:
      capture_groups:
        - name: requirement_id
          group: 1

  - name: PageObject
    tag: "@LivDoc:PageObject"
    pattern: '@LivDoc:PageObject\(([^)]+)\)'
    target: class
    required: false
    file_patterns:
      - "tests/pages/**/*.py"
    description: "Marks a class as a page object for UI testing."
    extraction_rules:
      capture_groups:
        - name: page_name
          group: 1

## 6. Comment Format Specification
Annotations are embedded in standard language comment/docstring formats.

### Python (docstrings)

```python
class UserService:
    """
    Handles user registration and authentication.

    @LivDoc:Feature(USER-AUTH-001)
    @LivDoc:AC(AC-001, AC-002)
    """

    def register_user(self, user_data: dict) -> User:
        """
        Register a new user.

        @LivDoc:AC(AC-001)
        """
        ...

def test_user_registration():
    """
    @LivDoc:TestEvidence(REQ-USER-001)
    """
    ... 
```

### TypeScript / JavaScript (JSDoc/TSDoc)

```
/**
 * Handles user registration and authentication.
 *
 * @LivDoc:Feature(USER-AUTH-001)
 * @LivDoc:AC(AC-001, AC-002)
 */
class UserService {
    /**
     * Register a new user.
     *
     * @LivDoc:AC(AC-001)
     */
    registerUser(userData: UserData): User {
        ...
    }
}
```

### General Rules

- Annotations MUST appear inside comment blocks (docstrings, /** */, # comments).
- Multiple annotations per comment block are allowed.
- Annotations with multiple values use comma separation: @LivDoc:AC(AC-001, AC-002).
- Annotations are case-sensitive.
- Unrecognized annotations (not in augmentation_types.yml) are reported as warnings.

## 7. Configuration

### 7.1 Configuration File
The action reads configuration from augmentation_types.yml (path configurable via input).

### 7.2 Configuration Validation
On startup, the action validates:

YAML syntax is correct.
All required fields are present for each type.
Regex patterns compile successfully.
File glob patterns are valid.
No duplicate type names or tags.
Invalid configuration causes exit code 2.

## 8. Action Inputs & Outputs

### Inputs

Input	Required	Default	Description
regime	yes	—	Operating mode: augmentor or collector
config-path	no	augmentation_types.yml	Path to the augmentation types configuration file
scan-mode	no	pr	Augmentor scan mode: pr, full, or per-type
augmentation-type	no	—	When scan-mode: per-type, the specific type to check
source-paths	no	.	Comma-separated list of directories to scan
exclude-paths	no	—	Comma-separated list of glob patterns to exclude
output-path	no	code_augmentations.json	Output file path for the collector regime
fail-on-violations	no	true	Whether the augmentor should fail the workflow on violations
verbose	no	false	Enable verbose/debug logging
python-version	no	3.14	Python version to use

### Outputs

Output	Description
violations-count	Number of violations found (augmentor regime)
annotations-count	Total annotations found
output-file	Path to the generated code_augmentations.json (collector regime)
types-summary	JSON string summarizing counts per augmentation type

## 9. Collector Output Schema

The collector produces code_augmentations.json with the following structure:

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "properties": {
    "metadata": {
      "type": "object",
      "properties": {
        "generated_at": { "type": "string", "format": "date-time" },
        "repository": { "type": "string" },
        "commit_sha": { "type": "string" },
        "ref": { "type": "string" },
        "config_version": { "type": "string" },
        "tool_version": { "type": "string" }
      }
    },
    "summary": {
      "type": "object",
      "properties": {
        "total_annotations": { "type": "integer" },
        "total_files_scanned": { "type": "integer" },
        "total_files_with_annotations": { "type": "integer" },
        "by_type": {
          "type": "object",
          "additionalProperties": { "type": "integer" }
        }
      }
    },
    "annotations": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "type": { "type": "string" },
          "tag": { "type": "string" },
          "value": { "type": "string" },
          "file": { "type": "string" },
          "line": { "type": "integer" },
          "target_name": { "type": "string" },
          "target_kind": { "type": "string", "enum": ["function", "class", "method", "module"] },
          "extracted_data": { "type": "object" },
          "raw_comment": { "type": "string" }
        },
        "required": ["type", "tag", "value", "file", "line"]
      }
    }
  }
}
````

### Example Output

```json
{
  "metadata": {
    "generated_at": "2026-02-19T10:30:00Z",
    "repository": "AbsaOSS/generate-release-notes",
    "commit_sha": "abc123def456",
    "ref": "refs/heads/main",
    "config_version": "1.0",
    "tool_version": "0.1.0"
  },
  "summary": {
    "total_annotations": 15,
    "total_files_scanned": 42,
    "total_files_with_annotations": 8,
    "by_type": {
      "Feature": 3,
      "AC": 7,
      "TestEvidence": 5
    }
  },
  "annotations": [
    {
      "type": "Feature",
      "tag": "@LivDoc:Feature",
      "value": "USER-AUTH-001",
      "file": "src/user_service.py",
      "line": 5,
      "target_name": "UserService",
      "target_kind": "class",
      "extracted_data": {
        "feature_id": "USER-AUTH-001"
      },
      "raw_comment": "Handles user registration and authentication.\n\n@LivDoc:Feature(USER-AUTH-001)"
    }
  ]
}
```

## 10. GitHub Action Definition (action.yml)

The action follows the composite action pattern used in AbsaOSS/generate-release-notes:

```yaml
name: 'Living Doc Augmentor'
description: 'Augment and collect structured annotations from source code for living documentation.'
author: 'MoranaApps'

inputs:
  regime:
    description: 'Operating mode: augmentor or collector'
    required: true
  config-path:
    description: 'Path to augmentation_types.yml'
    required: false
    default: 'augmentation_types.yml'
  scan-mode:
    description: 'Augmentor scan mode: pr, full, or per-type'
    required: false
    default: 'pr'
  augmentation-type:
    description: 'Specific augmentation type for per-type scan mode'
    required: false
    default: ''
  source-paths:
    description: 'Comma-separated directories to scan'
    required: false
    default: '.'
  exclude-paths:
    description: 'Comma-separated glob patterns to exclude'
    required: false
    default: ''
  output-path:
    description: 'Output file path for collector regime'
    required: false
    default: 'code_augmentations.json'
  fail-on-violations:
    description: 'Fail workflow on augmentor violations'
    required: false
    default: 'true'
  verbose:
    description: 'Enable verbose logging'
    required: false
    default: 'false'

outputs:
  violations-count:
    description: 'Number of violations found'
    value: ${{ steps.run.outputs.violations-count }}
  annotations-count:
    description: 'Total annotations found'
    value: ${{ steps.run.outputs.annotations-count }}
  output-file:
    description: 'Path to generated output file'
    value: ${{ steps.run.outputs.output-file }}
  types-summary:
    description: 'JSON summary of counts per augmentation type'
    value: ${{ steps.run.outputs.types-summary }}

runs:
  using: 'composite'
  steps:
    - name: Set up Python
      uses: actions/setup-python@v5
      with:
        python-version: '3.14'

    - name: Install dependencies
      shell: bash
      run: |
        cd ${{ github.action_path }}
        pip install -r requirements.txt

    - name: Run Living Doc Augmentor
      id: run
      shell: bash
      env:
        INPUT_REGIME: ${{ inputs.regime }}
        INPUT_CONFIG_PATH: ${{ inputs.config-path }}
        INPUT_SCAN_MODE: ${{ inputs.scan-mode }}
        INPUT_AUGMENTATION_TYPE: ${{ inputs.augmentation-type }}
        INPUT_SOURCE_PATHS: ${{ inputs.source-paths }}
        INPUT_EXCLUDE_PATHS: ${{ inputs.exclude-paths }}
        INPUT_OUTPUT_PATH: ${{ inputs.output-path }}
        INPUT_FAIL_ON_VIOLATIONS: ${{ inputs.fail-on-violations }}
        INPUT_VERBOSE: ${{ inputs.verbose }}
      run: |
        cd ${{ github.action_path }}
        python main.py
```

## 11. Example Workflows

### 11.1 Example Implementation in AbsaOSS/generate-release-notes

The following examples show how living-doc-augmentor-gh would be integrated into the AbsaOSS/generate-release-notes repository.

#### 11.1.1 PR Augmentor Check

```yaml
name: Living Doc Augmentor — PR Check

on:
  pull_request:
    branches: [ master ]
    types: [ opened, synchronize, reopened ]

jobs:
  augmentor-check:
    runs-on: ubuntu-latest
    name: Check Annotations in Changed Files
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Run Augmentor (PR Mode)
        uses: MoranaApps/living-doc-augmentor-gh@main
        with:
          regime: augmentor
          scan-mode: pr
          config-path: augmentation_types.yml
          fail-on-violations: 'true'
```

#### 11.1.2 Full Repository Scan (On-Demand)

```yaml
name: Living Doc Augmentor — Full Scan

on:
  workflow_dispatch:
    inputs:
      augmentation-type:
        description: 'Specific type to scan (leave empty for all)'
        required: false
        default: ''

jobs:
  full-scan:
    runs-on: ubuntu-latest
    name: Full Repository Annotation Scan
    steps:
      - uses: actions/checkout@v4

      - name: Run Augmentor (Full Mode)
        uses: MoranaApps/living-doc-augmentor-gh@main
        with:
          regime: augmentor
          scan-mode: ${{ github.event.inputs.augmentation-type != '' && 'per-type' || 'full' }}
          augmentation-type: ${{ github.event.inputs.augmentation-type }}
          config-path: augmentation_types.yml
          fail-on-violations: 'false'
```

#### 11.1.3 Collector (Extract Annotations for Release)

```yaml

name: Living Doc Collector

on:
  release:
    types: [ published ]
  workflow_dispatch:

jobs:
  collect-annotations:
    runs-on: ubuntu-latest
    name: Extract All Annotations
    steps:
      - uses: actions/checkout@v4

      - name: Run Collector
        id: collector
        uses: MoranaApps/living-doc-augmentor-gh@main
        with:
          regime: collector
          config-path: augmentation_types.yml
          output-path: code_augmentations.json

      - name: Upload Augmentation Data
        uses: actions/upload-artifact@v4
        with:
          name: code-augmentations
          path: code_augmentations.json

      - name: Summary
        run: |
          echo "### Living Doc Collector Results" >> $GITHUB_STEP_SUMMARY
          echo "- **Annotations found:** ${{ steps.collector.outputs.annotations-count }}" >> $GITHUB_STEP_SUMMARY
          echo "- **Output file:** ${{ steps.collector.outputs.output-file }}" >> $GITHUB_STEP_SUMMARY
```

## 12. Quality Gates

Modeled after AbsaOSS/generate-release-notes, the repository enforces the following quality gates:

### 12.1 CI Workflows

Workflow	Trigger	Description
Unit Tests	PR, push to main	Run pytest with coverage ≥ 80%
Integration Tests	PR, push to main	End-to-end tests with sample repositories
Linting (pylint)	PR, push to main	Pylint score ≥ 9.0/10
Linting (ruff)	PR, push to main	Zero ruff violations
Type Checking (mypy)	PR, push to main	Strict mode, zero errors
Code Formatting (black)	PR, push to main	Zero formatting violations
Dependency Audit	PR, scheduled	Check for known vulnerabilities
PR Title Convention	PR	Enforce conventional commit format
YAML Validation	PR	Validate action.yml and example configs

### 12.2 Branch Protection Rules

- Require PR reviews (≥ 1 approval).
- Require all status checks to pass before merging.
- Require linear history (no merge commits).
- Require signed commits (recommended).

### 12.3 Configuration Files (modeled after generate-release-notes)

File	Purpose
.pylintrc	Pylint configuration (see generate-release-notes/.pylintrc)
pyproject.toml	Project metadata, black/mypy/ruff configuration
requirements.txt	Runtime dependencies
requirements-dev.txt	Development/testing dependencies
renovate.json	Automated dependency updates (see generate-release-notes/renovate.json)

## 13. Repository Structure

```code
living-doc-augmentor-gh/
├── .github/
│   ├── workflows/
│   │   ├── ci.yml                        # Unit tests, linting, type checking
│   │   ├── integration_tests.yml         # Integration tests
│   │   ├── check_pr_title.yml            # PR title convention
│   │   ├── release_draft.yml             # Release draft automation
│   │   └── dependabot.yml                # Dependency management
│   └── CODEOWNERS
├── living_doc_augmentor/
│   ├── __init__.py
│   ├── augmentor.py                      # Augmentor regime logic
│   ├── collector.py                      # Collector regime logic
│   ├── scanner.py                        # Core scanning engine
│   ├── config.py                         # Configuration loader & validator
│   ├── models.py                         # Data models (Pydantic)
│   ├── diff_parser.py                    # PR diff parsing for PR mode
│   ├── formatters.py                     # Output formatting (JSON, GitHub annotations)
│   └── utils.py                          # Shared utilities
├── tests/
│   ├── unit/
│   │   ├── test_augmentor.py
│   │   ├── test_collector.py
│   │   ├── test_scanner.py
│   │   ├── test_config.py
│   │   ├── test_models.py
│   │   └── test_diff_parser.py
│   ├── integration/
│   │   ├── test_augmentor_pr_mode.py
│   │   ├── test_augmentor_full_mode.py
│   │   ├── test_collector_e2e.py
│   │   └── fixtures/
│   │       ├── sample_repo/              # Sample repo with annotations
│   │       ├── augmentation_types.yml    # Test configuration
│   │       └── expected_output.json      # Expected collector output
│   └── conftest.py
├── examples/
│   ├── augmentation_types.yml            # Example configuration
│   ├── workflow_pr_check.yml             # Example PR workflow
│   ├── workflow_full_scan.yml            # Example full-scan workflow
│   └── workflow_collector.yml            # Example collector workflow
├── docs/
│   └── SPEC.md                           # This file
├── action.yml                            # Composite action definition
├── main.py                               # Entry point
├── requirements.txt                      # Runtime dependencies
├── requirements-dev.txt                  # Dev/test dependencies
├── pyproject.toml                        # Project configuration
├── .pylintrc                             # Pylint configuration
├── renovate.json                         # Renovate bot configuration
├── .gitignore
├── LICENSE
├── CONTRIBUTING.md
├── DEVELOPER.md
├── README.md
└── SPEC.md                               # → docs/SPEC.md (symlink or copy)
```

## 14. Copilot Extensibility

The augmentor detection logic is designed to be extensible by GitHub Copilot:

### 14.1 Plugin Architecture

The scanner supports pluggable detection strategies:

```python
class DetectionStrategy(Protocol):
    """Protocol for annotation detection strategies."""

    def detect(self, file_content: str, file_path: str, config: AugmentationConfig) -> list[Annotation]:
        """Detect annotations in file content."""
        ...
```

### 14.2 Built-in Strategies

Strategy	Description
RegexDetectionStrategy	Pattern-based detection using regex from augmentation_types.yml
DocstringDetectionStrategy	Python docstring-aware detection (understands docstring boundaries)
CommentBlockDetectionStrategy	Generic comment block detection (/** */, # ..., <!-- -->)

### 14.3 Copilot Extension Points

- Custom detection strategies: Copilot can generate new DetectionStrategy implementations for project-specific patterns.
- Augmentation type templates: Copilot can generate augmentation_types.yml entries based on project conventions.
- Rule generation: Copilot can analyze existing code and suggest appropriate annotation rules.
- False positive tuning: Detection thresholds and exclusion patterns can be refined with Copilot assistance.

### 14.4 Copilot-Friendly Code Patterns

All core modules include:

- Comprehensive type hints (Python 3.14 style).
- Detailed docstrings explaining intent and contracts.
- Clear separation of concerns enabling targeted modifications.
- Well-defined interfaces (Protocol classes) for extensibility.

## 15. Roadmap

### Phase 1 — Foundation (v0.1.0)
[ ] Repository scaffolding with quality gates
[ ] Configuration schema (augmentation_types.yml) and validator
[ ] Core scanner with regex-based detection
[ ] Augmentor regime — full scan mode
[ ] Collector regime — JSON output
[ ] Unit tests (≥ 80% coverage)
[ ] action.yml composite action definition

### Phase 2 — PR Integration (v0.2.0)
[ ] PR diff parsing for PR mode
[ ] GitHub Actions annotations for violations
[ ] Augmentor PR mode with changed-files-only scanning
[ ] Integration tests with sample repositories
[ ] Example workflows for AbsaOSS/generate-release-notes

### Phase 3 — Advanced Features (v0.3.0)
[ ] Per-type scan mode
[ ] Multiple detection strategies (docstring-aware, comment-block-aware)
[ ] Copilot extension point documentation
[ ] JSON Schema validation for output
[ ] Summary report in $GITHUB_STEP_SUMMARY

### Phase 4 — Maturity (v1.0.0)
[ ] AST-based detection for Python (optional enhancement)
[ ] Caching for faster incremental scans
[ ] Configurable severity levels for violations
[ ] Multi-language support (Python, TypeScript, Java)
[ ] Published to GitHub Marketplace

## Appendix A — Glossary

Term	Definition
Augmentation	The process of enriching source code with structured annotations for living documentation
Augmentation Type	A defined category of annotation (e.g., Feature, AC, TestEvidence) with rules for placement and extraction
Annotation	A structured comment/tag in source code following the @LivDoc:<Type>(value) convention
Augmentor	The regime that validates annotations conform to defined rules
Collector	The regime that extracts all annotations into structured JSON
Detection Strategy	A pluggable algorithm for finding annotations in source code

