#!/usr/bin/env python3
"""Audit an EasyMCP public artifact repo for expected files and source leakage."""

import argparse
from pathlib import Path


REQUIRED = [
    "README.md",
    "ENTERPRISE.md",
    "SECURITY.md",
    "install.sh",
    "cli/install.sh",
    "scripts/install-git-hooks.sh",
    ".github/workflows/security.yml",
    ".githooks/pre-commit",
    ".githooks/pre-push",
    "DOCKER_TAGS.md",
    "docker-tags.json",
    "DOCKERHUB_README.md",
    "docs/cli.md",
    "docs/docker-runtime.md",
    "examples/README.md",
    "releases/README.md",
]

FORBIDDEN_SUFFIXES = {".go", ".pyc"}
FORBIDDEN_NAMES = {"go.mod", "go.sum", "Dockerfile"}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("repo", nargs="?", default=".")
    args = parser.parse_args()
    root = Path(args.repo).resolve()

    missing = [path for path in REQUIRED if not (root / path).exists()]
    forbidden = []
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        if "releases/downloads" in path.as_posix():
            continue
        if path.suffix in FORBIDDEN_SUFFIXES or path.name in FORBIDDEN_NAMES:
            forbidden.append(path.relative_to(root).as_posix())

    if missing or forbidden:
        if missing:
            print("missing required files:")
            for item in missing:
                print(f"  - {item}")
        if forbidden:
            print("forbidden implementation files:")
            for item in forbidden:
                print(f"  - {item}")
        raise SystemExit(1)

    print(f"public repo audit ok: {root}")


if __name__ == "__main__":
    main()
