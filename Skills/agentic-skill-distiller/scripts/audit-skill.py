#!/usr/bin/env python3
"""Audit an agent skill folder for common packaging and design issues."""

import argparse
import re
import sys
from pathlib import Path


FORBIDDEN_FILENAMES = {
    "README.md",
    "INSTALLATION_GUIDE.md",
    "QUICK_REFERENCE.md",
    "CHANGELOG.md",
}

FORBIDDEN_PATTERNS = [
    re.compile("TO" + r"DO|\[TO" + r"DO\]", re.IGNORECASE),
    re.compile("github" + r"_pat_|ghp_[A-Za-z0-9]{20,}"),
    re.compile(r"BEGIN [A-Z ]*PRIVATE KEY"),
    re.compile("__py" + r"cache__|\\.pyc$"),
]


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def parse_frontmatter(skill_md: str) -> dict[str, str]:
    if not skill_md.startswith("---\n"):
        raise ValueError("SKILL.md must start with YAML frontmatter")
    end = skill_md.find("\n---\n", 4)
    if end == -1:
        raise ValueError("SKILL.md frontmatter must end with ---")
    values: dict[str, str] = {}
    for line in skill_md[4:end].splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        values[key.strip()] = value.strip().strip('"')
    return values


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("skill_dir", type=Path)
    args = parser.parse_args()

    skill_dir = args.skill_dir
    errors: list[str] = []

    skill_md_path = skill_dir / "SKILL.md"
    if not skill_md_path.exists():
        errors.append("missing SKILL.md")
        skill_text = ""
    else:
        skill_text = read_text(skill_md_path)
        try:
            frontmatter = parse_frontmatter(skill_text)
        except ValueError as exc:
            errors.append(str(exc))
            frontmatter = {}
        if not frontmatter.get("name"):
            errors.append("frontmatter missing name")
        if len(frontmatter.get("description", "")) < 80:
            errors.append("frontmatter description is too short for reliable routing")

    if not (skill_dir / "agents" / "openai.yaml").exists():
        errors.append("missing agents/openai.yaml")

    for path in skill_dir.rglob("*"):
        if path.name in FORBIDDEN_FILENAMES:
            errors.append(f"forbidden auxiliary file: {path.relative_to(skill_dir)}")
        if path.is_file():
            relative = str(path.relative_to(skill_dir))
            text = read_text(path) if path.suffix in {".md", ".py", ".yaml", ".yml", ".json", ".txt"} else ""
            for pattern in FORBIDDEN_PATTERNS:
                if pattern.search(relative) or pattern.search(text):
                    errors.append(f"forbidden pattern in {relative}: {pattern.pattern}")

    references_dir = skill_dir / "references"
    if references_dir.exists() and skill_text:
        for reference in references_dir.glob("*.md"):
            reference_name = f"references/{reference.name}"
            if reference_name not in skill_text and reference.name not in skill_text:
                errors.append(f"reference not linked from SKILL.md: {reference_name}")

    scripts_dir = skill_dir / "scripts"
    if scripts_dir.exists():
        for script in scripts_dir.glob("*"):
            if script.is_file() and not script.stat().st_mode & 0o111:
                errors.append(f"script is not executable: {script.relative_to(skill_dir)}")

    if errors:
        print("skill audit failed:", file=sys.stderr)
        for error in errors:
            print(f"  - {error}", file=sys.stderr)
        return 1

    print(f"skill audit ok: {skill_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
