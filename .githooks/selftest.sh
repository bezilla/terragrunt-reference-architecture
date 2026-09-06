#!/usr/bin/env bash
#
# selftest: proves the pre-push gate rejects what it claims to reject, and --
# just as important -- accepts what it claims to accept.
#
# A gate nobody has watched fail is a gate nobody knows works, and a gate only
# ever watched to refuse could be one that refuses everything. Each case builds a
# throwaway repository, produces exactly one kind of history, and feeds the hook
# the same stdin git would feed it on a real push.
#
# Case 0 is not a test of the gate, it is a test of the arrangement: this
# repository enforces the same rule from two places -- .githooks/pre-push and the
# `identity` job in .github/workflows/validate.yml -- and they carry the same
# check_trailers function. Case 0 hashes it out of both and fails if they differ,
# so the local gate and the CI gate cannot drift apart silently.
#
# Every case captures the hook's status with `|| rc=$?` rather than running it
# bare and reading `$?`. CI runs steps under `bash -eo pipefail`, where a bare
# non-zero command kills the step before the assertion is reached.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$HERE/pre-push"
WORKFLOW="$HERE/../.github/workflows/validate.yml"
[ -x "$HOOK" ]      || { echo "selftest: $HOOK is not executable"; exit 1; }
[ -r "$WORKFLOW" ]  || { echo "selftest: $WORKFLOW is not readable"; exit 1; }

ZERO='0000000000000000000000000000000000000000'
CANON_NAME='Paul Bezilla'
CANON_EMAIL='bezilla@protonmail.com'
CANON="${CANON_NAME} <${CANON_EMAIL}>"

pass=0
fail=0
ok()  { printf '  \033[32mok\033[0m   %-58s rc=%s\n' "$1" "${2:-0}"; pass=$((pass + 1)); }
bad() { printf '  \033[31mFAIL\033[0m %-58s rc=%s\n' "$1" "${2:-?}"; fail=$((fail + 1)); }

new_repo() {
	local d
	d="$(mktemp -d)"
	git -C "$d" init -q -b main
	git -C "$d" config user.name  "$CANON_NAME"
	git -C "$d" config user.email "$CANON_EMAIL"
	git -C "$d" config tag.gpgSign false
	git -C "$d" config commit.gpgSign false
	printf 'clean\n' > "$d/README.md"
	git -C "$d" add -- README.md
	git -C "$d" commit -q -m 'Base commit'
	printf '%s' "$d"
}

commit_msg() {
	local d="$1" msg="$2"
	printf 'x %s\n' "$RANDOM" > "$d/file.txt"
	git -C "$d" add -- file.txt
	git -C "$d" commit -q -m "$msg"
}

run_hook() {
	local d="$1" base="$2" tip rc=0
	tip="$(git -C "$d" rev-parse HEAD)"
	( cd "$d" && printf 'refs/heads/main %s refs/heads/main %s\n' "$tip" "$base" \
		| "$HOOK" origin >/dev/null 2>&1 ) || rc=$?
	printf '%s' "$rc"
}

run_hook_tag() {
	local d="$1" tag="$2" obj rc=0
	obj="$(git -C "$d" rev-parse "refs/tags/${tag}")"
	( cd "$d" && printf 'refs/tags/%s %s refs/tags/%s %s\n' "$tag" "$obj" "$tag" "$ZERO" \
		| "$HOOK" origin >/dev/null 2>&1 ) || rc=$?
	printf '%s' "$rc"
}

# --- 0: the hook and the CI job carry the same rule ---------------------------
# The workflow copy lives inside a YAML block scalar, so it is indented by ten
# spaces. Dedent by exactly that, then compare byte for byte.
fn_hook="$(sed -n '/^check_trailers() {/,/^}/p' "$HOOK" | shasum -a 256 | cut -d' ' -f1)"
fn_ci="$(sed -n '/^          check_trailers() {/,/^          }$/p' "$WORKFLOW" | sed 's/^          //' | shasum -a 256 | cut -d' ' -f1)"
if [ -n "$fn_hook" ] && [ "$fn_hook" = "$fn_ci" ]; then
	ok 'check_trailers identical in hook and validate.yml' 0
else
	bad 'check_trailers has DRIFTED between hook and validate.yml' 1
fi

# --- 1: a clean commit is accepted --------------------------------------------
d="$(new_repo)"; base="$(git -C "$d" rev-parse HEAD)"
commit_msg "$d" 'Add a file'
rc="$(run_hook "$d" "$base")"
[ "$rc" = '0' ] && ok 'clean commit: accepted' "$rc" \
                || bad 'clean commit was REJECTED -- the gate blocks good history' "$rc"
rm -rf "$d"

# --- 2: wrong author ----------------------------------------------------------
d="$(new_repo)"; base="$(git -C "$d" rev-parse HEAD)"
printf 'x\n' > "$d/file.txt"; git -C "$d" add -- file.txt
GIT_AUTHOR_NAME='Somebody Else' GIT_AUTHOR_EMAIL='somebody@example.invalid' \
	git -C "$d" commit -q -m 'Wrong author'
rc="$(run_hook "$d" "$base")"
[ "$rc" != '0' ] && ok 'wrong author: rejected' "$rc" || bad 'wrong AUTHOR was accepted' "$rc"
rm -rf "$d"

# --- 3: wrong committer -------------------------------------------------------
d="$(new_repo)"; base="$(git -C "$d" rev-parse HEAD)"
printf 'x\n' > "$d/file.txt"; git -C "$d" add -- file.txt
GIT_COMMITTER_NAME='Some Service' GIT_COMMITTER_EMAIL='noreply@example.invalid' \
	git -C "$d" commit -q -m 'Wrong committer'
rc="$(run_hook "$d" "$base")"
[ "$rc" != '0' ] && ok 'wrong committer: rejected' "$rc" || bad 'wrong COMMITTER was accepted' "$rc"
rm -rf "$d"

# --- 4: a trailer key outside the allowlist -----------------------------------
d="$(new_repo)"; base="$(git -C "$d" rev-parse HEAD)"
commit_msg "$d" 'Add a file

Reviewed-by: Someone <someone@example.invalid>'
rc="$(run_hook "$d" "$base")"
[ "$rc" != '0' ] && ok 'disallowed trailer key: rejected' "$rc" \
                 || bad 'a trailer OUTSIDE the allowlist was accepted' "$rc"
rm -rf "$d"

# --- 5/6: Signed-off-by, both directions --------------------------------------
d="$(new_repo)"; base="$(git -C "$d" rev-parse HEAD)"
commit_msg "$d" "Add a file

Signed-off-by: ${CANON}"
rc="$(run_hook "$d" "$base")"
[ "$rc" = '0' ] && ok 'Signed-off-by, canonical identity: accepted' "$rc" \
                || bad 'the permitted sign-off was REJECTED' "$rc"
rm -rf "$d"

d="$(new_repo)"; base="$(git -C "$d" rev-parse HEAD)"
commit_msg "$d" 'Add a file

Signed-off-by: Someone Else <someone@example.invalid>'
rc="$(run_hook "$d" "$base")"
[ "$rc" != '0' ] && ok 'Signed-off-by, different identity: rejected' "$rc" \
                 || bad 'a sign-off naming somebody else was accepted' "$rc"
rm -rf "$d"

# --- 7/8: Verified and Measured take free text --------------------------------
d="$(new_repo)"; base="$(git -C "$d" rev-parse HEAD)"
commit_msg "$d" 'Add a file

Verified: tofu validate is clean across all stacks.'
rc="$(run_hook "$d" "$base")"
[ "$rc" = '0' ] && ok 'Verified, free text: accepted' "$rc" || bad 'Verified was REJECTED' "$rc"
rm -rf "$d"

d="$(new_repo)"; base="$(git -C "$d" rev-parse HEAD)"
commit_msg "$d" 'Add a file

Measured: 55 module unit tests, 11 policy tests, 0 failures.'
rc="$(run_hook "$d" "$base")"
[ "$rc" = '0' ] && ok 'Measured, free text: accepted' "$rc" || bad 'Measured was REJECTED' "$rc"
rm -rf "$d"

# --- 9: an unlisted evidence key ----------------------------------------------
d="$(new_repo)"; base="$(git -C "$d" rev-parse HEAD)"
commit_msg "$d" 'Add a file

Tested: every stack plans clean.'
rc="$(run_hook "$d" "$base")"
[ "$rc" != '0' ] && ok 'unlisted evidence key (Tested): rejected' "$rc" \
                 || bad 'an unlisted evidence key was accepted' "$rc"
rm -rf "$d"

# --- 10: a mid-message Key: Value line is not a trailer -----------------------
# This repository carries more of these than any other in the family: 18 distinct
# shapes across 36 commits -- docs:, chore:, ci:, test:, once:, zone:, cannot: --
# and not one is a trailer. A ^Key: regex would have rejected all of them.
d="$(new_repo)"; base="$(git -C "$d" rev-parse HEAD)"
commit_msg "$d" 'Add a file

docs: this line is not in the final paragraph.

So it is prose, and this paragraph is what makes it so.'
rc="$(run_hook "$d" "$base")"
[ "$rc" = '0' ] && ok 'mid-message Key: Value, not a trailer: accepted' "$rc" \
                || bad 'ordinary prose was treated as a trailer and REJECTED' "$rc"
rm -rf "$d"

# --- 11-13: annotated tags ----------------------------------------------------
d="$(new_repo)"
GIT_COMMITTER_NAME='Some Service' GIT_COMMITTER_EMAIL='noreply@example.invalid' \
	git -C "$d" tag -a v9.9.9 -m 'Release nine'
rc="$(run_hook_tag "$d" 'v9.9.9')"
[ "$rc" != '0' ] && ok 'annotated tag, wrong tagger: rejected' "$rc" \
                 || bad 'a tag tagged by somebody else was accepted' "$rc"
rm -rf "$d"

d="$(new_repo)"
git -C "$d" tag -a v1.0.0 -m 'Release one'
rc="$(run_hook_tag "$d" 'v1.0.0')"
[ "$rc" = '0' ] && ok 'annotated tag, canonical tagger: accepted' "$rc" \
                || bad 'a correctly tagged release was REJECTED' "$rc"
rm -rf "$d"

d="$(new_repo)"
git -C "$d" tag -a v2.0.0 -m 'Release two

Reviewed-by: Someone <someone@example.invalid>'
rc="$(run_hook_tag "$d" 'v2.0.0')"
[ "$rc" != '0' ] && ok 'disallowed trailer in a tag annotation: rejected' "$rc" \
                 || bad 'a tag annotation carried a disallowed trailer' "$rc"
rm -rf "$d"

printf '\n%d as expected, %d unexpected\n' "$pass" "$fail"
[ "$fail" -eq 0 ] || exit 1
