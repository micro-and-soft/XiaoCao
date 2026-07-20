# XiaoCao — 3-Minute Video Script & Storyboard

Focus: a cheap, serverless chat UI for Azure AI Foundry agents — for both test and production.
Total runtime target: ~3:00. Narration ~430 words (~145 wpm).
Record with PowerPoint "Record", Clipchamp, or OBS. Or feed narration into a TTS/avatar tool.

---

## Scene 1 — Hook (0:00–0:20)
**Visual:** Title card "XiaoCao — A Low-Cost Chat UI for Azure AI Foundry Agents". Fade to the cyber terminal UI.
**Narration:**
> You've built an agent in Azure AI Foundry. Now you need to put a chat UI in front of it — without paying for always-on servers. This is XiaoCao: a serverless, white-label chat experience for Foundry agents that runs at near-zero cost, with one codebase for both your test and production environments.

## Scene 2 — The Problem (0:20–0:45)
**Visual:** A dedicated VM / app service with a "$$$ always-on" tag, crossed out. Beside it, a Foundry agent icon waiting for a front end.
**Narration:**
> A Foundry agent is just an API — it has no user interface. The usual answer is to stand up a web server or a container to host one. But that means paying around the clock for compute that mostly sits idle, and maintaining infrastructure you don't want to own. For a simple chat front end, that's overkill.

## Scene 3 — The Architecture (0:45–1:20)
**Visual:** Animate the diagram: Browser → Static Web App → Azure Function → Foundry agent.
**Narration:**
> XiaoCao keeps it lean. The browser loads a React app from Azure Static Web Apps — pure static files, effectively free to host. It calls a serverless Azure Function that talks to your Foundry agent: it opens a conversation, starts a run, polls until the agent is done, and returns the reply. There's no server to manage. Everything scales to zero when no one is using it, so you only pay when it's actually working.

## Scene 4 — Security & Cost (1:20–1:50)
**Visual:** Icons: managed identity key, "no secrets in browser". Then a two-column cost table: Test = $0, Production = lean pay-per-use.
**Narration:**
> Security is built in. The Function authenticates to Foundry with a managed identity, so no keys are ever exposed in the browser. And cost is the whole point: the test environment runs entirely on free tiers — zero dollars a month. Production adds a small Static Web Apps fee for custom domains and an SLA, while the API stays on consumption billing, where the first million calls each month are free.

## Scene 5 — Live Demo (1:50–2:30)
**Visual:** Screen-record the app. Type a prompt like "Explain the CAP theorem in three sentences." Show the "thinking" indicator, then the streamed answer.
**Narration:**
> Here it is in action. The user sends a message, the Function dispatches it to the Foundry agent, and the UI polls in the background while the agent thinks. A moment later, the answer comes back and renders right in the terminal-style interface. Same experience whether you're pointing at your test agent or your production one.

## Scene 6 — Provision & Close (2:30–3:00)
**Visual:** Show the one-line `provision.ps1` command with `-EnvironmentType test`, then `production`. End on the diagram and project name.
**Narration:**
> Deployment is a single command. Give it your subscription, resource group, and Foundry agent, then pick test or production. The script provisions the resources, wires up permissions, and deploys the app so it works immediately. Two environments, one codebase, near-zero cost. That's XiaoCao. Thanks for watching.

---

## Recording tips
- 1080p, 16:9. Hide bookmarks/desktop clutter.
- Pre-warm the app once before recording the demo so there's no cold start on camera.
- PowerPoint → **Record** → export **MP4** gives you video+audio in one step.
- For synthetic voice: paste each scene's narration into a TTS tool (e.g. Azure AI Speech)
  and align clips to the timestamps above. The included `explainer.html` can also narrate
  automatically using the browser's built-in speech synthesis.
