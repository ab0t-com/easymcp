# EasyMCP Production Auth Guide

## Scope

This guide explains how authentication is expected to work for MCP in production, what an MCP server should and should not store, how downstream API tokens differ from MCP server tokens, and what enterprise-safe patterns look like when you need to ship EasyMCP as a product.

This guide assumes two different security boundaries:
- **client -> MCP server**
- **MCP server -> downstream API**

Those are separate auth problems.

## Short Answer

### Do MCP servers ever store private client things?

Sometimes, yes, but only for specific reasons.

An MCP server may legitimately store or access:
- its **own** upstream API credentials
- its **own** OAuth confidential client credentials for upstream APIs
- short-lived session state needed to validate or use auth
- optional token introspection credentials if the server validates opaque tokens against an IdP

An MCP server should **not** normally:
- act as a dumb pass-through for the user's MCP access token
- store arbitrary long-lived user secrets when a client or secret manager should hold them
- mix one tenant's credentials with another tenant's runtime context

For remote HTTP MCP, the MCP server is expected to validate tokens presented by the client. If the MCP server calls downstream APIs, it should use a **separate** token or credential set for those APIs.

## What the MCP spec expects

For **HTTP MCP**:
- the MCP client obtains and sends access tokens to the MCP server
- the MCP server acts as an OAuth resource server and validates those tokens
- if the MCP server makes requests to upstream APIs, it may act as an OAuth client to them using separate credentials
- the MCP server **must not** pass through the inbound client token to the upstream API

For **STDIO MCP**:
- the HTTP OAuth flow is not the normal model
- local environment-based credentials are expected instead

This is the current official direction of the MCP authorization spec and its security guidance.

## The four auth planes

For an enterprise EasyMCP deployment, there are usually four distinct auth planes.

### 1. MCP transport auth

This is auth for:
- Claude Code / Codex / another MCP client -> EasyMCP server

Examples:
- OAuth authorization code + PKCE
- bearer token validation at the MCP server
- JWT validation with issuer/audience/JWKS
- mTLS or enterprise edge auth in front of MCP

### 2. Downstream API auth

This is auth for:
- EasyMCP server -> target API described by the OpenAPI spec

Examples:
- API key header
- bearer token
- basic auth
- OAuth client credentials
- signed service account JWT

### 3. Tenant/account context

This is not always the same thing as auth.

Examples:
- `org_id`
- `org_slug`
- account id
- workspace id
- region / environment selector

You may be authenticated correctly but still be pointed at the wrong tenant. That is a separate risk.

### 4. Secret source auth

This is auth for retrieving secret values themselves.

Examples:
- Vault auth
- AWS IAM for Secrets Manager
- GCP workload identity for Secret Manager
- Azure managed identity for Key Vault

## Recommended storage boundaries

The safest production model is:

### Client stores

The MCP client should store:
- user OAuth tokens for remote HTTP MCP access
- optional client ID / client secret for pre-registered MCP OAuth clients
- local project config and agent registration config

Example today:
- Claude Code stores auth tokens securely and refreshes them automatically for remote MCP OAuth flows

### MCP server stores or resolves

The EasyMCP server may store or resolve:
- references to downstream API credentials
- server-side client credentials for upstream APIs
- JWT validation metadata such as issuer, audience, JWKS URI
- non-secret tenant/account metadata

### Secret manager stores

A secret manager should hold:
- real API tokens
- client secrets
- private keys
- tenant-specific credentials for production environments

### Registry/config stores

EasyMCP registry/config should store:
- **references** to env vars or secret-provider keys
- auth mode
- expected tenant mode
- expected identity provider
- expected downstream base URL

For local/operator workflows, EasyMCP profiles add a separate non-secret account boundary:
- `profiles.json` stores customer/environment metadata, credential refs, tenant metadata, and agent auth projections
- `audit.jsonl` records profile mutations and profile-aware agent installs
- profile-aware agent config writes env var references, not raw token values

EasyMCP registry/config should not normally store:
- raw production secrets
- shared multi-tenant credentials pasted inline

## Production deployment models

### Model A: Local developer workflow

- EasyMCP runs locally in Docker
- credentials are loaded from the local environment
- Claude/Codex connects over local HTTP or stdio

Good for:
- development
- testing
- isolated single-user use

Less good for:
- shared enterprise operations

### Model B: Hosted remote MCP service

- EasyMCP is hosted remotely
- MCP clients connect over HTTPS
- auth is enforced at the MCP server using OAuth or JWT validation
- downstream API credentials are server-side

Good for:
- enterprise deployment
- multi-user access control
- audit and policy

### Model C: Hosted MCP plus enterprise edge

- EasyMCP is behind an enterprise gateway
- edge handles network policy, WAF, TLS termination, maybe primary auth
- EasyMCP still validates MCP tokens or trusted identity context
- downstream API auth remains server-side

Good for:
- larger enterprises
- compliance-heavy deployments

## API token mode vs OAuth mode

### API token mode

Use when the downstream API only supports:
- API key headers
- bearer tokens already minted elsewhere
- simple service credentials

Best practice:
- store only env var or secret-manager references in EasyMCP config
- rotate outside EasyMCP
- restart and verify after rotation
- use profiles when different customers/environments need separate credential refs or tenant selectors

### OAuth mode

Use when the system needs:
- per-user delegated access
- consented scopes
- refresh semantics
- enterprise IdP integration
- clean separation between MCP access tokens and downstream API tokens

For remote HTTP MCP, OAuth is the right long-term model when the MCP server exposes sensitive operations or user data.

## OAuth flow roles

The main roles are:

- **MCP client**: Claude Code, Codex, custom app
- **MCP server**: EasyMCP
- **authorization server / IdP**: for example `auth.service.ab0t.com`, Okta, Auth0, Entra ID, Keycloak, WorkOS
- **downstream API**: the API generated from OpenAPI

## Production OAuth flow for remote HTTP MCP

This is the standard remote MCP pattern.

```text
User
  |
  | 1. Connect MCP server in client
  v
MCP Client (Claude/Codex/custom)
  |
  | 2. Request MCP endpoint
  v
EasyMCP Server
  |
  | 3. 401 + Protected Resource Metadata / auth discovery
  v
MCP Client
  |
  | 4. Discover authorization server metadata
  v
Authorization Server / IdP
  |
  | 5. Browser login + consent
  v
User
  |
  | 6. Authorization code returned to client
  v
MCP Client
  |
  | 7. Exchange code for MCP access token
  v
Authorization Server / IdP
  |
  | 8. Access token issued for EasyMCP audience/resource
  v
MCP Client
  |
  | 9. Authorization: Bearer <mcp-token>
  v
EasyMCP Server
  |
  | 10. Validate token (issuer, audience, expiry, scopes)
  |
  | 11. Execute tool call
  v
Downstream API (using separate server-side credentials if needed)
```

## Critical rule: no token passthrough

This is one of the most important rules.

The MCP token presented by the client is for the **MCP server**.
It is not automatically a valid token for the downstream API.

So EasyMCP should not do this:
- receive `Authorization: Bearer <mcp-token>` from Claude/Codex
- forward that exact token to the target API

That creates audience confusion and a confused-deputy risk.

Instead, EasyMCP should do one of these:
- use its own service credential to call the downstream API
- exchange/obtain a separate downstream token for the target API
- select a tenant-specific credential binding

## Enterprise downstream OAuth patterns

### Pattern 1: service credential

EasyMCP uses:
- client credentials
- service account token
- API key

Good when:
- the server acts as a service integration
- per-user attribution is not required downstream

### Pattern 2: token exchange / delegated downstream auth

EasyMCP validates the MCP token, then obtains a different token for the downstream API.

Good when:
- downstream APIs need user identity or delegated permissions
- enterprise audit trails require user attribution end-to-end

Harder to implement correctly.

### Pattern 3: tenant-bound service credentials

EasyMCP selects one of several service credentials based on the instance or explicit account profile.

Good when:
- consultants or agencies manage multiple customer tenants
- isolation is more important than shared-session convenience

This is usually safer than in-place auth switching.

## `auth.service.ab0t.com` as the main auth server

If `auth.service.ab0t.com` is your central auth authority, a strong production model is:

- `auth.service.ab0t.com` issues tokens for EasyMCP as an MCP resource server
- EasyMCP validates those inbound tokens for the EasyMCP audience/resource
- EasyMCP separately uses downstream credentials for the target API
- EasyMCP does not forward the inbound MCP token to unrelated target APIs

That means `auth.service.ab0t.com` can be your control point for:
- user auth
- scopes
- tenant/org membership
- token lifetimes
- refresh policy
- audit metadata

But the downstream API auth may still be different.

Examples:
- some customers use your main `auth.service.ab0t.com`
- another enterprise customer wants Okta
- another wants Entra ID
- another wants Auth0

So the product should support:
- a first-party auth-server mode
- a bring-your-own-IdP mode

## Enterprise IdP compatibility model

Your sellable production design should support these broad classes:

### 1. OIDC / OAuth authorization servers

Examples:
- your own `auth.service.ab0t.com`
- Okta
- Auth0
- Microsoft Entra ID
- Keycloak
- WorkOS
- Google

Requirements:
- discovery metadata
- issuer validation
- JWKS validation
- audience/resource validation
- scopes
- optional dynamic client registration
- optional pre-registered clients

### 2. JWT-only validation mode

For environments where tokens are minted elsewhere but can be validated with:
- issuer
- audience
- JWKS URI

### 3. service-key / API-key mode

For less mature downstream systems or machine-only usage.

### 4. client-credentials extension

For non-human MCP clients or automation, MCP now has an official client-credentials extension path.

Use this when:
- there is no interactive user
- the MCP client is a service or automation worker

## What should the product support

For a production-distributed EasyMCP, support these options explicitly.

### Inbound MCP auth options

- none
- JWT validation
- OAuth/OIDC authorization code + PKCE
- OAuth pre-registered client
- OAuth dynamic client registration
- client credentials extension for machine clients
- enterprise gateway or reverse-proxy integration

### Downstream API auth options

- none
- bearer token ref
- API key ref
- basic auth ref
- OAuth client credentials
- token exchange / delegated downstream token

### Secret source options

- env
- file
- Vault
- AWS Secrets Manager
- GCP Secret Manager
- Azure Key Vault
- Doppler / 1Password / equivalent adapter

### Tenant/account options

- fixed tenant per instance
- fixed customer/account per instance
- explicit profile-to-instance mapping
- optional future session-based switching, but not as the default enterprise model

## What should be stored where

### Client stores

The MCP client may store:
- user refresh tokens for MCP access
- client secret for the MCP OAuth client if pre-registered
- per-project MCP registration config

Best practice:
- use secure OS storage / keychain where available
- do not commit secrets to project config files

### EasyMCP runtime stores

EasyMCP may store:
- auth metadata
- secret references
- non-secret tenant/account metadata
- short-lived runtime state
- verification history

EasyMCP should avoid storing:
- raw long-lived user tokens unless absolutely required
- shared multi-tenant customer secrets inline in config

### Secret manager stores

Secret managers should store:
- API keys
- client secrets
- private keys
- tenant-specific credentials

## Best practices

### 1. keep inbound and outbound auth separate

Never assume the MCP token is the downstream API token.

### 2. validate token audience

If the token is for EasyMCP, validate that it is actually for EasyMCP.

### 3. do not pass through tokens

This is an explicit MCP anti-pattern.

### 4. prefer isolated instances for multi-customer use

For consultants or agencies:
- `acme-auth-prod`
- `globex-auth-prod`
- `initech-auth-prod`

This is safer than one instance that keeps changing account context.

### 5. model tenant/account identity explicitly

Store:
- customer
- environment
- tenant mode
- expected account id or org marker

### 6. verify after rotation

After changing secrets:
- restart
- verify MCP connectivity
- verify one safe authenticated downstream call
- verify tenant/account identity

### 7. store references, not values

Prefer:
- `EASYMCP_PAYMENT_API_TOKEN`

Not:
- inline secrets in YAML

### 8. use short-lived tokens where possible

Especially for user-delegated OAuth flows.

### 9. support both first-party and customer IdPs

Your product should not assume every customer will use your own auth server.

### 10. add enterprise verification commands

The product should eventually implement:
- `easymcp env required <name>`
- `easymcp env doctor <name>`
- `easymcp auth inspect <name>`
- `easymcp auth verify <name>`
- `easymcp tenant verify <name>`

## Recommended product posture

The production EasyMCP product should be able to say:

- we support standard MCP HTTP authorization flows
- we support local stdio/env-based auth for developer workflows
- we separate MCP auth from downstream API auth
- we do not rely on token passthrough
- we support first-party and bring-your-own IdP models
- we support secret references instead of forcing raw secret storage
- we support isolated per-customer instances for safer enterprise multi-tenant operations

## Bottom line

Yes, MCP servers may need to handle and sometimes store sensitive auth-related material.
But the correct production pattern is:

- clients store client-side login state
- MCP servers validate inbound MCP auth
- MCP servers use separate downstream credentials for target APIs
- secret managers hold long-lived secrets
- tenant/account context is explicit and verifiable

That is the design you want if EasyMCP is going to be sold and deployed as an enterprise product.
