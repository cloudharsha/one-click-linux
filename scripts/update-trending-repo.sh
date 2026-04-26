#!/usr/bin/env bash
set -euo pipefail

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "error: '$1' is required"
    exit 1
  }
}

need python3

OUTPUT_DIR="${OUTPUT_DIR:-trending}"
TRENDING_PERIOD="${TRENDING_PERIOD:-daily}"
TRENDING_LIMIT="${TRENDING_LIMIT:-12}"
TODAY="$(date -u +%F)"

mkdir -p "$OUTPUT_DIR"

python3 - "$OUTPUT_DIR" "$TRENDING_PERIOD" "$TRENDING_LIMIT" "$TODAY" <<'PY'
import datetime as dt
import html
import json
import os
import re
import sys
import urllib.error
import urllib.request


output_dir, trending_period, trending_limit_raw, today = sys.argv[1:5]
trending_limit = int(trending_limit_raw)

headers = {
    "Accept": "application/vnd.github+json",
    "User-Agent": "one-click-linux-trending-bot",
}
token = os.getenv("GITHUB_TOKEN")
if token:
    headers["Authorization"] = f"Bearer {token}"


def fetch_text(url):
    request = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read().decode("utf-8", errors="ignore")


def fetch_json(url):
    request = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def existing_repo_links():
    links = set()
    if not os.path.isdir(output_dir):
        return links

    link_pattern = re.compile(r"https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+")
    for root, _, files in os.walk(output_dir):
        for filename in files:
            if not filename.endswith(".md"):
                continue
            path = os.path.join(root, filename)
            with open(path, encoding="utf-8", errors="ignore") as fh:
                links.update(match.group(0).lower() for match in link_pattern.finditer(fh.read()))
    return links


def safe_slug(full_name):
    slug = full_name.replace("/", "-").lower()
    slug = re.sub(r"[^a-z0-9._-]+", "-", slug).strip("-")
    if not slug:
        raise ValueError(f"Could not create slug for {full_name}")
    return slug


def format_number(value):
    return f"{int(value):,}"


def date_only(value):
    if not value:
        return "Unknown"
    try:
        parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return value
    return parsed.date().isoformat()


def sentence(value):
    value = html.unescape((value or "").strip())
    if not value:
        return "No repository description is available from the GitHub API."
    if value[-1] not in ".!?":
        value += "."
    return value


def render_markdown(repo, today):
    topics = repo.get("topics") or []
    license_info = repo.get("license") or {}
    language = repo.get("language") or "Unknown"
    license_name = license_info.get("spdx_id") or license_info.get("name") or "Not specified"
    topics_text = ", ".join(topics) if topics else "None listed"
    description = sentence(repo.get("description"))
    pushed_at = date_only(repo.get("pushed_at"))
    updated_at = date_only(repo.get("updated_at"))

    lines = [
        f"# {repo['full_name']}",
        "",
        f"- Link: {repo['html_url']}",
        f"- Description: {description}",
        f"- Language: {language}",
        f"- Stars: {format_number(repo.get('stargazers_count', 0))}",
        f"- Forks: {format_number(repo.get('forks_count', 0))}",
        f"- Open issues: {format_number(repo.get('open_issues_count', 0))}",
        f"- License: {license_name}",
        f"- Topics: {topics_text}",
        f"- Last pushed: {pushed_at}",
        f"- Last updated: {updated_at}",
        "",
        "## What It Does",
        "",
        f"- {description}",
        f"- The project is primarily written in {language}.",
    ]

    if topics:
        lines.append(f"- GitHub topics place it around: {topics_text}.")
    else:
        lines.append("- GitHub does not list repository topics for this project.")

    lines.extend(
        [
            "",
            "## Why It Is Interesting",
            "",
            f"- It appeared in GitHub Trending for the {trending_period} period.",
            f"- It has {format_number(repo.get('stargazers_count', 0))} stars and {format_number(repo.get('forks_count', 0))} forks, which suggests active community interest.",
            f"- Generated on {today} UTC.",
            "",
        ]
    )
    return "\n".join(lines)


print(f"Fetching GitHub Trending ({trending_period})...")
try:
    trending_html = fetch_text(f"https://github.com/trending?since={trending_period}")
except (urllib.error.URLError, TimeoutError) as exc:
    raise SystemExit(f"Could not fetch GitHub Trending: {exc}")

repo_names = []
for full_name in re.findall(r'href="/([A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+)"', trending_html):
    if full_name not in repo_names:
        repo_names.append(full_name)
    if len(repo_names) >= trending_limit:
        break

if not repo_names:
    raise SystemExit("No trending repositories found.")

used_links = existing_repo_links()
selected = None
for full_name in repo_names:
    url = f"https://github.com/{full_name}"
    if url.lower() in used_links:
        continue

    try:
        repo = fetch_json(f"https://api.github.com/repos/{full_name}")
    except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError):
        continue

    if repo.get("html_url", url).lower() in used_links:
        continue

    selected = repo
    break

if selected is None:
    print("All current trending repositories already have markdown entries.")
    raise SystemExit(0)

slug = safe_slug(selected["full_name"])
target_file = os.path.join(output_dir, f"{today}-{slug}.md")
if os.path.exists(target_file):
    suffix = 2
    while os.path.exists(os.path.join(output_dir, f"{today}-{slug}-{suffix}.md")):
        suffix += 1
    target_file = os.path.join(output_dir, f"{today}-{slug}-{suffix}.md")

with open(target_file, "w", encoding="utf-8") as fh:
    fh.write(render_markdown(selected, today))

print(f"Wrote {target_file}")
PY
