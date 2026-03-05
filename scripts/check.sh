#!/usr/bin/env bash
set -euo pipefail

TARGET_DIR="${1:-.}"

if [[ ! -d "$TARGET_DIR" ]]; then
  echo "Error: target directory does not exist: $TARGET_DIR" >&2
  exit 1
fi

TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
POM_FILE="$TARGET_DIR/pom.xml"
GRADLE_FILE="$TARGET_DIR/build.gradle"
GRADLE_KTS_FILE="$TARGET_DIR/build.gradle.kts"
audit_javax_tmp=""
audit_sf_tmp=""
trap 'rm -f "$audit_javax_tmp" "$audit_sf_tmp"' EXIT

section() {
  printf "\n== %s ==\n" "$1"
}

# Extract first occurrence of <tag>value</tag> using grep + sed (no ripgrep)
extract_xml_tag_value() {
  local file="$1"
  local tag="$2"
  grep -oE "<${tag}>[^<]+</${tag}>" "$file" 2>/dev/null | head -1 | sed -E "s#<${tag}>([^<]+)</${tag}>#\1#"
}

extract_boot_parent_version_from_pom() {
  local file="$1"
  awk '
    /<parent>/ {in_parent=1}
    in_parent && /<artifactId>spring-boot-starter-parent<\/artifactId>/ {is_boot_parent=1}
    in_parent && is_boot_parent && /<version>/ {
      match($0, /<version>[^<]+<\/version>/)
      if (RSTART > 0) {
        value = substr($0, RSTART + 9, RLENGTH - 19)
        print value
        exit
      }
    }
    /<\/parent>/ {
      in_parent=0
      is_boot_parent=0
    }
  ' "$file"
}

extract_boot_version_from_gradle() {
  local file="$1"
  grep -oE "org\.springframework\.boot['\"]?\\)? version ['\"][^'\"]+['\"]" "$file" 2>/dev/null | head -1 | sed -E "s/.* version ['\"]([^'\"]+)['\"].*/\1/"
}

section "Target"
echo "$TARGET_DIR"

section "Build files"
found_build_file=0
if [[ -f "$POM_FILE" ]]; then
  echo "Found: pom.xml"
  found_build_file=1
fi
if [[ -f "$GRADLE_FILE" ]]; then
  echo "Found: build.gradle"
  found_build_file=1
fi
if [[ -f "$GRADLE_KTS_FILE" ]]; then
  echo "Found: build.gradle.kts"
  found_build_file=1
fi
if [[ "$found_build_file" -eq 0 ]]; then
  echo "No Maven/Gradle build file found in root."
fi

section "Spring Boot version hints"
if [[ -f "$POM_FILE" ]]; then
  parent_version="$(extract_boot_parent_version_from_pom "$POM_FILE" || true)"
  prop_version="$(extract_xml_tag_value "$POM_FILE" "spring-boot.version" || true)"
  [[ -n "${parent_version:-}" ]] && echo "pom parent spring-boot-starter-parent: $parent_version"
  [[ -n "${prop_version:-}" ]] && echo "pom property spring-boot.version: $prop_version"
  if [[ -z "${parent_version:-}" && -z "${prop_version:-}" ]]; then
    echo "No spring boot version found from pom parent/property."
  fi
fi
if [[ -f "$GRADLE_FILE" ]]; then
  gradle_version="$(extract_boot_version_from_gradle "$GRADLE_FILE" || true)"
  [[ -n "${gradle_version:-}" ]] && echo "gradle plugin org.springframework.boot: $gradle_version" || echo "No spring boot plugin version found in build.gradle."
fi
if [[ -f "$GRADLE_KTS_FILE" ]]; then
  gradle_kts_version="$(extract_boot_version_from_gradle "$GRADLE_KTS_FILE" || true)"
  [[ -n "${gradle_kts_version:-}" ]] && echo "gradle.kts plugin org.springframework.boot: $gradle_kts_version" || echo "No spring boot plugin version found in build.gradle.kts."
fi

section "Javax usage scan"
audit_javax_tmp="$(mktemp)"
find "$TARGET_DIR" -type f \( -name '*.java' -o -name '*.kt' -o -name '*.kts' -o -name '*.groovy' \) 2>/dev/null \
  -exec grep -n 'import javax\.' {} + 2>/dev/null > "$audit_javax_tmp" || true
javax_count="$(wc -l < "$audit_javax_tmp" | tr -d ' ')"
echo "Total javax import lines: $javax_count"
if [[ "$javax_count" -gt 0 ]]; then
  echo "Top files with javax imports:"
  find "$TARGET_DIR" -type f \( -name '*.java' -o -name '*.kt' -o -name '*.kts' -o -name '*.groovy' \) 2>/dev/null | while read -r f; do
    c="$(grep -c 'import javax\.' "$f" 2>/dev/null || echo 0)"
    if [[ "$c" -gt 0 ]]; then
      printf "%s %s\n" "$c" "$f"
    fi
  done | sort -rn | head -10
fi

section "Springfox usage scan"
audit_sf_tmp="$(mktemp)"
find "$TARGET_DIR" -type f \( -name 'pom.xml' -o -name 'build.gradle' -o -name 'build.gradle.kts' -o -name '*.java' -o -name '*.kt' -o -name '*.properties' -o -name '*.yml' -o -name '*.yaml' \) 2>/dev/null | while read -r f; do
  grep -nE '<groupId>io\.springfox</groupId>|<artifactId>springfox[^<]*</artifactId>|import springfox\.' "$f" 2>/dev/null || true
done > "$audit_sf_tmp"
springfox_count="$(wc -l < "$audit_sf_tmp" | tr -d ' ')"
echo "Total springfox matches: $springfox_count"
if [[ "$springfox_count" -gt 0 ]]; then
  head -20 "$audit_sf_tmp"
fi

section "Summary"
if [[ "$found_build_file" -eq 0 ]]; then
  echo "Status: unknown (missing build files)."
elif [[ "$javax_count" -gt 0 ]]; then
  echo "Status: migration needed (javax remains)."
else
  echo "Status: no javax imports detected; continue full Boot 3 compatibility checks."
fi
