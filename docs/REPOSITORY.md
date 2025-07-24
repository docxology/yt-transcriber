# YT-Transcriber Repository Documentation

## Repository Structure

This repository is organized to efficiently manage video transcription, summarization, and translation workflows for the Active Inference Institute's extensive video collection.

### Directory Structure

```
yt-transcriber/
├── README.md                     # Main project documentation
├── setup.sh                      # Automated setup script
├── .cursorrules                  # Development guidelines
├── 
├── core/                         # Core transcription tools
│   ├── yt-transcriber           # Main transcription script
│   ├── summarize                # Text summarization tool
│   ├── translate                # Translation tool
│   └── support_functions.bash  # Shared utility functions
│
├── scripts/                      # Batch processing and automation
│   ├── batch_transcribe.sh      # Batch transcription script
│   ├── video_manager.py         # Video metadata and status management
│   ├── generate_index.py        # Generate searchable index
│   └── utils/                   # Utility scripts
│
├── data/                         # All video and transcript data
│   ├── videos/                  # Video metadata and sources
│   │   ├── video_download.csv   # Master video list
│   │   └── metadata/            # Individual video metadata files
│   ├── transcripts/             # All transcript files organized by series
│   │   ├── Livestream/          # Livestream transcripts
│   │   ├── GuestStream/         # GuestStream transcripts
│   │   ├── ModelStream/         # ModelStream transcripts
│   │   ├── MathStream/          # MathStream transcripts
│   │   └── [other_series]/      # Other series transcripts
│   ├── summaries/               # Generated summaries
│   └── translations/            # Generated translations
│
├── docs/                         # Documentation
│   ├── README.md                # This file
│   ├── SETUP.md                 # Setup instructions
│   ├── USAGE.md                 # Usage guide
│   └── API.md                   # API documentation
│
├── cache/                        # Cache and temporary files
│   ├── downloads/               # Temporary video downloads
│   └── processing/              # Processing workspace
│
├── output/                       # Generated outputs and reports
│   ├── index.html               # Searchable video index
│   ├── reports/                 # Processing reports
│   └── exports/                 # Data exports
│
└── config/                       # Configuration files
    ├── series_config.json       # Series-specific configurations
    ├── transcription_config.json # Transcription settings
    └── export_templates/        # Output templates
```

## Core Components

### 1. Transcription Tools (`core/`)

- **yt-transcriber**: Main script for downloading and transcribing YouTube videos
- **summarize**: Script for generating summaries using OpenAI, Ollama, or LM Studio
- **translate**: Script for translating text to different languages
- **support_functions.bash**: Shared utility functions

### 2. Batch Processing (`scripts/`)

- **batch_transcribe.sh**: Processes multiple videos from the CSV with intelligent caching
- **video_manager.py**: Manages video metadata, tracks processing status
- **generate_index.py**: Creates searchable HTML index of all content

### 3. Data Organization (`data/`)

#### Video Metadata (`data/videos/`)
- Master CSV file with all video information
- Individual metadata files for detailed video information

#### Transcripts (`data/transcripts/`)
Organized by series for easy navigation:
- Each series has its own subdirectory
- Consistent naming convention: `{series}_{number}_{sanitized_title}.txt`
- Includes metadata headers in transcript files

#### Processed Content (`data/summaries/`, `data/translations/`)
- Organized parallel to transcripts
- Multiple output formats supported

## Workflow

### 1. Initial Setup
```bash
./setup.sh
```

### 2. Batch Transcription
```bash
./scripts/batch_transcribe.sh
```

### 3. Generate Index
```bash
python scripts/generate_index.py
```

### 4. Individual Processing
```bash
# Transcribe single video
./core/yt-transcriber "https://youtube.com/watch?v=VIDEO_ID"

# Summarize existing transcript
cat data/transcripts/Livestream/livestream_001_narrative_as_active_inference.txt | ./core/summarize

# Translate content
cat data/transcripts/Livestream/livestream_001_narrative_as_active_inference.txt | ./core/translate Spanish
```

## Features

### Intelligent Caching
- Transcripts are never re-generated if they already exist
- Metadata tracking prevents duplicate work
- Resumable batch processing

### Flexible Output Formats
- Plain text transcripts with metadata headers
- HTML output with timestamps and speakers
- JSON exports for programmatic access

### Series-Based Organization
- Automatic categorization by video series
- Consistent naming conventions
- Easy navigation and discovery

### Search and Discovery
- Generated HTML index with full-text search
- Metadata-rich organization
- Cross-series linking and references

## Configuration

### Series Configuration (`config/series_config.json`)
Defines how each series should be processed:
- Naming conventions
- Special processing rules
- Output formats

### Transcription Settings (`config/transcription_config.json`)
Controls transcription behavior:
- Whisper model settings
- Quality parameters
- Processing options

## Status Tracking

The system tracks processing status for each video:
- **pending**: Not yet processed
- **processing**: Currently being transcribed
- **completed**: Successfully transcribed
- **error**: Failed processing
- **skipped**: Intentionally skipped

## Dependencies

See main README.md for dependency information and setup instructions.

## Contributing

1. Follow the coding guidelines in `.cursorrules`
2. Update documentation when adding features
3. Test with a small subset before batch processing
4. Maintain the organized directory structure 