#!/usr/bin/env bash
# Run locally: prepare the PR, merge it in GitHub, then run again with --tag.
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"
repo=jaruccky/devops-homework
branch=feature/infra-setup
tag=v0.1.0
mode=${1:-prepare}
if (( $# > 1 )) || [[ $mode != prepare && $mode != --tag ]]; then
    echo 'Usage: bash scripts/finalize.sh [--tag]' >&2
    exit 2
fi
for command_name in git gh python3; do
    command -v "$command_name" >/dev/null || { echo "Missing command: $command_name" >&2; exit 2; }
done
if [[ -n $(git status --porcelain) ]]; then
    echo 'Есть незакоммиченные изменения. Проверь git status.' >&2
    exit 1
fi

if [[ $mode == --tag ]]; then
    if [[ $(gh api "repos/$repo/pulls/1" --jq '.merged') != true ]]; then
        echo 'Сначала объедини PR #1 в GitHub, затем повтори запуск с --tag.' >&2
        exit 1
    fi
    if [[ $(gh api "repos/$repo/pulls/1" --jq '.head.sha') != $(git rev-parse "$branch") ]]; then
        echo 'PR содержит другую версию ветки. Проверь, что все изменения включены.' >&2
        exit 1
    fi
    merge_sha=$(gh api "repos/$repo/pulls/1" --jq '.merge_commit_sha')
    git fetch origin refs/heads/main:refs/remotes/origin/main --tags
    git merge-base --is-ancestor "$merge_sha" origin/main
    if git rev-parse --verify "refs/tags/$tag" >/dev/null 2>&1; then
        if [[ $(git rev-parse "$tag^{commit}") != "$merge_sha" ]]; then
            echo 'Тег v0.1.0 уже указывает на другой коммит. Проверь его вручную.' >&2
            exit 1
        fi
    else
        git tag -a "$tag" "$merge_sha" -m 'Container infrastructure v0.1.0'
    fi
    git push origin "refs/tags/$tag"
    echo "Готово: https://github.com/$repo/releases/tag/$tag"
    exit 0
fi

if [[ $(gh api "repos/$repo/pulls/1" --jq '.state') != open ]]; then
    echo 'PR #1 уже закрыт. Проверь GitHub перед отправкой изменений.' >&2
    exit 1
fi
git push origin "refs/heads/$branch:refs/heads/$branch"
head_sha=$(git rev-parse "$branch")
if [[ $(gh api "repos/$repo/pulls/1" --jq '.head.sha') != "$head_sha" ]]; then
    echo 'Вершина PR отличается от отправленной ветки. Проверь PR.' >&2
    exit 1
fi
payload=$(mktemp)
trap 'rm -f "$payload"' EXIT
git show "$branch:docs/merge-request.md" | python3 -c 'import json,sys; json.dump({"body":sys.stdin.read()},sys.stdout)' > "$payload"
gh api "repos/$repo/pulls/1" --method PATCH --input "$payload" --jq '.html_url'
if [[ $(gh api "repos/$repo/pulls/1" --jq '.draft') == true ]]; then
    gh pr ready 1 --repo "$repo"
fi
echo "PR готов для merge: https://github.com/$repo/pull/1"
echo 'После merge выполни: bash scripts/finalize.sh --tag'
