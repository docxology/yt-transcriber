# yt-transcriber

TUI app- Give it a YouTube URL (or a path to a video or audio file) and you get a transcription with possible speaker identification (WIP) and optional summary or translation, all thanks to open-source AI tooling and my lack of enough free time to watch content-sparse YouTube videos

## features

- [x] transcribe YouTube videos by URL
- [x] output metadata about the video
- [ ] speaker identification (probably using an LLM in conjunction with a speaker diarization library)
- [x] summarization via `summarize` (requires `OPENAI_API_KEY` to be set)
- [x] translation via `translate <language_name>` (requires `OPENAI_API_KEY` to be set)
- [x] can use almost any audio or video format that `ffmpeg` can handle as input, not just YouTube URLs
- [x] Test suite (run it with `yt-transcriber TEST` or `TEST=1 yt-transcriber`)
- [ ] support for other video platforms
- [ ] convert all this to a web service or web app

Speaker identification ("diarization"), summarization and translation will probably require an API key for Claude or OpenAI and/or one from Huggingface.

## installation

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
- Install all required dependencies (FFmpeg 7+, Python 3.12, pyenv)
- Set up the Python virtual environment with all required packages
- Download the Whisper model
- Create symlinks for easy access
- Test the installation

### Manual Installation

If you have Nix installed or are running on NixOS, just symlink `yt-transcriber`, `summarize`
and `translate` to any directory (usually `~/bin` or `XDG_BIN_HOME` which is usually `~/.local/bin`)
in your `PATH` and you're good to go (the last two require OPENAI_API_KEY to be
defined in your environment). The shell script will automatically procure all dependencies
deterministically and locally and cache them.

If you do not have Nix installed, I recommend using the Determinate Nix Installer from here:
https://github.com/DeterminateSystems/nix-installer

If you refuse to use Nix, you can try to install the following dependencies manually, but I make no guarantees:

```bash
python312
ffmpeg
glow
```

(`glow` is optional; if using the `--markdown|-md` argument with `summarize`, this makes things prettier in the terminal if you pipe to it)
The Python dependencies will be installed via pip into a venv cached in `$XDG_CACHE_HOME/yt-transcriber/.venv`
and XDG_CACHE_HOME defaults to `~/.cache` if not set.
The Whisper model will be downloaded to `$XDG_CACHE_HOME/yt-transcriber/.whisper`.

the `flake.nix` file manages all deps, so just `nix develop` when in there.
`./yt_transcriber TEST` tests the app itself.
No app keys needed, Whisper runs locally.

## usage

### Individual Video Transcription

```bash
# Transcribe a single video
./core/yt-transcriber "https://www.youtube.com/watch?v=<youtube_id>"

# Use different Whisper model
./core/yt-transcriber -m medium "https://www.youtube.com/watch?v=<youtube_id>"

# Pipe to summarization and translation
./core/yt-transcriber "video.mp4" | ./core/summarize | ./core/translate Spanish
```

### Batch Processing

Process all videos from the CSV file:
```bash
# Process all videos
./scripts/batch_transcribe.sh

# Process only specific series
./scripts/batch_transcribe.sh -s "Livestream"

# Dry run to see what would be processed
./scripts/batch_transcribe.sh -n -s "GuestStream"

# Resume from specific video
./scripts/batch_transcribe.sh -r "Livestream #025.0"

# Check processing status
./scripts/batch_transcribe.sh --status
```

### Generate Searchable Index

Create an HTML index of all transcripts:
```bash
python3 scripts/generate_index.py
# Opens in browser: output/index.html
```

### Repository Structure

After reorganization, the repository follows this structure:
- `core/` - Main transcription tools (yt-transcriber, summarize, translate)
- `scripts/` - Batch processing and automation scripts
- `data/` - All video metadata, transcripts, summaries, and translations
- `config/` - Configuration files for series and transcription settings
- `output/` - Generated indexes and reports
- `docs/` - Comprehensive documentation

### Model Options

By default the app uses the `small` model. Available options:
- `base` - Fastest, lower accuracy
- `small` - Good balance (recommended)
- `medium` - Better accuracy, slower
- `large` - Best accuracy, much slower
- `large-v2` - Latest improvements

### Advanced Usage

```bash
# Debug mode
DEBUG=1 ./core/yt-transcriber -m small "video_url"

# Force reprocess existing transcripts
./scripts/batch_transcribe.sh -f -s "MathStream"

# Process videos from specific date
./scripts/batch_transcribe.sh -d "2023-01-01"

# Custom parallel processing
./scripts/batch_transcribe.sh -j 5 -s "ModelStream"
```
