#!/usr/bin/env python3
"""
Generate Searchable Index for YT-Transcriber Repository

This script creates an HTML index of all transcripts with search functionality,
metadata display, and cross-series navigation.
"""

import json
import os
import re
import csv
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Any
import argparse


class TranscriptIndexer:
    def __init__(self, project_root: str):
        self.project_root = Path(project_root)
        self.data_dir = self.project_root / "data"
        self.videos_dir = self.data_dir / "videos"
        self.transcripts_dir = self.data_dir / "transcripts"
        self.metadata_dir = self.videos_dir / "metadata"
        self.output_dir = self.project_root / "output"
        self.csv_file = self.videos_dir / "video_download.csv"
        
        # Ensure output directory exists
        self.output_dir.mkdir(exist_ok=True)
        
    def load_video_metadata(self) -> Dict[str, Dict[str, Any]]:
        """Load video metadata from CSV and individual JSON files."""
        metadata = {}
        
        # Load from CSV
        if self.csv_file.exists():
            with open(self.csv_file, 'r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    video_id = self.extract_video_id(row.get('YouTube', ''))
                    if video_id:
                        metadata[video_id] = {
                            'unique_name': row.get('Unique event name', ''),
                            'series': row.get('Series', ''),
                            'number': row.get('Number', ''),
                            'date': row.get('Date', ''),
                            'youtube_url': row.get('YouTube', ''),
                            'guests': row.get('Guests', ''),
                            'title': row.get('Title or name of stream', ''),
                            'video_id': video_id
                        }
        
        # Enhance with individual metadata files
        if self.metadata_dir.exists():
            for metadata_file in self.metadata_dir.glob("*.json"):
                try:
                    with open(metadata_file, 'r', encoding='utf-8') as f:
                        file_metadata = json.load(f)
                        video_id = metadata_file.stem
                        if video_id in metadata:
                            metadata[video_id].update(file_metadata)
                        else:
                            metadata[video_id] = file_metadata
                except Exception as e:
                    print(f"Error loading metadata from {metadata_file}: {e}")
        
        return metadata
    
    def extract_video_id(self, url: str) -> str:
        """Extract YouTube video ID from URL."""
        patterns = [
            r'v=([a-zA-Z0-9_-]+)',
            r'youtu\.be/([a-zA-Z0-9_-]+)'
        ]
        
        for pattern in patterns:
            match = re.search(pattern, url)
            if match:
                return match.group(1)
        return ""
    
    def find_transcripts(self) -> Dict[str, Dict[str, Any]]:
        """Find all transcript files and extract their metadata."""
        transcripts = {}
        
        if not self.transcripts_dir.exists():
            return transcripts
        
        for transcript_file in self.transcripts_dir.rglob("*.txt"):
            try:
                # Read transcript file and extract metadata
                with open(transcript_file, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                # Extract metadata from transcript header
                metadata = self.extract_transcript_metadata(content)
                
                # Get relative path for organization
                relative_path = transcript_file.relative_to(self.transcripts_dir)
                series = relative_path.parts[0] if len(relative_path.parts) > 1 else "Unknown"
                
                # Extract transcript content (after metadata header)
                transcript_content = self.extract_transcript_content(content)
                
                transcripts[str(transcript_file)] = {
                    'file_path': str(transcript_file),
                    'relative_path': str(relative_path),
                    'series': series,
                    'filename': transcript_file.name,
                    'size': transcript_file.stat().st_size,
                    'modified': datetime.fromtimestamp(transcript_file.stat().st_mtime).isoformat(),
                    'content': transcript_content,
                    'content_preview': transcript_content[:500] + "..." if len(transcript_content) > 500 else transcript_content,
                    'word_count': len(transcript_content.split()),
                    **metadata
                }
                
            except Exception as e:
                print(f"Error processing transcript {transcript_file}: {e}")
        
        return transcripts
    
    def extract_transcript_metadata(self, content: str) -> Dict[str, str]:
        """Extract metadata from transcript header."""
        metadata = {}
        
        # Look for metadata section
        if "=== Video Metadata ===" in content:
            lines = content.split('\n')
            in_metadata = False
            
            for line in lines:
                line = line.strip()
                if "=== Video Metadata ===" in line:
                    in_metadata = True
                    continue
                elif "=== Transcript ===" in line:
                    break
                elif in_metadata and ':' in line:
                    key, value = line.split(':', 1)
                    metadata[key.strip().lower().replace(' ', '_')] = value.strip()
        
        return metadata
    
    def extract_transcript_content(self, content: str) -> str:
        """Extract just the transcript content, removing metadata header."""
        if "=== Transcript ===" in content:
            parts = content.split("=== Transcript ===", 1)
            if len(parts) > 1:
                return parts[1].strip()
        
        return content.strip()
    
    def get_series_statistics(self, transcripts: Dict[str, Dict[str, Any]]) -> Dict[str, Dict[str, Any]]:
        """Calculate statistics for each series."""
        series_stats = {}
        
        for transcript in transcripts.values():
            series = transcript.get('series', 'Unknown')
            
            if series not in series_stats:
                series_stats[series] = {
                    'count': 0,
                    'total_words': 0,
                    'latest_date': None,
                    'earliest_date': None,
                    'transcripts': []
                }
            
            stats = series_stats[series]
            stats['count'] += 1
            stats['total_words'] += transcript.get('word_count', 0)
            stats['transcripts'].append(transcript)
            
            # Update date range
            date_str = transcript.get('date', '')
            if date_str:
                try:
                    # Try to parse date (multiple formats possible)
                    date_obj = self.parse_date(date_str)
                    if date_obj:
                        if not stats['latest_date'] or date_obj > stats['latest_date']:
                            stats['latest_date'] = date_obj
                        if not stats['earliest_date'] or date_obj < stats['earliest_date']:
                            stats['earliest_date'] = date_obj
                except:
                    pass
        
        # Sort transcripts within each series by date/number
        for series in series_stats:
            series_stats[series]['transcripts'].sort(
                key=lambda x: (x.get('date', ''), x.get('number', ''))
            )
        
        return series_stats
    
    def parse_date(self, date_str: str) -> datetime:
        """Parse date string in various formats."""
        formats = [
            "%m/%d/%Y",
            "%m/%d/%Y %I:%M %p",
            "%Y-%m-%d",
            "%Y-%m-%dT%H:%M:%S"
        ]
        
        for fmt in formats:
            try:
                return datetime.strptime(date_str, fmt)
            except ValueError:
                continue
        
        return None
    
    def generate_html_index(self, transcripts: Dict[str, Dict[str, Any]], 
                           metadata: Dict[str, Dict[str, Any]]) -> str:
        """Generate the main HTML index page."""
        
        series_stats = self.get_series_statistics(transcripts)
        
        # Generate series cards
        series_cards = ""
        for series, stats in sorted(series_stats.items()):
            latest = stats['latest_date'].strftime("%Y-%m-%d") if stats['latest_date'] else "Unknown"
            earliest = stats['earliest_date'].strftime("%Y-%m-%d") if stats['earliest_date'] else "Unknown"
            
            series_cards += f"""
            <div class="series-card" onclick="filterBySeries('{series}')">
                <h3>{series}</h3>
                <div class="series-stats">
                    <div><strong>{stats['count']}</strong> videos</div>
                    <div><strong>{stats['total_words']:,}</strong> words</div>
                    <div>From {earliest} to {latest}</div>
                </div>
            </div>
            """
        
        # Generate transcript cards
        transcript_cards = ""
        for transcript in sorted(transcripts.values(), 
                               key=lambda x: (x.get('series', ''), x.get('date', ''), x.get('number', ''))):
            
            guests = transcript.get('guests', '')
            guests_display = f"<div class='guests'>Guests: {guests}</div>" if guests else ""
            
            date_display = transcript.get('date', 'Unknown date')
            series_display = transcript.get('series', 'Unknown series')
            title_display = transcript.get('title', transcript.get('filename', 'Untitled'))
            
            youtube_url = transcript.get('youtube_url', '')
            youtube_link = f'<a href="{youtube_url}" target="_blank" class="youtube-link">▶ Watch</a>' if youtube_url else ''
            
            transcript_cards += f"""
            <div class="transcript-card" data-series="{series_display}" data-date="{date_display}">
                <div class="card-header">
                    <h3>{title_display}</h3>
                    <div class="card-meta">
                        <span class="series-tag">{series_display}</span>
                        <span class="date-tag">{date_display}</span>
                        {youtube_link}
                    </div>
                </div>
                <div class="card-content">
                    {guests_display}
                    <div class="content-preview">{transcript.get('content_preview', '')}</div>
                    <div class="file-info">
                        <span>{transcript.get('word_count', 0):,} words</span>
                        <span>{transcript.get('size', 0):,} bytes</span>
                        <span>Modified: {transcript.get('modified', '')[:10]}</span>
                    </div>
                    <div class="file-path">{transcript.get('relative_path', '')}</div>
                </div>
            </div>
            """
        
        html_content = f"""
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Active Inference Institute - Video Transcripts Index</title>
    <style>
        * {{
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }}
        
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            line-height: 1.6;
            color: #333;
            background: #f5f7fa;
        }}
        
        .header {{
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 2rem 0;
            text-align: center;
        }}
        
        .header h1 {{
            font-size: 2.5rem;
            margin-bottom: 0.5rem;
        }}
        
        .header p {{
            font-size: 1.1rem;
            opacity: 0.9;
        }}
        
        .container {{
            max-width: 1200px;
            margin: 0 auto;
            padding: 0 1rem;
        }}
        
        .search-section {{
            background: white;
            padding: 2rem;
            margin: 2rem 0;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }}
        
        .search-box {{
            width: 100%;
            padding: 1rem;
            font-size: 1.1rem;
            border: 2px solid #e1e5e9;
            border-radius: 8px;
            margin-bottom: 1rem;
        }}
        
        .search-box:focus {{
            outline: none;
            border-color: #667eea;
        }}
        
        .filters {{
            display: flex;
            gap: 1rem;
            flex-wrap: wrap;
            margin-bottom: 1rem;
        }}
        
        .filter-button {{
            padding: 0.5rem 1rem;
            border: 1px solid #ddd;
            background: white;
            border-radius: 20px;
            cursor: pointer;
            transition: all 0.3s;
        }}
        
        .filter-button:hover,
        .filter-button.active {{
            background: #667eea;
            color: white;
            border-color: #667eea;
        }}
        
        .stats {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 1rem;
            margin: 2rem 0;
        }}
        
        .stat-card {{
            background: white;
            padding: 1.5rem;
            border-radius: 8px;
            text-align: center;
            box-shadow: 0 2px 5px rgba(0,0,0,0.1);
        }}
        
        .stat-card h3 {{
            font-size: 2rem;
            color: #667eea;
            margin-bottom: 0.5rem;
        }}
        
        .series-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(250px, 1fr));
            gap: 1rem;
            margin: 2rem 0;
        }}
        
        .series-card {{
            background: white;
            padding: 1.5rem;
            border-radius: 8px;
            cursor: pointer;
            transition: transform 0.3s, box-shadow 0.3s;
            box-shadow: 0 2px 5px rgba(0,0,0,0.1);
        }}
        
        .series-card:hover {{
            transform: translateY(-2px);
            box-shadow: 0 4px 15px rgba(0,0,0,0.15);
        }}
        
        .series-card h3 {{
            color: #667eea;
            margin-bottom: 1rem;
        }}
        
        .series-stats div {{
            margin: 0.25rem 0;
            font-size: 0.9rem;
            color: #666;
        }}
        
        .transcripts-grid {{
            display: grid;
            gap: 1rem;
            margin: 2rem 0;
        }}
        
        .transcript-card {{
            background: white;
            border-radius: 8px;
            padding: 1.5rem;
            box-shadow: 0 2px 5px rgba(0,0,0,0.1);
            transition: transform 0.3s;
        }}
        
        .transcript-card:hover {{
            transform: translateY(-1px);
            box-shadow: 0 4px 10px rgba(0,0,0,0.15);
        }}
        
        .card-header {{
            margin-bottom: 1rem;
        }}
        
        .card-header h3 {{
            color: #333;
            margin-bottom: 0.5rem;
        }}
        
        .card-meta {{
            display: flex;
            gap: 0.5rem;
            flex-wrap: wrap;
            align-items: center;
        }}
        
        .series-tag,
        .date-tag {{
            background: #e1e5e9;
            padding: 0.25rem 0.5rem;
            border-radius: 12px;
            font-size: 0.8rem;
            color: #666;
        }}
        
        .series-tag {{
            background: #667eea;
            color: white;
        }}
        
        .youtube-link {{
            background: #ff0000;
            color: white;
            padding: 0.25rem 0.5rem;
            border-radius: 12px;
            text-decoration: none;
            font-size: 0.8rem;
        }}
        
        .youtube-link:hover {{
            background: #cc0000;
        }}
        
        .guests {{
            font-style: italic;
            color: #666;
            margin-bottom: 0.5rem;
        }}
        
        .content-preview {{
            color: #555;
            line-height: 1.4;
            margin-bottom: 1rem;
        }}
        
        .file-info {{
            display: flex;
            gap: 1rem;
            font-size: 0.8rem;
            color: #888;
            margin-bottom: 0.5rem;
        }}
        
        .file-path {{
            font-family: monospace;
            font-size: 0.8rem;
            color: #999;
            background: #f8f9fa;
            padding: 0.25rem 0.5rem;
            border-radius: 4px;
        }}
        
        .hidden {{
            display: none !important;
        }}
        
        @media (max-width: 768px) {{
            .header h1 {{
                font-size: 2rem;
            }}
            
            .filters {{
                flex-direction: column;
            }}
            
            .stats {{
                grid-template-columns: 1fr;
            }}
            
            .series-grid {{
                grid-template-columns: 1fr;
            }}
            
            .file-info {{
                flex-direction: column;
                gap: 0.25rem;
            }}
        }}
    </style>
</head>
<body>
    <div class="header">
        <div class="container">
            <h1>Active Inference Institute</h1>
            <p>Video Transcripts Archive</p>
        </div>
    </div>
    
    <div class="container">
        <div class="search-section">
            <input type="text" class="search-box" placeholder="Search transcripts..." id="searchInput">
            <div class="filters">
                <button class="filter-button active" onclick="showAll()">All Series</button>
                <button class="filter-button" onclick="clearSearch()">Clear Search</button>
            </div>
        </div>
        
        <div class="stats">
            <div class="stat-card">
                <h3>{len(transcripts)}</h3>
                <p>Total Transcripts</p>
            </div>
            <div class="stat-card">
                <h3>{len(series_stats)}</h3>
                <p>Video Series</p>
            </div>
            <div class="stat-card">
                <h3>{sum(stats['total_words'] for stats in series_stats.values()):,}</h3>
                <p>Total Words</p>
            </div>
            <div class="stat-card">
                <h3>{datetime.now().strftime("%Y")}</h3>
                <p>Index Updated</p>
            </div>
        </div>
        
        <div class="series-grid" id="seriesGrid">
            {series_cards}
        </div>
        
        <div class="transcripts-grid" id="transcriptsGrid">
            {transcript_cards}
        </div>
    </div>
    
    <script>
        // Search functionality
        const searchInput = document.getElementById('searchInput');
        const transcriptCards = document.querySelectorAll('.transcript-card');
        const seriesGrid = document.getElementById('seriesGrid');
        
        searchInput.addEventListener('input', function() {{
            const searchTerm = this.value.toLowerCase();
            
            transcriptCards.forEach(card => {{
                const text = card.textContent.toLowerCase();
                if (text.includes(searchTerm)) {{
                    card.classList.remove('hidden');
                }} else {{
                    card.classList.add('hidden');
                }}
            }});
            
            // Hide series grid when searching
            if (searchTerm) {{
                seriesGrid.classList.add('hidden');
            }} else {{
                seriesGrid.classList.remove('hidden');
            }}
        }});
        
        // Filter by series
        function filterBySeries(series) {{
            transcriptCards.forEach(card => {{
                const cardSeries = card.getAttribute('data-series');
                if (cardSeries === series) {{
                    card.classList.remove('hidden');
                }} else {{
                    card.classList.add('hidden');
                }}
            }});
            
            seriesGrid.classList.add('hidden');
            searchInput.value = '';
        }}
        
        // Show all transcripts
        function showAll() {{
            transcriptCards.forEach(card => {{
                card.classList.remove('hidden');
            }});
            
            seriesGrid.classList.remove('hidden');
            searchInput.value = '';
        }}
        
        // Clear search
        function clearSearch() {{
            searchInput.value = '';
            showAll();
        }}
        
        // Generate timestamp
        document.addEventListener('DOMContentLoaded', function() {{
            console.log('YT-Transcriber Index loaded with {len(transcripts)} transcripts');
        }});
    </script>
</body>
</html>
        """
        
        return html_content
    
    def generate_index(self):
        """Generate the complete index."""
        print("Loading video metadata...")
        metadata = self.load_video_metadata()
        print(f"Loaded metadata for {len(metadata)} videos")
        
        print("Finding transcripts...")
        transcripts = self.find_transcripts()
        print(f"Found {len(transcripts)} transcripts")
        
        print("Generating HTML index...")
        html_content = self.generate_html_index(transcripts, metadata)
        
        # Write HTML file
        output_file = self.output_dir / "index.html"
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(html_content)
        
        print(f"Index generated: {output_file}")
        
        # Generate JSON export for programmatic access
        json_output = {
            'metadata': metadata,
            'transcripts': transcripts,
            'series_stats': self.get_series_statistics(transcripts),
            'generated': datetime.now().isoformat()
        }
        
        json_file = self.output_dir / "transcripts_index.json"
        with open(json_file, 'w', encoding='utf-8') as f:
            json.dump(json_output, f, indent=2, ensure_ascii=False)
        
        print(f"JSON export generated: {json_file}")


def main():
    parser = argparse.ArgumentParser(description='Generate searchable index of transcripts')
    parser.add_argument('--project-root', default='.', 
                       help='Project root directory (default: current directory)')
    
    args = parser.parse_args()
    
    indexer = TranscriptIndexer(args.project_root)
    indexer.generate_index()


if __name__ == "__main__":
    main() 