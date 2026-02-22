# Living Documentation — Source Code Augmentor GitHub Action

## Specification

> **Version:** 0.1.0-draft  
> **Date:** 2026-02-19  
> **Status:** Draft  

---

## Table of Contents

1. [Overview](#1-overview)
2. [Goals & Non-Goals](#2-goals--non-goals)
3. [Architecture](#3-architecture)
4. [Regimes (Operating Modes)](#4-regimes-operating-modes)
5. [Augmentation Type System](#5-augmentation-type-system)
6. [Location Detection System](#6-location-detection-system)
7. [Comment Format Specification](#7-comment-format-specification)
8. [Augmentation Type Catalogue — IT Project Examples](#8-augmentation-type-catalogue--it-project-examples)
9. [Configuration](#9-configuration)
10. [Ignore Rules](#10-ignore-rules)
11. [Action Inputs & Outputs](#11-action-inputs--outputs)
12. [Collector Output Schema](#12-collector-output-schema)
13. [GitHub Action Definition (action.yml)](#13-github-action-definition-actionyml)
14. [Example Workflows](#14-example-workflows)
15. [Quality Gates](#15-quality-gates)
16. [Repository Structure](#16-repository-structure)
17. [AI Assistant Integration](#17-ai-assistant-integration)
18. [Error Reporting & Diagnostics](#18-error-reporting--diagnostics)
19. [Versioning & Compatibility](#19-versioning--compatibility)
20. [Security Considerations](#20-security-considerations)
21. [Performance & Scalability](#21-performance--scalability)
22. [Tutorial — Full Augmentation Examples](#22-tutorial--full-augmentation-examples)
23. [Roadmap](#23-roadmap)

---

## 1. Overview

**Living Documentation Source Code Augmentor** (`living-doc-augmentor-gh`) is a **composite GitHub Action** written in **Python 3.14** that enriches source code with structured annotations and extracts those annotations into machine-readable output.

The action operates in two distinct regimes:

| Regime | Purpose |
|---|---|
| **Augmentor** | Search for location without annotations and report violations based on user-defined augmentation types and rules. Runs in PR mode (changed files only) or full-scan mode (entire repository). |
| **Collector** | Extracts all augmented data from source code into a structured JSON output for upstream consumption |

---

## 2. Goals & Non-Goals

### Goals

- **G1:** Provide a composite GitHub Action (Python 3.14) for augmenting and collecting structured annotations from source code.
- **G2:** Support two regimes — **augmentor** (validation) and **collector** (extraction).
- **G3:** Allow user-defined augmentation types with configurable rules for placement and detection.
- **G4:** Provide a **generic, language-agnostic solution** where all detection behavior is driven by flexible, user-defined rules — not hard-coded to any single framework or language.
- **G5:** Implement a **flexible location detection system** with composable target scoping rules (file globs, code structure targets, comment-style awareness) that can adapt to any project convention.
- **G6:** Run augmentor in PR mode (validate only changed files) and full-scan mode (validate entire repository).
- **G7:** Run augmentor on demand, optionally scoped to a specific augmentation type.
- **G8:** Produce deterministic, structured JSON output (`code_augmentations.json`) from the collector.
- **G9:** Maintain strong quality gates (linting, type checking, unit tests, integration tests, code coverage) modeled after [AbsaOSS/generate-release-notes](https://github.com/AbsaOSS/generate-release-notes).
- **G10:** Provide **first-class AI assistant integration** — including Copilot instructions, agent-mode support, custom chat participants, and AI-assisted annotation authoring. Designed to be model-agnostic (GitHub Copilot, Claude, Gemini, etc.).
- **G11:** Ship a rich **augmentation type catalogue** with ready-to-use examples for common IT project documentation needs (features, requirements, test evidence, API contracts, ADRs, SLAs, ownership, deprecation notices, decisions, glossary, domain objects, project descriptions, and more).
- **G12:** Support **multiple `augmentation_types.yml` files** to allow separate namespaces and prefixes for different concerns (e.g., one for QA, one for architecture, one for operations).
- **G13:** Provide **ignore rules** (`@LivDoc:Ignore`) so developers can suppress specific augmentor violations where intentional, preserving user decisions.
- **G14:** Provide a **tutorial document** with full, multiline augmentation examples for every catalogue type — serving as an onboarding guide.
- **G15:** Support **cross-language annotation parity** — the same semantic annotation can appear in files of different languages, each requiring language-specific comment patterns while sharing the same augmentation type definition.

### Non-Goals

- UI rendering of living documentation (handled by upstream consumers).
- Language-specific AST parsing in v1 (regex/pattern-based detection first; AST is a future enhancement).
- Replacing dedicated documentation tools (Sphinx, MkDocs, etc.) — this action augments source code, it does not generate final documentation artifacts.

> **Note:** Source code auto-modification (auto-fix of missing annotations) is **not** in scope for the augmentor itself. However, AI assistants (Copilot, Claude, etc.) integrated via §17 can suggest and apply annotations in the developer's editor. The augmentor validates; the AI assistant authors.

---

## 3. Architecture

```
┌─────────────────────────────────────────────────────────┐
│                GitHub Action (composite)                 │
│                                                         │
│  ┌──────────────┐   ┌───────────────────────────────┐   │
│  │  action.yml   │───▶│ main.py (Python 3.14 entry)  │   │
│  └──────────────┘   └──────────┬────────────────────┘   │
│                                │                        │
│                  ┌─────────────┴────────────┐           │
│                  ▼                          ▼           │
│         ┌──────────────┐          ┌──────────────┐      │
│         │  Augmentor   │          │  Collector   │      │
│         │   Regime     │          │   Regime     │      │
│         └──────┬───────┘          └──────┬───────┘      │
│                │                         │              │
│    ┌───────────┴──────────┐              │              │
│    ▼                      ▼              ▼              │
│ ┌──────────┐  ┌────────────┐  ┌──────────────────┐      │
│ │ PR Mode  │  │ Full Scan  │  │ JSON Extractor   │      │
│ │  (diff)  │  │(repo-wide) │  │ (aggregate all)  │      │
│ └──────────┘  └────────────┘  └──────────────────┘      │
│                                                         │
│  ┌─────────────────────────────────────────────────┐    │
│  │   augmentation_types.yml (user-defined rules)   │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```


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

#### 4.1.4 Augmentor Output

Each augmentor run produces a **structured result** containing:

| Output | Description |
|---|---|
| **Violations list** | One entry per violation: file, line, target name, target kind, expected augmentation type, severity, message |
| **Annotations found** | All valid annotations discovered during the scan (same structure as collector, but scoped to scanned files) |
| **Ignored locations** | Locations where violations were suppressed by `@LivDoc:Ignore` rules (see §10) |
| **Summary counts** | Total files scanned, files with violations, violation count by type and severity |
| **`$GITHUB_STEP_SUMMARY`** | Human-readable report written to the GitHub Actions step summary |
| **GitHub annotations** | `::error`, `::warning`, `::notice` annotations attached to specific files and lines in the PR |

The augmentor outputs are available as action outputs (see §11) and optionally as a JSON report file.

#### 4.1.5 Augmentor Exit Codes

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

### 5.1 Multiple Configuration Files

The action supports **multiple `augmentation_types.yml` files**, each defining its own namespace (prefix). This allows teams to separate concerns:

```yaml
# Action input — comma-separated list of config files
config-path: "livdoc_core.yml,livdoc_qa.yml,livdoc_ops.yml"
```

Each file defines its own `annotation_prefix`. The prefix is **automatically prepended** to all type names — there is no need to repeat the prefix in each type's `tag` or `pattern`. The action auto-generates the `tag` as `<prefix>:<name>` and the `pattern` as `<prefix>:<name>\(([^)]+)\)`.

### 5.2 Type Properties

| Property | Type | Required | Description |
|---|---|---|---|
| `name` | `string` | yes | Unique identifier within this config file (e.g., `Feature`, `AC`). The full tag is auto-derived as `<prefix>:<name>`. |
| `target` | `string` | yes | Where the annotation must appear. Built-in values: `function`, `class`, `module`, `method`, `any`. **Custom targets** can be defined in the `languages` section (see §6). |
| `required` | `boolean` | no | Whether the annotation is mandatory for matching targets (default: `false`) |
| `file_patterns` | `list[string]` | yes | Glob patterns for files where this type applies |
| `description` | `string` | no | Human-readable description |
| `extraction_rules` | `object` | no | Rules for extracting structured data from the annotation body |
| `severity` | `enum` | no | Violation severity when missing: `error`, `warning`, `info` (default: `error`) |
| `multi_value` | `boolean` | no | Whether the annotation accepts comma-separated values (default: `false`) |
| `multiline` | `boolean` | no | Whether the annotation body can span multiple lines (default: `false`) |
| `deprecated` | `boolean` | no | Mark as deprecated — still collected but violations become warnings (default: `false`) |
| `target_document` | `string` | no | The intended downstream document this annotation feeds (e.g., `Technical Design`, `Test Report`, `API Reference`) |
| `audience` | `enum` | no | Primary audience: `technical`, `business`, `qa`, `architecture`, `operations`, `security` |
| `pattern` | `string` (regex) | no | **Override** — custom regex if the auto-generated pattern is insufficient |

### 5.3 Annotation Placement — Inside vs. Outside the Object

Annotations are always detected in the **comment block immediately preceding or inside** the target code construct:

- **Inside (docstring):** The annotation is inside the object's own docstring (Python `"""`, Javadoc `/** */`). This is the **preferred** placement.
- **Preceding (comment above):** The annotation is in a comment block directly above the object declaration (e.g., `# @LivDoc:Feature(F-1)` above a Python class, or `// @LivDoc:Feature(F-1)` above a TypeScript class).

For compact constructs (e.g., Scala one-line classes, TypeScript type aliases), the preceding-comment form is the only option:

```scala
// @LivDoc:DomainEvent(OrderPlaced)
case class OrderPlaced(orderId: String, timestamp: Instant)
```

The scanner considers a comment block to be **associated** with a target if there are **zero blank lines** between the comment's last line and the target's declaration line.

### 5.4 Cross-Language Parity

The same augmentation type can appear in files of different languages. The type definition is language-agnostic; only the **comment delimiters** and **target detection patterns** differ per language (configured in §6). This means:

- A `Feature` annotation in `src/service.py` uses `""" @LivDoc:Feature(F-1) """`.
- The same `Feature` annotation in `src/service.ts` uses `/** @LivDoc:Feature(F-1) */`.
- The same `Feature` annotation in `infra/main.tf` uses `# @LivDoc:Feature(F-1)`.

Both are validated identically by the augmentor and produce identical collector output.

### 5.5 Multi-Value Annotations — Documentation Fragments in Place

The `multi_value: true` property allows a single annotation to carry multiple comma-separated values. The design intent is to **keep documentation fragments as close as possible to the code they describe** — co-locating metadata with its reason-of-existence:

```python
def place_order(self, cart: Cart) -> Order:
    """
    @LivDoc:AC(AC-ORD-001, AC-ORD-002, AC-ORD-003)
    """
    ...
```

Rather than maintaining a separate mapping file, the developer declares all related identifiers inline.

### 5.6 Multiline Annotations

When `multiline: true`, the annotation body can span multiple lines. The body starts after the opening `(` and ends at the matching `)`. This is useful for types that carry longer documentation fragments:

```python
class OrderService:
    """
    @LivDoc:Decision(
        type=technology,
        title=Use PostgreSQL for order storage,
        rationale=ACID compliance required for financial transactions,
        date=2026-01-15,
        status=accepted
    )
    @LivDoc:Glossary(
        term=Order,
        definition=A confirmed purchase request containing one or more
            line items with quantities and prices
    )
    """
    ...
```

### 5.7 Example Configuration

```yaml
version: "1.0"

annotation_prefix: "@LivDoc"

types:
  - name: Feature
    target: class
    required: true
    file_patterns:
      - "src/**/*.py"
    description: "Links a class to a feature identifier from the feature registry."
    target_document: "Feature Matrix"
    audience: business
    extraction_rules:
      capture_groups:
        - name: feature_id
          group: 1

  - name: AC
    target: method
    required: false
    multi_value: true
    file_patterns:
      - "src/**/*.py"
      - "tests/**/*.py"
    description: "Links a method to acceptance criteria."
    target_document: "Acceptance Criteria Report"
    audience: qa

  - name: TestEvidence
    target: function
    required: true
    file_patterns:
      - "tests/**/*.py"
    description: "Links a test function to the requirement it verifies."
    target_document: "Test Traceability Matrix"
    audience: qa

  - name: Decision
    target: class
    required: false
    multiline: true
    file_patterns:
      - "src/**/*.py"
      - "src/**/*.ts"
    description: "Records a technology, library, or business decision in-place."
    target_document: "Decision Log"
    audience: architecture

  - name: Glossary
    target: class
    required: false
    multiline: true
    file_patterns:
      - "src/**/*.py"
    description: "Defines a domain term at the point where the concept is implemented."
    target_document: "Domain Glossary"
    audience: business

  - name: DomainObject
    target: class
    required: false
    file_patterns:
      - "src/domain/**/*.py"
      - "src/models/**/*.py"
    description: "Marks a class as a domain object with its bounded context."
    target_document: "Domain Model"
    audience: architecture

  - name: ProjectDescription
    target: module
    required: false
    multiline: true
    file_patterns:
      - "README.md"
      - "docs/**/*.md"
      - "**/__init__.py"
    description: "Captures high-level project or module description for living documentation."
    target_document: "Project Overview"
    audience: business
```

> **Note:** The `tag` and `pattern` fields are **not present** — they are auto-derived from `annotation_prefix` + `name`. If a type needs a non-standard pattern (e.g., multiline with key-value syntax), provide an explicit `pattern` override.

---

## 6. Location Detection System

The location detection system is the core mechanism that determines **where** in a codebase the augmentor looks for annotations and **what code structures** are expected to carry them. It is designed to be fully generic and rule-driven — no behavior is hard-coded to a specific language or framework.

### 6.1 Design Principles

- **Rule-driven:** All detection behavior is specified in `augmentation_types.yml`. Zero detection logic is language-specific in the core engine.
- **Composable scoping:** File-level globs, code-structure targets, and comment-style awareness combine independently.
- **Multi-language:** Comment extraction supports Python, TypeScript/JavaScript, Java, C#, Go, Rust, and any language with configurable comment delimiters.
- **Extensible:** Users (and Copilot) can add custom location matchers without modifying the scanner core.

### 6.2 Scoping Layers

Location detection operates through three composable layers:

```
┌───────────────────────────────────────────┐
│  Layer 1 — File Selection (globs)         │  Which files to scan?
├───────────────────────────────────────────┤
│  Layer 2 — Code Structure (targets)       │  Which constructs within those files?
├───────────────────────────────────────────┤
│  Layer 3 — Comment Style (delimiters)     │  Which comment format to parse?
└───────────────────────────────────────────┘
```

#### Layer 1 — File Selection

Driven by `file_patterns` and `exclude_patterns` on each augmentation type:

```yaml
file_patterns:
  - "src/**/*.py"           # All Python files under src/
  - "lib/**/*.ts"           # All TypeScript files under lib/
  - "!**/generated/**"      # Exclude generated code (negation globs)
```

#### Layer 2 — Code Structure Targets

The `target` property scopes annotations to specific code constructs. Built-in targets provide common defaults, but **targets are fully customizable** per language. Users can define any target name and provide a regex pattern for it — the system imposes no fixed enum:

| Built-in Target | Description | Default Detection |
|---|---|---|
| `class` | Class / interface / struct definitions | `^(class\|interface\|struct)\s+\w+` |
| `function` | Top-level functions | `^(def\|function\|func\|fn)\s+\w+` |
| `method` | Methods inside a class | Indented function definitions within class scope |
| `module` | File/module-level (top of file) | First comment block in the file |
| `any` | Any comment block, anywhere | No structural constraint |
| `constructor` | Constructor / initializer | `__init__`, `constructor`, etc. |
| `decorator` | Decorated functions/classes | Decorator syntax above the target |
| `endpoint` | REST/GraphQL endpoint handlers | Route decorator or annotation patterns |

**Custom targets** — users can add any target name with a regex:

```yaml
languages:
  terraform:
    targets:
      resource: '^\s*resource\s+"(\w+)"\s+"(\w+)"'
      data_source: '^\s*data\s+"(\w+)"\s+"(\w+)"'
      variable: '^\s*variable\s+"(\w+)"'
      output: '^\s*output\s+"(\w+)"'
      module_block: '^\s*module\s+"(\w+)"'
  scala:
    targets:
      case_class: '^\s*case\s+class\s+(\w+)'
      object: '^\s*(case\s+)?object\s+(\w+)'
      trait: '^\s*(sealed\s+)?trait\s+(\w+)'
      val: '^\s*(lazy\s+)?val\s+(\w+)'
```

Target patterns are configured per language in a `languages` section:

```yaml
languages:
  python:
    extensions: [".py"]
    comment_styles:
      - docstring: '"""'
      - hash: "#"
    targets:
      class: '^\s*class\s+(\w+)'
      function: '^\s*def\s+(\w+)'
      method: '^\s{4,}def\s+(\w+)'
      module: '__file_header__'
      constructor: '^\s+def\s+__init__\s*\('
      decorator: '^\s*@\w+'
      endpoint: '^\s*@(app|router)\.(get|post|put|delete|patch)'

  typescript:
    extensions: [".ts", ".tsx"]
    comment_styles:
      - jsdoc: '/** */'
      - line: '//'
    targets:
      class: '^\s*(export\s+)?(abstract\s+)?class\s+(\w+)'
      function: '^\s*(export\s+)?(async\s+)?function\s+(\w+)'
      method: '^\s+(async\s+)?(\w+)\s*\('
      module: '__file_header__'
      constructor: '^\s+constructor\s*\('
      endpoint: '^\s*@(Get|Post|Put|Delete|Patch)\('
      type_alias: '^\s*(export\s+)?type\s+(\w+)\s*='
      interface: '^\s*(export\s+)?interface\s+(\w+)'

  java:
    extensions: [".java"]
    comment_styles:
      - javadoc: '/** */'
      - line: '//'
    targets:
      class: '^\s*(public|protected|private)?\s*(abstract\s+)?class\s+(\w+)'
      function: '^\s*(public|protected|private)?\s*(static\s+)?\w+\s+(\w+)\s*\('
      module: '__file_header__'
      constructor: '^\s*(public|protected|private)?\s+(\w+)\s*\(.*\)\s*\{'
      endpoint: '^\s*@(Get|Post|Put|Delete|Patch)Mapping'
      interface: '^\s*(public\s+)?interface\s+(\w+)'

  scala:
    extensions: [".scala", ".sc"]
    comment_styles:
      - scaladoc: '/** */'
      - line: '//'
    targets:
      class: '^\s*(case\s+)?class\s+(\w+)'
      object: '^\s*(case\s+)?object\s+(\w+)'
      trait: '^\s*(sealed\s+)?trait\s+(\w+)'
      function: '^\s*def\s+(\w+)'
      module: '__file_header__'
      val: '^\s*(lazy\s+)?val\s+(\w+)'

  terraform:
    extensions: [".tf"]
    comment_styles:
      - hash: "#"
      - block: '/* */'
    targets:
      resource: '^\s*resource\s+"(\w+)"\s+"(\w+)"'
      data_source: '^\s*data\s+"(\w+)"\s+"(\w+)"'
      variable: '^\s*variable\s+"(\w+)"'
      output: '^\s*output\s+"(\w+)"'
      module_block: '^\s*module\s+"(\w+)"'

  html:
    extensions: [".html", ".htm", ".svg"]
    comment_styles:
      - xml: '<!-- -->'
    targets:
      module: '__file_header__'
      any: '__any__'

  xml:
    extensions: [".xml", ".xsd", ".wsdl", ".pom"]
    comment_styles:
      - xml: '<!-- -->'
    targets:
      module: '__file_header__'
      any: '__any__'

  markdown:
    extensions: [".md", ".mdx"]
    comment_styles:
      - html: '<!-- -->'
    targets:
      module: '__file_header__'
      any: '__any__'

  text:
    extensions: [".txt", ".csv", ".log"]
    comment_styles:
      - hash: "#"
    targets:
      module: '__file_header__'
      any: '__any__'

  yaml:
    extensions: [".yml", ".yaml"]
    comment_styles:
      - hash: "#"
    targets:
      module: '__file_header__'
      any: '__any__'

  shell:
    extensions: [".sh", ".bash", ".zsh"]
    comment_styles:
      - hash: "#"
    targets:
      function: '^\s*(function\s+)?(\w+)\s*\(\s*\)'
      module: '__file_header__'

  sql:
    extensions: [".sql"]
    comment_styles:
      - line: '--'
      - block: '/* */'
    targets:
      module: '__file_header__'
      any: '__any__'

  glue_job:
    extensions: [".py"]         # AWS Glue jobs are Python, but may need custom targets
    inherits: python             # Inherit Python defaults, override selectively
    targets:
      job_entry: '^\s*def\s+(main|run|process)\s*\('
```

> **Extensibility guarantee:** The `target` field is a free-form string matched against the `languages.<lang>.targets` map. Adding a new target requires only a new entry in the YAML — no code changes.

#### Layer 3 — Comment Style Awareness

The scanner understands different comment styles per language:

| Style | Languages | Example |
|---|---|---|
| Docstring (`"""`) | Python | `"""@LivDoc:Feature(F-1)"""` |
| JSDoc / Javadoc / Scaladoc (`/** */`) | TypeScript, JavaScript, Java, C#, Scala | `/** @LivDoc:Feature(F-1) */` |
| Hash (`#`) | Python, Ruby, YAML, Shell, Terraform | `# @LivDoc:Feature(F-1)` |
| Line (`//`) | TypeScript, JavaScript, Java, Go, Rust, C#, Scala | `// @LivDoc:Feature(F-1)` |
| Block (`/* */`) | C, C++, Go, CSS, Terraform, SQL | `/* @LivDoc:Feature(F-1) */` |
| XML (`<!-- -->`) | HTML, XML, SVG, Markdown | `<!-- @LivDoc:Feature(F-1) -->` |
| SQL line (`--`) | SQL | `-- @LivDoc:Feature(F-1)` |

### 6.3 Custom Location Matchers

For advanced use cases, users can define custom matchers combining multiple conditions:

```yaml
types:
  - name: APIContract
    tag: "@LivDoc:APIContract"
    pattern: '@LivDoc:APIContract\(([^)]+)\)'
    target: endpoint                          # Only on endpoint handlers
    required: true
    file_patterns:
      - "src/api/**/*.py"
      - "src/routes/**/*.ts"
    location_matcher:                          # Advanced location rules
      must_be_preceded_by:
        - "@app.route"                         # Python Flask
        - "@router."                           # Python FastAPI
        - "@Get\\(|@Post\\(|@Put\\("          # NestJS decorators
      max_distance_lines: 5                    # Annotation must be within 5 lines of the target
    description: "Documents a public API endpoint with its contract ID."
```

### 6.4 Location Detection Protocol

```python
class LocationMatcher(Protocol):
    """Protocol for custom location matching logic."""

    def matches(
        self,
        file_path: str,
        line_number: int,
        context_lines: list[str],
        target_kind: str,
    ) -> bool:
        """Return True if this location is a valid placement for the annotation."""
        ...
```

---

## 7. Comment Format Specification

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

```typescript
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

### Java (Javadoc)

```java
/**
 * Manages payment processing.
 *
 * @LivDoc:Feature(PAY-001)
 * @LivDoc:Owner(team-payments)
 */
public class PaymentService {
    /**
     * Process a single payment transaction.
     *
     * @LivDoc:AC(AC-PAY-001)
     * @LivDoc:SLA(latency-p99, 200ms)
     */
    public PaymentResult processPayment(PaymentRequest request) {
        ...
    }
}
```

### General Rules

- Annotations MUST appear inside comment blocks (docstrings, `/** */`, `# comments`, `<!-- -->`, `--`).
- The annotation comment block must be **immediately preceding** (zero blank lines before) or **inside** the target construct.
- For single-line constructs (Scala `case class`, TypeScript `type`, etc.), the preceding-comment form is required.
- Multiple annotations per comment block are allowed.
- Annotations with multiple values use comma separation: `@LivDoc:AC(AC-001, AC-002)`.
- Multiline annotations (when `multiline: true`) span from `(` to the matching `)` across lines.
- Annotations are case-sensitive.
- Unrecognized annotations (not in any loaded config) are reported as warnings.
- Annotations can carry key-value metadata: `@LivDoc:SLA(latency-p99, 200ms)`.
- Annotations do **not** replace inner code documentation links (e.g., Gherkin step references in test code remain as-is; the annotation adds traceability metadata alongside them).

### Scala

```scala
/**
 * Order aggregate root.
 *
 * @LivDoc:Aggregate(Order)
 * @LivDoc:BoundedContext(OrderManagement)
 * @LivDoc:Feature(ORD-001)
 */
class Order(val id: OrderId, val items: List[LineItem]) {
  /**
   * @LivDoc:AC(AC-ORD-001)
   * @LivDoc:DomainEvent(OrderPlaced)
   */
  def place(): OrderPlaced = ???
}

// @LivDoc:DomainEvent(OrderPlaced)
case class OrderPlaced(orderId: String, timestamp: Instant)

// @LivDoc:Glossary(term=Line Item, definition=A single product entry with quantity in an order)
case class LineItem(product: Product, quantity: Int)
```

### Terraform

```hcl
# @LivDoc:Feature(INFRA-VPC-001)
# @LivDoc:Owner(team-platform)
# @LivDoc:Decision(
#   type=technology,
#   title=Use AWS VPC with private subnets,
#   rationale=Security requirement for PCI-DSS compliance,
#   date=2026-01-10,
#   status=accepted
# )
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# @LivDoc:Tier(tier-1)
# @LivDoc:SLA(availability, 99.95%)
resource "aws_rds_instance" "orders_db" {
  engine         = "postgres"
  instance_class = "db.r6g.xlarge"
}
```

### HTML / Markdown

```html
<!-- @LivDoc:ProjectDescription(
  name=Order Management UI,
  purpose=Customer-facing order placement and tracking interface,
  team=team-frontend
) -->
<!DOCTYPE html>
<html>
  ...
</html>
```

```markdown
<!-- @LivDoc:ProjectDescription(
  name=Living Doc Augmentor,
  purpose=GitHub Action for structured source code annotations,
  version=0.1.0
) -->
# Living Documentation Augmentor
...
```

### AWS Glue Job (Python)

```python
"""
ETL job: Transform raw orders into analytics-ready format.

@LivDoc:Feature(ANALYTICS-001)
@LivDoc:Owner(team-data)
@LivDoc:Tier(tier-2)
@LivDoc:Decision(
    type=technology,
    title=Use Glue Spark for order ETL,
    rationale=Native AWS integration with S3 and Redshift,
    date=2026-02-01,
    status=accepted
)
"""
def main():
    ...
```

### Multiline Annotation Examples

When `multiline: true` is set on a type, the annotation body spans from `(` to `)` across lines:

```python
class PaymentProcessor:
    """
    @LivDoc:Decision(
        type=library,
        title=Use Stripe SDK for payment processing,
        rationale=Best-in-class API reliability and PCI compliance,
        alternatives=Adyen\, Braintree,
        date=2026-01-20,
        status=accepted
    )
    @LivDoc:Glossary(
        term=Payment Processor,
        definition=A service that handles the authorization and capture
            of payment transactions through external payment gateways
    )
    @LivDoc:DomainObject(PaymentProcessor)
    """
    ...
```

```typescript
/**
 * @LivDoc:Decision(
 *   type=business,
 *   title=Support only EUR and USD currencies,
 *   rationale=Initial market scope limited to EU and US,
 *   date=2026-02-01,
 *   status=accepted
 * )
 */
class CurrencyService {
    ...
}
```

---

## 8. Augmentation Type Catalogue — IT Project Examples

This section provides a comprehensive catalogue of augmentation types commonly needed in IT projects. These serve as ready-to-use examples and can be mixed and matched in any `augmentation_types.yml`.

### 8.1 Requirements & Traceability

| Type | Tag | Target | Target Document | Audience | Purpose |
|---|---|---|---|---|---|
| **Feature** | `@LivDoc:Feature(ID)` | `class` | Feature Matrix | Business | Links code to a feature in the feature registry / backlog |
| **UserStory** | `@LivDoc:UserStory(ID)` | `class`, `method` | User Story Map | Business | Traces code to a user story (e.g., Jira, Azure DevOps) |
| **Requirement** | `@LivDoc:Requirement(ID)` | `any` | Requirements Traceability Matrix | Business | Links to a formal requirement (e.g., DOORS, ReqIF) |
| **AC** | `@LivDoc:AC(ID, ...)` | `method` | Acceptance Criteria Report | QA | Maps to acceptance criteria — supports multiple values |
| **Epic** | `@LivDoc:Epic(ID)` | `module`, `class` | Epic Overview | Business | Groups code under a high-level epic |

**Example:**

```python
class OrderService:
    """
    Handles order lifecycle management.

    @LivDoc:Feature(ORD-001)
    @LivDoc:UserStory(US-2345)
    @LivDoc:Epic(E-100)
    """

    def place_order(self, cart: Cart) -> Order:
        """
        Place a new order from the shopping cart.

        @LivDoc:AC(AC-ORD-001, AC-ORD-002)
        @LivDoc:Requirement(REQ-ORD-PLACE-001)
        """
        ...
```

### 8.2 Testing & Quality Evidence

| Type | Tag | Target | Target Document | Audience | Purpose |
|---|---|---|---|---|---|
| **TestEvidence** | `@LivDoc:TestEvidence(REQ-ID)` | `function` | Test Traceability Matrix | QA | Links a test to the requirement it verifies |
| **TestCategory** | `@LivDoc:TestCategory(category)` | `class`, `function` | Test Report | QA | Classifies tests: `unit`, `integration`, `e2e`, `performance`, `security` |
| **PageObject** | `@LivDoc:PageObject(name)` | `class` | Page Object Catalogue / BDD Keyword Reference | QA | Marks a class as a UI page object — see BDD keyword catalogue below |
| **TestData** | `@LivDoc:TestData(fixture)` | `function` | Test Data Inventory | QA | Documents the test data/fixture a test relies on |
| **CoverageExclusion** | `@LivDoc:CoverageExclusion(reason)` | `function`, `class` | Coverage Report | QA | Documents why code is excluded from coverage |

**Example:**

```python
class TestOrderPlacement:
    """
    @LivDoc:TestCategory(integration)
    @LivDoc:Feature(ORD-001)
    """

    def test_place_order_success(self, sample_cart: Cart):
        """
        @LivDoc:TestEvidence(REQ-ORD-PLACE-001)
        @LivDoc:AC(AC-ORD-001)
        @LivDoc:TestData(fixtures/sample_cart.json)
        """
        ...
```

#### BDD Keyword Catalogue per PageObject

The `PageObject` annotation type is particularly valuable for creating a living **BDD keyword catalogue**. Each PageObject class documents its available actions (keywords) that can be used in Gherkin scenarios:

```python
class LoginPage:
    """
    Page object for the login screen.

    @LivDoc:PageObject(LoginPage)
    @LivDoc:BoundedContext(Authentication)
    @LivDoc:Feature(AUTH-001)
    """

    def enter_username(self, username: str):
        """
        @LivDoc:BDDStep(When the user enters username {username})
        """
        self.username_field.send_keys(username)

    def enter_password(self, password: str):
        """
        @LivDoc:BDDStep(And the user enters password {password})
        """
        self.password_field.send_keys(password)

    def click_login(self):
        """
        @LivDoc:BDDStep(And the user clicks the login button)
        """
        self.login_button.click()

    def verify_error_message(self, expected: str):
        """
        @LivDoc:BDDStep(Then the error message {expected} is displayed)
        """
        assert self.error_label.text == expected
```

The collector extracts this into a structured BDD keyword catalogue — each PageObject becomes a keyword group with its available actions, suitable for generating a living test dictionary.

### 8.3 Architecture & Design Decisions

| Type | Tag | Target | Target Document | Audience | Purpose |
|---|---|---|---|---|---|
| **ADR** | `@LivDoc:ADR(ID)` | `class`, `module` | Architecture Decision Log | Architecture | Links code to an Architecture Decision Record |
| **DesignPattern** | `@LivDoc:DesignPattern(name)` | `class` | Technical Design Document | Technical | Documents the design pattern implemented |
| **BoundedContext** | `@LivDoc:BoundedContext(name)` | `module`, `class` | Domain Model Map | Architecture | DDD bounded context assignment |
| **Aggregate** | `@LivDoc:Aggregate(name)` | `class` | Domain Model | Architecture | Marks an aggregate root in DDD |
| **DomainEvent** | `@LivDoc:DomainEvent(name)` | `class` | Event Catalogue | Architecture | Marks a domain event class |

**Example:**

```python
class OrderRepository:
    """
    Persistence layer for Order aggregates.

    @LivDoc:ADR(ADR-007)
    @LivDoc:DesignPattern(Repository)
    @LivDoc:BoundedContext(OrderManagement)
    """
    ...
```

### 8.4 API & Contract Documentation

| Type | Tag | Target | Target Document | Audience | Purpose |
|---|---|---|---|---|---|
| **APIContract** | `@LivDoc:APIContract(ID)` | `endpoint`, `function` | API Reference | Technical | Links an endpoint to its API contract / OpenAPI operationId |
| **APIVersion** | `@LivDoc:APIVersion(version)` | `class`, `module` | API Version Matrix | Technical | Documents the API version a component belongs to |
| **EventSchema** | `@LivDoc:EventSchema(ID)` | `class` | Event Schema Registry | Architecture | Links a class to an async event schema (Kafka, RabbitMQ) |
| **GraphQLType** | `@LivDoc:GraphQLType(name)` | `class` | GraphQL Schema Docs | Technical | Maps a class to a GraphQL type definition |

**Example:**

```python
@app.post("/api/v2/orders")
async def create_order(request: CreateOrderRequest) -> OrderResponse:
    """
    Create a new order.

    @LivDoc:APIContract(POST-orders-v2)
    @LivDoc:APIVersion(v2)
    @LivDoc:AC(AC-ORD-001)
    """
    ...
```

### 8.5 Ownership & Operational Metadata

| Type | Tag | Target | Target Document | Audience | Purpose |
|---|---|---|---|---|---|
| **Owner** | `@LivDoc:Owner(team)` | `module`, `class` | Service Ownership Map | Operations | Assigns code ownership to a team |
| **SLA** | `@LivDoc:SLA(metric, target)` | `function`, `endpoint` | SLA Dashboard | Operations | Documents SLA expectations (latency, uptime) |
| **Runbook** | `@LivDoc:Runbook(URL)` | `class`, `module` | Runbook Index | Operations | Links to the operational runbook |
| **AlertRule** | `@LivDoc:AlertRule(ID)` | `function` | Alert Catalogue | Operations | Links to a monitoring alert rule |
| **Tier** | `@LivDoc:Tier(level)` | `module`, `class` | Service Tier Map | Operations | Service criticality tier |

**Example:**

```python
class PaymentGateway:
    """
    External payment provider integration.

    @LivDoc:Owner(team-payments)
    @LivDoc:Tier(tier-1)
    @LivDoc:Runbook(https://wiki.internal/runbooks/payment-gateway)
    @LivDoc:SLA(availability, 99.95%)
    """

    def charge(self, amount: Decimal, currency: str) -> ChargeResult:
        """
        @LivDoc:SLA(latency-p99, 500ms)
        @LivDoc:AlertRule(ALERT-PAY-LATENCY-001)
        """
        ...
```

### 8.6 Lifecycle & Deprecation

| Type | Tag | Target | Target Document | Audience | Purpose |
|---|---|---|---|---|---|
| **Deprecated** | `@LivDoc:Deprecated(reason, replacement)` | `any` | Deprecation Report | Technical | Marks code as deprecated with migration guidance |
| **Since** | `@LivDoc:Since(version)` | `any` | Changelog | Technical | Records the version when a component was introduced |
| **PlannedRemoval** | `@LivDoc:PlannedRemoval(version)` | `any` | Deprecation Report | Technical | Scheduled removal version |
| **MigrationGuide** | `@LivDoc:MigrationGuide(URL)` | `class`, `module` | Migration Guide | Technical | Links to migration instructions |

**Example:**

```python
def get_user_legacy(user_id: int) -> dict:
    """
    Legacy user retrieval — use UserService.get_user() instead.

    @LivDoc:Deprecated(Use UserService.get_user(), UserService.get_user)
    @LivDoc:Since(v1.0.0)
    @LivDoc:PlannedRemoval(v3.0.0)
    @LivDoc:MigrationGuide(https://wiki.internal/migration/user-api-v2)
    """
    ...
```

### 8.7 Security & Compliance

| Type | Tag | Target | Target Document | Audience | Purpose |
|---|---|---|---|---|---|
| **SecurityControl** | `@LivDoc:SecurityControl(ID)` | `class`, `function` | Security Controls Matrix | Security | Maps to a security control (OWASP, SOC2) |
| **DataClassification** | `@LivDoc:DataClassification(level)` | `class`, `module` | Data Classification Inventory | Security | Data sensitivity level |
| **ComplianceRule** | `@LivDoc:ComplianceRule(ID)` | `any` | Compliance Report | Security | Links to compliance requirement (GDPR, HIPAA, PCI-DSS) |
| **ThreatModel** | `@LivDoc:ThreatModel(ID)` | `class`, `module` | Threat Model | Security | Links to a threat model entry |

**Example:**

```python
class UserDataStore:
    """
    Stores personally identifiable information.

    @LivDoc:DataClassification(confidential)
    @LivDoc:ComplianceRule(GDPR-ART-17)
    @LivDoc:SecurityControl(OWASP-A01)
    @LivDoc:ThreatModel(TM-USER-DATA-001)
    """
    ...
```

### 8.8 Living Documentation Links

These types are specifically designed for integration with living documentation systems (Cucumber Living Doc, Serenity BDD, Pickles, SpecFlow+LivingDoc, etc.):

| Type | Tag | Target | Target Document | Audience | Purpose |
|---|---|---|---|---|---|
| **GherkinScenario** | `@LivDoc:GherkinScenario(feature:scenario)` | `function` | Living Doc Report | QA | Links test code to a Gherkin scenario |
| **GherkinFeature** | `@LivDoc:GherkinFeature(feature-file)` | `class`, `module` | Living Doc Report | QA | Links implementation to a `.feature` file |
| **BDDStep** | `@LivDoc:BDDStep(step-pattern)` | `function` | BDD Keyword Catalogue | QA | Documents a step definition for BDD frameworks |
| **SpecFlowBinding** | `@LivDoc:SpecFlowBinding(step)` | `method` | SpecFlow Living Doc | QA | Links a SpecFlow step binding |

> **Note:** The annotation does **not** replace inner code links. A Gherkin test function still references its `.feature` file through the test framework’s own mechanism (e.g., `@pytest.mark.usefixtures`, `@CucumberOptions`). The `@LivDoc:GherkinScenario` annotation adds a **traceability layer** for living documentation purposes.

**Example:**

```python
def test_user_login_with_valid_credentials():
    """
    @LivDoc:GherkinScenario(user_auth.feature:Valid login)
    @LivDoc:TestEvidence(REQ-AUTH-001)
    @LivDoc:AC(AC-AUTH-001, AC-AUTH-002)
    """
    ...


class LoginSteps:
    """
    @LivDoc:GherkinFeature(features/user_auth.feature)
    @LivDoc:BoundedContext(Authentication)
    """

    def step_user_enters_credentials(self, username: str, password: str):
        """
        @LivDoc:BDDStep(Given the user enters {username} and {password})
        """
        ...
```

### 8.9 Decisions (Technology, Library, Business)

| Type | Tag | Target | Target Document | Audience | Purpose |
|---|---|---|---|---|---|
| **Decision** | `@LivDoc:Decision(type, title, ...)` | `class`, `module` | Decision Log | Architecture | Records a technology, library, or business decision in-place (multiline) |
| **TechChoice** | `@LivDoc:TechChoice(technology)` | `class`, `module` | Technology Radar | Architecture | Quick tag for a technology choice without full decision context |

**Example:**

```python
class EventBus:
    """
    @LivDoc:Decision(
        type=technology,
        title=Use Apache Kafka for event streaming,
        rationale=High throughput and exactly-once semantics required for order events,
        alternatives=RabbitMQ\, AWS SQS,
        date=2026-01-15,
        status=accepted
    )
    @LivDoc:TechChoice(Apache Kafka)
    """
    ...
```

### 8.10 Glossary & Domain Terms

| Type | Tag | Target | Target Document | Audience | Purpose |
|---|---|---|---|---|---|
| **Glossary** | `@LivDoc:Glossary(term, definition)` | `class` | Domain Glossary | Business | Defines a domain term at the point where the concept is implemented (multiline) |

**Example:**

```python
class ShoppingCart:
    """
    @LivDoc:Glossary(
        term=Shopping Cart,
        definition=A temporary collection of items selected by a customer
            for purchase. A cart becomes an Order upon checkout.
    )
    @LivDoc:BoundedContext(OrderManagement)
    @LivDoc:Aggregate(ShoppingCart)
    """
    ...
```

### 8.11 Domain Objects

| Type | Tag | Target | Target Document | Audience | Purpose |
|---|---|---|---|---|---|
| **DomainObject** | `@LivDoc:DomainObject(name)` | `class` | Domain Model | Architecture | Marks a class as a domain object with its bounded context |
| **ValueObject** | `@LivDoc:ValueObject(name)` | `class` | Domain Model | Architecture | Marks an immutable value object in DDD |
| **DomainService** | `@LivDoc:DomainService(name)` | `class` | Domain Model | Architecture | Marks a domain service (stateless business logic) |

**Example:**

```python
# @LivDoc:ValueObject(Money)
# @LivDoc:Glossary(term=Money, definition=A value object representing an amount with currency)
class Money:
    def __init__(self, amount: Decimal, currency: str):
        ...
```

### 8.12 Project Description Files

| Type | Tag | Target | Target Document | Audience | Purpose |
|---|---|---|---|---|---|
| **ProjectDescription** | `@LivDoc:ProjectDescription(name, purpose, ...)` | `module` | Project Overview | Business | Captures high-level project or module description (multiline) |
| **ModuleDescription** | `@LivDoc:ModuleDescription(name, purpose)` | `module` | Architecture Overview | Technical | Documents a module’s purpose within the system |

**Example (in `__init__.py`):**

```python
"""
@LivDoc:ModuleDescription(
    name=living_doc_augmentor,
    purpose=Core scanning engine and augmentation type system
        for the Living Documentation Source Code Augmentor GitHub Action
)
"""
```

**Example (in `README.md`):**

```markdown
<!-- @LivDoc:ProjectDescription(
    name=Order Management Service,
    purpose=Microservice handling order placement\, tracking\, and fulfillment,
    team=team-orders,
    tier=tier-1
) -->
# Order Management Service
...
```

### 8.13 Summary — Full Catalogue

| Category | Types | Primary Audience |
|---|---|---|
| Requirements & Traceability | `Feature`, `UserStory`, `Requirement`, `AC`, `Epic` | Business |
| Testing & Quality Evidence | `TestEvidence`, `TestCategory`, `PageObject`, `TestData`, `CoverageExclusion` | QA |
| Architecture & Design | `ADR`, `DesignPattern`, `BoundedContext`, `Aggregate`, `DomainEvent` | Architecture |
| API & Contracts | `APIContract`, `APIVersion`, `EventSchema`, `GraphQLType` | Technical |
| Ownership & Operations | `Owner`, `SLA`, `Runbook`, `AlertRule`, `Tier` | Operations |
| Lifecycle & Deprecation | `Deprecated`, `Since`, `PlannedRemoval`, `MigrationGuide` | Technical |
| Security & Compliance | `SecurityControl`, `DataClassification`, `ComplianceRule`, `ThreatModel` | Security |
| Living Documentation | `GherkinScenario`, `GherkinFeature`, `BDDStep`, `SpecFlowBinding` | QA |
| Decisions | `Decision`, `TechChoice` | Architecture |
| Glossary & Domain Terms | `Glossary` | Business |
| Domain Objects | `DomainObject`, `ValueObject`, `DomainService` | Architecture |
| Project Descriptions | `ProjectDescription`, `ModuleDescription` | Business / Technical |

---

## 9. Configuration

### 9.1 Configuration Files

The action reads one or more configuration files specified via the `config-path` input. Multiple files are comma-separated:

```yaml
config-path: "livdoc_core.yml,livdoc_qa.yml,livdoc_ops.yml"
```

Each file defines its own `annotation_prefix`, creating a separate namespace. Types across files must not have conflicting fully-qualified tags (e.g., two files both defining `@LivDoc:Feature` is an error).

### 9.2 Configuration Validation

On startup, the action validates:

- YAML syntax is correct in all config files.
- All required fields are present for each type.
- Regex patterns (explicit or auto-generated) compile successfully.
- File glob patterns are valid.
- No duplicate fully-qualified tags across all loaded config files.
- `annotation_prefix` is present in each config file.

Invalid configuration causes exit code `2`.

---

## 10. Ignore Rules

Developers can suppress specific augmentor violations using `@LivDoc:Ignore` annotations. This preserves user decisions where a violation is intentional.

### 10.1 Syntax

```python
class HelperUtility:
    """
    Internal helper — no feature annotation needed.

    @LivDoc:Ignore(Feature, reason=Internal utility not mapped to a feature)
    """
    ...
```

### 10.2 Ignore Variants

| Syntax | Scope |
|---|---|
| `@LivDoc:Ignore(TypeName)` | Suppress violations for `TypeName` on this target |
| `@LivDoc:Ignore(TypeName, reason=...)` | Same, with a documented reason (recommended) |
| `@LivDoc:Ignore(*)` | Suppress all augmentor violations on this target |

### 10.3 Behavior

- Ignored violations are **not** counted in the exit code.
- Ignored violations **are** reported in the summary with status `ignored`.
- The collector **still extracts** `@LivDoc:Ignore` annotations (they appear in `code_augmentations.json` with `type: "Ignore"`).
- An ignore without a `reason` produces a `warning`.

### 10.4 File-Level Ignore

To ignore all violations for an entire file, place at the top of the file:

```python
"""
@LivDoc:Ignore(*, reason=Auto-generated file — annotations managed externally)
"""
```

---

## 11. Action Inputs & Outputs

### Inputs

| Input | Required | Default | Description |
|---|---|---|---|
| `regime` | yes | — | Operating mode: `augmentor` or `collector` |
| `config-path` | no | `augmentation_types.yml` | Comma-separated list of augmentation types config files |
| `scan-mode` | no | `pr` | Augmentor scan mode: `pr`, `full`, or `per-type` |
| `augmentation-type` | no | — | When `scan-mode: per-type`, the specific type to check |
| `source-paths` | no | `.` | Comma-separated list of directories to scan |
| `exclude-paths` | no | — | Comma-separated list of glob patterns to exclude |
| `output-path` | no | `code_augmentations.json` | Output file path for the collector regime |
| `fail-on-violations` | no | `true` | Whether the augmentor should fail the workflow on violations |
| `verbose` | no | `false` | Enable verbose/debug logging |

### Outputs

| Output | Description |
|---|---|
| `violations-count` | Number of violations found (augmentor regime) |
| `annotations-count` | Total annotations found |
| `output-file` | Path to the generated `code_augmentations.json` (collector regime) |
| `types-summary` | JSON string summarizing counts per augmentation type |

---

## 12. Collector Output Schema

The collector produces `code_augmentations.json` with the following structure:

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

---

## 13. GitHub Action Definition (action.yml)

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
    description: 'Comma-separated list of augmentation types config files'
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

---

## 14. Example Workflows

### 14.1 Example Implementation in AbsaOSS/generate-release-notes

The following examples show how living-doc-augmentor-gh would be integrated into the AbsaOSS/generate-release-notes repository.

#### 14.1.1 PR Augmentor Check

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

#### 14.1.2 Full Repository Scan (On-Demand)

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

#### 14.1.3 Collector (Extract Annotations for Release)

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

---

## 15. Quality Gates

Modeled after AbsaOSS/generate-release-notes, the repository enforces the following quality gates.

> **On-Demand CI:** All CI workflows use `workflow_dispatch` (or `pull_request` where
> essential) to protect paid GitHub Actions minutes. Developers run the full
> quality-gate suite **locally** before pushing (see §15.4).

### 15.1 CI Workflows

| Workflow | Trigger | Description |
|---|---|---|
| Unit Tests | `workflow_dispatch`, `pull_request` | Run pytest with coverage ≥ **95 %** |
| Integration Tests | `workflow_dispatch` | End-to-end tests with sample repositories |
| Linting (pylint) | `workflow_dispatch`, `pull_request` | Pylint score ≥ 9.0/10 |
| Linting (ruff) | `workflow_dispatch`, `pull_request` | Zero ruff violations |
| Type Checking (mypy) | `workflow_dispatch`, `pull_request` | Strict mode, zero errors |
| Code Formatting (black) | `workflow_dispatch`, `pull_request` | Zero formatting violations |
| Complexity (radon) | `workflow_dispatch`, `pull_request` | Cyclomatic complexity ≤ **B** (no function rated C or worse) |
| Dependency Audit | `workflow_dispatch`, `schedule` | `pip audit` — check for known vulnerabilities |
| PR Title Convention | `pull_request` | Enforce conventional commit format |
| YAML Validation | `pull_request` | Validate `action.yml` and example configs |

### 15.2 Branch Protection Rules

- Require PR reviews (≥ 1 approval).
- Require all status checks to pass before merging.
- Require linear history (no merge commits).
- Require signed commits (recommended).

### 15.3 Configuration Files

| File | Purpose |
|---|---|
| `.pylintrc` | Pylint configuration (see generate-release-notes/.pylintrc) |
| `pyproject.toml` | Project metadata, black/mypy/ruff/radon configuration |
| `requirements.txt` | Runtime dependencies |
| `requirements-dev.txt` | Development/testing dependencies (incl. `radon`, `pip-audit`) |
| `.github/dependabot.yml` | Automated dependency updates via Dependabot |

### 15.4 Local Quality-Gate Script

A `Makefile` (with a thin wrapper `scripts/run_qa.sh` for CI parity) runs **every**
gate locally so developers never need to push just to see CI results:

```makefile
.PHONY: qa lint typecheck fmt complexity test audit

qa: lint typecheck fmt complexity test audit  ## Run ALL quality gates

lint:
	pylint living_doc_augmentor
	ruff check .

typecheck:
	mypy living_doc_augmentor

fmt:
	black --check .

complexity:
	radon cc living_doc_augmentor -a -nb   # fail on grade C+

test:
	pytest --cov=living_doc_augmentor --cov-fail-under=95 tests/

audit:
	pip-audit -r requirements.txt
```

```bash
# Quick one-liner
make qa
# …or via wrapper (same thing, used in CI)
./scripts/run_qa.sh
```

---

## 16. Repository Structure

> **Single-purpose files:** Every source module has exactly one responsibility.
> Test files mirror the source tree 1:1 so navigation is instant.

```code
living-doc-augmentor-gh/
├── .github/
│   ├── copilot-instructions.md           # AI assistant project context
│   ├── dependabot.yml                    # Automated dependency updates
│   ├── workflows/
│   │   ├── ci.yml                        # Unit tests, linting, type checking
│   │   ├── integration_tests.yml         # Integration tests
│   │   ├── check_pr_title.yml            # PR title convention
│   │   └── release_draft.yml             # Release draft automation
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
│   ├── ignore.py                         # @LivDoc:Ignore logic
│   ├── location.py                       # Location detection system & matchers
│   ├── languages.py                      # Language-specific comment/target definitions
│   └── utils.py                          # Shared utilities
├── tests/
│   ├── unit/
│   │   ├── test_augmentor.py             # ← mirrors augmentor.py
│   │   ├── test_collector.py             # ← mirrors collector.py
│   │   ├── test_scanner.py               # ← mirrors scanner.py
│   │   ├── test_config.py                # ← mirrors config.py
│   │   ├── test_models.py                # ← mirrors models.py
│   │   ├── test_ignore.py                # ← mirrors ignore.py
│   │   ├── test_location.py              # ← mirrors location.py
│   │   ├── test_languages.py             # ← mirrors languages.py
│   │   └── test_diff_parser.py           # ← mirrors diff_parser.py
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
│   ├── augmentation_types_full.yml       # Full catalogue example (all §8 types)
│   ├── workflow_pr_check.yml             # Example PR workflow
│   ├── workflow_full_scan.yml            # Example full-scan workflow
│   └── workflow_collector.yml            # Example collector workflow
├── scripts/
│   └── run_qa.sh                         # CI-equivalent local QA wrapper
├── docs/
│   └── SPEC.md                           # This file
├── action.yml                            # Composite action definition
├── main.py                               # Entry point
├── Makefile                              # Local quality-gate runner (see §15.4)
├── requirements.txt                      # Runtime dependencies
├── requirements-dev.txt                  # Dev/test dependencies
├── pyproject.toml                        # Project configuration
├── .pylintrc                             # Pylint configuration
├── .gitignore
├── LICENSE
├── CONTRIBUTING.md
├── DEVELOPER.md
├── README.md
└── SPEC.md                               # → docs/SPEC.md (symlink or copy)
```

---

## 17. AI Assistant Integration

> **Model-agnostic design.** While GitHub Copilot is the primary example below,
> every technique applies equally to **any** LLM-backed coding assistant
> (Claude, Gemini, Cursor, Cody, etc.). The project never depends on a specific
> model or vendor — only on well-structured code and configuration that any
> assistant can leverage.

AI-powered coding assistants are first-class citizens in this project. The
action, its configuration, and its codebase are designed to maximize the value
developers get from assistants — both when **using** the action in their
projects and when **contributing** to the action itself.

### 17.1 AI Assistant Instructions File

The repository ships a `.github/copilot-instructions.md` file (also usable by
Claude, Gemini, and other assistants that read project-context files):

```markdown
# AI Assistant Instructions — Living Doc Augmentor

## Project Context
This is a composite GitHub Action (Python 3.14) that validates and extracts
structured `@LivDoc:*` annotations from source code.

## Annotation Convention
- All annotations follow the pattern `@LivDoc:<Type>(<value>)`
- Annotations live inside comments/docstrings (Python `"""`, JSDoc `/** */`, `#`, `//`)
- Types are defined in `augmentation_types.yml`

## When generating code in this project:
- Always add appropriate `@LivDoc:*` annotations in docstrings
- Use the types defined in the project's `augmentation_types.yml`
- Place `@LivDoc:Feature(ID)` on classes, `@LivDoc:AC(ID)` on methods
- Place `@LivDoc:TestEvidence(REQ-ID)` on test functions

## When generating augmentation_types.yml:
- Follow the schema in SPEC.md §5
- Use descriptive `name` values
- Provide valid regex patterns with capture groups
- Set appropriate `target` and `file_patterns`
```

### 17.2 Plugin Architecture

The scanner supports pluggable detection strategies:

```python
class DetectionStrategy(Protocol):
    """Protocol for annotation detection strategies."""

    def detect(self, file_content: str, file_path: str, config: AugmentationConfig) -> list[Annotation]:
        """Detect annotations in file content."""
        ...
```

### 17.3 Built-in Detection Strategies

| Strategy | Description |
|---|---|
| `RegexDetectionStrategy` | Pattern-based detection using regex from `augmentation_types.yml` |
| `DocstringDetectionStrategy` | Python docstring-aware detection (understands docstring boundaries) |
| `CommentBlockDetectionStrategy` | Generic comment block detection (`/** */`, `# ...`, `<!-- -->`) |

### 17.4 Agent Mode Support

The project is structured to work optimally with AI assistants in **agent mode** (multi-step autonomous tasks):

- **Clear file responsibilities:** Each module has a single, well-documented purpose (see §3 Architecture).
- **Protocol-based interfaces:** All extension points use Python `Protocol` classes, making it easy for assistants to generate conforming implementations.
- **Comprehensive type hints:** Python 3.14 type hints on every function, method, and variable.
- **Detailed docstrings:** Every public API includes docstrings describing intent, parameters, return values, and side effects.
- **Test-first patterns:** Test files mirror source files 1:1, enabling assistants to generate tests alongside implementation.

### 17.5 Chat Participant — `@livingdoc` (Future)

A custom `@livingdoc` chat participant can be registered in VS Code (or equivalent IDE plugin) to provide in-editor assistance:

| Command | Description |
|---|---|
| `@livingdoc /annotate` | Suggest `@LivDoc:*` annotations for the current file based on `augmentation_types.yml` |
| `@livingdoc /check` | Run a quick augmentor check on the current file and report violations inline |
| `@livingdoc /generate-config` | Analyze the project and generate an `augmentation_types.yml` tailored to its conventions |
| `@livingdoc /explain` | Explain the purpose and rules of a specific augmentation type |
| `@livingdoc /catalogue` | Show available augmentation types from the catalogue (§8) with usage examples |
| `@livingdoc /coverage` | Report annotation coverage statistics for the workspace |
| `@livingdoc /auto-fix` | Automatically add missing `@LivDoc:*` annotations to the current file (AI-assisted) |

### 17.6 AI Extension Points

- **Custom detection strategies:** Assistants can generate new `DetectionStrategy` implementations for project-specific patterns.
- **Augmentation type templates:** Assistants can generate `augmentation_types.yml` entries based on project conventions.
- **Rule generation:** Assistants can analyze existing code and suggest appropriate annotation rules.
- **False positive tuning:** Detection thresholds and exclusion patterns can be refined with AI assistance.
- **Annotation authoring:** In-editor assistant suggestions can auto-complete `@LivDoc:*` tags based on context.
- **Review assistance:** Assistants can review PRs for missing annotations and suggest additions.
- **Auto-fix (AI-scoped):** Given a violation list, an AI assistant can propose fix commits adding the missing annotations.

### 17.7 AI-Friendly Code Patterns

All core modules include:

- Comprehensive type hints (Python 3.14 style).
- Detailed docstrings explaining intent and contracts.
- Clear separation of concerns enabling targeted modifications.
- Well-defined interfaces (`Protocol` classes) for extensibility.
- Inline `# TODO(ai):` markers for areas where assistant help is expected.

---

## 18. Error Reporting & Diagnostics

### 18.1 Violation Report Format

The augmentor produces structured violation reports:

```
::error file=src/user_service.py,line=1,col=1::Missing required annotation @LivDoc:Feature on class UserService (rule: Feature, target: class, file_patterns: src/**/*.py)
::warning file=src/utils.py,line=15,col=1::Unrecognized annotation @LivDoc:Unknown in comment block
```

### 18.2 Severity Levels

| Level | GitHub Annotation | CI Behavior |
|---|---|---|
| `error` | `::error` | Fails the workflow (when `fail-on-violations: true`) |
| `warning` | `::warning` | Reported but does not fail the workflow |
| `info` | `::notice` | Informational — logged but no annotation |

### 18.3 Diagnostic Output

When `verbose: true`, the action produces detailed diagnostic output:

- Files scanned and skipped (with reasons).
- Augmentation types evaluated per file.
- Pattern match attempts and results.
- Location detection decisions (which layer matched/rejected).
- Timing information per phase.

### 18.4 Summary Report

After every run, the action writes a summary to `$GITHUB_STEP_SUMMARY`:

```markdown
### Living Doc Augmentor — Results

| Metric | Value |
|---|---|
| Files scanned | 42 |
| Files with annotations | 8 |
| Total annotations | 15 |
| Violations | 3 |

#### Violations
| File | Line | Type | Message |
|---|---|---|---|
| `src/user_service.py` | 1 | `Feature` | Missing required `@LivDoc:Feature` on class `UserService` |
| `src/order_service.py` | 1 | `Feature` | Missing required `@LivDoc:Feature` on class `OrderService` |
| `tests/test_orders.py` | 12 | `TestEvidence` | Missing required `@LivDoc:TestEvidence` on function `test_place_order` |
```

---

## 19. Versioning & Compatibility

### 19.1 Configuration Schema Versioning

The `augmentation_types.yml` file includes a `version` field:

```yaml
version: "1.0"
```

The action validates that the configuration version is compatible with the running action version. Incompatible versions produce exit code `2` with a clear error message.

### 19.2 Semantic Versioning

The action follows [Semantic Versioning 2.0.0](https://semver.org/):

- **MAJOR:** Breaking changes to configuration schema, output schema, or CLI behavior.
- **MINOR:** New augmentation type properties, new detection strategies, new inputs/outputs.
- **PATCH:** Bug fixes, performance improvements, documentation updates.

### 19.3 Output Schema Versioning

The `code_augmentations.json` output includes a `tool_version` field in metadata. Consumers should use this to handle schema evolution.

### 19.4 Backward Compatibility Policy

- Configuration files from version `N` will work with action version `N+1` (one major version forward compatibility).
- Output schema changes within a major version are always additive (new fields only, never removed).
- Deprecated configuration properties emit warnings for at least one minor release before removal.

---

## 20. Security Considerations

### 20.1 Input Validation

- All regex patterns from `augmentation_types.yml` are compiled with timeout protection to prevent ReDoS attacks.
- File glob patterns are validated and sandboxed to the repository root — no path traversal is possible.
- Action inputs are sanitized before use in shell commands.

### 20.2 No Code Execution

The action **reads** source code but never **executes** it. Annotations are extracted from comments and docstrings only — no imports, no `eval`, no dynamic code loading.

### 20.3 Output Sanitization

The `code_augmentations.json` output sanitizes all extracted values to prevent injection when consumed by downstream tools.

### 20.4 Dependency Security

- Dependencies are pinned to exact versions in `requirements.txt`.
- Automated dependency updates via **Dependabot** with vulnerability alerts.
- `pip audit` is included in the CI pipeline.

### 20.5 Permissions

The GitHub Action requires only `contents: read` permission. It does not need write access to the repository.

---

## 21. Performance & Scalability

### 21.1 Design Targets

| Metric | Target |
|---|---|
| Scan speed (full repo) | ≥ 1,000 files/second for regex detection |
| PR mode overhead | < 5 seconds for typical PRs (< 50 changed files) |
| Memory usage | < 256 MB for repositories with up to 10,000 files |
| Collector output generation | < 10 seconds for 10,000 annotations |

### 21.2 Optimization Strategies

- **Lazy file reading:** Files are read only when their path matches at least one `file_patterns` glob.
- **Early termination:** In PR mode, only changed files are loaded.
- **Compiled patterns:** All regex patterns are pre-compiled once at startup.
- **Streaming scan:** Files are scanned line-by-line to avoid loading entire files into memory for large files.
- **Parallel file processing:** Multi-threaded file scanning for full-repo mode (configurable concurrency).

### 21.3 Caching (Future)

A future version will support caching scan results keyed by file content hash, enabling incremental scans that skip unchanged files.

---

## 22. Tutorial — Full Augmentation Examples

This section provides a **complete, copy-pasteable** reference for every
augmentation category defined in §8. Each example shows the annotation in
context — including multiline variants — so teams can use this chapter as a
self-service onboarding guide.

### 22.1 Traceability (Feature, AC, User Story)

```python
class OrderService:
    """Service handling order lifecycle.

    @LivDoc:Feature(ORD-001)
    @LivDoc:AC(ORD-001-AC-01)
    @LivDoc:UserStory(US-042)
    """

    def place_order(self, cart: Cart) -> Order:
        """Place an order from a shopping cart.

        @LivDoc:AC(ORD-001-AC-02)

        Multi-value: a single method may satisfy several acceptance criteria.
        The documentation fragment lives close to the code that fulfils it.
        """
        ...
```

### 22.2 Testing (TestEvidence, BDD Keyword Catalogue)

```python
# @LivDoc:TestEvidence(ORD-001-AC-01)
def test_place_order_creates_record(order_service, sample_cart):
    """Verify that placing an order persists a record."""
    ...
```

**BDD keyword catalogue per PageObject:**

```gherkin
# features/order.feature
# @LivDoc:BDDKeywords(OrderPage: place_order, verify_total, apply_discount)
Feature: Order management
  Scenario: Place a new order
    Given the user is on the OrderPage
    When  the user calls place_order
    Then  the order total matches verify_total
```

### 22.3 Architecture (Layer, Component, ArchDecision)

```java
/**
 * @LivDoc:Layer(Application)
 * @LivDoc:Component(OrderProcessing)
 * @LivDoc:ArchDecision(ADR-007 — Use event sourcing for order state)
 */
public class OrderCommandHandler {
    // ...
}
```

### 22.4 API Documentation (Endpoint, Contract, DataModel)

```python
class UserRouter:
    """
    @LivDoc:Endpoint(GET /api/v1/users/{id})
    @LivDoc:Contract(UserResponseV1)
    @LivDoc:DataModel(UserDTO)
    """
    ...
```

### 22.5 Operations (Runbook, Alert, SLA)

```yaml
# monitoring/alerts.yml
# @LivDoc:Alert(OrderLatencyP99 > 500ms)
# @LivDoc:Runbook(https://wiki.example.com/runbooks/order-latency)
# @LivDoc:SLA(99.9% availability for /api/v1/orders)
groups:
  - name: order_alerts
    rules:
      - alert: OrderLatencyHigh
        expr: histogram_quantile(0.99, rate(order_duration_seconds_bucket[5m])) > 0.5
```

### 22.6 Compliance (Regulation, DataClassification, AuditControl)

```python
class PaymentProcessor:
    """Process credit-card payments.

    @LivDoc:Regulation(PCI-DSS v4.0 §6.2)
    @LivDoc:DataClassification(PII — credit card number)
    @LivDoc:AuditControl(AC-PAY-003 — encrypt card data at rest)
    """
    ...
```

### 22.7 Dependencies (ExternalSystem, Library, Migration)

```python
# @LivDoc:ExternalSystem(Stripe API v2023-10-16)
# @LivDoc:Library(stripe-python 7.1.0)
import stripe

# @LivDoc:Migration(V3__add_payment_method_column)
def upgrade():
    op.add_column("users", sa.Column("payment_method", sa.String()))
```

### 22.8 Process (Workflow, SLA, Stakeholder)

```typescript
/**
 * @LivDoc:Workflow(OnboardNewClient)
 * @LivDoc:SLA(Client onboarding < 48h)
 * @LivDoc:Stakeholder(Legal, Compliance, Sales)
 */
export class ClientOnboardingOrchestrator { /* ... */ }
```

### 22.9 Decisions

```python
class EventBus:
    """Central event bus.

    @LivDoc:TechDecision(TECH-012 — RabbitMQ chosen over Kafka for simplicity)
    @LivDoc:LibDecision(LIB-005 — pika 1.3 for AMQP connectivity)
    """
    ...
```

```scala
/** @LivDoc:BusinessDecision(BIZ-009 — Free tier limited to 1 000 events/month) */
object PricingPolicy
```

### 22.10 Glossary

```python
class Tenant:
    """A Tenant is an isolated organizational unit within the platform.

    @LivDoc:Glossary(Tenant — An isolated organizational unit that owns
      its own data partition, user base, and configuration. Tenants
      are the top-level boundary for multi-tenancy.)
    """
    ...
```

### 22.11 Domain Objects

```java
/**
 * @LivDoc:DomainObject(Order — Aggregate root representing a customer purchase.
 *   Invariant: total = Σ line-item prices + tax − discount.
 *   Lifecycle: Draft → Placed → Fulfilled → Closed.)
 */
public class Order { /* ... */ }
```

### 22.12 Project Descriptions

```markdown
<!-- @LivDoc:ProjectDescription(living-doc-augmentor-gh — A composite GitHub
  Action that validates and extracts structured @LivDoc annotations from source
  code, producing JSON output for living-documentation pipelines.) -->
# Living Doc Augmentor
```

### 22.13 Cross-Language Parity

The **same** logical annotation in different languages:

| Language | Example |
|---|---|
| Python | `# @LivDoc:Feature(ORD-001)` or inside `"""..."""` |
| Java | `// @LivDoc:Feature(ORD-001)` or inside `/** ... */` |
| Scala | `// @LivDoc:Feature(ORD-001)` or inside `/** ... */` |
| TypeScript | `// @LivDoc:Feature(ORD-001)` or inside `/** ... */` |
| Terraform | `# @LivDoc:Feature(ORD-001)` |
| HTML | `<!-- @LivDoc:Feature(ORD-001) -->` |
| XML | `<!-- @LivDoc:Feature(ORD-001) -->` |
| Markdown | `<!-- @LivDoc:Feature(ORD-001) -->` |
| YAML | `# @LivDoc:Feature(ORD-001)` |
| SQL | `-- @LivDoc:Feature(ORD-001)` |
| Shell | `# @LivDoc:Feature(ORD-001)` |
| Glue (PySpark) | `# @LivDoc:Feature(ORD-001)` (inside Python script) |

---

## 23. Roadmap

> **Granular iterations.** Each phase is scoped to ≤ 2 weeks of work for a
> single contributor. Every milestone ships with **≥ 95 % test coverage** and
> a passing `make qa` run.

### Phase 1 — Scaffold & Core (v0.1.0)

- [ ] Repository scaffolding: `Makefile`, `scripts/run_qa.sh`, CI workflows (`workflow_dispatch`)
- [ ] `.github/dependabot.yml` for dependency updates
- [ ] AI assistant instructions file (`.github/copilot-instructions.md`)
- [ ] Configuration schema (`augmentation_types.yml`) — single file, Pydantic validator
- [ ] Core scanner with regex-based detection (single-line)
- [ ] Augmentor regime — full scan mode, exit codes 0/1/2
- [ ] Collector regime — JSON output (`code_augmentations.json`)
- [ ] `action.yml` composite action definition
- [ ] Unit tests ≥ 95 % coverage; `make qa` green

### Phase 2 — PR Integration (v0.2.0)

- [ ] PR diff parsing for PR mode (changed-files-only)
- [ ] GitHub Actions annotations for violations (`::error`, `::warning`)
- [ ] `$GITHUB_STEP_SUMMARY` report
- [ ] Integration tests with sample repository fixture
- [ ] Example workflows (PR check, full scan, collector)

### Phase 3 — Multi-Language & Location Detection (v0.3.0)

- [ ] Generic location detection system (§6) — three composable layers
- [ ] Language-configurable target patterns: Python, TypeScript, Java, Scala
- [ ] Additional languages: Terraform, HTML, XML, Markdown, YAML, Shell, SQL, Glue
- [ ] Custom target definitions in `augmentation_types.yml`
- [ ] Per-type scan mode (`scan-mode: per-type`)

### Phase 4 — Advanced Features (v0.4.0)

- [ ] Multiline annotation detection
- [ ] `@LivDoc:Ignore` rules (§10)
- [ ] Multiple `augmentation_types.yml` files with separate namespaces
- [ ] Inside/outside placement rules per type
- [ ] Cross-language parity validation
- [ ] Augmentation type catalogue examples shipped in `examples/`

### Phase 5 — AI Assistant Integration (v0.5.0)

- [ ] Agent-mode optimization (Protocol interfaces, docstring contracts)
- [ ] `@livingdoc` chat participant prototype (VS Code)
- [ ] `/annotate`, `/check`, `/generate-config`, `/auto-fix` commands
- [ ] AI-assisted `augmentation_types.yml` generation

### Phase 6 — New Augmentation Categories (v0.6.0)

- [ ] Decisions (TechDecision, LibDecision, BusinessDecision)
- [ ] Glossary annotations
- [ ] Domain Object annotations
- [ ] Project Description annotations
- [ ] BDD keyword catalogue per PageObject
- [ ] Target Document & Audience metadata per category

### Phase 7 — Maturity & Marketplace (v1.0.0)

- [ ] AST-based detection for Python (optional enhancement)
- [ ] Caching for faster incremental scans
- [ ] Configurable severity levels per violation
- [ ] Security hardening (ReDoS protection, input sanitization)
- [ ] Output schema versioning & backward compatibility guarantees
- [ ] Performance benchmarks (1,000+ files/second)
- [ ] Published to GitHub Marketplace

### Verification Scripts

Each phase ships with:

```bash
# 1. Full local QA
make qa

# 2. Smoke-test the action locally (act or nektos/act)
act -j augmentor-check --secret-file .env

# 3. Coverage report
pytest --cov=living_doc_augmentor --cov-report=html tests/
open htmlcov/index.html
```

---

## Appendix A — Glossary

| Term | Definition |
|---|---|
| Annotation | A structured comment/tag in source code following the `@LivDoc:<Type>(value)` convention |
| Augmentation | The process of enriching source code with structured annotations for living documentation |
| Augmentation Catalogue | A collection of pre-defined augmentation type definitions for common IT project documentation needs |
| Augmentation Type | A defined category of annotation (e.g., Feature, AC, TestEvidence) with rules for placement and extraction |
| Augmentor | The regime that validates annotations conform to defined rules |
| Auto-Prefix | When a config file sets `prefix`, the tag `@LivDoc:<Prefix><Name>` is derived automatically — no need to repeat the prefix in each type's `name` |
| Chat Participant | A VS Code extension that registers a custom `@` mention in an AI assistant chat for domain-specific assistance |
| Collector | The regime that extracts all annotations into structured JSON |
| Cross-Language Parity | The principle that the same logical annotation has equivalent syntax in every supported language |
| Custom Target | A user-defined code-structure target (regex pattern) extending the built-in target vocabulary |
| Decision (annotation) | A `@LivDoc:*Decision` annotation capturing a technology, library, or business decision close to the code it affects |
| Detection Strategy | A pluggable algorithm for finding annotations in source code |
| Domain Object | A `@LivDoc:DomainObject` annotation documenting an entity, aggregate, or value object from the domain model |
| Glossary (annotation) | A `@LivDoc:Glossary` annotation defining a term in the project's ubiquitous language |
| Ignore Rule | A `@LivDoc:Ignore` or `@LivDoc:Ignore(<Type>)` annotation that suppresses augmentor violations for a file, class, or function |
| AI Assistant Instructions | A `.github/copilot-instructions.md` file that provides project-specific context to AI coding assistants |
| Living Documentation | Documentation that is automatically generated or validated from source code artifacts, always reflecting the current state of the system |
| Location Detection | The multi-layer system that determines where in a codebase to look for annotations (file globs → code targets → comment styles) |
| Location Matcher | A composable rule that validates whether a specific code location is a valid placement for an annotation |
| Multi-Config | Support for multiple `augmentation_types.yml` files, each with its own namespace/prefix |
| Multi-Value | The practice of placing multiple annotations of the same type on a single code element, keeping each documentation fragment close to the code that justifies it |
| Project Description | A `@LivDoc:ProjectDescription` annotation documenting a repository's purpose, scope, and boundaries |
| Scoping Layer | One of the three composable layers in the location detection system: file selection, code structure targets, comment style awareness |
| Target Document | The downstream document (wiki page, handbook, report) that a particular annotation category feeds into |

