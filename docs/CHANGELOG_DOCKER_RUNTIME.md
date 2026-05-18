# EasyMCP Docker Runtime Changelog

This file is the public changelog for the EasyMCP Docker runtime image.

The Docker runtime is the public OpenAPI-to-MCP server runtime. Users run it from Docker Hub instead of cloning private implementation source.

Release evidence:

- Docker tag list: [`../DOCKER_TAGS.md`](../DOCKER_TAGS.md)
- Machine-readable Docker metadata: [`../docker-tags.json`](../docker-tags.json)
- Docker Hub repository: `https://hub.docker.com/r/ab0tcom/easymcp`

## Current Docker Hub State

- Published tags: `v0.1.1`, `v0.1.0`.
- `latest` tag: not currently published.
- Current CLI default image: `ab0tcom/easymcp:v0.1.0`.

## v0.1.1

### Public Summary

`v0.1.1` is a published Docker Hub runtime tag for users who want a pinned EasyMCP image.

### Pull

```bash
docker pull ab0tcom/easymcp:v0.1.1
```

### Public Message

- Active Docker Hub image tag.
- Intended for pinned runtime usage.
- Use immutable tags in examples, scripts, CI, and production-style deployments.

### Support Notes

- Docker Hub confirms this tag exists.
- Do not infer implementation-level change details from Docker tag metadata alone.
- If a user asks which image to run with the current CLI defaults, use `ab0tcom/easymcp:v0.1.0` until the CLI default is explicitly changed.

## v0.1.0

### Public Summary

`v0.1.0` is the initial public EasyMCP Docker runtime image.

### Pull

```bash
docker pull ab0tcom/easymcp:v0.1.0
```

### Public Message

- Initial public OpenAPI-to-MCP Docker runtime.
- Allows users to run EasyMCP without access to private implementation source.
- Current CLI default runtime image.

### User Value

- Fast local runtime for turning OpenAPI specs into MCP tools.
- Works with the public CLI lifecycle.
- Can be pinned in Docker commands, Compose examples, internal docs, and agent onboarding flows.

## Docker Communication Rules

- Do not publish instructions that use `ab0tcom/easymcp:latest` unless Docker Hub actually has a `latest` tag.
- Prefer immutable tags for reproducible examples.
- Check `../DOCKER_TAGS.md` before claiming that a tag exists.
- Keep private source, private build details, and internal implementation notes out of public Docker release copy.
