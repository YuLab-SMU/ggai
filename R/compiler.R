ggai_diagram_committer_system_body <- function() {
  paste(
    "You are a diagram scene designer.",
    "Translate the instruction into a strict JSON scene specification for a diagram canvas.",
    "",
    "Rules:",
    "- Prefer simple nodes and edges with explicit coordinates when the instruction demands exact placement.",
    "- If the instruction describes order, lanes, stages, pipeline flow, grouped modules, or dependencies but not exact coordinates, use `layout` hints and let the renderer auto-layout the scene.",
    "- Prefer the layout DSL keys `stage`, `lane`, `group`, `order`, `after`, `before`, `row`, `column`, `align`, `center_on` instead of inventing ad hoc fields.",
    "- Use `canvas.layout.engine = \"constraint\"` for stage/dependency-based layouts and `canvas.layout.engine = \"grid\"` for matrix-like arrangements.",
    "- Use `canvas.layout.distribute` when evenly spacing nodes along an axis is more natural than hard-coding positions.",
    "- Use generated assets only as references, never inline image bytes.",
    sep = "\n"
  )
}

compile_diagram_spec <- function(instruction,
                                 scene_context = list(),
                                 model = NULL,
                                 registry = NULL,
                                 skills = NULL,
                                 skill_registry = NULL,
                                 skill_path = NULL,
                                 ...) {
  ggai_run_spec_committer_agent(
    kind = "diagram",
    instruction = instruction,
    system_body = ggai_diagram_committer_system_body(),
    schema = z_ggai_diagram_spec(),
    context = scene_context,
    context_label = "Scene context",
    normalize = normalize_diagram_spec_body,
    validate = validate_diagram_spec_body,
    model = model,
    registry = registry,
    skills = skills,
    skill_registry = skill_registry,
    skill_path = skill_path
  )
}

ggai_glyph_committer_system_body <- function() {
  paste(
    "You are a glyph asset planner.",
    "Translate the instruction into a strict JSON glyph specification for a generated visual asset.",
    "",
    "Rules:",
    "- Keep prompts short, concrete, and stylistically coherent.",
    "- Generated glyphs are local reusable assets, not full-plot renders.",
    sep = "\n"
  )
}

compile_glyph_spec <- function(instruction,
                               glyph_context = list(),
                               model = NULL,
                               registry = NULL,
                               skills = NULL,
                               skill_registry = NULL,
                               skill_path = NULL,
                               ...) {
  ggai_run_spec_committer_agent(
    kind = "glyph",
    instruction = instruction,
    system_body = ggai_glyph_committer_system_body(),
    schema = z_ggai_glyph_spec(),
    context = glyph_context,
    context_label = "Glyph context",
    normalize = normalize_glyph_spec_body,
    validate = validate_glyph_spec_body,
    model = model,
    registry = registry,
    skills = skills,
    skill_registry = skill_registry,
    skill_path = skill_path
  )
}
