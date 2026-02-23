.PHONY: qa qa-parallel lint typecheck fmt complexity test audit

qa: lint typecheck fmt complexity test audit  ## Run ALL quality gates (sequential)

qa-parallel:  ## Run independent gates in parallel
	@echo "Running lint, typecheck, fmt, complexity in parallel..."
	$(MAKE) -j4 lint typecheck fmt complexity
	@echo "Running tests (sequential — needs clean state)..."
	$(MAKE) test
	$(MAKE) audit

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
