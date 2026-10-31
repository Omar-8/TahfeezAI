#!/usr/bin/env python3
"""Cuts the App Store app preview out of a simulator recording
(.github/workflows/ios-screenshots.yml) and encodes it as Apple asks:
30 fps H.264, a silent stereo AAC track, 15–30 s, at [size].

  python3 tool/cut_app_preview.py <recording.mov> <marks.json> <out.mp4> <W:H>

Where the tour is in the recording: the recorder's clock and the test's
log don't line up (seconds apart, either way), so it is found in the
picture — the tour ends where the screen last goes black ("Test
finished.", right after it), and starts the tour's length (from the test's
log, marks.json) before.
Needs ffmpeg.
"""
import json
import subprocess
import sys
from pathlib import Path

recording, marks_path, out, size = sys.argv[1:5]
marks = json.loads(Path(marks_path).read_text())
tour = marks["end"] - marks["start"]

# The screen's brightness, 10 times a second over the whole recording. The
# simulator records a frame only when the screen changes, so the timeline
# is made even from 0 first (fps with start_time), never seeked into: after
# a seek, a still screen would shift every time after it.
gray = subprocess.run(
    ["ffmpeg", "-loglevel", "error", "-i", recording,
     "-vf", "fps=10:start_time=0,scale=16:16,format=gray", "-f", "rawvideo", "-"],
    check=True, capture_output=True,
).stdout
frames = [gray[i:i + 256] for i in range(0, len(gray), 256)]
# The tour ends where the recording's last black stretch begins ("Test
# finished.", then only the simulator's home screen until it stops).
dark = [sum(f) / 256 < 10 for f in frames]
if True not in dark:
    sys.exit("no black frame: is 'Test finished.' in the recording?")
last = len(dark) - 1 - dark[::-1].index(True)
while last > 0 and dark[last - 1]:
    last -= 1
end = last / 10
start = max(0.0, end - tour)
length = min(29.5, end - start)
if length < 15:
    sys.exit(f"the tour is {length:.1f} s: Apple wants 15–30 s")
print(f"{recording}: tour {start:.1f}–{end:.1f} s ({length:.1f} s)")

subprocess.run(
    ["ffmpeg", "-loglevel", "error", "-y", "-i", recording,
     "-f", "lavfi", "-i", "anullsrc=channel_layout=stereo:sample_rate=44100",
     # Cut on the even timeline too (see above).
     "-vf", f"fps=30:start_time=0,trim=start={start:.2f}:duration={length:.2f},setpts=PTS-STARTPTS,"
            f"scale={size}:force_original_aspect_ratio=increase,crop={size},setsar=1",
     "-c:v", "libx264", "-profile:v", "high", "-level", "4.0", "-pix_fmt", "yuv420p",
     "-b:v", "11M", "-maxrate", "12M", "-bufsize", "24M",
     "-c:a", "aac", "-b:a", "256k", "-ar", "44100", "-shortest",
     "-movflags", "+faststart", out],
    check=True,
)
