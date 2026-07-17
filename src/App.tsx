import { useEffect, useRef, useState } from "react";
import { useAgentSession } from "./hooks/useAgentSession";

const AGENT_NAME = (import.meta.env.VITE_AGENT_NAME as string) || "Foundry Agent";

export default function App() {
  const { messages, submitPrompt, isProcessing, error } = useAgentSession();
  const [input, setInput] = useState("");
  const scrollRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight, behavior: "smooth" });
  }, [messages, isProcessing]);

  const send = (e: React.FormEvent) => {
    e.preventDefault();
    submitPrompt(input);
    setInput("");
  };

  return (
    <div className="app">
      <div className="grid-bg" aria-hidden />
      <div className="scanline" aria-hidden />

      <header className="topbar">
        <div className="brand">
          <span className="logo">XIAOCAO</span>
          <span className="sep">//</span>
          <span className="sub">FOUNDRY AGENT TERMINAL</span>
        </div>
        <div className="status">
          <span className={`dot ${isProcessing ? "busy" : "online"}`} />
          <span>{isProcessing ? "PROCESSING" : "ONLINE"}</span>
        </div>
      </header>

      <main className="chat" ref={scrollRef}>
        {messages.length === 0 && (
          <div className="empty">
            <pre className="ascii">
{`  ┌──────────────────────────────┐
  │  CONNECTION ESTABLISHED       │
  │  AGENT: ${AGENT_NAME.padEnd(21).slice(0, 21)}│
  └──────────────────────────────┘`}
            </pre>
            <p>Type a message to engage the agent.</p>
          </div>
        )}

        {messages.map((m) => (
          <div key={m.id} className={`row ${m.role}`}>
            <div className="tag">{m.role === "user" ? "YOU" : "AGENT"}</div>
            <div className={`bubble ${m.role}`}>
              {m.pending ? <span className="typing">▋ thinking</span> : m.text}
            </div>
          </div>
        ))}
      </main>

      {error && <div className="error">! {error}</div>}

      <form className="composer" onSubmit={send}>
        <span className="prompt-char">&gt;</span>
        <input
          value={input}
          onChange={(e) => setInput(e.target.value)}
          placeholder="enter command..."
          autoFocus
          disabled={isProcessing}
        />
        <button type="submit" disabled={isProcessing || !input.trim()}>
          SEND
        </button>
      </form>
    </div>
  );
}
