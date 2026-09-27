# Alberta Game Jam 2026

Shared Godot project for Alberta Game Jam 2026.

## Setup

1. Install **Godot 4.x** and **GitHub Desktop**.
2. Clone this repository in GitHub Desktop.
3. In Godot, choose **Import** and select `project.godot`.
4. Before starting work, **Pull** the latest changes.
5. When finished with a small piece of work, **Commit** it with a clear message and **Push**.

## Team workflow

For a two-person game jam, keep the workflow simple:

**Pull → Work → Save → Commit → Push**

Try not to edit the same `.tscn` scene at the same time. Tell the other person which scene you are working on before making large scene changes.

Prefer small reusable scenes such as:

- `scenes/player/player.tscn`
- `scenes/enemies/`
- `scenes/levels/`
- `scenes/ui/`
- `scripts/`
- `assets/`

This reduces merge conflicts and lets both people work in parallel.

## Commit examples

- `Add player movement`
- `Add enemy chase behaviour`
- `Create level 1 layout`
- `Add title screen UI`
- `Fix player collision`

## Important

The `.godot/` folder is generated locally by Godot and should **not** be committed.

If someone is currently editing a major scene, coordinate before editing that same scene yourself.
