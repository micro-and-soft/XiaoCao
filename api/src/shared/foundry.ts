import { AgentsClient } from "@azure/ai-agents";
import { DefaultAzureCredential } from "@azure/identity";

let cachedClient: AgentsClient | null = null;
let cachedAgentId: string | null = null;

export function getClient(): AgentsClient {
  const endpoint = process.env.AZURE_AI_FOUNDRY_ENDPOINT;
  if (!endpoint) {
    throw new Error("AZURE_AI_FOUNDRY_ENDPOINT is not configured.");
  }
  if (!cachedClient) {
    // Uses the Function App's managed identity in Azure,
    // or developer credentials locally. No keys are stored.
    cachedClient = new AgentsClient(endpoint, new DefaultAzureCredential());
  }
  return cachedClient;
}

/**
 * Resolves the configured agent name to its id. The customer provides the
 * friendly agent name at provision time; we look up the id once and cache it.
 * If an id is supplied directly it is used as-is.
 */
export async function resolveAgentId(): Promise<string> {
  if (cachedAgentId) return cachedAgentId;

  const directId = process.env.AZURE_AI_AGENT_ID;
  if (directId) {
    cachedAgentId = directId;
    return cachedAgentId;
  }

  const name = process.env.AZURE_AI_AGENT_NAME;
  if (!name) {
    throw new Error("AZURE_AI_AGENT_NAME (or AZURE_AI_AGENT_ID) is not configured.");
  }

  const client = getClient();
  for await (const agent of client.listAgents()) {
    if (agent.name === name) {
      cachedAgentId = agent.id;
      return cachedAgentId;
    }
  }
  throw new Error(`No Foundry agent found with name "${name}".`);
}
