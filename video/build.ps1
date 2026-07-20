# Builds the final narrated MP4 from slide PNGs + per-slide TTS wavs.
$ErrorActionPreference = "Stop"
Set-Location "Q:/testcode/Project Xiaocao/video"
$frames = "frames"

function FF([string] $ffargs) { cmd /c "ffmpeg -y $ffargs 2>nul" | Out-Null }

# Minimum on-screen time per slide (visual pacing)
$minDur = @(20, 25, 35, 30, 40, 30)

# Segment duration = max(min, narration + 1.5s tail), rounded up.
$seg = @()
for ($i = 0; $i -lt 6; $i++) {
    $wav = Join-Path $frames ("say{0:d2}.wav" -f $i)
    $sd = [double](ffprobe -v error -show_entries format=duration -of default=nk=1:nw=1 $wav)
    $d = [math]::Ceiling([math]::Max($minDur[$i], $sd + 1.5))
    $seg += [int]$d
}
Write-Host "Segment durations: $($seg -join ', ')  total=$(($seg | Measure-Object -Sum).Sum)s"

# 1) Video: concat slides with computed durations
$vlist = @("ffconcat version 1.0")
for ($i = 0; $i -lt 6; $i++) {
    $vlist += "file 'slide{0:d2}.png'" -f $i
    $vlist += "duration $($seg[$i])"
}
$vlist += "file 'slide05.png'"
$vlist | Set-Content -Encoding ascii (Join-Path $frames "video.txt")

# 2) Audio: pad each narration wav out to its segment length, then concat
$alist = @()
for ($i = 0; $i -lt 6; $i++) {
    $inWav = Join-Path $frames ("say{0:d2}.wav" -f $i)
    $outWav = Join-Path $frames ("seg{0:d2}.wav" -f $i)
    FF "-i `"$inWav`" -af apad -t $($seg[$i]) -ar 44100 -ac 2 `"$outWav`""
    $alist += "file 'seg{0:d2}.wav'" -f $i
}
$alist | Set-Content -Encoding ascii (Join-Path $frames "audio.txt")
FF "-f concat -safe 0 -i `"$(Join-Path $frames 'audio.txt')`" -c copy `"$(Join-Path $frames 'narration.wav')`""

# 3) Mux: silent slideshow video + narration -> final mp4
FF "-f concat -safe 0 -i `"$(Join-Path $frames 'video.txt')`" -i `"$(Join-Path $frames 'narration.wav')`" -vf `"fps=30,format=yuv420p,scale=1920:1080`" -c:v libx264 -c:a aac -b:a 160k -shortest -movflags +faststart xiaocao-explainer.mp4"

$dur = [math]::Round([double](ffprobe -v error -show_entries format=duration -of default=nk=1:nw=1 xiaocao-explainer.mp4), 1)
$size = [math]::Round((Get-Item xiaocao-explainer.mp4).Length / 1MB, 2)
Write-Host "FINAL: xiaocao-explainer.mp4  ${dur}s  ${size} MB"
