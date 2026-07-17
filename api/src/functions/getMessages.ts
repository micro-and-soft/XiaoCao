import { app, HttpRequest, HttpResponseInit, InvocationContext } from "@azure/functions";
import { getClient } from "../shared/foundry";

type OutMessage = { id: string; role: "user" | "assistant"; text: string };

export async function getMessages(
  request: HttpRequest,
  context: InvocationContext
): Promise<HttpResponseInit> {
  try {
    const threadId = request.query.get("threadId");
    if (!threadId) {
      return { status: 400, jsonBody: { error: "threadId is required." } };
    }

    const client = getClient();
    const collected: OutMessage[] = [];

    for await (const msg of client.messages.list(threadId, { order: "asc" })) {
      const text = (msg.content ?? [])
        .map((c: unknown) => {
          const item = c as { type?: string; text?: { value?: string } };
          return item.type === "text" ? item.text?.value ?? "" : "";
        })
        .join("")
        .trim();

      if (!text) continue;

      collected.push({
        id: msg.id,
        role: msg.role === "user" ? "user" : "assistant",
        text
      });
    }

    return { status: 200, jsonBody: { messages: collected } };
  } catch (error: unknown) {
    const msg = error instanceof Error ? error.message : "unknown error";
    context.error(`getMessages failed: ${msg}`);
    return { status: 500, jsonBody: { error: "Failed to fetch messages." } };
  }
}

app.http("getMessages", {
  methods: ["GET"],
  authLevel: "anonymous",
  route: "chat/messages",
  handler: getMessages
});
