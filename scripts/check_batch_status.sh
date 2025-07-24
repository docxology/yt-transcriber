#!/bin/bash
# Script to check batch processing status for yt-transcriber
# Shows which videos from CSV already have transcripts vs which need processing

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CSV_FILE="$PROJECT_ROOT/data/videos/video_download.csv"
TRANSCRIPTS_DIR="$PROJECT_ROOT/data/transcripts"

# Function to extract YouTube video ID from URL
extract_video_id() {
    local url="$1"
    if [[ "$url" =~ v=([a-zA-Z0-9_-]+) ]] || \
       [[ "$url" =~ youtu\.be/([a-zA-Z0-9_-]+) ]] || \
       [[ "$url" =~ /live/([a-zA-Z0-9_-]+) ]] || \
       [[ "$url" =~ youtube\.com/live/([a-zA-Z0-9_-]+) ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo ""
    fi
}

# Function to check if transcript exists for video ID
transcript_exists() {
    local video_id="$1"
    # Check in all series directories
    if [[ -f "$TRANSCRIPTS_DIR/Livestream/${video_id}.txt" ]] || \
       [[ -f "$TRANSCRIPTS_DIR/GuestStream/${video_id}.txt" ]] || \
       [[ -f "$TRANSCRIPTS_DIR/ModelStream/${video_id}.txt" ]] || \
       [[ -f "$TRANSCRIPTS_DIR/MathStream/${video_id}.txt" ]] || \
       [[ -f "$TRANSCRIPTS_DIR/General/${video_id}.txt" ]]; then
        return 0
    else
        return 1
    fi
}

# Function to find transcript path for video ID
find_transcript_path() {
    local video_id="$1"
    local series_dirs=("Livestream" "GuestStream" "ModelStream" "MathStream" "General")
    
    for series in "${series_dirs[@]}"; do
        if [[ -f "$TRANSCRIPTS_DIR/${series}/${video_id}.txt" ]]; then
            echo "$TRANSCRIPTS_DIR/${series}/${video_id}.txt"
            return 0
        fi
    done
    echo ""
}

# Main execution function
main() {
    echo -e "${BLUE}=== YT-Transcriber Batch Processing Status ===${NC}"
    echo ""

    # Check if CSV file exists
    if [[ ! -f "$CSV_FILE" ]]; then
        echo -e "${RED}Error: CSV file not found at $CSV_FILE${NC}"
        exit 1
    fi

# Count totals
total_videos=$(tail -n +2 "$CSV_FILE" | wc -l)
existing_transcripts=0
missing_transcripts=0

# Arrays to store results
declare -a existing_list=()
declare -a missing_list=()

echo -e "${YELLOW}Analyzing $total_videos videos from CSV...${NC}"
echo ""

# Process each line in CSV - using python for proper CSV parsing
# Note: Variables modified inside pipe/subshell aren't visible outside, so we use a different approach
while IFS=$'\t' read -r unique_name series number date youtube_url guests title; do
    
    # Skip empty lines
    if [[ -z "$youtube_url" ]]; then
        continue
    fi
    
    # Extract video ID
    video_id=$(extract_video_id "$youtube_url")
    
    if [[ -z "$video_id" ]]; then
        echo -e "${RED}Warning: Could not extract video ID from: $youtube_url${NC}"
        continue
    fi
    
    # Check if transcript exists
    if transcript_exists "$video_id"; then
        existing_transcripts=$((existing_transcripts + 1))
        transcript_path=$(find_transcript_path "$video_id")
        existing_list+=("$unique_name | $video_id | $transcript_path")
    else
        missing_transcripts=$((missing_transcripts + 1))
        missing_list+=("$unique_name | $series | $video_id | $youtube_url")
    fi
    
done < <(python3 - "$CSV_FILE" <<'EOF'
import csv
import sys

csv_file = sys.argv[1]
with open(csv_file, 'r', encoding='utf-8') as f:
    reader = csv.reader(f)
    header = next(reader)  # Skip header
    for row in reader:
        if len(row) >= 5:  # Ensure we have at least 5 columns
            # Output tab-separated values to make parsing easier
            print('\t'.join(row))
EOF
)

# Display summary
echo -e "${GREEN}=== SUMMARY ===${NC}"
echo -e "Total videos in CSV: ${BLUE}$total_videos${NC}"
echo -e "Existing transcripts: ${GREEN}$existing_transcripts${NC}"
echo -e "Missing transcripts: ${RED}$missing_transcripts${NC}"
echo -e "Completion rate: ${YELLOW}$(( existing_transcripts * 100 / total_videos ))%${NC}"
echo ""

# Show existing transcripts
if [[ $existing_transcripts -gt 0 ]]; then
    echo -e "${GREEN}=== EXISTING TRANSCRIPTS ($existing_transcripts) ===${NC}"
    for item in "${existing_list[@]}"; do
        echo -e "${GREEN}✓${NC} $item"
    done
    echo ""
fi

# Show missing transcripts (first 10)
if [[ $missing_transcripts -gt 0 ]]; then
    echo -e "${RED}=== MISSING TRANSCRIPTS ($missing_transcripts) ===${NC}"
    echo -e "${YELLOW}(Showing first 10)${NC}"
    count=0
    for item in "${missing_list[@]}"; do
        if [[ $count -lt 10 ]]; then
            echo -e "${RED}✗${NC} $item"
            count=$((count + 1))
        else
            break
        fi
    done
    
    if [[ $missing_transcripts -gt 10 ]]; then
        echo -e "${YELLOW}... and $((missing_transcripts - 10)) more${NC}"
    fi
    echo ""
fi

echo -e "${BLUE}=== NEXT STEPS ===${NC}"
if [[ $missing_transcripts -gt 0 ]]; then
    echo "To process missing transcripts, run:"
    echo -e "${YELLOW}  ./scripts/batch_transcribe.sh${NC}"
    echo ""
    echo "To process a specific series, run:"
    echo -e "${YELLOW}  ./scripts/batch_transcribe.sh --series 'Livestream'${NC}"
    echo ""
    echo "To do a dry run first:"
    echo -e "${YELLOW}  ./scripts/batch_transcribe.sh --dry-run${NC}"
else
    echo -e "${GREEN}All videos have been transcribed! 🎉${NC}"
fi
}

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 