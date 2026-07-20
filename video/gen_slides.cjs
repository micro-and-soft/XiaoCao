// Generates six 1920x1080 slide PNGs for the XiaoCao explainer using sharp.
const sharp = require("sharp");
const path = require("path");

const OUT = path.join(__dirname, "frames");
const W = 1920, H = 1080;

const C = {
  cyan: "#00f0ff", magenta: "#ff2bd6", green: "#39ff8b",
  text: "#cdefff", muted: "#7f97b5", panel: "#0e1a2e"
};

function esc(s) { return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;"); }

// Word-wrap into <tspan> lines centered at cx.
function wrap(text, max, x, y, lh, cls) {
  const words = text.split(" ");
  const lines = [];
  let cur = "";
  for (const w of words) {
    if ((cur + " " + w).trim().length > max) { lines.push(cur.trim()); cur = w; }
    else cur += " " + w;
  }
  if (cur.trim()) lines.push(cur.trim());
  return lines.map((ln, i) =>
    `<text x="${x}" y="${y + i * lh}" text-anchor="middle" class="${cls}">${esc(ln)}</text>`
  ).join("");
}

function node(x, y, w, h, label, sub, mag) {
  const stroke = mag ? C.magenta : C.cyan;
  return `
    <rect x="${x}" y="${y}" width="${w}" height="${h}" rx="12"
      fill="${C.panel}" stroke="${stroke}" stroke-opacity="0.6"/>
    <text x="${x + w / 2}" y="${y + (sub ? h / 2 - 6 : h / 2 + 8)}" text-anchor="middle" class="node">${esc(label)}</text>
    ${sub ? `<text x="${x + w / 2}" y="${y + h / 2 + 22}" text-anchor="middle" class="nodesub">${esc(sub)}</text>` : ""}`;
}

function arrow(x, y) {
  return `<text x="${x}" y="${y}" text-anchor="middle" class="arrow">&#8594;</text>`;
}

function frame(inner) {
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
    <defs>
      <radialGradient id="bg" cx="50%" cy="12%" r="90%">
        <stop offset="0%" stop-color="#0b1836"/>
        <stop offset="60%" stop-color="#05070d"/>
      </radialGradient>
      <pattern id="grid" width="48" height="48" patternUnits="userSpaceOnUse">
        <path d="M48 0 H0 V48" fill="none" stroke="#00f0ff" stroke-opacity="0.06"/>
      </pattern>
      <style>
        .tag{fill:${C.magenta};font-family:Segoe UI,Arial,sans-serif;font-size:26px;letter-spacing:6px;font-weight:600}
        .h1{fill:#ffffff;font-family:Segoe UI,Arial,sans-serif;font-size:96px;font-weight:800}
        .h2{fill:${C.cyan};font-family:Segoe UI,Arial,sans-serif;font-size:64px;font-weight:800}
        .p{fill:${C.text};font-family:Segoe UI,Arial,sans-serif;font-size:34px}
        .big{fill:${C.green};font-family:Segoe UI,Arial,sans-serif;font-size:64px;font-weight:800}
        .cardbig{fill:${C.green};font-family:Segoe UI,Arial,sans-serif;font-size:38px;font-weight:800}        .cardlab{fill:${C.text};font-family:Segoe UI,Arial,sans-serif;font-size:28px}
        .node{fill:${C.text};font-family:Segoe UI,Arial,sans-serif;font-size:30px;font-weight:600}
        .nodesub{fill:${C.muted};font-family:Segoe UI,Arial,sans-serif;font-size:22px}
        .arrow{fill:${C.muted};font-family:Segoe UI,Arial,sans-serif;font-size:44px}
        .code{fill:#eaffff;font-family:Consolas,monospace;font-size:30px}
        .mono{fill:${C.muted};font-family:Consolas,monospace;font-size:24px}
        .brand{fill:${C.cyan};font-family:Segoe UI,Arial,sans-serif;font-size:30px;font-weight:800;letter-spacing:3px}
      </style>
    </defs>
    <rect width="${W}" height="${H}" fill="url(#bg)"/>
    <rect width="${W}" height="${H}" fill="url(#grid)"/>
    <text x="70" y="80" class="brand">XIAOCAO</text>
    ${inner}
  </svg>`;
}

const cx = W / 2;

const slides = [
  // 0 - title
  frame(`
    <text x="${cx}" y="430" text-anchor="middle" class="tag">SERVERLESS &#183; WHITE-LABEL &#183; LOW-COST</text>
    <text x="${cx}" y="540" text-anchor="middle" class="h1">XiaoCao</text>
    ${wrap("A serverless, white-label chat UI for Azure AI Foundry agents — near-zero hosting cost, one codebase for test and production.", 58, cx, 640, 48, "p")}
  `),
  // 1 - problem
  frame(`
    <text x="${cx}" y="230" text-anchor="middle" class="h2">The Problem</text>
    ${node(430, 430, 420, 150, "Always-on server", "pays 24/7, mostly idle", true)}
    <text x="${cx}" y="520" text-anchor="middle" class="arrow">vs</text>
    ${node(1070, 430, 420, 150, "Foundry agent", "an API with no UI", false)}
    ${wrap("Standing up a server to host a UI means paying around the clock for idle compute — overkill for a simple chat front end.", 66, cx, 700, 46, "p")}
  `),
  // 2 - architecture
  frame(`
    <text x="${cx}" y="230" text-anchor="middle" class="h2">The Architecture</text>
    ${node(150, 470, 300, 130, "Browser", "React SPA", false)}
    ${arrow(485, 545)}
    ${node(520, 470, 340, 130, "Static Web App", "static files", false)}
    ${arrow(895, 545)}
    ${node(930, 470, 340, 130, "Azure Function", "Consumption", false)}
    ${arrow(1305, 545)}
    ${node(1340, 470, 340, 130, "Foundry agent", "persistent", false)}
    ${wrap("Static files are effectively free to host. The Function scales to zero — you pay only when it is working.", 70, cx, 730, 46, "p")}
  `),
  // 3 - security & cost
  frame(`
    <text x="${cx}" y="230" text-anchor="middle" class="h2">Security &amp; Cost</text>
    ${card(360, "Managed identity", "no secrets in browser", true)}
    ${card(760, "$0", "test environment")}
    ${card(1160, "1M", "free API calls / mo")}
    ${wrap("Test runs entirely on free tiers. Production adds a small SWA fee for custom domains and an SLA.", 70, cx, 760, 46, "p")}
  `),
  // 4 - demo
  frame(`
    <text x="${cx}" y="220" text-anchor="middle" class="h2">Live Demo</text>
    <text x="${cx}" y="320" text-anchor="middle" class="code">Prompt: Explain the CAP theorem in three sentences.</text>
    ${node(210, 470, 320, 120, "Send message", "", false)}
    ${arrow(560, 535)}
    ${node(600, 470, 340, 120, "Function to agent", "", false)}
    ${arrow(975, 535)}
    ${node(1010, 470, 300, 120, "Poll while thinking", "", false)}
    ${arrow(1345, 535)}
    ${node(1380, 470, 300, 120, "Answer", "", false)}
    ${wrap("Same experience whether you point at your test agent or your production one.", 70, cx, 730, 46, "p")}
  `),
  // 5 - provision & close
  frame(`
    <text x="${cx}" y="250" text-anchor="middle" class="h2">Provision in One Command</text>
    <rect x="260" y="330" width="1400" height="90" rx="10" fill="${C.panel}" stroke="${C.cyan}" stroke-opacity="0.4"/>
    <text x="${cx}" y="388" text-anchor="middle" class="code">./scripts/provision.ps1 -SubscriptionId ... -FoundryAgentName ... -EnvironmentType test</text>
    ${wrap("Pick test or production. The script provisions resources, wires up permissions, and deploys — working immediately.", 70, cx, 500, 46, "p")}
    <text x="${cx}" y="700" text-anchor="middle" class="h2">Two environments &#183; One codebase &#183; Near-zero cost</text>
  `)
];

function card(x, big, label, small) {
  const w = 400;
  const bigCls = small ? "cardbig" : "big";
  return `
    <rect x="${x}" y="420" width="${w}" height="200" rx="12" fill="${C.panel}" stroke="${C.cyan}" stroke-opacity="0.4"/>
    <text x="${x + w / 2}" y="510" text-anchor="middle" class="${bigCls}">${esc(big)}</text>
    <text x="${x + w / 2}" y="570" text-anchor="middle" class="cardlab">${esc(label)}</text>`;
}

(async () => {
  for (let i = 0; i < slides.length; i++) {
    const out = path.join(OUT, `slide${String(i).padStart(2, "0")}.png`);
    await sharp(Buffer.from(slides[i])).png().toFile(out);
    console.log("wrote", out);
  }
})();
