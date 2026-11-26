# Contributing to DEADWEIGHT

DEADWEIGHT is released as-is under the [MIT license](LICENSE). The original author has stopped
working on it. Fork it, finish it, strip it for parts or ship your own version.

## AI contributions are welcome

Most of this game was written by AI coding agents (Claude) working from task cards, so
AI-written pull requests are welcome too. Use whatever tools you like. Every pull request,
however it was written, should:

- pass the quality gate: `powershell -ExecutionPolicy Bypass -File tests/run_all.ps1`
- say what changed and how you checked it (a test, a capture, or a playthrough)
- name the model or tool you used in the description or a `Co-Authored-By:` trailer, so
  readers know what produced it
- include only work you are allowed to share under the MIT license: nothing copied from
  other games, and no third-party art, music or fonts unless you add their license to
  `THIRD_PARTY_NOTICES.txt`

AI-generated images or audio need their prompt recorded next to them, the same way
[assets/dreamscape/PROMPTS.md](assets/dreamscape/PROMPTS.md) records the six existing textures.

## Where to start

- [README.md](README.md): setup, controls, builds and the project map.
- [docs/EXECUTOR_BRIEF.md](docs/EXECUTOR_BRIEF.md): the rules every agent followed. Point your agent at it.
- [docs/TASKS.md](docs/TASKS.md) and [docs/PLAN.md](docs/PLAN.md): what was planned and what was left.
- [docs/PLAYTEST_QUESTS.md](docs/PLAYTEST_QUESTS.md): a checklist for playing the whole game.

Nobody is watching this repository closely, so a pull request may wait a long time. If you
want something to move faster, fork it.
