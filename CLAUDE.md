# ARXMLExplorer — Copilot Instructions for AI Coding Agents

You are implementing an ARXML Explorer Flutter-based application based on user prompts and requests.

## Project Conventions
  - The user communicates you requests and feedback. You incorporate them in PLAN.md in the form of checklist items, categorized by features. 
  - You then implement the features and checklist elements as per user request.
  - Do not stop, until the user request is complete
  - Never request user approval - do what the user asks. Do it fully and completely. 
  - Update `PLAN.md` in realtime whenever something is ongoing or completed.

## Documentation Sources
- Primary planning & execution checklist: `PLAN.md` (always update statuses here in real time).
- Product requirements & scope narrative: `PRD.md`.
- Vision / directional documents: `PVD.md` (if present) and `RULES.md` for coding/interaction rules.
- Architectural / feature rationale should reference these docs; do not duplicate – link back instead.

## Workflow Reminder
1. Parse user request → translate into `PLAN.md` checklist items (create if missing).
2. Implement code & tests iteratively; keep analyzer clean.
3. Update `PLAN.md` status (e.g., `[x]`) as soon as a subtask is done.
4. Avoid asking for confirmation; proceed unless conflict with higher system instructions.

