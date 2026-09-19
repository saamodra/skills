---
name: editorial-imagegen
description: Create or revise clean editorial infographics, visual explainers, comparison graphics, timelines, and social-media images that feel deliberately designed rather than AI-illustrated. Use when the user wants an image with clear information hierarchy, restrained Figma-like styling, accurate labels or numeric relationships, and no cute mascots, generic characters, glossy 3D art, or decorative AI-looking clutter.
---

# Editorial Imagegen

Turn the user's idea into an immediately understandable visual while preserving the information that makes the idea useful. Aim for an art-directed editorial graphic, not an empty minimalist poster and not a generated cartoon.

## Visual direction

- Prefer typography, grids, lines, bars, markers, cards, arrows, and simple geometric shapes.
- Use strong hierarchy, deliberate alignment, generous but functional whitespace, and a restrained palette with one accent color.
- Keep concrete labels, times, numbers, comparisons, and relative positions when they explain the idea. Do not simplify away the mechanism.
- Use flat colors and modest corner radii by default.
- Avoid cute humans, robots, mascots, expressive characters, stock-style scenes, emoji, glossy effects, pseudo-3D, gradients, excessive pills, decorative scribbles, and arbitrary icons unless the user explicitly asks for them.
- Avoid visuals that are technically clean but lifeless. Preserve an interesting composition, contrast, and a clear focal point.

## Workflow

1. Identify the single idea the image must communicate at a glance.
2. Choose the smallest visual structure that explains it: comparison, timeline, flow, or annotated composition.
3. Draft concise exact text. Prefer short Indonesian labels when the user writes in Indonesian.
4. Specify spatial relationships precisely. Equal quantities must have equal visual lengths; time markers and sequences must be positioned accurately.
5. Generate a square composition by default for social threads unless the user requests another format.
6. Inspect the result for text accuracy, alignment, information loss, and common AI-looking artifacts.
7. If the result violates the direction, make one targeted revision. Remove unwanted decoration without flattening the useful explanation.

## Prompt construction

Describe the deliverable as a `square editorial infographic designed in Figma` and state the information structure before colors or decoration. Quote all required on-image text verbatim. Include the concrete constraints that matter for the subject.

Use an avoid list similar to:

`no characters, mascots, cute robots, stock illustrations, emoji, 3D, gradients, shadows, glossy effects, hand-drawn decoration, watermark, or extra text`

Adapt the list when the user intentionally requests one of those elements.

## Revision rule

When revising an existing image, preserve the parts the user says are working. Change only the visual language or specific defect they called out. If the explanation is already easy to understand, do not replace it with a more abstract design merely to make it cleaner.
