Add-Type -AssemblyName System.Speech
$dir = "Q:/testcode/Project Xiaocao/video/frames"

$texts = @(
 "You've built an agent in Azure AI Foundry. Now you need to put a chat UI in front of it, without paying for always-on servers. This is XiaoCao: a serverless, white-label chat experience for Foundry agents that runs at near-zero cost, with one codebase for both your test and production environments.",
 "A Foundry agent is just an API. It has no user interface. The usual answer is to stand up a web server or a container to host one. But that means paying around the clock for compute that mostly sits idle, and maintaining infrastructure you don't want to own. For a simple chat front end, that's overkill.",
 "XiaoCao keeps it lean. The browser loads a React app from Azure Static Web Apps: pure static files, effectively free to host. It calls a serverless Azure Function that talks to your Foundry agent. It opens a conversation, starts a run, polls until the agent is done, and returns the reply. There's no server to manage. Everything scales to zero when no one is using it, so you only pay when it's actually working.",
 "Security is built in. The Function authenticates to Foundry with a managed identity, so no keys are ever exposed in the browser. And cost is the whole point. The test environment runs entirely on free tiers: zero dollars a month. Production adds a small Static Web Apps fee for custom domains and an SLA, while the API stays on consumption billing, where the first million calls each month are free.",
 "Here it is in action. The user sends a message, the Function dispatches it to the Foundry agent, and the UI polls in the background while the agent thinks. A moment later, the answer comes back and renders right in the terminal-style interface. Same experience whether you're pointing at your test agent or your production one.",
 "Deployment is a single command. Give it your subscription, resource group, and Foundry agent, then pick test or production. The script provisions the resources, wires up permissions, and deploys the app so it works immediately. Two environments, one codebase, near-zero cost. That's XiaoCao. Thanks for watching."
)

$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
$synth.Rate = 0
$synth.Volume = 100
# Prefer a higher-quality installed voice if available
$voices = $synth.GetInstalledVoices() | Where-Object { $_.Enabled } | ForEach-Object { $_.VoiceInfo.Name }
foreach ($pref in @('Microsoft Aria','Microsoft Jenny','Microsoft Zira','Microsoft David')) {
  if ($voices -contains $pref) { $synth.SelectVoice($pref); break }
}
Write-Host "Voice: $($synth.Voice.Name)"

for ($i = 0; $i -lt $texts.Count; $i++) {
  $out = Join-Path $dir ("say{0:d2}.wav" -f $i)
  $synth.SetOutputToWaveFile($out)
  $synth.Speak($texts[$i])
}
$synth.SetOutputToNull()
$synth.Dispose()
Write-Host "done"
