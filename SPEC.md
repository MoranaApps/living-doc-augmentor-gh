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
10. [Action Inputs & Outputs](#10-action-inputs--outputs)
11. [Collector Output Schema](#11-collector-output-schema)
12. [GitHub Action Definition (action.yml)](#12-github-action-definition-actionyml)
13. [Example Workflows](#13-example-workflows)
14. [Quality Gates](#14-quality-gates)
15. [Repository Structure](#15-repository-structure)
16. [Copilot Integration](#16-copilot-integration)
17. [Error Reporting & Diagnostics](#17-error-reporting--diagnostics)
18. [Versioning & Compatibility](#18-versioning--compatibility)
19. [Security Considerations](#19-security-considerations)
20. [Performance & Scalability](#20-performance--scalability)
21. [Roadmap](#21-roadmap)

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
- **G10:** Provide **first-class GitHub Copilot integration** — including Copilot instructions, agent-mode support, custom chat participants, and AI-assisted annotation authoring.
- **G11:** Ship a rich **augmentation type catalogue** with ready-to-use examples for common IT project documentation needs (features, requirements, test evidence, API contracts, ADRs, SLAs, ownership, deprecation notices, and more).

### Non-Goals

- UI rendering of living documentation (handled by upstream consumers).
- Modifying source code automatically (the augmentor validates; it does not auto-fix).
- Language-specific AST parsing in v1 (regex/pattern-based detection first; AST is a future enhancement).
- Replacing dedicated documentation tools (Sphinx, MkDocs, etc.) — this action augments source code, it does not generate final documentation artifacts.

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
| `severity` | `enum` | Violation severity when this type is missing: `error`, `warning`, `info` (default: `error`) |
| `multi_value` | `boolean` | Whether the annotation accepts comma-separated values (default: `false`) |
| `deprecated` | `boolean` | Mark a type as deprecated — still collected but violations are warnings (default: `false`) |

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
    multi_value: true
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
```

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

The `target` property scopes annotations to specific code constructs:

| Target | Description | Detection Method |
|---|---|---|
| `class` | Class / interface definitions | Regex: `^(class\|interface\|struct)\s+\w+` (language-configurable) |
| `function` | Top-level functions | Regex: `^(def\|function\|func\|fn)\s+\w+` |
| `method` | Methods inside a class | Indented function definitions within class scope |
| `module` | File/module-level (top of file) | First comment block in the file |
| `any` | Any comment block, anywhere | No structural constraint |
| `constructor` | Constructor / initializer | Language-specific patterns (`__init__`, `constructor`, etc.) |
| `decorator` | Decorated functions/classes | Presence of decorator syntax above the target |
| `endpoint` | REST/GraphQL endpoint handlers | Route decorator or annotation patterns |

Target patterns are configured per language in a `languages` section:

```yaml
languages:
  python:
    comment_styles:
      - docstring: '"""'           # Triple-quote docstrings
      - hash: "#"                  # Hash-line comments
    targets:
      class: '^\s*class\s+(\w+)'
      function: '^\s*def\s+(\w+)'
      method: '^\s{4,}def\s+(\w+)'
      module: '__file_header__'
      constructor: '^\s+def\s+__init__\s*\('
      decorator: '^\s*@\w+'
      endpoint: '^\s*@(app|router)\.(get|post|put|delete|patch)'

  typescript:
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

  java:
    comment_styles:
      - javadoc: '/** */'
      - line: '//'
    targets:
      class: '^\s*(public|protected|private)?\s*(abstract\s+)?class\s+(\w+)'
      function: '^\s*(public|protected|private)?\s*(static\s+)?\w+\s+(\w+)\s*\('
      module: '__file_header__'
      constructor: '^\s*(public|protected|private)?\s+(\w+)\s*\(.*\)\s*\{'
      endpoint: '^\s*@(Get|Post|Put|Delete|Patch)Mapping'
```

#### Layer 3 — Comment Style Awareness

The scanner understands different comment styles per language:

| Style | Languages | Example |
|---|---|---|
| Docstring (`"""`) | Python | `"""@LivDoc:Feature(F-1)"""` |
| JSDoc / Javadoc (`/** */`) | TypeScript, JavaScript, Java, C# | `/** @LivDoc:Feature(F-1) */` |
| Hash (`#`) | Python, Ruby, YAML, Shell | `# @LivDoc:Feature(F-1)` |
| Line (`//`) | TypeScript, JavaScript, Java, Go, Rust, C# | `// @LivDoc:Feature(F-1)` |
| Block (`/* */`) | C, C++, Go, CSS | `/* @LivDoc:Feature(F-1) */` |
| XML (`<!-- -->`) | HTML, XML, SVG | `<!-- @LivDoc:Feature(F-1) -->` |

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

- Annotations MUST appear inside comment blocks (docstrings, `/** */`, `# comments`).
- Multiple annotations per comment block are allowed.
- Annotations with multiple values use comma separation: `@LivDoc:AC(AC-001, AC-002)`.
- Annotations are case-sensitive.
- Unrecognized annotations (not in `augmentation_types.yml`) are reported as warnings.
- Annotations can optionally carry key-value metadata: `@LivDoc:SLA(latency-p99, 200ms)`.

---

## 8. Augmentation Type Catalogue — IT Project Examples

This section provides a comprehensive catalogue of augmentation types commonly needed in IT projects. These serve as ready-to-use examples and can be mixed and matched in any `augmentation_types.yml`.

### 8.1 Requirements & Traceability

| Type | Tag | Target | Purpose |
|---|---|---|---|
| **Feature** | `@LivDoc:Feature(ID)` | `class` | Links code to a feature in the feature registry / backlog |
| **UserStory** | `@LivDoc:UserStory(ID)` | `class`, `method` | Traces code to a user story (e.g., Jira, Azure DevOps) |
| **Requirement** | `@LivDoc:Requirement(ID)` | `any` | Links to a formal requirement (e.g., DOORS, ReqIF) |
| **AC** | `@LivDoc:AC(ID, ...)` | `method` | Maps to acceptance criteria — supports multiple values |
| **Epic** | `@LivDoc:Epic(ID)` | `module`, `class` | Groups code under a high-level epic |

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

| Type | Tag | Target | Purpose |
|---|---|---|---|
| **TestEvidence** | `@LivDoc:TestEvidence(REQ-ID)` | `function` | Links a test to the requirement it verifies |
| **TestCategory** | `@LivDoc:TestCategory(category)` | `class`, `function` | Classifies tests: `unit`, `integration`, `e2e`, `performance`, `security` |
| **PageObject** | `@LivDoc:PageObject(name)` | `class` | Marks a class as a UI page object |
| **TestData** | `@LivDoc:TestData(fixture)` | `function` | Documents the test data/fixture a test relies on |
| **CoverageExclusion** | `@LivDoc:CoverageExclusion(reason)` | `function`, `class` | Documents why a piece of code is excluded from coverage |

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

### 8.3 Architecture & Design Decisions

| Type | Tag | Target | Purpose |
|---|---|---|---|
| **ADR** | `@LivDoc:ADR(ID)` | `class`, `module` | Links code to an Architecture Decision Record |
| **DesignPattern** | `@LivDoc:DesignPattern(name)` | `class` | Documents the design pattern implemented (e.g., `Repository`, `Strategy`, `Observer`) |
| **BoundedContext** | `@LivDoc:BoundedContext(name)` | `module`, `class` | DDD bounded context assignment |
| **Aggregate** | `@LivDoc:Aggregate(name)` | `class` | Marks an aggregate root in DDD |
| **DomainEvent** | `@LivDoc:DomainEvent(name)` | `class` | Marks a domain event class |

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

| Type | Tag | Target | Purpose |
|---|---|---|---|
| **APIContract** | `@LivDoc:APIContract(ID)` | `endpoint`, `function` | Links an endpoint to its API contract / OpenAPI operationId |
| **APIVersion** | `@LivDoc:APIVersion(version)` | `class`, `module` | Documents the API version a component belongs to |
| **EventSchema** | `@LivDoc:EventSchema(ID)` | `class` | Links a class to an async event schema (Kafka, RabbitMQ) |
| **GraphQLType** | `@LivDoc:GraphQLType(name)` | `class` | Maps a class to a GraphQL type definition |

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

| Type | Tag | Target | Purpose |
|---|---|---|---|
| **Owner** | `@LivDoc:Owner(team)` | `module`, `class` | Assigns code ownership to a team |
| **SLA** | `@LivDoc:SLA(metric, target)` | `function`, `endpoint` | Documents SLA expectations (latency, uptime, etc.) |
| **Runbook** | `@LivDoc:Runbook(URL)` | `class`, `module` | Links to the operational runbook |
| **AlertRule** | `@LivDoc:AlertRule(ID)` | `function` | Links to a monitoring alert rule |
| **Tier** | `@LivDoc:Tier(level)` | `module`, `class` | Service criticality tier (`tier-1`, `tier-2`, `tier-3`) |

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

| Type | Tag | Target | Purpose |
|---|---|---|---|
| **Deprecated** | `@LivDoc:Deprecated(reason, replacement)` | `any` | Marks code as deprecated with migration guidance |
| **Since** | `@LivDoc:Since(version)` | `any` | Records the version when a component was introduced |
| **PlannedRemoval** | `@LivDoc:PlannedRemoval(version)` | `any` | Scheduled removal version |
| **MigrationGuide** | `@LivDoc:MigrationGuide(URL)` | `class`, `module` | Links to migration instructions |

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

| Type | Tag | Target | Purpose |
|---|---|---|---|
| **SecurityControl** | `@LivDoc:SecurityControl(ID)` | `class`, `function` | Maps to a security control (e.g., OWASP, SOC2) |
| **DataClassification** | `@LivDoc:DataClassification(level)` | `class`, `module` | Data sensitivity: `public`, `internal`, `confidential`, `restricted` |
| **ComplianceRule** | `@LivDoc:ComplianceRule(ID)` | `any` | Links to a compliance requirement (GDPR, HIPAA, PCI-DSS) |
| **ThreatModel** | `@LivDoc:ThreatModel(ID)` | `class`, `module` | Links to a threat model entry |

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

| Type | Tag | Target | Purpose |
|---|---|---|---|
| **GherkinScenario** | `@LivDoc:GherkinScenario(feature:scenario)` | `function` | Links test code to a Gherkin scenario |
| **GherkinFeature** | `@LivDoc:GherkinFeature(feature-file)` | `class`, `module` | Links implementation to a `.feature` file |
| **BDDStep** | `@LivDoc:BDDStep(step-pattern)` | `function` | Documents a step definition for BDD frameworks |
| **SpecFlowBinding** | `@LivDoc:SpecFlowBinding(step)` | `method` | Links a SpecFlow step binding |

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

### 8.9 Summary — Full Catalogue

| Category | Types |
|---|---|
| Requirements & Traceability | `Feature`, `UserStory`, `Requirement`, `AC`, `Epic` |
| Testing & Quality Evidence | `TestEvidence`, `TestCategory`, `PageObject`, `TestData`, `CoverageExclusion` |
| Architecture & Design | `ADR`, `DesignPattern`, `BoundedContext`, `Aggregate`, `DomainEvent` |
| API & Contracts | `APIContract`, `APIVersion`, `EventSchema`, `GraphQLType` |
| Ownership & Operations | `Owner`, `SLA`, `Runbook`, `AlertRule`, `Tier` |
| Lifecycle & Deprecation | `Deprecated`, `Since`, `PlannedRemoval`, `MigrationGuide` |
| Security & Compliance | `SecurityControl`, `DataClassification`, `ComplianceRule`, `ThreatModel` |
| Living Documentation | `GherkinScenario`, `GherkinFeature`, `BDDStep`, `SpecFlowBinding` |

---

## 9. Configuration

### 9.1 Configuration File

The action reads configuration from `augmentation_types.yml` (path configurable via input).

### 9.2 Configuration Validation

On startup, the action validates:

- YAML syntax is correct.
- All required fields are present for each type.
- Regex patterns compile successfully.
- File glob patterns are valid.
- No duplicate type names or tags.

Invalid configuration causes exit code `2`.

---

## 10. Action Inputs & Outputs

### Inputs

| Input | Required | Default | Description |
|---|---|---|---|
| `regime` | yes | — | Operating mode: `augmentor` or `collector` |
| `config-path` | no | `augmentation_types.yml` | Path to the augmentation types configuration file |
| `scan-mode` | no | `pr` | Augmentor scan mode: `pr`, `full`, or `per-type` |
| `augmentation-type` | no | — | When `scan-mode: per-type`, the specific type to check |
| `source-paths` | no | `.` | Comma-separated list of directories to scan |
| `exclude-paths` | no | — | Comma-separated list of glob patterns to exclude |
| `output-path` | no | `code_augmentations.json` | Output file path for the collector regime |
| `fail-on-violations` | no | `true` | Whether the augmentor should fail the workflow on violations |
| `verbose` | no | `false` | Enable verbose/debug logging |
| `python-version` | no | `3.14` | Python version to use |

### Outputs

| Output | Description |
|---|---|
| `violations-count` | Number of violations found (augmentor regime) |
| `annotations-count` | Total annotations found |
| `output-file` | Path to the generated `code_augmentations.json` (collector regime) |
| `types-summary` | JSON string summarizing counts per augmentation type |

---

## 11. Collector Output Schema

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

## 12. GitHub Action Definition (action.yml)

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

---

## 13. Example Workflows

### 13.1 Example Implementation in AbsaOSS/generate-release-notes

The following examples show how living-doc-augmentor-gh would be integrated into the AbsaOSS/generate-release-notes repository.

#### 13.1.1 PR Augmentor Check

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

#### 13.1.2 Full Repository Scan (On-Demand)

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

#### 13.1.3 Collector (Extract Annotations for Release)

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

## 14. Quality Gates

Modeled after AbsaOSS/generate-release-notes, the repository enforces the following quality gates:

### 14.1 CI Workflows

| Workflow | Trigger | Description |
|---|---|---|
| Unit Tests | PR, push to main | Run pytest with coverage ≥ 80% |
| Integration Tests | PR, push to main | End-to-end tests with sample repositories |
| Linting (pylint) | PR, push to main | Pylint score ≥ 9.0/10 |
| Linting (ruff) | PR, push to main | Zero ruff violations |
| Type Checking (mypy) | PR, push to main | Strict mode, zero errors |
| Code Formatting (black) | PR, push to main | Zero formatting violations |
| Dependency Audit | PR, scheduled | Check for known vulnerabilities |
| PR Title Convention | PR | Enforce conventional commit format |
| YAML Validation | PR | Validate action.yml and example configs |

### 14.2 Branch Protection Rules

- Require PR reviews (≥ 1 approval).
- Require all status checks to pass before merging.
- Require linear history (no merge commits).
- Require signed commits (recommended).

### 14.3 Configuration Files (modeled after generate-release-notes)

| File | Purpose |
|---|---|
| `.pylintrc` | Pylint configuration (see generate-release-notes/.pylintrc) |
| `pyproject.toml` | Project metadata, black/mypy/ruff configuration |
| `requirements.txt` | Runtime dependencies |
| `requirements-dev.txt` | Development/testing dependencies |
| `renovate.json` | Automated dependency updates (see generate-release-notes/renovate.json) |

---

## 15. Repository Structure

```code
living-doc-augmentor-gh/
├── .github/
│   ├── copilot-instructions.md           # Copilot project context
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
│   ├── location.py                       # Location detection system & matchers
│   ├── languages.py                      # Language-specific comment/target definitions
│   └── utils.py                          # Shared utilities
├── tests/
│   ├── unit/
│   │   ├── test_augmentor.py
│   │   ├── test_collector.py
│   │   ├── test_scanner.py
│   │   ├── test_config.py
│   │   ├── test_models.py
│   │   ├── test_location.py
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
│   ├── augmentation_types_full.yml       # Full catalogue example (all §8 types)
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

---

## 16. Copilot Integration

GitHub Copilot is a first-class citizen in this project. The action, its configuration, and its codebase are designed to maximize the value developers get from Copilot — both when **using** the action in their projects and when **contributing** to the action itself.

### 16.1 Copilot Instructions File

The repository ships a `.github/copilot-instructions.md` file that provides Copilot with project-specific context:

```markdown
# Copilot Instructions — Living Doc Augmentor

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

### 16.2 Plugin Architecture

The scanner supports pluggable detection strategies:

```python
class DetectionStrategy(Protocol):
    """Protocol for annotation detection strategies."""

    def detect(self, file_content: str, file_path: str, config: AugmentationConfig) -> list[Annotation]:
        """Detect annotations in file content."""
        ...
```

### 16.3 Built-in Detection Strategies

| Strategy | Description |
|---|---|
| `RegexDetectionStrategy` | Pattern-based detection using regex from `augmentation_types.yml` |
| `DocstringDetectionStrategy` | Python docstring-aware detection (understands docstring boundaries) |
| `CommentBlockDetectionStrategy` | Generic comment block detection (`/** */`, `# ...`, `<!-- -->`) |

### 16.4 Copilot Agent Mode Support

The project is structured to work optimally with Copilot in **agent mode** (multi-step autonomous tasks):

- **Clear file responsibilities:** Each module has a single, well-documented purpose (see §3 Architecture).
- **Protocol-based interfaces:** All extension points use Python `Protocol` classes, making it easy for Copilot to generate conforming implementations.
- **Comprehensive type hints:** Python 3.14 type hints on every function, method, and variable.
- **Detailed docstrings:** Every public API includes docstrings describing intent, parameters, return values, and side effects.
- **Test-first patterns:** Test files mirror source files 1:1, enabling Copilot to generate tests alongside implementation.

### 16.5 Copilot Chat Participant (Future)

A custom `@livingdoc` chat participant can be registered to provide in-editor assistance:

| Command | Description |
|---|---|
| `@livingdoc /annotate` | Suggest `@LivDoc:*` annotations for the current file based on `augmentation_types.yml` |
| `@livingdoc /check` | Run a quick augmentor check on the current file and report violations inline |
| `@livingdoc /generate-config` | Analyze the project and generate an `augmentation_types.yml` tailored to its conventions |
| `@livingdoc /explain` | Explain the purpose and rules of a specific augmentation type |
| `@livingdoc /catalogue` | Show available augmentation types from the catalogue (§8) with usage examples |
| `@livingdoc /coverage` | Report annotation coverage statistics for the workspace |

### 16.6 Copilot Extension Points

- **Custom detection strategies:** Copilot can generate new `DetectionStrategy` implementations for project-specific patterns.
- **Augmentation type templates:** Copilot can generate `augmentation_types.yml` entries based on project conventions.
- **Rule generation:** Copilot can analyze existing code and suggest appropriate annotation rules.
- **False positive tuning:** Detection thresholds and exclusion patterns can be refined with Copilot assistance.
- **Annotation authoring:** In-editor Copilot suggestions can auto-complete `@LivDoc:*` tags based on context.
- **Review assistance:** Copilot can review PRs for missing annotations and suggest additions.

### 16.7 Copilot-Friendly Code Patterns

All core modules include:

- Comprehensive type hints (Python 3.14 style).
- Detailed docstrings explaining intent and contracts.
- Clear separation of concerns enabling targeted modifications.
- Well-defined interfaces (`Protocol` classes) for extensibility.
- Inline `# TODO(copilot):` markers for areas where Copilot assistance is expected.

---

## 17. Error Reporting & Diagnostics

### 17.1 Violation Report Format

The augmentor produces structured violation reports:

```
::error file=src/user_service.py,line=1,col=1::Missing required annotation @LivDoc:Feature on class UserService (rule: Feature, target: class, file_patterns: src/**/*.py)
::warning file=src/utils.py,line=15,col=1::Unrecognized annotation @LivDoc:Unknown in comment block
```

### 17.2 Severity Levels

| Level | GitHub Annotation | CI Behavior |
|---|---|---|
| `error` | `::error` | Fails the workflow (when `fail-on-violations: true`) |
| `warning` | `::warning` | Reported but does not fail the workflow |
| `info` | `::notice` | Informational — logged but no annotation |

### 17.3 Diagnostic Output

When `verbose: true`, the action produces detailed diagnostic output:

- Files scanned and skipped (with reasons).
- Augmentation types evaluated per file.
- Pattern match attempts and results.
- Location detection decisions (which layer matched/rejected).
- Timing information per phase.

### 17.4 Summary Report

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

## 18. Versioning & Compatibility

### 18.1 Configuration Schema Versioning

The `augmentation_types.yml` file includes a `version` field:

```yaml
version: "1.0"
```

The action validates that the configuration version is compatible with the running action version. Incompatible versions produce exit code `2` with a clear error message.

### 18.2 Semantic Versioning

The action follows [Semantic Versioning 2.0.0](https://semver.org/):

- **MAJOR:** Breaking changes to configuration schema, output schema, or CLI behavior.
- **MINOR:** New augmentation type properties, new detection strategies, new inputs/outputs.
- **PATCH:** Bug fixes, performance improvements, documentation updates.

### 18.3 Output Schema Versioning

The `code_augmentations.json` output includes a `tool_version` field in metadata. Consumers should use this to handle schema evolution.

### 18.4 Backward Compatibility Policy

- Configuration files from version `N` will work with action version `N+1` (one major version forward compatibility).
- Output schema changes within a major version are always additive (new fields only, never removed).
- Deprecated configuration properties emit warnings for at least one minor release before removal.

---

## 19. Security Considerations

### 19.1 Input Validation

- All regex patterns from `augmentation_types.yml` are compiled with timeout protection to prevent ReDoS attacks.
- File glob patterns are validated and sandboxed to the repository root — no path traversal is possible.
- Action inputs are sanitized before use in shell commands.

### 19.2 No Code Execution

The action **reads** source code but never **executes** it. Annotations are extracted from comments and docstrings only — no imports, no `eval`, no dynamic code loading.

### 19.3 Output Sanitization

The `code_augmentations.json` output sanitizes all extracted values to prevent injection when consumed by downstream tools.

### 19.4 Dependency Security

- Dependencies are pinned to exact versions in `requirements.txt`.
- Automated dependency updates via Renovate with vulnerability alerts.
- `pip audit` is included in the CI pipeline.

### 19.5 Permissions

The GitHub Action requires only `contents: read` permission. It does not need write access to the repository.

---

## 20. Performance & Scalability

### 20.1 Design Targets

| Metric | Target |
|---|---|
| Scan speed (full repo) | ≥ 1,000 files/second for regex detection |
| PR mode overhead | < 5 seconds for typical PRs (< 50 changed files) |
| Memory usage | < 256 MB for repositories with up to 10,000 files |
| Collector output generation | < 10 seconds for 10,000 annotations |

### 20.2 Optimization Strategies

- **Lazy file reading:** Files are read only when their path matches at least one `file_patterns` glob.
- **Early termination:** In PR mode, only changed files are loaded.
- **Compiled patterns:** All regex patterns are pre-compiled once at startup.
- **Streaming scan:** Files are scanned line-by-line to avoid loading entire files into memory for large files.
- **Parallel file processing:** Multi-threaded file scanning for full-repo mode (configurable concurrency).

### 20.3 Caching (Future)

A future version will support caching scan results keyed by file content hash, enabling incremental scans that skip unchanged files.

---

## 21. Roadmap

### Phase 1 — Foundation (v0.1.0)

- [ ] Repository scaffolding with quality gates
- [ ] Configuration schema (`augmentation_types.yml`) and validator
- [ ] Core scanner with regex-based detection
- [ ] Augmentor regime — full scan mode
- [ ] Collector regime — JSON output
- [ ] Unit tests (≥ 80% coverage)
- [ ] `action.yml` composite action definition
- [ ] Copilot instructions file (`.github/copilot-instructions.md`)

### Phase 2 — PR Integration (v0.2.0)

- [ ] PR diff parsing for PR mode
- [ ] GitHub Actions annotations for violations
- [ ] Augmentor PR mode with changed-files-only scanning
- [ ] `$GITHUB_STEP_SUMMARY` report
- [ ] Integration tests with sample repositories
- [ ] Example workflows for AbsaOSS/generate-release-notes

### Phase 3 — Location Detection & Multi-Language (v0.3.0)

- [ ] Generic location detection system (§6) with composable layers
- [ ] Language-configurable target patterns (Python, TypeScript, Java)
- [ ] Custom location matchers
- [ ] Per-type scan mode
- [ ] Multiple detection strategies (docstring-aware, comment-block-aware)
- [ ] Augmentation type catalogue examples shipped in `examples/`

### Phase 4 — Copilot Integration (v0.4.0)

- [ ] Copilot agent-mode optimization (Protocol interfaces, docstring contracts)
- [ ] `@livingdoc` chat participant prototype
- [ ] `/annotate`, `/check`, `/generate-config` commands
- [ ] Copilot-assisted `augmentation_types.yml` generation

### Phase 5 — Maturity (v1.0.0)

- [ ] AST-based detection for Python (optional enhancement)
- [ ] Caching for faster incremental scans
- [ ] Configurable severity levels for violations
- [ ] Security hardening (ReDoS protection, input sanitization)
- [ ] Output schema versioning and backward compatibility guarantees
- [ ] Performance benchmarks (1,000+ files/second)
- [ ] Published to GitHub Marketplace

---

## Appendix A — Glossary

| Term | Definition |
|---|---|
| Augmentation | The process of enriching source code with structured annotations for living documentation |
| Augmentation Type | A defined category of annotation (e.g., Feature, AC, TestEvidence) with rules for placement and extraction |
| Annotation | A structured comment/tag in source code following the `@LivDoc:<Type>(value)` convention |
| Augmentor | The regime that validates annotations conform to defined rules |
| Collector | The regime that extracts all annotations into structured JSON |
| Detection Strategy | A pluggable algorithm for finding annotations in source code |
| Location Detection | The multi-layer system that determines where in a codebase to look for annotations (file globs → code targets → comment styles) |
| Location Matcher | A composable rule that validates whether a specific code location is a valid placement for an annotation |
| Living Documentation | Documentation that is automatically generated or validated from source code artifacts, always reflecting the current state of the system |
| Copilot Instructions | A `.github/copilot-instructions.md` file that provides project-specific context to GitHub Copilot |
| Chat Participant | A VS Code extension that registers a custom `@` mention in Copilot Chat for domain-specific assistance |
| Scoping Layer | One of the three composable layers in the location detection system: file selection, code structure targets, comment style awareness |
| Augmentation Catalogue | A collection of pre-defined augmentation type definitions for common IT project documentation needs |

