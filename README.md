# yt-transcriber

A comprehensive YouTube video transcription system with batch processing, local AI models, and intelligent organization. Transcribe YouTube videos by URL or local media files, with optional summarization and translation capabilities.

## ✨ Features

- [x] **Transcribe YouTube videos by URL** with metadata extraction
- [x] **Local Whisper models** - No API keys required for transcription
- [x] **Batch processing** - Process entire video libraries systematically
- [x] **Progress indicators** - Real-time status updates during transcription
- [x] **Intelligent caching** - Skip already processed videos automatically
- [x] **Organized storage** - YouTube ID-based file naming and series organization
- [x] **Summarization** via `summarize` (requires `OPENAI_API_KEY` for OpenAI or local LLM)
- [x] **Translation** via `translate <language_name>` (requires `OPENAI_API_KEY` for OpenAI or local LLM)
- [x] **Multiple audio/video formats** - Any format `ffmpeg` can handle
- [x] **Test suite** - Run with `yt-transcriber TEST` or `TEST=1 yt-transcriber`
- [x] **Batch status checking** - See what's processed vs what needs work
- [x] **Searchable index** - Generate HTML index of all transcripts
- [ ] Speaker identification (diarization) - WIP
- [ ] Support for other video platforms - Planned
- [ ] Web service conversion - Planned

## 🏗️ Repository Structure

```
yt-transcriber/
├── core/                          # Main transcription tools
│   ├── yt-transcriber            # Primary transcription script
│   ├── summarize                 # AI-powered summarization
│   ├── translate                 # Multi-language translation
│   └── support_functions.bash    # Shared utility functions
├── scripts/                      # Batch processing & automation
│   ├── batch_transcribe.sh       # Main batch processing script
│   ├── check_batch_status.sh     # Status checking and reporting
│   └── generate_index.py         # HTML index generation
├── data/                         # All generated content
│   ├── videos/                   # Video metadata and CSV files
│   │   ├── video_download.csv    # Main video database
│   │   └── metadata/             # Extracted video metadata
│   ├── transcripts/              # Generated transcripts
│   │   ├── Livestream/           # Series-organized transcripts
│   │   ├── GuestStream/          # Each series gets its own folder
│   │   └── {VideoID}.txt         # YouTube ID-based naming
│   ├── summaries/                # AI-generated summaries
│   └── translations/             # Translated transcripts
├── config/                       # Configuration files
│   ├── transcription_config.json # Whisper model settings
│   ├── series_config.json        # Series definitions
│   └── export_templates/         # Output templates
├── cache/                        # Temporary processing files
│   ├── downloads/                # Downloaded audio/video files
│   └── processing/               # Intermediate processing files
├── output/                       # Generated reports and indexes
│   ├── index.html                # Searchable transcript index
│   ├── reports/                  # Processing reports
│   └── exports/                  # Formatted exports
├── docs/                         # Documentation
├── flake.nix                     # Nix development environment
├── setup.sh                      # Automated setup script
└── README.md                     # This file
```

## 🚀 Installation

### Quick Setup (Recommended)

For Ubuntu/Debian systems, use the automated setup script:

```bash
# Clone the repository
git clone <repository-url>
cd yt-transcriber

# Run the setup script
./setup.sh
```

The setup script will:
- Install all required dependencies (FFmpeg 7+, Python 3.12, Rye)
- Set up the Python virtual environment with all required packages
- Download the Whisper model
- Create symlinks for easy access
- Test the installation

### Manual Installation

#### Option 1: Nix (Recommended)

If you have Nix installed or are running on NixOS:

```bash
# Install Nix if you don't have it
curl -sSf https://rye.astral.sh/get | bash
source "$HOME/.rye/env"

# Clone and enter the repository
git clone <repository-url>
cd yt-transcriber

# Enter the development environment
nix develop

# Install Python dependencies
rye sync

# Test the installation
./core/yt-transcriber TEST
```

#### Option 2: Manual Dependencies

If you prefer manual installation, you'll need:

```bash
# System dependencies
sudo apt update
sudo apt install python3.12 python3.12-venv ffmpeg jq curl

# Install Rye for Python dependency management
curl -sSf https://rye.astral.sh/get | bash
source "$HOME/.rye/env"

# Clone the repository
git clone <repository-url>
cd yt-transcriber

# Install Python dependencies
rye sync

# Test the installation
./core/yt-transcriber TEST
```

## 📖 Usage

### Individual Video Transcription

```bash
# Basic transcription
./core/yt-transcriber "https://www.youtube.com/watch?v=<youtube_id>"

# Use different Whisper model
./core/yt-transcriber -m medium "https://www.youtube.com/watch?v=<youtube_id>"

# Transcribe local file
./core/yt-transcriber "video.mp4"

# Pipe to summarization and translation
./core/yt-transcriber "video.mp4" | ./core/summarize | ./core/translate Spanish

# Debug mode with progress indicators
DEBUG=1 ./core/yt-transcriber "video_url"
```

### Batch Processing

Process all videos from the CSV file:

```bash
# Process all videos (all series)
./scripts/batch_transcribe.sh

# Process only specific series
./scripts/batch_transcribe.sh -s "Livestream"

# Process multiple series
./scripts/batch_transcribe.sh -s "Livestream,GuestStream"

# Dry run to see what would be processed
./scripts/batch_transcribe.sh -n -s "GuestStream"

# Resume from specific video
./scripts/batch_transcribe.sh -r "Livestream #025.0"

# Force reprocess existing transcripts
./scripts/batch_transcribe.sh -f -s "MathStream"

# Custom parallel processing (default: 3)
./scripts/batch_transcribe.sh -j 5 -s "ModelStream"

# Process videos from specific date
./scripts/batch_transcribe.sh -d "2023-01-01"
```

### Status and Monitoring

```bash
# Check batch processing status
./scripts/check_batch_status.sh

# Check specific series status
./scripts/check_batch_status.sh -s "Livestream"

# Generate searchable index
python3 scripts/generate_index.py
# Opens in browser: output/index.html
```

### Model Options

By default the app uses the `small` model. Available options:
- `base` - Fastest, lower accuracy (~1GB RAM)
- `small` - Good balance, recommended (~2GB RAM)
- `medium` - Better accuracy, slower (~5GB RAM)
- `large` - Best accuracy, much slower (~10GB RAM)
- `large-v2` - Latest improvements (~10GB RAM)

### Advanced Usage

```bash
# Environment variables for customization
export DEFAULT_WHISPER_MODEL="medium"
export DEBUG=1
export OPENAI_API_KEY="your-key-here"

# Custom cache directory
export XDG_CACHE_HOME="/custom/cache/path"

# Force specific device (CPU/GPU)
export CUDA_VISIBLE_DEVICES="0"
```

## 🔧 Configuration

### Transcription Settings

Edit `config/transcription_config.json`:

```json
{
  "default_model": "small",
  "max_parallel_jobs": 3,
  "cache_audio": true,
  "output_format": "txt"
}
```

### Series Configuration

Edit `config/series_config.json` to define video series:

```json
{
  "Livestream": {
    "description": "Active Inference Institute Livestreams",
    "output_dir": "data/transcripts/Livestream"
  },
  "GuestStream": {
    "description": "Guest speaker presentations",
    "output_dir": "data/transcripts/GuestStream"
  }
}
```

## 📊 Progress Indicators

The system provides comprehensive progress feedback:

- **System Information**: CPU cores, memory, GPU availability
- **Audio Duration**: Video length detection
- **Model Loading**: Spinner with completion status
- **Processing Estimates**: Time estimates based on video length
- **Transcription Progress**: Real-time status during Whisper processing
- **File Operations**: Save confirmations and file sizes

## 🗂️ File Organization

### Transcript Storage

Transcripts are automatically organized by:
- **Series**: Each series gets its own directory (`Livestream/`, `GuestStream/`, etc.)
- **YouTube ID**: Files named using the video's YouTube ID (`C94WDXAe4EE.txt`)
- **Metadata**: Associated metadata stored alongside transcripts

### Example Structure

```
data/transcripts/
├── Livestream/
│   ├── C94WDXAe4EE.txt          # "Narrative as active inference"
│   ├── 601-lt_8eVE.txt          # Livestream #002.1
│   └── mz7L4GD5g-E.txt          # Livestream #003.1
├── GuestStream/
│   ├── ijuxHfPDd3U.txt          # Guest presentation
│   └── Y6qx6C1tmjs.txt          # Another guest talk
└── metadata/
    ├── C94WDXAe4EE.json         # Video metadata
    └── 601-lt_8eVE.json         # Channel, duration, etc.
```

## 🧪 Testing

```bash
# Run the test suite
./core/yt-transcriber TEST

# Or with environment variable
TEST=1 ./core/yt-transcriber

# Integration tests with real API
./core/yt-transcriber --integration-test
```

## 🔍 Troubleshooting

### Common Issues

1. **"Command 'pyenv' not found"**
   - Install Rye: `curl -sSf https://rye.astral.sh/get | bash`
   - Source it: `source "$HOME/.rye/env"`

2. **Whisper model download fails**
   - Check internet connection
   - Verify disk space (models are 1-10GB)
   - Try manual download: `python3 -c "import whisper; whisper.load_model('small')"`

3. **CUDA/GPU issues**
   - Install CUDA drivers if using GPU
   - Force CPU: `export CUDA_VISIBLE_DEVICES=""`

4. **Memory issues with large models**
   - Use smaller model: `-m base` or `-m small`
   - Close other applications
   - Process shorter videos first

### Debug Mode

Enable detailed logging:

```bash
DEBUG=1 ./core/yt-transcriber "video_url"
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Follow the coding style guidelines
4. Add tests for new functionality
5. Submit a pull request

## 📄 License

[Add your license information here]

## 🙏 Acknowledgments

- OpenAI for Whisper models
- yt-dlp for YouTube downloading
- FFmpeg for media processing
- The open-source AI community
