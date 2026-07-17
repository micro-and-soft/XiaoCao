Here is a complete, production-ready architectural design document tailored for Azure Static Web Apps (SWA). This design provides an enterprise-ready, white-labelable chat UI for Azure AI Foundry Agents while maintaining a near-zero hosting cost for consumers.
------------------------------
## Technical Design Document: Serverless Chat UI for Azure AI Foundry
Target Architecture: Azure Static Web Apps (SWA) + Azure Functions (Consumption)
Cost Profile: Free Tier optimized (~ $0/mo base cost, pay-per-execution)
------------------------------
## 1. System Architecture Diagram

  ┌────────────────────────────────────────────────────────┐
  │               AZURE STATIC WEB APP (SWA)               │
  │                                                        │
  │   ┌──────────────────────┐    ┌────────────────────┐   │
  │   │   Static Frontend    │───>│ Built-in API Proxy │   │
  │   │ (React / Vite / TS)  │<───│    (/api/*)        │   │
  │   └──────────────────────┘    └─────────┬──────────┘   │
  └─────────────────────────────────────────┼──────────────┘
                                            ▼
                         ┌─────────────────────────────────────┐
                         │      Azure Function App             │
                         │   (Consumption / Serverless Node)   │
                         └──────────────────┬──────────────────┘
                                            ▼ (Secured Auth)
                         ┌─────────────────────────────────────┐
                         │          Azure Key Vault            │
                         │      (Stores AI Project Keys)       │
                         └──────────────────┬──────────────────┘
                                            ▼
                         ┌─────────────────────────────────────┐
                         │       Azure AI Foundry              │
                         │    Persistent Agent Engine          │
                         └─────────────────────────────────────┘

------------------------------
## 2. Component Specifications## 2.1 Static Frontend Layer

* Framework: React 19 / TypeScript / Vite (Compiled down to pure HTML/JS/CSS assets).
* Styling: Tailwind CSS + Shadcn UI (Provides high-performance, accessible components with zero runtime JavaScript execution overhead).
* State Management: TanStack Query (@tanstack/react-query) to orchestrate the short-polling message queue and handle state invalidation natively.

## 2.2 Serverless API Gateway Layer

* Platform: Azure Functions (Isolated Worker Model, Node.js).
* Hosting Tier: Consumption Plan ($0 base cost; first 1 million executions per month are free).
* Security Configuration: App settings mapped to Azure Key Vault references using System-Assigned Managed Identities. No raw access keys are exposed to the client.

------------------------------
## 3. Communication Sequence & Execution Control
To bypass the strict 100-second execution timeout enforced by the Azure Static Web Apps routing proxy, the system relies on an Asynchronous Execution Pattern rather than streaming long-lived server-sent events.

[ Client Browser ]          [ SWA API (/api/run) ]        [ Azure AI Foundry ]
       │                              │                              │
       │  1. POST Prompt Payload       │                              │
       ├─────────────────────────────>│                              │
       │                              │  2. createMessage() &        │
       │                              │     createRun()              │
       │                              ├─────────────────────────────>│
       │  3. Return threadId + runId  │                              │
       │<─────────────────────────────┤                              │
       │                              │                              │
       │  == BEGIN POLL LOOP ==       │                              │
       │                              │                              │
       │  4. GET status?runId=xyz     │                              │
       ├─────────────────────────────>│                              │
       │                              │  5. Retrieve Run Status      │
       │                              ├─────────────────────────────>│
       │  6. Return state (e.g. "in_progress")                       │
       │<─────────────────────────────┤                              │
       │                              │                              │
       │  [Wait 1.5 seconds]          │                              │
       │                              │                              │
       │  7. GET status?runId=xyz     │                              │
       ├─────────────────────────────>│                              │
       │                              │  8. Retrieve Run Status      │
       │                              ├─────────────────────────────>│
       │  9. Return state ("completed")                              │
       │<─────────────────────────────┤                              │
       │                              │                              │
       │  10. GET messages?threadId=abc                              │
       ├─────────────────────────────>│                              │
       │                              │  11. Fetch Final Text       │
       │                              ├─────────────────────────────>│
       │  12. Render text to Screen   │                              │
       │<─────────────────────────────┤                              │

------------------------------
## 4. Source Code Blueprint## 4.1 Serverless Orchestrator (/api/src/functions/postPrompt.ts)
This serverless function creates the communication channel inside the secure Azure AI environment.

import { app, HttpRequest, HttpResponseInit, InvocationContext } from "@azure/functions";import { AzureAIAgentClient } from "@azure/ai-agents";import { DefaultAzureCredential } from "@azure/identity";
export async function postPrompt(request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> {
    try {
        const { threadId, message } = await request.json() as { threadId?: string; message: string };
        
        // Connect securely using Managed Identity or Key Vault strings
        const client = new AzureAIAgentClient(
            process.env.AZURE_AI_FOUNDRY_ENDPOINT!,
            new DefaultAzureCredential()
        );

        // Reuse existing conversation thread or instantiate a fresh one
        const activeThreadId = threadId || (await client.createThread()).id;

        // Post the raw prompt into the tracking thread
        await client.createMessage(activeThreadId, "user", message);

        // Instruct the Foundry backend engine to assign the query to your target Agent
        const run = await client.createRun(activeThreadId, process.env.AZURE_AI_AGENT_ID!);

        return {
            status: 200,
            jsonBody: { threadId: activeThreadId, runId: run.id, status: run.status }
        };
    } catch (error: any) {
        context.error(`Failed to dispatch prompt: ${error.message}`);
        return { status: 500, jsonBody: { error: "Failed to queue agent task." } };
    }
}

app.http("postPrompt", {
    methods: ["POST"],
    authLevel: "anonymous",
    route: "chat/prompt",
    handler: postPrompt
});

## 4.2 Frontend Polling Engine (src/hooks/useAgentSession.ts)
This component runs completely on the client side, keeping the browser UI fully interactive while the background system executes.

import { useState } from "react";
export function useAgentSession() {
  const [messages, setMessages] = useState<any[]>([]);
  const [isProcessing, setIsProcessing] = useState(false);
  const [currentThreadId, setCurrentThreadId] = useState<string | null>(null);

  const submitPrompt = async (userInput: string) => {
    setIsProcessing(true);
    
    // Step 1: Initialize the Turn
    const initResponse = await fetch("/api/chat/prompt", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ threadId: currentThreadId, message: userInput })
    });
    
    const { threadId, runId } = await initResponse.json();
    if (!currentThreadId) setCurrentThreadId(threadId);

    // Step 2: Establish the Client Polling Interval
    const pollInterval = setInterval(async () => {
      const statusCheck = await fetch(`/api/chat/status?threadId=${threadId}&runId=${runId}`);
      const { status } = await statusCheck.json();

      if (status === "completed" || status === "failed") {
        clearInterval(pollInterval);
        
        // Step 3: Fetch Updated Timeline Blocks once completed
        const contentFetch = await fetch(`/api/chat/messages?threadId=${threadId}`);
        const finalPayload = await contentFetch.json();
        
        setMessages(finalPayload.messages);
        setIsProcessing(false);
      }
    }, 1500); // Executed every 1500ms to balance responsiveness and rate limits
  };

  return { messages, submitPrompt, isProcessing };
}

------------------------------
## 5. Deployment Configuration## 5.1 CI/CD Configuration File (.github/workflows/azure-static-web-apps.yml)
This file compiles the UI assets and automatically deploys them to the $0 Static Web Apps container whenever code changes.

name: Deploy Chat UI to Azure SWA
on:
  push:
    branches:
      - main
jobs:
  build_and_deploy_job:
    runs-on: ubuntu-latest
    name: Build and Deploy Job
    steps:
      - uses: actions/checkout@v4
        with:
          submodules: true

      - name: Build And Deploy Static Assets & Functions
        id: builddeploy
        uses: Azure/static-web-apps-deploy@v1
        with:
          azure_static_web_apps_api_token: ${{ secrets.AZURE_STATIC_WEB_APPS_API_TOKEN }}
          repo_token: ${{ secrets.GITHUB_TOKEN }}
          action: "upload"
          app_location: "/"          # Root repository directory for frontend
          api_location: "api"        # Azure Functions subdirectory
          output_location: "dist"    # Vite build static outputs target directory

------------------------------
## 6. Commercialization & White-Label Strategy
This serverless architecture can easily be packaged and turned into a commercial product:

   1. Multi-Tenancy Integration: Update the /api/chat/prompt endpoint to read target Azure Foundry Connection Strings from custom tenant headers rather than hardcoded system values.
   2. Enterprise Marketplace Model: Package this repository as an Azure Application Template (ARM/Bicep). This lets enterprise clients purchase your product from the Azure Marketplace and deploy it into their own Azure subnets with a single click.
   3. Visual Differentiation: Since standard templates provide plain-text outputs, focus your UI components on rendering structured tool timelines. If the hosted agent executes an MCP-driven code analysis or corporate data query, show a clean, interactive timeline interface that visualizes the agent's work step-by-step.

------------------------------
How would you like to handle your user authentication layer? We can configure it to use Azure SWA's built-in free social logins (Microsoft, GitHub, Google), or we can set up Microsoft Entra ID for secure corporate access.

