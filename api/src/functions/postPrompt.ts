import { app, HttpRequest, HttpResponseInit, InvocationContext } from "@azure/functions";
import { getClient, resolveAgentId } from "../shared/foundry";

export async function postPrompt(
  request: HttpRequest,
  context: InvocationContext
): Promise<HttpResponseInit> {
  try {
    const { threadId, message } = (await request.json()) as {
      threadId?: string;
      message?: string;
    };

    if (!message || !message.trim()) {
      return { status: 400, jsonBody: { error: "message is required." } };
    }

    const client = getClient();
    const agentId = await resolveAgentId();

    // Reuse an existing conversation thread or create a fresh one.
    const activeThreadId = threadId ?? (await client.threads.create()).id;

    // Post the user prompt into the thread.
    await client.messages.create(activeThreadId, "user", message);

    // Kick off the agent run.
    const run = await client.runs.create(activeThreadId, agentId);

    return {
      status: 200,
      jsonBody: { threadId: activeThreadId, runId: run.id, status: run.status }
    };
  } catch (error: unknown) {
    const msg = error instanceof Error ? error.message : "unknown error";
    context.error(`postPrompt failed: ${msg}`);
    return { status: 500, jsonBody: { error: "Failed to queue agent task." } };
  }
}

app.http("postPrompt", {
  methods: ["POST"],
  authLevel: "anonymous",
  route: "chat/prompt",
  handler: postPrompt
});
