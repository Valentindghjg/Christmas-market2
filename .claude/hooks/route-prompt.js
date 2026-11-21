// UserPromptSubmit hook: makes the chat classify every message for model routing
// (CLAUDE.md, "Plan, implement, verify"). Hooks cannot switch models themselves;
// the skills cm2-plan (Opus 5.5 high) and cm2-task (Sonnet 5.5) do the switch.
let raw = "";
process.stdin.on("data", (chunk) => (raw += chunk));
process.stdin.on("end", () => {
	let prompt = "";
	try {
		prompt = String(JSON.parse(raw).prompt || "");
	} catch (_) {}
	if (prompt.trim().startsWith("/")) return; // explicit slash command: nothing to add
	const context = [
		"Model routing (CLAUDE.md, owner rule). Before you answer this message, classify it:",
		"- Planning (design, decisions, spec, backlog, priorities, balancing, art direction, workflow, \"how should this work\"): invoke the skill cm2-plan first.",
		"- Work that changes code, tests, models or the map, or carries out a plan: invoke the skill cm2-task first.",
		"- A short question or conversation: neither skill.",
	].join("\n");
	process.stdout.write(
		JSON.stringify({ hookSpecificOutput: { hookEventName: "UserPromptSubmit", additionalContext: context } })
	);
});
