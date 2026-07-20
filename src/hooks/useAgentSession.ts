import { useState } from "react";

export type ChatMessage = {
  id: string;
  role: "user" | "assistant";
  text: string;
  pending?: boolean;
};

type PromptResponse = { threadId: string; runId: string; status: string };
type StatusResponse = { status: string };
type MessagesResponse = {
  messages: { id: string; role: "user" | "assistant"; text: string }[];
};

const POLL_MS = 1500;
const MAX_POLLS = 120; // ~3 minutes safety cap

// Empty for production (same-origin /api via linked backend). For the free/test
// tier, VITE_API_BASE is the Function App URL so the static site calls it via CORS.
const API_BASE = (import.meta.env.VITE_API_BASE ?? "").replace(/\/$/, "");
const api = (path: string) => `${API_BASE}${path}`;

async function readJson<T>(res: Response): Promise<T> {
  if (!res.ok) {
    throw new Error(`Request failed (${res.status})`);
  }
  return (await res.json()) as T;
}

const delay = (ms: number) => new Promise((r) => setTimeout(r, ms));

export function useAgentSession() {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [isProcessing, setIsProcessing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [threadId, setThreadId] = useState<string | null>(null);

  const submitPrompt = async (userInput: string) => {
    const trimmed = userInput.trim();
    if (!trimmed || isProcessing) return;

    setError(null);
    setIsProcessing(true);

    const localUser: ChatMessage = {
      id: `u-${Date.now()}`,
      role: "user",
      text: trimmed
    };
    const placeholder: ChatMessage = {
      id: `a-${Date.now()}`,
      role: "assistant",
      text: "",
      pending: true
    };
    setMessages((prev) => [...prev, localUser, placeholder]);

    try {
      // Step 1: dispatch the prompt
      const init = await readJson<PromptResponse>(
        await fetch(api("/api/chat/prompt"), {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ threadId, message: trimmed })
        })
      );
      if (!threadId) setThreadId(init.threadId);

      // Step 2: poll the run status
      let polls = 0;
      let finalState = init.status;
      while (!["completed", "failed", "cancelled", "expired"].includes(finalState)) {
        if (polls++ > MAX_POLLS) throw new Error("Timed out waiting for the agent.");
        await delay(POLL_MS);
        const s = await readJson<StatusResponse>(
          await fetch(
            api(`/api/chat/status?threadId=${encodeURIComponent(init.threadId)}&runId=${encodeURIComponent(init.runId)}`)
          )
        );
        finalState = s.status;
      }

      if (finalState !== "completed") {
        throw new Error(`Agent run ${finalState}.`);
      }

      // Step 3: fetch the final transcript
      const payload = await readJson<MessagesResponse>(
        await fetch(api(`/api/chat/messages?threadId=${encodeURIComponent(init.threadId)}`))
      );

      const mapped: ChatMessage[] = payload.messages.map((m) => ({
        id: m.id,
        role: m.role,
        text: m.text
      }));
      setMessages(mapped);
    } catch (e) {
      const msg = e instanceof Error ? e.message : "Unexpected error.";
      setError(msg);
      setMessages((prev) =>
        prev.map((m) =>
          m.pending ? { ...m, pending: false, text: `⚠ ${msg}` } : m
        )
      );
    } finally {
      setIsProcessing(false);
    }
  };

  return { messages, submitPrompt, isProcessing, error };
}
