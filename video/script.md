# XiaoCao / Menshen — 3-Minute Video Script & Storyboard

Total runtime target: ~3:00. Narration ≈ 430 words (~145 wpm).
Record with PowerPoint "Record", Clipchamp, or OBS. Or feed narration into a TTS/avatar tool.

---

## Scene 1 — Hook (0:00–0:20)
**Visual:** Title card "XiaoCao — A Serverless, White-Label Chat UI for Azure AI Foundry Agents". Fade to the cyber terminal UI.
**Narration:**
> Enterprises want to put an AI agent in front of their users — but without paying for always-on servers, and without exposing sensitive systems to the cloud. This is XiaoCao: a serverless, white-label chat experience for Azure AI Foundry agents that runs at near-zero cost and keeps private data on-premises.

## Scene 2 — The Problem (0:20–0:45)
**Visual:** Split graphic: "Cloud AI" on one side, "Private hospital data / on-prem systems" on the other, a red gap between them.
**Narration:**
> Here's the challenge. The smart orchestration — reasoning, planning, compliance — belongs in the cloud. But the actual patient data lives behind the firewall and can never leave. So how does a cloud agent get answers from a system it isn't allowed to reach?

## Scene 3 — The Architecture (0:45–1:25)
**Visual:** Animate the concept diagram: User → Static Web App → Azure Functions → Foundry orchestrator; then Functions → Service Bus → Local Daemon (on-prem) → PHI Agent.
**Narration:**
> XiaoCao uses a hybrid, agent-to-agent pattern. The browser talks to an Azure Static Web App — pure static assets, effectively free to host. It calls a serverless Azure Function, which drives the Foundry orchestrator agent. When the orchestrator needs private data, it doesn't call the hospital directly. Instead it dispatches a task onto an Azure Service Bus queue. A lightweight daemon running inside the private network connects outbound, picks up the task, runs the on-premises agent, and streams status back. The cloud never opens a hole into the private network — the connection is always outbound.

## Scene 4 — Security & Cost (1:25–1:50)
**Visual:** Icons: managed identity key, "no secrets in browser", "$0 base cost", "1M free executions".
**Narration:**
> Security is built in. The Function authenticates to Foundry with a managed identity — no keys ever touch the browser. Access is granted with scoped role assignments at provision time. And because the front end is static and the back end is consumption-based, the base cost is essentially zero — you pay only per execution.

## Scene 5 — Live Demo (1:50–2:35)
**Visual:** Screen-record the app. Type: "get the details of patient 12345". Show the streamed updates: compliance check → dispatched to on-prem → progress → completed result.
**Narration:**
> Let's see it. A user asks for patient twelve-three-four-five. First, a compliance gatekeeper screens the request and strips any direct identifiers. The orchestrator then dispatches the job to the on-premises agent and hands back a task ID. Watch the progress stream in real time as the local agent retrieves the record — and finally the result comes back to the browser, without the raw data ever being stored in the cloud.

## Scene 6 — Provision & Close (2:35–3:00)
**Visual:** Show the one-line `provision.ps1` command, then the deployed URL. End on the concept diagram + project name.
**Narration:**
> Deployment is a single command. Provide your subscription, resource group, and Foundry agent — the script provisions everything, wires up permissions, and deploys the app so it works immediately. That's XiaoCao: cloud intelligence, private data, serverless cost. Thanks for watching.

---

## Recording tips
- 1080p, 16:9. Hide bookmarks/desktop clutter.
- For the demo, pre-warm the app once so there's no cold start on camera.
- If narrating live, PowerPoint → **Record** → export **MP4** gives you video+audio in one step.
- For synthetic voice: paste each scene's narration into a TTS tool (e.g. Azure AI Speech) and align clips to the timestamps above.
