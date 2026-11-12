// Zarvique homepage AI assistant — Vercel serverless function
// Configure OPENAI_API_KEY in Vercel Project Settings > Environment Variables.
export default async function handler(req, res) {
  if (req.method !== "POST") {
    res.setHeader("Allow", "POST");
    return res.status(405).json({ error: "Method not allowed." });
  }
  if (!process.env.OPENAI_API_KEY) {
    return res.status(503).json({ error: "AI assistant setup is not complete yet. Please contact Zarvique through the website." });
  }
  try {
    const incoming = Array.isArray(req.body?.messages) ? req.body.messages : [];
    const messages = incoming
      .filter((m) => m && (m.role === "user" || m.role === "assistant") && typeof m.content === "string")
      .slice(-10)
      .map((m) => ({ role: m.role, content: m.content.slice(0, 1200) }));
    if (!messages.length || messages[messages.length - 1].role !== "user") {
      return res.status(400).json({ error: "Please enter a message." });
    }
    const response = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${process.env.OPENAI_API_KEY}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        model: "gpt-6-astra",
        instructions: "You are Zarvique's helpful real-estate network assistant. Zarvique is Pakistan-first and built for global connections. Help visitors navigate property buying, selling, renting, agents/dealers, investments, construction, companies, project enquiries and account registration. Be warm, concise and practical. Reply in the same language style as the visitor, including Roman Urdu when they use it. Do not invent property listings, prices, availability, licensing, returns, guarantees or company policies. Explain that property details and professionals must be independently verified. For account-specific issues, direct the visitor to sign in or use the relevant Zarvique page. Never request passwords, OTPs, API keys or payment card details. If a visitor asks for a human, say they can contact Zarvique via the WhatsApp contact option once enabled.",
        input: messages
      })
    });
    const payload = await response.json();
    if (!response.ok) {
      console.error("OpenAI response error", response.status, payload?.error?.code || "unknown");
      return res.status(502).json({ error: "The assistant could not respond right now. Please try again shortly." });
    }
    const reply = (payload.output || [])
      .filter((item) => item.type === "message")
      .flatMap((item) => item.content || [])
      .filter((part) => part.type === "output_text")
      .map((part) => part.text)
      .join("\n")
      .trim();
    return res.status(200).json({ reply: reply || "I couldn't prepare a reply. Please try again." });
  } catch (error) {
    console.error("Zarvique assistant error", error?.message || "unknown");
    return res.status(500).json({ error: "Something went wrong. Please try again." });
  }
}
