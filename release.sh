#!/usr/bin/env bash
#
# release.sh — bump version, commit, tag, push.
#
# Usage:
#   ./release.sh patch               # bump 0.14.0 -> 0.14.1 (npm convention)
#   ./release.sh minor               # bump 0.14.0 -> 0.15.0
#   ./release.sh major               # bump 0.14.0 -> 1.0.0
#   ./release.sh <version>           # explicit, e.g. 0.14.1
#   ./release.sh <version>+<build>   # explicit version + build, e.g. 0.14.1+26
#   ./release.sh --dry-run <input>   # preview without doing anything
#
# Updates pubspec.yaml and lib/screens/about_screen.dart, commits with
# "bump to X.Y.Z", tags vX.Y.Z, and pushes the commit + tag. Pending
# working-tree changes get stashed (with --include-untracked) before
# the bump and popped at the end via an EXIT trap, even on failure.
#
# The pushed tag triggers .github/workflows/release.yml, which builds
# and publishes a signed APK to GitHub Releases.

set -euo pipefail

# ---- arg parsing -----------------------------------------------------------
DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=1
  shift
fi

if [[ $# -ne 1 ]]; then
  cat >&2 <<EOF
usage: $0 [--dry-run] <input>
  $0 patch             # bump 0.14.0 -> 0.14.1 (npm convention)
  $0 minor             # bump 0.14.0 -> 0.15.0
  $0 major             # bump 0.14.0 -> 1.0.0
  $0 0.14.1            # explicit version, auto-increment build
  $0 0.14.1+26         # explicit version + build
  $0 0.14.1-rc1        # pre-release suffix supported (tag becomes v0.14.1-rc1)
EOF
  exit 1
fi

INPUT="$1"

# ---- preflight: read current version from pubspec --------------------------
# Done before resolving INPUT because patch/minor/major need the current
# version to compute the new one from.
if [[ ! -f pubspec.yaml ]]; then
  echo "error: pubspec.yaml not found — run from the project root" >&2
  exit 1
fi

CURRENT_LINE="$(grep -E '^version:' pubspec.yaml | head -1)"
CURRENT="${CURRENT_LINE#version: }"
CURRENT="$(echo "$CURRENT" | tr -d '[:space:]')"
CURRENT_VERSION="${CURRENT%+*}"
CURRENT_BUILD="${CURRENT##*+}"

# ---- resolve INPUT into NEW_VERSION + (optional) EXPLICIT_BUILD ----------
EXPLICIT_BUILD=""
case "$INPUT" in
  patch|minor|major)
    # npm-style bump from the current pubspec version. Strip any
    # pre-release suffix ("-rc1" etc.) before bumping — going from
    # 0.14.0-rc1 to a real release should land on 0.14.1, not preserve
    # the rc tag.
    BASE="${CURRENT_VERSION%%-*}"
    IFS='.' read -r CUR_MAJOR CUR_MINOR CUR_PATCH <<< "$BASE"
    case "$INPUT" in
      patch) NEW_VERSION="$CUR_MAJOR.$CUR_MINOR.$((CUR_PATCH + 1))" ;;
      minor) NEW_VERSION="$CUR_MAJOR.$((CUR_MINOR + 1)).0" ;;
      major) NEW_VERSION="$((CUR_MAJOR + 1)).0.0" ;;
    esac
    ;;
  *)
    # Explicit: X.Y.Z, X.Y.Z-suffix, X.Y.Z+N, X.Y.Z-suffix+N
    if [[ ! "$INPUT" =~ ^([0-9]+\.[0-9]+\.[0-9]+(-[A-Za-z0-9]+)?)(\+([0-9]+))?$ ]]; then
      echo "error: '$INPUT' is not valid input" >&2
      echo "       want one of: patch | minor | major | X.Y.Z[-suffix][+N]" >&2
      exit 1
    fi
    NEW_VERSION="${BASH_REMATCH[1]}"
    EXPLICIT_BUILD="${BASH_REMATCH[4]}"
    ;;
esac

if [[ -n "$EXPLICIT_BUILD" ]]; then
  NEW_BUILD="$EXPLICIT_BUILD"
else
  NEW_BUILD=$((CURRENT_BUILD + 1))
fi

FULL_NEW="${NEW_VERSION}+${NEW_BUILD}"
TAG="v${NEW_VERSION}"

echo "Current: $CURRENT"
echo "New:     $FULL_NEW"
echo "Tag:     $TAG"
echo

# Pull latest tags so the duplicate-tag check is honest
git fetch --tags --quiet || true

if git rev-parse --verify --quiet "$TAG" >/dev/null; then
  echo "error: tag $TAG already exists locally" >&2
  exit 1
fi
if git ls-remote --exit-code --tags origin "$TAG" >/dev/null 2>&1; then
  echo "error: tag $TAG already exists on origin" >&2
  exit 1
fi

if [[ -z "$EXPLICIT_BUILD" ]] && (( NEW_BUILD <= CURRENT_BUILD )); then
  echo "error: build $NEW_BUILD is not greater than current $CURRENT_BUILD" >&2
  exit 1
fi

if [[ $DRY_RUN -eq 1 ]]; then
  echo "(dry run — no changes made)"
  exit 0
fi

# ---- stash, with restore on exit -------------------------------------------
NEED_STASH=0
if [[ -n "$(git status --porcelain)" ]]; then
  echo "Stashing working-tree changes..."
  git stash push --include-untracked --message "release.sh autostash for $TAG" >/dev/null
  NEED_STASH=1
fi

cleanup() {
  local rc=$?
  if [[ $NEED_STASH -eq 1 ]]; then
    echo "Restoring stashed changes..."
    if ! git stash pop; then
      echo "warning: 'git stash pop' had conflicts — resolve manually" >&2
    fi
  fi
  exit $rc
}
trap cleanup EXIT

# ---- bump files ------------------------------------------------------------
# Cross-platform sed -i works via .bak suffix + immediate delete.
sed -i.bak "s/^version: .*/version: $FULL_NEW/" pubspec.yaml
rm -f pubspec.yaml.bak

# about_screen's _versionLabel is a hardcoded const — bump it alongside
# pubspec. Pattern check first so older branches (where the const
# doesn't exist) silently skip rather than mutating unrelated text.
ABOUT="lib/screens/about_screen.dart"
if [[ -f "$ABOUT" ]] && grep -q "static const _versionLabel = '" "$ABOUT"; then
  sed -i.bak "s/static const _versionLabel = '[^']*';/static const _versionLabel = '$TAG';/" "$ABOUT"
  rm -f "$ABOUT.bak"
fi

echo
echo "Diff:"
git --no-pager diff -- pubspec.yaml "$ABOUT"
echo

# ---- commit, tag, push -----------------------------------------------------
git add pubspec.yaml "$ABOUT"
git commit -m "bump to $NEW_VERSION"
git tag "$TAG"

echo "Pushing commit and tag..."
git push
git push origin "$TAG"

echo
echo "Done. The release workflow should now be running for tag $TAG."
echo "Watch: https://github.com/IrosTheBeggar/mstream_music/actions"
