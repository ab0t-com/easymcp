# Public Repo Map

The public repo is an artifact and support repo, not the private implementation repo.

Expected tree:

```text
.
├── README.md
├── install.sh
├── cli/install.sh
├── DOCKERHUB_README.md
├── docs/
├── examples/
├── releases/
├── Skills/
└── .github/ISSUE_TEMPLATE/
```

Allowed content:

- public product docs
- install script
- example configs
- release archives and checksums
- issue templates
- skills for AI agents

Disallowed content:

- Go source
- Python implementation source
- Dockerfile from the private runtime build
- private test fixtures
- embedded credentials
- private operational notes

Public users should rely on:

- Docker image: `ab0tcom/easymcp`
- CLI installer: `https://raw.githubusercontent.com/ab0t-com/easymcp/main/install.sh`
- release downloads and checksums
- public docs and examples

