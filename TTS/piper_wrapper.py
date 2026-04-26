#!/usr/bin/env python3
import sys
import subprocess
from pathlib import Path
import tempfile
import platform

def main():
    if len(sys.argv) < 2:
        print("Usage: python piper_wrapper.py 'Text to speak'")
        sys.exit(1)

    text = sys.argv[1]

    script_dir = Path(__file__).parent
    voice_file = script_dir / "voices" / "en_GB-northern_english_male-medium.onnx"

    if not voice_file.exists():
        print(f"Voice file not found: {voice_file}")
        sys.exit(1)

    output_wav = tempfile.mktemp(suffix=".wav")

    # Call Piper using embedded Python
    python_exe = str(script_dir.parent / "python/venv/bin/python")
    try:
        subprocess.run([
            python_exe,
            "-m", "piper",
            "--model", str(voice_file),
            "--text", text,
            "--output_file", output_wav
        ], check=True)
    except subprocess.CalledProcessError as e:
        print(f"Error running Piper: {e}")
        sys.exit(1)

    # Play WAV
    if platform.system() == "Darwin":
        subprocess.run(["afplay", output_wav])
    elif platform.system() == "Linux":
        subprocess.run(["aplay", output_wav])
    elif platform.system() == "Windows":
        subprocess.run([
            "powershell", "-Command",
            f"(New-Object Media.SoundPlayer '{output_wav}').PlaySync();"
        ])
    else:
        print(f"Cannot play audio on {platform.system()}")

if __name__ == "__main__":
    main()
