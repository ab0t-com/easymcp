# Config Patterns

## No Auth

```yaml
version: "1.0"
server:
  name: public-api
openapi:
  url: https://api.example.com/openapi.json
api_auth:
  type: none
mcp_auth:
  enabled: false
  type: none
transport:
  type: http
  host: 0.0.0.0
  port: 8000
```

## Bearer Auth to Upstream API

```yaml
api_auth:
  type: bearer
  token_env: EASYMCP_API_TOKEN
```

Run with:

```bash
docker run --rm -e EASYMCP_API_TOKEN ...
```

## Basic Auth to Upstream API

```yaml
api_auth:
  type: basic
  username_env: EASYMCP_API_USERNAME
  password_env: EASYMCP_API_PASSWORD
```

## Rules

- Store env var names in config, not secret values.
- Keep `host: 0.0.0.0` inside containers.
- Map host ports explicitly with `-p host:container`.
- Pin Docker image tags for shared or production usage.

