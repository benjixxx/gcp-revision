#!/usr/bin/env bash
# ==============================================================================
# Automatic Semantic Version Bumper for QualityAirApp
# ==============================================================================
# Usage:
#   ./bump_version.sh [patch|minor|major|get|set <version>] [--commit] [--tag]
#
# Examples:
#   ./bump_version.sh          # 1.0.0 -> 1.0.1 (default: patch)
#   ./bump_version.sh minor    # 1.0.0 -> 1.1.0
#   ./bump_version.sh major    # 1.0.0 -> 2.0.0
#   ./bump_version.sh set 2.1.0
#   ./bump_version.sh get      # prints current version
#   ./bump_version.sh patch --tag --commit
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

VERSION_FILE="${SCRIPT_DIR}/VERSION"
DEPLOYMENT_FILE="${SCRIPT_DIR}/k8s/deployment.yaml"
KUSTOMIZATION_FILE="${SCRIPT_DIR}/k8s/kustomization.yaml"

if [[ ! -f "${VERSION_FILE}" ]]; then
  echo "1.0.0" > "${VERSION_FILE}"
fi

CURRENT_VERSION="$(head -n 1 "${VERSION_FILE}" | tr -d '[:space:]')"

# Default values
ACTION="patch"
SET_VERSION=""
DO_COMMIT=false
DO_TAG=false

# Argument parsing
while [[ $# -gt 0 ]]; do
  case "$1" in
    patch|minor|major|get)
      ACTION="$1"
      shift
      ;;
    set)
      ACTION="set"
      SET_VERSION="$2"
      shift 2
      ;;
    --commit)
      DO_COMMIT=true
      shift
      ;;
    --tag)
      DO_TAG=true
      shift
      ;;
    -h|--help)
      echo "Usage: $0 [patch|minor|major|get|set <version>] [--commit] [--tag]"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      exit 1
      ;;
  esac
done

if [[ "${ACTION}" == "get" ]]; then
  echo "${CURRENT_VERSION}"
  exit 0
fi

# Parse SemVer components
if [[ "${CURRENT_VERSION}" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)(.*)$ ]]; then
  MAJOR="${BASH_REMATCH[1]}"
  MINOR="${BASH_REMATCH[2]}"
  PATCH="${BASH_REMATCH[3]}"
else
  echo "Warning: Current version '${CURRENT_VERSION}' is not standard SemVer (X.Y.Z). Defaulting to 1.0.0"
  MAJOR=1
  MINOR=0
  PATCH=0
fi

case "${ACTION}" in
  patch)
    NEW_PATCH=$((PATCH + 1))
    NEW_VERSION="${MAJOR}.${MINOR}.${NEW_PATCH}"
    ;;
  minor)
    NEW_MINOR=$((MINOR + 1))
    NEW_VERSION="${MAJOR}.${NEW_MINOR}.0"
    ;;
  major)
    NEW_MAJOR=$((MAJOR + 1))
    NEW_VERSION="${NEW_MAJOR}.0.0"
    ;;
  set)
    if [[ -z "${SET_VERSION}" ]]; then
      echo "Error: Version string required for 'set' action"
      exit 1
    fi
    NEW_VERSION="${SET_VERSION}"
    ;;
esac

echo "=================================================="
echo "  Bumping QualityAirApp Version: ${CURRENT_VERSION} -> ${NEW_VERSION}"
echo "=================================================="

# 1. Update VERSION file
echo "${NEW_VERSION}" > "${VERSION_FILE}"
echo "✓ Updated ${VERSION_FILE}"

# 2. Update k8s/deployment.yaml if present
if [[ -f "${DEPLOYMENT_FILE}" ]]; then
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' -E "s|(image: .*/quality-air-app:)[^ ]+|\1${NEW_VERSION}|g" "${DEPLOYMENT_FILE}"
  else
    sed -i -E "s|(image: .*/quality-air-app:)[^ ]+|\1${NEW_VERSION}|g" "${DEPLOYMENT_FILE}"
  fi
  echo "✓ Updated ${DEPLOYMENT_FILE}"
fi

# 3. Update k8s/kustomization.yaml if present
if [[ -f "${KUSTOMIZATION_FILE}" ]]; then
  if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' -E "s|(newTag: \")[^\"]+(\")|\1${NEW_VERSION}\2|g" "${KUSTOMIZATION_FILE}"
    sed -i '' -E "s|(newTag: )[^\"].*|\1\"${NEW_VERSION}\"|g" "${KUSTOMIZATION_FILE}"
  else
    sed -i -E "s|(newTag: \")[^\"]+(\")|\1${NEW_VERSION}\2|g" "${KUSTOMIZATION_FILE}"
    sed -i -E "s|(newTag: )[^\"].*|\1\"${NEW_VERSION}\"|g" "${KUSTOMIZATION_FILE}"
  fi
  echo "✓ Updated ${KUSTOMIZATION_FILE}"
fi

# 4. Optional Git commit & tag
if [[ "${DO_COMMIT}" == true ]]; then
  git -C "${REPO_ROOT}" add "${VERSION_FILE}" "${DEPLOYMENT_FILE}" "${KUSTOMIZATION_FILE}"
  git -C "${REPO_ROOT}" commit -m "chore(release): bump quality-air-app to ${NEW_VERSION}"
  echo "✓ Git commit created"
fi

if [[ "${DO_TAG}" == true ]]; then
  git -C "${REPO_ROOT}" tag -a "v${NEW_VERSION}" -m "Release v${NEW_VERSION}"
  echo "✓ Git tag v${NEW_VERSION} created"
fi

echo "=================================================="
echo "Successfully updated version to ${NEW_VERSION}"
echo "=================================================="
