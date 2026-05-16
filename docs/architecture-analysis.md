# Architecture Documentation vs Code Analysis

## Summary

The architecture documentation in `docs/architecture.md` is **partially accurate but incomplete**. It correctly identifies the agent-based approach but misses several key components and mischaracterizes the actual implementation.

## Key Findings

### ✅ Accurate Claims

1. **Agent-based architecture exists** - Confirmed via `R/agentic_edit.R` (988 lines), `R/goal_agent.R` (747 lines)
2. **Session state tracking** - Confirmed via `R/session_state.R`, `R/session_edit.R` (24KB), `R/session_methods.R`
3. **Polish pipeline** - Confirmed via `R/figure_polish.R`
4. **Public API entrypoints** - Confirmed via `R/ggai_entry.R`, `R/entrypoints.R`

### ❌ Inaccurate or Incomplete

1. **"Minimal compiler (legacy support)"** - `R/compiler.R` is only 77 lines and handles diagram spec compilation, not legacy layer compilation. The docs overstate its role.

2. **Missing major components**:
   - `R/acquisition_runtime.R` (51KB!) - Data acquisition and context gathering
   - `R/goal_agent.R` (747 lines) - Goal-based agent execution
   - `R/spec_committer_agent.R` - Spec generation agents
   - `R/runtime_contracts.R` (12KB) - Runtime type contracts
   - `R/spec_layer.R` - Schema definitions (not removed as docs suggest)

3. **Agent Tools location** - Docs say `R/agent_tools.R` contains tools like `inspect_data()`, `try_ggplot_code()`, etc. Need to verify these actually exist there.

4. **"Agent Runtime" description** - Docs say `R/agent_runtime.R` is the "central execution engine" but it's only 322 lines. The real execution happens in:
   - `R/agentic_edit.R` (988 lines) - `ggai_agentic_repair_edit()`
   - `R/goal_agent.R` (747 lines) - `ggai_goal_agent_session()`
   - `R/acquisition_runtime.R` (51KB) - Data acquisition

5. **Execution flow** - The documented flow is oversimplified. The actual flow involves:
   - Goal agent for initial session creation
   - Agentic repair edit for iterative edits
   - Acquisition runtime for data/context gathering
   - Multiple validation and repair loops

## Actual Architecture (from code)

### Core Execution Paths

1. **`ggai()` entry** → `ggai_goal_agent_session()` → goal agent with tools
2. **`gg_edit()` session edit** → `ggai_agentic_repair_edit()` → repair agent with validation
3. **`geom_ai()` layer** → `ggai_agentic_repair_edit()` → layer compilation

### Major Components (by size)

| File | Lines | Purpose |
|------|-------|---------|
| `acquisition_runtime.R` | 51KB | Data acquisition, file detection, URL handling |
| `goal_agent.R` | 747 | Goal-based agent execution |
| `agentic_edit.R` | 988 | Agentic repair and validation loop |
| `session_edit.R` | 24KB | Session editing, deterministic patches |
| `figure_polish.R` | 28KB | Polish pipeline |
| `runtime_contracts.R` | 12KB | Type contracts and schemas |

### Missing from Docs

- **Acquisition runtime** - Massive component for context gathering
- **Goal agent** - Separate agent type for initial goal-based execution
- **Spec committer agents** - Agents that generate structured specs
- **Deterministic patches** - Fast path for simple edits without agents
- **Validation and repair loops** - Multi-step validation with automatic repair

## Recommendations

1. **Rewrite architecture.md** to accurately reflect:
   - Three agent types: goal agent, repair agent, spec committer
   - Acquisition runtime as a major component
   - Deterministic patch fast path
   - Validation/repair loop architecture

2. **Add component size context** - The 51KB acquisition runtime is clearly a major piece

3. **Clarify "compiler removed"** - The old style_compiler was removed, but spec compilation still exists via agents

4. **Document the actual execution paths** with code references

5. **Add architecture diagram** showing the three agent types and their interactions
