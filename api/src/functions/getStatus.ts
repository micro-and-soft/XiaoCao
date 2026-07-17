import { app, HttpRequest, HttpResponseInit, InvocationContext } from "@azure/functions";
import { getClient } from "../shared/foundry";

export async function getStatus(
  request: HttpRequest,
  context: InvocationContext
): Promise<HttpResponseInit> {
  try {
    const threadId = request.query.get("threadId");
    const runId = request.query.get("runId");

    if (!threadId || !runId) {
      return { status: 400, jsonBody: { error: "threadId and runId are required." } };
    }

    const client = getClient();
    const run = await client.runs.get(threadId, runId);

    return { status: 200, jsonBody: { status: run.status } };
  } catch (error: unknown) {
    const msg = error instanceof Error ? error.message : "unknown error";
    context.error(`getStatus failed: ${msg}`);
    return { status: 500, jsonBody: { error: "Failed to retrieve run status." } };
  }
}

app.http("getStatus", {
  methods: ["GET"],
  authLevel: "anonymous",
  route: "chat/status",
  handler: getStatus
});
