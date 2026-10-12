#!/bin/bash
#
# YouTube Video Downloader
# Downloads videos from JSON file at 360p with audio
#
# Usage: ./youtube_dl.sh <input_json_file> [output_directory]
#
# If output_directory is not specified, downloads to the current directory.
#
# Example input JSON (links.json):
# {
#   "deep_dive_llms_chatgpt": "www.youtube.com/watch?v=VIDEO_ID",
#   "how_i_use_llms": "www.youtube.com/watch?v=VIDEO_ID"
# }
#
# The script targets 360p video with the best available audio quality.

set -e  # Exit on error

# Check if yt-dlp is installed
if ! command -v yt-dlp &> /dev/null; then
    echo -e "\033[0;31mError: yt-dlp is not installed. Please install it first.\033[0m"
    exit 1
fi

# Check if jq is installed (needed for JSON parsing)
if ! command -v jq &> /dev/null; then
    echo -e "\033[0;31mError: jq is not installed. Please install it first.\033[0m"
    exit 1
fi

# Check if input file argument is provided
if [[ $# -lt 1 ]]; then
    echo -e "\033[0;31mError: Input JSON file is required.\033[0m"
    echo
    cat << EOF
Usage: $0 <input_json_file> [output_directory]

Download YouTube videos from JSON file in 360p with audio.

Arguments:
  input_json_file    Path to JSON file with video names and URLs
  output_directory   Directory to save videos (default: current directory)

Example input JSON:
  {
    "deep_dive_llms_chatgpt": "www.youtube.com/watch?v=7xTGNNLPyMI",
    "how_i_use_llms": "www.youtube.com/watch?v=EWvNQjAaOHw"
  }

Examples:
  $0 links.json                          # Download to current directory
  $0 links.json /path/to/videos          # Download to specified directory

Environment variables:
  YT_DLP_FORMAT           Override the default format (default: "best[height<=360][ext=mp4]")
  YT_DLP_DEBUG            Set to "true" to enable debug mode

EOF
    exit 1
fi

INPUT_FILE="$1"
OUTPUT_DIR="${2:-.}"

# Validate input file exists
if [[ ! -f "$INPUT_FILE" ]]; then
    echo -e "\033[0;31mError: Input file '$INPUT_FILE' not found.\033[0m"
    exit 1
fi

# Validate JSON is valid
if ! jq empty "$INPUT_FILE" 2>/dev/null; then
    echo -e "\033[0;31mError: Invalid JSON in '$INPUT_FILE'.\033[0m"
    exit 1
fi

# Count total videos (number of keys in the object)
TOTAL_VIDEOS=$(jq 'keys | length' "$INPUT_FILE")

# Enable color output
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# Debug mode
DEBUG_MODE="${YT_DLP_DEBUG:-false}"

# Print header
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  YouTube Downloader - 360p with Audio${NC}"
echo -e "${BLUE}============================================${NC}"
echo
echo -e "${YELLOW}Source: ${INPUT_FILE}${NC}"
echo -e "${YELLOW}Output: ${OUTPUT_DIR}/${NC}"
echo -e "${GREEN}Total videos: ${TOTAL_VIDEOS}${NC}"
echo

# Format selector: Best quality up to 360p, preferring MP4
# This finds formats that include both video and audio
DEFAULT_FORMAT="best[height<=360][ext=mp4]"
OVERRIDE_FORMAT="${YT_DLP_FORMAT:-$DEFAULT_FORMAT}"

# Create status file for tracking
STATUS_FILE="/tmp/download_status_$$"
> "$STATUS_FILE"  # Clear/create file

# Process each video - iterate over object keys
for video_name in $(jq -r 'keys[]' "$INPUT_FILE"); do
    url=$(jq -r --arg name "$video_name" '.[$name]' "$INPUT_FILE")
    
    # Clean up URL (add https:// if missing)
    if [[ ! "$url" =~ ^https?:// ]]; then
        url="https://$url"
    fi
    
    # Get the video title (fallback to input name if title fails)
    title=$(yt-dlp -q --get-title "$url" 2>/dev/null || echo "$video_name")
    
    # Clean video name for filename (replace special chars, spaces with underscores)
    safe_name=$(echo "$video_name" | tr -c '[:alnum:]' '_' | sed 's/^_//;s/_$//')
    output_file="${OUTPUT_DIR}/${safe_name}.mp4"
    
    echo
    echo -e "${GREEN}📥 Downloading: ${video_name}${NC}"
    echo -e "   Title: ${title}"
    echo -e "   Output: ${output_file}"
    echo -e "   Format: ${OVERRIDE_FORMAT}"
    
    if [[ "$DEBUG_MODE" == "true" ]]; then
        echo -e "   🔍 Listing available formats..."
        yt-dlp -Q --simulate --list-formats "$url" 2>/dev/null | grep -E "^(ID|134|243|396|135|244|397|18|best)" || true
    fi
    
    # Download the video
    yt-dlp \
        -f "$OVERRIDE_FORMAT" \
        --skip-unavailable-fragments \
        --merge-output-format mp4 \
        -o "$output_file" \
        "$url" 2>&1
    
    # Check if download succeeded
    if [[ $? -eq 0 ]]; then
        file_size=$(du -h "$output_file" 2>/dev/null | cut -f1)
        echo -e "${GREEN}✅ Download complete: ${file_size}${NC}"
        echo "SUCCESS: $video_name" >> "$STATUS_FILE"
    else
        echo -e "${RED}❌ Download failed for: ${video_name}${NC}"
        echo "FAILED: $video_name" >> "$STATUS_FILE"
        echo
        echo -e "${RED}============================================${NC}"
    fi
    
    # Wait between downloads to be nice to the server
    sleep 2
done

# Get final counts
SUCCESS=$(grep -c "^SUCCESS:" "$STATUS_FILE" 2>/dev/null | head -1 || echo 0)
FAILED=$(grep -c "^FAILED:" "$STATUS_FILE" 2>/dev/null | head -1 || echo 0)
rm -f "$STATUS_FILE"

echo
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Download Summary${NC}"
echo -e "${BLUE}============================================${NC}"
echo
echo -e "${GREEN}Successful: ${SUCCESS}/${TOTAL_VIDEOS}${NC}"
if [[ $FAILED -gt 0 ]]; then
    echo -e "${RED}Failed: ${FAILED}/${TOTAL_VIDEOS}${NC}"
else
    echo -e "${GREEN}No failures!${NC}"
fi
echo
echo -e "${YELLOW}Files saved to: ${OUTPUT_DIR}/${NC}"
