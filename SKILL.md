---
name: sparring
description: |
  Adversarial sparring between two AI models — advocate vs critic, up to 6 structured rounds.
  Default: Claude Opus (advocate) vs GPT (critic). Both sides fully configurable.
  Triggers: "sparring", "디베이트", "토론해봐", "GPT랑 토론", "비판적으로 검토해줘",
  "찬반 토론", "반론 받아봐", "argue both sides", "stress-test this idea"
allowed-tools:
  - Bash
  - Read
  - Glob
  - WebSearch
---

# claude-code-sparring

Adversarial sparring between two AI models. One argues your position. The other attacks it.
Current session moderates, detects convergence, and synthesizes the final verdict.

**Default pairing** — Claude Opus (advocate) vs GPT (critic). Both are configurable.

| Role | Default | Override |
|------|---------|---------|
| 🟢 Advocate | Claude Opus (`delegate_task` or `ANTHROPIC_API_KEY`) | `SPARRING_ADVOCATE_BACKEND` |
| 🔴 Critic | GPT (`codex` CLI or `OPENAI_API_KEY`) | `SPARRING_CRITIC_BACKEND` |
| ⚪ Moderator | Current session | — |

**Advocate call** (Claude Code): `delegate_task`
**Advocate call** (API fallback): `bash ~/.claude/skills/sparring/bin/advocate.sh "<prompt>"`
**Critic call**: `bash ~/.claude/skills/sparring/bin/ask.sh "<prompt>"`

> Auto-detection order — Advocate: `delegate_task` → `ANTHROPIC_API_KEY` → `OPENAI_API_KEY` → `GOOGLE_API_KEY`
> Auto-detection order — Critic: `codex` CLI → `OPENAI_API_KEY` → `agy` CLI → `GOOGLE_API_KEY`
> Override: `export SPARRING_ADVOCATE_BACKEND=anthropic`, `export SPARRING_CRITIC_BACKEND=gemini`, etc.

---

## Protocol

### 0. Init

- Format: `debate [topic]`. No topic → ask in one line.
- Check which backends are available: run `bash ~/.claude/skills/sparring/bin/ask.sh "ping" 2>&1` to verify critic.
- **Sensitive data**: Never send personal financials, contracts, or private strategy to external models. Anonymize.
- Init transcript: `/tmp/sparring_[timestamp].md`

---

### 1. 🔍 Research Phase — Fight Prep (Required Before Round 1)

**Goal**: Understand the user's actual position so the advocate argues *their* case, not a generic one.

#### 1-A. Domain Classification

Classify the topic keyword into a domain, then scan the user's relevant workspace:

| Domain | Example Keywords | Where to Look First |
|--------|-----------------|---------------------|
| Finance / Investment | stocks, crypto, portfolio, leverage, ETF | finance/investment folders |
| Work / Career | job, startup, product, strategy, launch | work/project folders |
| Technology | AI, automation, code, system, infra | tech/engineering folders |
| Creative / Art | music, design, content, brand, release | creative folders |
| Legal / Contract | agreement, IP, dispute, rights, terms | legal folders |
| Personal / Life | health, relationship, move, decision | personal folders |
| Complex / Mixed | — | decisions log + memory first |

> **No hardcoded paths.** Explore the actual folder tree — read CLAUDE.md of relevant folders first, then discover files dynamically.

#### 1-B. Workspace Scan (Dynamic)

Traverse relevant folders based on domain. **Never use a fixed file list — find files by exploring.**

```
1. Read CLAUDE.md of the relevant domain folder (if exists)
2. List files → open the most topic-relevant ones
3. Follow cross-references to other folders
4. Find the decisions log → what's already settled (don't re-argue these)
5. Find the feedback/patterns log → what the user has rejected before (avoid dead ends)
6. Find the memory/context file → current status and active issues
```

#### 1-C. Conversation Context

Note everything the user has said in this session — premises, preferences, stated opinions. Session context beats file content for recency.

#### 1-D. External Research (Topic-Dependent)

If the topic touches the outside world, **web search is mandatory**. Internal files alone give half-arguments.

- Finance/market: current market data, analyst views, recent news
- Tech/trends: latest landscape, competitor moves, published benchmarks
- Legal: relevant statutes, precedents, industry norms
- General: fact-check any numbers or claims

After searching: **cite sources explicitly** — anticipate the critic attacking with the same data.

#### 1-E. Context Brief Synthesis

Synthesize everything into a brief passed verbatim to the advocate:

```
[USER CONTEXT BRIEF]
- Who this person is: (role, situation, relevant background)
- Their current position on this topic: (from workspace + conversation)
- What's already decided: (from decisions log — not up for debate)
- Their values/principles relevant to this topic: (from feedback/identity files)
- Current constraints or active issues: (from memory/context files)
- External data (if applicable): (key findings from web search)
- Anticipated critic attack vectors: (honest assessment of weak points)
```

#### 1-F. Agenda Refinement + Confirm

Sharpen the user's rough topic into **one precise debatable sentence**.

Output to user:
```
📋 Research complete.

Scanned:
- Workspace: [files read, briefly]
- Web: [search queries / "none"]
- Session context: applied

Refined agenda:
"[one sharp sentence]"

Advocate: [detected advocate] — Critic: [detected critic]
Start debate?
```

Wait for confirmation. Revise if requested.

---

### 2. Debate Start

```
Debate starting.
Agenda: [refined agenda]
Advocate: [model] — Critic: [model] — max 6 rounds
```

---

### 3. Round 1 — Advocate Opening

**Option A — Claude Code (delegate_task):**
```
delegate_task goal="
DEBATE AGENDA: [refined agenda]

[USER CONTEXT BRIEF — paste full block from 1-E]

Your role: be this person's advocate. Defend this agenda forcefully.
- Build 3–5 arguments grounded in THIS person's actual values, context, and situation.
- No generic reasoning. Every argument must connect to their specific circumstances.
- Anticipate the critic's likely attacks on the weak points listed above and pre-empt them.
- Be logical, concrete, and combative.
"
```

**Option B — API fallback (advocate.sh):**
```bash
bash ~/.claude/skills/sparring/bin/advocate.sh "
DEBATE AGENDA: [refined agenda]

[USER CONTEXT BRIEF — paste full block from 1-E]

Your role: be this person's advocate. Defend this agenda forcefully.
- Build 3–5 arguments grounded in THIS person's actual values, context, and situation.
- No generic reasoning. Every argument must connect to their specific circumstances.
- Anticipate the critic's likely attacks on the weak points listed above and pre-empt them.
- Be logical, concrete, and combative.
"
```

### 4. Round 1 — Critic Attack

```bash
bash ~/.claude/skills/sparring/bin/ask.sh "
You are a relentless adversarial critic in Round 1 of max 6.

DEBATE TOPIC: [agenda]

ADVOCATE'S POSITION:
[advocate response summary]

Your ONLY role: challenge the advocate's position. Be sharp, specific, aggressive.
Find risks, blind spots, hidden assumptions, edge cases, counter-examples.
Rounds 1-3: Never signal convergence. Always find new objections.
"
```

### 5. Rounds 2–6 — Exchange Loop

Each round:

**Step A — Advocate Rebuttal** (use delegate_task or advocate.sh, same as Round 1):
```
Rebut the critic's argument below. Defend your position.
(Allowed to refine position if critique lands — but hold your core stance)

CRITIC:
[critic response]

Prior round key points:
[prior round summary]
```

**Step B — Critic Counter:**
```bash
bash ~/.claude/skills/sparring/bin/ask.sh "
Round [N] of max 6.

ADVOCATE'S REBUTTAL:
[advocate response summary]

TRANSCRIPT SO FAR:
[running summary of key points]

Rules:
- Rounds 1–4: Never signal convergence. Always find new objections.
- Round 5+: If you genuinely have NO remaining significant objections,
  start your response with 'CONVERGENCE:' followed by any final minor concerns.
- Otherwise continue attacking.
"
```

**Step C — Convergence Check** (moderator judgment):
- Critic response starts with `CONVERGENCE:` → end loop
- 6 rounds exceeded → force end
- Same point repeated 3+ rounds → moderator may end early

### 6. Final Synthesis (Moderator)

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
## Debate Result — [topic]

### Participants
- Advocate: [model used]
- Critic: [model used]
- Moderator: [current session model]
- Total rounds: [N]

### Points of Agreement
- [what both sides accepted]

### Advocate Position Evolution
- Opening: [round 1 stance]
- Final: [final stance — highlight what changed]

### Points Critic Conceded
- [arguments critic accepted or failed to rebut]

### Remaining Disagreements
- [what stayed unresolved]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
## Final Verdict

[3–5 sentences. The debate-tested position + core reasoning.]

**Evidence:**
1. [point 1 — critic conceded or failed to rebut]
2. [point 2 — strengthened through debate]
3. [point 3 — reached by both sides]

**Caveats:**
- [conditions the verdict depends on]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Constraints

- **Sensitive data**: anonymize before sending to external models.
- **Position evolution**: allowed. Sound critique should refine the advocate's stance.
- **No early convergence**: minimum 4 rounds. Never end before round 3.
- **No critic paraphrasing**: quote critic's key sentences verbatim.
- **Transcripts**: append every round to `/tmp/sparring_[timestamp].md`
