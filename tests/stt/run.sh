#!/usr/bin/env bash
# stt test suite. Requires: whisper-cli, ffmpeg, jq, and
# tests/fixtures/jfk.wav (whisper.cpp sample; fetched by `make fixtures`).
#
# Usage: tests/run.sh
# Uses the fast ggml-tiny.en model so the suite runs quickly; one end-to-end
# run at the bottom exercises the default (base.en) model.
#
# Note: tiny.en's transcript of jfk.wav omits the comma after "Americans",
# so tiny-model assertions use TINY_TEXT rather than the base.en output.

set -u
cd "$(dirname "$0")"/../..
STT=./stt.sh

FIXTURE=tests/stt/fixtures/jfk.wav
TINY="$HOME/.pi/agent/models/ggml-tiny.en.bin"
[ -f "$FIXTURE" ] || { echo "missing $FIXTURE — run: make fixtures" >&2; exit 1; }
[ -f "$TINY" ] || { echo "missing model $TINY" >&2; exit 1; }

# base.en (default model) output
BASE_TEXT="And so my fellow Americans, ask not what your country can do for you, ask what you can do for your country."
# tiny.en output (same words, no comma after "Americans")
TINY_TEXT="And so my fellow Americans ask not what your country can do for you, ask what you can do for your country."

pass=0 fail=0
t() { # t NAME EXPECTED_EXIT CMD...
	local name="$1" want="$2"; shift 2
	local out rc
	out=$("$@" 2>/dev/null); rc=$?
	if [ "$rc" = "$want" ]; then
		pass=$((pass + 1)); echo "ok   - $name"
	else
		fail=$((fail + 1)); echo "FAIL - $name (exit $rc, want $want)"; echo "  got: $out"
	fi
}
expect() { # expect NAME WANT GOT
	local name="$1" want="$2" got="$3"
	if [ "$got" = "$want" ]; then
		pass=$((pass + 1)); echo "ok   - $name"
	else
		fail=$((fail + 1)); echo "FAIL - $name"; echo "  want: $want"; echo "  got:  $got"
	fi
}

# --- transcription (tiny.en for speed) --------------------------------------
t "transcribe file (tiny.en)"   0 $STT -m "$TINY" "$FIXTURE"
t "transcribe stdin pcm"        0 bash -c "ffmpeg -v error -i $FIXTURE -ar 16000 -ac 1 -f s16le - 2>/dev/null | $STT -m $TINY -"
t "missing file errors"         1 $STT -m "$TINY" /nonexistent.wav
t "missing model errors"        1 $STT -m /nope.bin "$FIXTURE"
t "bad flag prints usage"       1 $STT --bogus

# --- stdout purity & json ----------------------------------------------------
out=$($STT -m "$TINY" "$FIXTURE" 2>/dev/null)
expect "stdout is clean transcript (no leading space)" "$TINY_TEXT" "$out"

js=$($STT -m "$TINY" --json "$FIXTURE")
expect "json parses" "$TINY_TEXT" "$(printf '%s' "$js" | jq -r .text)"
expect "json audio_seconds" 11 "$(printf '%s' "$js" | jq -r .audio_seconds)"
expect "json stopped false" 0 "$(printf '%s' "$js" | jq -r .stopped)"
expect "json has rt_factor" true "$(printf '%s' "$js" | jq 'has("rt_factor")')"

# --- stop words --------------------------------------------------------------
out=$($STT -m "$TINY" -w fellow "$FIXTURE"); rc=$?
expect "stop word truncates" "And so my" "$out"
expect "stop word exit code" "10" "$rc"

out=$($STT -m "$TINY" -w "fellow Americans, ask" "$FIXTURE"); rc=$?
expect "stop phrase truncates" "And so my" "$out"
expect "stop phrase exit code" "10" "$rc"

out=$($STT -m "$TINY" -w "" "$FIXTURE"); rc=$?
expect "empty -w disables stop words" "$TINY_TEXT" "$out"
expect "no stop word exit 0" "0" "$rc"

out=$($STT -m "$TINY" -w zzz "$FIXTURE"); rc=$?
expect "unmatched stop word is passthrough" "$TINY_TEXT" "$out"
expect "unmatched stop word exit 0" "0" "$rc"

out=$($STT -m "$TINY" -w "and" "$FIXTURE"); rc=$?
expect "stop word at start empties text" "" "$out"
expect "stop word at start still exit 10" "10" "$rc"

js=$($STT -m "$TINY" -w fellow --json "$FIXTURE")
expect "json stopped true" 1 "$(printf '%s' "$js" | jq -r .stopped)"

# --- -o and --list-models -----------------------------------------------------
tmp=$(mktemp)
$STT -m "$TINY" -o "$tmp" "$FIXTURE"
expect "-o writes file" "$TINY_TEXT" "$(cat "$tmp")"
rm -f "$tmp"

t "--list-models exits 0" 0 $STT --list-models

# --- config file --------------------------------------------------------------
cfg=$(mktemp)
printf 'model: %s\nstop_words: country\ncase: keep\n' "$TINY" > "$cfg"
out=$(STT_CONFIG="$cfg" $STT "$FIXTURE"); rc=$?
expect "config model + stop_words honored" "And so my fellow Americans ask not what your" "$out"
expect "config stop word exit code" "10" "$rc"
rm -f "$cfg"

# --- default model end-to-end (slower: ggml-base.en) --------------------------
out=$($STT "$FIXTURE" 2>/dev/null)
expect "default model transcript (base.en)" "$BASE_TEXT" "$out"

echo
echo "$pass passed, $fail failed"
[ "$fail" = 0 ]