#!/usr/bin/env bash
# stt — one-shot speech-to-text CLI.
#
# Usage:
#   stt [FILE|-]      transcribe a file (wav/mp3/flac/ogg) or stdin PCM (16k mono
#                     s16le, "-"); with no argument, record from the mic (arecord)
#                     until Enter is pressed. While recording, a live partial
#                     transcript is shown on stderr.
#
# Options:
#   -m MODEL          model path (default from config or ggml-base.en)
#   -o FILE           write transcript to FILE instead of stdout
#   -w WORDS          stop words, comma-separated; transcript is truncated at the
#                     first occurrence. Empty string disables. Default from config.
#   --json            output JSON: {text, elapsed, audio_seconds, rt_factor, stopped}
#   --list-models     list models in the model directory and exit
#
# Config (first match wins): $STT_CONFIG, ~/.config/stt/config.yaml, defaults.
# Flat YAML only:   model: path    backend: cmd with {model} and {file}    stop_words: a, b    case: sentence|keep
# Env: STT_PARTIAL_INTERVAL (seconds between partials, default 2)
#
# stdout carries ONLY the transcript. Diagnostics go to stderr.
# Exit codes: 0 ok, 1 usage/error, 2 no speech detected, 10 stop word hit.

set -u

die()  { echo "stt: $*" >&2; exit 1; }
info() { echo "stt: $*" >&2; }

usage() {
	sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
	exit 1
}

# strindex: print 1-based index of $1 within stdin, or exit 1.
strindex() {
	local needle="$1" hay i=1
	hay=$(cat)
	while [ -n "$hay" ]; do
		case "$hay" in
			"$needle"*) printf '%s' "$i"; return 0 ;;
		esac
		hay="${hay#?}"
		i=$((i + 1))
	done
	return 1
}

# --- config ---------------------------------------------------------------

CONFIG_FILE="${STT_CONFIG:-$HOME/.config/stt/config.yaml}"

# shellcheck disable=SC2034
CFG_MODEL="" CFG_BACKEND="" CFG_STOP_WORDS="" CFG_CASE=""
if [ -f "$CONFIG_FILE" ]; then
	while IFS= read -r line; do
		case "$line" in
			\#*|"") continue ;;
		esac
		key="${line%%:*}"
		val="${line#*:}"
		val="${val#"${val%%[![:space:]]*}"}"   # ltrim
		val="${val%"${val##*[![:space:]]}"}"   # rtrim
		val="${val%\"}" val="${val#\"}"
		case "$key" in
			model)      CFG_MODEL="$val" ;;
			backend)    CFG_BACKEND="$val" ;;
			stop_words) CFG_STOP_WORDS="$val" ;;
			case)       CFG_CASE="$val" ;;
		esac
	done < "$CONFIG_FILE"
fi

# --- defaults -------------------------------------------------------------

MODEL_DIR="$HOME/.pi/agent/models"
DEFAULT_BACKEND="whisper-cli -m {model} -nt {file}"
DEF_MODEL="$MODEL_DIR/ggml-base.en.bin"

MODEL="${CFG_MODEL:-$DEF_MODEL}"
BACKEND="${CFG_BACKEND:-$DEFAULT_BACKEND}"
STOP_WORDS="${CFG_STOP_WORDS-peacock}"   # config may set empty to disable
CASE_MODE="${CFG_CASE:-sentence}"

JSON=0
OPT_OUTPUT=""
SRC=""

while [ $# -gt 0 ]; do
	case "$1" in
		-m) MODEL="${2:?}"; shift 2 ;;
		-m*) MODEL="${1#-m}"; shift ;;
		-o) OPT_OUTPUT="${2:?}"; shift 2 ;;
		-w) STOP_WORDS="${2-}"; shift 2 ;;
		-w*) STOP_WORDS="${1#-w}"; shift ;;
		--json) JSON=1; shift ;;
		--list-models)
			ls -1 "$MODEL_DIR"/ggml-*.bin 2>/dev/null || info "no models in $MODEL_DIR"
			exit 0 ;;
		-h|--help) usage ;;
		--) shift; SRC="${1:-}"; [ $# -gt 0 ] && shift; break ;;
		-) SRC="-"; shift ;;
		-*) usage ;;
		*) SRC="$1"; shift ;;
	esac
done
[ "${1:-}" ] && usage

[ -x "$(command -v "${BACKEND%% *}")" ] || die "backend '${BACKEND%% *}' not found on PATH"
# Resolve {model} once; {file} is substituted per capture.
MODEL_ABS=${MODEL/#\~/$HOME}
[ -f "$MODEL_ABS" ] || die "model not found: $MODEL_ABS (see --list-models)"

# --- capture --------------------------------------------------------------

T_START=$(date +%s)
PARTIAL_INTERVAL=${STT_PARTIAL_INTERVAL:-2}   # seconds between partial transcriptions
LAST_PARTIAL=""

# show_partial: transcribe the raw PCM captured so far ($1) and print the
# result as a single updating line on stderr. Skips very short captures and
# runs that yield no text; harmless if the file is mid-write (WAV header is
# regenerated from current size each time).
show_partial() {
	local pcm="$1" size
	size=$(stat -c %s "$pcm" 2>/dev/null) || return 0
	[ "$size" -lt 32000 ] && return 0   # < 1s of audio: too little to bother
	local wav
	wav=$(mktemp --suffix=.wav)
	pcm_to_wav "$pcm" > "$wav"
	local raw cmd
	cmd=${BACKEND//\{model\}/$MODEL_ABS}
	cmd=${cmd//\{file\}/$wav}
	raw=$($cmd 2>/dev/null < /dev/null) || { rm -f "$wav"; return 0; }
	rm -f "$wav"
	local text
	text=$(clean_text "$raw")
	[ -z "$text" ] && return 0
	[ "$text" = "$LAST_PARTIAL" ] && return 0
	LAST_PARTIAL="$text"
	printf '\r\033[K%s' "$text" >&2
}

# clean_text: join whisper-cli's segment lines into one trimmed string.
clean_text() {
	printf '%s\n' "$1" | tr '\n' ' ' | sed 's/  */ /g' | sed 's/^ *//; s/ *$//'
}

# capture_wav: sets globals WAV and AUDIO_SECONDS.
capture_wav() {
	local tmp
	tmp=$(mktemp --suffix=.wav)
	if [ "$SRC" = "-" ]; then
		cat > "$tmp.pcm"
		pcm_to_wav "$tmp.pcm" > "$tmp"
		rm -f "$tmp.pcm"
	elif [ -n "$SRC" ]; then
		case "$SRC" in
			*.wav) cp -- "$SRC" "$tmp" ;;
			*) ffmpeg -v error -i "$SRC" -ar 16000 -ac 1 -f wav - > "$tmp" ;;
		esac
	else
		info "recording... press Enter to stop"
		# arecord to raw PCM in the background so partials can read the file as it grows
		arecord -q -r 16000 -c 1 -f S16_LE -t raw "$tmp.pcm" &
		local pid=$!
		# stop watching when arecord exits OR Enter is hit (racer determines which)
		read -r _ < /dev/tty &
		local reader=$!
		while kill -0 "$pid" 2>/dev/null && kill -0 "$reader" 2>/dev/null; do
			sleep "$PARTIAL_INTERVAL"
			show_partial "$tmp.pcm"
		done
		kill "$reader" 2>/dev/null
		wait "$reader" 2>/dev/null
		kill -INT "$pid" 2>/dev/null
		wait "$pid" 2>/dev/null
		echo >&2   # move past the partial line
		pcm_to_wav "$tmp.pcm" > "$tmp"
		rm -f "$tmp.pcm"
	fi
	local bytes
	bytes=$(stat -c %s "$tmp")
	AUDIO_SECONDS=$(( (bytes - 44) / 32000 ))   # 16000 Hz * 2 bytes
	WAV="$tmp"
}

# pcm_to_wav: wrap raw s16le PCM from $1 into a minimal WAV on stdout.
pcm_to_wav() {
	local pcm="$1" hdr
	hdr=$(mktemp)
	local size
	size=$(stat -c %s "$pcm")
	{
		printf 'RIFF'
		printf "\\$(printf '%03o' $(( (size + 36) % 256 )))\\$(printf '%03o' $(( (size + 36) / 256 % 256 )))\\$(printf '%03o' $(( (size + 36) / 65536 % 256 )))\\$(printf '%03o' $(( (size + 36) / 16777216 )))"
		printf 'WAVEfmt '
		printf '\x10\x00\x00\x00\x01\x00\x01\x00'
		printf '\x80\x3e\x00\x00\x00\x7d\x00\x00\x02\x00\x10\x00'
		printf 'data'
		printf "\\$(printf '%03o' $(( size % 256 )))\\$(printf '%03o' $(( size / 256 % 256 )))\\$(printf '%03o' $(( size / 65536 % 256 )))\\$(printf '%03o' $(( size / 16777216 )))"
	} > "$hdr"
	cat "$hdr" "$pcm"
	rm -f "$hdr"
}

# --- transcribe -----------------------------------------------------------

capture_wav
trap 'rm -f "$WAV"' EXIT
[ -s "$WAV" ] || die "no audio captured"

BACKEND_CMD=${BACKEND//\{model\}/$MODEL_ABS}
BACKEND_CMD=${BACKEND_CMD//\{file\}/$WAV}

RAW=$($BACKEND_CMD 2>/dev/null) || die "backend failed (exit $?)"
TEXT=$(clean_text "$RAW")

[ -z "$TEXT" ] && exit 2

# --- stop words -----------------------------------------------------------

STOPPED=0
if [ -n "$STOP_WORDS" ]; then
	IFS=',' read -r -a words <<< "$STOP_WORDS"
	lc=$(printf '%s' "$TEXT" | tr '[:upper:]' '[:lower:]')
	for w in "${words[@]}"; do
		w=$(printf '%s' "$w" | sed 's/^ *//; s/ *$//' | tr '[:upper:]' '[:lower:]')
		[ -z "$w" ] && continue
		if idx=$(printf '%s' "$lc" | strindex "$w"); then
			if [ "$idx" -gt 1 ]; then
				TEXT=$(printf '%s' "$TEXT" | cut -c1-$((idx - 1)) | sed 's/ *$//')
			else
				TEXT=""
			fi
			STOPPED=1
			break
		fi
	done
fi
unset IFS

# --- output ---------------------------------------------------------------

T_END=$(date +%s)
ELAPSED=$((T_END - T_START))
if [ "$AUDIO_SECONDS" -gt 0 ] && [ "$ELAPSED" -gt 0 ]; then
	RT=$(awk "BEGIN{printf \"%.2f\", $AUDIO_SECONDS / $ELAPSED}")
else
	RT="n/a"
fi

if [ "$JSON" = 1 ]; then
	jq -n --arg t "$TEXT" --argjson e "$ELAPSED" --argjson a "$AUDIO_SECONDS" \
		--arg r "$RT" --argjson s "$STOPPED" \
		'{text: $t, elapsed: $e, audio_seconds: $a, rt_factor: $r, stopped: $s}'
elif [ -n "$OPT_OUTPUT" ]; then
	printf '%s\n' "$TEXT" > "$OPT_OUTPUT"
else
	printf '%s\n' "$TEXT"
fi

[ "$STOPPED" = 1 ] && exit 10
exit 0
