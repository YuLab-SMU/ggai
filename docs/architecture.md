# ggai Architecture

## Overview

ggai uses a **multi-agent architecture** with four specialized agent types that work together to transform natural-language instructions into validated visualizations. Each agent type has distinct tools, execution patterns, and responsibilities:

- **Goal Agent** - Autonomous completion of natural-language visualization goals
- **Repair Agent** - Iterative plot editing and refinement with validation loops
- **Spec Committer Agent** - Structured spec generation (layers, diagrams, annotations)
- **Acquisition Agent** - Data acquisition and context gathering

All agents execute through the aisdk runtime, use bounded execution with decision gates, and validate outputs before committing results.

## Agent Types

### 1. Goal Agent

**Purpose:** Completes natural-language visualization goals autonomously by executing R code in a persistent session.

**Location:** `R/goal_agent.R` (747 lines)

**Entry Point:** `ggai("natural language goal")` when input is a plain string

**Key Characteristics:**
- Executes R code in a persistent `goal` scope via `ggai_execute_goal_code` tool
- Manages a todo-list plan with status tracking (pending, current, done, blocked)
- Can fetch/parse files, create/transform data, draft plots, and iterate
- Must commit a validated ggplot by calling `ggai_commit_goal_plot()` inside R code
- Returns a `ggai_session` with the committed plot and full metadata

**Tools (4):**
1. `ggai_execute_goal_code` - Execute R code in persistent goal session
2. `ggai_update_goal_plan` - Update user-visible todo list
3. `ggai_inspect_goal_executions` - Review execution history and budget
4. `ggai_declare_goal_blocker` - Declare goal cannot be completed

**Execution:**
- Max steps: 100 (configurable via `ggai.goal_agent_max_steps`)
- Execution budget: Inf (configurable via `ggai.goal_agent_execution_budget`)
- Decision slack: 4 (configurable via `ggai.goal_agent_decision_slack`)

**Output:** `ggai_session` with committed plot, code, data references, and execution trace

**Example Flow:**
```r
ggai("make a scatter plot of mtcars mpg vs wt")
  ↓
ggai_goal_agent_session()
  ↓ Agent executes R code
  ↓ Agent calls ggai_commit_goal_plot(plot=p, ...)
  ↓
Returns ggai_session
```

---

### 2. Repair Agent

**Purpose:** Iteratively edits and refines plots through validated R code candidates with automatic repair loops.

**Location:** `R/agentic_edit.R` (988 lines)

**Entry Points:**
- `gg_edit(session, instruction)` - Edit existing session
- `ggai(plot, instruction)` - Edit existing plot
- `ggai("@data instruction")` - Create initial plot from data

**Key Characteristics:**
- Executes bounded R code via `ggai_try_plot_code` tool
- Stores candidates with validation status (ok/error)
- Implements decision gates to prevent infinite loops
- Auto-commits best validation-ok candidate if agent stops before explicit commit
- Returns compiled spec with validated plot

**Tools (5):**
1. `ggai_inspect_current_plot` - Inspect current plot state and context
2. `ggai_try_plot_code` - Execute and validate R code candidate
3. `ggai_inspect_plot_attempts` - Review attempt history and repeated signatures
4. `ggai_declare_plot_blocker` - Declare task cannot be completed
5. `ggai_commit_plot_candidate` - Commit a validation-ok candidate

**Execution:**
- Max steps: 100 (configurable via `ggai.agentic_edit_max_steps`)
- Valid candidate budget: 4 (configurable via `ggai.agentic_valid_candidate_budget`)
- Attempt budget: 16 (configurable via `ggai.agentic_candidate_attempt_budget`)
- Auto-commit: TRUE (configurable via `ggai.agentic_auto_commit_valid_candidates`)

**Output:** Compiled spec with validated plot, validation details, and repair metadata

**Example Flow:**
```r
gg_edit(session, "make the points larger")
  ↓
ggai_agentic_repair_edit()
  ↓ Agent inspects current plot
  ↓ Agent tries code candidates
  ↓ Each candidate validated (ok/error)
  ↓ Decision gates check budgets
  ↓ Agent commits or auto-commits best candidate
  ↓
Returns compiled spec → session updated
```

---

### 3. Spec Committer Agent

**Purpose:** Generates structured specs (layer, diagram, annotation) via schema-validated commits.

**Location:** `R/spec_committer_agent.R` (116 lines)

**Entry Point:** Internal compilation workflows (not user-facing)

**Key Characteristics:**
- Has exactly one primary tool: `ggai_commit_<kind>_spec` (dynamically named)
- Reads instruction and context, calls commit tool with complete spec
- If commit returns issues, calls again with corrected spec
- Stops once commit returns `status="committed"`
- Does not call unrelated tools or emit text

**Tools (1 dynamic):**
- `ggai_commit_<kind>_spec` - Validate and commit spec (kind = layer, diagram, glyph, etc.)

**Execution:**
- Max steps: 6 (configurable via `ggai.spec_committer_max_steps`)
- Schema validation: Required before commit
- Normalization: Applied via kind-specific normalize function

**Output:** Committed spec with validation status

**Example Flow:**
```r
compile_layer_spec(instruction, context, model)
  ↓
ggai_run_spec_committer_agent()
  ↓ Agent reads instruction and context
  ↓ Agent calls ggai_commit_layer_spec(spec=...)
  ↓ Validates against schema
  ↓ Returns status="committed" or "rejected"
  ↓
Returns compiled spec
```

---

### 4. Acquisition Agent

**Purpose:** Acquires data for visualization goals when source data is not directly available.

**Location:** `R/acquisition_runtime.R` (51,828 bytes / ~1,400 lines)

**Entry Point:** Internal data acquisition workflows (currently not exposed in user-facing `ggai()`)

**Key Characteristics:**
- Runs bounded R steps or calls configured acquisition tools
- Can read URLs, detect file paths, parse data files
- Returns either a validated data frame or a reference brief with seed data
- Auto-commits best candidate if agent stops before explicit commit

**Tools (9):**
1. `ggai_inspect_acquisition_context` - Inspect goal and acquisition context
2. `ggai_inspect_acquisition_session` - Inspect acquisition session state
3. `ggai_run_acquisition_step` - Execute bounded R code step
4. `ggai_read_url` - Read content from URL
5. `ggai_list_acquisition_tools` - List available acquisition tools
6. `ggai_run_acquisition_tool` - Run configured acquisition tool
7. `ggai_try_acquisition_code` - Try R code for data acquisition
8. `ggai_commit_acquired_data` - Commit validated data frame
9. `ggai_commit_reference_brief` - Commit reference brief with seed data
10. `ggai_declare_acquisition_blocker` - Declare data cannot be acquired

**Execution:**
- Max steps: 100 (configurable)
- Acquisition budget: Configurable per tool
- Persistent session scope: "acquisition"

**Output:** Data frame, reference brief, or blocker

**Example Flow:**
```r
ggai_acquire_goal_data(goal, model, tools)
  ↓
ggai_agentic_acquire_goal_data()
  ↓ Agent inspects context
  ↓ Agent runs acquisition steps or tools
  ↓ Agent commits data or reference brief
  ↓
Returns acquired data or brief
```

---

## Agent Tools

### Repair Agent Tools (5 tools)

Defined in `R/agentic_edit.R` (lines 604-748):

1. **`ggai_inspect_current_plot`**
   - Parameters: None
   - Returns: Instruction, data summary, plot context
   - Use: Inspect current state before proposing code

2. **`ggai_try_plot_code`**
   - Parameters: `code` (required), `rationale` (optional)
   - Returns: Candidate response with validation status
   - Use: Execute and validate R code candidate
   - Implements decision gate check

3. **`ggai_inspect_plot_attempts`**
   - Parameters: `max_attempts` (optional, default 12)
   - Returns: Attempt history with validation status and repeated signatures
   - Use: Decide whether to continue or commit

4. **`ggai_declare_plot_blocker`**
   - Parameters: `reason` (required), `evidence` (optional), `next_step` (optional)
   - Returns: Blocker declaration
   - Use: Declare task cannot be completed

5. **`ggai_commit_plot_candidate`**
   - Parameters: `candidate_id` (required), `completion_summary` (required), `remaining_risks` (optional)
   - Returns: Validation details
   - Use: Commit a validation-ok candidate
   - Validates summary is final (not exploratory/partial)

### General Agent Tools (17 tools)

Defined in `R/agent_tools.R` (lines 148-442):

1. **`ggai_data_profile`** - Profile data frame columns with statistics
2. **`ggai_plot_inspection`** - Inspect plot context, mappings, layers, spec history
3. **`ggai_session_inspection`** - Inspect ggai session context
4. **`ggai_stat_method_selection`** - Select statistical methods for data
5. **`ggai_package_check`** - Check if R package is available
6. **`ggai_package_install`** - Handle CRAN package installation per policy
7. **`ggai_help_inspection`** - Inspect R help for package topics
8. **`ggai_examples_inspection`** - Inspect R examples for package topics
9. **`ggai_vignette_index`** - List installed vignettes
10. **`ggai_source_url_detection`** - Detect URLs in text
11. **`ggai_github_inspection`** - Inspect GitHub repos without live network
12. **`ggai_local_file_listing`** - List bounded local source files
13. **`ggai_local_file_reading`** - Read bounded local source files
14. **`ggai_source_summary`** - Summarize source evidence records
15. **`ggai_diagram_compilation`** - Compile diagram specs
16. **`ggai_plot_validation`** - Build and validate ggplot
17. **`ggai_artifact_recording`** - Record artifacts in session

### Goal Agent Tools (4 tools)

Defined in `R/goal_agent.R` (lines 349-464):

1. **`ggai_execute_goal_code`**
   - Parameters: `code` (required), `rationale` (optional), `preview_n` (optional)
   - Returns: Execution summary with status/error/result
   - Use: Execute R in persistent goal session scope
   - Captures output, tracks execution budget

2. **`ggai_update_goal_plan`**
   - Parameters: `items` (required), `statuses` (optional), `note` (optional)
   - Returns: Plan update confirmation
   - Use: Update user-visible todo list
   - Renders plan to console/markdown

3. **`ggai_inspect_goal_executions`**
   - Parameters: `max_executions` (optional, default 8)
   - Returns: Execution history with budget tracking
   - Use: Review execution history

4. **`ggai_declare_goal_blocker`**
   - Parameters: `reason` (required), `evidence` (optional), `next_step` (optional)
   - Returns: Blocker declaration
   - Use: Declare goal cannot be completed

### Context Tools (dynamic)

Integrated via `R/context_bridge.R` (lines 167-187):

- **`create_r_context_tools()`** - R-specific context tools from aisdk
- **`create_context_query_tools(session)`** - Session-specific query tools

Context tools are dynamically added and merged with agent-specific tools at runtime.

---

## Execution Flows

### Flow 1: Natural-Language Goal → Goal Agent

```
ggai("make a scatter plot of mtcars mpg vs wt")
  ↓
ggai.character() [R/ggai_entry.R:660]
  ↓
ggai_goal_agent_session() [R/goal_agent.R]
  ├─ Creates aisdk shared session with goal scope
  ├─ Binds ggai_commit_goal_plot() callback
  ├─ Creates agent with 4 goal tools + context tools
  ├─ Runs agent loop (max_steps = 100)
  │  ├─ Agent executes R code via ggai_execute_goal_code
  │  ├─ Agent updates plan via ggai_update_goal_plan
  │  └─ Agent calls ggai_commit_goal_plot(plot=p, ...)
  ├─ Validates committed plot
  └─ Returns ggai_session with plot and metadata
```

### Flow 2: Session Edit → Repair Agent

```
gg_edit(session, "make the points larger")
  ↓
ggai_agentic_repair_edit() [R/agentic_edit.R:789]
  ├─ Creates aisdk shared session with context
  ├─ Registers context objects (data, plot, mentions)
  ├─ Creates agent with 5 repair tools + context tools
  ├─ Runs agent loop (max_steps = 100)
  │  ├─ Agent inspects via ggai_inspect_current_plot
  │  ├─ Agent tries code via ggai_try_plot_code
  │  ├─ Each candidate validated (ok/error)
  │  ├─ Decision gates check budgets (4 valid, 16 attempts)
  │  └─ Agent commits via ggai_commit_plot_candidate
  ├─ Auto-commits best candidate if no explicit commit
  ├─ Returns compiled spec with validated plot
  └─ gg_edit() appends entry to session history
```

### Flow 3: Direct Plot Edit → Repair Agent

```
ggai(ggplot_object, "add a title")
  ↓
ggai.ggplot() [R/ggai_entry.R:742]
  ├─ Starts session from plot
  └─ Calls gg_edit(session, instruction)
    ↓
    [Same as Flow 2]
```

### Flow 4: Data-Grounded Plot → Repair Agent

```
ggai("@my_data scatter plot of x vs y")
  ↓
ggai.character() [R/ggai_entry.R:618]
  ├─ Resolves @my_data mention from parent environment
  ├─ Extracts data frame
  └─ Calls ggai_session_from_data_frame()
    ↓
    build_agentic_initial_session()
      ├─ Creates base ggplot(data=data)
      ├─ Calls ggai_agentic_repair_edit() with instruction
      └─ Returns session with initial plot
```

---

## Core Components

### File Organization

```
R/
├── goal_agent.R (747 lines)           # Goal agent implementation
├── agentic_edit.R (988 lines)         # Repair agent implementation
├── acquisition_runtime.R (51KB)       # Data acquisition runtime
├── spec_committer_agent.R (116 lines) # Spec generation agents
├── agent_tools.R (443 lines)          # General agent tools
├── agent_runtime.R (322 lines)        # Agent execution utilities
├── session_state.R (158 lines)        # Session state management
├── session_edit.R (24KB)              # Session editing and patches
├── session_methods.R (5KB)            # Session methods (print, plot, etc.)
├── figure_polish.R (28KB)             # Polish pipeline
├── figure_generation.R (8KB)          # Generation modes
├── runtime_contracts.R (12KB)         # Type contracts and schemas
├── ggai_entry.R (25KB)                # Public API entry points
├── entrypoints.R (2KB)                # Layer/diagram entry points
├── compiler.R (77 lines)              # Diagram spec compilation
├── spec_layer.R (22 lines)            # Schema definitions
├── context_bridge.R (5KB)             # Context tool integration
├── ai_bridge.R (8KB)                  # AI SDK bridge
└── validation_tools.R (5KB)           # Validation and repair utilities
```

### Major Components by Size

| Component | Size | Purpose |
|-----------|------|---------|
| `acquisition_runtime.R` | 51KB | Data acquisition, file detection, URL handling |
| `figure_polish.R` | 28KB | Polish pipeline for publication-quality images |
| `ggai_entry.R` | 25KB | Public API entry points and mention resolution |
| `session_edit.R` | 24KB | Session editing, deterministic patches (removed) |
| `runtime_contracts.R` | 12KB | Type contracts, schemas, validation |
| `agentic_edit.R` | 988 lines | Repair agent with validation loops |
| `goal_agent.R` | 747 lines | Goal agent with persistent R session |

---

## Validation and Repair

### Decision Gates

Repair agents implement decision gates to prevent infinite loops:

- **Valid candidate budget:** 4 (configurable via `ggai.agentic_valid_candidate_budget`)
- **Attempt budget:** 16 (configurable via `ggai.agentic_candidate_attempt_budget`)

When either budget is reached, the agent must commit or declare a blocker.

### Validation Flow

1. **Agent tries code** via `ggai_try_plot_code`
2. **Code executed** in isolated environment with ggplot2 namespace
3. **Plot validated** via `ggplot2::ggplot_build()` + `ggplot2::ggplotGrob()`
4. **Candidate stored** with status (ok/error), signature, rationale
5. **Decision gate checks** budgets and repeated signatures
6. **Agent commits** via `ggai_commit_plot_candidate` or declares blocker

### Code Safety

Code execution is protected by `ggai_assert_safe_plot_code()`:

**Forbidden operations:**
- System calls (`system`, `system2`)
- File I/O (`write`, `save`, `saveRDS`)
- Package installation (`install.packages`)
- Source loading (`source`)
- Directory changes (`setwd`)
- Triple-colon access (`:::`)

Code is evaluated in an isolated environment with only ggplot2 namespace available.

### Auto-Commit

If the agent stops without explicit commit but has validation-ok candidates:

1. Selects last code-source candidate (or last valid candidate)
2. Auto-commits if `ggai.agentic_auto_commit_valid_candidates` is TRUE (default)
3. Records auto-commit in metadata

This ensures users get a result even if the agent doesn't explicitly commit.

### Runtime Repair

Post-render validation can trigger automatic repairs:

- **`ggai_repair_invalid_manual_scale()`** - Drops empty manual scales
- **`ggai_repair_discrete_scale_mapping()`** - Converts numeric columns to factors

These are applied after rendering, not during compilation.

---

## Configuration Options

### Agent Execution

- `ggai.agentic_edit` - Enable/disable agentic edit (default: TRUE)
- `ggai.agentic_edit_max_steps` - Max agent steps (default: 100)
- `ggai.agentic_edit_run_args` - Additional run args (default: list())
- `ggai.agentic_tool_log_mode` - Logging mode: quiet/compact/detailed/inherit (default: quiet)

### Repair Agent Budgets

- `ggai.agentic_valid_candidate_budget` - Valid candidate limit (default: 4)
- `ggai.agentic_candidate_attempt_budget` - Attempt limit (default: 16)
- `ggai.agentic_auto_commit_valid_candidates` - Auto-commit (default: TRUE)

### Goal Agent

- `ggai.goal_agent_max_steps` - Max agent steps (default: 100)
- `ggai.goal_agent_execution_budget` - Execution limit (default: Inf)
- `ggai.goal_agent_decision_slack` - Decision buffer (default: 4)

### Spec Committer

- `ggai.spec_committer_max_steps` - Max agent steps (default: 6)

### Model-Specific

- `ggai.deepseek_disable_thinking_for_tools` - Disable thinking for tool calls (default: TRUE)

---

## Historical Context

### Deterministic Patches (Removed in commit d21d873)

Prior to commit d21d873, `gg_edit()` had a **three-tier fallback hierarchy**:

1. **Deterministic patch** - Pattern-matched edits (6 types)
2. **Deterministic style** - Style-only modifications (never implemented)
3. **Agent-based compilation** - Full LLM-based compilation (fallback)

**Deterministic patch types:**
- Rect outline patch ("outline only", "no fill")
- Colour patch ("green", "red", "blue", "teal")
- Alpha patch ("transparent", "opaque")
- Linewidth patch ("thicker", "thinner")
- Text size patch ("smaller", "larger")
- Text position patch ("up", "down", "left", "right")

**Why removed:**
- **Maintenance burden** - 6 pattern-matching functions with hardcoded regex
- **Limited scope** - Only handled ~6 specific edit types
- **Inconsistent UX** - Users couldn't predict which edits were "fast"
- **Agent reliability** - Modern LLMs reliable enough to not need fallbacks
- **Cleaner architecture** - Single, well-defined path easier to reason about

**Current approach:** All edits route through agents exclusively. The deterministic patch functions remain in `R/session_edit.R` (lines 163-333) as dead code for historical reference.

### Compiler Runtime Removal (commit eb6fdf7)

Commit eb6fdf7 removed ~1,600 lines including:

- **Style compiler** - Predefined style transformations
- **Spec layer operations** - Fixed operation schemas
- **Direct compiler edit path** - Non-agent compilation

**Replaced by:** Agent-based execution with validation loops, flexible tool use, and natural error handling.

**Rationale:** User requests require arbitrary ggplot grammar (scales, facets, coords, guides). Enumerating all operations turns the runtime into schema maintenance. Agents handle novel combinations and edge cases through code generation and validation.

---

## Extension Points

### Adding New Agent Tools

1. Define tool function in appropriate file (`agent_tools.R`, `agentic_edit.R`, etc.)
2. Add tool to agent initialization function
3. Document tool behavior in system prompt
4. Test tool with agent execution

### Adding New Agent Types

1. Create agent-specific file (e.g., `R/new_agent.R`)
2. Define agent tools and system prompt
3. Implement agent session function
4. Add entry point in `R/ggai_entry.R` or appropriate location
5. Document agent type in this file

### Adding New Validation Rules

1. Add validation function in `R/validation_tools.R`
2. Integrate into `ggai_validate_session_artifact()` or `ggai_validate_and_repair()`
3. Add corresponding repair function if applicable
4. Test validation with known failure cases

---

## See Also

- [Quick Start FAQ](ggai-agentic-quickstart-faq.md) - Model setup, debugging, common issues
- [Usage Scenarios](usage-scenarios/) - Six runnable examples
- [Case Studies](cases/) - Real-world analysis pipelines
