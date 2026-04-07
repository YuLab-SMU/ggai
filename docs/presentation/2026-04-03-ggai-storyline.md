# ggai Storyline

## One-Sentence Positioning

`ggai` is an AI-native scientific figure system that compiles research intent into publication-style figures, with direct image generation as the primary rendering path and structured specs as the sidecar for control, debugging, and iteration.

## The Problem

The hardest figures in papers and grants are not statistical plots. They are:

- mechanism figures
- workflow overviews
- platform diagrams
- translational medicine summary figures

Today these are still made mostly by hand in PowerPoint, Illustrator, Figma, or BioRender. That workflow is slow, expensive to revise, and disconnected from the scientific logic that the figure is trying to communicate.

## The Core Idea

Instead of treating figures as manual drawings, `ggai` treats them as compiled outputs.

The system takes:

- scientific intent
- object list
- causal and spatial relations
- composition guidance
- style constraints

and turns them into:

- a final direct-image prompt bundle
- multiple generated figure candidates
- an evaluation trace
- a reproducible sidecar artifact

## Why This Is Interesting

This is not just another image prompt wrapper.

`ggai` has three strategic advantages:

1. It is figure-native rather than chatbot-native.
2. It keeps a structured sidecar for inspection, editing, and future tooling.
3. It can serve the specific figure classes that matter in research communication.

## Current Truth

What works well now:

- workflow figures
- platform overview figures
- biomedical mechanism figures
- direct image generation with prompt bundles and candidate selection

What is not done yet:

- precise post-hoc editing of every local element
- robust vector-native editing
- a large biomedical asset library comparable to BioRender
- a production UI

## Why Direct Image Mode Is The Main Route

We tested hybrid composition and learned that asset-by-asset assembly is too fragile and visually inconsistent. The direct image path is now the primary route because it gives:

- stronger global consistency
- better composition
- more BioRender-like visual coherence
- lower engineering complexity for better visual return

## Short-Term Goal

Do not frame `ggai` as “we already replaced BioRender.”

Frame it as:

“We have a working AI-native figure compiler that can already generate compelling scientific overview figures, and we are now optimizing it into a research-grade figure generation workflow.”

## What Support To Ask For

- time to refine direct-image prompts and evaluators
- access to stable model endpoints and better image-model quotas
- 5-10 high-value use cases from internal teams
- permission to build a lightweight internal showcase/gallery
