#!/bin/bash

# Batch Transcription Script for YT-Transcriber
# Processes all videos from video_download.csv with intelligent caching

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CSV_FILE="$PROJECT_ROOT/data/videos/video_download.csv"
TRANSCRIPTS_DIR="$PROJECT_ROOT/data/transcripts"
METADATA_DIR="$PROJECT_ROOT/data/videos/metadata"
REPORTS_DIR="$PROJECT_ROOT/output/reports"
CACHE_DIR="$PROJECT_ROOT/cache"
YT_TRANSCRIBER="$PROJECT_ROOT/core/yt-transcriber"

# Status tracking
STATUS_FILE="$PROJECT_ROOT/cache/transcription_status.json"
PROGRESS_FILE="$PROJECT_ROOT/cache/batch_progress.log"

# Default settings
DEFAULT_MODEL="small"
MAX_PARALLEL_JOBS=3
RESUME_FROM=""
SERIES_FILTER=""
DATE_FILTER=""
DRY_RUN=false
FORCE_REPROCESS=false

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$PROGRESS_FILE"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$PROGRESS_FILE"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$PROGRESS_FILE"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$PROGRESS_FILE"
}

print_progress() {
    echo -e "${CYAN}[PROGRESS]${NC} $1" | tee -a "$PROGRESS_FILE"
}

# Function to show help
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Batch transcribe all videos from the video_download.csv file.

Options:
    -h, --help              Show this help message
    -m, --model MODEL       Whisper model to use (default: $DEFAULT_MODEL)
    -j, --jobs NUM          Maximum parallel jobs (default: $MAX_PARALLEL_JOBS)
    -r, --resume-from ID    Resume from specific video ID
    -s, --series SERIES     Only process videos from specific series
    -d, --date-from DATE    Only process videos from date onwards (YYYY-MM-DD)
    -n, --dry-run           Show what would be processed without doing it
    -f, --force             Force reprocess existing transcripts
    --status                Show current processing status
    --clean                 Clean cache and temporary files

Examples:
    $0                                  # Process all videos
    $0 -s "Livestream"                 # Only process Livestream videos
    $0 -d "2023-01-01"                 # Only process videos from 2023 onwards
    $0 -r "Livestream #025.0"          # Resume from specific video
    $0 -n -s "GuestStream"             # Dry run for GuestStream videos
    $0 --force -s "MathStream"         # Force reprocess MathStream videos

EOF
}

# Function to sanitize filename
sanitize_filename() {
    local filename="$1"
    # Remove/replace problematic characters
    filename=$(echo "$filename" | sed 's/[^a-zA-Z0-9._-]/_/g')
    # Remove multiple underscores
    filename=$(echo "$filename" | sed 's/__*/_/g')
    # Trim underscores from start/end
    filename=$(echo "$filename" | sed 's/^_*//; s/_*$//')
    # Limit length
    echo "${filename:0:100}"
}

# Function to create directory structure for series
create_series_dir() {
    local series="$1"
    local series_dir="$TRANSCRIPTS_DIR/$series"
    mkdir -p "$series_dir"
    echo "$series_dir"
}

# Function to generate transcript filename
generate_transcript_filename() {
    local series="$1"
    local number="$2"
    local title="$3"
    local unique_name="$4"
    
    # Use unique name if available, otherwise construct from series/number/title
    if [[ -n "$unique_name" && "$unique_name" != "$series" ]]; then
        local base_name=$(sanitize_filename "$unique_name")
    else
        local sanitized_title=$(sanitize_filename "$title")
        local base_name="${series}_${number}_${sanitized_title}"
        base_name=$(sanitize_filename "$base_name")
    fi
    
    echo "${base_name}.txt"
}

# Function to check if transcript exists
transcript_exists() {
    local transcript_path="$1"
    [[ -f "$transcript_path" ]]
}

# Function to extract video ID from YouTube URL
extract_video_id() {
    local url="$1"
    if [[ "$url" =~ v=([a-zA-Z0-9_-]+) ]] || [[ "$url" =~ youtu\.be/([a-zA-Z0-9_-]+) ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo ""
    fi
}

# Function to update status tracking
update_status() {
    local video_id="$1"
    local status="$2"
    local transcript_path="$3"
    local timestamp=$(date -Iseconds)
    
    # Create status file if it doesn't exist
    if [[ ! -f "$STATUS_FILE" ]]; then
        echo "{}" > "$STATUS_FILE"
    fi
    
    # Update status using jq
    jq --arg id "$video_id" \
       --arg status "$status" \
       --arg path "$transcript_path" \
       --arg timestamp "$timestamp" \
       '.[$id] = {status: $status, transcript_path: $path, last_updated: $timestamp}' \
       "$STATUS_FILE" > "${STATUS_FILE}.tmp" && mv "${STATUS_FILE}.tmp" "$STATUS_FILE"
}

# Function to get status
get_status() {
    local video_id="$1"
    if [[ -f "$STATUS_FILE" ]]; then
        jq -r --arg id "$video_id" '.[$id].status // "pending"' "$STATUS_FILE"
    else
        echo "pending"
    fi
}

# Function to process a single video
process_video() {
    local unique_name="$1"
    local series="$2"
    local number="$3"
    local date="$4"
    local youtube_url="$5"
    local guests="$6"
    local title="$7"
    
    # Extract video ID for tracking
    local video_id=$(extract_video_id "$youtube_url")
    if [[ -z "$video_id" ]]; then
        print_error "Could not extract video ID from URL: $youtube_url"
        return 1
    fi
    
    # Create series directory
    local series_dir=$(create_series_dir "$series")
    
    # Generate transcript filename
    local transcript_filename=$(generate_transcript_filename "$series" "$number" "$title" "$unique_name")
    local transcript_path="$series_dir/$transcript_filename"
    
    print_progress "Processing: $unique_name"
    print_status "  Series: $series | Number: $number | Date: $date"
    print_status "  URL: $youtube_url"
    print_status "  Output: $transcript_path"
    
    # Check if transcript already exists and we're not forcing reprocess
    if transcript_exists "$transcript_path" && [[ "$FORCE_REPROCESS" == "false" ]]; then
        print_success "  Transcript already exists, skipping"
        update_status "$video_id" "completed" "$transcript_path"
        return 0
    fi
    
    # Check current status
    local current_status=$(get_status "$video_id")
    if [[ "$current_status" == "processing" ]]; then
        print_warning "  Video appears to be currently processing, skipping"
        return 0
    fi
    
    # Dry run mode
    if [[ "$DRY_RUN" == "true" ]]; then
        print_status "  [DRY RUN] Would transcribe to: $transcript_path"
        return 0
    fi
    
    # Update status to processing
    update_status "$video_id" "processing" "$transcript_path"
    
    # Create metadata header
    local metadata_header=$(cat << EOF
=== Video Metadata ===
Title: $title
Series: $series
Number: $number
Date: $date
Guests: $guests
URL: $youtube_url
Unique Name: $unique_name
Transcribed: $(date -Iseconds)
=== Transcript ===

EOF
)
    
    # Run transcription
    print_status "  Starting transcription..."
    if echo "$metadata_header" > "$transcript_path" && \
       bash "$YT_TRANSCRIBER" -m "$DEFAULT_MODEL" "$youtube_url" >> "$transcript_path" 2>/dev/null; then
        print_success "  Transcription completed successfully"
        update_status "$video_id" "completed" "$transcript_path"
        
        # Save individual metadata file
        local metadata_file="$METADATA_DIR/${video_id}.json"
        jq -n --arg unique_name "$unique_name" \
              --arg series "$series" \
              --arg number "$number" \
              --arg date "$date" \
              --arg youtube_url "$youtube_url" \
              --arg guests "$guests" \
              --arg title "$title" \
              --arg transcript_path "$transcript_path" \
              --arg transcribed "$(date -Iseconds)" \
              '{
                unique_name: $unique_name,
                series: $series,
                number: $number,
                date: $date,
                youtube_url: $youtube_url,
                guests: $guests,
                title: $title,
                transcript_path: $transcript_path,
                transcribed: $transcribed
              }' > "$metadata_file"
        
        return 0
    else
        print_error "  Transcription failed"
        update_status "$video_id" "error" "$transcript_path"
        rm -f "$transcript_path"  # Remove partial file
        return 1
    fi
}

# Function to show processing status
show_status() {
    if [[ ! -f "$STATUS_FILE" ]]; then
        print_status "No processing status file found"
        return
    fi
    
    local total_videos=$(jq 'length' "$STATUS_FILE")
    local completed=$(jq '[.[] | select(.status == "completed")] | length' "$STATUS_FILE")
    local processing=$(jq '[.[] | select(.status == "processing")] | length' "$STATUS_FILE")
    local errors=$(jq '[.[] | select(.status == "error")] | length' "$STATUS_FILE")
    local pending=$(($(wc -l < "$CSV_FILE") - 1 - total_videos))  # Subtract header
    
    echo
    print_status "=== Processing Status ==="
    print_success "Completed: $completed"
    print_warning "Processing: $processing"
    print_error "Errors: $errors"
    print_status "Pending: $pending"
    print_status "Total: $((completed + processing + errors + pending))"
    echo
    
    if [[ $errors -gt 0 ]]; then
        print_error "Videos with errors:"
        jq -r 'to_entries[] | select(.value.status == "error") | "  " + .key' "$STATUS_FILE"
        echo
    fi
}

# Function to clean cache
clean_cache() {
    print_status "Cleaning cache and temporary files..."
    rm -rf "$CACHE_DIR"/*
    rm -f "$STATUS_FILE" "$PROGRESS_FILE"
    print_success "Cache cleaned"
}

# Function to generate summary report
generate_report() {
    local report_file="$REPORTS_DIR/batch_transcription_$(date +%Y%m%d_%H%M%S).md"
    mkdir -p "$REPORTS_DIR"
    
    cat > "$report_file" << EOF
# Batch Transcription Report

Generated: $(date -Iseconds)

## Summary

EOF
    
    if [[ -f "$STATUS_FILE" ]]; then
        local total=$(jq 'length' "$STATUS_FILE")
        local completed=$(jq '[.[] | select(.status == "completed")] | length' "$STATUS_FILE")
        local errors=$(jq '[.[] | select(.status == "error")] | length' "$STATUS_FILE")
        
        cat >> "$report_file" << EOF
- Total processed: $total
- Successfully completed: $completed
- Errors: $errors
- Success rate: $(( completed * 100 / total ))%

## Completed Transcriptions

EOF
        
        jq -r 'to_entries[] | select(.value.status == "completed") | "- " + .key + " -> " + .value.transcript_path' "$STATUS_FILE" >> "$report_file"
        
        if [[ $errors -gt 0 ]]; then
            cat >> "$report_file" << EOF

## Failed Transcriptions

EOF
            jq -r 'to_entries[] | select(.value.status == "error") | "- " + .key' "$STATUS_FILE" >> "$report_file"
        fi
    fi
    
    print_success "Report generated: $report_file"
}

# Main processing function
main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -m|--model)
                DEFAULT_MODEL="$2"
                shift 2
                ;;
            -j|--jobs)
                MAX_PARALLEL_JOBS="$2"
                shift 2
                ;;
            -r|--resume-from)
                RESUME_FROM="$2"
                shift 2
                ;;
            -s|--series)
                SERIES_FILTER="$2"
                shift 2
                ;;
            -d|--date-from)
                DATE_FILTER="$2"
                shift 2
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -f|--force)
                FORCE_REPROCESS=true
                shift
                ;;
            --status)
                show_status
                exit 0
                ;;
            --clean)
                clean_cache
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Initialize
    mkdir -p "$METADATA_DIR" "$REPORTS_DIR" "$CACHE_DIR"
    
    # Check if CSV file exists
    if [[ ! -f "$CSV_FILE" ]]; then
        print_error "CSV file not found: $CSV_FILE"
        exit 1
    fi
    
    # Check if yt-transcriber exists and is executable
    if [[ ! -x "$YT_TRANSCRIBER" ]]; then
        print_error "yt-transcriber not found or not executable: $YT_TRANSCRIBER"
        exit 1
    fi
    
    print_status "Starting batch transcription..."
    print_status "Model: $DEFAULT_MODEL"
    print_status "Max parallel jobs: $MAX_PARALLEL_JOBS"
    if [[ -n "$SERIES_FILTER" ]]; then
        print_status "Series filter: $SERIES_FILTER"
    fi
    if [[ -n "$DATE_FILTER" ]]; then
        print_status "Date filter: from $DATE_FILTER"
    fi
    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "DRY RUN MODE - No files will be created"
    fi
    echo
    
    # Process CSV file
    local line_number=0
    local processed=0
    local skipped=0
    local errors=0
    local resume_found=false
    
    # Skip header line and process each video
    tail -n +2 "$CSV_FILE" | while IFS=',' read -r unique_name series number date youtube_url guests title || [[ -n "$unique_name" ]]; do
        line_number=$((line_number + 1))
        
        # Remove quotes from fields
        unique_name=$(echo "$unique_name" | sed 's/^"//; s/"$//')
        series=$(echo "$series" | sed 's/^"//; s/"$//')
        number=$(echo "$number" | sed 's/^"//; s/"$//')
        date=$(echo "$date" | sed 's/^"//; s/"$//')
        youtube_url=$(echo "$youtube_url" | sed 's/^"//; s/"$//')
        guests=$(echo "$guests" | sed 's/^"//; s/"$//')
        title=$(echo "$title" | sed 's/^"//; s/"$//')
        
        # Skip empty lines
        if [[ -z "$unique_name" || -z "$youtube_url" ]]; then
            continue
        fi
        
        # Resume logic
        if [[ -n "$RESUME_FROM" && "$resume_found" == "false" ]]; then
            if [[ "$unique_name" == "$RESUME_FROM" ]]; then
                resume_found=true
                print_status "Resuming from: $RESUME_FROM"
            else
                continue
            fi
        fi
        
        # Series filter
        if [[ -n "$SERIES_FILTER" && "$series" != "$SERIES_FILTER" ]]; then
            continue
        fi
        
        # Date filter (basic implementation)
        if [[ -n "$DATE_FILTER" ]]; then
            # Convert date to comparable format (YYYY-MM-DD)
            local video_date=$(echo "$date" | grep -oE '[0-9]{1,2}/[0-9]{1,2}/[0-9]{4}' | head -1)
            if [[ -n "$video_date" ]]; then
                # Convert MM/DD/YYYY to YYYY-MM-DD for comparison
                local converted_date=$(date -d "$video_date" +%Y-%m-%d 2>/dev/null || echo "")
                if [[ -n "$converted_date" && "$converted_date" < "$DATE_FILTER" ]]; then
                    continue
                fi
            fi
        fi
        
        # Process the video
        print_progress "[$((processed + 1))] Processing video..."
        if process_video "$unique_name" "$series" "$number" "$date" "$youtube_url" "$guests" "$title"; then
            processed=$((processed + 1))
        else
            errors=$((errors + 1))
        fi
        
        echo "---"
        
        # Limit parallel processing (simple approach)
        if [[ $((processed % MAX_PARALLEL_JOBS)) -eq 0 ]]; then
            sleep 1  # Brief pause between batches
        fi
    done
    
    # Generate final report
    print_status "Batch transcription completed"
    print_success "Successfully processed: $processed videos"
    if [[ $errors -gt 0 ]]; then
        print_error "Failed: $errors videos"
    fi
    
    generate_report
    show_status
}

# Run main function
main "$@" 