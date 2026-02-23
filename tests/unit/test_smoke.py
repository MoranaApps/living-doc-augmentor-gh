"""Smoke test — verifies package is importable."""

import living_doc_augmentor


def test_package_import() -> None:
    """Verify that the living_doc_augmentor package is importable."""
    assert living_doc_augmentor is not None
