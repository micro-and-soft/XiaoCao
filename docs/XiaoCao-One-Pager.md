# Agents at Work: Foundry Platform Hackathon — Project One-Pager

| | |
|---|---|
| **Project Name** | XiaoCao — Low-Cost, White-Label Chat UI for Foundry Agents |
| **Team Members** | [enter here] |
| **Primary Contact** | [enter here] |
| **Submission Date** | July 20, 2026 |

---

## 1. Project Summary

### What did you build?
XiaoCao is a **serverless, white-label chat UI** that puts any **Azure AI Foundry** agent
in front of end users at **near-zero hosting cost**. A single codebase deploys to two cost
tiers from one command — a **$0 test** environment and a lean **production** environment.

The end-to-end experience:
- A **React single-page app** hosted on **Azure Static Web Apps** (static files, effectively
  free to serve) provides a fast, cyber-styled chat terminal.
- An **Azure Functions** backend (Consumption plan) talks to the Foundry agent using an
  **asynchronous dispatch → poll → fetch** pattern that stays within the gateway timeout.
- The Function authenticates to Foundry with a **system-assigned managed identity** — no
  keys are ever exposed in the browser.
- Provisioning is a single script that deploys resources, grants scoped RBAC, resolves the
  agent id, and deploys both the API and UI so the app works immediately.

### Problem solved
A Foundry agent is an API with no user interface. The usual way to add one — standing up a
web server or container — means paying around the clock for compute that mostly sits idle,
plus owning infrastructure and secrets. That is overkill and unnecessary cost for a chat
front end. XiaoCao removes the always-on server entirely: the front end is static, the
back end scales to zero on Consumption billing (first 1M executions/month free), and the
same code serves both a free test environment and a production environment.

### Target user or audience
Teams and ISVs who have built a Foundry agent and need a cheap, brandable chat UI to demo,
test, or ship it — without standing up or paying for dedicated hosting, and without
embedding API keys in client code.

---

## 2. Challenge Alignment

**Select all challenge(s) supported:**

- [x] Make It Effortless: Design for Product Simplicity
- [ ] EngThrive 15/30 Challenge
- [ ] Unlock Intelligence with Microsoft IQs
- [x] Build on Foundry Agents Platform
- [x] Make the Basics Fast: AI-First Engineering
- [ ] Hybrid Agents — Best of Edge + Cloud
- [ ] No specific challenge

### How the solution aligns
XiaoCao is built **on the Foundry Agents Platform**: it drives a Foundry persistent agent
through threads and runs, with no custom model hosting. It embodies **product simplicity and
speed** — one command provisions and deploys a working, secure, low-cost chat experience for
any agent, turning a bare Foundry API into a shippable product in minutes rather than days.

---

## 3. Foundry Platform Usage

**Relevant Foundry area(s):**

- [x] Agents Platform
- [x] Hosted Agents
- [ ] Prompt Agents
- [ ] Skills
- [ ] Toolboxes
- [ ] Routines
- [ ] Tracing / Observability
- [ ] Optimization / Evaluation
- [ ] Voice
- [ ] Multi-Agent Orchestration
- [ ] Other: ______

### Key features used
- **Azure AI Foundry Agents** via the `@azure/ai-agents` SDK: create/reuse **threads**, post
  **messages**, start **runs**, poll run **status**, and read the transcript.
- **Managed identity auth** with `DefaultAzureCredential` (scope `https://ai.azure.com`) —
  no SAS keys or secrets in code or in the browser.
- **Agent id resolved once at provision time** (`AZURE_AI_AGENT_ID`) to avoid per-instance
  `listAgents` calls, improving cold-start latency and reliability.
- Deployment surfaces: **Azure Static Web Apps** (Free & Standard), **Azure Functions**
  (Consumption), **Bicep** IaC, and a React/Vite frontend.

---

## 4. Architecture & Design

### Architecture overview
A three-hop serverless path, no always-on compute:

```
🧑 Browser (React SPA)
      │  HTTPS
      ▼
⚡ Azure Static Web App  ── static assets ──┐
      │  /api (prod: linked backend │ test: direct CORS)
      ▼
🔧 Azure Function (Consumption, managed identity)
      │  dispatch → poll → fetch
      ▼
🧠 Azure AI Foundry — persistent agent
```

*(See `concept.svg` / `concept.png` for the diagram, and the narrated 3-minute explainer in
`video/xiaocao-explainer.mp4`.)*

### Key architectural decisions
- **Static front end + serverless API:** No servers to run or patch; everything scales to
  zero, so base cost is effectively $0 and you pay only per execution.
- **Two cost tiers, one codebase:** A Bicep `environmentType` parameter switches SWA
  **Free** (test) vs **Standard** (production). Free tier has no linked backend, so the UI
  calls the Function URL directly via CORS; Standard links the Function as same-origin `/api`.
- **Async dispatch/poll pattern:** Splitting a turn into a fast dispatch and short status
  polls keeps every request within the SWA gateway timeout, even for long agent runs.
- **Keyless by default:** The Function reaches Foundry via managed identity with scoped
  role assignments (account + project); the browser never holds a secret.

### Known limitations / future work
- SWA Free tier lacks custom domains/SLA; production tier adds them.
- Consumption cold starts add first-request latency; a warm-up ping or Flex plan can help.
- Add optional auth (SWA built-in social logins or Entra ID) for gated deployments.
- Add response streaming for lower perceived latency on long agent runs.

---

## 5. Impact & Learnings

### Expected impact
Turns any Foundry agent into a shippable, brandable chat product with essentially no hosting
cost and no infrastructure to own — lowering the barrier to demoing and productizing agents.
The same artifact serves both test and production, so teams move from prototype to release
without rework.

### Success measure
- **$0 base cost** for the test environment; pay-per-execution in production.
- **One-command** provision + deploy that yields a working app immediately.
- **No secrets in the browser**; Foundry reached only via managed identity.
- **Same codebase** validated across test (Free) and production (Standard) tiers.

### Platform feedback or learnings
- Resolving the agent id at provision time avoids fragile runtime `listAgents` calls and the
  associated cold-start 401s while RBAC propagates.
- The dispatch/poll tool pattern is a clean way to keep serverless API calls fast and within
  gateway limits regardless of how long the agent takes.
- Managed identity + scoped RBAC keeps the security story simple and secret-free.

---

## 6. Supporting Materials

### Demo video
Narrated 3-minute walkthrough: `video/xiaocao-explainer.mp4`
(upload to the project form video field).

### Links to supporting materials
- Code repository: https://github.com/micro-and-soft/XiaoCao
- Architecture design doc: `design.md`
- Concept diagram: `concept.svg` / `concept.png`
- Video script & storyboard: `video/script.md`

### Optional notes for reviewers
The provisioning script (`scripts/provision.ps1`) validates inputs (including rejecting
portal URLs for the Foundry resource id), grants RBAC at both account and project scope, and
selects the cost tier via `-EnvironmentType test|production`. The demo points at a live
Foundry agent; no data is stored server-side.
