#!/usr/bin/env bash
set -euo pipefail

# Safe installer for easymcp from public release artifacts.
# Intended usage:
#   curl -fsSL https://raw.githubusercontent.com/ab0t-com/easymcp/main/cli/install.sh | bash
#
# Environment variables:
#   EASYMCP_REPO=ab0t-com/easymcp
#   EASYMCP_BINARY=easymcp
#   EASYMCP_RUNTIME_BINARY=easymcp-runtime
#   EASYMCP_INCLUDE_RUNTIME=1
#   EASYMCP_INSTALL_DIR=$HOME/.local/bin
#   EASYMCP_VERSION=latest|vX.Y.Z
#   EASYMCP_CHECKSUMS=1
#   EASYMCP_DRY_RUN=0|1
#   EASYMCP_RELEASE_BASE_URL=https://github.com/<repo>/releases/download
#   EASYMCP_RELEASE_MIRROR_BASE_URL=https://raw.githubusercontent.com/<repo>/main/releases/downloads
#   EASYMCP_LATEST_URL=https://raw.githubusercontent.com/<repo>/main/releases/latest.txt
#   EASYMCP_GITHUB_API=https://api.github.com
#
# Notes:
# - By default this installs the `easymcp` CLI and, when a matching release
#   asset exists, the companion `easymcp-runtime` static binary side by side
#   (the Go runtime form — same config, no Docker daemon required). The
#   runtime is best-effort: if a release predates it or the asset is absent,
#   the CLI still installs cleanly. Set EASYMCP_INCLUDE_RUNTIME=0 to skip it,
#   or EASYMCP_BINARY=easymcp-runtime to install only the runtime binary.
# - It prefers GitHub Releases, then falls back to repo-mirrored release files.
# - It verifies checksums when a matching checksums file is available.
# - It does not run sudo automatically. If INSTALL_DIR is not writable, it exits.

REPO="${EASYMCP_REPO:-ab0t-com/easymcp}"
BINARY="${EASYMCP_BINARY:-easymcp}"
RUNTIME_BINARY="${EASYMCP_RUNTIME_BINARY:-easymcp-runtime}"
INCLUDE_RUNTIME="${EASYMCP_INCLUDE_RUNTIME:-1}"
INSTALL_DIR="${EASYMCP_INSTALL_DIR:-$HOME/.local/bin}"
VERSION="${EASYMCP_VERSION:-latest}"
CHECKSUMS="${EASYMCP_CHECKSUMS:-1}"
DRY_RUN="${EASYMCP_DRY_RUN:-0}"
GITHUB_API="${EASYMCP_GITHUB_API:-${GITHUB_API:-https://api.github.com}}"
RELEASE_BASE="${EASYMCP_RELEASE_BASE_URL:-https://github.com/${REPO}/releases/download}"
MIRROR_BASE="${EASYMCP_RELEASE_MIRROR_BASE_URL:-https://raw.githubusercontent.com/${REPO}/main/releases/downloads}"
LATEST_URL="${EASYMCP_LATEST_URL:-https://raw.githubusercontent.com/${REPO}/main/releases/latest.txt}"

fail() {
  echo "install.sh: $*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

try_fetch() {
  local url="$1"
  local out="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$out" 2>/dev/null
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$out" "$url" 2>/dev/null
  else
    fail "curl or wget is required"
  fi
}

fetch() {
  local url="$1"
  local out="$2"
  try_fetch "$url" "$out" || fail "failed to fetch: $url"
}

fetch_first() {
  local out="$1"
  shift
  local url
  for url in "$@"; do
    if try_fetch "$url" "$out"; then
      echo "$url"
      return 0
    fi
  done
  fail "failed to fetch any candidate URL"
}

detect_os() {
  case "$(uname -s)" in
    Linux) echo "linux" ;;
    Darwin) echo "darwin" ;;
    *) fail "unsupported operating system: $(uname -s)" ;;
  esac
}

detect_arch() {
  case "$(uname -m)" in
    x86_64|amd64) echo "amd64" ;;
    arm64|aarch64) echo "arm64" ;;
    *) fail "unsupported architecture: $(uname -m)" ;;
  esac
}

resolve_version() {
  if [ "$DRY_RUN" = "1" ] && [ "$VERSION" != "latest" ]; then
    echo "$VERSION"
    return
  fi
  if [ "$VERSION" != "latest" ]; then
    echo "$VERSION"
    return
  fi

  need_cmd sed
  local tmp tag
  tmp="$(mktemp)"
  tag=""
  if try_fetch "${GITHUB_API}/repos/${REPO}/releases/latest" "$tmp"; then
    tag="$(sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' "$tmp" | head -n1)"
  fi
  if [ -z "$tag" ] && try_fetch "$LATEST_URL" "$tmp"; then
    tag="$(sed -n 's/^[[:space:]]*\(v[0-9][^[:space:]]*\)[[:space:]]*$/\1/p' "$tmp" | head -n1)"
  fi
  rm -f "$tmp"
  [ -n "$tag" ] || fail "could not resolve latest release for ${REPO}"
  echo "$tag"
}

verify_checksum() {
  local file="$1"
  local checksums="$2"
  local basename
  basename="$(basename "$file")"
  grep -q " ${basename}\$" "$checksums" || fail "no checksum entry found for ${basename}"
  if command -v sha256sum >/dev/null 2>&1; then
    local output
    output="$(cd "$(dirname "$file")" && sha256sum -c "$(basename "$checksums")" --ignore-missing)"
    [ -n "$output" ] || fail "checksum verification produced no result for ${basename}"
    printf '%s\n' "$output" >&2
  elif command -v shasum >/dev/null 2>&1; then
    local expected actual
    expected="$(grep " ${basename}\$" "$checksums" | awk '{print $1}')"
    actual="$(shasum -a 256 "$file" | awk '{print $1}')"
    [ "$expected" = "$actual" ] || fail "checksum mismatch for ${basename}"
    echo "${basename}: OK" >&2
  else
    fail "checksum verification requested but sha256sum/shasum is unavailable"
  fi
  echo "Checksum verified for ${basename}" >&2
}

# install_one_binary downloads, verifies, and installs a single binary's
# release tarball into INSTALL_DIR. The tarball naming and URL layout are
# identical for every binary (easymcp, easymcp-runtime), so both share this
# function.
#
# Args:
#   $1 binary   — binary name (== tarball prefix and extracted file name).
#   $2 os
#   $3 arch
#   $4 version
#   $5 tmpdir   — a scratch dir the caller owns and cleans up.
#   $6 required — "1" to fail on a missing asset, "0" for best-effort (warn
#                 and skip). The companion runtime is best-effort so a
#                 release that predates it still installs the CLI cleanly.
install_one_binary() {
  local binary="$1" os="$2" arch="$3" version="$4" tmpdir="$5" required="$6"
  local asset_name asset_url asset_mirror_url asset_root_mirror_url
  local checksums_url checksums_mirror_url checksums_root_mirror_url
  local archive checksums binary_path fetched_asset_url fetched_checksums_url

  asset_name="${binary}_${version#v}_${os}_${arch}.tar.gz"
  asset_url="${RELEASE_BASE}/${version}/${asset_name}"
  asset_mirror_url="${MIRROR_BASE}/${version}/${asset_name}"
  asset_root_mirror_url="${MIRROR_BASE}/${asset_name}"
  checksums_url="${RELEASE_BASE}/${version}/checksums.txt"
  checksums_mirror_url="${MIRROR_BASE}/${version}/checksums.txt"
  checksums_root_mirror_url="${MIRROR_BASE}/checksums.txt"

  archive="${tmpdir}/${asset_name}"
  checksums="${tmpdir}/${binary}.checksums.txt"

  echo "Installing ${binary} ${version} from ${REPO}" >&2
  if [ "$required" = "1" ]; then
    fetched_asset_url="$(fetch_first "$archive" "$asset_url" "$asset_mirror_url" "$asset_root_mirror_url")"
  else
    fetched_asset_url="$(fetch_first "$archive" "$asset_url" "$asset_mirror_url" "$asset_root_mirror_url" 2>/dev/null)" || {
      echo "Skipping ${binary}: no release asset found for ${version} (this release may not ship it)." >&2
      return 0
    }
  fi
  echo "Downloaded ${asset_name} from ${fetched_asset_url}" >&2

  if [ "$CHECKSUMS" = "1" ]; then
    fetched_checksums_url="$(fetch_first "$checksums" "$checksums_url" "$checksums_mirror_url" "$checksums_root_mirror_url")"
    echo "Downloaded checksums from ${fetched_checksums_url}" >&2
    verify_checksum "$archive" "$checksums"
  fi

  tar -xzf "$archive" -C "$tmpdir"
  binary_path="${tmpdir}/${binary}"
  [ -f "$binary_path" ] || fail "release archive did not contain ${binary}"

  mkdir -p "$INSTALL_DIR"
  [ -w "$INSTALL_DIR" ] || fail "install dir is not writable: ${INSTALL_DIR}"

  install -m 0755 "$binary_path" "${INSTALL_DIR}/${binary}"
  if [ "${binary}" = "easymcp" ]; then
    ln -sfn "${INSTALL_DIR}/${binary}" "${INSTALL_DIR}/mcpctl"
  fi
  if [ "$CHECKSUMS" = "1" ]; then
    echo "Verified and installed ${binary} ${version} to ${INSTALL_DIR}/${binary}" >&2
  else
    echo "Installed ${binary} ${version} to ${INSTALL_DIR}/${binary} (checksum verification disabled)" >&2
  fi
}

main() {
  need_cmd mktemp
  need_cmd tar

  local os arch version tmpdir
  os="$(detect_os)"
  arch="$(detect_arch)"
  version="$(resolve_version)"

  # The runtime companion is only meaningful when installing the CLI. When a
  # caller pins EASYMCP_BINARY to something else, honor exactly that binary.
  local include_runtime="$INCLUDE_RUNTIME"
  if [ "$BINARY" != "easymcp" ]; then
    include_runtime="0"
  fi

  if [ "$DRY_RUN" = "1" ]; then
    echo "Dry run OK" >&2
    echo "  repo:         ${REPO}" >&2
    echo "  version:      ${version}" >&2
    echo "  asset:        ${BINARY}_${version#v}_${os}_${arch}.tar.gz" >&2
    echo "  asset_url:    ${RELEASE_BASE}/${version}/${BINARY}_${version#v}_${os}_${arch}.tar.gz" >&2
    if [ "$include_runtime" = "1" ]; then
      echo "  runtime:      ${RUNTIME_BINARY}_${version#v}_${os}_${arch}.tar.gz (best-effort)" >&2
      echo "  runtime_url:  ${RELEASE_BASE}/${version}/${RUNTIME_BINARY}_${version#v}_${os}_${arch}.tar.gz" >&2
    else
      echo "  runtime:      (skipped)" >&2
    fi
    echo "  checksums:    ${CHECKSUMS}" >&2
    echo "  install_dir:  ${INSTALL_DIR}" >&2
    exit 0
  fi

  tmpdir="$(mktemp -d)"
  trap 'rm -rf "${tmpdir:-}"' EXIT

  install_one_binary "$BINARY" "$os" "$arch" "$version" "$tmpdir" 1
  if [ "$include_runtime" = "1" ]; then
    install_one_binary "$RUNTIME_BINARY" "$os" "$arch" "$version" "$tmpdir" 0
  fi

  echo "Run '${BINARY} --help' to get started." >&2
}

main "$@"
