# Docker Run Patterns

## Basic Run

```bash
docker run --rm \
  --name easymcp-public-api \
  -p 8000:8000 \
  -v "$PWD/config.yaml:/app/config.yaml:ro" \
  ab0tcom/easymcp:v0.1.0 \
  /app/config.yaml
```

## With Env Vars

```bash
docker run --rm \
  --name easymcp-secure-api \
  -p 8000:8000 \
  -e EASYMCP_API_TOKEN \
  -v "$PWD/config.yaml:/app/config.yaml:ro" \
  ab0tcom/easymcp:v0.1.0 \
  /app/config.yaml
```

## Diagnostics

```bash
docker ps
docker logs easymcp-public-api
curl -s http://localhost:8000/health
```

MCP endpoint:

```text
http://localhost:8000/mcp
```

## Common Mistakes

- Mounting the config at the wrong path.
- Forgetting the positional `/app/config.yaml` argument.
- Mapping a different host port than the config container port.
- Using `latest` accidentally in production.
- Expecting Docker Hub README to update from `docker push`.

