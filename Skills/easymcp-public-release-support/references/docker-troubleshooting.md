# Docker Troubleshooting

## Pull Image

```bash
docker pull ab0tcom/easymcp:v0.1.0
docker image inspect ab0tcom/easymcp:v0.1.0
```

## Run With Config

```bash
docker run --rm \
  -p 8000:8000 \
  -v "$PWD/config.yaml:/app/config.yaml:ro" \
  ab0tcom/easymcp:v0.1.0 \
  /app/config.yaml
```

## Common Issues

- Docker is not installed or not running.
- Port is already allocated.
- Config file path is wrong.
- Required env var is not passed with `-e`.
- OpenAPI URL is private or unreachable from the container.

## Docker Hub README Behavior

Pushing an image does not update Docker Hub README/Overview.

Docker Hub README updates require one of:

- manual edit in Docker Hub UI
- automated build README sync from linked source repo
- Docker Hub API metadata update with a Docker Hub token

